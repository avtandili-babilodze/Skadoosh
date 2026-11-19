extends Node2D
## Off-screen player markers. For any fighter outside the visible screen, draws
## a bubble pinned to the nearest screen edge/corner with that fighter's
## portrait inside and an arrowhead aimed at where they really are — so a player
## launched off the side, the top, the bottom or a corner is always tracked.
## The bubble takes the player's colour (blue for P1, orange for P2).

## Radius of the bubble, in px.
const RADIUS := 24.0
## Keep the bubble this far inside the screen edges.
const MARGIN := 40.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var screen := Rect2(Vector2.ZERO, view)
	# The HUD sits on its own canvas layer, so world positions are converted to
	# screen positions through the world canvas (the camera's transform).
	var to_screen := get_viewport().get_canvas_transform()
	for p in get_tree().get_nodes_in_group("players"):
		if not p.visible:
			continue                       # eliminated / waiting to respawn
		var pos: Vector2 = to_screen * (p as Node2D).global_position
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
		var fighter := p as Fighter
		var color := fighter.get_player_color() if fighter != null else Color.WHITE
		var icon: Texture2D = fighter.hero.icon if fighter != null and fighter.hero != null else null
		_marker(center, dir.normalized(), color, icon)


## Draws a portrait bubble at `center` with an arrowhead pointing along `dir`.
func _marker(center: Vector2, dir: Vector2, color: Color, icon: Texture2D) -> void:
	var ang := dir.angle()
	var tip := PackedVector2Array()
	for v in [Vector2(RADIUS + 15.0, 0.0), Vector2(RADIUS - 2.0, -11.0), Vector2(RADIUS - 2.0, 11.0)]:
		tip.append(v.rotated(ang) + center)
	draw_colored_polygon(tip, color)
	draw_circle(center, RADIUS + 3.0, color)
	draw_circle(center, RADIUS, UI.INK)
	if icon != null:
		var half := RADIUS * 0.74
		draw_texture_rect(icon, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false)
