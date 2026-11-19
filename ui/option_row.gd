class_name OptionRow
extends Button
## One line of a settings list: a name on the left, its value on the right.
## Left / right change the value while the row is focused; clicking or pressing
## accept steps it forward. Values are a list of labels, so the same row serves
## volume steps ("0" … "10"), counts and on/off switches.

signal value_changed(index: int)

var values: PackedStringArray = PackedStringArray()
var index: int = 0
## When true the value wraps around at the ends (switches); otherwise it stops.
var wraps: bool = false

var _value_label: Label


func setup(caption: String, option_values: PackedStringArray, start: int, wrap: bool = false) -> void:
	values = option_values
	index = clampi(start, 0, maxi(0, values.size() - 1))
	wraps = wrap
	text = caption
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(460, 46)
	add_theme_font_override("font", UI.BOLD)
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", UI.TEXT)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, UI.INK)
	var idle := UI.box(Color(UI.PANEL, 0.86), UI.LINE, 2, 4, UI.SKEW)
	var lit := UI.box(UI.GOLD, Color.WHITE, 2, 4, UI.SKEW)
	for style: StyleBoxFlat in [idle, lit]:
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", lit)
	add_theme_stylebox_override("focus", lit)
	add_theme_stylebox_override("pressed", lit)

	_value_label = UI.label("", 22, UI.GOLD, UI.BOLD)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_value_label)
	UI.fill(_value_label)
	_value_label.offset_right = -24.0
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	pressed.connect(func(): step(1, true))
	_refresh()


func step(direction: int, wrap_override: bool = false) -> void:
	if values.is_empty():
		return
	var next := index + direction
	if wraps or wrap_override:
		next = posmod(next, values.size())
	else:
		next = clampi(next, 0, values.size() - 1)
	if next == index:
		return
	index = next
	_refresh()
	Sfx.ui("ui_move")
	value_changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()


func _refresh() -> void:
	if _value_label == null:
		return
	var lit := has_focus()
	_value_label.text = ("‹  %s  ›" % values[index]) if lit else values[index]
	_value_label.add_theme_color_override("font_color", UI.INK if lit else UI.GOLD)
