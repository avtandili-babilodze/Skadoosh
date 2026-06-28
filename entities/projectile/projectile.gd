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
var _shooter: Node = null            # the player who fired it (never self-hit)
# Visuals — stored here and applied in _ready (configure runs before add_child).
var _texture: Texture2D = null
var _art_height: float = 70.0
var _art_faces_right: bool = true


## Configure the projectile. Call this BEFORE add_child; the visuals are applied
## in _ready (which runs when it enters the tree).
func configure(shooter: Node, facing: float, damage: float, knockback: float, up_ratio: float,
		speed: float, travel_range: float, lifetime: float,
		texture: Texture2D, art_height: float, art_faces_right: bool) -> void:
	_shooter = shooter
	_dir = signf(facing) if facing != 0.0 else 1.0
	_damage = damage
	_knockback = knockback
	_up_ratio = up_ratio
	_velocity = Vector2(_dir * speed, 0.0)
	_range_left = travel_range
	_life_left = lifetime
	_texture = texture
	_art_height = art_height
	_art_faces_right = art_faces_right


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _texture != null:
		var sprite: Sprite2D = $Sprite2D
		sprite.texture = _texture
		var h := _texture.get_height()
		if h > 0:
			var s := _art_height / h
			sprite.scale = Vector2(s, s)
		# Face the direction of travel.
		sprite.flip_h = (_dir > 0.0) != _art_faces_right


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	global_position += step

	# Despawn once it has flown its max range.
	if _range_left > 0.0:
		_range_left -= step.length()
		if _range_left <= 0.0:
			queue_free()
			return

	# Safety nets: despawn after its lifetime, or if it flies off the visible area.
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	if not get_viewport_rect().grow(150.0).has_point(global_position):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == _shooter:
		return  # never hit the caster
	if body.is_in_group("players") and body.has_method("take_hit"):
		body.take_hit(_damage, _knockback, _dir, _up_ratio)
		queue_free()
