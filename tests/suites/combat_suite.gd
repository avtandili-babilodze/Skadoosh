extends RefCounted
## Combat: attack transactions, melee timing, what a hit and a miss cost, how
## attacks move the fighter, ground hazards and projectiles.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const PROJECTILE_SCENE := preload("res://entities/projectile/projectile.tscn")

## Top of the test floor (see _floor) and where a fighter's centre rests on it.
const FLOOR_TOP := 350.0
const STANDING := FLOOR_TOP - 50.0


## Commands written by a test instead of read from the keyboard: each entry of
## `presses` is the set of buttons pressed on one physics tick.
class Pad extends FighterInput:
	var presses: Array = []

	func poll(_fighter: Fighter, _delta: float) -> void:
		pressed = presses.pop_front() if not presses.is_empty() else {}

	func press(action: String) -> void:
		presses.append({action: true})


## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	await _test_attack_transaction()
	await _test_missed_attack_end_lag()
	await _test_point_blank_hit()
	await _test_light_into_heavy_combo()
	await _test_attack_movement()
	await _test_rising_heavy()
	await _test_aimed_attacks()
	await _test_dash_pose()
	await _test_dive()
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
	# A hit that lands gives the attacker the advantage: the rest of the attack
	# can be cut short, and it ends without the end lag a miss would cost.
	t.check(not fighter.can_cancel(), "the contact pose is held for a moment before a landed hit can be cut short")
	fighter._tick_cooldowns(Fighter.HIT_CANCEL_DELAY + 0.001)
	t.check(fighter.can_cancel(), "a landed hit can be cut short")
	t.check(fighter.can_use(light, false), "the other skill is ready to follow a landed hit")
	t.check(not fighter.can_use(heavy, true), "a skill cannot be cut short into itself")
	t.check(target._state_time_left > heavy.active_time + heavy.recovery_time * 0.5,
			"the rival is still stunned while the attacker can already act")
	fighter._tick_attack(heavy.active_time + heavy.recovery_time + 0.01)
	t.check(fighter.is_free(), "an attack that landed ends without end lag")
	fighter.queue_free()
	target.queue_free()
	t.get_tree().call_group("projectiles", "queue_free")
	await t.get_tree().process_frame


## A solid floor wide enough for a short exchange, with its top at FLOOR_TOP.
func _floor(centre_x: float = 570.0, width: float = 900.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, 20.0)
	shape.shape = box
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(centre_x, FLOOR_TOP + 10.0)
	body.add_child(shape)
	t.add_child(body)
	return body


func _hero(hero_name: String) -> HeroData:
	for hero: HeroData in Roster.heroes:
		if hero.hero_name == hero_name:
			return hero
	return null


## A fighter driven by the test's own commands.
func _fighter(hero: HeroData, at: Vector2) -> Fighter:
	var fighter: Fighter = PLAYER_SCENE.instantiate()
	fighter.hero = hero
	fighter.position = at
	fighter.input = Pad.new()
	t.add_child(fighter)
	return fighter


func _ticks(count: int) -> void:
	for i in count:
		await t.get_tree().physics_frame


## Runs physics until `done` returns true, for at most `seconds` of game time.
func _until(done: Callable, seconds: float) -> bool:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await t.get_tree().physics_frame
		if done.call():
			return true
	return false


## A miss is what leaves a fighter open: it pays the skill's end lag in full,
## and both skills keep that lag short.
func _test_missed_attack_end_lag() -> void:
	var fighter := _fighter(_hero("Kunoichi"), Vector2(300.0, STANDING))
	fighter.set_physics_process(false)
	await t.get_tree().physics_frame
	var skills := {false: fighter.hero.light_attack, true: fighter.hero.heavy_attack}
	for is_heavy: bool in [false, true]:
		var skill: AttackData = skills[is_heavy]
		var other: AttackData = skills[not is_heavy]
		var label := "heavy" if is_heavy else "light"
		t.check(fighter._begin_attack(skill, is_heavy), "a free fighter starts its %s attack" % label)
		fighter._tick_attack(skill.startup_time + skill.active_time + skill.recovery_time + 0.001)
		t.check(fighter.is_in_end_lag(), "a missed %s attack leaves the fighter in end lag" % label)
		t.check(not fighter.can_cancel(), "a missed %s attack cannot be cut short" % label)
		t.check(not fighter._begin_attack(other, not is_heavy), "nothing starts during the %s end lag" % label)
		fighter._tick_state(skill.post_end_lag - 0.01)
		t.check(fighter.is_in_end_lag(), "the %s end lag lasts as long as the skill says" % label)
		fighter._tick_state(0.02)
		t.check(fighter.is_free(), "the fighter is free again once the %s end lag is over" % label)
		fighter._tick_cooldowns(5.0)
	fighter.queue_free()
	await t.get_tree().process_frame


