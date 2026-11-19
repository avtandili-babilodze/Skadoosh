extends Area2D
## A generic projectile (e.g. Linea's fireball).
##
## Flies straight horizontally, hits the first opposing player it touches, then
## disappears. It's configured with explicit values via configure(), so ONE scene
## serves every ranged attack — a hero's primary fireball, a small secondary one,
## future heroes, etc.

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _knockback: float = 0.0
var _up_ratio: float = 0.18
var _dir: float = 1.0
var _life_left: float = 2.0
var _range_left: float = 0.0         # px of travel remaining (0 = unlimited)
var _travel_range: float = 0.0
var _distance_traveled: float = 0.0
var _range_expires_next_tick: bool = false
var _shooter: Node = null            # the player who fired it (never self-hit)
# Visuals — stored here and applied in _ready (configure runs before add_child).
var _texture: Texture2D = null
var _art_height: float = 70.0
var _collision_radius: float = 28.0
var _art_faces_right: bool = true
var _start_scale: float = 1.0
var _end_scale: float = 1.0
var _end_damage_multiplier: float = 1.0
var _grounded: bool = false
var _base_visual_scale: float = 1.0
var _age: float = 0.0
var _tint: Color = Color.WHITE
var _hframes: int = 1
var _vframes: int = 1
var _frame_count: int = 1
var _fps: float = 0.0
var _effect_name: String = ""
var _effect: ToonEffect = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


## Configure the projectile. Call this BEFORE add_child; the visuals are applied
## in _ready (which runs when it enters the tree).
func configure(shooter: Node, facing: float, damage: float, knockback: float, up_ratio: float,
		speed: float, travel_range: float, lifetime: float,
		texture: Texture2D, art_height: float, collision_radius: float,
		art_faces_right: bool, start_scale: float, end_scale: float,
		end_damage_multiplier: float, grounded: bool) -> void:
	_shooter = shooter
	_dir = signf(facing) if facing != 0.0 else 1.0
	_damage = damage
	_knockback = knockback
	_up_ratio = up_ratio
	_velocity = Vector2(_dir * speed, 0.0)
	_travel_range = maxf(0.0, travel_range)
	_range_left = _travel_range
	_life_left = lifetime
	_texture = texture
	_art_height = art_height
	_collision_radius = maxf(1.0, collision_radius)
	_art_faces_right = art_faces_right
	_start_scale = maxf(0.05, start_scale)
	_end_scale = maxf(0.05, end_scale)
	_end_damage_multiplier = maxf(0.0, end_damage_multiplier)
	_grounded = grounded


## Draws the projectile as a toon effect preset instead of its texture. Call
## before add_child, like configure().
func set_effect(preset: String) -> void:
	_effect_name = preset if ToonEffect.has_preset(preset) else ""


## Makes the projectile play a looping sheet instead of a still image. Call
## before add_child, like configure(). `frames` 0 plays the whole grid.
func set_animation(hframes: int, vframes: int, frames: int, fps: float) -> void:
	_hframes = maxi(1, hframes)
	_vframes = maxi(1, vframes)
	_frame_count = frames if frames > 0 else _hframes * _vframes
	_frame_count = clampi(_frame_count, 1, _hframes * _vframes)
	_fps = maxf(0.0, fps)


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		# Scene resources are shared by default. Duplicate before changing the radius
		# so differently sized projectiles cannot resize each other.
		circle = circle.duplicate()
		circle.radius = _collision_radius
		_collision_shape.shape = circle
	if _effect_name != "":
		_effect = ToonEffect.new(_effect_name, _art_height, _dir < 0.0)
		add_child(_effect)
		_sprite.visible = false
	elif _texture != null:
		_sprite.texture = _texture
		_sprite.hframes = _hframes
		_sprite.vframes = _vframes
		var h := _texture.get_height() / float(_vframes)
		if h > 0.0:
			_base_visual_scale = _art_height / h
		# Face the direction of travel.
		_sprite.flip_h = (_dir > 0.0) != _art_faces_right
	# The fighter script preloads this scene, so naming its class here would make
	# the two scripts depend on each other while loading. Ask by property instead.
	if is_instance_valid(_shooter) and "hero" in _shooter:
		_tint = Roster.accent_of(_shooter.hero)
	if Fx.is_active() and _effect == null:
		_add_trail()
	_apply_travel_progress()


