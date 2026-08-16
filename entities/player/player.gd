extends CharacterBody2D
## A player-controlled fighter. Hero stats and skills come from HeroData; this
## scene owns the shared movement/combat state machine used by every fighter.

const PROJECTILE := preload("res://entities/projectile/projectile.tscn")
const GROUND_SPIKE := preload("res://entities/ground_spike/ground_spike.tscn")

enum FighterState { FREE, DASHING, DODGING, ATTACKING, END_LAG, HIT_STUN, FROZEN, ELIMINATED }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

@export var hero: HeroData

@export_group("Controls")
@export var action_left: StringName = "p1_left"
@export var action_right: StringName = "p1_right"
@export var action_jump: StringName = "p1_jump"
@export var action_down: StringName = "p1_down"
@export var action_dash: StringName = "p1_dash"
@export var action_attack: StringName = "p1_attack"
@export var action_attack2: StringName = "p1_attack2"

@export_group("Rules")
@export var respawn_invincibility: float = 3.0
@export var hit_stun: float = 0.2

@onready var _visual: ColorRect = $ColorRect
@onready var _sprite: Sprite2D = $Sprite2D

## Accumulated damage %. Higher damage amplifies incoming knockback.
var damage_taken: float = 0.0

var _spawn_position: Vector2
var _state: FighterState = FighterState.FREE
var _state_time_left: float = 0.0
var _invincible_time_left: float = 0.0
var _jumps_left: int = 0
var _air_attack_jumps_left: int = 0
var _facing: float = 1.0
var _dash_cooldown_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _heavy_cooldown_left: float = 0.0
var _light_cooldown_left: float = 0.0
var _attack_lock_left: float = 0.0

var _attack_skill: AttackData = null
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_phase_time_left: float = 0.0
var _attack_animation_elapsed: float = 0.0
var _attack_hit_targets: Dictionary = {}

var _art_faces_right: bool = true
var _pose: String = ""
var _anim_time: float = 0.0


func _ready() -> void:
	add_to_group("players")
	if hero == null:
		push_warning("%s has no HeroData assigned — using defaults." % name)
		hero = HeroData.new()
	_spawn_position = global_position
	_reset_air_actions()
	_show_idle()


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_state(delta)

	var dodging := _state == FighterState.DODGING
	var tint := Color(1.8, 1.8, 1.8) if dodging else Color.WHITE
	if _invincible_time_left > 0.0:
		tint.a = 0.35 if int(_invincible_time_left * 10.0) % 2 == 0 else 1.0
	modulate = tint

	# Dodge suspends vertical movement. Every other airborne state receives gravity,
	# including attacks and hit stun, so launch trajectories remain predictable.
	if dodging:
		velocity.y = 0.0
	elif not is_on_floor():
		var fall := get_gravity() * hero.gravity_scale
		if _state == FighterState.FREE and Input.is_action_pressed(action_down):
			fall *= hero.fast_fall_scale
		velocity += fall * delta

	if is_on_floor():
		_reset_air_actions()

	var direction := 0.0
	if _state == FighterState.FREE:
		direction = Input.get_axis(action_left, action_right)
		if direction != 0.0:
			_facing = signf(direction)
		_handle_free_input(direction)

	_apply_horizontal_movement(direction, delta)
	_update_pose(direction, delta)
	_sprite.flip_h = (_facing > 0.0) != _art_faces_right
	move_and_slide()


func _tick_cooldowns(delta: float) -> void:
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_heavy_cooldown_left = maxf(0.0, _heavy_cooldown_left - delta)
	_light_cooldown_left = maxf(0.0, _light_cooldown_left - delta)
	_attack_lock_left = maxf(0.0, _attack_lock_left - delta)
	_invincible_time_left = maxf(0.0, _invincible_time_left - delta)


func _tick_state(delta: float) -> void:
	match _state:
		FighterState.DASHING, FighterState.DODGING, FighterState.END_LAG, FighterState.HIT_STUN:
			_state_time_left = maxf(0.0, _state_time_left - delta)
			if _state_time_left == 0.0:
				_state = FighterState.FREE
		FighterState.ATTACKING:
			_tick_attack(delta)


func _handle_free_input(direction: float) -> void:
	var jumped := false
	if Input.is_action_just_pressed(action_jump) and _jumps_left > 0:
		velocity.y = hero.jump_velocity
		_jumps_left -= 1
		jumped = true

	# Actions are intentionally exclusive and prioritized. Pressing both attack
	# buttons can no longer execute two skills in the same physics frame.
	if Input.is_action_just_pressed(action_dash) and _dash_cooldown_left == 0.0:
		_start_dash_or_dodge(direction)
	elif not jumped and Input.is_action_just_pressed(action_attack):
		if not is_on_floor():
			if _air_attack_jumps_left > 0:
				velocity.y = hero.jump_velocity
				_air_attack_jumps_left -= 1
		else:
			_try_heavy_attack()
	elif not jumped and Input.is_action_just_pressed(action_attack2):
		if _light_cooldown_left == 0.0 and _attack_lock_left == 0.0:
			_begin_attack(hero.light_attack, false)


