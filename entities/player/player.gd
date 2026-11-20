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
const INPUT_BUFFER := 0.15
## How long a tap of "down" lets the fighter fall through a platform.
const DROP_TIME := 0.24
## Damage % from which a fighter visibly smoulders: one more good hit will send
## them a long way.
const DANGER_PERCENT := 100.0
## A fighter who reaches the stage's side wall with its feet no more than this
## far below the ledge is pulled up onto it, so a recovery that just falls short
## still makes it.
const LEDGE_HELP := 40.0
## Once an attack has landed, the attacker may cut the rest of it short with a
## jump, a dash or the other attack. This short wait lets the contact pose read.
const HIT_CANCEL_DELAY := 0.04
## Share of the floor's grip a grounded melee attack keeps, so a run-up carries
## into the swing instead of stopping dead.
const ATTACK_GRIP := 0.5
## The step forward a grounded melee attack takes as its hit comes out, in
## pixels/second. The floor's grip stops it within a few dozen pixels.
const LIGHT_LUNGE := 220.0
const HEAVY_LUNGE := 330.0
## Share of normal air steering available while attacking in the air.
const AIR_ATTACK_CONTROL := 0.75
## A melee hitbox starts this far behind the attacker's centre, so a rival
## standing inside the attacker is hit instead of being swung past.
const MELEE_BACK_REACH := 22.0
## A grounded attack stops this far short of a ledge instead of sliding off it.
const LEDGE_STOP := 10.0
## Stick or key tilt past which a side counts as held when an attack is aimed.
const AIM_DEADZONE := 0.3
## Stone thrown up where a heavy blow breaks the floor.
const DEBRIS := Color(0.34, 0.32, 0.36, 0.95)
## Sparks struck off steel.
const GOLD := Color(1.0, 0.8, 0.3)
## The little hop a dive takes off a fighter it hits in mid-air, px/s.
const DIVE_BOUNCE := 230.0
## How much quicker than their tuned numbers fighters jump and fall. Take-off
## speed is multiplied by this and gravity by its square, so every jump reaches
## the height it always did in less time (1.25 = four fifths of the time). A
## launched fighter in hit stun keeps its own tuned gravity, so how far a hit
## sends someone is unchanged.
const JUMP_PACE := 1.25
const BUFFERED_ACTIONS := ["jump", "dash", "attack", "attack2"]

enum FighterState { FREE, DASHING, DODGING, ATTACKING, END_LAG, HIT_STUN, FROZEN, ELIMINATED }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY, DIVE }

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
@export var hit_stun: float = 0.22
## Extra stun per unit of launch speed, so a big launch cannot be braked at once.
@export var hit_stun_per_knockback: float = 0.00025
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
var _attack_is_heavy: bool = false
## True once the current attack has hit someone: it can then be cut short, and
## it ends without the end lag a miss would cost.
var _attack_connected: bool = false
var _cancel_delay_left: float = 0.0
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
		if _state != FighterState.HIT_STUN:
			fall *= JUMP_PACE * JUMP_PACE
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
	elif can_cancel() and _has_ready_action():
		# A landed hit hands control back early: the buffered action cuts the
		# attack short, turning to face the held direction first.
		_finish_attack()
		direction = input.axis
		face(direction)
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


## True while an attack is coming out or its hit is live, not while it recovers
## or plunges.
func is_striking() -> bool:
	return _state == FighterState.ATTACKING \
			and (_attack_phase == AttackPhase.STARTUP or _attack_phase == AttackPhase.ACTIVE)


## True while a dive is plunging.
func is_diving() -> bool:
	return _state == FighterState.ATTACKING and _attack_phase == AttackPhase.DIVE


## True for the whole of a dive attack, from its turn to its recovery.
func is_dive_attack() -> bool:
	return _state == FighterState.ATTACKING and _attack_skill != null and _attack_skill.dive_speed > 0.0


## True while a landed hit lets the fighter cut its attack short with a jump, a
## dash or its other attack.
func can_cancel() -> bool:
	return _state == FighterState.ATTACKING and _attack_connected and _cancel_delay_left == 0.0


## True when the given skill could start right now, from a free stance or by
## cutting short an attack that has landed.
func can_use(skill: AttackData, is_heavy: bool) -> bool:
	if skill == null or not (_state == FighterState.FREE or can_cancel()):
		return false
	return _skill_ready(is_heavy)


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
	_cancel_delay_left = maxf(0.0, _cancel_delay_left - delta)
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
		velocity.y = hero.jump_velocity * JUMP_PACE
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
	if _wants("dash") and _dash_ready(direction):
		_consume("dash")
		_start_dash_or_dodge(direction)
	elif not jumped and _wants("attack"):
		if _use_heavy():
			_consume("attack")
	elif not jumped and _wants("attack2"):
		if _try_attack(false):
			_consume("attack2")


