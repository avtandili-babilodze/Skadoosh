class_name Fighter
extends CharacterBody2D
## A player-controlled fighter. Hero stats and skills come from HeroData; this
## scene owns the shared movement/combat state machine used by every fighter.
## How the fighter looks lives in FighterVisuals, which this script feeds with
## what happens: the pose to show, attacks, hits, landings and respawns. Sparks,
## shake and sound go through the Fx and Sfx services, which stay silent unless
## a match is running.

const PROJECTILE := preload("res://entities/projectile/projectile.tscn")
const GROUND_SPIKE := preload("res://entities/ground_spike/ground_spike.tscn")
const OVERLAY := preload("res://entities/player/fighter_overlay.gd")

## Physics layers: 1 = solid stage, 2 = fighters, 3 = pass-through platforms.
const SOLID_MASK := 1
const PLATFORM_MASK := 4
## A press this long before an action becomes possible still counts, so a jump
## tapped just before landing or an attack tapped during end lag is not lost.
const INPUT_BUFFER := 0.12
## How long a tap of "down" lets the fighter fall through a platform.
const DROP_TIME := 0.24
## Damage % from which a fighter visibly smoulders: one more good hit will send
## them a long way.
const DANGER_PERCENT := 100.0
## A fighter who reaches the stage's side wall with its feet no more than this
## far below the ledge is pulled up onto it, so a recovery that just falls short
## still makes it.
const LEDGE_HELP := 40.0
const BUFFERED_ACTIONS := ["jump", "dash", "attack", "attack2"]

enum FighterState { FREE, DASHING, DODGING, ATTACKING, END_LAG, HIT_STUN, FROZEN, ELIMINATED }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

@export var hero: HeroData
## 0 = Player 1, 1 = Player 2. Picks the player colour and tag.
@export var player_index: int = 0
## Short name shown above the fighter and on its HUD plate ("P1", "CPU").
## Empty means "P" + the player number.
@export var tag: String = ""

@export_group("Controls")
@export var action_left: StringName = "p1_left"
@export var action_right: StringName = "p1_right"
@export var action_jump: StringName = "p1_jump"
@export var action_down: StringName = "p1_down"
@export var action_dash: StringName = "p1_dash"
@export var action_attack: StringName = "p1_attack"
@export var action_attack2: StringName = "p1_attack2"

@export_group("Rules")
@export var respawn_invincibility: float = 2.5
## Shortest time a hit leaves its victim without control.
@export var hit_stun: float = 0.2
## Extra stun per unit of launch speed, so a big launch cannot be braked at once.
@export var hit_stun_per_knockback: float = 0.0002
@export var max_hit_stun: float = 0.75

## Accumulated damage %. Higher damage amplifies incoming knockback.
var damage_taken: float = 0.0
## Everything this fighter shows: poses, animation clocks, squash and bob.
var visuals: FighterVisuals
## False while the match is counting in or over: the fighter stands and
## animates but ignores its player.
var controls_enabled: bool = true
## Who landed the last accepted hit, and when (for crediting knock-outs).
var last_attacker: Node = null
var last_hit_ms: int = 0
## Total damage this fighter has dealt this match.
var damage_dealt: float = 0.0
## Where this fighter's commands come from: a player's keys by default, or a
## FighterBrain when the CPU plays it.
var input: FighterInput = FighterInput.new()

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
var _drop_time_left: float = 0.0
var _buffer: Dictionary = {}
var _trail_time_left: float = 0.0
var _steam_time_left: float = 0.0
var _last_step: int = 0
var _was_on_floor: bool = true
var _last_fall_speed: float = 0.0
var _last_velocity_x: float = 0.0

var _attack_skill: AttackData = null
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_phase_time_left: float = 0.0
var _attack_hit_targets: Dictionary = {}
var _overlay: Node2D