func _try_heavy_attack() -> bool:
	if _heavy_cooldown_left > 0.0 or _attack_lock_left > 0.0:
		return false
	return _begin_attack(hero.heavy_attack, true)


func _start_dash_or_dodge(direction: float) -> void:
	var wants_dodge := direction == 0.0 and hero.dodge_duration > 0.0
	if wants_dodge:
		if _dodge_cooldown_left > 0.0:
			return
		_state = FighterState.DODGING
		_state_time_left = hero.dodge_duration
		_dodge_cooldown_left = hero.dodge_cooldown
		velocity = Vector2.ZERO
	else:
		_state = FighterState.DASHING
		_state_time_left = hero.dash_duration
	_dash_cooldown_left = hero.dash_cooldown


func _apply_horizontal_movement(direction: float, delta: float) -> void:
	match _state:
		FighterState.HIT_STUN:
			pass # Preserve launch momentum until hit stun ends.
		FighterState.DODGING:
			velocity.x = 0.0
		FighterState.DASHING:
			velocity.x = _facing * hero.dash_speed
		FighterState.ATTACKING:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, hero.ground_acceleration * delta)
		FighterState.END_LAG:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, hero.ground_acceleration * delta)
		FighterState.FREE:
			var acceleration := hero.ground_acceleration if is_on_floor() else hero.air_acceleration
			var target := direction * hero.speed
			velocity.x = move_toward(velocity.x, target, acceleration * delta)


## Starts one attack transaction. The state guard makes this safe even if multiple
## callers request attacks in the same frame.
func _begin_attack(skill: AttackData, is_heavy: bool) -> bool:
	if _state != FighterState.FREE or skill == null:
		return false
	_state = FighterState.ATTACKING
	_attack_skill = skill
	_attack_hit_targets.clear()
	_attack_lock_left = hero.min_attack_interval
	if is_heavy:
		_heavy_cooldown_left = skill.cooldown
	else:
		_light_cooldown_left = skill.cooldown

	_attack_animation_elapsed = 0.0
	if skill.animation_texture != null:
		_show_attack_animation(skill)
	elif hero.attack_texture != null:
		_show_texture(hero.attack_texture, hero.attack_faces_right)
		_pose = "attack"
	# Ground hazards telegraph from the moment the button is pressed. Their own
	# delay controls the exact eruption time, while the caster completes startup.
	if skill.kind == AttackData.Kind.GROUND_SPIKE:
		_spawn_ground_spike(skill)
	_set_attack_phase(AttackPhase.STARTUP)
	_resolve_zero_length_phases()
	return true


func _tick_attack(delta: float) -> void:
	_attack_animation_elapsed += delta
	_update_attack_animation()
	_attack_phase_time_left -= delta
	var transitions := 0
	while _state == FighterState.ATTACKING and _attack_phase_time_left <= 0.0 and transitions < 4:
		var overflow := -_attack_phase_time_left
		_advance_attack_phase()
		if _state == FighterState.ATTACKING:
			_attack_phase_time_left -= overflow
		transitions += 1
	if _state == FighterState.ATTACKING and _attack_phase == AttackPhase.ACTIVE:
		if _attack_skill.kind == AttackData.Kind.MELEE:
			_melee_hit(_attack_skill)


func _resolve_zero_length_phases() -> void:
	var transitions := 0
	while _state == FighterState.ATTACKING and _attack_phase_time_left <= 0.0 and transitions < 4:
		_advance_attack_phase()
		transitions += 1


func _set_attack_phase(phase: AttackPhase) -> void:
	_attack_phase = phase
	match phase:
		AttackPhase.STARTUP:
			_attack_phase_time_left = _attack_skill.startup_time
		AttackPhase.ACTIVE:
			_attack_phase_time_left = _attack_skill.active_time
			match _attack_skill.kind:
				AttackData.Kind.RANGED:
					_spawn_projectile(_attack_skill)
				AttackData.Kind.GROUND_SPIKE:
					pass # Already spawned at button press so its warning is visible immediately.
				_:
					_melee_hit(_attack_skill)
		AttackPhase.RECOVERY:
			_attack_phase_time_left = _attack_skill.recovery_time


func _advance_attack_phase() -> void:
	match _attack_phase:
		AttackPhase.STARTUP:
			_set_attack_phase(AttackPhase.ACTIVE)
		AttackPhase.ACTIVE:
			_set_attack_phase(AttackPhase.RECOVERY)
		AttackPhase.RECOVERY:
			_finish_attack(true)


