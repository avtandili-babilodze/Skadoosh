class_name PauseMenu
extends Control
## The pause screen. Opening it freezes the whole match (the scene tree is
## paused); this menu keeps running, dims the fight and offers the ways out.

const SELECT_SCENE := "res://scenes/character_select.tscn"
const MAP_SCENE := "res://scenes/map_select.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

var _first: Button
var _music: OptionRow


func _ready() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.fill(self)
	UI.no_interpolation(self)

	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.72)
	add_child(dim)
	UI.fill(dim)

	var centre := CenterContainer.new()
	add_child(centre)
	UI.fill(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	var title := UI.title("PAUSED", 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var entries := [
		["RESUME", close],
		["RESTART MATCH", func(): Transition.reload()],
		["CHANGE FIGHTERS", func(): Transition.to(SELECT_SCENE)],
		["CHANGE STAGE", func(): Transition.to(MAP_SCENE)],
		["QUIT TO TITLE", func(): Transition.to(TITLE_SCENE)],
	]
	for entry in entries:
		var button := UI.button(entry[0], Vector2(340, 50), 24)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1])
		column.add_child(button)
		if _first == null:
			_first = button

	_music = OptionRow.new()
	_music.setup("MUSIC  (7)", PackedStringArray(["OFF", "ON"]), int(Music.enabled), true)
	_music.custom_minimum_size = Vector2(340, 46)
	_music.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_music.value_changed.connect(func(i: int): Music.set_enabled(i == 1))
	column.add_child(_music)
	hide()


func open() -> void:
	if visible or Transition.busy:
		return
	get_tree().paused = true
	Music.menu_mode(0.2)
	Sfx.ui("ui_select")
	_music.index = int(Music.enabled)
	_music._refresh()
	show()
	_first.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Music.battle_mode(0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Transition.busy:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		Sfx.ui("ui_back")
		close()
		get_viewport().set_input_as_handled()
