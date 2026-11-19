extends Control
## Stage select. Either player moves along the row of stages; the whole screen
## becomes the stage under the cursor (its sky behind, a working miniature of
## its layout in the middle). The last card picks a stage at random.

const SELECT_SCENE := "res://scenes/character_select.tscn"
const ARENA_SCENE := "res://scenes/arena.tscn"
const CARD_SIZE := Vector2(190, 108)

var _index: int = 0
var _started: bool = false
var _backdrop: MenuBackdrop
var _preview: StagePreview
var _name: Label
var _description: Label
var _cards: Array[Panel] = []
var _row: HBoxContainer
## Seconds until the random card shows its next stage.
var _shuffle_left: float = 0.0
var _shuffle_map: int = 0


func _ready() -> void:
	UI.fill(self)
	UI.no_interpolation(self)
	Music.menu_mode()
	_index = clampi(Roster.last_map_index, 0, Roster.maps.size())
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	if _started or Transition.busy:
		return
	var step := 0
	for prefix: String in ["p1_", "p2_"]:
		if Input.is_action_just_pressed(prefix + "left"):
			step -= 1
		if Input.is_action_just_pressed(prefix + "right"):
			step += 1
		if Input.is_action_just_pressed(prefix + "attack"):
			_confirm()
			return
		if Input.is_action_just_pressed(prefix + "attack2"):
			_back()
			return
	if step != 0:
		_index = posmod(_index + signi(step), _cards.size())
		Sfx.ui("ui_move")
		_refresh()
	# On the random card the preview flips through the stages.
	if _is_random():
		_shuffle_left -= delta
		if _shuffle_left <= 0.0:
			_shuffle_left = 0.5
			_shuffle_map = (_shuffle_map + 1) % Roster.maps.size()
			_show(Roster.maps[_shuffle_map], "RANDOM", "Let the stage pick you.")


func _unhandled_input(event: InputEvent) -> void:
	if _started or Transition.busy:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_back()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_confirm()


func _is_random() -> bool:
	return _index >= Roster.maps.size()


func _confirm() -> void:
	if Roster.maps.is_empty():
		return
	_started = true
	Roster.last_map_index = _index
	Roster.map = Roster.maps[randi() % Roster.maps.size()] if _is_random() else Roster.maps[_index]
	Sfx.ui("ui_lock")
	Transition.to(ARENA_SCENE)


func _back() -> void:
	_started = true
	Sfx.ui("ui_back")
	Transition.to(SELECT_SCENE)


func _refresh() -> void:
	for i in _cards.size():
		var lit := i == _index
		var style: StyleBoxFlat = _cards[i].get_theme_stylebox("panel")
		style.border_color = UI.GOLD if lit else UI.LINE
		style.set_border_width_all(4 if lit else 2)
		style.shadow_color = Color(UI.GOLD, 0.4 if lit else 0.0)
		style.shadow_size = 12 if lit else 0
		_cards[i].modulate = Color.WHITE if lit else Color(0.72, 0.72, 0.78)
		_cards[i].position.y = -10.0 if lit else 0.0
	if _is_random():
		_shuffle_left = 0.0
	elif _index < Roster.maps.size():
		var map := Roster.maps[_index]
		_show(map, map.map_name.to_upper(), map.description)


func _show(map: MapData, title: String, description: String) -> void:
	_backdrop.show_map(map)
	_preview.map = map
	_name.text = title
	_name.add_theme_color_override("font_color", map.accent.lerp(Color.WHITE, 0.35))
	_description.text = description


# --- UI construction -----------------------------------------------------------

func _build_ui() -> void:
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)

	var title := UI.title("CHOOSE YOUR STAGE", 46)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UI.place(title, Control.PRESET_TOP_WIDE, 0.0, 8.0, 0.0, 70.0)

	_preview = StagePreview.new()
	_preview.name = "Preview"
	add_child(_preview)
	UI.place(_preview, Control.PRESET_FULL_RECT, 150.0, 74.0, -150.0, -290.0)

	_name = UI.title("", 52, UI.TEXT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	UI.place(_name, Control.PRESET_BOTTOM_WIDE, 0.0, -292.0, 0.0, -232.0)

	_description = UI.label("", 18, UI.TEXT, UI.MEDIUM)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_description)
	UI.place(_description, Control.PRESET_BOTTOM_WIDE, 60.0, -232.0, -60.0, -204.0)

	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	UI.place(holder, Control.PRESET_BOTTOM_WIDE, 0.0, -192.0, 0.0, -64.0)
	_row = HBoxContainer.new()
	_row.name = "Stages"
	_row.add_theme_constant_override("separation", 16)
	holder.add_child(_row)
	for map: MapData in Roster.maps:
		_add_card(map.background, map.map_name)
	_add_card(null, "Random")

	var bar := UI.panel(Color(UI.INK, 0.82), Color(UI.LINE, 0.7), 12.0)
	bar.name = "Hints"
	add_child(bar)
	UI.place(bar, Control.PRESET_BOTTOM_WIDE, 24.0, -50.0, -24.0, -10.0)
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 22)
	bar.add_child(hints)
	hints.add_child(UI.hint(["A", "D", "←", "→"], "choose"))
	hints.add_child(UI.hint(["F", "/", "Enter"], "fight"))
	hints.add_child(UI.hint(["G", "'", "Esc"], "back to fighters"))


## A thumbnail card. The holder keeps its slot in the row while the card itself
## lifts when selected.
func _add_card(picture: Texture2D, caption: String) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = CARD_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(slot)

	var card := Panel.new()
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	card.size = CARD_SIZE
	card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 2, 8))
	slot.add_child(card)

	if picture != null:
		var thumb := TextureRect.new()
		thumb.texture = picture
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(thumb)
		UI.fill(thumb, 3.0)
	else:
		var mark := UI.title("?", 72)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(mark)
		UI.fill(mark)
		mark.offset_bottom = -22.0

	var plate := ColorRect.new()
	plate.color = Color(UI.INK, 0.82)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plate)
	UI.place(plate, Control.PRESET_BOTTOM_WIDE, 3.0, -30.0, -3.0, -3.0)
	var name_label := UI.label(caption.to_upper(), 15, UI.TEXT, UI.BOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(name_label)
	UI.fill(name_label)
	_cards.append(card)
