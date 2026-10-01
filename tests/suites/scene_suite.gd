extends RefCounted
## Scenes: the character select and the arena start up with everything they need.

const ARENA_SCENE := preload("res://scenes/arena.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/character_select.tscn")

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> void:
	t = runner
	await _test_scene_startup()

func _test_scene_startup() -> void:
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
	character_select._move(0, -1)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check(roster_scroll.scroll_vertical > 0,
			"the roster automatically scrolls to an off-screen selected fighter")
	character_select.queue_free()
	await t.get_tree().process_frame
	Roster.heroes.resize(original_roster_size)

	var arena = ARENA_SCENE.instantiate()
	# Audio playback teardown is asynchronous on some headless drivers. The scene
	# test validates gameplay/UI initialization, so detach music before _ready.
	arena.get_node("Music").stream = null
	t.add_child(arena)
	await t.get_tree().physics_frame
	await t.get_tree().physics_frame
	t.check(arena.get_node_or_null("Player1") != null, "arena creates Player 1")
	t.check(arena.get_node_or_null("Player2") != null, "arena creates Player 2")
	t.check(arena.get_node_or_null("HUD/Message") != null, "arena creates its HUD")
	var music: AudioStreamPlayer = arena.get_node("Music")
	music.stop()
	music.stream = null
	arena.queue_free()
	await t.get_tree().process_frame
	await t.get_tree().create_timer(0.05).timeout
