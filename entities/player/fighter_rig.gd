class_name FighterRig
extends Node2D
## A fighter drawn as a live cutout skeleton instead of sprite sheets.
##
## The art is one drawing cut into parts (head, torso, upper arm, forearm, ...).
## Each part rides on a bone; animations store every bone's rotation sampled at
## 30 per second and are interpolated at whatever rate the screen draws, so the
## motion is as smooth as the display. Hair, scarves, tails and cloth are
## pendulum chains simulated live, so they react to how the fighter actually
## moves: a run streams them back, a launch whips them, a landing settles them.
##
## The rig description (bones, parts, chains, animations) is a JSON file written
## by the art pipeline next to the part textures. Positions are in world pixels
## with the origin on the floor line under the body's centre; this node therefore
## sits at the fighter's feet. The art faces right; `facing` mirrors it.

const FLASH_SHADER := preload("res://entities/player/rig_flash.gdshader")
## Seconds a new animation takes to blend in from the pose that was showing.
const BLEND_TIME := 0.09
## Fixed simulation step for the chains (they run several steps per frame).
const CHAIN_STEP := 1.0 / 240.0
## How far a chain segment turns per try when it is lifted off the floor (radians).
const FLOOR_NUDGE := 0.06
## How far below the floor line the body is still drawn (world px): soles may
## dip a little in a landing, anything deeper is hidden by the floor.
const FLOOR_CLIP := 4.0
## How far a segment rooted on the ground may sink while it lies flat (world px):
## a thin lock of hair lies flat, a wide tail fan curls up off the floor instead.
const FLOOR_SINK := 3.0

## Per texture path, the mipmapped texture: part textures are drawn smaller than
## they are stored, and mipmaps keep the inked lines clean when they shrink.
static var _texture_cache: Dictionary = {}

var data: Dictionary = {}
## The floor under the rig (node space, unflipped; the rig's origin is at the
## feet, so 0 is the ground it stands on). Hair and cloth chains rest on it
## instead of sinking through. INF while airborne: then they hang freely.
var floor_y: float = 0.0:
	set(value):
		floor_y = value
		if _material != null:
			_material.set_shader_parameter("floor_clip", value + FLOOR_CLIP if value < INF else 1.0e9)
## 1 faces right, -1 faces left.
var facing: float = 1.0:
	set(value):
		facing = 1.0 if value >= 0.0 else -1.0
		_apply_flip()

var _body: CanvasGroup
var _material: ShaderMaterial
var _bone_names: PackedStringArray = PackedStringArray()
var _bone_index: Dictionary = {}
var _parent: PackedInt32Array = PackedInt32Array()
var _anchor: PackedVector2Array = PackedVector2Array()   # pivot relative to the parent's pivot, at rest
var _rest_pivot: PackedVector2Array = PackedVector2Array()
var _theta: PackedFloat32Array = PackedFloat32Array()     # absolute rotation, 0 = as drawn
var _pos: PackedVector2Array = PackedVector2Array()       # pivot position this frame
var _parts: Array[Sprite2D] = []
var _part_bone: PackedInt32Array = PackedInt32Array()
var _part_offset: PackedVector2Array = PackedVector2Array()
var _part_hull: Array[PackedVector2Array] = []
var _bone_hull: Dictionary = {}  # chain bone index -> outline points of its parts
var _part_names: PackedStringArray = PackedStringArray()
var _order_key: String = ""
var _hidden_key: String = ""
## The current animation's whole-body turn, in radians, and the bone it turns about.
var _spin: float = 0.0
var _spin_bone: int = -1
var _texel: float = 3.0
var _root_offset: Vector2 = Vector2.ZERO

var _anim: Dictionary = {}
var _anim_name: String = ""
var _blend_left: float = 0.0
var _blend_time: float = BLEND_TIME
var _from_theta: PackedFloat32Array = PackedFloat32Array()
var _from_root: Vector2 = Vector2.ZERO

var _chains: Array = []          # [{bones, pinned, stiffness, ...state}]
var _chain_bone: Dictionary = {} # bone index -> true for simulated bones
var _chain_time: float = 0.0
var _last_motion: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _settled: bool = false


