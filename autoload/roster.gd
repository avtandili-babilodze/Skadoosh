extends Node
## Global hero roster, stage list and the current match's picks (autoloaded as "Roster").
##
## The character-select screen writes each player's chosen hero here, the map
## select writes the stage, then the arena loads and reads them back.
##
## To add a new fighter to the game, drop its folder in res://data/heroes/ and
## add its hero.tres path to HERO_PATHS below — the select screen builds itself from
## this list, so no UI code needs to change. Stages work the same way through
## MAP_PATHS (see tools/make_maps.py).

## Every selectable hero, in the order they appear on the select screen.
const HERO_PATHS := [
	"res://data/heroes/kunoichi/hero.tres",
	"res://data/heroes/linea/hero.tres",
	"res://data/heroes/primordial_demon/hero.tres",
	"res://data/heroes/water_bender/hero.tres",
	"res://data/heroes/lilith/hero.tres",
	"res://data/heroes/kitsune/hero.tres",
	"res://data/heroes/antiope/hero.tres",
	"res://data/heroes/musashi/hero.tres",
	"res://data/heroes/akane/hero.tres",
	"res://data/heroes/knight/hero.tres",
]

## Every selectable stage, in the order they appear on the map select.
const MAP_PATHS := [
	"res://data/maps/neon.tres",
	"res://data/maps/shrine.tres",
	"res://data/maps/caldera.tres",
	"res://data/maps/frost.tres",
]

## Player colours, used for cursors, HUD plates, markers and hit sparks.
const PLAYER_COLORS := [Color(0.23, 0.63, 1.0), Color(1.0, 0.48, 0.18)]

## Loaded HeroData resources (parallel to HERO_PATHS), filled at startup.
var heroes: Array[HeroData] = []
## Loaded MapData resources (parallel to MAP_PATHS), filled at startup.
var maps: Array[MapData] = []

## The picks made on the select screens. Null until chosen; the arena falls back
## to its own scene defaults when these are null (e.g. when run directly).
var p1_hero: HeroData = null
var p2_hero: HeroData = null
var map: MapData = null
## True for a one-player match: the CPU plays Player 2.
var cpu_opponent: bool = false
## True for the title screen's demo match: the CPU plays both fighters and any
## key returns to the title.
var demo: bool = false

## Remembered cursor positions, so returning to a select screen keeps the picks.
var last_hero_index := [0, 1]
var last_map_index: int = 0

var _accents: Dictionary = {}


func _ready() -> void:
	for path in HERO_PATHS:
		var hero: HeroData = load(path)
		if hero != null:
			heroes.append(hero)
	for path in MAP_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var stage: MapData = load(path)
		if stage != null:
			maps.append(stage)


## Sets up a CPU-versus-CPU demo match on a random stage with random fighters.
func roll_demo() -> void:
	demo = true
	cpu_opponent = true
	if not heroes.is_empty():
		p1_hero = heroes[randi() % heroes.size()]
		p2_hero = heroes[randi() % heroes.size()]
	if not maps.is_empty():
		map = maps[randi() % maps.size()]


## The stage a match should load: the pick, or the first stage when run directly.
func current_map() -> MapData:
	if map != null:
		return map
	return maps[0] if not maps.is_empty() else null


## A hero's signature colour, read from the most vivid pixels of its icon, so
## sparks and UI accents match the fighter without a hand-kept table.
func accent_of(hero: HeroData) -> Color:
	if hero == null:
		return Color.WHITE
	if _accents.has(hero):
		return _accents[hero]
	var accent := hero.color
	if hero.accent.a > 0.0:
		accent = hero.accent
	elif hero.icon != null:
		var image := hero.icon.get_image()
		if image != null and not image.is_empty():
			if image.is_compressed():
				image.decompress()
			image.resize(24, 24, Image.INTERPOLATE_BILINEAR)
			var sum := Vector3.ZERO
			var weight := 0.0
			for y in image.get_height():
				for x in image.get_width():
					var pixel := image.get_pixel(x, y)
					if pixel.a < 0.5:
						continue
					# Vivid mid-bright pixels dominate; greys and skin barely count.
					var w := pow(pixel.s, 3.0) * pixel.v
					sum += Vector3(pixel.r, pixel.g, pixel.b) * w
					weight += w
			if weight > 0.01:
				accent = Color(sum.x / weight, sum.y / weight, sum.z / weight)
				accent.s = clampf(accent.s * 1.15, 0.45, 0.95)
				accent.v = clampf(accent.v * 1.25, 0.75, 1.0)
	_accents[hero] = accent
	return accent
