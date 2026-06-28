extends Node2D
## Off-screen player markers. For any player outside the visible screen, draws a
## small arrow pinned to the nearest screen edge/corner, pointing toward them — so
## a player off the side, the top, the bottom, or a corner (two edges at once) is
## always tracked by a single triangle aimed in their actual direction.
## P1 = white triangle (black outline), P2 = black triangle (white outline).

## Size of the arrow, in px.
const SIZE := 14.0
## Keep the arrow this far inside the screen edges (room for the triangle + label).
const MARGIN := 22.0

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var screen := Rect2(Vector2.ZERO, view)
	for p in get_tree().get_nodes_in_group("players"):
		if not p.visible:
			continue                       # eliminated / parked off-screen
		var pos: Vector2 = p.global_position
		if screen.has_point(pos):
			continue                       # on-screen — no marker needed
		# Pin the marker to the screen edge/corner closest to the player; the arrow
		# then points from that pinned spot out toward the player's real position.
		var center := Vector2(
				clampf(pos.x, MARGIN, view.x - MARGIN),
				clampf(pos.y, MARGIN, view.y - MARGIN))
		var dir := pos - center
		if dir.length() < 0.001:
			continue
		dir = dir.normalized()
		var is_p1 := String(p.name) == "Player1"
		_marker(center, dir,
				Color.WHITE if is_p1 else Color.BLACK,
				Color.BLACK if is_p1 else Color.WHITE,
				"1" if is_p1 else "2")


## Draw an arrowhead at `center` pointing along `dir`, with the player number
## placed just inside the screen from it.
func _marker(center: Vector2, dir: Vector2, fill: Color, outline: Color, label: String) -> void:
	var ang := dir.angle()
	var pts := PackedVector2Array()
	for v in [Vector2(SIZE, 0.0), Vector2(-SIZE, -SIZE * 0.85), Vector2(-SIZE, SIZE * 0.85)]:
		pts.append(v.rotated(ang) + center)
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), outline, 2.0)
	var label_pos := center - dir * (SIZE + 12.0) + Vector2(-4.0, 6.0)
	draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, outline)