## Builds the skeleton and its parts from a rig description. `folder` is where
## the part textures live (the JSON file's own folder).
func setup(rig_data: Dictionary, folder: String) -> void:
	data = rig_data
	_texel = float(data.get("texel", 3.0))
	_body = CanvasGroup.new()
	_body.name = "Body"
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_body.material = _material
	add_child(_body)
	floor_y = floor_y

	var bones: Array = data["bones"]
	for i in bones.size():
		var bone: Dictionary = bones[i]
		_bone_names.append(bone["name"])
		_bone_index[bone["name"]] = i
		_parent.append(int(bone["parent"]))
		_anchor.append(_vec(bone["anchor"]))
		_rest_pivot.append(_vec(bone["pivot"]))
	_theta.resize(bones.size())
	_pos.resize(bones.size())
	_from_theta.resize(bones.size())

	for part: Dictionary in data["parts"]:
		var sprite := Sprite2D.new()
		sprite.name = part["name"]
		sprite.centered = false
		sprite.texture = _texture(folder.path_join(part["texture"]))
		sprite.scale = Vector2.ONE / _texel
		_body.add_child(sprite)
		_parts.append(sprite)
		_part_names.append(part["name"])
		_part_bone.append(int(part["bone"]))
		_part_offset.append(_vec(part["offset"]))
		var hull := PackedVector2Array()
		for p in part.get("hull", []):
			hull.append(_vec(p))
		_part_hull.append(hull)

	for chain: Dictionary in data.get("chains", []):
		var state := chain.duplicate(true)
		var count: int = chain["bones"].size()
		state["theta"] = PackedFloat32Array()
		state["omega"] = PackedFloat32Array()
		state["theta"].resize(count)
		state["omega"].resize(count)
		_chains.append(state)
		for b in chain["bones"]:
			_chain_bone[int(b)] = true
	for b: int in _chain_bone:
		var points := PackedVector2Array()
		for k in _parts.size():
			if _part_bone[k] == b:
				points.append_array(_part_hull[k])
		_bone_hull[b] = points
	# Half the thickness of each chain segment across its length: how far it
	# reaches below its own line when it lies flat on the ground.
	for state: Dictionary in _chains:
		var half := PackedFloat32Array()
		for j in state["bones"].size():
			var along := Vector2.from_angle(float(state["dirs"][j]))
			var widest := 0.0
			for p in _bone_hull.get(int(state["bones"][j]), PackedVector2Array()):
				widest = maxf(widest, absf(along.cross(p)))
			half.append(widest)
		state["half"] = half
	_spin_bone = _bone_index.get("pelvis", -1)
	_apply_flip()
	play(_first_animation())
	_sample(0.0)
	_solve()
	_apply_parts()


func has_animation(anim_name: String) -> bool:
	return data.get("anims", {}).has(anim_name)


## Length of an animation in seconds.
func length_of(anim_name: String) -> float:
	var anim: Dictionary = data.get("anims", {}).get(anim_name, {})
	if anim.is_empty():
		return 0.0
	return float(anim["frames"]) / float(anim["fps"])


func animation_info(anim_name: String) -> Dictionary:
	return data.get("anims", {}).get(anim_name, {})


## Switches to an animation; the pose that was showing blends into it over
## `blend_time` seconds.
func play(anim_name: String, blend: bool = true, blend_time: float = BLEND_TIME) -> void:
	if anim_name == _anim_name or not has_animation(anim_name):
		return
	if blend and _anim_name != "" and blend_time > 0.0:
		_from_theta = _theta.duplicate()
		_from_root = _root_offset
		_blend_time = blend_time
		_blend_left = blend_time
	else:
		_blend_left = 0.0
	_anim_name = anim_name
	_anim = data["anims"][anim_name]


func current_animation() -> String:
	return _anim_name


## Shows the current animation at time `t` (seconds) and advances the chains by
## `delta`. `world_velocity` is how the fighter is moving through the world, so
## hair and cloth can stream behind it.
func pose(t: float, delta: float, world_velocity: Vector2 = Vector2.ZERO) -> void:
	_sample(t)
	if _blend_left > 0.0:
		_blend_left = maxf(0.0, _blend_left - delta)
		var w := 1.0 - _blend_left / _blend_time
		w = w * w * (3.0 - 2.0 * w)
		for i in _theta.size():
			if not _chain_bone.has(i):
				_theta[i] = lerp_angle(_from_theta[i], _theta[i], w)
		_root_offset = _from_root.lerp(_root_offset, w)
	_solve()
	_simulate_chains(delta, Vector2(world_velocity.x * facing, world_velocity.y))
	_apply_parts()


