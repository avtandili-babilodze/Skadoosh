extends Node
## Global hero roster + the current match's character picks (autoloaded as "Roster").
##
## The character-select screen writes each player's chosen hero here, then loads
## the arena. The arena reads these back to configure Player1 / Player2.
##
## To add a new fighter to the game, drop its folder in res://data/heroes/ and
## add its hero.tres path to HEROES below — the select screen builds itself from
## this list, so no UI code needs to change.

## Every selectable hero, in the order they appear on the select screen.
const HERO_PATHS := [
	"res://data/heroes/kunoichi/hero.tres",
	"res://data/heroes/linea/hero.tres",
]

## Loaded HeroData resources (parallel to HERO_PATHS), filled at startup.
var heroes: Array[HeroData] = []

## The picks made on the select screen. Null until chosen; the arena falls back
## to its own scene defaults when these are null (e.g. when run directly).
var p1_hero: HeroData = null
var p2_hero: HeroData = null


func _ready() -> void:
	for path in HERO_PATHS:
		var hero: HeroData = load(path)
		if hero != null:
			heroes.append(hero)
