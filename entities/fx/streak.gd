extends Node2D
## A quick line of light: the flash along a thrust, a cut across a body, a crack
## along the floor. A thin diamond from this node to a point that snaps out to
## its full length and fades. It animates on game time, like the impact star,
## so it holds still during hit-stop.

var _to: Vector2 = Vector2.RIGHT
var _color: Color = Color.WHITE
var _width: float = 6.0
var _life: float = 0.15
var _age: float = 0.0


## `to` is the far end, relative to where the node is placed.
func setup(to: Vector2, color: Color, width: float, life: float) -> void:
	_to = to
	_color = color
	_width = width
	_life = maxf(0.01, life)
	z_index = 19


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _to.is_zero_approx():
		return
	var t := _age / _life
	var grow := 1.0 - pow(1.0 - minf(1.0, t * 4.0), 3.0)      # snaps out, then holds
	var fade := 1.0 - t * t
	var tip := _to * grow
	var side := _to.orthogonal().normalized() * _width * 0.5 * (1.0 - t * 0.6)
	var mid := tip * 0.35
	# A coloured body with a white core down its middle.
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, mid + side, tip, mid - side]),
			Color(_color, fade * 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, mid + side * 0.4, tip, mid - side * 0.4]),
			Color(1.0, 1.0, 1.0, fade))