## Hit flash (0..1, toward `color`) and overall opacity, for the whole body at once.
func set_feedback(flash: float, color: Color, alpha: float) -> void:
	_material.set_shader_parameter("flash", flash)
	_material.set_shader_parameter("flash_color", color)
	_material.set_shader_parameter("alpha", alpha)


## Global position of a point on a bone, such as a sword tip. `point` is in the
## bone's rest space (world px relative to its pivot).
func bone_point(bone_name: String, point: Vector2) -> Vector2:
	var i: int = _bone_index.get(bone_name, -1)
	if i < 0:
		return global_position
	return to_global(_body.transform * (_pos[i] + point.rotated(_theta[i])))


func has_point(point_name: String) -> bool:
	return data.get("points", {}).has(point_name)


## Global position of a named point from the rig description ("sword_tip").
func named_point(point_name: String) -> Vector2:
	var entry = data.get("points", {}).get(point_name)
	if entry == null:
		return global_position
	return bone_point(entry[0], _vec(entry[1]))


## Lowest point of the drawn body (largest y, node space, unflipped), from each
## part's outline hull: where the soles are in the current pose.
func lowest_point() -> float:
	var lowest := -INF
	for k in _parts.size():
		var b := _part_bone[k]
		for p in _part_hull[k]:
			lowest = maxf(lowest, (_pos[b] + p.rotated(_theta[b])).y)
	return lowest


## Largest distance of any part from the rig's origin (a runaway chain shows up here).
func extent() -> float:
	var far := 0.0
	for k in _parts.size():
		far = maxf(far, _parts[k].position.length())
	return far


## A frozen copy of the current drawing, for afterimages.
func snapshot() -> Node2D:
	var copy := Node2D.new()
	copy.transform = transform
	var group := _body.duplicate(0) as CanvasGroup
	group.material = null
	copy.add_child(group)
	return copy


# --- Internals ------------------------------------------------------------------

func _first_animation() -> String:
	var anims: Dictionary = data.get("anims", {})
	if anims.has("idle"):
		return "idle"
	return anims.keys()[0] if not anims.is_empty() else ""


func _sample(t: float) -> void:
	if _anim.is_empty():
		return
	var fps := float(_anim["fps"])
	var frames: int = int(_anim["frames"])
	var loop: bool = _anim.get("loop", false)
	var f := t * fps
	var i0: int
	var i1: int
	var u: float
	if loop:
		f = fposmod(f, float(frames))
		i0 = int(floor(f))
		i1 = (i0 + 1) % frames
		u = f - i0
	else:
		f = clampf(f, 0.0, float(frames - 1))
		i0 = int(floor(f))
		i1 = mini(i0 + 1, frames - 1)
		u = f - i0
	var tracks: Dictionary = _anim["theta"]
	for name: String in tracks:
		var i: int = _bone_index.get(name, -1)
		if i < 0:
			continue
		var values: Array = tracks[name]
		_theta[i] = lerp_angle(float(values[i0]), float(values[i1]), u)
	var root: Array = _anim["root"]
	_root_offset = _vec(root[i0]).lerp(_vec(root[i1]), u)
	var spin: Array = _anim.get("spin", [])
	_spin = lerpf(float(spin[i0]), float(spin[i1]), u) if spin.size() > i1 else 0.0
	_apply_order(i0)
	_apply_hidden(i0)


## Hides the parts the rig keeps out of sight (a blade that is in its scabbard),
## or the set the animation names from this frame on.
func _apply_hidden(frame: int) -> void:
	var changes: Array = _anim.get("hidden", [])
	var pick := -1
	for c in changes.size():
		if int(changes[c][0]) <= frame:
			pick = c
	var key := "%s:%d" % [_anim_name, pick]
	if key == _hidden_key:
		return
	_hidden_key = key
	var hidden: Array = changes[pick][1] if pick >= 0 else data.get("hidden", [])
	var out := {}
	for index in hidden:
		out[int(index)] = true
	for i in _parts.size():
		_parts[i].visible = not out.has(i)


