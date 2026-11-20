class_name FighterVisuals
extends RefCounted
## What a fighter looks like, kept apart from how it plays. The fighter owns the
## rules (state, movement, attacks) and reports what happens; this object picks
## the pose, advances animation on the render clock, and layers on procedural
## squash and bob so low-frame-count art still reads as continuous motion.

const FLASH_SHADER := preload("res://entities/player/flash.gdshader")

## Vertical speed below which the jump/dive pose is held rather than swapped.
const AIR_POSE_DEADZONE := 40.0
## How long the dash pose is kept from the start of a dash, in seconds: longer
## than the burst itself, which is over in about a tenth of a second.
const DASH_POSE_HOLD := 0.22
## How fast the white hit flash fades, in units per second.
const FLASH_FADE := 6.0
## Sideways rattle of a struck fighter while the hit is frozen, in pixels.
const HIT_RATTLE := 3.5
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const DODGE_FLASH_COLOR := Color(0.72, 0.9, 1.0)

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
## Time spent in the dash pose (rigs with a "dash" animation only).
var dash_time: float = 0.0
## Scale set by the current sheet, before procedural effects are applied.
var base_scale: float = 1.0
## Current vertical squash/stretch; 1.0 is neutral.
var squash: float = 1.0
## Distance from the body's centre down to its feet (half the collision box).
## Squash pivots on this line and the bob scales with the body, never with the
## sprite cell, which may carry empty space for long effects like a whip.
var ground_offset: float = 50.0

## Current strength of the hit flash, 1 = fully white.
var flash: float = 0.0
## The live skeleton drawing this fighter, or null for a sprite-sheet fighter.
var rig: FighterRig = null
## The blade's swing arc, for rigs that carry a sword.
var trail: SwordTrail = null
## A live whip, for rigs with a "whip_grip" point.
var whip: Whip = null

var _fighter: Fighter
var _sprite: Sprite2D
var _fallback: ColorRect
var _attack_skill: AttackData = null
var _art_faces_right: bool = true
var _was_on_floor: bool = true
var _material: ShaderMaterial


func _init(fighter: Fighter, sprite: Sprite2D, fallback: ColorRect, feet_offset: float) -> void:
	_fighter = fighter
	_sprite = sprite
	_fallback = fallback
	ground_offset = feet_offset
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_sprite.material = _material
	var hero := fighter.hero
	if hero != null and hero.rig != null:
		rig = FighterRig.new()
		rig.name = "Rig"
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		fighter.add_child(rig)
		rig.setup(hero.rig.data, hero.rig.resource_path.get_base_dir())
		rig.position = Vector2(0.0, ground_offset)
		_sprite.visible = false
		_fallback.visible = false
		if rig.has_point("sword_tip"):
			trail = SwordTrail.new()
			trail.name = "SwordTrail"
			fighter.add_child(trail)
		if rig.has_point("whip_grip"):
			whip = Whip.new()
			whip.name = "Whip"
			fighter.add_child(whip)


## True when the fighter has art for an animation ("run", "hurt", "land", ...).
func has_animation(anim: String) -> bool:
	if rig != null:
		return rig.has_animation(anim)
	var hero := _fighter.hero
	match anim:
		"run": return hero.walk_texture != null
		"hurt": return hero.hurt_texture != null
		"land": return hero.land_texture != null
		"jump", "fall": return hero.jump_texture != null or hero.fall_texture != null
	return false


# --- Poses (chosen from physics) --------------------------------------------

