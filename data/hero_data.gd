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
## Multiplies gravity. 1.0 = normal fall, higher = falls faster/heavier.
@export var gravity_scale: float = 1.4
## Extra gravity multiplier while holding "down" in the air (fast fall).
@export var fast_fall_scale: float = 2.0
## Horizontal burst speed during a dash, in pixels/second.
@export var dash_speed: float = 900.0
## How long the dash burst lasts, in seconds.
@export var dash_duration: float = 0.15
## Cooldown before the player can dash again, in seconds.
@export var dash_cooldown: float = 0.6

@export_group("Combat")
@export var max_health: float = 100.0
## Incoming damage is divided by this. Higher = tankier.
@export var defense: float = 1.0
## Damage added to the victim's "% taken" on each hit (more % = bigger knockback).
@export var attack_power: float = 10.0
## Base knockback impulse applied to a hit opponent (grows with their % taken).
@export var knockback: float = 1100.0
## Upward part of knockback as a fraction of the sideways force.
## Low = mostly horizontal push with little vertical pop.
@export var knockback_up_ratio: float = 0.18
## Horizontal reach of the attack, in pixels.
@export var attack_range: float = 95.0
## Vertical reach of the attack, in pixels.
@export var attack_height: float = 90.0
## How long the attack pose / active window lasts, in seconds.
@export var attack_duration: float = 0.25
## Cooldown before the next attack, in seconds.
@export var attack_cooldown: float = 0.45

@export_group("Attack Appearance")
## Image shown while attacking. Falls back to the normal texture if empty.
@export var attack_texture: Texture2D
## Set FALSE if the attack art is drawn facing left.
@export var attack_faces_right: bool = true

@export_group("Appearance")
## Avatar image for this hero. If set, it's shown instead of the color box.
## Drop a PNG/JPG into res://assets/sprites/ and assign it here.
@export var texture: Texture2D
## Which way the art is drawn. Set FALSE if the character faces left in the image.
@export var faces_right: bool = true
## Fallback body color, used when no texture is assigned.
@export var color: Color = Color(0.3, 0.6, 1.0)
## Height in pixels to scale the avatar to (keeps big images from filling the screen).
@export var sprite_height: float = 110.0
