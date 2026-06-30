class_name HeroData
extends Resource
## Data-driven definition of a playable hero.
##
## Each hero is a `.tres` file in res://data/heroes/ built from this template —
## so creating a new fighter means filling in numbers, NOT writing code.
## The Player scene reads these values to configure itself at runtime.

@export var hero_name: String = "Unnamed"
@export_multiline var description: String = ""

@export_group("Movement")
## Horizontal run speed, in pixels/second.
@export var speed: float = 350.0
## Upward velocity applied on jump. More negative = higher jump.
@export var jump_velocity: float = -650.0
## Total jumps available before landing. 2 = double jump, 3 = triple, etc.
@export var max_jumps: int = 2
## Extra mid-air jumps from the heavy-attack key, separate from max_jumps. Refills on landing.
@export var air_attack_jumps: int = 1
## Multiplies gravity. 1.0 = normal fall, higher = falls faster/heavier.
@export var gravity_scale: float = 1.4
## Extra gravity multiplier while holding "down" in the air (fast fall).
@export var fast_fall_scale: float = 2.0
## Horizontal burst speed during a dash, in pixels/second.
@export var dash_speed: float = 900.0
## How long the dash burst lasts, in seconds.
@export var dash_duration: float = 0.1125
## Cooldown before the player can dash again, in seconds.
@export var dash_cooldown: float = 0.15
## Dodge (a stationary dash): seconds of invincibility + no falling. 0 disables it.
@export var dodge_duration: float = 0.5
## Cooldown before you can dodge again, in seconds (separate from the dash cooldown).
@export var dodge_cooldown: float = 1.5

@export_group("Combat")
@export var max_health: float = 100.0
## Damage-resistance rating, 0 (none) to 10 (halves incoming %). Higher = tankier.
@export_range(0.0, 10.0) var defense: float = 0.0
## How much the accumulated damage % (shown in the HUD) amplifies knockback:
## factor = 1 + (% / 100) × this. 1 = knockback ×(1 + %/100) — at 100% you fly twice as far.
@export var knockback_percent_scale: float = 1.0
## Minimum time between ANY two attacks (light or heavy). Stops firing both at once.
@export var min_attack_interval: float = 0.0

@export_group("Skills")
## The quick, weaker attack (bound to the secondary attack key).
@export var light_attack: AttackData
## The slower, stronger attack (bound to the primary attack key).
@export var heavy_attack: AttackData

@export_group("Attack Appearance")
## Pose shown while attacking (shared by both skills). Falls back to the idle texture if empty.
@export var attack_texture: Texture2D
## Set FALSE if the attack art is drawn facing left.
@export var attack_faces_right: bool = true

@export_group("Air Poses")
## Pose shown while rising (after a jump). Falls back to the idle texture if empty.
@export var jump_texture: Texture2D
## Pose shown while falling (descending through the air). Falls back to jump/idle if empty.
@export var fall_texture: Texture2D
## Set FALSE if the air art is drawn facing left.
@export var air_faces_right: bool = true
## On-screen height of an air pose, in px. Tune so it matches the idle size.
@export var air_sprite_height: float = 110.0

@export_group("Walk Animation")
## Optional walk-cycle sprite sheet. If empty, the hero just uses the idle pose.
@export var walk_texture: Texture2D
## Sheet grid — number of frame columns.
@export var walk_hframes: int = 1
## Sheet grid — number of frame rows.
@export var walk_vframes: int = 1
## Frames to actually play (0 = hframes × vframes). Set if the grid has blank cells.
@export var walk_frames: int = 0
## Playback speed, in frames per second.
@export var walk_fps: float = 12.0
## On-screen height of one frame, in px. Tune so walking matches the idle size.
@export var walk_sprite_height: float = 130.0
## Set FALSE if the walk art is drawn facing left.
@export var walk_faces_right: bool = true

@export_group("Appearance")
## Icon shown for this hero on the character-select screen. Square art works best.
@export var icon: Texture2D
## Avatar image for this hero. If set, it's shown instead of the color box.
## Drop a PNG/JPG into res://assets/sprites/ and assign it here.
@export var texture: Texture2D
## Which way the art is drawn. Set FALSE if the character faces left in the image.
@export var faces_right: bool = true
## Fallback body color, used when no texture is assigned.
@export var color: Color = Color(0.3, 0.6, 1.0)
## Height in pixels to scale the avatar to (keeps big images from filling the screen).
@export var sprite_height: float = 110.0
