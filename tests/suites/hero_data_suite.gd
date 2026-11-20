extends RefCounted
## Hero data: the roster loads, every fighter's skills are sound, and every
## fighter's sheets follow the rules that make the roster read as one game:
## one scale, one ground line, enough frames to move smoothly, attacks pinned to
## the moment they hit, and legs that keep pace with the body.

const SheetChecks := preload("res://tests/support/sheet_checks.gd")

const MELEE := AttackData.Kind.MELEE
const RANGED := AttackData.Kind.RANGED
const SPIKE := AttackData.Kind.GROUND_SPIKE

## The roster's design: what each fighter's light and heavy skill is. A data
## slip that turns a zoner into a brawler changes how the fighter plays.
const KITS := {
	"Kunoichi": [MELEE, MELEE],
	"Linea": [RANGED, RANGED],
	"Primordial Demon": [MELEE, SPIKE],
	"Waterbender": [RANGED, RANGED],
	"Lilith": [MELEE, MELEE],
	"Kitsune": [RANGED, MELEE],
	"Antiope": [MELEE, MELEE],
	"Musashi": [MELEE, MELEE],
	"Akane": [MELEE, SPIKE],
	"Knight": [MELEE, MELEE],
}

## Fewest frames an animation may have and still read as smooth motion.
const MIN_FRAMES := {
	"idle": 16, "run": 10, "jump": 6, "fall": 6, "land": 6, "hurt": 6, "death": 10,
	"light attack": 8, "heavy attack": 10,
}

## On-screen pixels per texture pixel, shared by every sheet of every fighter
## (a 200 px cell is drawn 140.2 px tall), so nobody grows or shrinks between
## animations and the whole roster stands at one scale.
const ROSTER_SCALE := 140.2 / 200.0

## Fighters whose run is too fast for the stride measurement, which only sees
## frames where both feet are low at once; a sprint has a flight phase instead.
## Their runs are held to measured foot speed when the art is built.
const SPRINTERS := ["Kunoichi"]

## The runner: check() records a result; test nodes are added under it.
var t


func run(runner: Node) -> bool:
	t = runner
	_test_roster()
	for hero: HeroData in Roster.heroes:
		_test_skills(hero)
		_test_sheets(hero)
		_test_run_pace(hero)
	_test_signature_details()
	return true


func _test_roster() -> void:
	t.check(Roster.heroes.size() >= 9, "the roster loads all nine fighters")
	var names: Dictionary = {}
	for hero: HeroData in Roster.heroes:
		var who := hero.hero_name
		t.check(not who.is_empty(), "each fighter has a name")
		t.check(not names.has(who), "fighter names are unique: %s" % who)
		names[who] = true
		t.check(not hero.description.is_empty(), "%s has a description for the select screen" % who)
		t.check(hero.ground_acceleration > 0.0, "%s has grounded acceleration" % who)
		t.check(hero.air_acceleration > 0.0, "%s has air acceleration" % who)
		t.check(hero.icon != null and hero.icon.get_width() == hero.icon.get_height(),
				"%s has a square icon" % who)
	for who: String in KITS:
		t.check(names.has(who), "%s is on the roster" % who)


# --- Skills ------------------------------------------------------------------------

