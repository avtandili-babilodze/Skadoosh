class_name FighterVisuals
extends RefCounted
## What a fighter looks like, kept apart from how it plays. The fighter owns the
## rules (state, movement, attacks) and reports what happens; this object picks
## the pose, advances animation on the render clock, and layers on procedural
## squash and bob so low-frame-count art still reads as continuous motion.

## Vertical speed below which the jump/dive pose is held rather than swapped.
const AIR_POSE_DEADZONE := 40.0

# --- Procedural secondary motion -------------------------------------------
# Low frame-count artwork reads as choppy because nothing moves between frames.
# These effects keep the body in continuous motion, so 4 drawn frames still feel
# alive. Everything here is axis-aligned scaling/offset: rotating pixel art
# resamples it off-grid and looks worse than the choppiness it would hide.
## Walk bob height, as a fraction of the body's height.
const BOB_FRACTION := 0.035
## Vertical scale applied on landing (<1 flattens).
const LAND_SQUASH := 0.84
## Vertical scale applied when leaving the ground (>1 stretches).
const TAKEOFF_STRETCH := 1.13
## Vertical scale punch when taking a hit.
const HIT_SQUASH := 0.88
## Vertical scale during a dash, which reads as leaning into the burst.
const DASH_SQUASH := 0.92
## How fast squash/stretch springs back to neutral, in units per second.
const SQUASH_RECOVERY := 6.5

## The pose currently showing: idle, walk, jump, fall, land, hurt or attack.
var pose: String = ""
## Looping walk clock. Deliberately survives pose changes so the walk cycle keeps
## its phase instead of snapping back to frame 0.
var walk_time: float = 0.0
## Play-once clock for jump / fall, reset when an air pose is entered.
var air_time: float = 0.0
## Looping clock for an animated idle sheet.
var idle_time: float = 0.0
## Play-once clock for the hurt pose, restarted by every accepted hit.
var hurt_time: float = 0.0
## Play-once clock for the landing pose, restarted on every touchdown.
var land_time: float = 0.0
## Time since the current attack's artwork started.
var attack_time: float = 0.0
## Scale set by the current sheet, before procedural effects are applied.
var base_scale: float = 1.0
## Current vertical squash/stretch; 1.0 is neutral.
var squash: float = 1.0
## Distance from the body's centre down to its feet (half the collision box).
## Squash pivots on this line and the bob scales with the body, never with the
## sprite cell, which may carry empty space for long effects like a whip.
var ground_offset: float = 50.0

var _fighter: Fighter
var _sprite: Sprite2D
var _fallback: ColorRect
var _attack_skill: AttackData = null
var _art_faces_right: bool = true
var _was_on_floor: bool = true


func _init(fighter: Fighter, sprite: Sprite2D, fallback: ColorRect, feet_offset: float) -> void:
	_fighter = fighter
	_sprite = sprite
	_fallback = fallback
	ground_offset = feet_offset


# --- Poses (chosen from physics) --------------------------------------------

## Chooses which pose should be showing. Called from physics, because it depends
## on physics state; it only swaps textures, it never advances a frame.
func select_pose(move_direction: float) -> void:
	if _fighter.is_attacking():
		return
	var hero := _fighter.hero
	var on_floor := _fighter.is_on_floor()
	if _fighter.is_hit_stunned() and hero.hurt_texture != null:
		select_hurt_pose()
	elif not on_floor and (hero.jump_texture != null or hero.fall_texture != null):
		select_air_pose()
	elif pose == "land" and move_direction == 0.0 and not is_landing_done():
		return   # let the touchdown finish; moving cuts it short
	elif on_floor and move_direction != 0.0 and hero.walk_texture != null:
		select_walk_pose()
	else:
		show_idle()


func show_idle() -> void:
	if pose == "idle":
		return
	pose = "idle"
	var hero := _fighter.hero
	if hero.texture != null:
		_configure(hero.texture, hero.idle_hframes, hero.idle_vframes,
				hero.sprite_height, hero.faces_right)
	else:
		_fallback.color = hero.color
		_fallback.visible = true
		_sprite.visible = false


func select_walk_pose() -> void:
	if pose == "walk":
		return
	pose = "walk"
	var hero := _fighter.hero
	_configure(hero.walk_texture, hero.walk_hframes, hero.walk_vframes,
			hero.walk_sprite_height, hero.walk_faces_right)


