extends Control
## Character-select screen (the game's main scene).
##
## Player 1 picks with A / D and locks in with W; Player 2 picks with ← / → and
## locks in with ↑. Either can un-lock with their "down" key. Duplicates are
## allowed (both players may choose the same hero). When BOTH lock in, the picks
## are written to Roster and the arena loads.
##
## The whole grid is built from Roster.heroes at runtime, so adding a fighter to
## the roster needs no changes here.

const P1_COLOR := Color(0.34, 0.62, 1.0)   # blue cursor
const P2_COLOR := Color(1.0, 0.55, 0.22)   # orange cursor
const CELL_SIZE := Vector2(168, 168)

# Per-hero cursor frames: each entry is { "p1": Panel, "p2": Panel }.
var _cells: Array = []
var _p1_index: int = 0
var _p2_index: int = 0
var _p1_locked: bool = false
var _p2_locked: bool = false
var _started: bool = false

var _p1_name: Label
var _p2_name: Label
var _p1_status: Label
var _p2_status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# Start the two cursors on different heroes when possible, so both are visible.
	if Roster.heroes.size() > 1:
		_p2_index = Roster.heroes.size() - 1
	_refresh()


func _process(_delta: float) -> void:
	if _started:
		return
	# Player 1 — A/D to move, W to lock, S to unlock.
	if not _p1_locked:
		if Input.is_action_just_pressed("p1_left"):
			_move(0, -1)
		elif Input.is_action_just_pressed("p1_right"):
			_move(0, 1)
	if Input.is_action_just_pressed("p1_jump"):
		_set_lock(0, true)
	elif Input.is_action_just_pressed("p1_down"):
		_set_lock(0, false)
	# Player 2 — ←/→ to move, ↑ to lock, ↓ to unlock.
	if not _p2_locked:
		if Input.is_action_just_pressed("p2_left"):
			_move(1, -1)
		elif Input.is_action_just_pressed("p2_right"):
			_move(1, 1)
	if Input.is_action_just_pressed("p2_jump"):
		_set_lock(1, true)
	elif Input.is_action_just_pressed("p2_down"):
		_set_lock(1, false)


func _move(player: int, dir: int) -> void:
	var n: int = Roster.heroes.size()
	if n == 0:
		return
	if player == 0:
		_p1_index = (_p1_index + dir + n) % n
	else:
		_p2_index = (_p2_index + dir + n) % n
	_refresh()


func _set_lock(player: int, locked: bool) -> void:
	if player == 0:
		_p1_locked = locked
	else:
		_p2_locked = locked
	_refresh()
	if _p1_locked and _p2_locked:
		_start()


func _start() -> void:
	_started = true
	Roster.p1_hero = Roster.heroes[_p1_index]
	Roster.p2_hero = Roster.heroes[_p2_index]
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _refresh() -> void:
	for i in _cells.size():
		var f1: Panel = _cells[i].p1
		var f2: Panel = _cells[i].p2
		f1.visible = (i == _p1_index)
		f2.visible = (i == _p2_index)
		# Locked cursor is solid; while still choosing it's semi-transparent.
		f1.modulate = Color(1, 1, 1, 1.0 if _p1_locked else 0.6)
		f2.modulate = Color(1, 1, 1, 1.0 if _p2_locked else 0.6)
	if Roster.heroes.is_empty():
		return
	_p1_name.text = Roster.heroes[_p1_index].hero_name
	_p2_name.text = Roster.heroes[_p2_index].hero_name
	_p1_status.text = "READY" if _p1_locked else "Choosing…"
	_p2_status.text = "READY" if _p2_locked else "Choosing…"


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "CHOOSE YOUR FIGHTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 48.0
	title.offset_bottom = 120.0
	add_child(title)

	# Centered row of hero icons.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	center.add_child(row)

	for hero: HeroData in Roster.heroes:
		row.add_child(_make_cell(hero))

	_p1_name = _make_side_panel("PLAYER 1", P1_COLOR, true)
	_p2_name = _make_side_panel("PLAYER 2", P2_COLOR, false)

	var hint := Label.new()
	hint.text = "P1:  A / D  move   •   W  lock in        P2:  ← / →  move   •   ↑  lock in"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -64.0
	hint.offset_bottom = -28.0
	add_child(hint)


func _make_cell(hero: HeroData) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.add_theme_stylebox_override("panel", _cell_style())

	var icon := TextureRect.new()
	icon.texture = hero.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(icon, 14.0)
	cell.add_child(icon)

	var f1 := _make_frame(P1_COLOR, 0.0)   # outer frame (P1)
	var f2 := _make_frame(P2_COLOR, 7.0)   # inner frame (P2), inset so both show
	cell.add_child(f1)
	cell.add_child(f2)
	f1.hide()
	f2.hide()
	_cells.append({"p1": f1, "p2": f2})
	return cell


func _make_frame(color: Color, inset: float) -> Panel:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _frame_style(color))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(frame, inset)
	return frame


## Returns the hero-name Label so _refresh() can update it.
func _make_side_panel(title: String, color: Color, left: bool) -> Label:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	if left:
		box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		box.offset_left = 40.0
		box.offset_top = -80.0
	else:
		box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		box.offset_left = -300.0
		box.offset_top = -80.0
	add_child(box)

	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", color)
	box.add_child(head)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 20)
	status.modulate = Color(1, 1, 1, 0.75)
	box.add_child(status)

	if left:
		_p1_status = status
	else:
		_p2_status = status
	return name_label


func _fill(c: Control, inset: float) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = inset
	c.offset_top = inset
	c.offset_right = -inset
	c.offset_bottom = -inset


func _cell_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.2)
	sb.set_corner_radius_all(10)
	return sb


func _frame_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(6)
	sb.border_color = color
	sb.set_corner_radius_all(10)
	return sb