## A rival standing inside the attacker is hit, not swung past: the hitbox
## starts behind the attacker's centre.
func _test_point_blank_hit() -> void:
	var hero := _hero("Antiope")
	var fighter := _fighter(hero, Vector2(300.0, STANDING))
	# Just behind the attacker's centre, where the two bodies overlap.
	var target := _fighter(Roster.heroes[1], Vector2(270.0, STANDING))
	fighter.set_physics_process(false)
	target.set_physics_process(false)
	await _ticks(2)
	fighter._begin_attack(hero.light_attack, false)
	fighter._tick_attack(hero.light_attack.startup_time + 0.001)
	t.check(target.damage_taken > 0.0, "a swing hits a rival standing inside the attacker")
	fighter.queue_free()
	target.queue_free()
	await t.get_tree().process_frame


## The basic combo, played with real inputs: a light attack that lands is cut
## short into the heavy, which arrives before the rival can act again.
func _test_light_into_heavy_combo() -> void:
	var ground := _floor()
	var hero := _hero("Kunoichi")
	var fighter := _fighter(hero, Vector2(300.0, STANDING))
	var target := _fighter(Roster.heroes[1], Vector2(360.0, STANDING))
	var pad: Pad = fighter.input
	await _until(func(): return fighter.is_on_floor() and target.is_on_floor(), 1.0)

	pad.press("attack2")
	var landed := await _until(func(): return target.damage_taken > 0.0, 1.0)
	t.check(landed, "a light attack lands on a rival in reach")
	var after_light: float = target.damage_taken
	var ticks := [0]
	pad.press("attack")
	var comboed := await _until(func():
		ticks[0] += 1
		return target.damage_taken > after_light or not target.is_hit_stunned(), 1.0)
	t.check(comboed and target.damage_taken > after_light,
			"a light that lands combos into the heavy before the rival recovers")
	var light := hero.light_attack
	t.check(ticks[0] / float(Engine.physics_ticks_per_second)
			< light.active_time + light.recovery_time + hero.heavy_attack.startup_time,
			"the heavy cuts the light short instead of waiting for it to finish")
	# The heavy landed too, so the fighter walks away without end lag.
	var free := await _until(func(): return fighter.is_free(), 1.0)
	t.check(free and not fighter.is_in_end_lag(), "the combo ends with the attacker free to move")

	fighter.queue_free()
	target.queue_free()
	ground.queue_free()
	await t.get_tree().process_frame


## Attacks move: a grounded swing steps forward, never off a ledge, and an
## attack in the air can still be steered.
func _test_attack_movement() -> void:
	var ground := _floor()            # spans x 120 … 1020
	var hero := _hero("Kunoichi")
	var fighter := _fighter(hero, Vector2(400.0, STANDING))
	var pad: Pad = fighter.input
	await _until(func(): return fighter.is_on_floor(), 1.0)

	# A side is held, so these are the side heavy (standing still aims upward).
	var start_x: float = fighter.global_position.x
	pad.axis = 1.0
	pad.press("attack")
	await _until(func(): return fighter.is_attacking(), 0.5)
	pad.axis = 0.0
	await _until(func(): return fighter.is_in_end_lag() or fighter.is_free(), 2.0)
	var step: float = fighter.global_position.x - start_x
	t.check(step > 10.0 and step < 90.0,
			"a grounded heavy swing steps forward (%.0f px)" % step)
	await _until(func(): return fighter.is_free(), 1.0)

	# Running at the ledge and swinging: the slide and the step stop at the edge.
	fighter.global_position = Vector2(1000.0, STANDING)
	fighter.velocity = Vector2(hero.speed, 0.0)
	fighter._tick_cooldowns(5.0)
	await _ticks(2)
	pad.axis = 1.0
	pad.press("attack")
	await _until(func(): return fighter.is_in_end_lag(), 2.0)
	pad.axis = 0.0
	t.check(fighter.is_on_floor() and fighter.global_position.x < 1020.0,
			"a grounded attack stops at a ledge instead of sliding off")
	await _until(func(): return fighter.is_free(), 1.0)

	# In the air an attack keeps its momentum and can be steered.
	fighter.global_position = Vector2(500.0, STANDING - 200.0)
	fighter.velocity = Vector2.ZERO
	fighter._tick_cooldowns(5.0)
	await _ticks(2)
	pad.axis = 1.0
	pad.press("attack2")
	await _until(func(): return fighter.is_attacking(), 0.5)
	await _ticks(12)
	t.check(fighter.is_attacking() and fighter.velocity.x > 20.0,
			"an attack in the air can be steered")
	pad.axis = 0.0

	fighter.queue_free()
	ground.queue_free()
	await t.get_tree().process_frame


