extends RefCounted
## Scenes: every screen starts up with what it needs, each stage builds a floor
## fighters can stand on, and the match rules above the fighters (ring-outs,
## stocks, respawns, pass-through platforms) behave.

const ARENA_SCENE := preload("res://scenes/arena.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/character_select.tscn")
const MAP_SELECT_SCENE := preload("res://scenes/map_select.tscn")
const TITLE_SCENE := preload("res://scenes/title.tscn")

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	await _test_menus()
	await _test_character_select()
	await _test_stages()
	await _test_ring_out_and_respawn()
	await _test_platform_drop_through()
	await _test_moving_platform()
	await _test_ledge_help()
	Roster.map = null
	return true


func _test_menus() -> void:
	var title = TITLE_SCENE.instantiate()
	t.add_child(title)
	await t.get_tree().process_frame
	t.check(title.get_node_or_null("Menu") != null and title.get_node("Menu").get_child_count() == 5,
			"the title screen builds its main menu with one- and two-player entries")
	t.check(title.get_node_or_null("HowToPlay") != null and title.get_node_or_null("Settings") != null,
			"the title screen carries its how-to-play and settings panels")
	title.queue_free()
	await t.get_tree().process_frame

	t.check(Roster.maps.size() >= 3, "several stages are selectable")
	var map_select = MAP_SELECT_SCENE.instantiate()
	t.add_child(map_select)
	await t.get_tree().process_frame
	t.check(map_select.find_child("Stages", true, false).get_child_count() == Roster.maps.size() + 1,
			"the map select shows a card for every stage plus a random pick")
	map_select.queue_free()
	await t.get_tree().process_frame


func _test_character_select() -> void:
	# Exercise the select screen with a roster much larger than the current game.
	# Reusing hero resources keeps this test lightweight while proving the layout wraps.
	var original_roster_size := Roster.heroes.size()
	while Roster.heroes.size() < 20:
		Roster.heroes.append(Roster.heroes[Roster.heroes.size() % original_roster_size])
	var character_select = CHARACTER_SELECT_SCENE.instantiate()
	t.add_child(character_select)
	await t.get_tree().process_frame
	t.check(character_select.get_child_count() > 0, "character-select UI builds successfully")
	var roster_scroll: ScrollContainer = character_select.get_node("RosterScroll")
	var hero_grid: GridContainer = roster_scroll.get_node("GridCenter/HeroGrid")
	t.check(hero_grid.get_child_count() == Roster.heroes.size(),
			"character select creates a card for every fighter in a large roster")
	t.check(hero_grid.columns > 1 and hero_grid.columns < Roster.heroes.size(),
			"large rosters wrap into a responsive multi-row grid")
	character_select._index[0] = 0
	character_select._move(0, -1, 0)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check(roster_scroll.scroll_vertical > 0,
			"the roster automatically scrolls to an off-screen selected fighter")
	character_select._index[0] = 0
	character_select._move(0, 0, 1)
	t.check(character_select._index[0] == hero_grid.columns,
			"moving down lands on the fighter directly below")
	character_select._set_lock(0, true)
	t.check(character_select._locked[0] and not character_select._started,
			"one player locking in does not start the match alone")
	character_select.queue_free()
	await t.get_tree().process_frame
	Roster.heroes.resize(original_roster_size)


## Every stage must give both fighters solid ground at their spawn points, keep
## those points inside the blast zone, and build the platforms its data lists.
func _test_stages() -> void:
	for map: MapData in Roster.maps:
		Roster.map = map
		var arena = ARENA_SCENE.instantiate()
		t.add_child(arena)
		for i in 30:
			await t.get_tree().physics_frame
		t.check(arena.get_node_or_null("Player1") != null and arena.get_node_or_null("Player2") != null,
				"%s creates both players" % map.map_name)
		t.check(arena.get_node_or_null("HUD/Hud/Message") != null, "%s creates its HUD" % map.map_name)
		t.check(arena.get_node_or_null("Stage/Ground") != null, "%s builds its main floor" % map.map_name)
		var platforms := 0
		for child in arena.get_node("Stage").get_children():
			if String(child.name).begins_with("Platform") or child.name == &"MovingPlatform":
				platforms += 1
		var expected := map.platforms.size() + (1 if map.has_moving_platform() else 0)
		t.check(platforms == expected, "%s builds every platform in its layout" % map.map_name)
		for player: Fighter in [arena.get_node("Player1"), arena.get_node("Player2")]:
			t.check(player.is_on_floor() and absf(player.get_feet().y) < 2.0,
					"%s stands %s on its floor line" % [map.map_name, player.name])
			t.check(map.blast_zone.has_point(player.global_position),
					"%s spawns %s inside the blast zone" % [map.map_name, player.name])
		for platform in map.platforms:
			t.check(platform.y < -90.0 and absf(platform.x) + platform.z * 0.5 <= map.stage_width * 0.5 + 60.0,
					"%s keeps its platforms above and over the floor" % map.map_name)
		arena.queue_free()
		await t.get_tree().process_frame
	await t.get_tree().create_timer(0.05).timeout


