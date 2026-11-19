extends Sprite2D
## An afterimage: a tinted, fading copy of a fighter's sprite frozen at the frame
## and place it was taken. Dashes and dodges drop a few of these behind them.

const LIFETIME := 0.22

var _age: float = 0.0
var _tint: Color = Color.WHITE


## Copies everything that defines how `source` looks right now.
func setup(source: Sprite2D, tint: Color) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	texture = source.texture
	hframes = source.hframes
	vframes = source.vframes
	frame = source.frame
	flip_h = source.flip_h
	texture_filter = source.texture_filter
	global_transform = source.global_transform
	z_index = -1
	_tint = tint
	modulate = Color(tint, 0.55)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	modulate = Color(_tint, 0.55 * (1.0 - _age / LIFETIME))
