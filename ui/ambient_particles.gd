class_name AmbientParticles
extends Control
## The air of a stage: cherry petals, embers, snow or neon motes drifting across
## whatever rectangle this control covers. Particles appear and vanish by
## fading, so they can be born anywhere on screen without popping.

var _particles: CPUParticles2D
var _kind: String = ""
var _color: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	resized.connect(_fit)
	_rebuild()


## `kind` is "petals", "embers", "snow", "motes" or "" for still air.
func configure(kind: String, color: Color) -> void:
	if kind == _kind and color == _color:
		return
	_kind = kind
	_color = color
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	if _particles != null:
		_particles.queue_free()
		_particles = null
	if _kind == "":
		return
	var p := CPUParticles2D.new()
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.local_coords = true
	p.spread = 25.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.75, 1.0])
	var solid := Color(_color, 0.9)
	fade.colors = PackedColorArray([Color(_color, 0.0), solid, solid, Color(_color, 0.0)])
	p.color_ramp = fade
	match _kind:
		"petals":
			p.amount = 46
			p.lifetime = 9.0
			p.direction = Vector2(-0.55, 1.0)
			p.initial_velocity_min = 26.0
			p.initial_velocity_max = 62.0
			p.gravity = Vector2(-6.0, 9.0)
			p.angular_velocity_min = -160.0
			p.angular_velocity_max = 160.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.5
		"embers":
			p.amount = 60
			p.lifetime = 5.5
			p.direction = Vector2(0.15, -1.0)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 95.0
			p.gravity = Vector2(4.0, -22.0)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.5
		"snow":
			p.amount = 90
			p.lifetime = 8.0
			p.direction = Vector2(0.3, 1.0)
			p.initial_velocity_min = 24.0
			p.initial_velocity_max = 70.0
			p.gravity = Vector2(5.0, 6.0)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
		_:   # motes
			p.amount = 34
			p.lifetime = 7.0
			p.direction = Vector2(0.2, -1.0)
			p.spread = 70.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 26.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
	# Start with the air already full instead of an empty first few seconds.
	p.preprocess = p.lifetime
	_particles = p
	add_child(p)
	_fit()


func _fit() -> void:
	if _particles == null:
		return
	_particles.position = size * 0.5
	_particles.emission_rect_extents = size * 0.55