func _ready() -> void:
	add_to_group("players")
	if hero == null:
		push_warning("%s has no HeroData assigned — using defaults." % name)
		hero = HeroData.new()
	_spawn_position = global_position
	var feet := 50.0
	var box := $CollisionShape2D.shape as RectangleShape2D
	if box != null:
		feet = box.size.y * 0.5
	collision_mask = SOLID_MASK | PLATFORM_MASK
	# The sprite animates on the render clock, so only the body is interpolated.
	$Sprite2D.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	$ColorRect.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visuals = FighterVisuals.new(self, $Sprite2D, $ColorRect, feet)
	_overlay = OVERLAY.new()
	_overlay.color = get_player_color()
	_overlay.label = get_tag()
	_overlay.feet = feet
	add_child(_overlay)
	move_child(_overlay, 0)
	for action: String in BUFFERED_ACTIONS:
		_buffer[action] = 0.0
	_reset_air_actions()
	visuals.show_idle()


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_state(delta)
	if controls_enabled:
		input.poll(self, delta)
	else:
		input.clear()
	_read_buffer(delta)

	var dodging := _state == FighterState.DODGING
	var down_held := input.down

	# Dodge suspends vertical movement. Every other airborne state receives gravity,
	# including attacks and hit stun, so launch trajectories remain predictable.
	if dodging:
		velocity.y = 0.0
	elif not is_on_floor():
		var fall := get_gravity() * hero.gravity_scale
		if _state == FighterState.FREE and down_held:
			fall *= hero.fast_fall_scale
		velocity += fall * delta

	if is_on_floor():
		_reset_air_actions()

	_update_platform_pass(down_held)

	var direction := 0.0
	if _state == FighterState.FREE:
		direction = input.axis
		if direction != 0.0:
			var new_facing := signf(direction)
			# Reversing at speed on the ground kicks up a skid of dust.
			if new_facing != _facing and is_on_floor() and absf(velocity.x) > hero.speed * 0.6:
				Fx.dust(get_feet(), _facing, 4, 150.0)
			_facing = new_facing
		_handle_free_input(direction)

	_apply_horizontal_movement(direction, delta)
	_last_fall_speed = velocity.y
	_last_velocity_x = velocity.x
	visuals.select_pose(direction)
	move_and_slide()
	_try_ledge_climb()
	visuals.note_ground(is_on_floor())
	_note_ground_change()
	_update_trails(delta)
	_overlay.update_floor(_probe_floor())


func _process(delta: float) -> void:
	visuals.advance(delta)
	_update_footsteps()


## A soft footfall twice per run cycle, read off the same clock that draws the legs.
func _update_footsteps() -> void:
	if visuals.pose != "walk" or hero.walk_fps <= 0.0:
		return
	var frames: int = hero.walk_frames if hero.walk_frames > 0 \
			else maxi(1, hero.walk_hframes * hero.walk_vframes)
	var footfall := int(visuals.walk_time * hero.walk_fps / float(frames) * 2.0)
	if footfall != _last_step:
		_last_step = footfall
		if Fx.is_active() and is_on_floor():
			Sfx.play("step", -9.0, 1.0, 0.1)


# --- State the visuals and the arena read ---------------------------------------

func is_attacking() -> bool:
	return _state == FighterState.ATTACKING


func is_hit_stunned() -> bool:
	return _state == FighterState.HIT_STUN


func is_dashing() -> bool:
	return _state == FighterState.DASHING


func is_dodging() -> bool:
	return _state == FighterState.DODGING


## The control lock that follows an attack (the attack itself has finished).
func is_in_end_lag() -> bool:
	return _state == FighterState.END_LAG


func is_invincible() -> bool:
	return _invincible_time_left > 0.0


func get_invincible_time_left() -> float:
	return _invincible_time_left


func is_eliminated() -> bool:
	return _state == FighterState.ELIMINATED


func get_facing() -> float:
	return _facing


func is_free() -> bool:
	return _state == FighterState.FREE


## Jumps still available from the jump key before landing.
func get_jumps_left() -> int:
	return _jumps_left


## Extra air jumps still available from the heavy-attack key.
func get_air_jumps_left() -> int:
	return _air_attack_jumps_left


## True when the given skill could start right now.
func can_use(skill: AttackData, is_heavy: bool) -> bool:
	if skill == null or _state != FighterState.FREE or _attack_lock_left > 0.0:
		return false
	return (_heavy_cooldown_left if is_heavy else _light_cooldown_left) == 0.0


