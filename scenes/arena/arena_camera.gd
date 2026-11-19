class_name ArenaCamera
extends Camera2D
## The match camera. It frames every fighter still in play with room to spare,
## zooming out as they separate and back in as they close, and never looks past
## the stage's blast zone. Hits add "trauma", which it plays back as shake.

## Closest and widest the camera goes.
const MAX_ZOOM := 1.0
const MIN_ZOOM := 0.5
## World pixels kept clear around the fighters: sides, above, below.
const PAD_SIDE := 370.0
const PAD_TOP := 210.0
const PAD_BOTTOM := 150.0
## How quickly it catches up with where it wants to be (higher = snappier).
const FOLLOW_SPEED := 4.2
const ZOOM_SPEED := 3.0
## Fighters are led by this many seconds of their own velocity.
const LEAD := 0.14
## How strongly the view is pulled back toward the middle of the stage (0..1),
## so a fight near one ledge still shows most of the floor.
const HOME_PULL := 0.3
const MAX_SHAKE := 20.0
const TRAUMA_DECAY := 2.4

## Fighters to keep in frame.
var targets: Array = []
## World rectangle the view must stay inside.
var bounds: Rect2 = Rect2(-1000, -800, 2000, 1300)
## Where the camera rests when nobody is in play.
var home: Vector2 = Vector2(0.0, -130.0)

var _trauma: float = 0.0
var _shake_clock: float = 0.0
var _last_usec: int = 0


func _init() -> void:
	# Following happens on physics ticks and is interpolated by the engine; the
	# shake offset is applied per drawn frame on top of that.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _ready() -> void:
	position = home
	zoom = Vector2.ONE * 0.62
	make_current()


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## Jumps straight to the ideal framing (used when a match starts).
func snap(start_zoom: float = -1.0) -> void:
	var goal := _goal()
	position = goal.position
	var z: float = goal.zoom if start_zoom <= 0.0 else start_zoom
	zoom = Vector2.ONE * z
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var goal := _goal()
	position = position.lerp(goal.position, 1.0 - exp(-FOLLOW_SPEED * delta))
	var z := lerpf(zoom.x, goal.zoom, 1.0 - exp(-ZOOM_SPEED * delta))
	zoom = Vector2.ONE * z


func _process(_delta: float) -> void:
	# Shake runs on the wall clock so it keeps rattling through hit-stop.
	var now := Time.get_ticks_usec()
	var real_delta := clampf((now - _last_usec) / 1000000.0, 0.0, 0.1) if _last_usec != 0 else 0.0
	_last_usec = now
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * real_delta)
	_shake_clock += real_delta * 46.0
	var strength := _trauma * _trauma * MAX_SHAKE
	offset = Vector2(sin(_shake_clock * 1.7) + sin(_shake_clock * 3.1 + 1.3),
			sin(_shake_clock * 2.3 + 0.6) + sin(_shake_clock * 3.7)) * 0.5 * strength


## The framing the camera is heading for: {position, zoom}.
func _goal() -> Dictionary:
	var view := get_viewport_rect().size
	var frame := Rect2()
	var found := false
	for target in targets:
		if not is_instance_valid(target) or not target.visible:
			continue
		var point: Vector2 = target.global_position
		if target is CharacterBody2D:
			point += (target as CharacterBody2D).velocity * LEAD
		# A fighter flying out of bounds must not drag the view with it.
		point = point.clamp(bounds.position, bounds.end)
		if found:
			frame = frame.expand(point)
		else:
			frame = Rect2(point, Vector2.ZERO)
			found = true
	if not found:
		frame = Rect2(home, Vector2.ZERO)
	frame = frame.grow_individual(PAD_SIDE, PAD_TOP, PAD_SIDE, PAD_BOTTOM)

	var z := clampf(minf(view.x / frame.size.x, view.y / frame.size.y), MIN_ZOOM, MAX_ZOOM)
	# Never zoom out so far that the view is larger than the bounds.
	z = maxf(z, maxf(view.x / bounds.size.x, view.y / bounds.size.y))
	var seen := view / z
	var centre := frame.get_center()
	centre.x = lerpf(centre.x, home.x, HOME_PULL)
	centre.x = _clamp_axis(centre.x, bounds.position.x, bounds.end.x, seen.x)
	centre.y = _clamp_axis(centre.y, bounds.position.y, bounds.end.y, seen.y)
	return {"position": centre, "zoom": z}


func _clamp_axis(value: float, low: float, high: float, seen: float) -> float:
	if seen >= high - low:
		return (low + high) * 0.5
	return clampf(value, low + seen * 0.5, high - seen * 0.5)
