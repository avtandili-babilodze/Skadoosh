extends Control
## Character-select screen.
##
## Each player moves a cursor over the roster grid with their movement keys and
## locks in with their heavy-attack key (F for Player 1, / for Player 2); the
## light-attack key unlocks again. Duplicates are allowed (both players may
## choose the same hero). A card on each side shows the fighter under that
## player's cursor, animated, with stats and skills. When BOTH lock in, the
## picks are written to Roster and the map select loads.
##
## In a one-player match (Roster.cpu_opponent) Player 1 makes both picks with
## the same keys: their own fighter first, then the CPU's.
##
## The whole grid is built from Roster.heroes at runtime, so adding a fighter to
## the roster needs no changes here.

const TITLE_SCENE := "res://scenes/title.tscn"
const MAP_SCENE := "res://scenes/map_select.tscn"
const CELL_SIZE := Vector2(126, 142)
const GRID_GAP := 14
## Width taken by the two fighter cards and their margins beside the grid.
const SIDE_WIDTH := 350.0

# Per-hero card and cursor frames: { "cell": Panel, "frames": [Panel, Panel] }.
var _cells: Array = []
var _index := [0, 0]
var _locked := [false, false]
var _started: bool = false

var _cards: Array[FighterCard] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _pending_focus_index: int = 0


func _ready() -> void:
	UI.fill(self)
	UI.no_interpolation(self)
	Music.menu_mode()
	_build_ui()
	for player in 2:
		_index[player] = clampi(Roster.last_hero_index[player], 0, maxi(0, Roster.heroes.size() - 1))
	_refresh()
	resized.connect(_update_grid_columns)
	call_deferred("_update_grid_columns")


func _process(_delta: float) -> void:
	if _started or Transition.busy:
		return
	if Roster.cpu_opponent:
		_process_single()
		return
	for player in 2:
		var prefix := "p%d_" % (player + 1)
		if not _locked[player]:
			if Input.is_action_just_pressed(prefix + "left"):
				_move(player, -1, 0)
			elif Input.is_action_just_pressed(prefix + "right"):
				_move(player, 1, 0)
			elif Input.is_action_just_pressed(prefix + "jump"):
				_move(player, 0, -1)
			elif Input.is_action_just_pressed(prefix + "down"):
				_move(player, 0, 1)
		if Input.is_action_just_pressed(prefix + "attack"):
			_set_lock(player, true)
		elif Input.is_action_just_pressed(prefix + "attack2"):
			_set_lock(player, false)


## One player drives both cursors in turn: theirs until it is locked, then the CPU's.
func _process_single() -> void:
	var cursor := 1 if _locked[0] else 0
	if Input.is_action_just_pressed("p1_left"):
		_move(cursor, -1, 0)
	elif Input.is_action_just_pressed("p1_right"):
		_move(cursor, 1, 0)
	elif Input.is_action_just_pressed("p1_jump"):
		_move(cursor, 0, -1)
	elif Input.is_action_just_pressed("p1_down"):
		_move(cursor, 0, 1)
	if Input.is_action_just_pressed("p1_attack"):
		_set_lock(cursor, true)
	elif Input.is_action_just_pressed("p1_attack2"):
		# Unlocking steps back one pick.
		_set_lock(1 if _locked[1] else 0, false)


func _unhandled_input(event: InputEvent) -> void:
	if _started or Transition.busy:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Sfx.ui("ui_back")
		Transition.to(TITLE_SCENE)


## Moves a player's cursor by whole cells. Sideways movement runs through the
## roster in reading order and wraps at both ends; vertical movement stays in
## its column.
func _move(player: int, dx: int, dy: int) -> void:
	var count: int = Roster.heroes.size()
	if count == 0:
		return
	var columns := maxi(1, _grid.columns)
	var index: int = _index[player]
	if dx != 0:
		index = posmod(index + dx, count)
	if dy != 0:
		var target := index + dy * columns
		if target >= 0 and target < count:
			index = target
	if index == _index[player]:
		return
	_index[player] = index
	_pending_focus_index = index
	Sfx.ui("ui_move")
	_refresh()


func _set_lock(player: int, locked: bool) -> void:
	if _locked[player] == locked:
		return
	_locked[player] = locked
	Sfx.ui("ui_lock" if locked else "ui_back")
	_refresh()
	if _locked[0] and _locked[1]:
		_start()


func _start() -> void:
	_started = true
	Roster.p1_hero = Roster.heroes[_index[0]]
	Roster.p2_hero = Roster.heroes[_index[1]]
	Roster.last_hero_index = [_index[0], _index[1]]
	# Hold on the two READY plates for a beat before leaving.
	await get_tree().create_timer(0.45).timeout
	Transition.to(MAP_SCENE)