func can_dodge() -> bool:
	return _state == FighterState.FREE and _dash_cooldown_left == 0.0 and _dodge_cooldown_left == 0.0


func face(direction: float) -> void:
	if direction != 0.0:
		_facing = signf(direction)


func get_tag() -> String:
	return tag if tag != "" else "P%d" % (player_index + 1)


func get_player_color() -> Color:
	return Roster.PLAYER_COLORS[clampi(player_index, 0, Roster.PLAYER_COLORS.size() - 1)]


## The point on the floor line under the fighter's centre.
func get_feet() -> Vector2:
	return global_position + Vector2(0.0, visuals.ground_offset)


# --- Timers and input -----------------------------------------------------------

func _tick_cooldowns(delta: float) -> void:
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_heavy_cooldown_left = maxf(0.0, _heavy_cooldown_left - delta)
	_light_cooldown_left = maxf(0.0, _light_cooldown_left - delta)
	_attack_lock_left = maxf(0.0, _attack_lock_left - delta)
	_invincible_time_left = maxf(0.0, _invincible_time_left - delta)
	_drop_time_left = maxf(0.0, _drop_time_left - delta)


func _tick_state(delta: float) -> void:
	match _state:
		FighterState.DASHING, FighterState.DODGING, FighterState.END_LAG, FighterState.HIT_STUN:
			_state_time_left = maxf(0.0, _state_time_left - delta)
			if _state_time_left == 0.0:
				_state = FighterState.FREE
		FighterState.ATTACKING:
			_tick_attack(delta)


## Remembers each fresh press for a short while (see INPUT_BUFFER).
func _read_buffer(delta: float) -> void:
	for key: String in BUFFERED_ACTIONS:
		if input.just(key):
			_buffer[key] = INPUT_BUFFER
		else:
			_buffer[key] = maxf(0.0, _buffer[key] - delta)


func _wants(action: String) -> bool:
	return _buffer[action] > 0.0


func _consume(action: String) -> void:
	_buffer[action] = 0.0


func _handle_free_input(direction: float) -> void:
	var jumped := false
	if _wants("jump") and _jumps_left > 0:
		_consume("jump")
		var from_floor := is_on_floor()
		velocity.y = hero.jump_velocity
		_jumps_left -= 1
		jumped = true
		if from_floor:
			Fx.dust(get_feet(), 0.0, 3, 110.0)
			Sfx.play("jump", -6.0)
		else:
			Fx.burst(get_feet(), Color(1, 1, 1, 0.7), 6, 160.0, Vector2.DOWN, 60.0, 0.3, 4.0, 0.0)
			Sfx.play("double_jump", -6.0)

	# Actions are intentionally exclusive and prioritized. Pressing both attack
	# buttons can no longer execute two skills in the same physics frame.
	if _wants("dash") and _dash_cooldown_left == 0.0:
		_consume("dash")
		_start_dash_or_dodge(direction)
	elif not jumped and _wants("attack"):
		if not is_on_floor():
			_consume("attack")
			if _air_attack_jumps_left > 0:
				velocity.y = hero.jump_velocity
				_air_attack_jumps_left -= 1
				Fx.burst(get_feet(), Color(1, 1, 1, 0.7), 6, 160.0, Vector2.DOWN, 60.0, 0.3, 4.0, 0.0)
				Sfx.play("double_jump", -6.0, 1.15)
		elif _try_heavy_attack():
			_consume("attack")
	elif not jumped and _wants("attack2"):
		if _light_cooldown_left == 0.0 and _attack_lock_left == 0.0:
			if _begin_attack(hero.light_attack, false):
				_consume("attack2")


func _try_heavy_attack() -> bool:
	if _heavy_cooldown_left > 0.0 or _attack_lock_left > 0.0:
		return false
	return _begin_attack(hero.heavy_attack, true)


# --- Movement -------------------------------------------------------------------

func _start_dash_or_dodge(direction: float) -> void:
	var wants_dodge := direction == 0.0 and hero.dodge_duration > 0.0
	if wants_dodge:
		if _dodge_cooldown_left > 0.0:
			return
		_state = FighterState.DODGING
		_state_time_left = hero.dodge_duration
		_dodge_cooldown_left = hero.dodge_cooldown
		velocity = Vector2.ZERO
		Sfx.play("dodge", -5.0)
	else:
		_state = FighterState.DASHING
		_state_time_left = hero.dash_duration
		if is_on_floor():
			Fx.dust(get_feet(), -_facing, 6, 190.0)
		Sfx.play("dash", -7.0)
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


