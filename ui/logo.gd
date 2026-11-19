class_name Logo
extends Control
## The SKADOOSH wordmark: comic lettering punched out of a spiky impact burst,
## the way a hit sound is lettered in a comic panel. It lands with a bounce and
## then breathes slowly. `scale_factor` sizes the whole mark.

const WORD := "SKADOOSH"
const TAGLINE := "PLATFORM  FIGHTER"
const SPIKES := 22

var scale_factor: float = 1.0

var _time: float = 0.0
var _land: float = 0.0           # 0 → 1 while the mark drops in
var _radii: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.no_interpolation(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in SPIKES * 2:
		# Outer points vary in reach so the burst looks hand-cut, not stamped.
		_radii.append(rng.randf_range(0.86, 1.12) if i % 2 == 0 else rng.randf_range(0.60, 0.70))
	create_tween().tween_property(self, "_land", 1.0, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var breathe := 1.0 + sin(_time * 1.6) * 0.012
	var s := scale_factor * breathe * lerpf(0.2, 1.0, _land)
	var tilt := deg_to_rad(-5.0) + sin(_time * 0.9) * 0.006

	var burst := func(radius_x: float, radius_y: float, spin: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in SPIKES * 2:
			var angle := spin + TAU * i / float(SPIKES * 2)
			points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y) * _radii[i] * s)
		return points

	# Ink shadow, hot burst, then a paler inner burst for depth.
	var spin := tilt + _time * 0.035
	var shadow: PackedVector2Array = burst.call(372.0, 150.0, spin)
	for i in shadow.size():
		shadow[i] += Vector2(9.0, 11.0) * s
	draw_colored_polygon(shadow, Color(UI.INK, 0.75))
	draw_colored_polygon(burst.call(372.0, 150.0, spin), UI.INK)
	draw_colored_polygon(burst.call(356.0, 138.0, spin), UI.HOT)
	draw_colored_polygon(burst.call(300.0, 108.0, spin + 0.07), Color(1.0, 0.45, 0.32))

	var font := UI.DISPLAY
	var size_px := int(150.0 * s)
	if size_px < 4:
		return
	var text_size := font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_set_transform(centre, tilt, Vector2.ONE)
	var origin := Vector2(-text_size.x * 0.5, text_size.y * 0.30)
	# Hard drop shadow, thick ink outline, then the gold face.
	draw_string_outline(font, origin + Vector2(8, 10) * s, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size_px, int(26 * s), Color(0, 0, 0, 0.6))
	draw_string_outline(font, origin, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(26 * s), UI.INK)
	draw_string(font, origin, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UI.GOLD)
	# A white glint along the top of the letters.
	draw_string(font, origin + Vector2(0, -5) * s, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
			Color(1, 1, 1, 0.16))

	var tag_px := int(22.0 * s)
	if tag_px >= 6:
		var tag_size := UI.BOLD.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_px)
		var plate := Rect2(Vector2(-tag_size.x * 0.5 - 18 * s, 62 * s), Vector2(tag_size.x + 36 * s, 34 * s))
		draw_rect(plate, UI.INK)
		draw_string(UI.BOLD, Vector2(-tag_size.x * 0.5, 62 * s + 25 * s), TAGLINE,
				HORIZONTAL_ALIGNMENT_LEFT, -1, tag_px, UI.TEXT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
