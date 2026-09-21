extends Node
## Lightweight, dependency-free regression suite. Run with:
## godot --headless --path . tests/test_runner.tscn

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const PROJECTILE_SCENE := preload("res://entities/projectile/projectile.tscn")
const ARENA_SCENE := preload("res://scenes/arena.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/character_select.tscn")

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _run() -> void:
	_test_hero_data()
	await _test_sprite_scale_stability()
	await _test_attack_transaction()
	await _test_ground_spike_attack()
	await _test_water_bender_projectiles()
	await _test_procedural_motion()
	await _test_idle_animation()
	await _test_hurt_animation()
	_test_attack_release_frame()
	_test_walk_sheet_alignment()
	await _test_scene_startup()
	if _failures == 0:
		print("All Skadoosh tests passed.")
	else:
		push_error("%d Skadoosh test(s) failed." % _failures)
	get_tree().quit(_failures)


func _test_hero_data() -> void:
	_check(Roster.heroes.size() >= 7, "the roster loads all seven fighters")
	var names: Dictionary = {}
	for hero: HeroData in Roster.heroes:
		_check(not hero.hero_name.is_empty(), "each fighter has a name")
		_check(not names.has(hero.hero_name), "fighter names are unique: %s" % hero.hero_name)
		names[hero.hero_name] = true
		_check(hero.ground_acceleration > 0.0, "%s has grounded acceleration" % hero.hero_name)
		_check(hero.air_acceleration > 0.0, "%s has air acceleration" % hero.hero_name)
		_validate_walk_animation(hero)
		_validate_air_animation(hero)
		_validate_death_sheet(hero)
		_validate_skill(hero, hero.light_attack)
		_validate_skill(hero, hero.heavy_attack)
		_check(is_equal_approx(hero.light_attack.post_end_lag, 0.3),
				"%s light attack has 0.3 seconds of post-skill lock" % hero.hero_name)
		_check(is_equal_approx(hero.heavy_attack.post_end_lag, 0.5),
				"%s heavy attack has 0.5 seconds of post-skill lock" % hero.hero_name)
		if (hero.light_attack != null and hero.heavy_attack != null
				and hero.light_attack.animation_texture != null
				and hero.heavy_attack.animation_texture != null):
			_check(hero.light_attack.animation_texture != hero.heavy_attack.animation_texture,
					"%s light and heavy attacks use different animation sheets" % hero.hero_name)
		if hero.hero_name == "Primordial Demon":
			_validate_primordial_demon_sheets(hero)
		elif hero.hero_name == "Waterbender":
			_check(hero.walk_frames >= 8, "Waterbender walk cycle has smooth in-between poses")
			_validate_water_bender(hero)
		elif hero.hero_name == "Lilith":
			_validate_rebuilt_hero(hero)
			_check(hero.light_attack.kind == AttackData.Kind.MELEE
					and hero.heavy_attack.kind == AttackData.Kind.MELEE,
					"Lilith fights with a melee whip")
		elif hero.hero_name == "Antiope":
			_validate_rebuilt_hero(hero)
			_check(hero.light_attack.kind == AttackData.Kind.MELEE
					and hero.heavy_attack.kind == AttackData.Kind.MELEE,
					"Antiope fights up close with shield and sword")
		elif hero.hero_name == "Kitsune":
			_validate_rebuilt_hero(hero)
			_check(hero.light_attack.kind == AttackData.Kind.RANGED,
					"Kitsune's light attack throws foxfire")
			_check(hero.light_attack.projectile_texture != hero.light_attack.animation_texture,
					"Kitsune's foxfire is its own projectile, not baked into her pose")


func _validate_walk_animation(hero: HeroData) -> void:
	if hero.walk_texture == null:
		return
	_check(hero.walk_hframes > 0 and hero.walk_vframes > 0,
			"%s has a valid walk-animation grid" % hero.hero_name)
	_check(hero.walk_texture.get_width() % hero.walk_hframes == 0,
			"%s walk sheet divides into equal columns" % hero.hero_name)
	_check(hero.walk_texture.get_height() % hero.walk_vframes == 0,
			"%s walk sheet divides into equal rows" % hero.hero_name)
	_check(hero.walk_frames >= 4, "%s walk cycle has at least four poses" % hero.hero_name)
	_check(_has_transparent_corners(hero.walk_texture),
			"%s walk sheet has transparent corners" % hero.hero_name)


func _validate_air_animation(hero: HeroData) -> void:
	var air_settings := [
		["jump", hero.jump_texture, hero.jump_hframes, hero.jump_vframes, hero.jump_frames],
		["fall/dive", hero.fall_texture, hero.fall_hframes, hero.fall_vframes, hero.fall_frames],
	]
	for setting in air_settings:
		var label: String = setting[0]
		var texture: Texture2D = setting[1]
		if texture == null:
			continue
		var hframes: int = setting[2]
		var vframes: int = setting[3]
		var frames: int = setting[4]
		_check(hframes > 0 and vframes > 0,
				"%s has a valid %s-animation grid" % [hero.hero_name, label])
		_check(texture.get_width() % hframes == 0,
				"%s %s sheet divides into equal columns" % [hero.hero_name, label])
		_check(texture.get_height() % vframes == 0,
				"%s %s sheet divides into equal rows" % [hero.hero_name, label])
		_check(_has_transparent_corners(texture),
				"%s %s sheet has transparent corners" % [hero.hero_name, label])
		if hframes * vframes > 1:
			_check(frames >= 4, "%s %s animation has at least four poses" % [hero.hero_name, label])


