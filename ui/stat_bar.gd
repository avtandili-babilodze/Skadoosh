class_name StatBar
extends Control
## A labelled, segmented meter ("SPEED ▮▮▮▮▮▯▯▯") for a fighter's stat card.
## The fill animates toward its target so switching fighters reads as a change.

const SEGMENTS := 10
const LABEL_WIDTH := 86.0

var caption: String = ""
var color: Color = UI.GOLD
## 0..1
var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		set_process(true)

var _shown: float = 0.0


func _init(text: String = "", bar_color: Color = UI.GOLD) -> void:
	caption = text
	color = bar_color
	custom_minimum_size = Vector2(220, 17)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_shown = move_toward(_shown, value, delta * 2.5)
	queue_redraw()
	if is_equal_approx(_shown, value):
		set_process(false)


func _draw() -> void:
	draw_string(UI.BOLD, Vector2(0, size.y - 3.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.MUTED)
	var gap := 3.0
	var width := (size.x - LABEL_WIDTH - gap * (SEGMENTS - 1)) / SEGMENTS
	var lit := _shown * SEGMENTS
	for i in SEGMENTS:
		var rect := Rect2(LABEL_WIDTH + i * (width + gap), 3.0, width, size.y - 7.0)
		draw_rect(rect, Color(UI.PANEL_HI, 0.9))
		var fill := clampf(lit - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), color)
