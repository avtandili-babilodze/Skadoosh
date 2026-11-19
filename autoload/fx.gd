extends Node
## Game feel in one place (autoloaded as "Fx"): hit-stop, camera shake, sparks,
## dust and knock-out blasts.
##
## Gameplay code reports what happened (a hit landed, a fighter touched down)
## and this service decides how that looks and sounds. It only acts while an
## arena has registered itself, so fighters used in tests or menus stay quiet
## and never touch the global time scale.

const IMPACT := preload("res://entities/fx/impact.gd")
const KO_BLAST := preload("res://entities/fx/ko_blast.gd")
const GHOST := preload("res://entities/fx/ghost.gd")
const DAMAGE_NUMBER := preload("res://entities/fx/damage_number.gd")

## Time scale while a hit is frozen. Not zero: a few engine paths divide by it.
const STOP_SCALE := 0.02
const DUST_COLOR := Color(0.93, 0.9, 0.86, 0.75)

## World-space parent for effects, set by the arena while a match is running.
var layer: Node2D = null
## The arena camera (anything with add_trauma), set by the arena.
var camera: Node = null

var _stop_until_ms: int = 0
var _slow_until_ms: int = 0
var _slow_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _stop_until_ms == 0 and _slow_until_ms == 0:
		return
	var now := Time.get_ticks_msec()
	if _slow_until_ms != 0 and now >= _slow_until_ms:
		_slow_until_ms = 0
		_slow_scale = 1.0
	if _stop_until_ms != 0 and now >= _stop_until_ms:
		_stop_until_ms = 0
	if _stop_until_ms == 0:
		Engine.time_scale = _slow_scale


func is_active() -> bool:
	return layer != null and is_instance_valid(layer)


## Called by the arena when a match starts and ends.
func bind(effects_layer: Node2D, arena_camera: Node) -> void:
	layer = effects_layer
	camera = arena_camera
	_clear_time()


func unbind() -> void:
	layer = null
	camera = null
	_clear_time()


func _clear_time() -> void:
	_stop_until_ms = 0
	_slow_until_ms = 0
	_slow_scale = 1.0
	Engine.time_scale = 1.0


# --- Time ---------------------------------------------------------------------

## Freezes the action for a moment so a hit reads as an impact.
func hit_stop(seconds: float) -> void:
	if not is_active() or seconds <= 0.0:
		return
	_stop_until_ms = maxi(_stop_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = STOP_SCALE


## Runs the game slowly for `seconds` of real time (the final knock-out).
func slow_motion(scale: float, seconds: float) -> void:
	if not is_active():
		return
	_slow_scale = scale
	_slow_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	if _stop_until_ms == 0:
		Engine.time_scale = scale


func shake(amount: float) -> void:
	if is_active() and camera != null and Settings.screen_shake:
		camera.add_trauma(amount)


# --- Events -------------------------------------------------------------------

## A hit was accepted. `force` is the final knockback speed, `dir` the side it
## launches toward, `color` the attacker's accent.
func hit(victim: Node2D, dir: float, damage: float, force: float, color: Color,
		projectile: bool = false, sound: String = "") -> void:
	if not is_active():
		return
	var power := clampf(force / 950.0, 0.12, 1.0)
	var at := victim.global_position + Vector2(-dir * 16.0, -10.0)
	var star := IMPACT.new()
	star.setup(color, lerpf(26.0, 74.0, power), dir)
	_add(star, at)
	burst(at, color.lerp(Color.WHITE, 0.45), int(lerpf(6.0, 20.0, power)),
			lerpf(260.0, 760.0, power), Vector2(dir, -0.35), 55.0, 0.34)
	var number := DAMAGE_NUMBER.new()
	number.setup(damage, color, dir)
	_add(number, victim.global_position + Vector2(randf_range(-10.0, 10.0), -78.0))
	hit_stop(lerpf(0.045, 0.15, power))
	shake(lerpf(0.16, 0.8, power))
	var heavy := damage >= 10.0 or power > 0.62
	if sound in ["fire", "water", "magic"]:
		Sfx.play("hit_" + sound, 0.0, lerpf(1.1, 0.88, power))
		# A strong elemental hit still lands with weight underneath.
		if heavy:
			Sfx.play("hit_heavy", -6.0, 0.9)
	elif sound == "blade":
		Sfx.play("hit_blade_heavy" if heavy else "hit_blade_light", 0.0, lerpf(1.08, 0.92, power))
	elif projectile:
		Sfx.play("hit_magic", -1.0, lerpf(1.1, 0.88, power))
	else:
		Sfx.play("hit_heavy" if heavy else "hit_light", 0.0, lerpf(1.1, 0.9, power))


## A fighter crossed the blast line at `at`, travelling along `direction`.
func knock_out(at: Vector2, direction: Vector2, color: Color) -> void:
	if not is_active():
		return
	var blast := KO_BLAST.new()
	blast.setup(color, -direction)
	_add(blast, at)
	burst(at, color.lerp(Color.WHITE, 0.3), 42, 980.0, -direction, 38.0, 0.7, 7.0)
	shake(1.0)
	Sfx.play("ko", 2.0, 1.0, 0.03)


## Floor dust kicked out to one side (dir = ±1) or both (dir = 0).
func dust(feet: Vector2, dir: float, count: int = 5, speed: float = 120.0) -> void:
	if not is_active():
		return
	var sides: Array[float] = [-1.0, 1.0]
	if dir != 0.0:
		sides = [signf(dir)]
	for side in sides:
		burst(feet, DUST_COLOR, count, speed, Vector2(side, -0.28), 26.0, 0.36, 5.0, 0.0)


## A single smoke puff left behind a launched fighter.
func trail(at: Vector2, color: Color) -> void:
	if not is_active():
		return
	burst(at, color, 2, 40.0, Vector2.UP, 180.0, 0.4, 7.0, -60.0)


## A fading copy of a sprite, left behind by dashes and dodges.
func ghost(sprite: Sprite2D, color: Color) -> void:
	if not is_active() or sprite == null or sprite.texture == null:
		return
	var copy := GHOST.new()
	copy.setup(sprite, color)
	layer.add_child(copy)


## A fading copy of any drawing (a rig's snapshot), placed at `where`.
func ghost_node(copy: Node2D, where: Transform2D, color: Color) -> void:
	if copy == null:
		return
	if not is_active():
		copy.queue_free()
		return
	copy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	copy.z_index = -1
	layer.add_child(copy)
	copy.global_transform = where
	copy.modulate = Color(color, 0.5)
	var fade := copy.create_tween()
	fade.tween_property(copy, "modulate:a", 0.0, 0.22)
	fade.tween_callback(copy.queue_free)


## Square pixel particles thrown along `direction` within `spread` degrees.
func burst(at: Vector2, color: Color, count: int, speed: float, direction: Vector2,
		spread: float, lifetime: float, size: float = 4.5, gravity: float = 900.0) -> void:
	if not is_active() or count <= 0:
		return
	var particles := CPUParticles2D.new()
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = lifetime
	particles.direction = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.35
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 1.2
	particles.damping_max = speed * 2.2
	particles.gravity = Vector2(0.0, gravity)
	particles.scale_amount_min = size * 0.55
	particles.scale_amount_max = size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.65, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = shrink
	particles.color = color
	particles.finished.connect(particles.queue_free)
	_add(particles, at)


func _add(node: Node2D, at: Vector2) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	layer.add_child(node)
	node.global_position = at