## True when a buffered press could be acted on this tick. An attack that has
## landed is only cut short when this says something will actually come out.
func _has_ready_action() -> bool:
	if _wants("jump") and _jumps_left > 0:
		return true
	if _wants("dash") and _dash_ready(input.axis):
		return true
	if _wants("attack") and (_can_attack(true) or (not is_on_floor() and _air_attack_jumps_left > 0)):
		return true
	return _wants("attack2") and _can_attack(false)


## A dash needs a direction; without one the press is a dodge, which has its
## own, longer cooldown.
func _dash_ready(direction: float) -> bool:
	if _dash_cooldown_left > 0.0:
		return false
	var dodge := direction == 0.0 and hero.dodge_duration > 0.0
	return not dodge or _dodge_cooldown_left == 0.0


func _skill_ready(is_heavy: bool) -> bool:
	if _attack_lock_left > 0.0:
		return false
	return (_heavy_cooldown_left if is_heavy else _light_cooldown_left) == 0.0


## Where a press of an attack button is aimed right now. In the air there is
## one attack per button, and down held turns the heavy one into the dive. On
## the ground, holding down gives the low attack, holding a side the side
## attack, and standing still the one aimed upward.
func get_aim() -> HeroData.Aim:
	if not is_on_floor():
		return HeroData.Aim.DIVE if input.down else HeroData.Aim.AIR
	if input.down:
		return HeroData.Aim.DOWN
	if absf(input.axis) > AIM_DEADZONE:
		return HeroData.Aim.SIDE
	return HeroData.Aim.UP


## The skill a button would start right now.
func aimed_skill(is_heavy: bool) -> AttackData:
	return hero.attack_for(is_heavy, get_aim())


func _can_attack(is_heavy: bool) -> bool:
	var skill := aimed_skill(is_heavy)
	return skill != null and _skill_ready(is_heavy) and (is_on_floor() or _can_cast_in_air(skill))


func _try_attack(is_heavy: bool) -> bool:
	if not _can_attack(is_heavy):
		return false
	return _begin_attack(aimed_skill(is_heavy), is_heavy)


## The heavy key. On the ground it is the heavy attack. In the air it is the
## rising heavy: the same attack carried upward by an extra jump, once per
## airtime. With the rise spent, or the skill not ready, whichever half is
## left still comes out.
func _use_heavy() -> bool:
	# On the floor it is the heavy attack; with down held in the air, the dive,
	# which goes down and so never takes the rise.
	if is_on_floor() or get_aim() == HeroData.Aim.DIVE:
		return _try_attack(true)
	var rising := _air_attack_jumps_left > 0
	var struck := _try_attack(true)
	if rising:
		velocity.y = hero.jump_velocity * JUMP_PACE
		_air_attack_jumps_left -= 1
		Fx.burst(get_feet(), Color(1, 1, 1, 0.7), 6, 160.0, Vector2.DOWN, 60.0, 0.3, 4.0, 0.0)
		Sfx.play("double_jump", -6.0, 1.15)
	return rising or struck


## Skills that need a floor cannot start in mid-air: a wave that runs along the
## ground, or an eruption with no ground under the point it would rise from.
func _can_cast_in_air(skill: AttackData) -> bool:
	match skill.kind:
		AttackData.Kind.RANGED:
			return not skill.projectile_grounded
		AttackData.Kind.GROUND_SPIKE:
			return not is_nan(_spike_floor(skill))
	return true


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
		FighterState.ATTACKING, FighterState.END_LAG:
			if is_on_floor():
				var grip := hero.ground_acceleration
				if _attack_skill != null and _attack_skill.kind == AttackData.Kind.MELEE:
					grip *= ATTACK_GRIP
				velocity.x = move_toward(velocity.x, 0.0, grip * delta)
				# The slide and the step of an attack never carry a fighter off a ledge.
				if velocity.x != 0.0 and not _floor_ahead(signf(velocity.x)):
					velocity.x = 0.0
			elif input.axis != 0.0:
				# In the air an attack can still be steered, a little less freely.
				velocity.x = move_toward(velocity.x, input.axis * hero.speed,
						hero.air_acceleration * AIR_ATTACK_CONTROL * delta)
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