## Chooses which pose should be showing. Called from physics, because it depends
## on physics state; it only swaps textures, it never advances a frame.
func select_pose(move_direction: float) -> void:
	if _fighter.is_attacking():
		return
	# A rig plays an attack's recovery through the end lag that follows it, so the
	# follow-through settles into the guard instead of snapping to idle.
	if rig != null and pose == "attack" and _fighter.is_in_end_lag():
		return
	var hero := _fighter.hero
	var on_floor := _fighter.is_on_floor()
	# A dash throws a rigged fighter into its dash pose, kept for a beat after the
	# burst (while a direction is still held) so so short a move still reads.
	if rig != null and rig.has_animation("dash") and not _fighter.is_hit_stunned():
		if _fighter.is_dashing():
			if pose != "dash":
				pose = "dash"
				dash_time = 0.0
			return
		if pose == "dash" and dash_time < DASH_POSE_HOLD and move_direction != 0.0:
			return
	if _fighter.is_hit_stunned() and has_animation("hurt"):
		select_hurt_pose()
	elif not on_floor and has_animation("jump"):
		select_air_pose()
	elif pose == "land" and move_direction == 0.0 and not is_landing_done():
		return   # let the touchdown finish; moving cuts it short
	elif on_floor and move_direction != 0.0 and has_animation("run"):
		select_walk_pose()
	else:
		show_idle()


func show_idle() -> void:
	if pose == "idle":
		return
	pose = "idle"
	if rig != null:
		return
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
	if rig != null:
		return
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
	var wanted_pose := "jump" if rising else "fall"
	if rig != null:
		if pose != wanted_pose:
			pose = wanted_pose
			air_time = 0.0
		return
	var texture: Texture2D = hero.jump_texture if rising else hero.fall_texture
	if texture == null:
		texture = hero.fall_texture if rising else hero.jump_texture
	if texture == null:
		show_idle()
		return
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
	if rig != null:
		return
	var hero := _fighter.hero
	_configure(hero.hurt_texture, hero.hurt_hframes, hero.hurt_vframes,
			hero.hurt_sprite_height, hero.hurt_faces_right)


func _start_landing() -> void:
	pose = "land"
	land_time = 0.0
	if rig != null:
		return
	var hero := _fighter.hero
	_configure(hero.land_texture, hero.land_hframes, hero.land_vframes,
			hero.land_sprite_height, hero.land_faces_right)


## Shows a skill's own sheet, or the hero's shared attack pose when it has none.
func show_attack(skill: AttackData) -> void:
	_attack_skill = skill
	attack_time = 0.0
	var hero := _fighter.hero
	if rig != null:
		pose = "attack"
		return
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
		if on_floor and has_animation("land") and not busy:
			_start_landing()
		else:
			squash = LAND_SQUASH if on_floor else TAKEOFF_STRETCH
	_was_on_floor = on_floor


## True once the landing sheet has played through (or there is none to play).
func is_landing_done() -> bool:
	if rig != null:
		return land_time >= rig.length_of("land")
	var hero := _fighter.hero
	if hero.land_texture == null or hero.land_fps <= 0.0:
		return true
	var count := hero.land_frames if hero.land_frames > 0 else maxi(1, hero.land_hframes * hero.land_vframes)
	return land_time >= float(count) / hero.land_fps


## A hit was accepted: punch the squash, flash white and restart the hurt animation.
func on_hit() -> void:
	squash = HIT_SQUASH
	hurt_time = 0.0
	flash = 1.0


## Back to a clean standing state, as after a respawn.
func reset() -> void:
	air_time = 0.0
	land_time = 0.0
	squash = 1.0
	flash = 0.0
	_was_on_floor = true
	_sprite.position = Vector2.ZERO
	pose = ""
	show_idle()


# --- Per drawn frame ---------------------------------------------------------

## Animation runs on the RENDER clock, not the physics clock. Physics ticks at a
## fixed rate; a 120/144 Hz display draws far more often than that, so advancing
## frames here makes the motion smooth instead of stepping at the physics rate.
func advance(delta: float) -> void:
	if rig != null:
		_advance_rig(delta)
		return
	advance_animation(delta)
	_sprite.flip_h = (_fighter.get_facing() > 0.0) != _art_faces_right
	apply_motion(delta)
	apply_feedback(delta)


