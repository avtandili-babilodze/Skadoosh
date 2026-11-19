extends Node2D
## The knock-out blast: a fan of light streaks fired back into the stage from
## the point where a fighter crossed the blast line.

const LIFETIME := 0.55
const STREAKS := 9

var _color: Color = Color.WHITE
var _inward: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _offsets: PackedFloat32Array = PackedFloat32Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()


func setup(color: Color, inward: Vector2) -> void:
	_color = color
	_inward = inward.normalized() if inward != Vector2.ZERO else Vector2.UP
	z_index = 30
	for i in STREAKS:
		_offsets.append(randf_range(-0.42, 0.42))
		_lengths.append(randf_range(0.55, 1.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var grow := 1.0 - pow(1.0 - t, 3.0)
	var fade := pow(1.0 - t, 1.5)
	var base := _inward.angle()
	for i in STREAKS:
		var dir := Vector2.from_angle(base + _offsets[i])
		var side := dir.orthogonal()
		var length := 1500.0 * _lengths[i] * grow
		var width := 46.0 * _lengths[i] * (1.0 - t)
		# A streak is a thin triangle: wide at the blast line, a point at its tip.
		var tint := _color.lerp(Color.WHITE, 0.55 if i % 2 == 0 else 0.1)
		draw_colored_polygon(PackedVector2Array([
			side * width, dir * length, -side * width]), Color(tint, fade * 0.85))
	draw_circle(Vector2.ZERO, 150.0 * grow, Color(1, 1, 1, fade * 0.5))
