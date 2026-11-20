extends Node2D
## The crescent of light a heavy cut leaves in the air: an arc that draws itself
## along the blade's sweep, glows, then thins out and fades from its tail. It is
## drawn additively in three bands (a wide glow, the coloured body, a white
## edge) and animates on game time, so it holds still during hit-stop.

const STEPS := 30

var _radius: float = 80.0
var _from: float = 0.0
var _sweep: float = PI
var _thickness: float = 22.0
var _color: Color = Color.WHITE
var _life: float = 0.3
var _age: float = 0.0


## Angles are radians on screen (0 forward, positive toward the floor); the arc
## runs from `from_angle` to `to_angle` the way the blade travelled.
func setup(radius: float, from_angle: float, to_angle: float, thickness: float,
		color: Color, life: float) -> void:
	_radius = radius
	_from = from_angle
	_sweep = to_angle - from_angle
	_thickness = thickness
	_color = color
	_life = maxf(0.01, life)
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	z_index = 18


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	# The arc is drawn in the first third of its life; after that its oldest end
	# dies away first.
	var head := 1.0 - pow(1.0 - clampf(t / 0.3, 0.0, 1.0), 2.0)
	var tail := clampf((t - 0.3) / 0.7, 0.0, 1.0) * 0.65
	if head - tail < 0.04:
		return
	var fade := 1.0 - smoothstep(0.4, 1.0, t)
	var radius := _radius * (1.0 + 0.08 * t)
	_band(tail, head, radius + _thickness * 0.35, _thickness * 1.9, Color(_color, 0.28 * fade))
	_band(tail, head, radius, _thickness, Color(_color.lerp(Color.WHITE, 0.25), 0.85 * fade))
	_band(tail, head, radius, _thickness * 0.34, Color(1.0, 1.0, 1.0, fade))


## One band of the arc between two positions along it (0..1): its outer edge at
## `radius`, tapering to nothing at both ends, brightest at the leading end.
func _band(tail: float, head: float, radius: float, width: float, color: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var shades := PackedColorArray()
	for i in STEPS + 1:
		var along := float(i) / float(STEPS)
		var angle := _from + _sweep * lerpf(tail, head, along)
		var direction := Vector2.from_angle(angle)
		var taper := pow(sin(PI * along), 0.7)
		outer.append(direction * radius)
		inner.append(direction * (radius - width * taper))
		shades.append(Color(color, color.a * (0.3 + 0.7 * along)))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in outer.size():
		points.append(outer[i])
		colors.append(shades[i])
	for i in range(inner.size() - 1, -1, -1):
		points.append(inner[i])
		colors.append(shades[i])
	if Geometry2D.triangulate_polygon(points).size() > 0:
		draw_polygon(points, colors)
