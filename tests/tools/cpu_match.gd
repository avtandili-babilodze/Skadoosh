extends Node
## Developer tool: two CPU fighters play real matches with every effect on, and
## the tool prints how long each lasted, how many hits landed and which skills
## each fighter used. It runs without a window, so it is the quick way to find
## script errors in combat code and to see whether the CPU uses a new moveset.
##
##   godot --headless --fixed-fps 120 --path . res://tests/tools/cpu_match.tscn -- --p1=Kunoichi --p2=Linea
##
## Options after the `--`:
##   --p1=<name> --p2=<name>   the two fighters (default Kunoichi against herself)
##   --matches=<n>             how many matches to play (default 1)
##   --limit=<seconds>         give up on a match after this much game time (default 80)
##
## Every result line starts with "SIM". Any "SCRIPT ERROR" in the output is a bug.
## `--fixed-fps 120` matters: it plays physics ticks as fast as the machine
## allows without changing how long a tick is.

const ARENA := "res://scenes/arena.tscn"


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


func _run() -> void:
	await get_tree().process_frame
	var first := _find_hero(_arg("p1", "Kunoichi"))
	var second := _find_hero(_arg("p2", _arg("p1", "Kunoichi")))
	if first == null or second == null:
		push_error("cpu_match: unknown fighter")
		get_tree().quit(1)
		return
	var limit := float(_arg("limit", "80"))
	for match_index in int(_arg("matches", "1")):
		Roster.cpu_opponent = true
		Roster.demo = false
		Roster.map = Roster.maps[match_index % Roster.maps.size()]
		Roster.p1_hero = first
		Roster.p2_hero = second
		var arena = load(ARENA).instantiate()
		arena.starting_lives = 2
		add_child(arena)
		await get_tree().physics_frame
		var players: Array = [arena.get_node("Player1"), arena.get_node("Player2")]
		for fighter in players:
			fighter.input = FighterBrain.new(FighterBrain.Level.HARD, arena.map)
		arena._begin_fight()
		var used := {}
		var last: Array = [null, null]
		var taken: Array = [0.0, 0.0]
		var hits := 0
		var ticks := 0
		while arena.phase == arena.Phase.FIGHT and ticks < int(limit * 120.0):
			await get_tree().physics_frame
			ticks += 1
			for k in 2:
				var fighter = players[k]
				var skill = fighter._attack_skill
				if skill != null and skill != last[k]:
					var key := "P%d %s: %s" % [k + 1, fighter.hero.hero_name, skill.skill_name]
					used[key] = int(used.get(key, 0)) + 1
				last[k] = skill
				if fighter.damage_taken > taken[k] + 0.001:
					hits += 1
				taken[k] = fighter.damage_taken
		print("SIM %s vs %s on %s: %.1f s, %d hits%s" % [first.hero_name, second.hero_name,
				arena.map.map_name if "map_name" in arena.map else "stage", ticks / 120.0, hits,
				"" if arena.phase != arena.Phase.FIGHT else "  (TIMEOUT)"])
		var names := used.keys()
		names.sort()
		for key: String in names:
			print("SIM   %-38s %d" % [key, used[key]])
		arena.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()
