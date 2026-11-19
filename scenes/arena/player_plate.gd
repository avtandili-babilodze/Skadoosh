class_name PlayerPlate
extends Control
## One fighter's corner of the HUD: portrait, name, the damage % (which heats
## from white to deep red as it climbs and jumps when it changes) and a pip for
## every stock, emptied as they are lost.

const SIZE := Vector2(304, 86)
const SLANT := 18.0

var hero: HeroData
var color: Color = Color.WHITE
var player_label: String = "P1"
## True for the right-hand plate, which mirrors the layout.
var mirrored: bool = false

var _damage: float = 0.0
var _stocks: int = 3
var _max_stocks: int = 3
## Extra scale on the damage number, kicked on every hit.
var _punch: float = 0.0
var _rattle: float = 0.0
## Countdown that makes the most recently lost pip flash before it goes dark.
var _lost_flash: float = 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(fighter_hero: HeroData, player: int, stocks: int, tag: String = "") -> void:
	hero = fighter_hero
	color = Roster.PLAYER_COLORS[player]
	player_label = tag if tag != "" else "P%d" % (player + 1)
	mirrored = player == 1
	_max_stocks = stocks
	_stocks = stocks
	queue_redraw()


func set_damage(value: float) -> void:
	if int(value) != int(_damage):
		if value > _damage:
			_punch = 1.0
			_rattle = 1.0
		queue_redraw()
	_damage = value


func set_stocks(value: int) -> void:
	if value < _stocks:
		_lost_flash = 1.0
	_stocks = value
	queue_redraw()


func _process(delta: float) -> void:
	if _punch > 0.0 or _rattle > 0.0 or _lost_flash > 0.0:
		_punch = maxf(0.0, _punch - delta * 4.5)
		_rattle = maxf(0.0, _rattle - delta * 5.0)
		_lost_flash = maxf(0.0, _lost_flash - delta * 1.6)
		queue_redraw()


## White at 0 %, through yellow and orange, to a dark red past 200 %.
static func damage_color(percent: float) -> Color:
	var stops := [
		[0.0, Color(1.0, 1.0, 1.0)], [40.0, Color(1.0, 0.93, 0.55)],
		[80.0, Color(1.0, 0.72, 0.25)], [130.0, Color(1.0, 0.36, 0.2)],
		[200.0, Color(0.78, 0.1, 0.16)],
	]
	for i in range(1, stops.size()):
		if percent <= stops[i][0]:
			var t := inverse_lerp(stops[i - 1][0], stops[i][0], percent)
			return (stops[i - 1][1] as Color).lerp(stops[i][1], t)
	return stops[-1][1]


func _draw() -> void:
	var w := SIZE.x
	var h := SIZE.y
	# The right-hand plate draws the same shapes through a mirror; text and the
	# portrait are placed afterwards so they are never drawn backwards.
	if mirrored:
		draw_set_transform(Vector2(w, 0.0), 0.0, Vector2(-1.0, 1.0))
	var body := PackedVector2Array([
		Vector2(SLANT, 8.0), Vector2(w, 8.0), Vector2(w - SLANT, h), Vector2(0.0, h)])
	var shadow := PackedVector2Array()
	for point in body:
		shadow.append(point + Vector2(0.0, 5.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(body, Color(UI.INK, 0.86))
	# The player's colour runs along the bottom edge.
	draw_colored_polygon(PackedVector2Array([
		Vector2(SLANT * 0.07, h - 6.0), Vector2(w - SLANT * 0.93, h - 6.0),
		Vector2(w - SLANT, h), Vector2(0.0, h)]), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Portrait in a coloured frame, on the outer side of the plate.
	var icon_size := 70.0
	var icon_x := (w - 14.0 - icon_size) if mirrored else 14.0
	var icon_rect := Rect2(icon_x, 2.0, icon_size, icon_size)
	draw_rect(icon_rect.grow(3.0), color)
	draw_rect(icon_rect, UI.PANEL)
	if hero != null and hero.icon != null:
		draw_texture_rect(hero.icon, icon_rect, false)

	var text_width := w - 96.0 - 26.0
	var text_x := 26.0 if mirrored else 96.0
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT

	var caption := "%s  %s" % [player_label, hero.hero_name.to_upper() if hero != null else ""]
	draw_string(UI.BOLD, Vector2(text_x, 27.0), caption, align, text_width, 14, color.lerp(Color.WHITE, 0.35))

	# The damage number: big, heated by damage, kicked on every hit.
	var number := "%d%%" % int(_damage)
	var number_size := int(46.0 * (1.0 + 0.28 * _punch))
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0 * _rattle
	var number_at := Vector2(text_x, 68.0 + (number_size - 46) * 0.3) + jitter
	draw_string_outline(UI.DISPLAY, number_at, number, align, text_width, number_size, 10, UI.INK)
	draw_string(UI.DISPLAY, number_at, number, align, text_width, number_size, damage_color(_damage))

	# Stocks sit beside the number at the inner end: a pip each, or a count when
	# there are too many to fit.
	var inner_x := 30.0 if mirrored else w - 30.0
	var toward_outer := 1.0 if mirrored else -1.0
	if _max_stocks > 4:
		var centre := Vector2(inner_x + toward_outer * 40.0, 55.0)
		draw_circle(centre, 6.5, UI.INK)
		draw_circle(centre, 4.5, color)
		var count_at := Vector2(centre.x + 10.0, 62.0)
		draw_string_outline(UI.BOLD, count_at, "×%d" % _stocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, UI.INK)
		draw_string(UI.BOLD, count_at, "×%d" % _stocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.TEXT)
		return
	for i in _max_stocks:
		var centre := Vector2(inner_x + toward_outer * i * 16.0, 55.0)
		var alive := i < _stocks
		var flashing := i == _stocks and _lost_flash > 0.0
		draw_circle(centre, 6.5, UI.INK)
		if alive:
			draw_circle(centre, 4.5, color)
		elif flashing:
			draw_circle(centre, 4.5 + 6.0 * (1.0 - _lost_flash), Color(1, 1, 1, _lost_flash))
		else:
			draw_circle(centre, 4.5, Color(UI.PANEL_HI, 0.9))
