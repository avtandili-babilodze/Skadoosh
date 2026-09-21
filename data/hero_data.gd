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
## How quickly horizontal velocity changes while grounded, in pixels/second².
@export var ground_acceleration: float = 3200.0
## Air steering acceleration. Lower values preserve launch momentum for longer.
@export var air_acceleration: float = 850.0
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
## Legacy/shared attack pose used when a skill has no animation sheet of its own.
@export var attack_texture: Texture2D
## Set FALSE if the fallback attack art is drawn facing left.
@export var attack_faces_right: bool = true

@export_group("Air Poses")
## Pose shown while rising (after a jump). Falls back to the idle texture if empty.
@export var jump_texture: Texture2D
## Pose shown while falling (descending through the air). Falls back to jump/idle if empty.
@export var fall_texture: Texture2D
## Grid/playback settings let jump and fall/dive use real animation sheets.
@export var jump_hframes: int = 1
@export var jump_vframes: int = 1
@export var jump_frames: int = 0
@export var jump_fps: float = 10.0
@export var fall_hframes: int = 1
@export var fall_vframes: int = 1
@export var fall_frames: int = 0
@export var fall_fps: float = 10.0
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
## Idle pose for this hero: a single image, or a sheet when the Idle Animation grid
## below is set. If empty, the fallback color box is shown instead.
@export var texture: Texture2D
## Which way the art is drawn. Set FALSE if the character faces left in the image.
@export var faces_right: bool = true
## Fallback body color, used when no texture is assigned.
@export var color: Color = Color(0.3, 0.6, 1.0)
## On-screen height of one idle cell, in px. Keep it in step with the other poses'
## heights so the fighter reads at one size in every animation.
@export var sprite_height: float = 110.0

@export_group("Idle Animation")
## Optional idle sheet grid for `texture`. The defaults (1 × 1) keep a single still pose.
@export var idle_hframes: int = 1
@export var idle_vframes: int = 1
## Frames to play (0 = hframes × vframes). Set if the grid has blank cells.
@export var idle_frames: int = 0
## Playback speed, in frames per second. Idle loops forever, so keep it slow.
@export var idle_fps: float = 6.0

@export_group("Hurt Animation")
## Optional pose sheet shown while stunned by a hit. Plays once, then holds its last frame.
@export var hurt_texture: Texture2D
@export var hurt_hframes: int = 1
@export var hurt_vframes: int = 1
## Frames to play (0 = hframes × vframes).
@export var hurt_frames: int = 0
## Playback speed. Hit stun is short (about 0.2 s), so keep it quick.
@export var hurt_fps: float = 15.0
## On-screen height of one sheet cell, in px.
@export var hurt_sprite_height: float = 110.0
## Set FALSE if the hurt art is drawn facing left.
@export var hurt_faces_right: bool = true

@export_group("Death Animation")
## Optional death sheet. The game does not play it yet (a ring-out removes the
## fighter); it is kept with the hero so it can be switched on without re-cutting art.
@export var death_texture: Texture2D
@export var death_hframes: int = 1
@export var death_vframes: int = 1
## Frames to play (0 = hframes × vframes).
@export var death_frames: int = 0
@export var death_fps: float = 10.0
## On-screen height of one sheet cell, in px.
@export var death_sprite_height: float = 110.0
## Set FALSE if the death art is drawn facing left.
@export var death_faces_right: bool = true
