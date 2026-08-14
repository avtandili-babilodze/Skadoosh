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
	if _texture != null:
		_sprite.texture = _texture
		var h := _texture.get_height()
		if h > 0:
			_base_visual_scale = _art_height / h
		# Face the direction of travel.
		_sprite.flip_h = (_dir > 0.0) != _art_faces_right
	_apply_travel_progress()


func _physics_process(delta: float) -> void:
	# Hold the exact endpoint for one physics frame so a target at maximum range
	# can still overlap and receive the full distance-scaled damage.
	if _range_expires_next_tick:
		queue_free()
		return
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

	# Safety nets: despawn after its lifetime, or if it flies off the visible area.
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	if not get_viewport_rect().grow(150.0).has_point(global_position):
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
	_sprite.scale = Vector2(_base_visual_scale * growth, _base_visual_scale * growth)
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
	if body == _shooter:
		return  # never hit the caster
	if body.is_in_group("players") and body.has_method("take_hit"):
		body.take_hit(get_current_damage(), _knockback, _dir, _up_ratio)
		queue_free()
