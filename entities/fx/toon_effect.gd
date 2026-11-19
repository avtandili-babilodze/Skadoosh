class_name ToonEffect
extends Node2D
## A cel-shaded elemental effect (toon_fx.gdshader) on a quad: fireballs,
## foxfire, water, pillars and eruptions drawn in the same inked style as the
## fighters. The node's origin is the quad's centre, or the middle of its
## bottom edge when `grounded` (pillars, waves and eruptions rise from the floor).
##
## Presets name a shape and a palette; AttackData.effect picks one.

const SHADER := preload("res://entities/fx/toon_fx.gdshader")

const SHAPE_BALL := 0
const SHAPE_COLUMN := 1
const SHAPE_BURST := 2
const SHAPE_WAVE := 3
const SHAPE_DROPLET := 4

## ink, dark, mid, light, core
const PALETTES := {
	"fire": [Color(0.16, 0.05, 0.03), Color(0.8, 0.15, 0.05), Color(1.0, 0.45, 0.08),
			Color(1.0, 0.78, 0.25), Color(1.0, 0.98, 0.84)],
	"foxfire": [Color(0.05, 0.08, 0.25), Color(0.15, 0.3, 0.85), Color(0.25, 0.6, 1.0),
			Color(0.6, 0.88, 1.0), Color(0.95, 1.0, 1.0)],
	"water": [Color(0.04, 0.12, 0.3), Color(0.1, 0.35, 0.8), Color(0.2, 0.6, 0.95),
			Color(0.55, 0.88, 1.0), Color(0.95, 1.0, 1.0)],
	"dark": [Color(0.06, 0.02, 0.1), Color(0.3, 0.06, 0.45), Color(0.6, 0.15, 0.85),
			Color(0.9, 0.45, 1.0), Color(1.0, 0.9, 1.0)],
}

## preset -> [shape, palette, width / height, grounded]
const PRESETS := {
	"fireball": [SHAPE_BALL, "fire", 1.8, false],
	"flame_jab": [SHAPE_BALL, "fire", 1.3, false],
	"foxfire_orb": [SHAPE_BALL, "foxfire", 1.8, false],
	"water_spit": [SHAPE_DROPLET, "water", 1.7, false],
	"water_wave": [SHAPE_WAVE, "water", 1.9, true],
	"fire_pillar": [SHAPE_COLUMN, "fire", 0.42, true],
	"fire_burst": [SHAPE_BURST, "fire", 1.3, true],
	"foxfire_burst": [SHAPE_BURST, "foxfire", 1.3, true],
	"dark_eruption": [SHAPE_BURST, "dark", 1.0, true],
}

## Ink rim thickness in screen pixels at zoom 1.
const INK_PX := 2.6

var preset: String = ""
var grounded: bool = false

var _rect: ColorRect
var _material: ShaderMaterial
var _aspect: float = 1.0
var _height: float = 64.0


## What a hit from this preset sounds like: "fire", "water" or "magic".
static func sound_kind(name: String) -> String:
	if not PRESETS.has(name):
		return ""
	match PRESETS[name][1]:
		"fire": return "fire"
		"water": return "water"
	return "magic"


static func has_preset(name: String) -> bool:
	return PRESETS.has(name)


## Width over height of a preset's quad.
static func aspect_of(name: String) -> float:
	return float(PRESETS[name][2]) if PRESETS.has(name) else 1.0


func _init(preset_name: String = "", height: float = 64.0, flip: bool = false) -> void:
	preset = preset_name
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var spec: Array = PRESETS.get(preset_name, PRESETS["fireball"])
	grounded = spec[3]
	_aspect = float(spec[2])
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var palette: Array = PALETTES[spec[1]]
	for i in 5:
		_material.set_shader_parameter(["ink", "dark", "mid", "light", "core"][i], palette[i])
	_material.set_shader_parameter("shape", spec[0])
	_material.set_shader_parameter("aspect", _aspect)
	_material.set_shader_parameter("seed", randf() * 10.0)
	_material.set_shader_parameter("time_offset", randf() * 10.0)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	set_flip(flip)
	set_height(height)


## Faces the effect the other way (it is drawn travelling right).
func set_flip(flip: bool) -> void:
	scale.x = -absf(scale.x) if flip else absf(scale.x)


## On-screen height of the quad; the width follows the preset's aspect.
func set_height(height: float) -> void:
	_height = maxf(1.0, height)
	var size := Vector2(_height * _aspect, _height)
	_rect.size = size
	_rect.position = Vector2(-size.x * 0.5, -size.y if grounded else -size.y * 0.5)
	_material.set_shader_parameter("ink_width", INK_PX / _height)


func set_grow(value: float) -> void:
	_material.set_shader_parameter("grow", clampf(value, 0.0, 1.0))


func set_fade(value: float) -> void:
	_material.set_shader_parameter("fade", clampf(value, 0.0, 1.0))