func _test_skills(hero: HeroData) -> void:
	var who := hero.hero_name
	_validate_skill(hero, hero.light_attack)
	_validate_skill(hero, hero.heavy_attack)
	if hero.light_attack == null or hero.heavy_attack == null:
		return
	# Aimed attacks are optional. The ones a hero has follow the same rules, and
	# every aim gives some skill: the side attack stands in for a missing one.
	for skill: AttackData in hero.all_attacks():
		if skill == hero.light_attack or skill == hero.heavy_attack:
			continue
		_validate_skill(hero, skill)
		var limit := 0.3 if hero.is_heavy_skill(skill) else 0.15
		t.check(skill.post_end_lag > 0.0 and skill.post_end_lag <= limit,
				"%s/%s pays a short end lag when it misses" % [who, skill.skill_name])
		t.check(skill.kind == AttackData.Kind.MELEE, "%s/%s is a melee strike" % [who, skill.skill_name])
	for is_heavy: bool in [false, true]:
		for aim: HeroData.Aim in HeroData.Aim.values():
			var aimed := hero.attack_for(is_heavy, aim)
			t.check(aimed != null and hero.is_heavy_skill(aimed) == is_heavy,
					"%s has a %s attack for every aim" % [who, "heavy" if is_heavy else "light"])
	# A miss costs something, a heavy miss costs more, and neither freezes the
	# fighter for long: long locks are what make a fighting game feel slow.
	var light_lag := hero.light_attack.post_end_lag
	var heavy_lag := hero.heavy_attack.post_end_lag
	t.check(light_lag > 0.0 and light_lag <= 0.15,
			"%s light attack pays a short end lag when it misses (%.2f s)" % [who, light_lag])
	t.check(heavy_lag > light_lag and heavy_lag <= 0.3,
			"%s heavy attack pays a longer, still short, end lag when it misses (%.2f s)" % [who, heavy_lag])
	var light_whiff := hero.light_attack.startup_time + hero.light_attack.active_time \
			+ hero.light_attack.recovery_time + light_lag
	t.check(hero.min_attack_interval <= light_whiff + Fighter.INPUT_BUFFER,
			"%s can attack again as soon as a missed light hands control back" % who)
	t.check(hero.light_attack.animation_texture != hero.heavy_attack.animation_texture,
			"%s light and heavy attacks use different animation sheets" % who)
	if KITS.has(who):
		t.check(hero.light_attack.kind == KITS[who][0] and hero.heavy_attack.kind == KITS[who][1],
				"%s keeps the skill types of her kit" % who)


func _validate_skill(hero: HeroData, skill: AttackData) -> void:
	t.check(skill != null, "%s has a configured skill" % hero.hero_name)
	if skill == null:
		return
	var label := "%s/%s" % [hero.hero_name, skill.skill_name]
	var total_time := skill.startup_time + skill.active_time + skill.recovery_time
	t.check(skill.active_time > 0.0, "%s has an active window" % label)
	t.check(total_time > 0.0, "%s has valid phase timing" % label)
	t.check(skill.cooldown >= total_time, "%s cooldown covers its full animation" % label)
	# A skill still cooling down after a miss has handed control back would
	# ignore the press; the input buffer covers at most this much.
	t.check(skill.cooldown <= total_time + skill.post_end_lag + Fighter.INPUT_BUFFER + 0.001,
			"%s is ready again when the fighter is, so a press is never ignored" % label)
	if skill.kind == RANGED:
		var art := skill.projectile_texture
		t.check(art != null, "%s has projectile art" % label)
		t.check(skill.projectile_radius > 0.0, "%s has a projectile hitbox" % label)
		if art != null:
			t.check(skill.projectile_hframes > 0 and skill.projectile_vframes > 0
					and art.get_width() % skill.projectile_hframes == 0
					and art.get_height() % skill.projectile_vframes == 0,
					"%s projectile sheet divides into equal cells" % label)
			t.check(skill.projectile_frames <= skill.projectile_hframes * skill.projectile_vframes,
					"%s projectile animation fits its sheet" % label)
	elif skill.kind == SPIKE:
		var spike := skill.ground_spike_texture
		t.check(spike != null, "%s has ground-spike art" % label)
		t.check(skill.ground_spike_distance >= 300.0, "%s erupts about four game meters away" % label)
		t.check(skill.ground_spike_hitbox_size.x > 0.0 and skill.ground_spike_hitbox_size.y > 0.0,
				"%s has a ground-spike hitbox" % label)
		if spike != null:
			t.check(SheetChecks.has_transparent_corners(spike),
					"%s ground-spike sheet has transparent corners" % label)
			t.check(SheetChecks.has_clear_vertical_frame_gutters(spike,
					skill.ground_spike_hframes, skill.ground_spike_vframes),
					"%s ground-spike frames have isolated atlas cells" % label)
			t.check(SheetChecks.frames_share_visible_baseline(spike,
					skill.ground_spike_hframes, skill.ground_spike_vframes),
					"%s rises from the floor in every frame" % label)