func _validate_skill(hero: HeroData, skill: AttackData) -> void:
	_check(skill != null, "%s has a configured skill" % hero.hero_name)
	if skill == null:
		return
	var total_time := skill.startup_time + skill.active_time + skill.recovery_time
	_check(skill.active_time > 0.0, "%s/%s has an active window" % [hero.hero_name, skill.skill_name])
	_check(total_time > 0.0, "%s/%s has valid phase timing" % [hero.hero_name, skill.skill_name])
	_check(skill.cooldown >= total_time,
			"%s/%s cooldown covers its full animation" % [hero.hero_name, skill.skill_name])
	if skill.animation_texture != null:
		_check(skill.animation_hframes > 0 and skill.animation_vframes > 0,
				"%s/%s has a valid animation grid" % [hero.hero_name, skill.skill_name])
		_check(skill.animation_texture.get_width() % skill.animation_hframes == 0,
				"%s/%s sheet divides into equal columns" % [hero.hero_name, skill.skill_name])
		_check(_has_transparent_corners(skill.animation_texture),
				"%s/%s sheet has transparent corners" % [hero.hero_name, skill.skill_name])
	if skill.kind == AttackData.Kind.RANGED:
		_check(skill.projectile_texture != null, "%s/%s has projectile art" % [hero.hero_name, skill.skill_name])
		_check(skill.projectile_radius > 0.0, "%s/%s has a projectile hitbox" % [hero.hero_name, skill.skill_name])
	elif skill.kind == AttackData.Kind.GROUND_SPIKE:
		_check(skill.ground_spike_texture != null,
				"%s/%s has ground-spike art" % [hero.hero_name, skill.skill_name])
		_check(_has_transparent_corners(skill.ground_spike_texture),
				"%s/%s ground-spike sheet has transparent corners" % [hero.hero_name, skill.skill_name])
		_check(skill.ground_spike_distance >= 300.0,
				"%s/%s erupts about four game meters away" % [hero.hero_name, skill.skill_name])
		_check(skill.ground_spike_hitbox_size.x > 0.0 and skill.ground_spike_hitbox_size.y > 0.0,
				"%s/%s has a ground-spike hitbox" % [hero.hero_name, skill.skill_name])


