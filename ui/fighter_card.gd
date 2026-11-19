class_name FighterCard
extends PanelContainer
## One player's side of the character select: the fighter under their cursor,
## alive and animated, with its name, pitch, stats and two skills, and a plate
## that says how to lock in (or that they are ready).

var player: int = 0
var color: Color = Color.WHITE

var _preview: HeroPreview
var _name: Label
var _description: Label
var _stats: Dictionary = {}
var _light: Label
var _heavy: Label
var _status: Label
var _status_plate: PanelContainer
var _style: StyleBoxFlat
var _locked: bool = false
var _lock_key: String = ""


## `caption` names the card ("PLAYER 1", "CPU"); `lock_key` is the key shown on
## the lock-in plate.
func setup(player_index: int, lock_key: String, caption: String = "") -> void:
	player = player_index
	color = Roster.PLAYER_COLORS[player]
	_lock_key = lock_key
	if caption == "":
		caption = "PLAYER %d" % (player + 1)
	custom_minimum_size = Vector2(300, 0)
	_style = UI.box(Color(UI.INK, 0.78), Color(color, 0.85), 2, 10)
	_style.content_margin_left = 16.0
	_style.content_margin_right = 16.0
	_style.content_margin_top = 10.0
	_style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)

	# Header: the player tag on the outer side, the lock-in plate beside it.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var tag := UI.label(caption, 20, color, UI.BOLD)
	_status_plate = PanelContainer.new()
	_status_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = UI.label("", 15, UI.TEXT, UI.BOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_plate.add_child(_status)
	if player == 0:
		header.add_child(tag)
		header.add_child(_status_plate)
	else:
		header.add_child(_status_plate)
		header.add_child(tag)

	_preview = HeroPreview.new()
	_preview.custom_minimum_size = Vector2(268, 200)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.zoom = 1.7
	_preview.facing = 1.0 if player == 0 else -1.0
	column.add_child(_preview)

	_name = UI.title("", 38, UI.TEXT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.clip_text = true
	column.add_child(_name)

	_description = UI.label("", 14, UI.MUTED, UI.MEDIUM)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(268, 46)
	_description.max_lines_visible = 2
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_description)

	for stat: String in ["SPEED", "POWER", "DEFENSE", "RANGE"]:
		var bar := StatBar.new(stat, color)
		column.add_child(bar)
		_stats[stat] = bar

	_light = UI.label("", 15, UI.TEXT, UI.SEMI)
	_heavy = UI.label("", 15, UI.TEXT, UI.SEMI)
	for skill: Label in [_light, _heavy]:
		skill.clip_text = true
		column.add_child(skill)

	set_locked(false)


func show_hero(hero: HeroData) -> void:
	if hero == null or _preview.hero == hero:
		return
	_preview.hero = hero
	_name.text = hero.hero_name.to_upper()
	_description.text = hero.description
	_stats["SPEED"].value = inverse_lerp(170.0, 420.0, hero.speed)
	_stats["DEFENSE"].value = 0.12 + hero.defense / 8.5
	var power := 0.0
	var reach := 0.0
	for skill: AttackData in [hero.light_attack, hero.heavy_attack]:
		if skill == null:
			continue
		power += skill.damage * (1.0 + skill.knockback / 900.0)
		match skill.kind:
			AttackData.Kind.RANGED:
				reach = maxf(reach, skill.projectile_range)
			AttackData.Kind.GROUND_SPIKE:
				reach = maxf(reach, skill.ground_spike_distance + 60.0)
			_:
				reach = maxf(reach, skill.reach)
	_stats["POWER"].value = inverse_lerp(18.0, 42.0, power)
	_stats["RANGE"].value = inverse_lerp(40.0, 560.0, reach)
	_light.text = "LIGHT   %s" % (hero.light_attack.skill_name if hero.light_attack != null else "—")
	_heavy.text = "HEAVY   %s" % (hero.heavy_attack.skill_name if hero.heavy_attack != null else "—")


## `waiting` replaces the lock-in prompt with a note that this card's turn
## comes later (the CPU's fighter is picked after the player's own).
func set_locked(locked: bool, waiting: bool = false) -> void:
	_locked = locked
	var plate := UI.box(UI.GOLD if locked else Color(UI.PANEL_HI, 0.9), Color.TRANSPARENT, 0, 4, UI.SKEW)
	plate.content_margin_top = 4.0
	plate.content_margin_bottom = 4.0
	_status_plate.add_theme_stylebox_override("panel", plate)
	_status.text = "READY!" if locked else "%s  TO LOCK IN" % _lock_key
	if waiting and not locked:
		_status.text = "PICKED NEXT"
	_status.add_theme_color_override("font_color", UI.INK if locked else UI.TEXT)
	_style.border_color = UI.GOLD if locked else Color(color, 0.85)
	_style.set_border_width_all(3 if locked else 2)
	_style.bg_color = Color(UI.INK, 0.9 if locked else 0.78)
