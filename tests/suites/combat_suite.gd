extends RefCounted
## Combat: attack transactions, melee timing, ground hazards and projectiles.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const PROJECTILE_SCENE := preload("res://entities/projectile/projectile.tscn")

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	await _test_attack_transaction()
	await _test_ground_spike_attack()
	await _test_water_bender_projectiles()
	await _test_animated_projectile()
	return true

func _test_attack_transaction() -> void:
	var fighter = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	# A melee fighter, so the hitbox timing below is about melee; prefer one still
	# drawn from sprite sheets for the frame checks (rigs are covered by rig_suite).
	var pick: HeroData = null
	for hero: HeroData in Roster.heroes:
		if hero.heavy_attack.kind == AttackData.Kind.MELEE and hero.light_attack.kind == AttackData.Kind.MELEE:
			if pick == null or (pick.rig != null and hero.rig == null):
				pick = hero
	fighter.hero = pick
	target.hero = Roster.heroes[1]
	fighter.position = Vector2(300.0, 300.0)
	target.position = Vector2(360.0, 300.0)
	t.add_child(fighter)
	t.add_child(target)
	await t.get_tree().physics_frame
	var sheet_drawn: bool = fighter.visuals.rig == null
	fighter.visuals.select_walk_pose()
	fighter.visuals.advance_animation(0.2)
	if sheet_drawn:
		t.check(fighter.get_node("Sprite2D").frame > 0, "walk animation advances beyond its first pose")
	var heavy: AttackData = fighter.hero.heavy_attack
	var light: AttackData = fighter.hero.light_attack
	t.check(fighter._begin_attack(heavy, true), "a free fighter can begin an attack")
	t.check(not fighter._begin_attack(light, false), "a second same-frame attack is rejected")
	var damage_before: float = target.damage_taken
	# Phase timing is physics-driven; the artwork advances on the render clock.
	# Step both by the same amount so this mirrors a real frame.
	fighter._tick_attack(heavy.startup_time * 0.5)
	fighter.visuals.advance_animation(heavy.startup_time * 0.5)
	t.check(target.damage_taken == damage_before, "melee does not hit during startup")
	fighter._tick_attack(heavy.startup_time * 0.5 + 0.001)
	fighter.visuals.advance_animation(heavy.startup_time * 0.5 + 0.001)
	t.check(target.damage_taken > damage_before, "melee hits when the active phase begins")
	if sheet_drawn:
		t.check(fighter.get_node("Sprite2D").frame > 0, "attack animation advances with phase timing")
	var damage_after_hit: float = target.damage_taken
	fighter._tick_attack(heavy.active_time * 0.5)
	t.check(target.damage_taken == damage_after_hit, "one attack cannot hit the same target twice")
	fighter._tick_attack(heavy.startup_time + heavy.active_time + heavy.recovery_time + 0.01)
	t.check(not fighter._begin_attack(light, false), "heavy attack blocks all actions during post-skill lock")
	fighter._tick_state(heavy.post_end_lag - 0.01)
	t.check(not fighter._begin_attack(light, false), "heavy lock lasts the full 0.5 seconds")
	fighter._tick_state(0.02)
	t.check(fighter._begin_attack(light, false), "fighter regains control after heavy post-skill lock")
	fighter._tick_attack(light.startup_time + light.active_time + light.recovery_time + 0.01)
	t.check(not fighter._begin_attack(heavy, true), "light attack blocks all actions during post-skill lock")
	fighter._tick_state(light.post_end_lag - 0.01)
	t.check(not fighter._begin_attack(heavy, true), "light lock lasts the full 0.3 seconds")
	fighter._tick_state(0.02)
	t.check(fighter._begin_attack(heavy, true), "fighter regains control after light post-skill lock")
	fighter.queue_free()
	target.queue_free()
	t.get_tree().call_group("projectiles", "queue_free")
	await t.get_tree().process_frame


