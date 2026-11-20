class_name AttackData
extends Resource
## One attack a hero can perform — a "skill" (e.g. a light or heavy attack).
##
## Each skill defines its OWN damage and knockback, so every attack of a hero can
## be tuned completely independently. A hero references a light and a heavy
## skill in its HeroData, and optionally one more of each per aim (up, down, in
## the air).

enum Kind { MELEE, RANGED, GROUND_SPIKE }

## Label for this skill (just for clarity in the editor).
@export var skill_name: String = "Attack"
## MELEE = hitbox in front; RANGED = projectile; GROUND_SPIKE = delayed floor hazard.
@export var kind: Kind = Kind.MELEE
## Damage % this attack adds to the victim on hit.
@export var damage: float = 8.0
## Base knockback this attack applies (grows further as the victim's damage rises).
@export var knockback: float = 400.0
## Upward part of knockback as a fraction of the force (low = flat push,
## negative = a spike toward the floor).
@export var knockback_up_ratio: float = 0.18
## Sideways part of knockback as a fraction of the force. 1 is a full push away
## from the attacker; a launcher that sends its victim straight up uses a small
## value with a knockback_up_ratio near 1.
@export var knockback_forward: float = 1.0
@export_group("Timing")
## Delay between pressing the button and the hitbox becoming active.
@export_range(0.0, 2.0, 0.01) var startup_time: float = 0.08
## How long the hitbox remains active. A target can only be hit once per attack.
@export_range(0.01, 2.0, 0.01) var active_time: float = 0.10
## Vulnerable recovery after the active window ends. Once the attack has hit
## someone, a jump, a dash or the other attack can cut this short.
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.17
## The price of a miss: a full control lock after recovery, paid only when the
## attack hit nobody. Gravity and existing momentum still apply, but no movement,
## jump, dash, dodge, or attack can start. Keep it short (about 0.12 for a
## light, 0.24 for a heavy): long locks make the whole game feel slow.
@export_range(0.0, 2.0, 0.01) var post_end_lag: float = 0.12
## Time from the start of THIS skill until it can start again, in seconds. Keep
## it between the attack's own length and the moment a miss hands control back,
## so the skill is ready when the fighter is and a press is never ignored.
@export var cooldown: float = 0.45

@export_group("Animation")
## The rig animation this skill plays ("light_up", "heavy_down", ...). Empty, or
## a name the hero's rig does not have, plays "light_attack" or "heavy_attack".
@export var rig_animation: String = ""
## Optional skill-specific sprite sheet. Falls back to the hero's shared attack pose.
@export var animation_texture: Texture2D
@export var animation_hframes: int = 1
@export var animation_vframes: int = 1
## Frames to play (0 = hframes × vframes). Frames spread evenly across all attack
## phases unless animation_release_frame pins the key pose to the hit.
@export var animation_frames: int = 0
## Frame (0-based) showing the moment of release, pinned to the active window:
## earlier frames play during startup and later ones during recovery. Use it when
## the art's key pose (a whip cracking, a fireball leaving the hand) must line up
## with the hit. -1 spreads every frame evenly across the whole attack instead.
@export var animation_release_frame: int = -1
## How many frames, starting at the release frame, play across the active
## window. 1 holds the release pose for the whole window; a sword swing drawn
## over three frames sets 3 so the blade keeps moving while the hit is live.
@export var animation_active_frames: int = 1
## Height used to scale one complete sheet cell on screen.
@export var animation_sprite_height: float = 110.0
## Set FALSE if the animation artwork is drawn facing left.
@export var animation_faces_right: bool = true

@export_group("Effect")
## A drawn elemental effect (ToonEffect preset: "fireball", "foxfire_orb",
## "water_spit", "water_wave", "fire_pillar", "dark_eruption", "foxfire_burst",
## "fire_burst", ...). For a projectile or ground spike it replaces the texture;
## for a melee skill it bursts out over the hitbox during the active window.
@export var effect: String = ""

