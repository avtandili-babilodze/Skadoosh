extends Node2D
## A burst of straight rays of light from one point: the points of a crown, a
## sunburst on the floor, cracks running out from a blow. Long and short rays
## alternate across an arc of directions; they snap out to full length and
## fade. Each is a coloured blade with a thin white core, drawn normally and
## not additively, so it keeps its colour in front of a bright sky. It animates
## on game time, like the impact star, so it holds still during hit-stop.

var _count: int = 7
var _length: float = 120.0
var _from: float = -PI
var _to: float = 0.0
var _color: Color = Color.WHITE
var _width: float = 10.0
var _life: float = 0.3
var _age: float = 0.0


## Angles are radians on screen (0 forward, positive toward the floor); the
## rays are spread evenly from `from_angle` to `to_angle`.
func setup(count: int, length: float, from_angle: float, to_angle: float,
		color: Color, width: float, life: float) -> void:
	_count = maxi(1, count)
	_length = length
	_from = from_angle
	_to = to_angle
	_color = color
	_width = width
	_life = maxf(0.01, life)
	z_index = 18


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	var grow := 1.0 - pow(1.0 - minf(1.0, t * 4.0), 3.0)      # snaps out, then holds
	var fade := 1.0 - t * t
	for i in _count:
		var along := 0.5 if _count == 1 else float(i) / float(_count - 1)
		var direction := Vector2.from_angle(lerpf(_from, _to, along))
		var reach := _length * grow * (1.0 if i % 2 == 0 else 0.62)
		var root := direction * _length * 0.1
		var tip := direction * reach
		if reach <= _length * 0.1:
			continue
		var side := direction.orthogonal() * _width * 0.5 * (1.0 - t * 0.5)
		var waist := root.lerp(tip, 0.22)
		draw_colored_polygon(PackedVector2Array([root, waist + side, tip, waist - side]),
				Color(_color, fade * 0.95))
		draw_colored_polygon(PackedVector2Array([root, waist + side * 0.28, tip.lerp(root, 0.12), waist - side * 0.28]),
				Color(1.0, 1.0, 1.0, fade * 0.9))