## The live skeleton's version of advance: pick the animation and the moment in
## it, pose the rig, then layer squash, flash, blink and hit rattle on top.
func _advance_rig(delta: float) -> void:
	var anim := "idle"
	var t := 0.0
	match pose:
		"walk":
			# The run plays at the speed the fighter really moves, so planted feet
			# stay planted whatever the momentum.
			var info := rig.animation_info("run")
			var natural: float = info.get("move_speed", _fighter.hero.speed)
			var rate := clampf(absf(_fighter.velocity.x) / maxf(1.0, natural), 0.55, 1.6)
			walk_time += delta * rate
			anim = "run"
			t = walk_time
		"jump", "fall":
			air_time += delta
			anim = pose
			t = air_time
		"land":
			land_time += delta
			anim = "land"
			t = land_time
		"hurt":
			hurt_time += delta
			anim = "hurt"
			t = hurt_time
		"dash":
			dash_time += delta
			anim = "dash"
			t = dash_time
		"attack":
			attack_time += delta
			if _fighter.is_diving():
				# A dive holds its plunge pose (the frame the hit starts on) until it arrives.
				attack_time = minf(attack_time, _attack_skill.startup_time)
			anim = _attack_skill.rig_animation
			if anim == "" or not rig.has_animation(anim):
				anim = "heavy_attack" if _fighter.hero.is_heavy_skill(_attack_skill) else "light_attack"
			t = rig_attack_time(_attack_skill, attack_time, rig.animation_info(anim), true)
		_:
			idle_time += delta
			t = idle_time
	rig.facing = _fighter.get_facing()
	# Chains rest on the ground the fighter stands on, and hang freely in the air.
	rig.floor_y = 0.0 if _fighter.is_on_floor() else INF
	# Attacks cut in fast so a short wind-up is not blended away.
	rig.play(anim, true, 0.03 if pose == "attack" or pose == "dash" else FighterRig.BLEND_TIME)
	rig.pose(t, delta, _fighter.velocity)

	if _fighter.is_dashing():
		squash = minf(squash, DASH_SQUASH)
	squash = move_toward(squash, 1.0, SQUASH_RECOVERY * delta)
	var sx := 1.0 / maxf(0.2, squash)
	rig.scale = Vector2(sx * rig.facing, squash)

	flash = move_toward(flash, 0.0, FLASH_FADE * delta)
	var shown := flash
	var tint := HIT_FLASH_COLOR
	if _fighter.is_dodging():
		shown = maxf(shown, 0.6)
		tint = DODGE_FLASH_COLOR
	var alpha := 1.0
	if _fighter.is_invincible() and (Time.get_ticks_msec() / 90) % 2 == 0:
		alpha = 0.4
	rig.set_feedback(shown, tint, alpha)
	var frozen := Engine.time_scale < 0.2 and _fighter.is_hit_stunned()
	rig.position = Vector2(randf_range(-HIT_RATTLE, HIT_RATTLE) if frozen else 0.0, ground_offset)
	if whip != null:
		_drive_whip(delta)
	if trail != null:
		trail.color = Roster.accent_of(_fighter.hero).lerp(Color.WHITE, 0.55)
		# Only the strike leaves an arc. A blade on its way back to rest would
		# draw a second one, and the attack would read as two cuts.
		# (A dive's cut goes straight down and has its own effect; the blade
		# turning to get there would leave an arc out to the side.)
		trail.feed(rig.named_point("sword_tip"), rig.named_point("sword_guard"), delta,
				pose == "attack" and _fighter.is_striking() and not _fighter.is_dive_attack()
				and (_attack_skill == null or _attack_skill.weapon_arc))


## The whip pays out through an attack's wind-up, snaps straight toward the
## target for the active window (cracking at its start), and recoils after.
func _drive_whip(delta: float) -> void:
	var hand := rig.named_point("whip_grip")
	var facing := _fighter.get_facing()
	var skill := _attack_skill
	var aim := Vector2(facing, 0.12).normalized()
	var straighten := 0.0
	var extension := 0.0
	if pose == "attack" and skill != null:
		whip.full_length = maxf(60.0, skill.reach * 1.12)
		# Aim from the hand at the middle of the hitbox in front of the body.
		var target := _fighter.global_position + Vector2(facing * skill.reach * 0.95, -4.0)
		aim = (target - hand).normalized() if target.distance_to(hand) > 4.0 else aim
		var startup := skill.startup_time
		var active := skill.active_time
		if attack_time < startup:
			extension = lerpf(0.25, 0.7, attack_time / maxf(startup, 0.001))
			whip.reset_crack()
		elif attack_time < startup + active:
			extension = 1.0
			straighten = 0.9
			whip.crack()
		else:
			var after := (attack_time - startup - active) / maxf(skill.recovery_time, 0.001)
			extension = lerpf(1.0, 0.0, clampf(after, 0.0, 1.0))
			straighten = maxf(0.0, 0.5 - after)
	whip.extension = move_toward(whip.extension, extension, delta * 14.0)
	# The fighter's origin is the body's centre; the ground is under its feet.
	var ground := _fighter.global_position.y + ground_offset if _fighter.is_on_floor() else INF
	whip.feed(hand, aim, straighten, delta, ground)