func _apply_order(frame: int) -> void:
	var changes: Array = _anim.get("order", [])
	var chosen = null
	for change in changes:
		if int(change[0]) <= frame:
			chosen = change[1]
	var key := "%s:%s" % [_anim_name, str(chosen)]
	if key == _order_key:
		return
	_order_key = key
	var wanted: Array = chosen if chosen != null else range(_parts.size())
	for slot in wanted.size():
		_body.move_child(_parts[int(wanted[slot])], slot)


func _solve() -> void:
	for i in _theta.size():
		var p := _parent[i]
		if p < 0:
			_pos[i] = _rest_pivot[i] + _root_offset
			continue
		_pos[i] = _pos[p] + _anchor[i].rotated(_theta[p])


func _apply_parts() -> void:
	for k in _parts.size():
		var b := _part_bone[k]
		var sprite := _parts[k]
		sprite.position = _pos[b] + _part_offset[k].rotated(_theta[b])
		sprite.rotation = _theta[b]
	# An animation's spin turns the whole body about its hips (a flip, a spinning
	# cut). The facing flip on this node mirrors it for a fighter facing left.
	var pivot := _pos[_spin_bone] if _spin_bone >= 0 else Vector2.ZERO
	_body.rotation = _spin
	_body.position = pivot - pivot.rotated(_spin)


func _apply_flip() -> void:
	scale.x = absf(scale.x) * facing


## Pendulum chains. Each segment is pulled back toward its parent's rotation (it
## keeps the shape it was drawn with), sags toward the way it was drawn hanging,
## lags behind when its root accelerates, and streams away from the direction of
## travel. Angles are clamped to the chain's limits around its parent.
func _simulate_chains(delta: float, world_velocity: Vector2) -> void:
	if _chains.is_empty() or delta <= 0.0:
		return
	# The root of the motion: the fighter moving through the world plus the
	# animation moving the body around inside the rig.
	var motion := world_velocity
	var accel := Vector2.ZERO
	if _settled:
		accel = ((motion - _last_motion) / delta).limit_length(9000.0)
	_last_motion = motion
	for chain: Dictionary in _chains:
		var bones: Array = chain["bones"]
		var theta: PackedFloat32Array = chain["theta"]
		var omega: PackedFloat32Array = chain["omega"]
		var root_bone: int = _parent[int(bones[0])]
		var root_now := _pos[root_bone] + _anchor[int(bones[0])].rotated(_theta[root_bone])
		var root_prev: Vector2 = chain.get("root_prev", root_now)
		var root_vel_prev: Vector2 = chain.get("root_vel", Vector2.ZERO)
		var root_vel := (root_now - root_prev) / delta
		var root_acc := ((root_vel - root_vel_prev) / delta).limit_length(9000.0) if _settled else Vector2.ZERO
		chain["root_prev"] = root_now
		chain["root_vel"] = root_vel
		var air := -(motion + root_vel)               # the air rushing past this chain
		var push := -(accel + root_acc)                # inertia: it lags behind acceleration
		if not _settled:
			for j in bones.size():
				theta[j] = _theta[root_bone] if j == 0 else theta[j - 1]
				omega[j] = 0.0
		var steps := clampi(int(ceil(delta / CHAIN_STEP)), 1, 8)
		var dt := delta / steps
		var dirs: Array = chain["dirs"]
		var lengths: Array = chain["lengths"]
		for _s in steps:
			for j in bones.size():
				var parent_theta := _theta[root_bone] if j == 0 else theta[j - 1]
				var limit := deg_to_rad(float(_per(chain, "limit", j, 60.0)))
				if j < int(chain.get("pinned", 0)):
					theta[j] = parent_theta
					omega[j] = 0.0
					continue
				var length := maxf(4.0, float(lengths[j]))
				var direction := Vector2.from_angle(float(dirs[j]) + theta[j])
				var acc := float(_per(chain, "stiffness", j, 20.0)) * 12.0 * angle_difference(theta[j], parent_theta)
				acc += float(_per(chain, "gravity", j, 1.0)) * 30.0 * angle_difference(theta[j], 0.0)
				acc += float(_per(chain, "inertia", j, 1.0)) * direction.cross(push) / length * 0.35
				acc += float(_per(chain, "drag", j, 1.0)) * direction.cross(air) / length * 2.2
				acc -= float(_per(chain, "damping", j, 4.0)) * 2.4 * omega[j]
				omega[j] += acc * dt
				theta[j] += omega[j] * dt
				var bend := angle_difference(parent_theta, theta[j])
				if absf(bend) > limit:
					theta[j] = parent_theta + signf(bend) * limit
					omega[j] *= 0.3
		if floor_y < INF:
			_rest_on_floor(bones, theta, omega, root_bone, chain["half"])
		chain["theta"] = theta
		chain["omega"] = omega
		for j in bones.size():
			var b := int(bones[j])
			_theta[b] = theta[j]
		# Chain bones were solved with stale angles: place them again.
		for j in bones.size():
			var b := int(bones[j])
			_pos[b] = _pos[_parent[b]] + _anchor[b].rotated(_theta[_parent[b]])
	_settled = true