# --- Sheets ------------------------------------------------------------------------

## Every animation a fighter has, as one list:
## [label, texture, hframes, vframes, frames, on-screen cell height, stands on the ground]
func _sheets(hero: HeroData) -> Array:
	var light := hero.light_attack
	var heavy := hero.heavy_attack
	var sheets := [
		["idle", hero.texture, hero.idle_hframes, hero.idle_vframes, hero.idle_frames, hero.sprite_height, true],
		["run", hero.walk_texture, hero.walk_hframes, hero.walk_vframes, hero.walk_frames, hero.walk_sprite_height, true],
		["jump", hero.jump_texture, hero.jump_hframes, hero.jump_vframes, hero.jump_frames, hero.air_sprite_height, false],
		["fall", hero.fall_texture, hero.fall_hframes, hero.fall_vframes, hero.fall_frames, hero.air_sprite_height, false],
		["land", hero.land_texture, hero.land_hframes, hero.land_vframes, hero.land_frames, hero.land_sprite_height, true],
		["hurt", hero.hurt_texture, hero.hurt_hframes, hero.hurt_vframes, hero.hurt_frames, hero.hurt_sprite_height, true],
		["death", hero.death_texture, hero.death_hframes, hero.death_vframes, hero.death_frames, hero.death_sprite_height, false],
	]
	if light != null:
		sheets.append(["light attack", light.animation_texture, light.animation_hframes,
				light.animation_vframes, light.animation_frames, light.animation_sprite_height, true])
	if heavy != null:
		sheets.append(["heavy attack", heavy.animation_texture, heavy.animation_hframes,
				heavy.animation_vframes, heavy.animation_frames, heavy.animation_sprite_height, true])
	return sheets


func _test_sheets(hero: HeroData) -> void:
	var who := hero.hero_name
	var idle_baseline := 0.0
	if hero.texture != null:
		idle_baseline = SheetChecks.visible_baseline_offset(hero.texture,
				hero.idle_hframes, hero.idle_vframes, hero.sprite_height)
	for sheet in _sheets(hero):
		var label: String = sheet[0]
		var texture: Texture2D = sheet[1]
		var columns: int = sheet[2]
		var rows: int = sheet[3]
		t.check(texture != null, "%s has a %s animation" % [who, label])
		if texture == null:
			continue
		var even := columns > 0 and rows > 0 \
				and texture.get_width() % columns == 0 and texture.get_height() % rows == 0
		t.check(even, "%s %s sheet divides into equal cells" % [who, label])
		if not even:
			continue
		var cells := columns * rows
		var frames: int = sheet[4] if sheet[4] > 0 else cells
		t.check(frames <= cells, "%s %s plays only frames its sheet has" % [who, label])
		t.check(frames >= MIN_FRAMES[label],
				"%s %s is smooth: %d frames (at least %d)" % [who, label, frames, MIN_FRAMES[label]])
		t.check(SheetChecks.has_transparent_corners(texture),
				"%s %s sheet has transparent corners" % [who, label])
		var cell_height := texture.get_height() / float(rows)
		var height: float = sheet[5]
		t.check(absf(height / cell_height - ROSTER_SCALE) < 0.004,
				"%s %s is drawn at the roster's scale" % [who, label])
		if sheet[6]:
			t.check(SheetChecks.frames_share_visible_baseline(texture, columns, rows),
					"%s %s frames share one ground line" % [who, label])
			var baseline := SheetChecks.visible_baseline_offset(texture, columns, rows, height)
			t.check(absf(baseline - idle_baseline) <= 4.0,
					"%s %s meets the idle ground line (%.1f px apart)" % [
						who, label, absf(baseline - idle_baseline)])

	for skill: AttackData in [hero.light_attack, hero.heavy_attack]:
		if skill == null or skill.animation_texture == null:
			continue
		var count := skill.animation_frames if skill.animation_frames > 0 \
				else skill.animation_hframes * skill.animation_vframes
		t.check(skill.animation_release_frame >= 0 and skill.animation_release_frame < count,
				"%s/%s art is pinned to the moment it hits" % [who, skill.skill_name])
		t.check(skill.animation_active_frames >= 1
				and skill.animation_release_frame + skill.animation_active_frames <= count,
				"%s/%s keeps its active frames inside the sheet" % [who, skill.skill_name])