## True when there is floor to stand on a step to `side` (±1) of the fighter.
func _floor_ahead(side: float) -> bool:
	var feet := get_feet()
	var from := Vector2(feet.x + side * LEDGE_STOP, feet.y - 8.0)
	var ray := PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, 24.0), SOLID_MASK | PLATFORM_MASK)
	ray.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


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
	elif (_state == FighterState.HIT_STUN and velocity.length() > 460.0) or is_diving():
		_trail_time_left = 0.03
		Fx.trail(global_position, Color(0.95, 0.93, 0.9, 0.55))
	# Past the danger line a fighter gives off wisps of steam, more the higher it climbs.
	_steam_time_left -= delta
	if damage_taken >= DANGER_PERCENT and _steam_time_left <= 0.0 and visible:
		_steam_time_left = lerpf(0.34, 0.12, clampf((damage_taken - DANGER_PERCENT) / 120.0, 0.0, 1.0))
		Fx.burst(global_position + Vector2(randf_range(-16.0, 16.0), -visuals.ground_offset * 0.7),
				Color(1.0, 0.82, 0.78, 0.5), 1, 46.0, Vector2.UP, 24.0, 0.5, 5.0, -90.0)


# --- Attacks --------------------------------------------------------------------

## The fighters inside a melee skill's hitbox right now.
func _melee_targets(skill: AttackData) -> Array[Node]:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(1.0, skill.reach + MELEE_BACK_REACH), maxf(1.0, skill.height))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(
			_facing * ((skill.reach - MELEE_BACK_REACH) * 0.5 + skill.hitbox_offset.x), skill.hitbox_offset.y))
	query.collision_mask = 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var found: Array[Node] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var other: Node = hit.get("collider")
		if other != null and other.is_in_group("players") and other.has_method("take_hit"):
			found.append(other)
	return found


## Starts one attack transaction. The state guard makes this safe even if multiple
## callers request attacks in the same frame.
func _begin_attack(skill: AttackData, is_heavy: bool) -> bool:
	if _state != FighterState.FREE or skill == null:
		return false
	_state = FighterState.ATTACKING
	_attack_skill = skill
	_attack_is_heavy = is_heavy
	_attack_connected = false
	_cancel_delay_left = 0.0
	_attack_hit_targets.clear()
	_attack_lock_left = hero.min_attack_interval
	# A run-up carries into the attack, but never faster than a run: a dash
	# does not turn into a long slide.
	if is_on_floor():
		velocity.x = clampf(velocity.x, -hero.speed, hero.speed)
	elif skill.dive_speed > 0.0:
		# A dive hangs for a moment as it turns over, then plunges.
		velocity = Vector2(velocity.x * 0.4, minf(velocity.y, 0.0) * 0.3)
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
	elif _state == FighterState.ATTACKING and _attack_phase == AttackPhase.DIVE:
		_tick_dive()


## A dive plunges for as long as its button is held. It ends in its hit where it
## reaches the floor or another fighter, and without one when the button is let go.
func _tick_dive() -> void:
	if is_on_floor():
		_set_attack_phase(AttackPhase.ACTIVE)
	elif not _melee_targets(_attack_skill).is_empty():
		velocity.y = -DIVE_BOUNCE
		_set_attack_phase(AttackPhase.ACTIVE)
	elif not input.heavy_held:
		_set_attack_phase(AttackPhase.RECOVERY)
	else:
		velocity.y = maxf(velocity.y, _attack_skill.dive_speed)


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
					_lunge()
					if _attack_skill.lift > 0.0:
						velocity.y = minf(velocity.y, -_attack_skill.lift * JUMP_PACE)
					_melee_hit(_attack_skill)
					_spawn_melee_effect(_attack_skill)
					_spawn_flourish(_attack_skill)
		AttackPhase.RECOVERY:
			_attack_phase_time_left = _attack_skill.recovery_time
		AttackPhase.DIVE:
			_attack_phase_time_left = INF      # until _tick_dive ends it


func _advance_attack_phase() -> void:
	match _attack_phase:
		AttackPhase.STARTUP:
			var dives := _attack_skill.dive_speed > 0.0 and not is_on_floor()
			_set_attack_phase(AttackPhase.DIVE if dives else AttackPhase.ACTIVE)
		AttackPhase.ACTIVE:
			_set_attack_phase(AttackPhase.RECOVERY)
		AttackPhase.RECOVERY:
			_finish_attack(true)


