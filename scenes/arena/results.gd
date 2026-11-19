class_name ResultsScreen
extends Control
## The end-of-match screen: the winner large and alive on one side, the loser
## collapsing on the other, the match's numbers between them, and where to go
## next. Buttons wake up after a short delay so mashing an attack key at the
## final blow cannot skip the screen.

const SELECT_SCENE := "res://scenes/character_select.tscn"
const MAP_SCENE := "res://scenes/map_select.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const INPUT_DELAY := 0.9

var _buttons: Array[Button] = []


## `rows` holds one dictionary per player: {hero, player, kos, falls, damage}.
## `winner` is an index into it, or -1 for a draw.
func present(rows: Array, winner: int) -> void:
	name = "Results"
	UI.fill(self)
	UI.no_interpolation(self)

	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.8)
	add_child(dim)
	UI.fill(dim)

	var winner_color: Color = UI.GOLD
	var headline := "DRAW!"
	if winner >= 0:
		winner_color = Roster.PLAYER_COLORS[rows[winner].player]
		headline = "PLAYER %d WINS!" % (rows[winner].player + 1)
		if Roster.cpu_opponent:
			headline = "YOU WIN!" if rows[winner].player == 0 else "CPU WINS!"
	var title := UI.title(headline, 84, winner_color.lerp(Color.WHITE, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UI.place(title, Control.PRESET_TOP_WIDE, 0.0, 14.0, 0.0, 120.0)
	title.pivot_offset = Vector2(size.x * 0.5, 50.0)
	title.scale = Vector2.ONE * 1.6
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fighters: the winner stands tall, everyone else goes down.
	for i in rows.size():
		var fighter := HeroPreview.new()
		fighter.hero = rows[i].hero
		var won := i == winner
		fighter.animation = "idle" if won or winner < 0 else "death"
		fighter.zoom = 3.0 if won else 2.2
		fighter.facing = 1.0 if i == 0 else -1.0
		fighter.modulate = Color.WHITE if won or winner < 0 else Color(0.62, 0.6, 0.7)
		add_child(fighter)
		if i == 0:
			UI.place(fighter, Control.PRESET_LEFT_WIDE, 10.0, 110.0, 330.0, -40.0)
		else:
			UI.place(fighter, Control.PRESET_RIGHT_WIDE, -330.0, 110.0, -10.0, -40.0)

	var centre := CenterContainer.new()
	add_child(centre)
	UI.place(centre, Control.PRESET_FULL_RECT, 320.0, 118.0, -320.0, -16.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)
	column.add_child(_stats_table(rows, winner))

	var entries := [
		["REMATCH", func(): Transition.reload()],
		["CHANGE FIGHTERS", func(): Transition.to(SELECT_SCENE)],
		["CHANGE STAGE", func(): Transition.to(MAP_SCENE)],
		["QUIT TO TITLE", func(): Transition.to(TITLE_SCENE)],
	]
	for entry in entries:
		var button := UI.button(entry[0], Vector2(340, 46), 22)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1])
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		column.add_child(button)
		_buttons.append(button)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	get_tree().create_timer(INPUT_DELAY, true, false, true).timeout.connect(_wake_buttons)


func _wake_buttons() -> void:
	for button in _buttons:
		button.disabled = false
		button.focus_mode = Control.FOCUS_ALL
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _stats_table(rows: Array, winner: int) -> Control:
	var panel := UI.panel(Color(UI.PANEL, 0.92), UI.LINE, 18.0)
	var grid := GridContainer.new()
	grid.columns = rows.size() + 1
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)

	grid.add_child(UI.label("", 16))
	for i in rows.size():
		var color: Color = Roster.PLAYER_COLORS[rows[i].player]
		var head := UI.label((rows[i].hero as HeroData).hero_name.to_upper(), 20, color, UI.BOLD)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size.x = 150.0
		grid.add_child(head)

	var lines := [
		["KNOCK-OUTS", "kos", "%d"],
		["FALLS", "falls", "%d"],
		["DAMAGE DEALT", "damage", "%d%%"],
	]
	for line in lines:
		grid.add_child(UI.label(line[0], 16, UI.MUTED, UI.BOLD))
		for i in rows.size():
			var value := UI.label(line[2] % int(rows[i][line[1]]), 26,
					UI.GOLD if i == winner else UI.TEXT, UI.BOLD)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(value)
	return panel