## The heavy key in the air: the heavy attack carried upward by an extra jump,
## once per airtime. A skill that needs the floor only gets the jump.
func _test_rising_heavy() -> void:
	var ground := _floor()
	for who: String in ["Kunoichi", "Waterbender"]:
		var hero := _hero(who)
		var fighter := _fighter(hero, Vector2(500.0, STANDING - 220.0))
		var pad: Pad = fighter.input
		await _ticks(12)
		t.check(not fighter.is_on_floor() and fighter.velocity.y > 0.0, "%s starts this check falling" % who)
		pad.press("attack")
		await _ticks(2)
		t.check(fighter.velocity.y < 0.0 and fighter.get_air_jumps_left() == hero.air_attack_jumps - 1,
				"%s's heavy key lifts her once in the air" % who)
		var floor_bound := hero.heavy_attack.kind == AttackData.Kind.RANGED and hero.heavy_attack.projectile_grounded
		t.check(fighter.is_attacking() != floor_bound,
				"%s's rising heavy %s" % [who, "is only a jump: her wave needs the floor" if floor_bound
						else "strikes as it rises"])
		fighter.queue_free()
		t.get_tree().call_group("projectiles", "queue_free")
		await t.get_tree().process_frame
	ground.queue_free()
	await t.get_tree().process_frame


func _test_aimed_attacks() -> void:
	var ground := _floor()
	var hero := _hero("Kunoichi")
	var plain := _hero("Linea")
	t.check(plain.attack_for(false, HeroData.Aim.UP) == plain.light_attack
			and plain.attack_for(true, HeroData.Aim.AIR) == plain.heavy_attack,
			"a hero without aimed attacks uses its side attacks for every aim")

	var fighter := _fighter(hero, Vector2(500.0, STANDING - 160.0))
	var pad: Pad = fighter.input
	await _ticks(4)
	t.check(fighter.aimed_skill(false) == hero.light_air and fighter.aimed_skill(true) == hero.heavy_air,
			"in the air each button has its air attack")
	await _until(func() -> bool: return fighter.is_on_floor(), 1.5)
	t.check(fighter.aimed_skill(false) == hero.light_up and fighter.aimed_skill(true) == hero.heavy_up,
			"standing still aims an attack upward")
	pad.axis = 1.0
	t.check(fighter.aimed_skill(false) == hero.light_attack and fighter.aimed_skill(true) == hero.heavy_attack,
			"holding a side gives the side attack")
	pad.down = true
	t.check(fighter.aimed_skill(false) == hero.light_down and fighter.aimed_skill(true) == hero.heavy_down,
			"holding down gives the low attack")
	pad.axis = 0.0

	# A rival held overhead: out of the low sweep, inside the upward cut.
	var target := _fighter(plain, fighter.position + Vector2(40.0, -112.0))
	target.set_physics_process(false)
	await _ticks(2)
	pad.press("attack2")
	await _until(func() -> bool: return fighter.is_free(), 1.0)
	t.check(is_zero_approx(target.damage_taken), "the low sweep passes under a rival overhead")
	pad.down = false
	await _ticks(2)
	pad.press("attack2")
	await _until(func() -> bool: return target.damage_taken > 0.0, 0.6)
	t.check(target.damage_taken > 0.0, "the upward light reaches a rival overhead")
	t.check(target.velocity.y < 0.0 and absf(target.velocity.x) < absf(target.velocity.y),
			"an upward attack launches its victim up more than away")
	target.queue_free()

	# The upward heavy carries her off the floor as it comes out.
	await _until(func() -> bool: return fighter.is_free() and fighter.is_on_floor(), 1.5)
	await _ticks(90)
	pad.press("attack")
	var rose := await _until(func() -> bool: return fighter.velocity.y < -100.0, 0.6)
	t.check(rose, "the upward heavy lifts her off the floor")

	# The CPU aims too: with a rival overhead only the upward attack reaches.
	var brain := FighterBrain.new(FighterBrain.Level.HARD)
	await _until(func() -> bool: return fighter.is_free() and fighter.is_on_floor(), 2.0)
	await _ticks(60)
	t.check(brain._strike(fighter, false, Vector2(30.0, -112.0), 1.0) and brain.axis == 0.0 and not brain.down,
			"the CPU aims upward at a rival overhead")
	t.check(brain._strike(fighter, false, Vector2(96.0, 40.0), 1.0) and (brain.axis != 0.0 or brain.down),
			"the CPU picks a side or low attack for a rival in front of it")
	fighter.queue_free()
	ground.queue_free()
	await t.get_tree().process_frame

