extends Node2D
## A ring of light that opens out and fades: the shock of a blow on the floor
## (flattened into an ellipse by the node's scale) or a halo round a spinning
## cut. It animates on game time, so it holds still during hit-stop.

var _radius: float = 60.0
var _color: Color = Color.WHITE
var _life: float = 0.35
var _age: float = 0.0


func setup(radius: float, color: Color, life: float) -> void:
	_radius = radius
	_color = color
	_life = maxf(0.01, life)
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	z_index = 17


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	var open := 1.0 - pow(1.0 - t, 3.0)                # fast, then settling
	var fade := 1.0 - t * t
	var radius := _radius * (0.25 + 0.75 * open)
	var width := maxf(1.0, 9.0 * (1.0 - t))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(_color, 0.35 * fade), width * 2.4)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(_color.lerp(Color.WHITE, 0.6), fade), width)
