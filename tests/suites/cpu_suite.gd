extends RefCounted
## The CPU opponent: it fights (closes the distance and lands hits), it gets
## back to the stage when knocked off, and it does not walk off a ledge.

const ARENA_SCENE := preload("res://scenes/arena.tscn")

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	for level in [FighterBrain.Level.EASY, FighterBrain.Level.HARD]:
		await _test_cpu_fights(level)
	await _test_cpu_recovers()
	await _test_cpu_respects_ledges()
	Roster.cpu_opponent = false
	Roster.map = null
	Roster.p1_hero = null
	Roster.p2_hero = null
	return true


func _start_match(cpu_hero: HeroData = null) -> Node:
	Roster.cpu_opponent = true
	Roster.map = Roster.maps[0]
	Roster.p2_hero = cpu_hero
	var arena = ARENA_SCENE.instantiate()
	arena.starting_lives = 3
	t.add_child(arena)
	await t.get_tree().physics_frame
	arena._begin_fight()
	return arena


## Runs physics until `done` returns true or `seconds` of game time pass.
func _run_until(done: Callable, seconds: float) -> bool:
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		await t.get_tree().physics_frame
		if done.call():
			return true
	return false


func _test_cpu_fights(level: int) -> void:
	var saved_level := Settings.cpu_level
	Settings.cpu_level = level
	# Every fighter must be playable by the CPU: each one has to land a hit on a
	# rival who just stands there.
	for hero: HeroData in Roster.heroes:
		var arena = await _start_match(hero)
		var player: Fighter = arena.get_node("Player1")
		var cpu: Fighter = arena.get_node("Player2")
		t.check(cpu.input is FighterBrain, "a one-player match hands Player 2 to the CPU")
		Engine.time_scale = 4.0
		var landed := await _run_until(func(): return player.damage_taken > 0.0, 12.0)
		Engine.time_scale = 1.0
		t.check(landed, "the level-%d CPU lands a hit as %s" % [level, hero.hero_name])
		arena.queue_free()
		await t.get_tree().process_frame
	Settings.cpu_level = saved_level


func _test_cpu_recovers() -> void:
	var arena = await _start_match()
	var cpu: Fighter = arena.get_node("Player2")
	var half: float = arena.map.stage_width * 0.5
	# Knocked out past the right ledge and already below the floor line.
	cpu.global_position = Vector2(half + 150.0, 40.0)
	cpu.velocity = Vector2(120.0, 60.0)
	cpu.reset_physics_interpolation()
	Engine.time_scale = 3.0
	var back := await _run_until(
			func(): return cpu.is_on_floor() and absf(cpu.global_position.x) < half, 6.0)
	Engine.time_scale = 1.0
	t.check(back, "the CPU jumps back onto the stage from below the ledge")
	t.check(arena._lives[1] == 3, "recovering costs the CPU no stock")
	arena.queue_free()
	await t.get_tree().process_frame


func _test_cpu_respects_ledges() -> void:
	var arena = await _start_match()
	var player: Fighter = arena.get_node("Player1")
	var cpu: Fighter = arena.get_node("Player2")
	var half: float = arena.map.stage_width * 0.5
	# The rival hangs in the air well past the ledge; chasing must stop at the edge.
	player.set_physics_process(false)
	player.global_position = Vector2(half + 260.0, -60.0)
	Engine.time_scale = 3.0
	var furthest := [0.0]
	await _run_until(func():
		furthest[0] = maxf(furthest[0], cpu.global_position.x)
		return false, 4.0)
	Engine.time_scale = 1.0
	t.check(furthest[0] > 0.0, "the CPU advances toward a rival past the ledge")
	t.check(furthest[0] < half and cpu.is_on_floor(),
			"the CPU stops at the ledge instead of walking off after its rival")
	arena.queue_free()
	await t.get_tree().process_frame