## Picks the jump or dive pose. The deadzone stops the two from flickering back
## and forth at the apex of a jump, where vertical speed hovers around zero.
func select_air_pose() -> void:
	var hero := _fighter.hero
	var vertical := _fighter.velocity.y
	var rising := pose == "jump"
	if vertical < -AIR_POSE_DEADZONE:
		rising = true
	elif vertical > AIR_POSE_DEADZONE:
		rising = false
	elif pose != "jump" and pose != "fall":
		rising = vertical < 0.0
	var texture: Texture2D = hero.jump_texture if rising else hero.fall_texture
	if texture == null:
		texture = hero.fall_texture if rising else hero.jump_texture
	if texture == null:
		show_idle()
		return
	var wanted_pose := "jump" if rising else "fall"
	if pose == wanted_pose:
		return
	pose = wanted_pose
	air_time = 0.0
	_configure(texture,
			hero.jump_hframes if rising else hero.fall_hframes,
			hero.jump_vframes if rising else hero.fall_vframes,
			hero.air_sprite_height, hero.air_faces_right)


func select_hurt_pose() -> void:
	if pose == "hurt":
		return
	pose = "hurt"
	hurt_time = 0.0
	var hero := _fighter.hero
	_configure(hero.hurt_texture, hero.hurt_hframes, hero.hurt_vframes,
			hero.hurt_sprite_height, hero.hurt_faces_right)


func _start_landing() -> void:
	pose = "land"
	land_time = 0.0
	var hero := _fighter.hero
	_configure(hero.land_texture, hero.land_hframes, hero.land_vframes,
			hero.land_sprite_height, hero.land_faces_right)


## Shows a skill's own sheet, or the hero's shared attack pose when it has none.
func show_attack(skill: AttackData) -> void:
	_attack_skill = skill
	attack_time = 0.0
	var hero := _fighter.hero
	if skill.animation_texture != null:
		pose = "attack"
		_configure(skill.animation_texture, skill.animation_hframes,
				skill.animation_vframes, skill.animation_sprite_height,
				skill.animation_faces_right)
	elif hero.attack_texture != null:
		pose = "attack"
		_configure(hero.attack_texture, 1, 1, hero.sprite_height, hero.attack_faces_right)


# --- Events reported by the fighter -----------------------------------------

## Fires the impact effects the moment the fighter leaves or meets the ground.
## Call after move_and_slide, which is when is_on_floor becomes accurate.
## A hero with landing art plays it on touchdown; otherwise the body squashes.
func note_ground(on_floor: bool) -> void:
	if on_floor != _was_on_floor:
		var hero := _fighter.hero
		var busy := _fighter.is_attacking() or _fighter.is_hit_stunned()
		if on_floor and hero.land_texture != null and not busy:
			_start_landing()
		else:
			squash = LAND_SQUASH if on_floor else TAKEOFF_STRETCH
	_was_on_floor = on_floor


## True once the landing sheet has played through (or there is none to play).
func is_landing_done() -> bool:
	var hero := _fighter.hero
	if hero.land_texture == null or hero.land_fps <= 0.0:
		return true
	var count := hero.land_frames if hero.land_frames > 0 else maxi(1, hero.land_hframes * hero.land_vframes)
	return land_time >= float(count) / hero.land_fps


## A hit was accepted: punch the squash and restart the hurt animation.
func on_hit() -> void:
	squash = HIT_SQUASH
	hurt_time = 0.0


## Back to a clean standing state, as after a respawn.
func reset() -> void:
	air_time = 0.0
	land_time = 0.0
	squash = 1.0
	_was_on_floor = true
	_sprite.position.y = 0.0
	show_idle()


# --- Per drawn frame ---------------------------------------------------------

## Animation runs on the RENDER clock, not the physics clock. Physics ticks at a
## fixed rate; a 120/144 Hz display draws far more often than that, so advancing
## frames here makes the motion smooth instead of stepping at the physics rate.
func advance(delta: float) -> void:
	advance_animation(delta)
	_sprite.flip_h = (_fighter.get_facing() > 0.0) != _art_faces_right
	apply_motion(delta)