## Ends the attack. Only a miss pays the end lag: an attack that landed hands
## control straight back.
func _finish_attack(apply_end_lag: bool = false) -> void:
	var end_lag := _attack_skill.post_end_lag if _attack_skill != null else 0.0
	if _attack_connected:
		end_lag = 0.0
	_attack_connected = false
	_cancel_delay_left = 0.0
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


## The step forward a grounded melee attack takes as its hit comes out. A
## run-up that is already faster is kept.
func _lunge() -> void:
	if not is_on_floor():
		return
	var step := HEAVY_LUNGE if _attack_is_heavy else LIGHT_LUNGE
	if _attack_skill != null and _attack_skill.lunge >= 0.0:
		step = _attack_skill.lunge
	velocity.x = _facing * maxf(velocity.x * _facing, step)


## Query actual physics hurtboxes in front of the fighter. Repeating this during
## the active phase allows a moving target to enter the hitbox, while the target
## dictionary guarantees at most one hit per attack. The box starts a little
## behind the attacker's centre (see MELEE_BACK_REACH).
func _melee_hit(skill: AttackData) -> void:
	for other: Node in _melee_targets(skill):
		var target_id := other.get_instance_id()
		if _attack_hit_targets.has(target_id):
			continue
		if other.take_hit(skill.damage, skill.knockback, _facing, skill.knockback_up_ratio, self, false,
				ToonEffect.sound_kind(skill.effect) if skill.effect != "" else hero.weapon_sound,
				skill.knockback_forward):
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
	var center := global_position + Vector2(
			_facing * (skill.reach * 0.55 + skill.hitbox_offset.x), skill.hitbox_offset.y)
	burst.position = center + (Vector2(0.0, skill.height * 0.5) if burst.grounded else Vector2.ZERO)
	get_parent().add_child(burst)
	var life := skill.active_time + 0.22
	var tween := burst.create_tween()
	tween.tween_method(burst.set_grow, 0.2, 1.0, minf(0.08, skill.active_time))
	tween.tween_interval(maxf(0.0, skill.active_time - 0.08))
	tween.tween_method(burst.set_fade, 1.0, 0.0, 0.22)
	tween.tween_callback(burst.queue_free)
	Sfx.play(_cast_sound(skill), -6.0)


