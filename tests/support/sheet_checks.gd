extends RefCounted
## Pixel-level checks shared by the suites: sheet grids, transparent corners,
## shared ground lines and drawn stride. All static; nothing here reports results.


static func has_transparent_corners(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	return (image.get_pixel(0, 0).a < 0.01
			and image.get_pixel(last_x, 0).a < 0.01
			and image.get_pixel(0, last_y).a < 0.01
			and image.get_pixel(last_x, last_y).a < 0.01)


## On-screen step length drawn in a walk sheet, measured heel to heel. Only the
## soles (the lowest rows of each frame) are read, so a long dress that reaches the
## floor cannot hide the feet; feet are told apart by the gap between them, and
## sheets face right, so each foot's heel is its left edge.
static func walk_step_length(hero: HeroData) -> float:
	var image := hero.walk_texture.get_image()
	var cell_w: int = image.get_width() / hero.walk_hframes
	var cell_h: int = image.get_height() / hero.walk_vframes
	var count: int = hero.walk_frames if hero.walk_frames > 0 else hero.walk_hframes * hero.walk_vframes
	var widest := 0
	for k in count:
		var ox: int = (k % hero.walk_hframes) * cell_w
		var oy: int = (k / hero.walk_hframes) * cell_h
		var top := -1
		var bottom := -1
		for y in cell_h:
			for x in cell_w:
				if image.get_pixel(ox + x, oy + y).a > 0.0:
					if top < 0:
						top = y
					bottom = y
					break
		if top < 0:
			continue
		var rows := maxi(3, int((bottom - top) * 0.06))
		var first_heel := -1
		var last_heel := -1
		var previous := -100
		for x in cell_w:
			var sole := false
			for y in range(bottom - rows + 1, bottom + 1):
				if image.get_pixel(ox + x, oy + y).a > 0.0:
					sole = true
					break
			if sole:
				if x - previous > 3:
					if first_heel < 0:
						first_heel = x
					last_heel = x
				previous = x
		if first_heel >= 0 and last_heel > first_heel:
			widest = maxi(widest, last_heel - first_heel)
	return float(widest) * hero.walk_sprite_height / cell_h


static func has_clear_vertical_frame_gutters(texture: Texture2D, hframes: int,
		vframes: int, gutter_width: int = 2) -> bool:
	if texture == null or hframes <= 0 or vframes <= 0:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	if image.get_width() % hframes != 0 or image.get_height() % vframes != 0:
		return false
	var frame_width := image.get_width() / hframes
	var frame_height := image.get_height() / vframes
	for row in range(vframes):
		var top := row * frame_height
		for column in range(hframes):
			var left := column * frame_width
			var right := left + frame_width - 1
			for inset in range(gutter_width):
				for y in range(top, top + frame_height):
					if (image.get_pixel(left + inset, y).a >= 0.01
							or image.get_pixel(right - inset, y).a >= 0.01):
						return false
	return true


static func has_opaque_pale_skin(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	var pale_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if (color.r >= 0.70 and color.g >= 0.60 and color.b >= 0.60
					and color.r >= color.g and absf(color.g - color.b) <= 0.09
					and color.a >= 0.99):
				pale_pixels += 1
	return pale_pixels > 32


static func all_visible_pixels_are_opaque(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha >= 0.01 and alpha < 0.99:
				return false
	return true


static func frames_share_visible_baseline(texture: Texture2D, hframes: int,
		vframes: int, tolerance: int = 1) -> bool:
	if texture == null or hframes <= 0 or vframes <= 0:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	if image.get_width() % hframes != 0 or image.get_height() % vframes != 0:
		return false
	var frame_width := image.get_width() / hframes
	var frame_height := image.get_height() / vframes
	var shared_bottom := -1
	for row in range(vframes):
		for column in range(hframes):
			var frame_bottom := -1
			for y in range(frame_height - 1, -1, -1):
				for x in range(frame_width):
					if image.get_pixel(column * frame_width + x, row * frame_height + y).a >= 0.01:
						frame_bottom = y
						break
				if frame_bottom >= 0:
					break
			if frame_bottom < 0:
				return false
			if shared_bottom < 0:
				shared_bottom = frame_bottom
			elif absi(frame_bottom - shared_bottom) > tolerance:
				return false
	return true


static func visible_baseline_offset(texture: Texture2D, hframes: int,
		vframes: int, sprite_height: float) -> float:
	if texture == null or hframes <= 0 or vframes <= 0:
		return INF
	var image := texture.get_image()
	if image == null or image.is_empty():
		return INF
	var frame_width: int = image.get_width() / hframes
	var frame_height: int = image.get_height() / vframes
	for y in range(frame_height - 1, -1, -1):
		for x in range(frame_width):
			if image.get_pixel(x, y).a >= 0.01:
				return (y - frame_height * 0.5) * sprite_height / frame_height
	return INF