## Advances whichever animation the current pose owns.
func advance_animation(delta: float) -> void:
	var hero := _fighter.hero
	var grid_frames := maxi(1, _sprite.hframes * _sprite.vframes)
	if pose == "idle":
		var idle_count := mini(grid_frames, hero.idle_frames if hero.idle_frames > 0 else grid_frames)
		if idle_count > 1 and hero.idle_fps > 0.0:
			idle_time += delta
			_sprite.frame = int(idle_time * hero.idle_fps) % idle_count
	elif pose == "walk":
		walk_time += delta
		var count := hero.walk_frames if hero.walk_frames > 0 else grid_frames
		if count > 0:
			_sprite.frame = int(walk_time * hero.walk_fps) % count
	elif pose == "jump" or pose == "fall":
		air_time += delta
		var rising := pose == "jump"
		var configured_frames := hero.jump_frames if rising else hero.fall_frames
		var fps := hero.jump_fps if rising else hero.fall_fps
		var frame_count := mini(grid_frames,
				configured_frames if configured_frames > 0 else grid_frames)
		# Jump and dive sequences play once, then hold their final pose.
		_sprite.frame = mini(frame_count - 1, int(air_time * maxf(0.0, fps)))
	elif pose == "land":
		land_time += delta
		var land_count := mini(grid_frames, hero.land_frames if hero.land_frames > 0 else grid_frames)
		_sprite.frame = mini(land_count - 1, int(land_time * maxf(0.0, hero.land_fps)))
	elif pose == "hurt":
		hurt_time += delta
		var hurt_count := mini(grid_frames, hero.hurt_frames if hero.hurt_frames > 0 else grid_frames)
		_sprite.frame = mini(hurt_count - 1, int(hurt_time * maxf(0.0, hero.hurt_fps)))
	elif pose == "attack" and _attack_skill != null and _attack_skill.animation_texture != null:
		attack_time += delta
		var frame_count := mini(grid_frames,
				_attack_skill.animation_frames if _attack_skill.animation_frames > 0 else grid_frames)
		_sprite.frame = attack_frame_at(_attack_skill, attack_time, frame_count)


## Continuous body motion layered on top of whatever frame is showing.
func apply_motion(delta: float) -> void:
	if not _sprite.visible:
		return
	if _fighter.is_dashing():
		squash = minf(squash, DASH_SQUASH)
	squash = move_toward(squash, 1.0, SQUASH_RECOVERY * delta)

	var sy := squash
	var sx := 1.0 / maxf(0.2, sy)   # keep the silhouette's volume roughly constant
	_sprite.scale = Vector2(base_scale * sx, base_scale * sy)

	# Scaling pivots on the sprite's centre, which would lift the feet off the
	# floor. Offsetting by the ground line keeps the feet exactly where they stand.
	var anchor := ground_offset * (1.0 - sy)
	var bob := 0.0
	var hero := _fighter.hero
	if pose == "walk" and hero.walk_fps > 0.0:
		var count := hero.walk_frames if hero.walk_frames > 0 else _sprite.hframes * _sprite.vframes
		var phase := fmod(walk_time * hero.walk_fps / maxf(1.0, float(count)), 1.0)
		# abs(sin) peaks twice per cycle - once per footfall.
		bob = -absf(sin(phase * TAU)) * ground_offset * 2.0 * BOB_FRACTION
	_sprite.position.y = anchor + bob


## Maps elapsed attack time to an artwork frame. With a release frame set, that
## frame is pinned to the active window so the art's key pose happens exactly when
## the hit or projectile does; otherwise frames spread evenly over the attack.
static func attack_frame_at(skill: AttackData, elapsed: float, frame_count: int) -> int:
	var release := skill.animation_release_frame
	if release < 0 or release >= frame_count:
		var total := skill.startup_time + skill.active_time + skill.recovery_time
		var progress := clampf(elapsed / maxf(total, 0.001), 0.0, 0.9999)
		return mini(frame_count - 1, int(progress * frame_count))
	if elapsed < skill.startup_time:
		if release == 0:
			return 0
		var windup := clampf(elapsed / maxf(skill.startup_time, 0.001), 0.0, 0.9999)
		return int(windup * release)
	if elapsed < skill.startup_time + skill.active_time:
		return release
	var remaining := frame_count - release - 1
	if remaining <= 0:
		return release
	var recover := clampf((elapsed - skill.startup_time - skill.active_time)
			/ maxf(skill.recovery_time, 0.001), 0.0, 0.9999)
	return release + 1 + int(recover * remaining)


## Points the sprite at a sheet and scales one cell to the requested height.
func _configure(texture: Texture2D, hframes: int, vframes: int,
		target_height: float, faces_right: bool) -> void:
	if texture == null:
		_sprite.visible = false
		return
	var columns := maxi(1, hframes)
	var rows := maxi(1, vframes)
	var frame_height := texture.get_height() / float(rows)
	if frame_height <= 0.0:
		_sprite.visible = false
		return
	var scale_factor := target_height / frame_height
	base_scale = scale_factor
	_sprite.visible = false
	_sprite.texture = texture
	_sprite.hframes = columns
	_sprite.vframes = rows
	_sprite.frame = 0
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_art_faces_right = faces_right
	_fallback.visible = false
	_sprite.visible = true