## A planted foot should stay put: the body may travel a little further than the
## legs step each cycle, but not far enough to read as gliding, and the legs must
## not pump faster than a person's do.
func _test_run_pace(hero: HeroData) -> void:
	if hero.walk_texture == null or hero.walk_fps <= 0.0:
		return
	var who := hero.hero_name
	var frames: int = hero.walk_frames if hero.walk_frames > 0 \
			else hero.walk_hframes * hero.walk_vframes
	var steps_per_second := 2.0 * hero.walk_fps / float(frames)
	t.check(steps_per_second <= 5.001,
			"%s legs move at a natural pace (%.1f steps/s)" % [who, steps_per_second])
	if SPRINTERS.has(who):
		return
	var step := SheetChecks.walk_step_length(hero)
	var travel := hero.speed * float(frames) / hero.walk_fps
	t.check(step > 0.0 and travel <= 2.0 * step * 1.3,
			"%s legs keep pace with the body (travel %.0f px per cycle, stride %.0f px)"
			% [who, travel, 2.0 * step])


# --- Details that define particular fighters -----------------------------------------

func _test_signature_details() -> void:
	for hero: HeroData in Roster.heroes:
		match hero.hero_name:
			"Waterbender":
				_test_water_bender(hero)
			"Kitsune":
				t.check(hero.light_attack.projectile_texture != hero.light_attack.animation_texture,
						"Kitsune's foxfire is its own projectile, not baked into her pose")
			"Musashi":
				var idle_top := _visible_top_offset(hero.texture, hero.idle_hframes,
						hero.idle_vframes, hero.sprite_height)
				var land_top := _visible_top_offset(hero.land_texture, hero.land_hframes,
						hero.land_vframes, hero.land_sprite_height)
				t.check(land_top > idle_top + 5.0,
						"Musashi crouches into his landings (%.1f px below standing)" % (land_top - idle_top))


func _test_water_bender(hero: HeroData) -> void:
	t.check(is_equal_approx(hero.light_attack.projectile_range, 240.0),
			"Waterbender water spit travels three game meters")
	t.check(is_equal_approx(hero.heavy_attack.projectile_range, 320.0),
			"Waterbender wave travels four game meters")
	t.check(hero.heavy_attack.projectile_start_scale < hero.heavy_attack.projectile_end_scale,
			"Waterbender wave starts small and grows while traveling")
	t.check(is_equal_approx(hero.heavy_attack.projectile_end_damage_multiplier, 2.0),
			"Waterbender wave reaches double damage at maximum range")
	t.check(hero.heavy_attack.projectile_grounded,
			"Waterbender wave remains anchored to the ground")


## On-screen offset of the first cell's top-most visible pixel from the cell
## centre (negative = above it). A landing crouch starts lower than standing.
func _visible_top_offset(texture: Texture2D, hframes: int, vframes: int,
		sprite_height: float) -> float:
	if texture == null:
		return -INF
	var image := texture.get_image()
	var frame_width: int = image.get_width() / maxi(1, hframes)
	var frame_height: int = image.get_height() / maxi(1, vframes)
	for y in frame_height:
		for x in frame_width:
			if image.get_pixel(x, y).a >= 0.01:
				return (y - frame_height * 0.5) * sprite_height / frame_height
	return -INF