func _reset_air_actions() -> void:
	_jumps_left = hero.max_jumps
	_air_attack_jumps_left = hero.air_attack_jumps


## Pass-through platforms stop colliding while the fighter drops through one
## (a tap of down while standing on it) or fast-falls with down held.
func _update_platform_pass(down_held: bool) -> void:
	if _state == FighterState.FREE and is_on_floor() and input.just("down") and _is_on_platform():
		_drop_time_left = DROP_TIME
		position.y += 2.0
	var passing := _drop_time_left > 0.0 \
			or (down_held and _state == FighterState.FREE and not is_on_floor())
	collision_mask = SOLID_MASK if passing else SOLID_MASK | PLATFORM_MASK


func _is_on_platform() -> bool:
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as CollisionObject2D
		if body != null and (body.collision_layer & PLATFORM_MASK) != 0:
			return true
	return false


## Pulls the fighter up onto a ledge it has reached from just below (see
## LEDGE_HELP). Only the solid stage counts, and only while steering or
## drifting into the wall, so nobody is yanked up by brushing past a corner.
func _try_ledge_climb() -> void:
	if is_on_floor() or not is_on_wall() or velocity.y < -260.0:
		return
	if _state == FighterState.HIT_STUN or _state == FighterState.DODGING:
		return
	var normal := get_wall_normal()
	if absf(normal.x) < 0.7:
		return
	var toward := -signf(normal.x)
	if input.axis * toward <= 0.0 and _last_velocity_x * toward <= 40.0:
		return
	var box := $CollisionShape2D.shape as RectangleShape2D
	var half_width := box.size.x * 0.5 if box != null else 25.0
	var feet := get_feet()
	# Look straight down onto the ledge from just inside the wall.
	var probe_x := feet.x + toward * (half_width + 8.0)
	var from := Vector2(probe_x, feet.y - LEDGE_HELP - 6.0)
	var ray := PhysicsRayQueryParameters2D.create(from, Vector2(probe_x, feet.y + 2.0), SOLID_MASK)
	ray.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector2).y > -0.7:
		return
	var top: float = (hit.position as Vector2).y
	if top <= from.y + 1.0:
		return   # the probe started inside the stage: this is not a ledge
	# Up onto the ledge and far enough in that the fighter stands over the floor.
	global_position += Vector2(toward * (half_width + 2.0), top - feet.y - 1.0)
	velocity.y = 0.0
	Fx.dust(Vector2(probe_x, top), -toward, 3, 90.0)


## Distance from the centre down to the nearest floor, or -1 over a pit.
func _probe_floor() -> float:
	var from := global_position
	var ray := PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, OVERLAY.REACH), SOLID_MASK | PLATFORM_MASK)
	ray.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return -1.0
	return (hit.position as Vector2).y - from.y


func _note_ground_change() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _last_fall_speed > 260.0:
		Fx.dust(get_feet(), 0.0, 4 if _last_fall_speed < 700.0 else 7, 130.0)
		Sfx.play("land", lerpf(-12.0, -4.0, clampf(_last_fall_speed / 1100.0, 0.0, 1.0)))
	_was_on_floor = on_floor


## Afterimages while dashing or dodging, smoke while being launched.
func _update_trails(delta: float) -> void:
	_trail_time_left -= delta
	if _trail_time_left > 0.0:
		return
	if _state == FighterState.DASHING or _state == FighterState.DODGING:
		_trail_time_left = 0.035
		if visuals.rig != null:
			Fx.ghost_node(visuals.rig.snapshot(), visuals.rig.global_transform, get_player_color())
		else:
			Fx.ghost($Sprite2D, get_player_color())
	elif _state == FighterState.HIT_STUN and velocity.length() > 460.0:
		_trail_time_left = 0.03
		Fx.trail(global_position, Color(0.95, 0.93, 0.9, 0.55))
	# Past the danger line a fighter gives off wisps of steam, more the higher it climbs.
	_steam_time_left -= delta
	if damage_taken >= DANGER_PERCENT and _steam_time_left <= 0.0 and visible:
		_steam_time_left = lerpf(0.34, 0.12, clampf((damage_taken - DANGER_PERCENT) / 120.0, 0.0, 1.0))
		Fx.burst(global_position + Vector2(randf_range(-16.0, 16.0), -visuals.ground_offset * 0.7),
				Color(1.0, 0.82, 0.78, 0.5), 1, 46.0, Vector2.UP, 24.0, 0.5, 5.0, -90.0)