func _test_ground_spike_attack() -> void:
	var demon: HeroData = null
	for hero: HeroData in Roster.heroes:
		if hero.hero_name == "Primordial Demon":
			demon = hero
			break
	t.check(demon != null, "Primordial Demon is selectable")
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
	t.add_child(floor_body)
	t.add_child(fighter)
	t.add_child(target)
	await t.get_tree().physics_frame
	# Keep the collider pair stationary while the spawned hazard runs normally.
	fighter.set_physics_process(false)
	target.set_physics_process(false)
	# Sheet-drawn air poses play once and hold (a live rig is checked in rig_suite).
	if demon.rig == null:
		fighter.velocity.y = -100.0
		fighter.visuals.select_air_pose()
		fighter.visuals.advance_animation(0.2)
		t.check(fighter.get_node("Sprite2D").frame > 0, "Primordial Demon's jump sheet animates")
		fighter.visuals.select_air_pose()
		fighter.visuals.advance_animation(10.0)
		t.check(fighter.get_node("Sprite2D").frame == demon.jump_frames - 1,
				"Primordial Demon's jump holds its final pose instead of looping")
		fighter.velocity.y = 100.0
		fighter.visuals.select_air_pose()
		fighter.visuals.advance_animation(0.2)
		t.check(fighter.get_node("Sprite2D").frame > 0, "Primordial Demon's dive sheet animates")
		fighter.visuals.select_air_pose()
		fighter.visuals.advance_animation(10.0)
		t.check(fighter.get_node("Sprite2D").frame == demon.fall_frames - 1,
				"Primordial Demon's dive holds its final pose instead of looping")
	var damage_before: float = target.damage_taken
	t.check(fighter._begin_attack(demon.heavy_attack, true), "Primordial Demon can cast her eruption")
	var hazards: Array[Node] = t.get_tree().get_nodes_in_group("ground_hazards")
	t.check(hazards.size() == 1,
			"the heavy cast shows its warning crack immediately")
	if hazards.size() == 1:
		t.check(absf(hazards[0].global_position.y - 350.0) < 1.0,
				"the heavy eruption snaps to the arena floor")
	await t.get_tree().create_timer(demon.heavy_attack.ground_spike_delay * 0.6).timeout
	t.check(target.damage_taken == damage_before, "ground spikes do not hit during their warning")
	await t.get_tree().create_timer(demon.heavy_attack.ground_spike_delay * 0.6 + 0.05).timeout
	t.check(target.damage_taken > damage_before, "erupted ground spikes damage a fighter at four meters")
	var damage_after_hit: float = target.damage_taken
	await t.get_tree().create_timer(demon.heavy_attack.ground_spike_active_time).timeout
	t.check(target.damage_taken == damage_after_hit, "one eruption cannot hit the same fighter twice")
	for hazard in t.get_tree().get_nodes_in_group("ground_hazards"):
		hazard.queue_free()
	fighter.queue_free()
	target.queue_free()
	floor_body.queue_free()
	await t.get_tree().process_frame


func _test_water_bender_projectiles() -> void:
	var water_bender: HeroData = null
	for hero: HeroData in Roster.heroes:
		if hero.hero_name == "Waterbender":
			water_bender = hero
			break
	t.check(water_bender != null, "Waterbender is selectable")
	if water_bender == null:
		return

	var skill := water_bender.heavy_attack
	var wave = PROJECTILE_SCENE.instantiate()
	wave.configure(t, 1.0, skill.damage, skill.knockback, skill.knockback_up_ratio,
			skill.projectile_speed, skill.projectile_range, skill.projectile_lifetime,
			skill.projectile_texture, skill.projectile_height, skill.projectile_radius,
			skill.projectile_faces_right, skill.projectile_start_scale,
			skill.projectile_end_scale, skill.projectile_end_damage_multiplier,
			skill.projectile_grounded)
	t.add_child(wave)
	wave.global_position = Vector2(300.0, 300.0)
	wave.set_physics_process(false)
	var start_position: Vector2 = wave.global_position
	var start_radius: float = (wave.get_node("CollisionShape2D").shape as CircleShape2D).radius
	t.check(is_equal_approx(wave.get_current_damage(), skill.damage),
			"the wave begins at its configured base damage")
	wave._physics_process(skill.projectile_range / skill.projectile_speed + 0.01)
	t.check(is_equal_approx(wave.global_position.x - start_position.x, skill.projectile_range),
			"the wave stops exactly at its four-meter maximum range")
	t.check(is_equal_approx(wave.get_travel_progress(), 1.0),
			"the wave reaches full travel progress at maximum range")
	t.check(is_equal_approx(wave.get_current_damage(), skill.damage * 2.0),
			"the wave deals exactly double base damage at four meters")
	var end_radius: float = (wave.get_node("CollisionShape2D").shape as CircleShape2D).radius
	t.check(end_radius > start_radius, "the wave hitbox scales up with its artwork")
	t.check(wave.get_node("Sprite2D").position.y < 0.0
			and wave.get_node("CollisionShape2D").position.y < 0.0,
			"the growing wave stays bottom-anchored to the arena floor")
	wave.queue_free()
	await t.get_tree().process_frame


## A projectile given a sheet grid plays it as a loop and is sized by one cell.
func _test_animated_projectile() -> void:
	var image := Image.create(120, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sheet := ImageTexture.create_from_image(image)
	var orb = PROJECTILE_SCENE.instantiate()
	orb.configure(t, 1.0, 5.0, 100.0, 0.1, 300.0, 600.0, 3.0, sheet, 40.0, 12.0,
			true, 1.0, 1.0, 1.0, false)
	orb.set_animation(6, 1, 0, 10.0)
	t.add_child(orb)
	orb.set_physics_process(false)
	var sprite: Sprite2D = orb.get_node("Sprite2D")
	t.check(sprite.hframes == 6 and sprite.frame == 0, "an animated projectile starts on its first frame")
	t.check(absf(absf(sprite.scale.y) * 20.0 - 40.0) < 3.0,
			"an animated projectile is sized by one cell of its sheet")
	orb._physics_process(0.25)
	t.check(sprite.frame == 2, "an animated projectile advances through its sheet")
	orb._physics_process(0.45)
	t.check(sprite.frame == 1, "an animated projectile loops its sheet")
	orb.queue_free()
	await t.get_tree().process_frame