## What a melee skill throws out besides its swing as the hit comes out. One
## strike gets one of these, never two stacked:
## "dive" (where a plunge arrives: a crescent coming down, and on the floor
## dust, a crack and a shock ring), "flash" (a flat crescent out in front: a level cut), "thrust" (a line of
## light along a stab), "slam" (dust, a crack and a shock ring where the blow
## meets the floor, under a crescent coming down), "rise" (a column kicked up
## from the feet and a tall crescent), "moon" (a full ring round a spinning
## cut), "sweep" (dust thrown along the floor), or "" for nothing. All but the
## last two are meant for heavy attacks. A lunging step kicks up a little dust
## on its own.
## Made of straight rays and sparks instead of arcs: "lance" (a beam along a
## long thrust), "crown" (a fan of spikes over an uppercut), "sunburst" (half a
## sun on the floor round a planted blade), "hammer" (rays driven down from a
## blow in the air), "tread" (a star of cracks under a stomp).
@export var flourish: String = ""
## The ribbon of light a blade leaves when it swings. Switch it off for a
## skill that does not strike with the blade (a pommel, a fist, a boot).
@export var weapon_arc: bool = true

@export_group("Dive")
## Above 0 this skill is a dive. Started in the air, the fighter plunges at this
## speed (px/s) for as long as the heavy button is held, and its hit comes out
## where it reaches the floor or another fighter. Letting go of the button ends
## the dive without the hit. The startup is the turn into the plunge.
@export var dive_speed: float = 0.0

@export_group("Melee reach")
## Horizontal reach of the hitbox, in pixels.
@export var reach: float = 95.0
## Total vertical size of the hitbox, in pixels.
@export var height: float = 90.0
## Moves the hitbox from its place in front of the body centre: x pushes it
## further forward, y lower (negative y lifts it, for a strike aimed upward).
@export var hitbox_offset: Vector2 = Vector2.ZERO
## Speed of the step forward a grounded melee attack takes as its hit comes out,
## in pixels/second. Negative uses the fighter's default for a light or heavy.
@export var lunge: float = -1.0
## Upward speed given to the attacker as the hit comes out (a rising strike).
@export var lift: float = 0.0

@export_group("Ranged projectile")
## Projectile image (required when kind is RANGED): a single picture, or a
## sheet when the grid below is set.
@export var projectile_texture: Texture2D
## Optional sheet grid for an animated projectile. The defaults (1 x 1) keep a
## single still image. The animation loops for as long as the projectile flies.
@export var projectile_hframes: int = 1
@export var projectile_vframes: int = 1
## Frames to play (0 = hframes x vframes).
@export var projectile_frames: int = 0
@export var projectile_fps: float = 14.0
## Travel speed, in pixels/second.
@export var projectile_speed: float = 700.0
## Max travel distance before it fizzles, in pixels (0 = unlimited).
@export var projectile_range: float = 500.0
## Despawn after this long if it hits nothing, in seconds.
@export var projectile_lifetime: float = 2.0
## On-screen height of the projectile art (one sheet cell), in pixels.
@export var projectile_height: float = 70.0
## Radius of the projectile collision circle, in pixels.
@export var projectile_radius: float = 28.0
## Set FALSE if the projectile art points left.
@export var projectile_faces_right: bool = true
## Spawn point relative to the caster: x = distance in front, y = vertical offset.
@export var projectile_spawn_offset: Vector2 = Vector2(70.0, -10.0)
## Optional travel growth. Defaults preserve the current fixed-size projectile behavior.
@export_range(0.05, 5.0, 0.05) var projectile_start_scale: float = 1.0
@export_range(0.05, 5.0, 0.05) var projectile_end_scale: float = 1.0
## Damage multiplier reached at maximum range. Interpolates linearly from 1×.
@export_range(0.0, 5.0, 0.05) var projectile_end_damage_multiplier: float = 1.0
## Anchors the visual and hit circle to the node's bottom edge while scaling.
@export var projectile_grounded: bool = false

@export_group("Ground spike")
## Animated effect used when kind is GROUND_SPIKE.
@export var ground_spike_texture: Texture2D
## Horizontal distance from the caster to the eruption point, in pixels.
@export var ground_spike_distance: float = 320.0
## Total warning time from button press to eruption. The crack appears immediately.
@export_range(0.0, 2.0, 0.01) var ground_spike_delay: float = 0.12
## How long the fully erupted spike hitbox remains dangerous.
@export_range(0.01, 2.0, 0.01) var ground_spike_active_time: float = 0.18
## Visual-only retract/dissolve time after the dangerous window.
@export_range(0.0, 2.0, 0.01) var ground_spike_fade_time: float = 0.22
## Collision box size. The box grows upward from the detected arena floor.
@export var ground_spike_hitbox_size: Vector2 = Vector2(120.0, 110.0)
@export var ground_spike_hframes: int = 4
@export var ground_spike_vframes: int = 1
@export var ground_spike_frames: int = 4
## On-screen height of one effect frame.
@export var ground_spike_sprite_height: float = 170.0
