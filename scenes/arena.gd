extends Node2D
## Match manager. Builds the chosen stage from its MapData (floor, platforms,
## sky), runs the match from count-in to results, and owns the rules that sit
## above the fighters: stocks, ring-outs past the blast zone, respawns and who
## gets credit for a knock-out.

enum Phase { INTRO, FIGHT, FINISH, RESULTS }

## Seconds between a knock-out and the fighter dropping back in.
const RESPAWN_DELAY := 0.9
## A ring-out is credited to whoever landed a hit within this long before it.
const KO_CREDIT_MS := 7000
## Half a fighter's collision box: feet sit this far below its centre.
const FEET := 50.0
## Height above the floor that fighters drop in from after a knock-out.
const RESPAWN_HEIGHT := 330.0
## How far the sky slides against the camera (0 = pinned, 1 = moves with the world).
const SKY_PARALLAX := 0.045
const SKY_OVERSCAN := 1.16
const TITLE_SCENE := "res://scenes/title.tscn"

## Lives (stocks) each fighter starts with. 0 uses the Settings value.
@export var starting_lives: int = 0

## The stage being played.
var map: MapData
var phase: Phase = Phase.INTRO

var _players: Array[Fighter] = []   # index 0 = Player 1, 1 = Player 2
var _lives: Array[int] = []         # parallel to _players
var _kos: Array[int] = []
var _falls: Array[int] = []
var _respawns: Array = []           # [{index, left}] fighters waiting to drop back in
var _clock: float = 0.0             # match time, drives the moving platform

var _camera: ArenaCamera
var _hud: ArenaHud
var _pause: PauseMenu
var _sky: TextureRect
var _sky_holder: Control
var _moving_platform: AnimatableBody2D


func _enter_tree() -> void:
	# Apply the picks made on the character-select screen. This runs before the
	# Player children's _ready (parent enters the tree first), so the override
	# lands before they read their hero. When the arena is launched directly the
	# picks are null and the heroes wired into the scene are kept.
	if Roster.p1_hero != null:
		$Player1.hero = Roster.p1_hero
	if Roster.p2_hero != null:
		$Player2.hero = Roster.p2_hero
	$Player1.player_index = 0
	$Player2.player_index = 1
	if Roster.cpu_opponent:
		$Player2.tag = "CPU"
	if Roster.demo:
		$Player1.tag = "CPU"


func _ready() -> void:
	add_to_group("arena")
	map = Roster.current_map()
	if map == null:
		map = MapData.new()

	_build_sky()
	_build_stage()

	_players = [$Player1 as Fighter, $Player2 as Fighter]
	if Roster.cpu_opponent:
		_players[1].input = FighterBrain.new(Settings.cpu_level, map)
	if Roster.demo:
		# The demo plays itself: two hard CPUs.
		for fighter in _players:
			fighter.input = FighterBrain.new(FighterBrain.Level.HARD, map)
	var stocks := starting_lives if starting_lives > 0 else Settings.stocks
	for i in _players.size():
		_lives.append(maxi(1, stocks))
		_kos.append(0)
		_falls.append(0)
		var feet := map.spawn_points[i] if i < map.spawn_points.size() else Vector2.ZERO
		var fighter := _players[i]
		fighter.global_position = feet - Vector2(0.0, FEET + 1.0)
		fighter.face(-feet.x if feet.x != 0.0 else (1.0 if i == 0 else -1.0))
		fighter.reset_physics_interpolation()

	var effects := Node2D.new()
	effects.name = "Effects"
	effects.z_index = 10
	add_child(effects)

	_camera = ArenaCamera.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.targets = _players
	_camera.bounds = map.blast_zone.grow(-30.0)
	_camera.snap(0.6)
	Fx.bind(effects, _camera)

	_build_hud(stocks)
	_update_hud()
	if Roster.demo:
		_hud.show_demo_banner()
	_start_intro()


func _exit_tree() -> void:
	Fx.unbind()