func _finish_attack(apply_end_lag: bool = false) -> void:
	var end_lag := _attack_skill.post_end_lag if _attack_skill != null else 0.0
	_attack_skill = null
	_attack_phase = AttackPhase.NONE
	_attack_phase_time_left = 0.0
	_attack_animation_elapsed = 0.0
	_attack_hit_targets.clear()
	if _state == FighterState.ATTACKING:
		if apply_end_lag and end_lag > 0.0:
			_state = FighterState.END_LAG
			_state_time_left = end_lag
		else:
			_state = FighterState.FREE


## Query actual physics hurtboxes in front of the fighter. Repeating this during
## the active phase allows a moving target to enter the hitbox, while the target
## dictionary guarantees at most one hit per attack.
func _melee_hit(skill: AttackData) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(1.0, skill.reach), maxf(1.0, skill.height))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(_facing * skill.reach * 0.5, 0.0))
	query.collision_mask = 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var other: Node = hit.get("collider")
		if other == null or not other.is_in_group("players") or not other.has_method("take_hit"):
			continue
		var target_id := other.get_instance_id()
		if _attack_hit_targets.has(target_id):
			continue
		if other.take_hit(skill.damage, skill.knockback, _facing, skill.knockback_up_ratio):
			_attack_hit_targets[target_id] = true


func _spawn_projectile(skill: AttackData) -> void:
	if skill.projectile_texture == null:
		push_warning("%s is ranged but has no projectile texture." % skill.skill_name)
		return
	var proj := PROJECTILE.instantiate()
	proj.configure(self, _facing, skill.damage, skill.knockback, skill.knockback_up_ratio,
			skill.projectile_speed, skill.projectile_range, skill.projectile_lifetime,
			skill.projectile_texture, skill.projectile_height, skill.projectile_radius,
			skill.projectile_faces_right, skill.projectile_start_scale,
			skill.projectile_end_scale, skill.projectile_end_damage_multiplier,
			skill.projectile_grounded)
	get_tree().current_scene.add_child(proj)
	var off := skill.projectile_spawn_offset
	proj.global_position = global_position + Vector2(_facing * off.x, off.y)


## Casts a delayed hazard at a fixed distance and snaps it to the first arena
## surface below that target point. A fallback keeps the move usable in test or
## custom scenes that do not provide floor collision on layer 1.
func _spawn_ground_spike(skill: AttackData) -> void:
	if skill.ground_spike_texture == null:
		push_warning("%s is a ground-spike attack but has no effect texture." % skill.skill_name)
		return
	var target_x := global_position.x + _facing * skill.ground_spike_distance
	var ray_start := Vector2(target_x, global_position.y - 180.0)
	var ray_end := Vector2(target_x, global_position.y + 900.0)
	var ray := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
	ray.exclude = [get_rid()]
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(ray)
	var floor_y := global_position.y + 50.0
	if not floor_hit.is_empty():
		floor_y = (floor_hit.position as Vector2).y

	var spike := GROUND_SPIKE.instantiate()
	spike.configure(self, _facing, skill.damage, skill.knockback,
			skill.knockback_up_ratio, skill.ground_spike_texture,
			skill.ground_spike_hframes, skill.ground_spike_vframes,
			skill.ground_spike_frames, skill.ground_spike_sprite_height,
			skill.ground_spike_hitbox_size, skill.ground_spike_delay,
			skill.ground_spike_active_time, skill.ground_spike_fade_time)
	get_tree().current_scene.add_child(spike)
	spike.global_position = Vector2(target_x, floor_y)


## Returns true only when damage was actually accepted. Active melee hitboxes can
## therefore continue checking a target that is currently protected by a dodge.
func take_hit(damage: float, base_knockback: float, dir: float, up_ratio: float) -> bool:
	if _invincible_time_left > 0.0 or _state == FighterState.DODGING:
		return false
	if _state == FighterState.ELIMINATED or _state == FighterState.FROZEN:
		return false
	var mitigation := clampf(hero.defense, 0.0, 10.0) / 20.0
	damage_taken += damage * (1.0 - mitigation)
	_finish_attack()
	_state = FighterState.HIT_STUN
	_state_time_left = hit_stun
	var percent_factor := 1.0 + (damage_taken / 100.0) * hero.knockback_percent_scale
	var force := base_knockback * percent_factor
	velocity = Vector2(dir * force, -force * up_ratio)
	return true


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	damage_taken = 0.0
	_state = FighterState.FREE
	_state_time_left = 0.0
	_finish_attack()
	_reset_air_actions()
	_dodge_cooldown_left = 0.0
	_dash_cooldown_left = 0.0
	_heavy_cooldown_left = 0.0
	_light_cooldown_left = 0.0
	_attack_lock_left = 0.0
	_invincible_time_left = respawn_invincibility
	_show_idle()


