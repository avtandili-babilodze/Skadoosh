class_name MapData
extends Resource
## Data-driven definition of a stage.
##
## World units are pixels at camera zoom 1. The main stage is centred on x = 0
## and its walkable top is y = 0, so everything else (platforms, spawn points,
## blast zone) is measured from the middle of the floor: negative y is up.
## The .tres files in res://data/maps/ are written by tools/make_maps.py, which
## also copies in the measurements of the stage art.

@export var id: String = ""
@export var map_name: String = "Unnamed"
@export_multiline var description: String = ""

@export_group("Art")
@export var background: Texture2D
@export var stage_texture: Texture2D
@export var platform_texture: Texture2D
## Where the walkable line sits inside the stage art, in texture pixels:
## x = left end, y = right end, z = row.
@export var stage_art_line: Vector3 = Vector3(0, 100, 0)
@export var platform_art_line: Vector3 = Vector3(0, 100, 0)
## Colour used for this stage's UI accents and ambient particles.
@export var accent: Color = Color(1, 1, 1)
## Drifting particles: "petals", "embers", "snow", "motes" or "" for none.
@export var ambient: String = ""

@export_group("Layout")
## Walkable width of the main stage.
@export var stage_width: float = 940.0
## Pass-through platforms: x = centre, y = top, z = width.
@export var platforms: Array[Vector3] = []
## A platform that glides side to side. x = centre, y = top, z = width;
## width 0 means the stage has none.
@export var moving_platform: Vector3 = Vector3.ZERO
## How far the moving platform travels to each side of its centre, and how long
## one full trip there and back takes.
@export var moving_platform_travel: float = 0.0
@export var moving_platform_period: float = 8.0
## Where each player starts and respawns (feet position).
@export var spawn_points: PackedVector2Array = PackedVector2Array([Vector2(-220, 0), Vector2(220, 0)])
## Leaving this rectangle is a ring-out.
@export var blast_zone: Rect2 = Rect2(-1100, -900, 2200, 1450)


# --- Placing the art ---------------------------------------------------------
# The stage and platform textures carry more than the walkable surface (bevels,
# machinery hanging underneath), so they are positioned by their measured line.

## World pixels per texture pixel for the main stage art.
func stage_scale() -> float:
	return stage_width / maxf(1.0, stage_art_line.y - stage_art_line.x)


## Top-left corner of the main stage art, in world space.
func stage_origin() -> Vector2:
	var art_scale := stage_scale()
	return Vector2(-(stage_art_line.x + stage_art_line.y) * 0.5 * art_scale,
			-stage_art_line.z * art_scale)


## World pixels per texture pixel for a platform of the given walkable width.
func platform_scale(width: float) -> float:
	return width / maxf(1.0, platform_art_line.y - platform_art_line.x)


## Top-left corner of the art for a platform (x = centre, y = top, z = width).
func platform_origin(platform: Vector3) -> Vector2:
	var art_scale := platform_scale(platform.z)
	return Vector2(platform.x - (platform_art_line.x + platform_art_line.y) * 0.5 * art_scale,
			platform.y - platform_art_line.z * art_scale)


## Where the moving platform's centre is `time` seconds into a match.
func moving_platform_x(time: float) -> float:
	if moving_platform.z <= 0.0 or moving_platform_period <= 0.0:
		return moving_platform.x
	return moving_platform.x + sin(time * TAU / moving_platform_period) * moving_platform_travel


func has_moving_platform() -> bool:
	return moving_platform.z > 0.0
