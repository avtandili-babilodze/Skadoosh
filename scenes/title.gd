extends Control
## The title screen (the game's main scene): the logo over a living stage, with
## two random fighters facing off, and the main menu. "How to play" and
## "Settings" open as panels on this same screen.

const SELECT_SCENE := "res://scenes/character_select.tscn"
const ARENA_SCENE := "res://scenes/arena.tscn"
## Seconds without input before the title starts a self-playing demo match.
const DEMO_AFTER := 28.0
## Where the fighters' feet stand, measured up from the bottom of the screen.
const FLOOR_HEIGHT := 64.0

var _backdrop: MenuBackdrop
var _logo: Logo
var _stage: TextureRect
var _fighters: Array[HeroPreview] = []
var _menu: VBoxContainer
var _how_to: Control
var _settings: Control
var _first_button: Button
var _map: MapData
var _idle: float = 0.0


func _ready() -> void:
	UI.fill(self)
	UI.no_interpolation(self)
	Music.menu_mode()

	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	if not Roster.maps.is_empty():
		_map = Roster.maps[randi() % Roster.maps.size()]
		_backdrop.show_map(_map, 0.0)

	_stage = TextureRect.new()
	_stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage.stretch_mode = TextureRect.STRETCH_SCALE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_fighters()

	_logo = Logo.new()
	_logo.name = "Logo"
	add_child(_logo)
	UI.place(_logo, Control.PRESET_TOP_WIDE, 0.0, 8.0, 0.0, 300.0)
	_logo.scale_factor = 0.86

	_build_menu()
	_how_to = _build_how_to()
	_settings = _build_settings()
	_build_footer()

	resized.connect(_layout)
	_layout()
	_show_panel(null)


func _process(delta: float) -> void:
	if Transition.busy or _how_to.visible or _settings.visible:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= DEMO_AFTER:
		_idle = 0.0
		Roster.roll_demo()
		Transition.to(ARENA_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_pressed() or event is InputEventMouseMotion:
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _how_to.visible or _settings.visible:
			Sfx.ui("ui_back")
			_show_panel(null)
			get_viewport().set_input_as_handled()


# --- Building ------------------------------------------------------------------

func _build_fighters() -> void:
	var picks: Array = Roster.heroes.duplicate()
	picks.shuffle()
	for i in mini(2, picks.size()):
		var fighter := HeroPreview.new()
		fighter.hero = picks[i]
		fighter.facing = 1.0 if i == 0 else -1.0
		fighter.zoom = 2.5
		fighter.floor_margin = 0.0
		add_child(fighter)
		_fighters.append(fighter)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var entries := [
		["1 PLAYER", func(): _start(true)],
		["2 PLAYERS", func(): _start(false)],
		["HOW TO PLAY", func(): _show_panel(_how_to)],
		["SETTINGS", func(): _show_panel(_settings)],
		["QUIT", func(): get_tree().quit()],
	]
	for entry in entries:
		var button := UI.button(entry[0], Vector2(320, 50))
		button.pressed.connect(entry[1])
		_menu.add_child(button)
		if _first_button == null:
			_first_button = button


func _start(against_cpu: bool) -> void:
	Roster.demo = false
	Roster.cpu_opponent = against_cpu
	Transition.to(SELECT_SCENE)


func _build_how_to() -> Control:
	var panel := UI.panel(Color(UI.INK, 0.94), UI.GOLD, 26.0)
	panel.name = "HowToPlay"
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UI.title("HOW TO PLAY", 44))

	var rules := UI.label(
			"Every hit raises your rival's %.  The higher it climbs, the farther they fly.\n"
			+ "Knock them past the edge of the stage to take a stock.  Last fighter standing wins.\n"
			+ "Land a hit and you can act at once: follow a light with your heavy, or jump or dash after them."
			+ "  Miss and you are left open.",
			18, UI.TEXT, UI.MEDIUM)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size.x = 760.0
	column.add_child(rules)

	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 26)
	column.add_child(sides)
	for player in 2:
		sides.add_child(_controls_column(player))

	var pads := UI.label(
			"Gamepads work too: stick or d-pad to move, A jump, X light attack, B / Y heavy attack, bumper dash.",
			16, UI.MUTED, UI.MEDIUM)
	pads.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pads.custom_minimum_size.x = 760.0
	column.add_child(pads)

	var back := UI.button("BACK", Vector2(200, 46), 22)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): _show_panel(null))
	column.add_child(back)
	return panel