## What a melee attack throws out as its hit comes out: dust behind a lunging
## step, and the skill's own flourish (see AttackData.flourish).
func _spawn_flourish(skill: AttackData) -> void:
	var feet := get_feet()
	var tint := Roster.accent_of(hero)
	var accent := tint.lerp(Color.WHITE, 0.6)
	# Where the blade swings from: about the shoulder.
	var chest := global_position + Vector2(_facing * 8.0, -16.0)
	if is_on_floor() and absf(velocity.x) > 140.0:
		Fx.dust(feet, -_facing, 3, 130.0)
	match skill.flourish:
		"thrust":
			var from := global_position + Vector2(_facing * 18.0, skill.hitbox_offset.y - 6.0)
			Fx.streak(from, from + Vector2(_facing * (skill.reach + 46.0), 0.0), accent, 12.0, 0.2)
			Fx.burst(from, Color(1.0, 1.0, 1.0, 0.8), 8, 820.0, Vector2(_facing, 0.0), 5.0, 0.2, 3.0, 0.0)
		"flash":
			# A level cut seen from the side: one flat crescent out in front.
			Fx.crescent(chest + Vector2(_facing * skill.reach * 0.35, 6.0), _facing, skill.reach * 0.78,
					150.0, -150.0, tint, 30.0, 0.34, 0.3)
			Fx.petals(chest + Vector2(_facing * skill.reach * 0.6, 0.0), tint, 12, Vector2(-_facing, -0.5))
		"slam":
			var at := feet + Vector2(_facing * skill.reach * 0.8, 0.0)
			Fx.dust(at, 0.0, 7, 250.0)
			Fx.burst(at, accent, 10, 430.0, Vector2.UP, 48.0, 0.32, 4.0)
			Fx.streak(at - Vector2(_facing * 46.0, 2.0), at + Vector2(_facing * 58.0, -2.0), Color.WHITE, 9.0, 0.22)
			Fx.shake(0.3)
			# The cut coming down over her head, and the shock running out along the floor.
			Fx.crescent(chest, _facing, skill.reach * 0.9, -140.0, 78.0, tint, 30.0, 0.34)
			Fx.ring(at, skill.reach * 0.8, accent, 0.4, 0.28)
			Fx.petals(at, tint, 14, Vector2.UP)
		"rise":
			Fx.dust(feet, 0.0, 5, 170.0)
			Fx.streak(feet + Vector2(_facing * 26.0, 0.0),
					feet + Vector2(_facing * 34.0, -skill.height - 24.0), accent, 12.0, 0.22)
			Fx.burst(feet, Color(1.0, 1.0, 1.0, 0.8), 8, 560.0, Vector2.UP, 12.0, 0.26, 3.2, 0.0)
			# The rising cut: a tall crescent up the front of her.
			Fx.crescent(chest, _facing, skill.height * 0.72, 120.0, -150.0, tint, 32.0, 0.36)
			Fx.petals(chest + Vector2(_facing * 30.0, -30.0), tint, 14, Vector2(_facing * 0.3, -1.0))
		"dive":
			# Where a plunge arrives the cut goes straight down, never out to the
			# side: a line from the chest to below the feet, a crescent bowed
			# under them, and on the floor the shock of it.
			# It is the fighter's biggest single cut, so it is drawn big: a tall
			# blade of light from well above the head to below the feet, white-hot
			# down its middle, with a thin line each side of it.
			var top := global_position + Vector2(_facing * 10.0, -165.0)
			var bottom := feet + Vector2(_facing * 10.0, 52.0)
			Fx.streak(top, bottom, accent, 40.0, 0.36)
			Fx.streak(top + Vector2(0.0, 24.0), bottom + Vector2(0.0, 16.0), Color.WHITE, 16.0, 0.3)
			for side: float in [-1.0, 1.0]:
				Fx.streak(top + Vector2(side * 26.0, 52.0), bottom + Vector2(side * 26.0, -12.0), tint, 6.0, 0.26)
			Fx.crescent(global_position + Vector2(_facing * 6.0, -62.0), _facing, 134.0,
					46.0, 134.0, tint, 46.0, 0.44)
			if is_on_floor():
				Fx.dust(feet, 0.0, 14, 380.0)
				Fx.ring(feet, 150.0, accent, 0.5, 0.26)
				Fx.ring(feet, 92.0, Color.WHITE, 0.36, 0.26)
				Fx.burst(feet, accent, 16, 520.0, Vector2.UP, 62.0, 0.42, 5.0)
				Fx.shake(0.65)
			Fx.petals(feet, tint, 22, Vector2.UP)
		"lance":
			# A thrust the length of a jousting lance: one straight beam, and a
			# spray of rays and sparks off its point.
			var from := global_position + Vector2(_facing * 20.0, skill.hitbox_offset.y)
			var point := from + Vector2(_facing * (skill.reach + 70.0), 0.0)
			Fx.streak(from, point, accent, 18.0, 0.3)
			Fx.streak(from + Vector2(_facing * 30.0, 0.0), point + Vector2(_facing * 26.0, 0.0), Color.WHITE, 7.0, 0.24)
			Fx.rays(point - Vector2(_facing * 34.0, 0.0), tint, 5, 86.0, -24.0, 24.0, 9.0, 0.3, 1.0, _facing)
			Fx.burst(point, GOLD, 16, 760.0, Vector2(_facing, -0.1), 20.0, 0.36, 3.4)
		"crown":
			# An uppercut: a crown of spikes of light over the fist.
			var fist := global_position + Vector2(_facing * 26.0, -58.0)
			Fx.rays(fist, tint, 7, 150.0, -150.0, -30.0, 13.0, 0.36)
			Fx.rays(fist, GOLD, 7, 84.0, -150.0, -30.0, 6.0, 0.26)
			Fx.burst(fist, GOLD, 18, 640.0, Vector2.UP, 46.0, 0.5, 3.6)
		"sunburst":
			# A sword planted in the ground: half a sun standing on the floor round
			# the blade, and the shock running out along it.
			var planted := feet + Vector2(_facing * 22.0, 0.0)
			Fx.rays(planted, tint, 13, 190.0, -176.0, -4.0, 13.0, 0.42)
			Fx.rays(planted, GOLD, 13, 104.0, -176.0, -4.0, 6.0, 0.3)
			Fx.ring(planted, 170.0, accent, 0.5, 0.24)
			Fx.dust(planted, 0.0, 12, 380.0)
			Fx.burst(planted, GOLD, 22, 700.0, Vector2.UP, 70.0, 0.6, 3.6)
			Fx.shake(0.7)
		"hammer":
			# A hammer blow in the air: rays and sparks driven straight down.
			var head := global_position + Vector2(_facing * 44.0, 34.0)
			Fx.rays(head, tint, 5, 150.0, 58.0, 122.0, 12.0, 0.32)
			Fx.streak(head - Vector2(0.0, 96.0), head + Vector2(0.0, 30.0), Color.WHITE, 12.0, 0.2)
			Fx.burst(head, GOLD, 20, 820.0, Vector2.DOWN, 34.0, 0.4, 3.6)
		"tread":
			# A stomp from the air: on the floor a star of cracks lying under the
			# boot and stone thrown up; on a fighter, rays driven down onto them.
			var boot := feet + Vector2(_facing * 6.0, 0.0)
			if is_on_floor():
				Fx.rays(boot, Color.WHITE, 12, 190.0, 0.0, 330.0, 9.0, 0.5, 0.26)
				Fx.rays(boot, tint, 6, 110.0, -160.0, -20.0, 11.0, 0.34)
				Fx.dust(boot, 0.0, 16, 430.0)
				Fx.burst(boot, DEBRIS, 22, 700.0, Vector2.UP, 62.0, 0.62, 6.0)
				Fx.shake(0.8)
			else:
				Fx.rays(boot, tint, 6, 130.0, 20.0, 160.0, 11.0, 0.34)
			Fx.burst(boot, GOLD, 14, 560.0, Vector2.UP, 60.0, 0.5, 3.4)
		"moon":
			# A full turn of the blade: a ring of light with a crescent riding on it.
			Fx.crescent(chest, _facing, skill.height * 0.62, 150.0, -210.0, tint, 30.0, 0.4)
			Fx.ring(chest, skill.height * 0.7, accent, 0.42)
			Fx.petals(chest, tint, 16, Vector2.UP)
		"sweep":
			Fx.dust(feet + Vector2(_facing * 30.0, 0.0), _facing, 8, 300.0)
			Fx.streak(feet + Vector2(_facing * 8.0, -8.0),
					feet + Vector2(_facing * (skill.reach + 10.0), -8.0), accent, 8.0, 0.18)