## A wake of square sparks in the caster's colour, left in the world as the
## projectile flies.
func _add_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	trail.amount = 18
	trail.lifetime = 0.32
	trail.local_coords = false
	trail.direction = Vector2(-_dir, 0.0)
	trail.spread = 28.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 90.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 2.5
	trail.scale_amount_max = 5.0
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = _collision_radius * 0.5
	var fade := Gradient.new()
	fade.set_color(0, Color(_tint.lerp(Color.WHITE, 0.5), 0.9))
	fade.set_color(1, Color(_tint, 0.0))
	trail.color_ramp = fade
	trail.z_index = -1
	add_child(trail)


func _physics_process(delta: float) -> void:
	# Hold the exact endpoint for one physics frame so a target at maximum range
	# can still overlap and receive the full distance-scaled damage.
	if _range_expires_next_tick:
		Fx.burst(global_position + _collision_shape.position, _tint.lerp(Color.WHITE, 0.4),
				8, 150.0, Vector2(_dir, -0.4), 90.0, 0.3, 4.0, 200.0)
		queue_free()
		return
	_age += delta
	var step := _velocity * delta
	if _travel_range > 0.0 and step.length() > _range_left:
		step = step.normalized() * _range_left
	global_position += step
	_distance_traveled += step.length()

	# Despawn once it has flown its max range.
	if _travel_range > 0.0:
		_range_left -= step.length()
		if _range_left <= 0.0:
			_range_left = 0.0
			_range_expires_next_tick = true
	_apply_travel_progress()

	# Safety net: despawn after its lifetime even if it never reaches its range.
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func get_travel_progress() -> float:
	if _travel_range <= 0.0:
		return 0.0
	return clampf(_distance_traveled / _travel_range, 0.0, 1.0)


func get_current_growth() -> float:
	return lerpf(_start_scale, _end_scale, get_travel_progress())


func get_current_damage() -> float:
	var multiplier := lerpf(1.0, _end_damage_multiplier, get_travel_progress())
	return _damage * multiplier


func _apply_travel_progress() -> void:
	var growth := get_current_growth()
	# A quick breathing pulse keeps a single still image feeling alive in flight.
	var pulse := 1.0 + sin(_age * 22.0) * 0.05
	_sprite.scale = Vector2(_base_visual_scale * growth * pulse, _base_visual_scale * growth / pulse)
	if _effect == null and _frame_count > 1 and _fps > 0.0:
		_sprite.frame = int(_age * _fps) % _frame_count
	if _effect != null:
		_effect.set_height(_art_height * growth)
		_effect.position.y = 0.0
		# A wave rises out of the floor during its first moments.
		_effect.set_grow(minf(1.0, 0.35 + _age * 5.0))
	var current_radius := _collision_radius * growth
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = current_radius
	if _grounded:
		_sprite.position.y = -_art_height * growth * 0.5
		_collision_shape.position.y = -current_radius
	else:
		_sprite.position.y = 0.0
		_collision_shape.position.y = 0.0


func _on_body_entered(body: Node) -> void:
	var caster: Node = _shooter if is_instance_valid(_shooter) else null
	if body == caster:
		return  # never hit the caster
	if body.is_in_group("players") and body.has_method("take_hit"):
		body.take_hit(get_current_damage(), _knockback, _dir, _up_ratio, caster, true,
				ToonEffect.sound_kind(_effect_name))
		queue_free()