func _controls_column(player: int) -> Control:
	var prefix := "p%d_" % (player + 1)
	var color: Color = Roster.PLAYER_COLORS[player]
	var box := UI.panel(Color(UI.PANEL, 0.9), Color(color, 0.8), 16.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	box.add_child(column)
	column.add_child(UI.label("PLAYER %d" % (player + 1), 24, color, UI.BOLD))
	var key := func(action: String) -> String: return GameInput.key_label(prefix + action)
	var rows := [
		[[key.call("left"), key.call("right")], "Move"],
		[[key.call("jump")], "Jump, again in the air to double jump"],
		[[key.call("down")], "Fast-fall, drop through platforms"],
		[[key.call("dash")], "Dash with a direction, dodge without"],
		[[key.call("attack2")], "Light attack"],
		[[key.call("attack")], "Heavy attack, a rising strike in the air"],
		[[key.call("left"), key.call("right"), key.call("down")],
				"Aim attacks: side, down for low, still for up"],
		[[key.call("down"), key.call("attack")], "In the air: hold both to dive"],
	]
	for row in rows:
		column.add_child(UI.hint(row[0], row[1], color))
	return box


func _build_settings() -> Control:
	var panel := UI.panel(Color(UI.INK, 0.94), UI.GOLD, 26.0)
	panel.name = "Settings"
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UI.title("SETTINGS", 44))

	var steps := PackedStringArray()
	for i in 11:
		steps.append(str(i))
	var counts := PackedStringArray()
	for i in range(1, 10):
		counts.append(str(i))
	var switch := PackedStringArray(["OFF", "ON"])

	var music := _option(column, "MUSIC VOLUME", steps, roundi(Settings.music_volume * 10.0))
	music.value_changed.connect(func(i: int): Settings.music_volume = i / 10.0; _commit())
	var sound := _option(column, "SOUND VOLUME", steps, roundi(Settings.sfx_volume * 10.0))
	sound.value_changed.connect(func(i: int): Settings.sfx_volume = i / 10.0; _commit(); Sfx.play("hit_light"))
	var stocks := _option(column, "STOCKS PER FIGHTER", counts, Settings.stocks - 1)
	stocks.value_changed.connect(func(i: int): Settings.stocks = i + 1; _commit())
	var cpu := _option(column, "CPU LEVEL", PackedStringArray(["EASY", "NORMAL", "HARD"]), Settings.cpu_level)
	cpu.value_changed.connect(func(i: int): Settings.cpu_level = i; _commit())
	var shake := _option(column, "SCREEN SHAKE", switch, int(Settings.screen_shake), true)
	shake.value_changed.connect(func(i: int): Settings.screen_shake = i == 1; _commit())
	var full := _option(column, "FULLSCREEN  (F11)", switch, int(Settings.fullscreen), true)
	full.value_changed.connect(func(i: int): Settings.fullscreen = i == 1; _commit())

	var back := UI.button("BACK", Vector2(200, 46), 22)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): _show_panel(null))
	column.add_child(back)
	return panel


func _option(parent: Control, caption: String, values: PackedStringArray, start: int,
		wrap: bool = false) -> OptionRow:
	var row := OptionRow.new()
	row.setup(caption, values, start, wrap)
	parent.add_child(row)
	return row


func _commit() -> void:
	Settings.apply()
	Settings.save()


func _build_footer() -> void:
	var bar := UI.panel(Color(UI.INK, 0.82), Color(UI.LINE, 0.7), 12.0)
	bar.name = "Hints"
	add_child(bar)
	UI.place(bar, Control.PRESET_BOTTOM_LEFT, 16.0, -50.0, 16.0, -10.0)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 22)
	bar.add_child(hints)
	hints.add_child(UI.hint(["W", "S"], "choose"))
	hints.add_child(UI.hint(["F", "Enter"], "confirm"))
	hints.add_child(UI.hint(["Esc"], "back"))
	hints.add_child(UI.hint(["7"], "music"))


# --- Behaviour -----------------------------------------------------------------

## Shows one panel (or the main menu when `panel` is null) and moves focus to it.
func _show_panel(panel: Control) -> void:
	_how_to.visible = panel == _how_to
	_settings.visible = panel == _settings
	_menu.visible = panel == null
	_logo.visible = panel == null
	if panel == null:
		_first_button.grab_focus.call_deferred()
		return
	for child in panel.find_children("*", "Button", true, false):
		# Settings focus their first row; How to play has only Back.
		(child as Button).grab_focus.call_deferred()
		break


func _layout() -> void:
	var view := size
	var floor_y := view.y - FLOOR_HEIGHT
	if _map != null and _map.stage_texture != null:
		var line := _map.stage_art_line
		var art_scale := view.x * 0.94 / maxf(1.0, line.y - line.x)
		_stage.texture = _map.stage_texture
		_stage.size = _map.stage_texture.get_size() * art_scale
		_stage.position = Vector2(
				view.x * 0.5 - (line.x + line.y) * 0.5 * art_scale, floor_y - line.z * art_scale)
	for i in _fighters.size():
		var fighter := _fighters[i]
		fighter.size = Vector2(420, 420)
		var x := view.x * (0.15 if i == 0 else 0.85)
		fighter.position = Vector2(x - 210.0, floor_y - 420.0)

	_menu.size = _menu.get_combined_minimum_size()
	_menu.position = Vector2((view.x - _menu.size.x) * 0.5, view.y * 0.5 - 40.0)
	for panel: Control in [_how_to, _settings]:
		panel.size = panel.get_combined_minimum_size()
		panel.position = (view - panel.size) * 0.5