func _refresh() -> void:
	for i in _cells.size():
		for player in 2:
			var frame: Panel = _cells[i].frames[player]
			frame.visible = i == _index[player]
			# Locked cursor is solid; while still choosing it's semi-transparent.
			frame.modulate = Color(1, 1, 1, 1.0 if _locked[player] else 0.7)
	if Roster.heroes.is_empty():
		return
	for player in 2:
		_cards[player].show_hero(Roster.heroes[_index[player]])
		_cards[player].set_locked(_locked[player],
				Roster.cpu_opponent and player == 1 and not _locked[0])
	call_deferred("_focus_pending_cell")


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	var backdrop := MenuBackdrop.new()
	add_child(backdrop)
	if not Roster.maps.is_empty():
		backdrop.show_map(Roster.maps[Roster.last_map_index % Roster.maps.size()], 0.0)

	var title := UI.title("CHOOSE YOUR FIGHTER", 46)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UI.place(title, Control.PRESET_TOP_WIDE, 0.0, 8.0, 0.0, 70.0)

	for player in 2:
		var card := FighterCard.new()
		card.name = "Card%d" % (player + 1)
		if Roster.cpu_opponent:
			card.setup(player, GameInput.key_label("p1_attack"), "YOU" if player == 0 else "CPU")
		else:
			card.setup(player, GameInput.key_label("p%d_attack" % (player + 1)))
		add_child(card)
		if player == 0:
			UI.place(card, Control.PRESET_LEFT_WIDE, 24.0, 78.0, 324.0, -58.0)
		else:
			UI.place(card, Control.PRESET_RIGHT_WIDE, -324.0, 78.0, -24.0, -58.0)
		_cards.append(card)

	_scroll = ScrollContainer.new()
	_scroll.name = "RosterScroll"
	add_child(_scroll)
	UI.place(_scroll, Control.PRESET_FULL_RECT, SIDE_WIDTH, 84.0, -SIDE_WIDTH, -62.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true

	var grid_center := CenterContainer.new()
	grid_center.name = "GridCenter"
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(grid_center)

	_grid = GridContainer.new()
	_grid.name = "HeroGrid"
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	grid_center.add_child(_grid)

	for hero: HeroData in Roster.heroes:
		_grid.add_child(_make_cell(hero))

	var bar := UI.panel(Color(UI.INK, 0.82), Color(UI.LINE, 0.7), 12.0)
	bar.name = "Hints"
	add_child(bar)
	UI.place(bar, Control.PRESET_BOTTOM_WIDE, 24.0, -50.0, -24.0, -10.0)
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 20)
	bar.add_child(hints)
	var key := func(action: String) -> String: return GameInput.key_label(action)
	var p1: Color = Roster.PLAYER_COLORS[0]
	var p2: Color = Roster.PLAYER_COLORS[1]
	hints.add_child(UI.hint([key.call("p1_jump"), key.call("p1_left"), key.call("p1_down"), key.call("p1_right")], "move", p1))
	hints.add_child(UI.hint([key.call("p1_attack")], "lock", p1))
	hints.add_child(UI.hint([key.call("p1_attack2")], "unlock", p1))
	hints.add_child(UI.hint(["Esc"], "title"))
	if Roster.cpu_opponent:
		hints.add_child(UI.label("Pick your fighter, then the CPU's.", 16, UI.MUTED, UI.MEDIUM))
		return
	hints.add_child(UI.hint([key.call("p2_jump"), key.call("p2_left"), key.call("p2_down"), key.call("p2_right")], "move", p2))
	hints.add_child(UI.hint([key.call("p2_attack")], "lock", p2))
	hints.add_child(UI.hint([key.call("p2_attack2")], "unlock", p2))


func _make_cell(hero: HeroData) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.9), UI.LINE, 2, 8))

	var icon := TextureRect.new()
	icon.texture = hero.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	UI.place(icon, Control.PRESET_FULL_RECT, 10.0, 10.0, -10.0, -32.0)

	var name_label := UI.label(hero.hero_name, 14, UI.TEXT, UI.BOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(name_label)
	UI.place(name_label, Control.PRESET_BOTTOM_WIDE, 7.0, -30.0, -7.0, -4.0)

	# Player 1's frame is the outer one and Player 2's sits inside it, so both
	# stay visible on a shared pick.
	var frames: Array[Panel] = []
	for player in 2:
		var frame := Panel.new()
		var color: Color = Roster.PLAYER_COLORS[player]
		frame.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT, color, 5, 8))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(frame)
		UI.fill(frame, player * 6.0)
		var tag := UI.keycap("CPU" if Roster.cpu_opponent and player == 1 else "P%d" % (player + 1), color)
		frame.add_child(tag)
		if player == 0:
			UI.place(tag, Control.PRESET_TOP_LEFT, 6.0, 6.0, 6.0, 6.0)
		else:
			tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			UI.place(tag, Control.PRESET_TOP_RIGHT, -4.0, 4.0, -4.0, 4.0)
		frame.hide()
		frames.append(frame)
	_cells.append({"cell": cell, "frames": frames})
	return cell


func _update_grid_columns() -> void:
	if _grid == null:
		return
	_grid.columns = _calculate_column_count(
			get_viewport_rect().size.x - SIDE_WIDTH * 2.0, Roster.heroes.size())
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