## Turns each chain segment whose outline dips below the floor up out of it,
## root first (a lifted segment carries the rest of the chain with it), and
## stops its swing: hair and cloth lie on the ground instead of sinking into it.
## Each segment also ends high enough for the next one to lie flat there.
func _rest_on_floor(bones: Array, theta: PackedFloat32Array, omega: PackedFloat32Array, root_bone: int, half: PackedFloat32Array) -> void:
	var pivot := _pos[root_bone] + _anchor[int(bones[0])].rotated(_theta[root_bone])
	for j in bones.size():
		var b := int(bones[j])
		if j > 0:
			pivot += _anchor[b].rotated(theta[j - 1])
		var hull: PackedVector2Array = _bone_hull.get(b, PackedVector2Array())
		if hull.is_empty():
			continue
		# A segment rooted on the ground (hair from a head lying down) can only
		# lie flat; it is never stood up out of the floor.
		var allowed := maxf(floor_y, pivot.y + minf(half[j], FLOOR_SINK))
		var next := _anchor[int(bones[j + 1])] if j + 1 < bones.size() else Vector2.ZERO
		var next_floor := floor_y - half[j + 1] if j + 1 < bones.size() else INF
		var excess := _floor_excess(hull, pivot, theta[j], allowed, next, next_floor)
		if excess <= 0.0:
			continue
		# Turn the way that lifts it, a little at a time, until it clears the floor.
		var up := _floor_excess(hull, pivot, theta[j] + FLOOR_NUDGE, allowed, next, next_floor)
		var down := _floor_excess(hull, pivot, theta[j] - FLOOR_NUDGE, allowed, next, next_floor)
		var turn := FLOOR_NUDGE if up < down else -FLOOR_NUDGE
		for _try in 26:
			var lifted := _floor_excess(hull, pivot, theta[j] + turn, allowed, next, next_floor)
			if lifted >= excess:
				break
			theta[j] += turn
			excess = lifted
			if excess <= 0.0:
				break
		omega[j] = 0.0


## How far a chain segment at `angle` sinks past where it may reach: its outline
## below `allowed`, or its end (where the next segment hangs) below `next_floor`.
static func _floor_excess(hull: PackedVector2Array, pivot: Vector2, angle: float, allowed: float, next: Vector2, next_floor: float) -> float:
	var low := -INF
	for p in hull:
		low = maxf(low, pivot.y + p.rotated(angle).y)
	var excess := low - allowed
	if next_floor < INF:
		excess = maxf(excess, pivot.y + next.rotated(angle).y - next_floor)
	return excess


static func _per(chain: Dictionary, key: String, j: int, fallback: float) -> float:
	var value = chain.get(key, fallback)
	if value is Array:
		return float(value[mini(j, value.size() - 1)])
	return float(value)


static func _vec(value) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var source: Texture2D = load(path)
	var texture: Texture2D = source
	if source != null:
		var image := source.get_image()
		if image != null and not image.is_empty():
			if image.is_compressed():
				image.decompress()
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture
