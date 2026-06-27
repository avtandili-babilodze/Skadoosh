extends CharacterBody2D
## A player-controlled fighter.
##
## Stats (speed, jump, attack, ...) come from an assigned HeroData resource.
## Controls come from an input "profile" — the action names mapped to this
## player's keys. The same scene is reused for every player; only the `hero`
## and the action names differ.

## The hero this player is currently playing. Assigned per-player in the arena.
@export var hero: HeroData

@export_group("Controls")
@export var action_left: StringName = "p1_left"
@export var action_right: StringName = "p1_right"
@export var action_jump: StringName = "p1_jump"
@export var action_down: StringName = "p1_down"
@export var action_dash: StringName = "p1_dash"
@export var action_attack: StringName = "p1_attack"

@export_group("Rules")
## Seconds of invincibility after respawning (can't be hit during this window).
@export var respawn_invincibility: float = 3.0

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
var _art_faces_right: bool = true     # drawn facing of whatever texture is shown


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

	# Respawn invincibility: count down and blink the fighter while active.
	if _invincible_time_left > 0.0:
		_invincible_time_left = maxf(0.0, _invincible_time_left - delta)
		modulate.a = 0.35 if int(_invincible_time_left * 10.0) % 2 == 0 else 1.0
		if _invincible_time_left == 0.0:
			modulate.a = 1.0

	if _attack_time_left > 0.0:
		_attack_time_left -= delta
		if _attack_time_left <= 0.0:
			_show_idle()  # attack finished → return to the idle pose

	# --- Gravity ---
	if not is_on_floor():
		var fall := get_gravity() * hero.gravity_scale
		if Input.is_action_pressed(action_down):
			fall *= hero.fast_fall_scale  # fast fall
		velocity += fall * delta

	# --- Jump (double / multi) ---
	if is_on_floor():
		_jumps_left = hero.max_jumps
	if Input.is_action_just_pressed(action_jump) and _jumps_left > 0:
		velocity.y = hero.jump_velocity
		_jumps_left -= 1

	# --- Facing ---
	var direction := Input.get_axis(action_left, action_right)
	if direction != 0.0:
		_facing = signf(direction)

	# --- Dash ---
	if Input.is_action_just_pressed(action_dash) and _dash_cooldown_left == 0.0:
		_dash_time_left = hero.dash_duration
		_dash_cooldown_left = hero.dash_cooldown

	# --- Attack ---
	if Input.is_action_just_pressed(action_attack) and _attack_cooldown_left == 0.0:
		_start_attack()

	# --- Horizontal velocity ---
	if _dash_time_left > 0.0:
		velocity.x = _facing * hero.dash_speed     # dash overrides movement
	elif direction != 0.0:
		velocity.x = direction * hero.speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, hero.speed)

	# Keep the avatar facing its movement direction.
	_sprite.flip_h = (_facing > 0.0) != _art_faces_right

	move_and_slide()


## Begin an attack: show the attack pose and hit anyone in range in front.
func _start_attack() -> void:
	_attack_time_left = hero.attack_duration
	_attack_cooldown_left = hero.attack_cooldown

	if hero.attack_texture != null:
		_show_texture(hero.attack_texture, hero.attack_faces_right)

	# Simple hitbox: a box in front of us. Hit every other player inside it.
	for other in get_tree().get_nodes_in_group("players"):
		if other == self:
			continue
		var offset: Vector2 = other.global_position - global_position
		var in_front := signf(offset.x) == _facing
		if in_front and absf(offset.x) <= hero.attack_range and absf(offset.y) <= hero.attack_height:
			other.take_hit(hero.attack_power, hero.knockback, _facing)


## Receive a hit: add damage % and get launched away from the attacker.
func take_hit(damage: float, base_knockback: float, dir: float) -> void:
	if _invincible_time_left > 0.0:
		return  # just respawned — immune for now
	damage_taken += damage
	# Knockback grows with accumulated damage — classic platform-fighter feel.
	var force := base_knockback * (1.0 + damage_taken / 100.0)
	# Mostly horizontal push, with a small upward component.
	velocity = Vector2(dir * force, -force * hero.knockback_up_ratio)


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
	_invincible_time_left = respawn_invincibility
	_show_idle()


## Out of lives: leave the match (hidden and parked off-screen).
func eliminate() -> void:
	hide()
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)


## Show the normal (idle) appearance.
func _show_idle() -> void:
	if hero.texture != null:
		_show_texture(hero.texture, hero.faces_right)
	else:
		_visual.color = hero.color
		_visual.visible = true
		_sprite.visible = false


## Swap the sprite to `tex`, scaled to hero.sprite_height, remembering its facing.
func _show_texture(tex: Texture2D, faces_right: bool) -> void:
	_sprite.texture = tex
	var h := tex.get_height()
	if h > 0:
		var s := hero.sprite_height / h
		_sprite.scale = Vector2(s, s)
	_art_faces_right = faces_right
	_sprite.visible = true
	_visual.visible = false
