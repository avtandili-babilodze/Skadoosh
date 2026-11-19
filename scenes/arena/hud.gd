class_name ArenaHud
extends Control
## The in-match HUD: a plate per fighter along the bottom, the big announcer
## text in the middle ("3", "FIGHT!", "GAME!"), the stage name during the
## count-in and a white flash for knock-outs.

var plates: Array[PlayerPlate] = []

var _message: Label
var _stage_name: Label
var _flash: ColorRect
var _message_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	name = "Hud"
	UI.fill(self)
	UI.no_interpolation(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	UI.fill(_flash)

	_message = UI.title("", 120)
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_message)
	UI.place(_message, Control.PRESET_FULL_RECT, 0.0, 0.0, 0.0, -120.0)
	_message.hide()

	_stage_name = UI.label("", 22, UI.TEXT, UI.BOLD)
	_stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stage_name)
	UI.place(_stage_name, Control.PRESET_TOP_WIDE, 0.0, 26.0, 0.0, 60.0)
	_stage_name.modulate.a = 0.0

	resized.connect(_layout)


func setup(fighters: Array, stocks: int) -> void:
	for plate in plates:
		plate.queue_free()
	plates.clear()
	for i in fighters.size():
		var plate := PlayerPlate.new()
		plate.setup(fighters[i].hero, fighters[i].player_index, stocks, fighters[i].get_tag())
		add_child(plate)
		plates.append(plate)
	_layout()


func update_player(index: int, damage: float, stocks: int) -> void:
	if index < plates.size():
		plates[index].set_damage(damage)
		plates[index].set_stocks(stocks)


## Pops a word into the middle of the screen. With `hold` > 0 it fades out after
## that long; with 0 it stays until the next call.
func announce(text: String, color: Color = UI.GOLD, hold: float = 0.6, size: int = 120) -> void:
	if _message_tween != null:
		_message_tween.kill()
	_message.text = text
	_message.add_theme_font_size_override("font_size", size)
	_message.add_theme_color_override("font_color", color)
	_message.add_theme_constant_override("outline_size", size / 5)
	_message.show()
	_message.modulate.a = 1.0
	_message.pivot_offset = _message.size * 0.5
	_message.scale = Vector2.ONE * 1.7
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_message_tween.tween_interval(hold)
		_message_tween.tween_property(_message, "modulate:a", 0.0, 0.18)
		_message_tween.tween_callback(_message.hide)


func clear_message() -> void:
	if _message_tween != null:
		_message_tween.kill()
	_message.hide()


## Shows the stage name for a few seconds at the top of the screen.
func show_stage_name(text: String, color: Color) -> void:
	_stage_name.text = text.to_upper()
	_stage_name.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.5))
	var tween := create_tween()
	tween.tween_property(_stage_name, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.2)
	tween.tween_property(_stage_name, "modulate:a", 0.0, 0.6)


## Marks a self-playing match and says how to leave it.
func show_demo_banner() -> void:
	var banner := UI.panel(Color(UI.INK, 0.8), UI.GOLD, 14.0)
	add_child(banner)
	UI.place(banner, Control.PRESET_CENTER_TOP, 0.0, 64.0, 0.0, 64.0)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.add_child(UI.label("DEMO   —   PRESS ANY KEY", 18, UI.GOLD, UI.BOLD))
	var blink := banner.create_tween().set_loops()
	blink.tween_property(banner, "modulate:a", 0.45, 0.7)
	blink.tween_property(banner, "modulate:a", 1.0, 0.7)


## A full-screen flash for knock-outs.
func flash(color: Color = Color.WHITE, strength: float = 0.55) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color = Color(color, strength)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.3)


func _layout() -> void:
	var gap := 26.0
	for i in plates.size():
		var plate := plates[i]
		var x := size.x * 0.5 - gap - PlayerPlate.SIZE.x if i == 0 else size.x * 0.5 + gap
		plate.position = Vector2(x, size.y - PlayerPlate.SIZE.y - 14.0)