## Maps elapsed attack time to a moment of a rig attack animation: the wind-up
## fills the skill's startup, the stretch from `release` to `release_end` fills
## the active window (the hit), the rest fills recovery. Continuous, so the
## swing is as smooth as the display.
static func rig_attack_time(skill: AttackData, elapsed: float, info: Dictionary,
		through_end_lag: bool = false) -> float:
	if info.is_empty():
		return elapsed
	var length := float(info["frames"]) / float(info["fps"])
	var release: float = info.get("release", -1.0)
	if release < 0.0:
		var total := skill.startup_time + skill.active_time + skill.recovery_time
		return clampf(elapsed / maxf(total, 0.001), 0.0, 1.0) * length
	var release_end: float = info.get("release_end", release)
	if elapsed < skill.startup_time:
		return release * clampf(elapsed / maxf(skill.startup_time, 0.001), 0.0, 1.0)
	if elapsed < skill.startup_time + skill.active_time:
		var swing := (elapsed - skill.startup_time) / maxf(skill.active_time, 0.001)
		return lerpf(release, release_end, clampf(swing, 0.0, 1.0))
	var recovery := skill.recovery_time + (skill.post_end_lag if through_end_lag else 0.0)
	var recover := (elapsed - skill.startup_time - skill.active_time) / maxf(recovery, 0.001)
	# Recovery eases out: most of the settling happens early, the end is gentle.
	recover = 1.0 - pow(1.0 - clampf(recover, 0.0, 1.0), 1.6)
	return lerpf(release_end, length, recover)


## Flashes, blinks and rattles: the readable signs of being hit, dodging or
## being untouchable after a respawn.
func apply_feedback(delta: float) -> void:
	flash = move_toward(flash, 0.0, FLASH_FADE * delta)
	var shown := flash
	var tint := HIT_FLASH_COLOR
	if _fighter.is_dodging():
		shown = maxf(shown, 0.6)
		tint = DODGE_FLASH_COLOR
	_material.set_shader_parameter("flash", shown)
	_material.set_shader_parameter("flash_color", tint)
	# Respawn invincibility blinks on the wall clock so it reads the same in slow motion.
	var alpha := 1.0
	if _fighter.is_invincible() and (Time.get_ticks_msec() / 90) % 2 == 0:
		alpha = 0.4
	_material.set_shader_parameter("alpha", alpha)
	# While a hit is frozen the victim rattles in place, which sells the impact.
	var frozen := Engine.time_scale < 0.2 and _fighter.is_hit_stunned()
	_sprite.position.x = randf_range(-HIT_RATTLE, HIT_RATTLE) if frozen else 0.0


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
## frame (and the animation_active_frames that follow it) is pinned to the active
## window so the art's key pose happens exactly when the hit or projectile does;
## otherwise frames spread evenly over the attack.
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
	var held := clampi(skill.animation_active_frames, 1, frame_count - release)
	if elapsed < skill.startup_time + skill.active_time:
		var swing := clampf((elapsed - skill.startup_time)
				/ maxf(skill.active_time, 0.001), 0.0, 0.9999)
		return release + int(swing * held)
	var remaining := frame_count - release - held
	if remaining <= 0:
		return release + held - 1
	var recover := clampf((elapsed - skill.startup_time - skill.active_time)
			/ maxf(skill.recovery_time, 0.001), 0.0, 0.9999)
	return release + held + int(recover * remaining)


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
