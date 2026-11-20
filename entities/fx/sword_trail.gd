class_name SwordTrail
extends Node2D
## The arc a blade leaves when it swings: a tapered ribbon between the blade's
## tip and a point partway down it, recorded every drawn frame and faded out
## within a fraction of a second. It is drawn live from the rig's real blade,
## so it follows every swing exactly at any frame rate, and it runs on game
## time, so it freezes with the hit-stop like everything else.

## How long a sample of the arc lasts, in seconds of game time.
const LIFETIME := 0.22
## Blade tip speed (world px/s) below which no new arc is laid down.
const MIN_SPEED := 480.0
## How far down the blade the inner edge of the arc reaches (0 = tip, 1 = guard).
const DEPTH := 0.92
## How far past the tip the outer edge of the arc is drawn, in world px: the
## sweep reads larger than the blade that made it.
const OVERSHOOT := 9.0

var color: Color = Color(0.85, 0.93, 1.0)

var _samples: Array = []        # [tip, inner, age]
var _last_tip: Vector2 = Vector2.ZERO
var _has_last: bool = false


func _ready() -> void:
	top_level = true
	z_index = 4
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Adds this frame's blade position (global coordinates). `swinging` is false
## outside attacks, so walking around with a sword leaves no trail.
func feed(tip: Vector2, guard: Vector2, delta: float, swinging: bool) -> void:
	for sample in _samples:
		sample[2] += delta
	while not _samples.is_empty() and _samples[0][2] > LIFETIME:
		_samples.pop_front()
	var fast := false
	if _has_last and delta > 0.0:
		fast = tip.distance_to(_last_tip) / delta > MIN_SPEED
	_last_tip = tip
	_has_last = true
	var outer := tip + (tip - guard).normalized() * OVERSHOOT
	if swinging and fast:
		_samples.append([outer, tip.lerp(guard, DEPTH), 0.0])
	elif swinging and not _samples.is_empty():
		# Keep the ribbon attached to the blade while it decelerates.
		_samples.append([tip, tip.lerp(guard, DEPTH * 0.4), 0.0])
	queue_redraw()


func clear() -> void:
	_samples.clear()
	_has_last = false
	queue_redraw()


func _draw() -> void:
	var count := _samples.size()
	if count < 2:
		return
	# Three bands, widest and darkest outside, a white core along the edge.
	var bands := [[1.0, color.darkened(0.1), 0.8], [0.62, color, 0.95], [0.3, Color.WHITE, 1.0]]
	for band in bands:
		var reach: float = band[0]
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var colors := PackedColorArray()
		for i in count:
			var sample: Array = _samples[i]
			var life := 1.0 - float(sample[2]) / LIFETIME
			var along := float(i) / float(count - 1)          # 0 = oldest, 1 = the blade now
			var taper := pow(along, 0.8)
			var tip: Vector2 = sample[0]
			var root: Vector2 = sample[1]
			outer.append(tip)
			inner.append(tip.lerp(root, reach * taper))
			colors.append(Color(band[1], band[2] * clampf(life, 0.0, 1.0) * along))
		var points := PackedVector2Array()
		var fill := PackedColorArray()
		for i in count:
			points.append(outer[i])
			fill.append(colors[i])
		for i in range(count - 1, -1, -1):
			points.append(inner[i])
			fill.append(colors[i])
		if points.size() >= 3 and Geometry2D.triangulate_polygon(points).size() > 0:
			draw_polygon(points, fill)