## Casts a delayed hazard at a fixed distance and snaps it to the first arena
## surface below that target point. A fallback keeps the move usable in test or
## custom scenes that do not provide floor collision on layer 1.
func _spawn_ground_spike(skill: AttackData) -> void:
	if skill.ground_spike_texture == null and not ToonEffect.has_preset(skill.effect):
		push_warning("%s is a ground-spike attack but has no effect art." % skill.skill_name)
		return
	var target_x := global_position.x + _facing * skill.ground_spike_distance
	var floor_y := _spike_floor(skill)
	if is_nan(floor_y):
		floor_y = global_position.y + 50.0

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


## The first arena surface under the point a ground spike would erupt from, or
## NAN when there is none.
func _spike_floor(skill: AttackData) -> float:
	var target_x := global_position.x + _facing * skill.ground_spike_distance
	var ray := PhysicsRayQueryParameters2D.create(Vector2(target_x, global_position.y - 180.0),
			Vector2(target_x, global_position.y + 900.0), SOLID_MASK | PLATFORM_MASK)
	ray.exclude = [get_rid()]
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return NAN if floor_hit.is_empty() else (floor_hit.position as Vector2).y


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
## `forward` is the sideways share of the force (see AttackData.knockback_forward).
func take_hit(damage: float, base_knockback: float, dir: float, up_ratio: float,
		attacker: Node = null, from_projectile: bool = false, sound: String = "",
		forward: float = 1.0) -> bool:
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
	velocity = Vector2(dir * force * forward, -force * up_ratio)
	visuals.on_hit()

	var spark := get_player_color()
	if attacker != null:
		last_attacker = attacker
		last_hit_ms = Time.get_ticks_msec()
		var foe := attacker as Fighter
		if foe != null:
			foe.damage_dealt += dealt
			foe.note_hit_landed()
			spark = Roster.accent_of(foe.hero)
	Fx.hit(self, dir, dealt, force, spark, from_projectile, sound)
	return true


## One of this fighter's attacks was accepted by a rival (a swing, or a
## projectile or eruption arriving later). The attack in progress can now be cut
## short and will not pay its end lag; end lag already being served is waived.
func note_hit_landed() -> void:
	_attack_lock_left = 0.0
	if _state == FighterState.ATTACKING and _attack_phase != AttackPhase.STARTUP:
		if not _attack_connected:
			_attack_connected = true
			_cancel_delay_left = HIT_CANCEL_DELAY
	elif _state == FighterState.END_LAG:
		_state = FighterState.FREE
		_state_time_left = 0.0


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
