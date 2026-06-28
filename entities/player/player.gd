extends CharacterBody2D
## A player-controlled fighter.
##
## Stats (speed, jump, attack, ...) come from an assigned HeroData resource.
## Controls come from an input "profile" — the action names mapped to this
## player's keys. The same scene is reused for every player; only the `hero`
## and the action names differ.

## Generic projectile used by ranged heroes (configured per-hero from HeroData).
const PROJECTILE := preload("res://entities/projectile/projectile.tscn")

## The hero this player is currently playing. Assigned per-player in the arena.
@export var hero: HeroData

@export_group("Controls")
@export var action_left: StringName = "p1_left"
@export var action_right: StringName = "p1_right"
@export var action_jump: StringName = "p1_jump"
@export var action_down: StringName = "p1_down"
@export var action_dash: StringName = "p1_dash"
@export var action_attack: StringName = "p1_attack"
## Light-attack key (the heavy attack is on action_attack).
@export var action_attack2: StringName = "p1_attack2"

@export_group("Rules")
## Seconds of invincibility after respawning (can't be hit during this window).
@export var respawn_invincibility: float = 3.0
## Seconds you're frozen (no control) after getting hit. Knockback still carries you.
@export var hit_stun: float = 0.2

@onready var _visual: ColorRect = $ColorRect
@onready var _sprite: Sprite2D = $Sprite2D

## Accumulated damage %, Brawlhalla-style: the higher it is, the farther this
## player flies when hit. Starts at 0.
var damage_taken: float = 0.0

# --- internal state ---
var _spawn_position: Vector2
var _invincible_time_left: float = 0.0
var _jumps_left: int = 0
var _facing: float = 1.0              # 1 = right, -1 = left
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _attack_time_left: float = 0.0
var _attack_cooldown_left: float = 0.0
var _attack2_cooldown_left: float = 0.0
var _attack_lock_left: float = 0.0    # shared lockout: blocks BOTH attacks briefly
var _stun_time_left: float = 0.0      # hit-stun: no control while > 0
var _art_faces_right: bool = true     # drawn facing of whatever texture is shown
var _pose: String = ""                # current visual: "idle" / "walk" / "attack"
var _anim_time: float = 0.0           # elapsed time in the current walk cycle


func _ready() -> void:
	add_to_group("players")
	# Fall back to default stats if someone forgot to assign a hero.
	if hero == null:
		push_warning("%s has no HeroData assigned — using defaults." % name)
		hero = HeroData.new()
	_spawn_position = global_position
	_show_idle()


func _physics_process(delta: float) -> void:
	# --- Tick timers ---
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_dash_time_left = maxf(0.0, _dash_time_left - delta)
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_attack2_cooldown_left = maxf(0.0, _attack2_cooldown_left - delta)
	_attack_lock_left = maxf(0.0, _attack_lock_left - delta)
	_stun_time_left = maxf(0.0, _stun_time_left - delta)

	# Respawn invincibility: count down and blink the fighter while active.
	if _invincible_time_left > 0.0:
		_invincible_time_left = maxf(0.0, _invincible_time_left - delta)
		modulate.a = 0.35 if int(_invincible_time_left * 10.0) % 2 == 0 else 1.0
		if _invincible_time_left == 0.0:
			modulate.a = 1.0

	if _attack_time_left > 0.0:
		_attack_time_left -= delta  # pose selector below restores idle/walk when it ends

	# --- Gravity ---
	if not is_on_floor():
		var fall := get_gravity() * hero.gravity_scale
		if Input.is_action_pressed(action_down):
			fall *= hero.fast_fall_scale  # fast fall
		velocity += fall * delta

	# Refill jumps on landing (even while stunned, so you're ready when it ends).
	if is_on_floor():
		_jumps_left = hero.max_jumps

	# While stunned: no input is read; gravity + knockback momentum still apply.
	var stunned := _stun_time_left > 0.0
	var direction := 0.0
	if not stunned:
		# --- Jump (double / multi) ---
		if Input.is_action_just_pressed(action_jump) and _jumps_left > 0:
			velocity.y = hero.jump_velocity
			_jumps_left -= 1

		# --- Facing ---
		direction = Input.get_axis(action_left, action_right)
		if direction != 0.0:
			_facing = signf(direction)

		# --- Dash ---
		if Input.is_action_just_pressed(action_dash) and _dash_cooldown_left == 0.0:
			_dash_time_left = hero.dash_duration
			_dash_cooldown_left = hero.dash_cooldown

		# --- Attack ---
		if Input.is_action_just_pressed(action_attack) and _attack_cooldown_left == 0.0 and _attack_lock_left == 0.0:
			_use_skill(hero.heavy_attack, true)
		if Input.is_action_just_pressed(action_attack2) and _attack2_cooldown_left == 0.0 and _attack_lock_left == 0.0:
			_use_skill(hero.light_attack, false)

	# --- Horizontal velocity ---
	if stunned:
		pass                                       # locked: keep the knockback momentum
	elif _dash_time_left > 0.0:
		velocity.x = _facing * hero.dash_speed     # dash overrides movement
	elif direction != 0.0:
		velocity.x = direction * hero.speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, hero.speed)

	# --- Pose selection (don't override the attack pose while it plays) ---
	if _attack_time_left <= 0.0:
		if is_on_floor() and direction != 0.0 and hero.walk_texture != null:
			_show_walk(delta)
		else:
			_show_idle()

	# Keep the avatar facing its movement direction.
	_sprite.flip_h = (_facing > 0.0) != _art_faces_right

	move_and_slide()