# --- Attacks --------------------------------------------------------------------

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

	visuals.show_attack(skill)
	if skill.kind == AttackData.Kind.MELEE:
		var weapon := hero.weapon_sound if hero.weapon_sound != "" else "swing"
		Sfx.play("%s_%s" % [weapon, "heavy" if is_heavy else "light"], -3.0)
	# Ground hazards telegraph from the moment the button is pressed. Their own
	# delay controls the exact eruption time, while the caster completes startup.
	if skill.kind == AttackData.Kind.GROUND_SPIKE:
		_spawn_ground_spike(skill)
		Sfx.play(_cast_sound(skill), -5.0)
	_set_attack_phase(AttackPhase.STARTUP)
	_resolve_zero_length_phases()
	return true


func _tick_attack(delta: float) -> void:
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
					_spawn_melee_effect(_attack_skill)
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
		if other.take_hit(skill.damage, skill.knockback, _facing, skill.knockback_up_ratio, self, false,
				ToonEffect.sound_kind(skill.effect) if skill.effect != "" else hero.weapon_sound):
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
	proj.set_animation(skill.projectile_hframes, skill.projectile_vframes,
			skill.projectile_frames, skill.projectile_fps)
	proj.set_effect(skill.effect)
	var off := skill.projectile_spawn_offset
	proj.position = global_position + Vector2(_facing * off.x, off.y)
	# Effects live beside the fighter (in the arena), so they end with the match.
	get_parent().add_child(proj)
	proj.reset_physics_interpolation()
	Sfx.play(_cast_sound(skill), -5.0)


## A melee skill with an effect bursts it out over its hitbox while the hit is live.
func _spawn_melee_effect(skill: AttackData) -> void:
	if skill.effect == "" or not ToonEffect.has_preset(skill.effect):
		return
	var burst := ToonEffect.new(skill.effect, skill.height * 1.15, _facing < 0.0)
	burst.z_index = 3
	var center := global_position + Vector2(_facing * skill.reach * 0.55, 0.0)
	burst.position = center + (Vector2(0.0, skill.height * 0.5) if burst.grounded else Vector2.ZERO)
	get_parent().add_child(burst)
	var life := skill.active_time + 0.22
	var tween := burst.create_tween()
	tween.tween_method(burst.set_grow, 0.2, 1.0, minf(0.08, skill.active_time))
	tween.tween_interval(maxf(0.0, skill.active_time - 0.08))
	tween.tween_method(burst.set_fade, 1.0, 0.0, 0.22)
	tween.tween_callback(burst.queue_free)
	Sfx.play(_cast_sound(skill), -6.0)


## Casts a delayed hazard at a fixed distance and snaps it to the first arena
## surface below that target point. A fallback keeps the move usable in test or
## custom scenes that do not provide floor collision on layer 1.
func _spawn_ground_spike(skill: AttackData) -> void:
	if skill.ground_spike_texture == null and not ToonEffect.has_preset(skill.effect):
		push_warning("%s is a ground-spike attack but has no effect art." % skill.skill_name)
		return
	var target_x := global_position.x + _facing * skill.ground_spike_distance
	var ray_start := Vector2(target_x, global_position.y - 180.0)
	var ray_end := Vector2(target_x, global_position.y + 900.0)
	var ray := PhysicsRayQueryParameters2D.create(ray_start, ray_end, SOLID_MASK | PLATFORM_MASK)
	ray.exclude = [get_rid()]
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(ray)
	var floor_y := global_position.y + 50.0
	if not floor_hit.is_empty():
		floor_y = (floor_hit.position as Vector2).y

	var spike := GROUND_SPIKE.instantiate()
	spike.effect = skill.effect
	spike.configure(self, _facing, skill.damage, skill.knockback,
			skill.knockback_up_ratio, skill.ground_spike_texture,
			skill.ground_spike_hframes, skill.ground_spike_vframes,
			skill.ground_spike_frames, skill.ground_spike_sprite_height,
			skill.ground_spike_hitbox_size, skill.ground_spike_delay,
			skill.ground_spike_active_time, skill.ground_spike_fade_time)
	spike.position = Vector2(target_x, floor_y)
	get_parent().add_child(spike)
	spike.reset_physics_interpolation()


