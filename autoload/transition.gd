extends CanvasLayer
## Scene changes with a wipe (autoloaded as "Transition").
##
## Transition.to("res://scenes/arena.tscn") slides a slanted curtain across the
## screen, swaps the scene behind it, then slides the curtain away. Input that
## arrives mid-wipe is ignored by checking Transition.busy.

const WIPE_TIME := 0.26
const CURTAIN_COLOR := Color(0.051, 0.043, 0.078)
const EDGE_COLOR := Color(1.0, 0.81, 0.23)

## True from the moment a change is requested until the new scene is revealed.
var busy: bool = false

var _curtain: Polygon2D
var _edge: Polygon2D
## 0 = curtain parked off the left side, 1 = covering the screen, 2 = gone right.
var _progress: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_edge = Polygon2D.new()
	_edge.color = EDGE_COLOR
	add_child(_edge)
	_curtain = Polygon2D.new()
	_curtain.color = CURTAIN_COLOR
	add_child(_curtain)
	_set_progress(0.0)


func to(scene_path: String) -> void:
	if busy:
		return
	busy = true
	# A paused tree (the pause menu) must not survive into the next scene.
	get_tree().paused = false
	Engine.time_scale = 1.0
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file(scene_path)
		busy = false
		return
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, WIPE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	# One idle frame lets the new scene build before it is revealed.
	tween.tween_interval(0.06)
	tween.tween_method(_set_progress, 1.0, 2.0, WIPE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): busy = false)


func reload() -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != "":
		to(current.scene_file_path)


func _set_progress(value: float) -> void:
	_progress = value
	var view := get_viewport().get_visible_rect().size
	var slant := view.y * 0.35
	var span := view.x + slant * 2.0
	# The curtain is a parallelogram wider than the screen that travels left to
	# right: parked off the left edge at 0, covering every corner at 1, gone at 2.
	var left := lerpf(-span - slant, -slant, value)
	if value > 1.0:
		left = lerpf(-slant, view.x, value - 1.0)
	var quad := func(x0: float, x1: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(x0 + slant, -4.0), Vector2(x1 + slant, -4.0),
			Vector2(x1, view.y + 4.0), Vector2(x0, view.y + 4.0)])
	_curtain.polygon = quad.call(left, left + span)
	_edge.polygon = quad.call(left - 14.0, left + span + 14.0)
	visible = value > 0.001 and value < 1.999