## Perform a skill (light or heavy). is_heavy picks which cooldown timer to set.
func _use_skill(skill: AttackData, is_heavy: bool) -> void:
	if skill == null:
		return
	_attack_time_left = skill.duration
	_attack_lock_left = hero.min_attack_interval
	if is_heavy:
		_attack_cooldown_left = skill.cooldown
	else:
		_attack2_cooldown_left = skill.cooldown

	# Both skills share the hero's attack pose.
	if hero.attack_texture != null:
		_show_texture(hero.attack_texture, hero.attack_faces_right)
		_pose = "attack"

	if skill.kind == AttackData.Kind.RANGED:
		_spawn_projectile(skill)
	else:
		_melee_hit(skill)


## Melee: a hitbox in front of us. Hit every other player inside it.
func _melee_hit(skill: AttackData) -> void:
	for other in get_tree().get_nodes_in_group("players"):
		if other == self:
			continue
		var offset: Vector2 = other.global_position - global_position
		var in_front := signf(offset.x) == _facing
		if in_front and absf(offset.x) <= skill.reach and absf(offset.y) <= skill.height:
			other.take_hit(skill.damage, skill.knockback, _facing, skill.knockback_up_ratio)


## Ranged: spawn a projectile in front of us that flies in our facing direction.
func _spawn_projectile(skill: AttackData) -> void:
	if skill.projectile_texture == null:
		return  # nothing to shoot — misconfigured ranged skill
	var proj := PROJECTILE.instantiate()
	proj.configure(self, _facing, skill.damage, skill.knockback, skill.knockback_up_ratio,
			skill.projectile_speed, skill.projectile_range, skill.projectile_lifetime,
			skill.projectile_texture, skill.projectile_height, skill.projectile_faces_right)
	get_tree().current_scene.add_child(proj)
	var off := skill.projectile_spawn_offset
	proj.global_position = global_position + Vector2(_facing * off.x, off.y)


## Receive a hit: add damage % and get launched away. The attack supplies its own
## knockback and up-ratio; the victim's low health amplifies it.
func take_hit(damage: float, base_knockback: float, dir: float, up_ratio: float) -> void:
	if _invincible_time_left > 0.0:
		return  # just respawned — immune for now
	# Defense (0–10) mitigates incoming %: 0 = full damage, 10 = halved.
	var mitigation := clampf(hero.defense, 0.0, 10.0) / 20.0
	damage_taken += damage * (1.0 - mitigation)
	# Freeze briefly and cancel any dash so the knockback isn't fought.
	_stun_time_left = hit_stun
	_dash_time_left = 0.0
	# Knockback rises with the damage % shown in the HUD: ×(1 + %/100).
	var percent_factor := 1.0 + (damage_taken / 100.0) * hero.knockback_percent_scale
	var force := base_knockback * percent_factor
	# Mostly horizontal push, with a small upward component.
	velocity = Vector2(dir * force, -force * up_ratio)


## Return to the spawn point and reset state (after a ring-out, if lives remain).
func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	damage_taken = 0.0
	_jumps_left = hero.max_jumps
	_dash_time_left = 0.0
	_attack_time_left = 0.0
	_dash_cooldown_left = 0.0
	_attack_cooldown_left = 0.0
	_attack2_cooldown_left = 0.0
	_attack_lock_left = 0.0
	_stun_time_left = 0.0
	_invincible_time_left = respawn_invincibility
	_show_idle()


## Out of lives: leave the match (hidden and parked off-screen).
func eliminate() -> void:
	hide()
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)


## Show the normal (idle) appearance.
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


## Play the walk-cycle sheet, advancing the frame over time.
func _show_walk(delta: float) -> void:
	if _pose != "walk":
		_pose = "walk"
		_anim_time = 0.0
		_sprite.texture = hero.walk_texture
		_sprite.hframes = maxi(1, hero.walk_hframes)
		_sprite.vframes = maxi(1, hero.walk_vframes)
		# Scale by a single frame's height so it matches the idle on-screen size.
		var frame_h := hero.walk_texture.get_height() / float(_sprite.vframes)
		if frame_h > 0.0:
			var s := hero.walk_sprite_height / frame_h
			_sprite.scale = Vector2(s, s)
		_art_faces_right = hero.walk_faces_right
		_sprite.visible = true
		_visual.visible = false
	_anim_time += delta
	var count := hero.walk_frames if hero.walk_frames > 0 else _sprite.hframes * _sprite.vframes
	if count > 0:
		_sprite.frame = int(_anim_time * hero.walk_fps) % count


## Swap the sprite to a single-frame `tex`, scaled to hero.sprite_height.
func _show_texture(tex: Texture2D, faces_right: bool) -> void:
	_sprite.texture = tex
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	var h := tex.get_height()
	if h > 0:
		var s := hero.sprite_height / h
		_sprite.scale = Vector2(s, s)
	_art_faces_right = faces_right
	_sprite.visible = true
	_visual.visible = false