func set_match_active(active: bool) -> void:
	if _state == FighterState.ELIMINATED:
		return
	if active:
		if _state == FighterState.FROZEN:
			_state = FighterState.FREE
		set_physics_process(true)
	else:
		_finish_attack()
		_state = FighterState.FROZEN
		velocity = Vector2.ZERO
		set_physics_process(false)


func eliminate() -> void:
	_finish_attack()
	_state = FighterState.ELIMINATED
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hide()
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)


func _reset_air_actions() -> void:
	_jumps_left = hero.max_jumps
	_air_attack_jumps_left = hero.air_attack_jumps


func _update_pose(direction: float, delta: float) -> void:
	if _state == FighterState.ATTACKING:
		return
	if not is_on_floor() and (hero.jump_texture != null or hero.fall_texture != null):
		_show_air(delta)
	elif is_on_floor() and direction != 0.0 and hero.walk_texture != null:
		_show_walk(delta)
	else:
		_show_idle()


func _show_attack_animation(skill: AttackData) -> void:
	_pose = "attack"
	_configure_sprite(skill.animation_texture, skill.animation_hframes,
			skill.animation_vframes, skill.animation_sprite_height,
			skill.animation_faces_right)


func _update_attack_animation() -> void:
	if _attack_skill == null or _attack_skill.animation_texture == null:
		return
	var grid_frames := maxi(1, _sprite.hframes * _sprite.vframes)
	var frame_count := mini(grid_frames,
			_attack_skill.animation_frames if _attack_skill.animation_frames > 0 else grid_frames)
	var total_time := (_attack_skill.startup_time + _attack_skill.active_time
			+ _attack_skill.recovery_time)
	var progress := clampf(_attack_animation_elapsed / maxf(total_time, 0.001), 0.0, 0.9999)
	_sprite.frame = mini(frame_count - 1, int(progress * frame_count))


func _show_idle() -> void:
	if _pose == "idle":
		return
	_pose = "idle"
	if hero.texture != null:
		_show_texture(hero.texture, hero.faces_right)
	else:
		_visual.color = hero.color
		_visual.visible = true
		_sprite.visible = false


func _show_walk(delta: float) -> void:
	if _pose != "walk":
		_pose = "walk"
		_anim_time = 0.0
		_configure_sprite(hero.walk_texture, hero.walk_hframes, hero.walk_vframes,
				hero.walk_sprite_height, hero.walk_faces_right)
	_anim_time += delta
	var count := hero.walk_frames if hero.walk_frames > 0 else _sprite.hframes * _sprite.vframes
	if count > 0:
		_sprite.frame = int(_anim_time * hero.walk_fps) % count


func _show_air(delta: float) -> void:
	var rising := velocity.y < 0.0
	var texture: Texture2D = hero.jump_texture if rising else hero.fall_texture
	if texture == null:
		texture = hero.fall_texture if rising else hero.jump_texture
	if texture == null:
		_show_idle()
		return
	var wanted_pose := "jump" if rising else "fall"
	var hframes := hero.jump_hframes if rising else hero.fall_hframes
	var vframes := hero.jump_vframes if rising else hero.fall_vframes
	var configured_frames := hero.jump_frames if rising else hero.fall_frames
	var fps := hero.jump_fps if rising else hero.fall_fps
	if _pose != wanted_pose:
		_pose = wanted_pose
		_anim_time = 0.0
		_configure_sprite(texture, hframes, vframes, hero.air_sprite_height,
				hero.air_faces_right)
	_anim_time += delta
	var grid_frames := maxi(1, _sprite.hframes * _sprite.vframes)
	var frame_count := mini(grid_frames,
			configured_frames if configured_frames > 0 else grid_frames)
	# Jump and dive sequences play once, then hold their final pose until vertical
	# direction changes. Looping takeoff frames in mid-air caused visible popping.
	_sprite.frame = mini(frame_count - 1, int(_anim_time * maxf(0.0, fps)))


func _show_texture(texture: Texture2D, faces_right: bool, height: float = -1.0) -> void:
	var target_height := height if height > 0.0 else hero.sprite_height
	_configure_sprite(texture, 1, 1, target_height, faces_right)


func _configure_sprite(texture: Texture2D, hframes: int, vframes: int,
		target_height: float, faces_right: bool) -> void:
	if texture == null:
		_sprite.visible = false
		return
	var columns := maxi(1, hframes)
	var rows := maxi(1, vframes)
	var frame_height := texture.get_height() / float(rows)
	if frame_height <= 0.0:
		_sprite.visible = false
		return
	var scale_factor := target_height / frame_height
	_sprite.visible = false
	_sprite.texture = texture
	_sprite.hframes = columns
	_sprite.vframes = rows
	_sprite.frame = 0
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_art_faces_right = faces_right
	_visual.visible = false
	_sprite.visible = true
