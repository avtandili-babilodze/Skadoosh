extends Node2D
## One delayed floor eruption. The visual telegraphs before the damaging frame,
## then dissolves. Physics queries make the hit reliable even if a player was
## already standing inside the area when the spike became active.

var _shooter: Node = null
var _dir: float = 1.0
var _damage: float = 0.0
var _knockback: float = 0.0
var _up_ratio: float = 0.18
var _texture: Texture2D = null
var _hframes: int = 4
var _vframes: int = 1
var _frame_count: int = 4
var _art_height: float = 170.0
var _hitbox_size: Vector2 = Vector2(120.0, 110.0)
var _delay: float = 0.12
var _active_time: float = 0.18
var _fade_time: float = 0.22
var _elapsed: float = 0.0
var _hit_targets: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D


func configure(shooter: Node, facing: float, damage: float, knockback: float,
		up_ratio: float, texture: Texture2D, hframes: int, vframes: int,
		frame_count: int, art_height: float, hitbox_size: Vector2,
		delay: float, active_time: float, fade_time: float) -> void:
	_shooter = shooter
	_dir = signf(facing) if facing != 0.0 else 1.0
	_damage = damage
	_knockback = knockback
	_up_ratio = up_ratio
	_texture = texture
	_hframes = maxi(1, hframes)
	_vframes = maxi(1, vframes)
	_frame_count = maxi(1, frame_count)
	_art_height = maxf(1.0, art_height)
	_hitbox_size = Vector2(maxf(1.0, hitbox_size.x), maxf(1.0, hitbox_size.y))
	_delay = maxf(0.0, delay)
	_active_time = maxf(0.01, active_time)
	_fade_time = maxf(0.0, fade_time)


func _ready() -> void:
	add_to_group("ground_hazards")
	if _texture == null:
		queue_free()
		return
	_sprite.texture = _texture
	_sprite.hframes = _hframes
	_sprite.vframes = _vframes
	var grid_frames := _hframes * _vframes
	_frame_count = mini(_frame_count, grid_frames)
	var frame_height := _texture.get_height() / float(_vframes)
	var scale_factor := _art_height / frame_height
	_sprite.scale = Vector2(scale_factor, scale_factor)
	# The effect art is drawn from a floor baseline. Move the frame upward so its
	# bottom edge sits on the raycast floor position represented by this node.
	_sprite.position.y = -_art_height * 0.5
	_sprite.frame = 0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _delay:
		var warning_progress := _elapsed / maxf(_delay, 0.001)
		_set_warning_frame(warning_progress)
	elif _elapsed < _delay + _active_time:
		_set_active_frame()
		_hit_overlapping_players()
	elif _elapsed < _delay + _active_time + _fade_time:
		var fade_progress := (_elapsed - _delay - _active_time) / maxf(_fade_time, 0.001)
		_set_fade_frame(fade_progress)
	else:
		queue_free()


func _set_stage(stage: int) -> void:
	_sprite.frame = mini(stage, _frame_count - 1)


func _set_warning_frame(progress: float) -> void:
	if _frame_count >= 6:
		_set_stage(mini(2, int(progress * 3.0)))
	else:
		_set_stage(0 if progress < 0.5 else 1)


func _set_active_frame() -> void:
	if _frame_count >= 6:
		_set_stage(3)
	else:
		_set_stage(2)


func _set_fade_frame(progress: float) -> void:
	if _frame_count >= 6:
		_set_stage(4 if progress < 0.5 else 5)
	else:
		_set_stage(3)


func _hit_overlapping_players() -> void:
	var shape := RectangleShape2D.new()
	shape.size = _hitbox_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0,
			global_position + Vector2(0.0, -_hitbox_size.y * 0.5))
	query.collision_mask = 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if is_instance_valid(_shooter) and _shooter is CollisionObject2D:
		query.exclude = [_shooter.get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var other: Node = hit.get("collider")
		if other == null or not other.is_in_group("players") or not other.has_method("take_hit"):
			continue
		var target_id := other.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		if other.take_hit(_damage, _knockback, _dir, _up_ratio):
			_hit_targets[target_id] = true