## The dive: heavy with down held in the air plunges for as long as the button
## is held, and ends in its hit where it reaches the floor or another fighter.
func _test_dive() -> void:
	var ground := _floor()
	var hero := _hero("Kunoichi")
	t.check(hero.attack_for(true, HeroData.Aim.DIVE) == hero.heavy_dive and hero.heavy_dive.dive_speed > 0.0,
			"Kunoichi has a dive of her own")
	t.check(hero.attack_for(false, HeroData.Aim.DIVE) == hero.light_air,
			"down held in the air leaves the light button its air attack")
	for other: HeroData in Roster.heroes:
		var dive := other.attack_for(true, HeroData.Aim.DIVE)
		t.check(dive != null and dive.dive_speed > 0.0 and other.is_heavy_skill(dive),
				"%s can dive" % other.hero_name)

	# Onto a rival standing below.
	var target := _fighter(_hero("Linea"), Vector2(500.0, STANDING))
	var fighter := _fighter(hero, Vector2(500.0, STANDING - 300.0))
	var pad: Pad = fighter.input
	await _ticks(6)
	pad.down = true
	pad.heavy_held = true
	pad.press("attack")
	var dived := await _until(func() -> bool: return fighter.is_diving(), 0.6)
	t.check(dived, "heavy with down held in the air starts a dive")
	await _ticks(4)
	t.check(fighter.velocity.y >= hero.heavy_dive.dive_speed * 0.9, "a dive plunges at its dive speed")
	t.check(fighter.get_air_jumps_left() == hero.air_attack_jumps, "a dive does not spend the rising heavy")
	await _until(func() -> bool: return not fighter.is_diving(), 1.5)
	await _ticks(3)
	t.check(target.damage_taken > 0.0, "a dive ends in its hit where it reaches a rival")
	target.queue_free()
	await _until(func() -> bool: return fighter.is_free() and fighter.is_on_floor(), 2.0)

	# Letting go of the button ends it in the air, with no hit.
	fighter.global_position = Vector2(500.0, STANDING - 330.0)
	fighter.velocity = Vector2.ZERO
	fighter._tick_cooldowns(5.0)
	await _ticks(4)
	pad.down = true
	pad.heavy_held = true
	pad.press("attack")
	await _until(func() -> bool: return fighter.is_diving(), 0.6)
	await _ticks(5)
	pad.heavy_held = false
	pad.down = false
	await _ticks(3)
	t.check(not fighter.is_diving() and not fighter.is_on_floor(), "letting go of the button ends the dive in the air")
	await _until(func() -> bool: return fighter.is_free() and fighter.is_on_floor(), 2.0)

	# Held all the way down, it lands with its hit on the floor.
	fighter.global_position = Vector2(700.0, STANDING - 300.0)
	fighter.velocity = Vector2.ZERO
	fighter._tick_cooldowns(5.0)
	await _ticks(4)
	pad.down = true
	pad.heavy_held = true
	pad.press("attack")
	await _until(func() -> bool: return fighter.is_diving(), 0.6)
	var landed := await _until(func() -> bool: return fighter.is_on_floor() and not fighter.is_diving(), 1.5)
	t.check(landed and fighter.is_attacking(), "a dive held to the floor strikes where it lands")
	pad.heavy_held = false
	pad.down = false
	fighter.queue_free()
	ground.queue_free()
	await t.get_tree().process_frame


## A rig with a dash animation shows it for the dash and a beat after.
func _test_dash_pose() -> void:
	var ground := _floor()
	var fighter := _fighter(_hero("Kunoichi"), Vector2(400.0, STANDING))
	var pad: Pad = fighter.input
	await _until(func() -> bool: return fighter.is_on_floor(), 1.0)
	await _ticks(4)
	t.check(fighter.visuals.rig != null and fighter.visuals.rig.has_animation("dash"),
			"Kunoichi has a dash pose")
	pad.axis = 1.0
	pad.press("dash")
	await _until(func() -> bool: return fighter.is_dashing(), 0.3)
	await _ticks(3)
	t.check(fighter.visuals.pose == "dash", "a dash shows the dash pose")
	await _until(func() -> bool: return not fighter.is_dashing(), 0.5)
	await _ticks(2)
	t.check(fighter.visuals.pose == "dash", "the dash pose is kept for a beat after the burst")
	await _ticks(40)
	t.check(fighter.visuals.pose == "walk", "and then gives way to the run")
	pad.axis = 0.0
	fighter.queue_free()
	ground.queue_free()
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