func _unhandled_input(event: InputEvent) -> void:
	if Roster.demo:
		# Any key or button ends the demo.
		if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
			_leave_demo()
		return
	if event.is_action_pressed("pause") and (phase == Phase.FIGHT or phase == Phase.INTRO):
		_pause.open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_sky()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _moving_platform != null:
		_moving_platform.position = Vector2(map.moving_platform_x(_clock), map.moving_platform.y)

	for i in range(_respawns.size() - 1, -1, -1):
		_respawns[i].left -= delta
		if _respawns[i].left <= 0.0:
			_drop_in(_respawns[i].index)
			_respawns.remove_at(i)

	if phase == Phase.FIGHT:
		for i in _players.size():
			# A fighter waiting to respawn is hidden and cannot ring out again.
			if _lives[i] <= 0 or not _players[i].visible:
				continue
			if not map.blast_zone.has_point(_players[i].global_position):
				_ring_out(i)
	_update_hud()


# --- Match flow -----------------------------------------------------------------

func _start_intro() -> void:
	phase = Phase.INTRO
	for fighter in _players:
		fighter.controls_enabled = false
	Music.battle_mode()
	_hud.show_stage_name(map.map_name, map.accent)
	var count := create_tween()
	count.tween_interval(0.55)
	for word: String in ["3", "2", "1"]:
		count.tween_callback(func():
			_hud.announce(word, UI.TEXT, 0.3, 130)
			Sfx.play("count_beep", -4.0, 1.0, 0.0))
		count.tween_interval(0.6)
	count.tween_callback(_begin_fight)


func _begin_fight() -> void:
	phase = Phase.FIGHT
	for fighter in _players:
		fighter.controls_enabled = true
	_hud.announce("FIGHT!", UI.GOLD, 0.5, 150)
	Sfx.play("count_go", -2.0, 1.0, 0.0)


func _ring_out(i: int) -> void:
	var fighter := _players[i]
	var zone := map.blast_zone
	var at := fighter.global_position.clamp(zone.position, zone.end)
	var travel := fighter.velocity
	if travel.length() < 60.0:
		travel = fighter.global_position - zone.get_center()

	_falls[i] += 1
	var by := _players.find(fighter.last_attacker as Fighter)
	if by >= 0 and by != i and Time.get_ticks_msec() - fighter.last_hit_ms < KO_CREDIT_MS:
		_kos[by] += 1

	var color := fighter.get_player_color()
	Fx.knock_out(at, travel.normalized(), color)
	_hud.flash(color.lerp(Color.WHITE, 0.6), 0.4)

	_lives[i] -= 1
	if _lives[i] > 0:
		fighter.vanish()
		_respawns.append({"index": i, "left": RESPAWN_DELAY})
	else:
		fighter.eliminate()
	_check_game_over()


func _drop_in(i: int) -> void:
	if phase != Phase.FIGHT or _lives[i] <= 0:
		return
	var spawn := map.spawn_points[i] if i < map.spawn_points.size() else Vector2.ZERO
	var at := Vector2(spawn.x * 0.45, -RESPAWN_HEIGHT)
	_players[i].respawn(at)
	# A ring of light in the player's colour marks where they come back in.
	var color := _players[i].get_player_color().lerp(Color.WHITE, 0.4)
	for angle in [0.0, 0.25, 0.5, 0.75]:
		Fx.burst(at, color, 6, 300.0, Vector2.from_angle(TAU * angle), 46.0, 0.45, 5.0, 0.0)
	Sfx.play("respawn", -6.0, 1.0, 0.0)


func _check_game_over() -> void:
	var alive: Array[int] = []
	for i in _players.size():
		if _lives[i] > 0:
			alive.append(i)
	if alive.size() > 1:
		return
	phase = Phase.FINISH
	var winner := alive[0] if alive.size() == 1 else -1
	for fighter in _players:
		fighter.controls_enabled = false
	get_tree().call_group("projectiles", "queue_free")
	Fx.slow_motion(0.2, 1.3)
	Music.menu_mode(1.0)
	_hud.announce("GAME!", UI.GOLD, 0.0, 170)
	# The results wait on the wall clock, not on the slowed game clock.
	get_tree().create_timer(1.6, true, false, true).timeout.connect(_show_results.bind(winner))


func _leave_demo() -> void:
	Roster.demo = false
	Roster.cpu_opponent = false
	Roster.p1_hero = null
	Roster.p2_hero = null
	Roster.map = null
	Transition.to(TITLE_SCENE)


