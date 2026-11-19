class_name HeroPreview
extends Control
## A live, animated fighter for menus: it plays one of a hero's own sheets
## (idle, walk, hurt or death) scaled up with crisp pixels, standing on the
## bottom edge of the control. Menus show the real in-game art this way, so a
## fighter looks the same on the select screen as in a match.

## Distance from a fighter's centre down to its feet, in world pixels (half the
## collision box). Sheets are centred on the body, so this locates the feet row.
const FEET := 50.0

var hero: HeroData:
	set(value):
		hero = value
		_time = 0.0
		_build_rig()
		queue_redraw()
## "idle", "walk", "hurt" or "death". Falls back to idle when the hero lacks it.
var animation: String = "idle":
	set(value):
		if animation != value:
			animation = value
			_time = 0.0
			queue_redraw()
## 1 faces right, -1 faces left.
var facing: float = 1.0
## Size on screen relative to the fighter's size in a match.
var zoom: float = 2.4
## Gap between the feet and the bottom edge of the control.
var floor_margin: float = 8.0

var _time: float = 0.0
## The live skeleton for a rigged hero (drawn as a child instead of by _draw).
var _rig: FighterRig = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_time += delta
	if _rig != null:
		_pose_rig(delta)
	else:
		queue_redraw()


func _build_rig() -> void:
	if _rig != null:
		_rig.queue_free()
		_rig = null
	if hero == null or hero.rig == null:
		return
	_rig = FighterRig.new()
	_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_rig)
	_rig.setup(hero.rig.data, hero.rig.resource_path.get_base_dir())
	_pose_rig(0.0)


func _pose_rig(delta: float) -> void:
	var anim := animation if _rig.has_animation(animation) else "idle"
	if anim == "walk" and _rig.has_animation("run"):
		anim = "run"
	_rig.play(anim, false)
	_rig.pose(_time, delta)
	_rig.facing = facing
	_rig.position = Vector2(size.x * 0.5, size.y - floor_margin)
	_rig.scale = Vector2(zoom * _rig.facing, zoom)


## Restarts the current animation from its first frame.
func restart() -> void:
	_time = 0.0


func _draw() -> void:
	if hero == null or _rig != null:
		return
	var clip := _clip()
	var texture: Texture2D = clip.texture
	if texture == null:
		return
	var columns: int = maxi(1, clip.hframes)
	var rows: int = maxi(1, clip.vframes)
	var cell := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var count: int = clip.frames if clip.frames > 0 else columns * rows
	count = clampi(count, 1, columns * rows)
	var frame := 0
	if count > 1 and clip.fps > 0.0:
		var step := int(_time * clip.fps)
		frame = step % count if clip.loop else mini(count - 1, step)
	var region := Rect2(Vector2(frame % columns, frame / columns) * cell, cell)

	var height: float = clip.height
	var scale_factor := height / cell.y * zoom
	# Pixel art scaled by a fraction gets uneven pixels (some one screen pixel
	# wide, some two). Snap the on-screen size of a texel to a whole number.
	var stretch: float = get_viewport().get_final_transform().get_scale().x
	var texel: float = scale_factor * stretch
	if texel >= 1.0 and stretch > 0.0:
		scale_factor = roundf(texel) / stretch
	var feet_row := cell.y * 0.5 + FEET * cell.y / height
	var feet := Vector2(size.x * 0.5, size.y - floor_margin)
	var flipped: bool = (facing > 0.0) != clip.faces_right
	# Draw around the feet point so flipping mirrors the fighter in place.
	draw_set_transform(feet, 0.0, Vector2(-scale_factor if flipped else scale_factor, scale_factor))
	draw_texture_rect_region(texture, Rect2(Vector2(-cell.x * 0.5, -feet_row), cell), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _clip() -> Dictionary:
	var idle := {
		"texture": hero.texture, "hframes": hero.idle_hframes, "vframes": hero.idle_vframes,
		"frames": hero.idle_frames, "fps": hero.idle_fps, "height": hero.sprite_height,
		"faces_right": hero.faces_right, "loop": true,
	}
	match animation:
		"walk":
			if hero.walk_texture != null:
				return {
					"texture": hero.walk_texture, "hframes": hero.walk_hframes,
					"vframes": hero.walk_vframes, "frames": hero.walk_frames,
					"fps": hero.walk_fps, "height": hero.walk_sprite_height,
					"faces_right": hero.walk_faces_right, "loop": true,
				}
		"hurt":
			if hero.hurt_texture != null:
				return {
					"texture": hero.hurt_texture, "hframes": hero.hurt_hframes,
					"vframes": hero.hurt_vframes, "frames": hero.hurt_frames,
					"fps": hero.hurt_fps, "height": hero.hurt_sprite_height,
					"faces_right": hero.hurt_faces_right, "loop": false,
				}
		"death":
			if hero.death_texture != null:
				return {
					"texture": hero.death_texture, "hframes": hero.death_hframes,
					"vframes": hero.death_vframes, "frames": hero.death_frames,
					"fps": hero.death_fps, "height": hero.death_sprite_height,
					"faces_right": hero.death_faces_right, "loop": false,
				}
	return idle
