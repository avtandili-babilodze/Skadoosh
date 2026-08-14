class_name AttackData
extends Resource
## One attack a hero can perform — a "skill" (e.g. a light or heavy attack).
##
## Each skill defines its OWN damage and knockback, so a hero's light and heavy
## attacks can be tuned completely independently. A hero references two of these
## (light_attack / heavy_attack) in its HeroData.

enum Kind { MELEE, RANGED, GROUND_SPIKE }

## Label for this skill (just for clarity in the editor).
@export var skill_name: String = "Attack"
## MELEE = hitbox in front; RANGED = projectile; GROUND_SPIKE = delayed floor hazard.
@export var kind: Kind = Kind.MELEE
## Damage % this attack adds to the victim on hit.
@export var damage: float = 8.0
## Base knockback this attack applies (grows further as the victim's damage rises).
@export var knockback: float = 400.0
## Upward part of knockback as a fraction of the sideways force (low = flat push).
@export var knockback_up_ratio: float = 0.18
@export_group("Timing")
## Delay between pressing the button and the hitbox becoming active.
@export_range(0.0, 2.0, 0.01) var startup_time: float = 0.08
## How long the hitbox remains active. A target can only be hit once per attack.
@export_range(0.01, 2.0, 0.01) var active_time: float = 0.10
## Vulnerable recovery after the active window ends.
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.17
## Full control lock after the animation/recovery finishes. Gravity and existing
## momentum still apply, but no movement, jump, dash, dodge, or attack can start.
@export_range(0.0, 2.0, 0.01) var post_end_lag: float = 0.30
## Cooldown before THIS skill can be used again, in seconds.
@export var cooldown: float = 0.45

@export_group("Animation")
## Optional skill-specific sprite sheet. Falls back to the hero's shared attack pose.
@export var animation_texture: Texture2D
@export var animation_hframes: int = 1
@export var animation_vframes: int = 1
## Frames to play (0 = hframes × vframes). Frames are spread across all attack phases.
@export var animation_frames: int = 0
## Height used to scale one complete sheet cell on screen.
@export var animation_sprite_height: float = 110.0
## Set FALSE if the animation artwork is drawn facing left.
@export var animation_faces_right: bool = true

@export_group("Melee reach")
## Horizontal reach of the hitbox, in pixels.
@export var reach: float = 95.0
## Total vertical size of the hitbox, in pixels.
@export var height: float = 90.0

@export_group("Ranged projectile")
## Projectile image (required when kind is RANGED).
@export var projectile_texture: Texture2D
## Travel speed, in pixels/second.
@export var projectile_speed: float = 700.0
## Max travel distance before it fizzles, in pixels (0 = unlimited).
@export var projectile_range: float = 500.0
## Despawn after this long if it hits nothing, in seconds.
@export var projectile_lifetime: float = 2.0
## On-screen height of the projectile art, in pixels.
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
