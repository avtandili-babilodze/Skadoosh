extends RefCounted
## Rigged fighters: a live cutout skeleton loads, has every animation, stands on
## its feet, keeps attacks pinned to the moment they hit, blends between
## animations without popping, and its simulated hair and cloth stay calm.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const ANIMS := ["idle", "run", "jump", "fall", "land", "light_attack", "heavy_attack", "hurt", "death"]

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	var rigged: Array[HeroData] = []
	for hero: HeroData in Roster.heroes:
		if hero.rig != null:
			rigged.append(hero)
	t.check(not rigged.is_empty(), "at least one fighter is drawn by a live skeleton")
	for hero in rigged:
		await _test_rig(hero)
	_test_attack_timing()
	return true


func _test_rig(hero: HeroData) -> void:
	var who := hero.hero_name
	var fighter = PLAYER_SCENE.instantiate()
	fighter.hero = hero
	fighter.position = Vector2(400.0, 300.0)
	t.add_child(fighter)
	fighter.set_physics_process(false)
	await t.get_tree().process_frame
	var visuals: FighterVisuals = fighter.visuals
	var rig: FighterRig = visuals.rig
	t.check(rig != null, "%s builds its live skeleton" % who)
	if rig == null:
		fighter.queue_free()
		return
	t.check(not fighter.get_node("Sprite2D").visible, "%s hides the sprite-sheet drawing" % who)
	for anim: String in ANIMS:
		t.check(rig.has_animation(anim), "%s has a %s animation" % [who, anim])
	t.check(float(rig.animation_info("run").get("move_speed", 0.0)) > 0.0,
			"%s's run knows the ground speed its feet show" % who)
	for anim: String in ["light_attack", "heavy_attack"]:
		var info := rig.animation_info(anim)
		var length := rig.length_of(anim)
		var release: float = info.get("release", -1.0)
		var release_end: float = info.get("release_end", -1.0)
		t.check(release > 0.0 and release <= release_end and release_end < length,
				"%s %s marks its hit inside the animation" % [who, anim])

	# Standing: the soles rest on the floor line (the node's origin).
	rig.play("idle", false)
	for i in 30:
		rig.pose(i / 60.0, 1.0 / 60.0)
	t.check(absf(rig.lowest_point()) < 4.0,
			"%s stands on the floor line (%.1f px off)" % [who, rig.lowest_point()])

	# Every animation poses without throwing anything far from the body.
	var calm := true
	for anim: String in ANIMS:
		rig.play(anim, false)
		var length := rig.length_of(anim)
		for i in 40:
			rig.pose(length * i / 39.0, 1.0 / 60.0, Vector2(300.0, 0.0))
			if rig.extent() > 400.0:
				calm = false
	t.check(calm, "%s stays in one piece through every animation" % who)

	# Lying on the ground after death, hair and cloth rest on the floor instead
	# of hanging through it.
	rig.floor_y = 0.0
	rig.play("death", false)
	var death_length := rig.length_of("death")
	var deepest := -INF
	for i in 120:
		rig.pose(minf(death_length, i / 60.0), 1.0 / 60.0)
		if i / 60.0 > death_length * 0.6:
			deepest = maxf(deepest, rig.lowest_point())
	# Turning segments lifts hair and cloth; filler drawn around a chain's root
	# (fur behind the body) cannot turn out of the floor, so the floor hides it.
	t.check(deepest < 10.0, "%s's hair and cloth rest on the floor after falling (%.1f px below)" % [who, deepest])
	var clip: float = rig._material.get_shader_parameter("floor_clip")
	t.check(is_equal_approx(clip, FighterRig.FLOOR_CLIP), "%s is not drawn below the floor it lies on" % who)

	# Switching animations blends from the pose that was showing.
	rig.play("idle", false)
	rig.pose(0.3, 1.0 / 60.0)
	var before := rig.named_point("sword_tip") if rig.has_point("sword_tip") else rig.bone_point("n_hand", Vector2.ZERO)
	rig.play("heavy_attack")
	rig.pose(0.25, 1.0 / 120.0)
	var after := rig.named_point("sword_tip") if rig.has_point("sword_tip") else rig.bone_point("n_hand", Vector2.ZERO)
	t.check(before.distance_to(after) < 40.0, "%s blends into a new animation instead of snapping" % who)

	# The fighter drives the right animation from its state.
	visuals.select_walk_pose()
	visuals.advance(1.0 / 60.0)
	t.check(rig.current_animation() == "run", "%s runs when it moves" % who)
	fighter._begin_attack(hero.light_attack, false)
	visuals.advance(1.0 / 60.0)
	t.check(rig.current_animation() == "light_attack", "%s plays its light attack" % who)
	if rig.has_point("sword_tip"):
		t.check(visuals.trail != null, "%s's blade leaves a swing trail" % who)
	if rig.has_point("whip_grip"):
		t.check(visuals.whip != null, "%s holds a live whip" % who)
		# Through the lash the whip pays out toward the target and then recoils.
		var longest := 0.0
		for i in 40:
			visuals.advance(1.0 / 60.0)
			longest = maxf(longest, visuals.whip.tip().distance_to(rig.named_point("whip_grip")))
		t.check(longest > 60.0, "%s's whip lashes out (%.0f px)" % [who, longest])
	fighter.queue_free()
	await t.get_tree().process_frame


## A rig attack's art is timed to the skill: the wind-up fills startup, the
## marked hit stretch fills the active window, the rest fills recovery and end lag.
func _test_attack_timing() -> void:
	var skill := AttackData.new()
	skill.startup_time = 0.1
	skill.active_time = 0.08
	skill.recovery_time = 0.2
	skill.post_end_lag = 0.3
	var info := {"frames": 60, "fps": 60.0, "release": 0.2, "release_end": 0.3}
	t.check(is_zero_approx(FighterVisuals.rig_attack_time(skill, 0.0, info)),
			"a rig attack starts at the beginning of its wind-up")
	t.check(absf(FighterVisuals.rig_attack_time(skill, 0.1, info) - 0.2) < 0.001,
			"the hit pose arrives exactly when the hitbox opens")
	t.check(absf(FighterVisuals.rig_attack_time(skill, 0.18, info) - 0.3) < 0.001,
			"the hit stretch lasts exactly the active window")
	t.check(absf(FighterVisuals.rig_attack_time(skill, 0.68, info, true) - 1.0) < 0.001,
			"recovery and end lag finish the animation together")
	var previous := -1.0
	var ordered := true
	for step in 80:
		var at := FighterVisuals.rig_attack_time(skill, step * 0.01, info, true)
		if at < previous - 0.0001:
			ordered = false
		previous = at
	t.check(ordered, "rig attack playback never runs backwards")
