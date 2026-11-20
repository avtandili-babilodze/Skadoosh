extends Node
## Developer tool: plays one fighter through its poses and every attack it has,
## in a real arena against a standing rival, and saves screenshots. This is how
## an animation or an effect is checked the way the game really draws it (the
## art kit's own previews show neither effects nor the game's blending).
##
##   godot --path . res://tests/tools/fighter_capture.tscn -- --windowed --hero=Kunoichi
##
## Options after the `--`:
##   --hero=<name>     fighter to capture (hero name or data folder; default Kunoichi)
##   --rival=<name>    who stands in front of it (default: the same fighter)
##   --out=<folder>    where the PNGs go (default: "captures" in the game's user data)
##   --windowed        keep the game in a window instead of taking over the screen
##
## Shots are numbered in play order: 01_idle, 02_run_a, ... then two per attack
## (`_a` as the hit comes out, `_b` a tenth of a second later) and two of the dive
## (plunging, then arriving). tools/tile_captures.py tiles a folder of them into
## one sheet.

const ARENA := "res://scenes/arena.tscn"
const AIM_NAMES := {HeroData.Aim.SIDE: "side", HeroData.Aim.UP: "up", HeroData.Aim.DOWN: "down",
		HeroData.Aim.AIR: "air"}


## Commands written by this script instead of read from the keyboard.
class Pad extends FighterInput:
	var presses: Array = []

	func poll(_fighter: Fighter, _delta: float) -> void:
		pressed = presses.pop_front() if not presses.is_empty() else {}

	func press(action: String) -> void:
		presses.append({action: true})


var out_dir: String = ""
var arena: Node
var one: Fighter
var two: Fighter
var pad: Pad
var home: Vector2
var shots: int = 0


func _ready() -> void:
	_run.call_deferred()


func _arg(option: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.substr(option.length() + 3)
	return fallback


func _find_hero(wanted: String) -> HeroData:
	for hero: HeroData in Roster.heroes:
		var folder := hero.resource_path.get_base_dir().get_file()
		if hero.hero_name.to_lower() == wanted.to_lower() or folder == wanted.to_lower():
			return hero
	return null


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	shots += 1
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [shots, label]))


## Puts the fighter back on its mark with the rival `gap` px in front of it.
func _line_up(gap: float) -> void:
	pad.axis = 0.0
	pad.down = false
	one.global_position = home
	two.global_position = home + Vector2(gap, 0.0)
	one.velocity = Vector2.ZERO
	two.velocity = Vector2.ZERO
	two.damage_taken = 0.0
	one.face(1.0)
	one._tick_cooldowns(5.0)


## How far away the rival should stand for a skill to connect.
func _gap_for(skill: AttackData) -> float:
	match skill.kind:
		AttackData.Kind.RANGED:
			return minf(skill.projectile_range * 0.6, 260.0)
		AttackData.Kind.GROUND_SPIKE:
			return skill.ground_spike_distance
	return maxf(50.0, (skill.reach + skill.hitbox_offset.x) * 0.8)


func _attack(heavy: bool, aim: HeroData.Aim, skill: AttackData) -> void:
	var label := "%s_%s" % ["heavy" if heavy else "light", AIM_NAMES[aim]]
	await _ticks(100)
	_line_up(_gap_for(skill))
	await _ticks(40)
	if aim == HeroData.Aim.AIR:
		pad.press("jump")
		await _ticks(18)
	pad.axis = 1.0 if aim == HeroData.Aim.SIDE else 0.0
	pad.down = aim == HeroData.Aim.DOWN
	pad.press("attack" if heavy else "attack2")
	await _ticks(2)
	pad.axis = 0.0
	await _ticks(int(round((skill.startup_time + 0.03) * 120.0)))
	await _shot(label + "_a")
	await _ticks(12)
	await _shot(label + "_b")
	pad.down = false


func _run() -> void:
	await get_tree().process_frame
	var hero := _find_hero(_arg("hero", "Kunoichi"))
	var rival := _find_hero(_arg("rival", _arg("hero", "Kunoichi")))
	if hero == null or rival == null:
		var names := PackedStringArray()
		for known: HeroData in Roster.heroes:
			names.append(known.hero_name)
		push_error("fighter_capture: unknown fighter. Known: %s" % ", ".join(names))
		get_tree().quit(1)
		return
	out_dir = _arg("out", OS.get_user_data_dir().path_join("captures"))
	DirAccess.make_dir_recursive_absolute(out_dir)

	Roster.cpu_opponent = false
	Roster.demo = false
	Roster.map = Roster.maps[0]
	Roster.p1_hero = hero
	Roster.p2_hero = rival
	arena = load(ARENA).instantiate()
	arena.starting_lives = 9
	add_child(arena)
	await get_tree().physics_frame
	one = arena.get_node("Player1")
	two = arena.get_node("Player2")
	pad = Pad.new()
	one.input = pad
	two.input = Pad.new()
	# Let the count-in run and its banner clear before the first shot.
	while arena.phase == arena.Phase.INTRO:
		await get_tree().physics_frame
	await _ticks(200)
	home = Vector2(-60.0, two.global_position.y)

	_line_up(170.0)
	await _ticks(70)
	await _shot("idle")
	pad.axis = 1.0
	await _ticks(36)
	await _shot("run_a")
	await _ticks(7)
	await _shot("run_b")
	_line_up(260.0)
	await _ticks(50)
	pad.axis = 1.0
	pad.press("dash")
	await _ticks(7)
	await _shot("dash")
	_line_up(170.0)
	await _ticks(60)
	pad.press("jump")
	await _ticks(14)
	await _shot("jump")
	await _ticks(46)
	await _shot("fall")

	# Every different skill once: a fighter without aimed attacks only has two.
	var seen := {}
	for heavy: bool in [false, true]:
		for aim: HeroData.Aim in [HeroData.Aim.SIDE, HeroData.Aim.UP, HeroData.Aim.DOWN, HeroData.Aim.AIR]:
			var skill := hero.attack_for(heavy, aim)
			if skill == null or seen.has(skill):
				continue
			# In the air a skill that needs the floor only gives the jump.
			if aim == HeroData.Aim.AIR and skill.kind != AttackData.Kind.MELEE:
				continue
			seen[skill] = true
			await _attack(heavy, aim, skill)
	# The dive: from high above the rival, held all the way down.
	await _ticks(100)
	_line_up(36.0)
	one.global_position = home + Vector2(0.0, -260.0)
	await _ticks(4)
	pad.down = true
	pad.heavy_held = true
	pad.press("attack")
	for i in 70:
		await get_tree().physics_frame
		if one.is_diving():
			break
	await _ticks(5)
	await _shot("heavy_dive_a")
	for i in 240:
		await get_tree().physics_frame
		if not one.is_diving():
			break
	await _ticks(4)
	await _shot("heavy_dive_b")
	pad.down = false
	pad.heavy_held = false
	await _ticks(60)
	print("CAPTURE %d shots of %s in %s" % [shots, hero.hero_name, out_dir])
	get_tree().quit()