## Leaving the blast zone costs a stock and credits the last attacker; the fighter
## drops back in clean, and losing the last stock ends the match.
func _test_ring_out_and_respawn() -> void:
	Roster.map = Roster.maps[0]
	var arena = ARENA_SCENE.instantiate()
	arena.starting_lives = 2
	t.add_child(arena)
	await t.get_tree().physics_frame
	arena._begin_fight()
	var attacker: Fighter = arena.get_node("Player1")
	var victim: Fighter = arena.get_node("Player2")
	t.check(victim.take_hit(10.0, 200.0, 1.0, 0.1, attacker), "a fighter in a match accepts a hit")
	t.check(attacker.damage_dealt > 0.0, "damage dealt is tracked for the results screen")
	victim.global_position = arena.map.blast_zone.end + Vector2(40.0, -200.0)
	await t.get_tree().physics_frame
	await t.get_tree().physics_frame
	t.check(arena._lives[1] == 1, "leaving the blast zone costs a stock")
	t.check(arena._kos[0] == 1 and arena._falls[1] == 1, "the knock-out is credited to the last attacker")
	t.check(not victim.visible, "a knocked-out fighter leaves play until it respawns")
	await t.get_tree().create_timer(arena.RESPAWN_DELAY + 0.2).timeout
	t.check(victim.visible and victim.damage_taken == 0.0 and victim.is_invincible(),
			"the fighter drops back in clean and briefly invincible")
	t.check(arena.map.blast_zone.has_point(victim.global_position),
			"the respawn point is inside the blast zone")
	victim.global_position = arena.map.blast_zone.position - Vector2(40.0, -200.0)
	await t.get_tree().physics_frame
	await t.get_tree().physics_frame
	t.check(arena._lives[1] == 0 and arena.phase == arena.Phase.FINISH,
			"losing the last stock ends the match")
	t.check(not attacker.controls_enabled, "the winner's controls are released when the match ends")
	arena.queue_free()
	await t.get_tree().process_frame
	t.check(is_equal_approx(Engine.time_scale, 1.0), "leaving a match restores normal game speed")


## Platforms hold a fighter from above, and a tap of down drops through them.
func _test_platform_drop_through() -> void:
	var map: MapData = null
	for candidate: MapData in Roster.maps:
		if not candidate.platforms.is_empty():
			map = candidate
			break
	t.check(map != null, "at least one stage has fixed platforms")
	if map == null:
		return
	Roster.map = map
	var arena = ARENA_SCENE.instantiate()
	t.add_child(arena)
	await t.get_tree().physics_frame
	var fighter: Fighter = arena.get_node("Player1")
	var platform := map.platforms[0]
	fighter.global_position = Vector2(platform.x, platform.y - 90.0)
	fighter.velocity = Vector2.ZERO
	for i in 90:
		await t.get_tree().physics_frame
		if fighter.is_on_floor():
			break
	t.check(fighter.is_on_floor() and absf(fighter.get_feet().y - platform.y) < 2.0,
			"a fighter falling onto a platform lands on it")
	fighter._drop_time_left = fighter.DROP_TIME
	fighter.position.y += 2.0
	for i in 60:
		await t.get_tree().physics_frame
	t.check(fighter.get_feet().y > platform.y + 20.0,
			"dropping through lets the fighter fall past the platform")
	arena.queue_free()
	await t.get_tree().process_frame


## The gliding platform keeps its height, travels side to side, and carries a
## fighter standing on it.
func _test_moving_platform() -> void:
	var map: MapData = null
	for candidate: MapData in Roster.maps:
		if candidate.has_moving_platform():
			map = candidate
			break
	t.check(map != null, "at least one stage has a moving platform")
	if map == null:
		return
	Roster.map = map
	var arena = ARENA_SCENE.instantiate()
	t.add_child(arena)
	await t.get_tree().physics_frame
	var platform: Node2D = arena.get_node("Stage/MovingPlatform")
	var fighter: Fighter = arena.get_node("Player1")
	fighter.global_position = Vector2(platform.global_position.x, map.moving_platform.y - 80.0)
	fighter.velocity = Vector2.ZERO
	for i in 90:
		await t.get_tree().physics_frame
		if fighter.is_on_floor():
			break
	t.check(fighter.is_on_floor() and absf(fighter.get_feet().y - map.moving_platform.y) < 2.0,
			"a fighter lands on the moving platform at its height")
	var start_x := platform.global_position.x
	var offset := fighter.global_position.x - start_x
	Engine.time_scale = 3.0
	for i in 240:
		await t.get_tree().physics_frame
	Engine.time_scale = 1.0
	t.check(absf(platform.global_position.y - map.moving_platform.y) < 0.5,
			"the moving platform holds its height")
	t.check(absf(platform.global_position.x - start_x) > 30.0, "the moving platform travels")
	t.check(fighter.is_on_floor() and absf(fighter.global_position.x - platform.global_position.x - offset) < 12.0,
			"the moving platform carries the fighter standing on it")
	arena.queue_free()
	await t.get_tree().process_frame


## A recovery that reaches the ledge wall just below the top is pulled up onto
## the stage; one that arrives well below it is not.
func _test_ledge_help() -> void:
	Roster.map = Roster.maps[0]
	var arena = ARENA_SCENE.instantiate()
	t.add_child(arena)
	await t.get_tree().physics_frame
	var fighter: Fighter = arena.get_node("Player1")
	var half: float = arena.map.stage_width * 0.5
	var cases := [[24.0, true], [fighter.LEDGE_HELP + 45.0, false]]
	for case in cases:
		var below: float = case[0]
		# Feet `below` px under the floor line, just outside the right ledge, drifting in.
		fighter.global_position = Vector2(half + 34.0, below - fighter.visuals.ground_offset)
		fighter.velocity = Vector2(-260.0, 0.0)
		fighter.reset_physics_interpolation()
		var landed := false
		for i in 40:
			await t.get_tree().physics_frame
			if fighter.is_on_floor() and absf(fighter.get_feet().y) < 2.0:
				landed = true
				break
			fighter.velocity.x = -260.0
		if case[1]:
			t.check(landed and fighter.global_position.x < half,
					"a fighter %d px below the ledge is pulled up onto the stage" % int(below))
		else:
			t.check(not landed, "a fighter %d px below the ledge gets no help" % int(below))
	arena.queue_free()
	await t.get_tree().process_frame
