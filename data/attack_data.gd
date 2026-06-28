class_name AttackData
extends Resource
## One attack a hero can perform — a "skill" (e.g. a light or heavy attack).
##
## Each skill defines its OWN damage and knockback, so a hero's light and heavy
## attacks can be tuned completely independently. A hero references two of these
## (light_attack / heavy_attack) in its HeroData.

enum Kind { MELEE, RANGED }

## Label for this skill (just for clarity in the editor).
@export var skill_name: String = "Attack"
## MELEE = hitbox in front of the attacker; RANGED = fires a projectile.
@export var kind: Kind = Kind.MELEE
## Damage % this attack adds to the victim on hit.
@export var damage: float = 8.0
## Base knockback this attack applies (grows further as the victim's health drops).
@export var knockback: float = 400.0
## Upward part of knockback as a fraction of the sideways force (low = flat push).
@export var knockback_up_ratio: float = 0.18
## How long the attack pose / active window lasts, in seconds.
@export var duration: float = 0.25
## Cooldown before THIS skill can be used again, in seconds.
@export var cooldown: float = 0.45

@export_group("Melee reach")
## Horizontal reach of the hitbox, in pixels.
@export var reach: float = 95.0
## Vertical reach of the hitbox, in pixels.
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
## Set FALSE if the projectile art points left.
@export var projectile_faces_right: bool = true
## Spawn point relative to the caster: x = distance in front, y = vertical offset.
@export var projectile_spawn_offset: Vector2 = Vector2(70.0, -10.0)
