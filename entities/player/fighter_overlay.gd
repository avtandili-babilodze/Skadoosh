extends Node2D
## What is drawn around a fighter rather than on it: a blob shadow on the floor
## below (so jumps read as height) and a small player tag above the head (so two
## players on the same hero can be told apart).

## Furthest the shadow is cast; beyond this there is nothing to stand on.
const REACH := 640.0
const TAG_HEIGHT := 92.0

var color: Color = Color.WHITE
var label: String = "P1"
## Distance from the fighter's centre down to the floor, or -1 over a pit.
var floor_distance: float = -1.0
## Half the collision box: where the feet are.
var feet: float = 50.0
var show_tag: bool = true


func _ready() -> void:
	z_index = -2
	# Moved by the fighter's physics tick and redrawn on change, never tweened.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT


## Called by the fighter each physics tick with a fresh floor probe.
func update_floor(distance: float) -> void:
	if not is_equal_approx(distance, floor_distance):
		floor_distance = distance
		queue_redraw()


func _draw() -> void:
	if floor_distance >= 0.0:
		var height := maxf(0.0, floor_distance - feet)
		var size := clampf(1.0 - height / 420.0, 0.3, 1.0)
		var radius := 30.0 * size
		# An ellipse is a circle drawn through a squashed transform.
		draw_set_transform(Vector2(0.0, floor_distance), 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.34 * size))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(color, 0.55 * size), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_tag:
		var tip := Vector2(0.0, -TAG_HEIGHT + 20.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-8.0, -11.0), tip + Vector2(8.0, -11.0), tip]), color)
		var font := UI.BOLD
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var at := Vector2(-text_size.x * 0.5, -TAG_HEIGHT + 4.0)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UI.INK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
