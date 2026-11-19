class_name FighterBrain
extends FighterInput
## The CPU player. It produces the same inputs a person would (an axis and a
## few button presses per tick) from what it can see: where it is on the stage,
## where its rival is, and which of its own skills would reach.
##
## Getting back to the stage is checked every tick. Everything else is decided
## at a human-ish pace set by the level: a harder CPU thinks more often, attacks
## more readily when a skill would land and dodges more of what it sees coming.

enum Level { EASY, NORMAL, HARD }

## Seconds between decisions, chance to attack when a skill would reach, chance
## to dodge a rival's attack up close, and how often it chooses the heavy skill.
const PROFILES := [
	{"think": 0.30, "attack": 0.40, "dodge": 0.05, "heavy": 0.25},
	{"think": 0.17, "attack": 0.72, "dodge": 0.28, "heavy": 0.40},
	{"think": 0.09, "attack": 0.95, "dodge": 0.60, "heavy": 0.50},
]
## Distance kept from a ledge while chasing, so it never runs off the stage.
const LEDGE_MARGIN := 44.0

var level: int = Level.NORMAL

var _stage_half: float = 470.0
var _think_left: float = 0.0
var _jump_wait: float = 0.0
## The skill it is currently positioning for, and how long it sticks with it.
var _plan_heavy: bool = false
var _plan_left: float = 0.0


func _init(cpu_level: int = Level.NORMAL, map: MapData = null) -> void:
	level = clampi(cpu_level, 0, PROFILES.size() - 1)
	if map != null:
		_stage_half = map.stage_width * 0.5


func poll(fighter: Fighter, delta: float) -> void:
	pressed = {}          # presses last exactly one tick
	down = false
	_jump_wait = maxf(0.0, _jump_wait - delta)
	if _recover(fighter):
		return
	_think_left -= delta
	_plan_left -= delta
	if _think_left > 0.0:
		return
	var profile: Dictionary = PROFILES[level]
	_think_left = profile.think * randf_range(0.7, 1.3)
	_decide(fighter, _find_rival(fighter), profile)


func _find_rival(fighter: Fighter) -> Fighter:
	var best: Fighter = null
	for node in fighter.get_tree().get_nodes_in_group("players"):
		var other := node as Fighter
		if other == null or other == fighter or not other.visible or other.is_eliminated():
			continue
		if best == null or fighter.global_position.distance_squared_to(other.global_position) \
				< fighter.global_position.distance_squared_to(best.global_position):
			best = other
	return best


## Steers back onto the stage when off it. Returns true while recovering.
func _recover(fighter: Fighter) -> bool:
	var at := fighter.global_position
	var feet_y := fighter.get_feet().y
	var over_stage := absf(at.x) < _stage_half - 8.0
	if over_stage and feet_y <= 4.0:
		return false
	# Under the deck the way back is out past the ledge first, then up and in.
	var under_deck := over_stage and feet_y > 4.0
	axis = signf(at.x) if under_deck else -signf(at.x)
	if axis == 0.0:
		axis = 1.0
	var falling := fighter.velocity.y > -40.0
	# Jump early enough to arrive above the ledge, not at it.
	var low := feet_y > -70.0
	if not under_deck and falling and low and _jump_wait == 0.0 and fighter.is_free():
		if fighter.get_jumps_left() > 0:
			pressed["jump"] = true
			_jump_wait = 0.22
		elif fighter.get_air_jumps_left() > 0:
			pressed["attack"] = true
			_jump_wait = 0.22
		elif absf(at.x) > _stage_half + 60.0:
			pressed["dash"] = true
			_jump_wait = 0.3
	return true


