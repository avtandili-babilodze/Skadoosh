extends Node2D
## The flash drawn where a hit lands: a four-point star that snaps open and a
## thin ring that keeps expanding as it fades. It animates on game time, so it
## holds still during hit-stop exactly like the fighters do.

const LIFETIME := 0.2

var _color: Color = Color.WHITE
var _size: float = 40.0
var _dir: float = 1.0
var _age: float = 0.0
var _spin: float = 0.0


func setup(color: Color, size: float, dir: float) -> void:
	_color = color
	_size = size
	_dir = dir
	_spin = randf_range(-0.5, 0.5)
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var open := 1.0 - pow(1.0 - minf(1.0, t * 3.0), 3.0)   # fast ease-out
	var fade := 1.0 - t * t
	# Long arms along the launch direction, short ones across it.
	var long_arm := _size * (0.55 + 0.75 * open)
	var short_arm := _size * 0.42 * open
	var waist := _size * 0.11 * (1.0 - t)
	var points := PackedVector2Array()
	for i in 8:
		var angle := _spin + TAU * i / 8.0
		var radius := waist
		if i % 2 == 0:
			radius = long_arm if i % 4 == 0 else short_arm
		points.append(Vector2(cos(angle) * radius * (1.25 if _dir != 0.0 else 1.0), sin(angle) * radius))
	draw_colored_polygon(points, Color(1, 1, 1, fade))
	var ring := _size * (0.35 + 0.9 * open)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 28, Color(_color, fade * 0.9), maxf(1.0, 5.0 * (1.0 - t)))
