class_name Whip
extends Node2D
## A live whip held in a rigged fighter's hand: a rope of segments simulated
## each frame (Verlet with gravity), drawn as a tapered inked leather cord.
## At rest it hangs short from the fist and sways with the body. In an attack it
## pays out and trails the hand through the wind-up, snaps out straight toward
## the target for the hit (with a crack at the tip), then recoils.

const SEGMENTS := 14
const GRAVITY := 1100.0
## Length when idle (world px); `full_length` is the length at full extension.
const REST_LENGTH := 36.0
## Thickness at the grip and at the tip, without the ink outline (world px).
const BASE_WIDTH := 3.2
const TIP_WIDTH := 0.9
const INK_WIDTH := 1.6
## How much a segment lying on the floor keeps of its sideways slide per step.
const FLOOR_FRICTION := 0.6
const INK := Color(0.05, 0.03, 0.04)
const LEATHER := Color(0.16, 0.08, 0.1)
const SHINE := Color(0.52, 0.2, 0.25)

var full_length: float = 140.0
## 0 = hanging short, 1 = fully extended toward `aim`.
var extension: float = 0.0

var _points: PackedVector2Array = PackedVector2Array()
var _previous: PackedVector2Array = PackedVector2Array()
var _ready_points: bool = false
var _cracked: bool = false


func _ready() -> void:
	top_level = true
	z_index = 3
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## `hand` is the grip in global coordinates. `aim` is the unit direction the whip
## lashes toward; `straighten` (0..1) pulls it into a straight line along `aim`.
## `floor_y` is the ground under the fighter (global y; INF in the air): the
## whip trails along it instead of passing through.
func feed(hand: Vector2, aim: Vector2, straighten: float, delta: float, floor_y: float = INF) -> void:
	if not _ready_points:
		_points.resize(SEGMENTS + 1)
		_previous.resize(SEGMENTS + 1)
		for i in SEGMENTS + 1:
			_points[i] = hand + Vector2(0.0, REST_LENGTH * i / SEGMENTS)
			_previous[i] = _points[i]
		_ready_points = true
	if delta <= 0.0:
		return
	var length := lerpf(REST_LENGTH, full_length, extension)
	var segment := length / SEGMENTS
	_points[0] = hand
	_previous[0] = hand
	var damping := 0.985
	for i in range(1, SEGMENTS + 1):
		var velocity := (_points[i] - _previous[i]) * damping
		_previous[i] = _points[i]
		_points[i] += velocity + Vector2(0.0, GRAVITY) * delta * delta
	# Pull toward the straight lash line: harder toward the tip, so it unrolls.
	if straighten > 0.0:
		for i in range(1, SEGMENTS + 1):
			var target := hand + aim * segment * i
			var pull := clampf(straighten * (0.35 + 0.65 * float(i) / SEGMENTS), 0.0, 1.0)
			_points[i] = _points[i].lerp(target, pull)
	for _iteration in 4:
		_points[0] = hand
		for i in range(SEGMENTS):
			var a := _points[i]
			var b := _points[i + 1]
			var d := b - a
			var dist := maxf(0.001, d.length())
			var fix := d * (1.0 - segment / dist)
			if i == 0:
				_points[i + 1] -= fix
			else:
				_points[i] += fix * 0.5
				_points[i + 1] -= fix * 0.5
		if floor_y < INF:
			for i in range(1, SEGMENTS + 1):
				if _points[i].y > floor_y:
					_points[i].y = floor_y
					# Leather drags on the ground: it slides, but slows.
					_previous[i].y = floor_y
					_previous[i].x = lerpf(_points[i].x, _previous[i].x, FLOOR_FRICTION)
	queue_redraw()


## The tip snapping out: a small white burst, once per lash.
func crack() -> void:
	if _cracked or _points.is_empty():
		return
	_cracked = true
	var tip := _points[SEGMENTS]
	Fx.burst(tip, Color(1.0, 0.95, 0.9), 8, 260.0, (tip - _points[SEGMENTS - 2]).normalized(), 70.0, 0.18, 4.0, 0.0)


func reset_crack() -> void:
	_cracked = false


func tip() -> Vector2:
	return _points[SEGMENTS] if not _points.is_empty() else global_position


func _draw() -> void:
	if _points.size() < 2:
		return
	var count := _points.size()
	# Ink outline under the leather, then a thin shine along the top edge.
	for pass_index in 3:
		var color: Color = [INK, LEATHER, SHINE][pass_index]
		for i in range(count - 1):
			var t := float(i) / (count - 1)
			var width := lerpf(BASE_WIDTH, TIP_WIDTH, t)
			if pass_index == 0:
				width += INK_WIDTH
			elif pass_index == 2:
				width *= 0.3
			var a := _points[i]
			var b := _points[i + 1]
			if pass_index == 2:
				var normal := (b - a).orthogonal().normalized()
				a -= normal * width * 0.8
				b -= normal * width * 0.8
			draw_line(a, b, color, width, true)
			if pass_index < 2:
				draw_circle(b, width * 0.5, color)
