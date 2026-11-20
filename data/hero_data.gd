class_name HeroData
extends Resource
## Data-driven definition of a playable hero.
##
## Each hero is a `.tres` file in res://data/heroes/ built from this template —
## so creating a new fighter means filling in numbers, NOT writing code.
## The Player scene reads these values to configure itself at runtime.

var _default_dive: AttackData = null

## Where an attack is aimed when its button is pressed.
enum Aim { SIDE, UP, DOWN, AIR, DIVE }

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
## Rising heavies per airtime: the heavy-attack key in the air lifts the fighter
## like a jump while the heavy attack comes out. Separate from max_jumps; refills on landing.
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

## What the hero's melee attacks sound like: "blade", "claw", "whip", or ""
## for a plain swing (fists, staffs, casters).
@export var weapon_sound: String = ""

@export_group("Skills")
## The quick, weaker attack (bound to the secondary attack key). It is the side
## attack, and stands in for every aimed light attack the hero does not have.
@export var light_attack: AttackData
## The slower, stronger attack (bound to the primary attack key). It is the side
## attack, and stands in for every aimed heavy attack the hero does not have.
@export var heavy_attack: AttackData
@export_subgroup("Aimed attacks")
## Standing still (no direction held) on the ground: a strike aimed upward.
@export var light_up: AttackData
## Holding down on the ground: a low strike.
@export var light_down: AttackData
## Anywhere in the air.
@export var light_air: AttackData
@export var heavy_up: AttackData
@export var heavy_down: AttackData
@export var heavy_air: AttackData
## Heavy with down held in the air: the dive (a skill with a dive_speed). A hero
## without one of its own gets default_dive().
@export var heavy_dive: AttackData

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

@export_group("Rig")
## A live cutout skeleton (rig.json from the art pipeline, with its part textures
## beside it). When set, the fighter is drawn by it and every sheet below is
## ignored: animations play at the display's frame rate and hair and cloth are
## simulated live.
@export var rig: JSON

@export_group("Appearance")
## Icon shown for this hero on the character-select screen. Square art works best.
@export var icon: Texture2D
## Idle pose for this hero: a single image, or a sheet when the Idle Animation grid
## below is set. If empty, the fallback color box is shown instead.
@export var texture: Texture2D
## Which way the art is drawn. Set FALSE if the character faces left in the image.
@export var faces_right: bool = true
## The fighter's signature colour: sparks, blade arcs, attack effects and UI
## accents. Left transparent, it is read from the most vivid pixels of the icon,
## which suits a fighter whose colour is on its head and shoulders. Set it when
## the icon would give the wrong answer (a steel-clad fighter whose colour is a
## cape below the bust comes out skin-toned).
@export var accent: Color = Color(0, 0, 0, 0)
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

@export_group("Landing Animation")
## Optional sheet played once on touching down (a crouch that rises back to
## standing). Moving, jumping or attacking cuts it short. Without it, the fighter
## lands with a procedural squash instead.
@export var land_texture: Texture2D
@export var land_hframes: int = 1
@export var land_vframes: int = 1
## Frames to play (0 = hframes × vframes).
@export var land_frames: int = 0
## Keep it quick: a landing that lingers makes controls feel sluggish.
@export var land_fps: float = 16.0
## On-screen height of one sheet cell, in px. Match the other poses.
@export var land_sprite_height: float = 110.0
## Set FALSE if the landing art is drawn facing left.
@export var land_faces_right: bool = true

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


## The skill a button gives for an aim. A hero without an attack of its own for
## that aim uses its side attack.
func attack_for(is_heavy: bool, aim: Aim) -> AttackData:
	var aimed: AttackData = null
	match aim:
		Aim.UP:
			aimed = heavy_up if is_heavy else light_up
		Aim.DOWN:
			aimed = heavy_down if is_heavy else light_down
		Aim.AIR:
			aimed = heavy_air if is_heavy else light_air
		Aim.DIVE:
			# Only the heavy button dives; the light one keeps its air attack.
			if is_heavy:
				return heavy_dive if heavy_dive != null else default_dive()
			aimed = light_air
	if aimed != null:
		return aimed
	return heavy_attack if is_heavy else light_attack


## Every skill the hero has, light ones first.
func all_attacks() -> Array[AttackData]:
	var skills: Array[AttackData] = []
	for skill: AttackData in [light_attack, light_up, light_down, light_air,
			heavy_attack, heavy_up, heavy_down, heavy_air, heavy_dive]:
		if skill != null:
			skills.append(skill)
	return skills


func is_heavy_skill(skill: AttackData) -> bool:
	return skill != null and skill in [heavy_attack, heavy_up, heavy_down, heavy_air,
			heavy_dive, _default_dive]


## The dive every fighter has until it is given one of its own: a plunge that
## ends in a blow around the body, nearly as strong as its heavy attack. It
## plays the rig's "heavy_dive" animation when there is one, the heavy attack's
## otherwise.
func default_dive() -> AttackData:
	if _default_dive == null:
		var dive := AttackData.new()
		dive.skill_name = "Dive"
		dive.kind = AttackData.Kind.MELEE
		dive.damage = (heavy_attack.damage if heavy_attack != null else 14.0) * 0.9
		dive.knockback = 540.0
		dive.knockback_up_ratio = 0.6
		dive.knockback_forward = 0.7
		dive.startup_time = 0.14
		dive.active_time = 0.1
		dive.recovery_time = 0.22
		dive.post_end_lag = 0.24
		dive.cooldown = 0.6
		dive.reach = 58.0
		dive.height = 84.0
		dive.hitbox_offset = Vector2(-18.0, 30.0)      # under the body, not out in front
		dive.lunge = 0.0
		dive.dive_speed = 1050.0
		dive.flourish = "dive"
		dive.rig_animation = "heavy_dive"
		_default_dive = dive
	return _default_dive
