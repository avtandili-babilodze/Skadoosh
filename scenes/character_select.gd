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
const CELL_SIZE := Vector2(126, 142)
const GRID_GAP := 16
const GRID_SIDE_MARGIN := 80.0

# Per-hero card and cursor frames: { "cell": Panel, "p1": Panel, "p2": Panel }.
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
var _scroll: ScrollContainer
var _grid: GridContainer
var _pending_focus_index: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# Adjacent starting picks remain visible even when the roster spans many rows.
	if Roster.heroes.size() > 1:
		_p2_index = 1
	_refresh()
	resized.connect(_update_grid_columns)
	call_deferred("_update_grid_columns")


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
		_pending_focus_index = _p1_index
	else:
		_p2_index = (_p2_index + dir + n) % n
		_pending_focus_index = _p2_index
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
	call_deferred("_focus_pending_cell")


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.name = "Title"
	title.text = "CHOOSE YOUR FIGHTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22.0
	title.offset_bottom = 78.0
	add_child(title)

	var count_label := Label.new()
	count_label.name = "RosterCount"
	count_label.text = "%d FIGHTERS" % Roster.heroes.size()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.modulate = Color(1, 1, 1, 0.55)
	count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count_label.offset_top = 72.0
	count_label.offset_bottom = 98.0
	add_child(count_label)

	var summaries := HBoxContainer.new()
	summaries.name = "PlayerSummaries"
	summaries.set_anchors_preset(Control.PRESET_TOP_WIDE)
	summaries.offset_left = 46.0
	summaries.offset_top = 102.0
	summaries.offset_right = -46.0
	summaries.offset_bottom = 178.0
	summaries.add_theme_constant_override("separation", 28)
	add_child(summaries)
	_p1_name = _make_player_summary(summaries, "PLAYER 1", P1_COLOR, true)
	_p2_name = _make_player_summary(summaries, "PLAYER 2", P2_COLOR, false)

	_scroll = ScrollContainer.new()
	_scroll.name = "RosterScroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 40.0
	_scroll.offset_top = 214.0
	_scroll.offset_right = -40.0
	_scroll.offset_bottom = -80.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	add_child(_scroll)

	var grid_center := CenterContainer.new()
	grid_center.name = "GridCenter"
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(grid_center)

	_grid = GridContainer.new()
	_grid.name = "HeroGrid"
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	grid_center.add_child(_grid)

	for hero: HeroData in Roster.heroes:
		_grid.add_child(_make_cell(hero))

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "P1: A / D move  •  W lock  •  S unlock       P2: ← / → move  •  ↑ lock  •  ↓ unlock"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -62.0
	hint.offset_bottom = -24.0
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
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_top = 10.0
	icon.offset_right = -10.0
	icon.offset_bottom = -32.0
	cell.add_child(icon)

	var name_label := Label.new()
	name_label.text = hero.hero_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 7.0
	name_label.offset_top = -30.0
	name_label.offset_right = -7.0
	name_label.offset_bottom = -4.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_label)

	var f1 := _make_frame(P1_COLOR, 0.0)   # outer frame (P1)
	var f2 := _make_frame(P2_COLOR, 7.0)   # inner frame (P2), inset so both show
	cell.add_child(f1)
	cell.add_child(f2)
	f1.hide()
	f2.hide()
	_cells.append({"cell": cell, "p1": f1, "p2": f2})
	return cell


func _make_frame(color: Color, inset: float) -> Panel:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _frame_style(color))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(frame, inset)
	return frame


## Returns the hero-name Label so _refresh() can update it.
func _make_player_summary(parent: Container, title: String, color: Color, left: bool) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _summary_style(color))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", color)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(head)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 15)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	status.modulate = Color(1, 1, 1, 0.75)
	box.add_child(status)

	if left:
		_p1_status = status
	else:
		_p2_status = status
	return name_label


func _update_grid_columns() -> void:
	if _grid == null:
		return
	_grid.columns = _calculate_column_count(
			get_viewport_rect().size.x - GRID_SIDE_MARGIN, Roster.heroes.size())
	call_deferred("_focus_pending_cell")


func _calculate_column_count(available_width: float, hero_count: int) -> int:
	if hero_count <= 0:
		return 1
	var fitting := maxi(1, int((available_width + GRID_GAP) / (CELL_SIZE.x + GRID_GAP)))
	return mini(hero_count, fitting)


func _focus_pending_cell() -> void:
	if (_scroll == null or _pending_focus_index < 0
			or _pending_focus_index >= _cells.size()):
		return
	_scroll.ensure_control_visible(_cells[_pending_focus_index].cell)


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


func _summary_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.17, 0.92)
	sb.border_color = Color(color, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb
