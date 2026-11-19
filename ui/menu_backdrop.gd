class_name MenuBackdrop
extends Control
## The moving picture behind every menu: a stage background that drifts slowly,
## darkened toward the edges so text sits on it cleanly, with that stage's
## particles in the air. show_map() cross-fades to another stage, which is how
## the map select previews the stage under the cursor.

const DRIFT := 18.0          # px the picture wanders to each side
const DRIFT_PERIOD := 26.0   # seconds for one full wander
const OVERSCAN := 1.12       # picture is this much larger than the screen

var _front: TextureRect
var _back: TextureRect
var _ambient: AmbientParticles
var _time: float = 0.0
var _fade: Tween
var _map: MapData


func _ready() -> void:
	UI.fill(self)
	UI.no_interpolation(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_back = _make_picture()
	_front = _make_picture()
	_ambient = AmbientParticles.new()
	add_child(_ambient)
	UI.fill(_ambient)
	# Dark at the top and bottom, clear through the middle.
	var top := UI.shade(Color(UI.INK, 0.86), Color(UI.INK, 0.0))
	add_child(top)
	UI.place(top, Control.PRESET_TOP_WIDE, 0.0, 0.0, 0.0, 230.0)
	var bottom := UI.shade(Color(UI.INK, 0.0), Color(UI.INK, 0.94))
	add_child(bottom)
	UI.place(bottom, Control.PRESET_BOTTOM_WIDE, 0.0, -300.0, 0.0, 0.0)
	var wash := ColorRect.new()
	wash.color = Color(UI.INK, 0.28)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	UI.fill(wash)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	_layout()


## Shows a stage. The first call appears at once; later calls cross-fade.
func show_map(map: MapData, fade: float = 0.35) -> void:
	if map == null or map == _map:
		return
	var first := _map == null
	_map = map
	_ambient.configure(map.ambient, map.accent)
	if first:
		_front.texture = map.background
		return
	_back.texture = _front.texture
	_back.modulate.a = 1.0
	_front.texture = map.background
	_front.modulate.a = 0.0
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_front, "modulate:a", 1.0, fade)


func _make_picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture


func _layout() -> void:
	var picture_size := size * OVERSCAN
	var offset := (size - picture_size) * 0.5
	offset.x += sin(_time * TAU / DRIFT_PERIOD) * DRIFT
	offset.y += cos(_time * TAU / (DRIFT_PERIOD * 1.7)) * DRIFT * 0.35
	for picture: TextureRect in [_back, _front]:
		picture.position = offset
		picture.size = picture_size
