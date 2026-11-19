class_name StagePreview
extends Control
## A working miniature of a stage: the real stage art laid out exactly as it is
## in a match (platforms in place, the moving one gliding), with the two chosen
## fighters standing on their spawn points. The map select shows this so the
## layout is understood before the match starts.

## World rectangle shown, relative to the middle of the main floor.
const VIEW := Rect2(-640, -330, 1280, 560)

var map: MapData:
	set(value):
		map = value
		_time = 0.0
		_place_fighters()
		queue_redraw()

var _time: float = 0.0
var _fighters: Array[HeroPreview] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	UI.no_interpolation(self)
	for player in 2:
		var fighter := HeroPreview.new()
		fighter.facing = 1.0 if player == 0 else -1.0
		fighter.floor_margin = 0.0
		add_child(fighter)
		_fighters.append(fighter)
	set_heroes(Roster.p1_hero, Roster.p2_hero)
	resized.connect(_place_fighters)


func set_heroes(p1: HeroData, p2: HeroData) -> void:
	if _fighters.size() < 2:
		return
	_fighters[0].hero = p1
	_fighters[1].hero = p2
	_place_fighters()


func _process(delta: float) -> void:
	_time += delta
	if map != null and map.has_moving_platform():
		queue_redraw()


func _scale() -> float:
	return minf(size.x / VIEW.size.x, size.y / VIEW.size.y)


## World point → position inside this control.
func _to_local(world: Vector2) -> Vector2:
	return size * 0.5 + (world - VIEW.get_center()) * _scale()


func _place_fighters() -> void:
	if map == null or _fighters.size() < 2:
		return
	var view_scale := _scale()
	for player in 2:
		var fighter := _fighters[player]
		fighter.visible = fighter.hero != null and player < map.spawn_points.size()
		if not fighter.visible:
			continue
		fighter.zoom = view_scale
		fighter.size = Vector2(160, 160)
		var feet := _to_local(map.spawn_points[player])
		fighter.position = feet - Vector2(80, 160)


func _draw() -> void:
	if map == null:
		return
	var view_scale := _scale()
	if map.stage_texture != null:
		var art_scale := map.stage_scale() * view_scale
		draw_texture_rect(map.stage_texture, Rect2(_to_local(map.stage_origin()),
				map.stage_texture.get_size() * art_scale), false)
	if map.platform_texture == null:
		return
	var platforms: Array[Vector3] = map.platforms.duplicate()
	if map.has_moving_platform():
		var moving := map.moving_platform
		moving.x = map.moving_platform_x(_time)
		platforms.append(moving)
	for platform in platforms:
		var art_scale := map.platform_scale(platform.z) * view_scale
		draw_texture_rect(map.platform_texture, Rect2(_to_local(map.platform_origin(platform)),
				map.platform_texture.get_size() * art_scale), false)
