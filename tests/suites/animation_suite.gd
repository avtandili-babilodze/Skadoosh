extends RefCounted
## Animation: fighters keep one size across poses, animate on the render clock,
## squash and bob around their feet, and pin attack art to the moment it hits.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> void:
	t = runner
	await _test_sprite_scale_stability()
	await _test_procedural_motion()
	await _test_idle_animation()
	await _test_hurt_animation()
	_test_attack_release_frame()
	await _test_landing_animation()

func _test_sprite_scale_stability() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.walk_texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		t.add_child(fighter)
		await t.get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		fighter.visuals.select_walk_pose()
		fighter.visuals.advance_animation(0.0)
		var walk_height := sprite.texture.get_height() / float(sprite.vframes) * absf(sprite.scale.y)
		t.check(absf(walk_height - hero.walk_sprite_height) < 0.01,
				"%s keeps its configured size when movement starts" % hero.hero_name)
		fighter.visuals.show_idle()
		var idle_height := sprite.texture.get_height() / float(sprite.vframes) * absf(sprite.scale.y)
		t.check(absf(idle_height - hero.sprite_height) < 0.01,
				"%s keeps its configured size when movement stops" % hero.hero_name)
		for skill: AttackData in [hero.light_attack, hero.heavy_attack]:
			fighter.visuals.show_attack(skill)
			var attack_height := (sprite.texture.get_height() / float(sprite.vframes)
					* absf(sprite.scale.y))
			t.check(absf(attack_height - skill.animation_sprite_height) < 0.01,
					"%s/%s keeps its configured attack size" % [
						hero.hero_name, skill.skill_name])
		fighter.queue_free()
		await t.get_tree().process_frame


## Procedural secondary motion: the effects that keep a low-frame-count sprite
## moving between drawn frames.
func _test_procedural_motion() -> void:
	var hero: HeroData = Roster.heroes[0]
	if hero.walk_texture == null:
		return
	var fighter = PLAYER_SCENE.instantiate()
	fighter.hero = hero
	t.add_child(fighter)
	await t.get_tree().process_frame
	var sprite: Sprite2D = fighter.get_node("Sprite2D")
	fighter.visuals.select_walk_pose()

	# Landing flattens the body, and the sprite is pushed down by half the height
	# it lost, so the feet stay on the floor instead of floating above it.
	fighter.visuals.walk_time = 0.0
	fighter.visuals.squash = FighterVisuals.LAND_SQUASH
	fighter.visuals.apply_motion(0.0)
	t.check(sprite.scale.y < fighter.visuals.base_scale,
			"landing squashes the fighter vertically")
	t.check(sprite.scale.x > fighter.visuals.base_scale,
			"squash widens the silhouette so volume is preserved")
	t.check(sprite.position.y > 0.0,
			"squash is anchored to the feet rather than lifting them")
	var feet_y: float = (sprite.position.y
			+ fighter.visuals.ground_offset * sprite.scale.y / fighter.visuals.base_scale)
	t.check(absf(feet_y - fighter.visuals.ground_offset) < 0.01,
			"squash keeps the feet exactly on the ground line")

	# The spring returns to neutral, leaving the pose exactly as authored.
	fighter.visuals.apply_motion(2.0)
	t.check(absf(sprite.scale.y - fighter.visuals.base_scale) < 0.001,
			"squash springs back to the authored scale")

	# The walk bob moves the body even on frames where the artwork is unchanged.
	var count: int = hero.walk_frames if hero.walk_frames > 0 else 4
	fighter.visuals.squash = 1.0
	fighter.visuals.walk_time = 0.0
	fighter.visuals.apply_motion(0.0)
	var flat_y: float = sprite.position.y
	fighter.visuals.squash = 1.0
	fighter.visuals.walk_time = 0.25 * float(count) / hero.walk_fps
	fighter.visuals.apply_motion(0.0)
	t.check(sprite.position.y < flat_y,
			"the walk bob lifts the body between footfalls")

	# Leaving the ground stretches, meeting it squashes.
	var visuals: FighterVisuals = fighter.visuals
	visuals.note_ground(true)
	visuals.squash = 1.0
	visuals.note_ground(false)
	t.check(visuals.squash > 1.0, "leaving the ground stretches the fighter")
	visuals.note_ground(true)
	t.check(visuals.squash < 1.0, "meeting the ground squashes the fighter")

	fighter.queue_free()
	await t.get_tree().process_frame


## An idle sheet loops on the render clock like the walk cycle does.
func _test_idle_animation() -> void:
	for hero: HeroData in Roster.heroes:
		var count: int = hero.idle_frames if hero.idle_frames > 0 else hero.idle_hframes * hero.idle_vframes
		if count <= 1 or hero.texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		t.add_child(fighter)
		await t.get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		fighter.visuals.pose = ""
		fighter.visuals.show_idle()
		t.check(sprite.hframes == hero.idle_hframes and sprite.vframes == hero.idle_vframes,
				"%s idle uses its sheet grid" % hero.hero_name)
		fighter.visuals.idle_time = 0.0
		fighter.visuals.advance_animation(0.0)
		var first: int = sprite.frame
		fighter.visuals.advance_animation(1.01 / hero.idle_fps)
		t.check(sprite.frame != first, "%s idle animation advances" % hero.hero_name)
		fighter.visuals.advance_animation(float(count) / hero.idle_fps)
		t.check(sprite.frame < count, "%s idle animation loops within its frames" % hero.hero_name)
		fighter.queue_free()
		await t.get_tree().process_frame


