extends Node2D
## A hit's damage, popped above the victim: it jumps up, hangs and fades. Bigger
## hits get bigger numbers, so the weight of a blow reads at a glance.

const LIFETIME := 0.7

var _text: String = ""
var _color: Color = Color.WHITE
var _size: int = 22
var _age: float = 0.0
var _drift: Vector2 = Vector2.ZERO


func setup(damage: float, color: Color, dir: float) -> void:
	_text = "%d%%" % maxi(1, roundi(damage))
	_color = color.lerp(Color.WHITE, 0.55)
	_size = int(clampf(18.0 + damage * 1.1, 18.0, 40.0))
	_drift = Vector2(dir * 26.0, -70.0)
	z_index = 25


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Fast at first, then it hangs: the classic pop.
	position += _drift * delta * maxf(0.0, 1.0 - _age / LIFETIME * 1.4) * 2.2
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - t * 6.0)
	var alpha := 1.0 - maxf(0.0, t - 0.6) / 0.4
	var size := int(_size * pop)
	var font := UI.DISPLAY
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-width * 0.5, 0.0)
	draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(UI.INK, alpha))
	draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(_color, alpha))