func _show_results(winner: int) -> void:
	if phase != Phase.FINISH:
		return
	if Roster.demo:
		_leave_demo()
		return
	phase = Phase.RESULTS
	_hud.hide()
	Sfx.play("win", -3.0, 1.0, 0.0)
	var rows: Array = []
	for i in _players.size():
		rows.append({
			"hero": _players[i].hero, "player": _players[i].player_index,
			"kos": _kos[i], "falls": _falls[i], "damage": _players[i].damage_dealt,
		})
	var results := ResultsScreen.new()
	$HUD.add_child(results)
	results.present(rows, winner)


func _update_hud() -> void:
	for i in _players.size():
		_hud.update_player(i, _players[i].damage_taken, _lives[i])


# --- Building the stage ---------------------------------------------------------

## The sky: a picture on its own canvas layer behind the world, larger than the
## screen so it can slide a little against the camera, with the stage's
## particles drifting in front of it.
func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -10
	add_child(layer)
	_sky_holder = Control.new()
	_sky_holder.clip_contents = true
	_sky_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.no_interpolation(_sky_holder)
	layer.add_child(_sky_holder)
	UI.fill(_sky_holder)

	_sky = TextureRect.new()
	_sky.texture = map.background
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_holder.add_child(_sky)

	var air := AmbientParticles.new()
	air.configure(map.ambient, map.accent.lerp(Color.WHITE, 0.25))
	_sky_holder.add_child(air)
	UI.fill(air)


func _update_sky() -> void:
	if _sky == null or _camera == null:
		return
	var view := _sky_holder.size
	var picture := view * SKY_OVERSCAN
	var slack := (picture - view) * 0.5
	var slide := -(_camera.position - _camera.home) * SKY_PARALLAX
	slide = slide.clamp(-slack, slack)
	_sky.size = picture
	_sky.position = -slack + slide


func _build_stage() -> void:
	var stage := Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	move_child(stage, 0)

	# Main floor: solid, shaped like the art (a deck that tapers underneath), so
	# fighters cannot hide inside the hull.
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = Fighter.SOLID_MASK
	ground.collision_mask = 0
	stage.add_child(ground)
	var half := map.stage_width * 0.5
	var depth := 150.0
	if map.stage_texture != null:
		ground.add_child(_art(map.stage_texture, map.stage_origin(), map.stage_scale()))
		depth = map.stage_texture.get_height() * map.stage_scale() * 0.8
	var hull := ConvexPolygonShape2D.new()
	hull.points = PackedVector2Array([
		Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(half - 12.0, 26.0),
		Vector2(half * 0.3, depth), Vector2(-half * 0.3, depth), Vector2(-half + 12.0, 26.0)])
	var ground_shape := CollisionShape2D.new()
	ground_shape.shape = hull
	ground.add_child(ground_shape)

	for i in map.platforms.size():
		var body := StaticBody2D.new()
		body.name = "Platform%d" % (i + 1)
		_fit_platform(body, map.platforms[i])
		stage.add_child(body)

	if map.has_moving_platform():
		_moving_platform = AnimatableBody2D.new()
		_moving_platform.name = "MovingPlatform"
		_moving_platform.sync_to_physics = true
		_fit_platform(_moving_platform, map.moving_platform)
		stage.add_child(_moving_platform)


## Turns a body into a pass-through platform (x = centre, y = top, z = width):
## it only collides from above, and fighters can drop through it.
func _fit_platform(body: PhysicsBody2D, platform: Vector3) -> void:
	body.position = Vector2(platform.x, platform.y)
	body.collision_layer = Fighter.PLATFORM_MASK
	body.collision_mask = 0
	if map.platform_texture != null:
		var local := Vector3(0.0, 0.0, platform.z)
		body.add_child(_art(map.platform_texture, map.platform_origin(local), map.platform_scale(platform.z)))
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform.z, 14.0)
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(0.0, 7.0)
	shape.one_way_collision = true
	body.add_child(shape)


func _art(texture: Texture2D, origin: Vector2, art_scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = origin
	sprite.scale = Vector2.ONE * art_scale
	return sprite


func _build_hud(stocks: int) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)

	var pointers := Node2D.new()
	pointers.name = "TopPointers"
	pointers.set_script(preload("res://scenes/top_pointers.gd"))
	layer.add_child(pointers)

	_hud = ArenaHud.new()
	layer.add_child(_hud)
	_hud.setup(_players, stocks)

	_pause = PauseMenu.new()
	layer.add_child(_pause)