## A hero with hurt art shows it while stunned, plays it once, then lets go.
func _test_hurt_animation() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.hurt_texture == null:
			continue
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		t.add_child(fighter)
		await t.get_tree().process_frame
		var sprite: Sprite2D = fighter.get_node("Sprite2D")
		t.check(fighter.take_hit(5.0, 100.0, 1.0, 0.1), "%s accepts a test hit" % hero.hero_name)
		fighter.visuals.select_pose(0.0)
		t.check(fighter.visuals.pose == "hurt" and sprite.texture == hero.hurt_texture,
				"%s shows the hurt pose while stunned" % hero.hero_name)
		fighter.visuals.advance_animation(10.0)
		var count: int = hero.hurt_frames if hero.hurt_frames > 0 else hero.hurt_hframes * hero.hurt_vframes
		t.check(sprite.frame == count - 1, "%s hurt animation plays once and holds" % hero.hero_name)
		fighter._state = fighter.FighterState.FREE
		fighter.visuals.select_pose(0.0)
		t.check(fighter.visuals.pose != "hurt", "%s leaves the hurt pose when the stun ends" % hero.hero_name)
		fighter.queue_free()
		await t.get_tree().process_frame


## A release frame pins the art's key pose to the active window: wind-up frames
## fill startup, the release frame covers the hit, the rest fill recovery.
func _test_attack_release_frame() -> void:
	var skill := AttackData.new()
	skill.startup_time = 0.16
	skill.active_time = 0.06
	skill.recovery_time = 0.28
	var frames := 8
	skill.animation_release_frame = 5
	t.check(FighterVisuals.attack_frame_at(skill, 0.0, frames) == 0,
			"release-frame attacks start on the first wind-up frame")
	t.check(FighterVisuals.attack_frame_at(skill, 0.159, frames) < 5,
			"release frame stays hidden during startup")
	t.check(FighterVisuals.attack_frame_at(skill, 0.161, frames) == 5,
			"release frame shows the moment the active window opens")
	t.check(FighterVisuals.attack_frame_at(skill, 0.219, frames) == 5,
			"release frame holds for the whole active window")
	t.check(FighterVisuals.attack_frame_at(skill, 0.499, frames) == frames - 1,
			"recovery finishes on the last frame")
	var previous := -1
	var ordered := true
	for step in 51:
		var frame: int = FighterVisuals.attack_frame_at(skill, step * 0.01, frames)
		if frame < previous:
			ordered = false
		previous = frame
	t.check(ordered, "release-frame playback never runs backwards")
	skill.animation_release_frame = -1
	t.check(FighterVisuals.attack_frame_at(skill, 0.25, frames) == 4,
			"without a release frame, frames still spread evenly")


## Dropped onto a real floor, a fighter with landing art plays it on touchdown,
## then hands back to idle; landing while moving cuts straight into the walk.
func _test_landing_animation() -> void:
	for hero: HeroData in Roster.heroes:
		if hero.land_texture == null:
			continue
		var who := hero.hero_name
		var floor_body := StaticBody2D.new()
		var floor_shape := CollisionShape2D.new()
		var floor_rect := RectangleShape2D.new()
		floor_rect.size = Vector2(900.0, 40.0)
		floor_shape.shape = floor_rect
		floor_body.collision_layer = 1
		floor_body.collision_mask = 0
		floor_body.position = Vector2(400.0, 420.0)
		floor_body.add_child(floor_shape)
		t.add_child(floor_body)
		var fighter = PLAYER_SCENE.instantiate()
		fighter.hero = hero
		fighter.position = Vector2(400.0, 250.0)
		t.add_child(fighter)
		var visuals: FighterVisuals = fighter.visuals

		t.check(await _wait_until_landed(fighter), "%s reaches the floor in the landing test" % who)
		t.check(visuals.pose == "land" and fighter.get_node("Sprite2D").texture == hero.land_texture,
				"%s plays the landing the moment it touches down" % who)
		for i in 240:
			if visuals.pose != "land":
				break
			await t.get_tree().physics_frame
		t.check(visuals.is_landing_done() and visuals.pose == "idle",
				"%s hands back to idle once the landing has played" % who)

		# Land again, and start moving during the touchdown.
		fighter.position = Vector2(400.0, 250.0)
		fighter.velocity = Vector2.ZERO
		t.check(await _wait_until_landed(fighter), "%s lands a second time" % who)
		visuals.select_pose(1.0)
		t.check(visuals.pose == "walk", "%s moving during a landing cuts straight into the walk" % who)

		fighter.queue_free()
		floor_body.queue_free()
		await t.get_tree().process_frame


func _wait_until_landed(fighter) -> bool:
	for i in 240:
		await t.get_tree().physics_frame
		if fighter.is_on_floor():
			return true
	return false