func _has_transparent_corners(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	return (image.get_pixel(0, 0).a < 0.01
			and image.get_pixel(last_x, 0).a < 0.01
			and image.get_pixel(0, last_y).a < 0.01
			and image.get_pixel(last_x, last_y).a < 0.01)


func _validate_primordial_demon_sheets(hero: HeroData) -> void:
	var character_sheets := [
		["walk", hero.walk_texture, hero.walk_hframes, hero.walk_vframes],
		["jump", hero.jump_texture, hero.jump_hframes, hero.jump_vframes],
		["dive", hero.fall_texture, hero.fall_hframes, hero.fall_vframes],
		["light attack", hero.light_attack.animation_texture,
				hero.light_attack.animation_hframes, hero.light_attack.animation_vframes],
		["heavy attack", hero.heavy_attack.animation_texture,
				hero.heavy_attack.animation_hframes, hero.heavy_attack.animation_vframes],
	]
	for sheet in character_sheets:
		_check(_has_clear_vertical_frame_gutters(sheet[1], sheet[2], sheet[3]),
				"Primordial Demon %s frames do not contain neighboring tails" % sheet[0])
	_check(_has_clear_vertical_frame_gutters(hero.heavy_attack.ground_spike_texture,
			hero.heavy_attack.ground_spike_hframes, hero.heavy_attack.ground_spike_vframes),
			"Primordial Demon eruption frames have isolated atlas cells")
	_check(_frames_share_visible_baseline(hero.walk_texture,
			hero.walk_hframes, hero.walk_vframes),
			"Primordial Demon walk frames share a stable ground line")
	_check_walk_pace(hero)
	_check(_frames_share_visible_baseline(hero.heavy_attack.animation_texture,
			hero.heavy_attack.animation_hframes, hero.heavy_attack.animation_vframes),
			"Primordial Demon heavy-cast frames finish on the ground")
	_check(_frames_share_visible_baseline(hero.heavy_attack.ground_spike_texture,
			hero.heavy_attack.ground_spike_hframes, hero.heavy_attack.ground_spike_vframes),
			"Primordial Demon eruption frames stay on the arena floor")
	var idle_baseline := _visible_baseline_offset(hero.texture, 1, 1, hero.sprite_height)
	var walk_baseline := _visible_baseline_offset(hero.walk_texture,
			hero.walk_hframes, hero.walk_vframes, hero.walk_sprite_height)
	var light_baseline := _visible_baseline_offset(hero.light_attack.animation_texture,
			hero.light_attack.animation_hframes, hero.light_attack.animation_vframes,
			hero.light_attack.animation_sprite_height)
	var heavy_baseline := _visible_baseline_offset(hero.heavy_attack.animation_texture,
			hero.heavy_attack.animation_hframes, hero.heavy_attack.animation_vframes,
			hero.heavy_attack.animation_sprite_height)
	_check(absf(walk_baseline - idle_baseline) <= 4.0,
			"Primordial Demon walk cycle meets her idle ground line")
	_check(absf(light_baseline - idle_baseline) <= 4.0,
			"Primordial Demon light attack meets her idle ground line")
	_check(absf(heavy_baseline - idle_baseline) <= 4.0,
			"Primordial Demon heavy cast meets her idle ground line")


## Heroes rebuilt from asset-pack sheets (Lilith, Kitsune) are cut apart and
## re-laid on one shared cell height, so every grounded pose must stand on the same
## ground line and read at one size, and the legs must keep pace with the body.
func _validate_rebuilt_hero(hero: HeroData) -> void:
	var who := hero.hero_name
	_check(hero.idle_hframes * hero.idle_vframes > 1 and hero.idle_frames >= 4,
			"%s has an animated idle" % who)
	_check(hero.texture.get_width() % hero.idle_hframes == 0
			and hero.texture.get_height() % hero.idle_vframes == 0,
			"%s idle sheet divides into equal cells" % who)
	_check(_has_transparent_corners(hero.texture), "%s idle sheet has transparent corners" % who)
	_check(_frames_share_visible_baseline(hero.texture, hero.idle_hframes, hero.idle_vframes),
			"%s idle frames share one ground line" % who)
	var idle_baseline := _visible_baseline_offset(hero.texture,
			hero.idle_hframes, hero.idle_vframes, hero.sprite_height)
	_check(hero.hurt_texture != null, "%s has a hurt animation" % who)
	var poses := [
		["walk", hero.walk_texture, hero.walk_hframes, hero.walk_vframes, hero.walk_sprite_height],
		["light attack", hero.light_attack.animation_texture, hero.light_attack.animation_hframes,
				hero.light_attack.animation_vframes, hero.light_attack.animation_sprite_height],
		["heavy attack", hero.heavy_attack.animation_texture, hero.heavy_attack.animation_hframes,
				hero.heavy_attack.animation_vframes, hero.heavy_attack.animation_sprite_height],
		["hurt", hero.hurt_texture, hero.hurt_hframes, hero.hurt_vframes, hero.hurt_sprite_height],
	]
	for pose in poses:
		_check(pose[1].get_width() % pose[2] == 0 and pose[1].get_height() % pose[3] == 0,
				"%s %s sheet divides into equal cells" % [who, pose[0]])
		var baseline := _visible_baseline_offset(pose[1], pose[2], pose[3], pose[4])
		_check(absf(baseline - idle_baseline) <= 4.0,
				"%s %s meets the idle ground line" % [who, pose[0]])
		_check(_frames_share_visible_baseline(pose[1], pose[2], pose[3]),
				"%s %s frames share one ground line" % [who, pose[0]])
	_check(hero.light_attack.animation_release_frame >= 0
			and hero.heavy_attack.animation_release_frame >= 0,
			"%s attack art is pinned to the moment it hits" % who)
	_check_walk_pace(hero)


## A planted foot should stay put: the body may travel a little further than the
## legs step each cycle, but not far enough to read as gliding.
func _check_walk_pace(hero: HeroData) -> void:
	var step := _walk_step_length(hero)
	var travel := hero.speed * float(hero.walk_frames) / hero.walk_fps
	_check(step > 0.0 and travel <= 2.0 * step * 1.3,
			"%s legs keep pace with the body (travel %.0f px per cycle, stride %.0f px)"
			% [hero.hero_name, travel, 2.0 * step])
	# ...and not by pumping the legs: past about five steps a second a walk or run
	# stops reading as natural and looks like frantic sprinting.
	var steps_per_second := 2.0 * hero.walk_fps / float(hero.walk_frames)
	_check(steps_per_second <= 5.0,
			"%s legs move at a natural pace (%.1f steps/s)" % [hero.hero_name, steps_per_second])


## On-screen step length drawn in a walk sheet, measured heel to heel. Only the
## soles (the lowest rows of each frame) are read, so a long dress that reaches the
## floor cannot hide the feet; feet are told apart by the gap between them, and
## sheets face right, so each foot's heel is its left edge.
func _walk_step_length(hero: HeroData) -> float:
	var image := hero.walk_texture.get_image()
	var cell_w: int = image.get_width() / hero.walk_hframes
	var cell_h: int = image.get_height() / hero.walk_vframes
	var count: int = hero.walk_frames if hero.walk_frames > 0 else hero.walk_hframes * hero.walk_vframes
	var widest := 0
	for k in count:
		var ox: int = (k % hero.walk_hframes) * cell_w
		var oy: int = (k / hero.walk_hframes) * cell_h
		var top := -1
		var bottom := -1
		for y in cell_h:
			for x in cell_w:
				if image.get_pixel(ox + x, oy + y).a > 0.0:
					if top < 0:
						top = y
					bottom = y
					break
		if top < 0:
			continue
		var rows := maxi(3, int((bottom - top) * 0.06))
		var first_heel := -1
		var last_heel := -1
		var previous := -100
		for x in cell_w:
			var sole := false
			for y in range(bottom - rows + 1, bottom + 1):
				if image.get_pixel(ox + x, oy + y).a > 0.0:
					sole = true
					break
			if sole:
				if x - previous > 3:
					if first_heel < 0:
						first_heel = x
					last_heel = x
				previous = x
		if first_heel >= 0 and last_heel > first_heel:
			widest = maxi(widest, last_heel - first_heel)
	return float(widest) * hero.walk_sprite_height / cell_h


## Death sheets are kept for later even though the game does not play them yet;
## make sure they stay usable in the meantime.
func _validate_death_sheet(hero: HeroData) -> void:
	if hero.death_texture == null:
		return
	var who := hero.hero_name
	_check(hero.death_hframes > 0 and hero.death_vframes > 0
			and hero.death_texture.get_width() % hero.death_hframes == 0
			and hero.death_texture.get_height() % hero.death_vframes == 0,
			"%s death sheet divides into equal cells" % who)
	_check(_has_transparent_corners(hero.death_texture), "%s death sheet has transparent corners" % who)
	var cells := hero.death_hframes * hero.death_vframes
	var frames: int = hero.death_frames if hero.death_frames > 0 else cells
	_check(frames >= 2 and frames <= cells, "%s death animation has a valid frame count" % who)


func _validate_water_bender(hero: HeroData) -> void:
	var character_sheets := [
		["idle", hero.texture, 1, 1],
		["walk", hero.walk_texture, hero.walk_hframes, hero.walk_vframes],
		["jump", hero.jump_texture, hero.jump_hframes, hero.jump_vframes],
		["fall", hero.fall_texture, hero.fall_hframes, hero.fall_vframes],
		["light attack", hero.light_attack.animation_texture,
				hero.light_attack.animation_hframes, hero.light_attack.animation_vframes],
		["heavy attack", hero.heavy_attack.animation_texture,
				hero.heavy_attack.animation_hframes, hero.heavy_attack.animation_vframes],
	]
	for sheet in character_sheets:
		_check(_has_clear_vertical_frame_gutters(sheet[1], sheet[2], sheet[3]),
				"Waterbender %s frames have isolated atlas cells" % sheet[0])
		_check(_has_opaque_pale_skin(sheet[1]),
				"Waterbender %s art uses opaque pale skin" % sheet[0])
	_check(_all_visible_pixels_are_opaque(hero.texture),
			"Waterbender idle art is fully opaque")
	_check(_frames_share_visible_baseline(hero.walk_texture,
			hero.walk_hframes, hero.walk_vframes),
			"Waterbender walk frames share a stable ground line")
	_check(_frames_share_visible_baseline(hero.light_attack.animation_texture,
			hero.light_attack.animation_hframes, hero.light_attack.animation_vframes),
			"Waterbender light-cast frames share a stable ground line")
	_check(_frames_share_visible_baseline(hero.heavy_attack.animation_texture,
			hero.heavy_attack.animation_hframes, hero.heavy_attack.animation_vframes),
			"Waterbender heavy-cast frames share a stable ground line")
	_check(is_equal_approx(hero.light_attack.projectile_range, 240.0),
			"Waterbender water spit travels three game meters")
	_check(is_equal_approx(hero.heavy_attack.projectile_range, 320.0),
			"Waterbender wave travels four game meters")
	_check(hero.heavy_attack.projectile_start_scale < hero.heavy_attack.projectile_end_scale,
			"Waterbender wave starts small and grows while traveling")
	_check(is_equal_approx(hero.heavy_attack.projectile_end_damage_multiplier, 2.0),
			"Waterbender wave reaches double damage at maximum range")
	_check(hero.heavy_attack.projectile_grounded,
			"Waterbender wave remains anchored to the ground")


func _has_clear_vertical_frame_gutters(texture: Texture2D, hframes: int,
		vframes: int, gutter_width: int = 2) -> bool:
	if texture == null or hframes <= 0 or vframes <= 0:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	if image.get_width() % hframes != 0 or image.get_height() % vframes != 0:
		return false
	var frame_width := image.get_width() / hframes
	var frame_height := image.get_height() / vframes
	for row in range(vframes):
		var top := row * frame_height
		for column in range(hframes):
			var left := column * frame_width
			var right := left + frame_width - 1
			for inset in range(gutter_width):
				for y in range(top, top + frame_height):
					if (image.get_pixel(left + inset, y).a >= 0.01
							or image.get_pixel(right - inset, y).a >= 0.01):
						return false
	return true


func _has_opaque_pale_skin(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	var pale_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if (color.r >= 0.70 and color.g >= 0.60 and color.b >= 0.60
					and color.r >= color.g and absf(color.g - color.b) <= 0.09
					and color.a >= 0.99):
				pale_pixels += 1
	return pale_pixels > 32


func _all_visible_pixels_are_opaque(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha >= 0.01 and alpha < 0.99:
				return false
	return true


func _frames_share_visible_baseline(texture: Texture2D, hframes: int,
		vframes: int, tolerance: int = 1) -> bool:
	if texture == null or hframes <= 0 or vframes <= 0:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	if image.get_width() % hframes != 0 or image.get_height() % vframes != 0:
		return false
	var frame_width := image.get_width() / hframes
	var frame_height := image.get_height() / vframes
	var shared_bottom := -1
	for row in range(vframes):
		for column in range(hframes):
			var frame_bottom := -1
			for y in range(frame_height - 1, -1, -1):
				for x in range(frame_width):
					if image.get_pixel(column * frame_width + x, row * frame_height + y).a >= 0.01:
						frame_bottom = y
						break
				if frame_bottom >= 0:
					break
			if frame_bottom < 0:
				return false
			if shared_bottom < 0:
				shared_bottom = frame_bottom
			elif absi(frame_bottom - shared_bottom) > tolerance:
				return false
	return true


func _visible_baseline_offset(texture: Texture2D, hframes: int,
		vframes: int, sprite_height: float) -> float:
	if texture == null or hframes <= 0 or vframes <= 0:
		return INF
	var image := texture.get_image()
	if image == null or image.is_empty():
		return INF
	var frame_width: int = image.get_width() / hframes
	var frame_height: int = image.get_height() / vframes
	for y in range(frame_height - 1, -1, -1):
		for x in range(frame_width):
			if image.get_pixel(x, y).a >= 0.01:
				return (y - frame_height * 0.5) * sprite_height / frame_height
	return INF


func _test_sprite_scale_stability() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.walk_texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		add_child(fighter)
		await get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		fighter._select_walk_pose()
		fighter._advance_animation(0.0)
		var walk_height := sprite.texture.get_height() / float(sprite.vframes) * absf(sprite.scale.y)
		_check(absf(walk_height - hero.walk_sprite_height) < 0.01,
				"%s keeps its configured size when movement starts" % hero.hero_name)
		fighter._show_idle()
		var idle_height := sprite.texture.get_height() / float(sprite.vframes) * absf(sprite.scale.y)
		_check(absf(idle_height - hero.sprite_height) < 0.01,
				"%s keeps its configured size when movement stops" % hero.hero_name)
		for skill: AttackData in [hero.light_attack, hero.heavy_attack]:
			fighter._show_attack_animation(skill)
			var attack_height := (sprite.texture.get_height() / float(sprite.vframes)
					* absf(sprite.scale.y))
			_check(absf(attack_height - skill.animation_sprite_height) < 0.01,
					"%s/%s keeps its configured attack size" % [
						hero.hero_name, skill.skill_name])
		fighter.queue_free()
		await get_tree().process_frame


func _test_attack_transaction() -> void:
	var fighter = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	fighter.hero = Roster.heroes[0]
	target.hero = Roster.heroes[1]
	fighter.position = Vector2(300.0, 300.0)
	target.position = Vector2(360.0, 300.0)
	add_child(fighter)
	add_child(target)
	await get_tree().physics_frame
	fighter._select_walk_pose()
	fighter._advance_animation(0.2)
	_check(fighter.get_node("Sprite2D").frame > 0, "walk animation advances beyond its first pose")
	var heavy: AttackData = fighter.hero.heavy_attack
	var light: AttackData = fighter.hero.light_attack
	_check(fighter._begin_attack(heavy, true), "a free fighter can begin an attack")
	_check(not fighter._begin_attack(light, false), "a second same-frame attack is rejected")
	var damage_before: float = target.damage_taken
	# Phase timing is physics-driven; the artwork advances on the render clock.
	# Step both by the same amount so this mirrors a real frame.
	fighter._tick_attack(heavy.startup_time * 0.5)
	fighter._advance_animation(heavy.startup_time * 0.5)
	_check(target.damage_taken == damage_before, "melee does not hit during startup")
	fighter._tick_attack(heavy.startup_time * 0.5 + 0.001)
	fighter._advance_animation(heavy.startup_time * 0.5 + 0.001)
	_check(target.damage_taken > damage_before, "melee hits when the active phase begins")
	_check(fighter.get_node("Sprite2D").frame > 0, "attack animation advances with phase timing")
	var damage_after_hit: float = target.damage_taken
	fighter._tick_attack(heavy.active_time * 0.5)
	_check(target.damage_taken == damage_after_hit, "one attack cannot hit the same target twice")
	fighter._tick_attack(heavy.startup_time + heavy.active_time + heavy.recovery_time + 0.01)
	_check(not fighter._begin_attack(light, false), "heavy attack blocks all actions during post-skill lock")
	fighter._tick_state(heavy.post_end_lag - 0.01)
	_check(not fighter._begin_attack(light, false), "heavy lock lasts the full 0.5 seconds")
	fighter._tick_state(0.02)
	_check(fighter._begin_attack(light, false), "fighter regains control after heavy post-skill lock")
	fighter._tick_attack(light.startup_time + light.active_time + light.recovery_time + 0.01)
	_check(not fighter._begin_attack(heavy, true), "light attack blocks all actions during post-skill lock")
	fighter._tick_state(light.post_end_lag - 0.01)
	_check(not fighter._begin_attack(heavy, true), "light lock lasts the full 0.3 seconds")
	fighter._tick_state(0.02)
	_check(fighter._begin_attack(heavy, true), "fighter regains control after light post-skill lock")
	fighter.queue_free()
	target.queue_free()
	await get_tree().process_frame


func _test_ground_spike_attack() -> void:
	var demon: HeroData = null
	for hero: HeroData in Roster.heroes:
		if hero.hero_name == "Primordial Demon":
			demon = hero
			break
	_check(demon != null, "Primordial Demon is selectable")
	if demon == null:
		return

	var fighter = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(900.0, 20.0)
	floor_shape.shape = floor_rectangle
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(570.0, 360.0)
	floor_body.add_child(floor_shape)
	fighter.hero = demon
	target.hero = Roster.heroes[0]
	fighter.position = Vector2(250.0, 300.0)
	target.position = Vector2(250.0 + demon.heavy_attack.ground_spike_distance, 300.0)
	add_child(floor_body)
	add_child(fighter)
	add_child(target)
	await get_tree().physics_frame
	# Keep the collider pair stationary while the spawned hazard runs normally.
	fighter.set_physics_process(false)
	target.set_physics_process(false)
	fighter.velocity.y = -100.0
	fighter._select_air_pose()
	fighter._advance_animation(0.2)
	_check(fighter.get_node("Sprite2D").frame > 0, "Primordial Demon's jump sheet animates")
	fighter._select_air_pose()
	fighter._advance_animation(10.0)
	_check(fighter.get_node("Sprite2D").frame == demon.jump_frames - 1,
			"Primordial Demon's jump holds its final pose instead of looping")
	fighter.velocity.y = 100.0
	fighter._select_air_pose()
	fighter._advance_animation(0.2)
	_check(fighter.get_node("Sprite2D").frame > 0, "Primordial Demon's dive sheet animates")
	fighter._select_air_pose()
	fighter._advance_animation(10.0)
	_check(fighter.get_node("Sprite2D").frame == demon.fall_frames - 1,
			"Primordial Demon's dive holds its final pose instead of looping")
	var damage_before: float = target.damage_taken
	_check(fighter._begin_attack(demon.heavy_attack, true), "Primordial Demon can cast her eruption")
	var hazards := get_tree().get_nodes_in_group("ground_hazards")
	_check(hazards.size() == 1,
			"the heavy cast shows its warning crack immediately")
	if hazards.size() == 1:
		_check(absf(hazards[0].global_position.y - 350.0) < 1.0,
				"the heavy eruption snaps to the arena floor")
	await get_tree().create_timer(demon.heavy_attack.ground_spike_delay * 0.6).timeout
	_check(target.damage_taken == damage_before, "ground spikes do not hit during their warning")
	await get_tree().create_timer(demon.heavy_attack.ground_spike_delay * 0.6 + 0.05).timeout
	_check(target.damage_taken > damage_before, "erupted ground spikes damage a fighter at four meters")
	var damage_after_hit: float = target.damage_taken
	await get_tree().create_timer(demon.heavy_attack.ground_spike_active_time).timeout
	_check(target.damage_taken == damage_after_hit, "one eruption cannot hit the same fighter twice")
	for hazard in get_tree().get_nodes_in_group("ground_hazards"):
		hazard.queue_free()
	fighter.queue_free()
	target.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame


func _test_water_bender_projectiles() -> void:
	var water_bender: HeroData = null
	for hero: HeroData in Roster.heroes:
		if hero.hero_name == "Waterbender":
			water_bender = hero
			break
	_check(water_bender != null, "Waterbender is selectable")
	if water_bender == null:
		return

	var skill := water_bender.heavy_attack
	var wave = PROJECTILE_SCENE.instantiate()
	wave.configure(self, 1.0, skill.damage, skill.knockback, skill.knockback_up_ratio,
			skill.projectile_speed, skill.projectile_range, skill.projectile_lifetime,
			skill.projectile_texture, skill.projectile_height, skill.projectile_radius,
			skill.projectile_faces_right, skill.projectile_start_scale,
			skill.projectile_end_scale, skill.projectile_end_damage_multiplier,
			skill.projectile_grounded)
	add_child(wave)
	wave.global_position = Vector2(300.0, 300.0)
	wave.set_physics_process(false)
	var start_position: Vector2 = wave.global_position
	var start_radius: float = (wave.get_node("CollisionShape2D").shape as CircleShape2D).radius
	_check(is_equal_approx(wave.get_current_damage(), skill.damage),
			"the wave begins at its configured base damage")
	wave._physics_process(skill.projectile_range / skill.projectile_speed + 0.01)
	_check(is_equal_approx(wave.global_position.x - start_position.x, skill.projectile_range),
			"the wave stops exactly at its four-meter maximum range")
	_check(is_equal_approx(wave.get_travel_progress(), 1.0),
			"the wave reaches full travel progress at maximum range")
	_check(is_equal_approx(wave.get_current_damage(), skill.damage * 2.0),
			"the wave deals exactly double base damage at four meters")
	var end_radius: float = (wave.get_node("CollisionShape2D").shape as CircleShape2D).radius
	_check(end_radius > start_radius, "the wave hitbox scales up with its artwork")
	_check(wave.get_node("Sprite2D").position.y < 0.0
			and wave.get_node("CollisionShape2D").position.y < 0.0,
			"the growing wave stays bottom-anchored to the arena floor")
	wave.queue_free()
	await get_tree().process_frame


func _test_scene_startup() -> void:
	# Exercise the select screen with a roster much larger than the current game.
	# Reusing hero resources keeps this test lightweight while proving the layout wraps.
	var original_roster_size := Roster.heroes.size()
	while Roster.heroes.size() < 20:
		Roster.heroes.append(Roster.heroes[Roster.heroes.size() % original_roster_size])
	var character_select = CHARACTER_SELECT_SCENE.instantiate()
	add_child(character_select)
	await get_tree().process_frame
	_check(character_select.get_child_count() > 0, "character-select UI builds successfully")
	var roster_scroll: ScrollContainer = character_select.get_node("RosterScroll")
	var hero_grid: GridContainer = roster_scroll.get_node("GridCenter/HeroGrid")
	_check(hero_grid.get_child_count() == Roster.heroes.size(),
			"character select creates a card for every fighter in a large roster")
	_check(hero_grid.columns > 1 and hero_grid.columns < Roster.heroes.size(),
			"large rosters wrap into a responsive multi-row grid")
	character_select._move(0, -1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(roster_scroll.scroll_vertical > 0,
			"the roster automatically scrolls to an off-screen selected fighter")
	character_select.queue_free()
	await get_tree().process_frame
	Roster.heroes.resize(original_roster_size)

	var arena = ARENA_SCENE.instantiate()
	# Audio playback teardown is asynchronous on some headless drivers. The scene
	# test validates gameplay/UI initialization, so detach music before _ready.
	arena.get_node("Music").stream = null
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(arena.get_node_or_null("Player1") != null, "arena creates Player 1")
	_check(arena.get_node_or_null("Player2") != null, "arena creates Player 2")
	_check(arena.get_node_or_null("HUD/Message") != null, "arena creates its HUD")
	var music: AudioStreamPlayer = arena.get_node("Music")
	music.stop()
	music.stream = null
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout


## Procedural secondary motion: the effects that keep a low-frame-count sprite
## moving between drawn frames.
func _test_procedural_motion() -> void:
	var hero: HeroData = Roster.heroes[0]
	if hero.walk_texture == null:
		return
	var fighter = PLAYER_SCENE.instantiate()
	fighter.hero = hero
	add_child(fighter)
	await get_tree().process_frame
	var sprite: Sprite2D = fighter.get_node("Sprite2D")
	fighter._select_walk_pose()

	# Landing flattens the body, and the sprite is pushed down by half the height
	# it lost, so the feet stay on the floor instead of floating above it.
	fighter._anim_time = 0.0
	fighter._squash = fighter.LAND_SQUASH
	fighter._apply_procedural_motion(0.0)
	_check(sprite.scale.y < fighter._base_scale,
			"landing squashes the fighter vertically")
	_check(sprite.scale.x > fighter._base_scale,
			"squash widens the silhouette so volume is preserved")
	_check(sprite.position.y > 0.0,
			"squash is anchored to the feet rather than lifting them")
	var feet_y: float = (sprite.position.y
			+ fighter._ground_offset * sprite.scale.y / fighter._base_scale)
	_check(absf(feet_y - fighter._ground_offset) < 0.01,
			"squash keeps the feet exactly on the ground line")

	# The spring returns to neutral, leaving the pose exactly as authored.
	fighter._apply_procedural_motion(2.0)
	_check(absf(sprite.scale.y - fighter._base_scale) < 0.001,
			"squash springs back to the authored scale")

	# The walk bob moves the body even on frames where the artwork is unchanged.
	var count: int = hero.walk_frames if hero.walk_frames > 0 else 4
	fighter._squash = 1.0
	fighter._anim_time = 0.0
	fighter._apply_procedural_motion(0.0)
	var flat_y: float = sprite.position.y
	fighter._squash = 1.0
	fighter._anim_time = 0.25 * float(count) / hero.walk_fps
	fighter._apply_procedural_motion(0.0)
	_check(sprite.position.y < flat_y,
			"the walk bob lifts the body between footfalls")

	# Leaving the ground stretches, meeting it squashes.
	fighter._was_on_floor = true
	fighter._squash = 1.0
	fighter.velocity.y = -100.0
	fighter._update_ground_transition()
	_check(fighter._squash > 1.0, "leaving the ground stretches the fighter")

	fighter.queue_free()
	await get_tree().process_frame


## Every frame of a walk sheet must share a feet baseline. When a sheet's rows are
## assembled at different vertical offsets the character hitches upward partway
## through the cycle, which reads as broken animation regardless of frame count.
func _test_walk_sheet_alignment() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.walk_texture == null:
			continue
		var image: Image = hero.walk_texture.get_image()
		var hf: int = maxi(1, hero.walk_hframes)
		var vf: int = maxi(1, hero.walk_vframes)
		var cell_w: int = image.get_width() / hf
		var cell_h: int = image.get_height() / vf
		var lowest: int = -1
		var highest: int = -1
		for r in vf:
			for c in hf:
				var baseline: int = -1
				for y in range(cell_h - 1, -1, -1):
					var hit := false
					# Sampling every 4th column is ample for locating a baseline.
					for x in range(0, cell_w, 4):
						if image.get_pixel(c * cell_w + x, r * cell_h + y).a > 0.03:
							hit = true
							break
					if hit:
						baseline = y
						break
				if baseline < 0:
					continue
				if lowest < 0 or baseline > lowest:
					lowest = baseline
				if highest < 0 or baseline < highest:
					highest = baseline
		var spread: int = lowest - highest
		_check(spread <= int(cell_h * 0.03) + 2,
				"%s walk frames share a feet baseline (spread %d px)" % [
					hero.hero_name, spread])


## An idle sheet loops on the render clock like the walk cycle does.
func _test_idle_animation() -> void:
	for hero: HeroData in Roster.heroes:
		var count: int = hero.idle_frames if hero.idle_frames > 0 else hero.idle_hframes * hero.idle_vframes
		if count <= 1 or hero.texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		add_child(fighter)
		await get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		fighter._pose = ""
		fighter._show_idle()
		_check(sprite.hframes == hero.idle_hframes and sprite.vframes == hero.idle_vframes,
				"%s idle uses its sheet grid" % hero.hero_name)
		fighter._idle_time = 0.0
		fighter._advance_animation(0.0)
		var first: int = sprite.frame
		fighter._advance_animation(1.01 / hero.idle_fps)
		_check(sprite.frame != first, "%s idle animation advances" % hero.hero_name)
		fighter._advance_animation(float(count) / hero.idle_fps)
		_check(sprite.frame < count, "%s idle animation loops within its frames" % hero.hero_name)
		fighter.queue_free()
		await get_tree().process_frame


## A release frame pins the art's key pose to the active window: wind-up frames
## fill startup, the release frame covers the hit, the rest fill recovery.
func _test_attack_release_frame() -> void:
	var fighter = PLAYER_SCENE.instantiate()
	var skill := AttackData.new()
	skill.startup_time = 0.16
	skill.active_time = 0.06
	skill.recovery_time = 0.28
	var frames := 8
	skill.animation_release_frame = 5
	_check(fighter._attack_frame_at(skill, 0.0, frames) == 0,
			"release-frame attacks start on the first wind-up frame")
	_check(fighter._attack_frame_at(skill, 0.159, frames) < 5,
			"release frame stays hidden during startup")
	_check(fighter._attack_frame_at(skill, 0.161, frames) == 5,
			"release frame shows the moment the active window opens")
	_check(fighter._attack_frame_at(skill, 0.219, frames) == 5,
			"release frame holds for the whole active window")
	_check(fighter._attack_frame_at(skill, 0.499, frames) == frames - 1,
			"recovery finishes on the last frame")
	var previous := -1
	var ordered := true
	for step in 51:
		var frame: int = fighter._attack_frame_at(skill, step * 0.01, frames)
		if frame < previous:
			ordered = false
		previous = frame
	_check(ordered, "release-frame playback never runs backwards")
	skill.animation_release_frame = -1
	_check(fighter._attack_frame_at(skill, 0.25, frames) == 4,
			"without a release frame, frames still spread evenly")
	fighter.free()


## A hero with hurt art shows it while stunned, plays it once, then lets go.
func _test_hurt_animation() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.hurt_texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		add_child(fighter)
		await get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		_check(fighter.take_hit(5.0, 100.0, 1.0, 0.1), "%s accepts a test hit" % hero.hero_name)
		fighter._select_pose()
		_check(fighter._pose == "hurt" and sprite.texture == hero.hurt_texture,
				"%s shows the hurt pose while stunned" % hero.hero_name)
		fighter._advance_animation(10.0)
		var count: int = hero.hurt_frames if hero.hurt_frames > 0 else hero.hurt_hframes * hero.hurt_vframes
		_check(sprite.frame == count - 1, "%s hurt animation plays once and holds" % hero.hero_name)
		fighter._state = fighter.FighterState.FREE
		fighter._select_pose()
		_check(fighter._pose != "hurt", "%s leaves the hurt pose when the stun ends" % hero.hero_name)
		fighter.queue_free()
		await get_tree().process_frame