func _decide(fighter: Fighter, rival: Fighter, profile: Dictionary) -> void:
	var at := fighter.global_position
	if rival == null:
		# Nobody to fight: drift back toward the middle of the stage.
		axis = -signf(at.x) if absf(at.x) > 80.0 else 0.0
		return
	var to := rival.global_position - at
	var gap := absf(to.x)
	var toward := signf(to.x) if to.x != 0.0 else fighter.get_facing()
	var hero := fighter.hero
	var grounded := fighter.is_on_floor()

	# Below hard, a rival knocked off the stage is given room to climb back
	# instead of being struck down at the ledge.
	var rival_off := absf(rival.global_position.x) > _stage_half + 6.0 or rival.get_feet().y > 24.0
	if rival_off and level < Level.HARD:
		var wait_x := signf(rival.global_position.x) * _stage_half * 0.35
		axis = signf(wait_x - at.x) if absf(wait_x - at.x) > 40.0 else 0.0
		if axis == 0.0:
			fighter.face(toward)
		return

	# Defence first: a rival swinging at arm's length is worth a dodge.
	if rival.is_attacking() and gap < 170.0 and absf(to.y) < 90.0 \
			and fighter.can_dodge() and randf() < profile.dodge:
		axis = 0.0
		pressed["dash"] = true
		return

	# Attack when a skill would connect.
	if fighter.is_free() and randf() < profile.attack:
		var heavy_ok := grounded and fighter.can_use(hero.heavy_attack, true) \
				and _reaches(hero.heavy_attack, to)
		var light_ok := fighter.can_use(hero.light_attack, false) and _reaches(hero.light_attack, to)
		if heavy_ok and (not light_ok or randf() < profile.heavy):
			fighter.face(toward)
			axis = 0.0
			pressed["attack"] = true
			return
		if light_ok:
			fighter.face(toward)
			axis = 0.0
			pressed["attack2"] = true
			return

	# Otherwise move to where the skill it is setting up would land. Sticking with
	# one skill for a while stops it hovering between two ranges where neither reaches.
	if _plan_left <= 0.0:
		_plan_left = randf_range(1.2, 2.6)
		_plan_heavy = randf() < profile.heavy
	var plan := hero.heavy_attack if _plan_heavy else hero.light_attack
	if plan == null:
		plan = hero.light_attack if hero.light_attack != null else hero.heavy_attack
	var wanted := _ideal_gap(plan)
	var slack := 22.0
	var move := 0.0
	if gap > wanted + slack:
		move = toward
	elif gap < wanted - slack and plan != null and plan.kind != AttackData.Kind.MELEE:
		move = -toward          # too close for a ranged skill: back off
	# Never walk off a ledge, whether chasing or backing away.
	if grounded and move != 0.0 and absf(at.x + move * 40.0) > _stage_half - LEDGE_MARGIN \
			and signf(move) == signf(at.x):
		move = 0.0
		# Cornered while backing off: commit to the close-range skill instead.
		_plan_heavy = false
		_plan_left = 1.0
	if move == 0.0:
		fighter.face(toward)
	axis = move

	# Follow a rival up to a platform, or drop down to one below.
	if to.y < -70.0 and gap < 190.0 and _jump_wait == 0.0:
		if grounded or fighter.get_jumps_left() > 0:
			pressed["jump"] = true
			_jump_wait = 0.35
	elif to.y > 70.0 and grounded and fighter.get_feet().y < -40.0 and gap < 220.0:
		pressed["down"] = true


## Would this skill hit a rival at offset `to` if started now?
func _reaches(skill: AttackData, to: Vector2) -> bool:
	if skill == null:
		return false
	var gap := absf(to.x)
	match skill.kind:
		AttackData.Kind.RANGED:
			var aim := to.y - skill.projectile_spawn_offset.y
			return gap < skill.projectile_range * 0.92 and gap > 40.0 \
					and absf(aim) < skill.projectile_radius + 46.0
		AttackData.Kind.GROUND_SPIKE:
			return absf(gap - skill.ground_spike_distance) < skill.ground_spike_hitbox_size.x * 0.5 + 24.0 \
					and absf(to.y) < skill.ground_spike_hitbox_size.y
		_:
			return gap < skill.reach + 14.0 and absf(to.y) < skill.height * 0.5 + 36.0


## The distance from the rival at which this skill connects best.
func _ideal_gap(skill: AttackData) -> float:
	if skill == null:
		return 80.0
	match skill.kind:
		AttackData.Kind.RANGED:
			return minf(skill.projectile_range * 0.6, 340.0)
		AttackData.Kind.GROUND_SPIKE:
			return skill.ground_spike_distance
		_:
			return skill.reach * 0.7