## Picks the cast sound from what the effect art is: water, fire or dark matter.
func _cast_sound(skill: AttackData) -> String:
	var art: Texture2D = skill.projectile_texture
	if skill.kind == AttackData.Kind.GROUND_SPIKE:
		art = skill.ground_spike_texture
	var path := art.resource_path.to_lower() if art != null else ""
	path += " " + skill.effect
	if path.contains("water") or path.contains("wave") or path.contains("spit"):
		return "cast_water"
	if skill.kind == AttackData.Kind.GROUND_SPIKE and not (path.contains("fire") or path.contains("pillar")):
		return "cast_dark"
	return "cast_fire"


# --- Hits, respawn and match flow -----------------------------------------------

## Returns true only when damage was actually accepted. Active melee hitboxes can
## therefore continue checking a target that is currently protected by a dodge.
## `sound` names what struck: "blade", "fire", "water", "magic" or "" (a blow).
func take_hit(damage: float, base_knockback: float, dir: float, up_ratio: float,
		attacker: Node = null, from_projectile: bool = false, sound: String = "") -> bool:
	if _invincible_time_left > 0.0 or _state == FighterState.DODGING:
		return false
	if _state == FighterState.ELIMINATED or _state == FighterState.FROZEN:
		return false
	var mitigation := clampf(hero.defense, 0.0, 10.0) / 20.0
	var dealt := damage * (1.0 - mitigation)
	damage_taken += dealt
	_finish_attack()
	var percent_factor := 1.0 + (damage_taken / 100.0) * hero.knockback_percent_scale
	var force := base_knockback * percent_factor
	_state = FighterState.HIT_STUN
	_state_time_left = clampf(hit_stun + force * hit_stun_per_knockback, hit_stun, max_hit_stun)
	velocity = Vector2(dir * force, -force * up_ratio)
	visuals.on_hit()

	var spark := get_player_color()
	if attacker != null:
		last_attacker = attacker
		last_hit_ms = Time.get_ticks_msec()
		var foe := attacker as Fighter
		if foe != null:
			foe.damage_dealt += dealt
			spark = Roster.accent_of(foe.hero)
	Fx.hit(self, dir, dealt, force, spark, from_projectile, sound)
	return true


## Returns the fighter to play at `at` (its original spawn point by default),
## clean and briefly invincible.
func respawn(at: Vector2 = _spawn_position) -> void:
	global_position = at
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
	_drop_time_left = 0.0
	_invincible_time_left = respawn_invincibility
	last_attacker = null
	collision_layer = 2
	collision_mask = SOLID_MASK | PLATFORM_MASK
	show()
	set_physics_process(true)
	set_process(true)
	visuals.reset()
	reset_physics_interpolation()


## Takes the fighter out of play between a knock-out and its respawn.
func vanish() -> void:
	_finish_attack()
	_state = FighterState.FROZEN
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hide()
	set_physics_process(false)
	set_process(false)


func set_match_active(active: bool) -> void:
	if _state == FighterState.ELIMINATED:
		return
	if active:
		if _state == FighterState.FROZEN:
			_state = FighterState.FREE
		set_physics_process(true)
		set_process(true)
	else:
		_finish_attack()
		_state = FighterState.FROZEN
		velocity = Vector2.ZERO
		set_physics_process(false)
		set_process(false)


func eliminate() -> void:
	_finish_attack()
	_state = FighterState.ELIMINATED
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hide()
	set_physics_process(false)
	set_process(false)
	global_position = Vector2(-100000, -100000)
