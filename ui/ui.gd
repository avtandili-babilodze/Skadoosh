class_name UI
extends RefCounted
## The look of every menu in one place: palette, fonts and the small builders
## the screens share. Screens assemble themselves from these instead of styling
## controls ad hoc, so the title, the selects, the HUD and the pause menu read
## as one game.

const DISPLAY: FontFile = preload("res://assets/fonts/Bangers-Regular.ttf")
const BOLD: FontFile = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const SEMI: FontFile = preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const MEDIUM: FontFile = preload("res://assets/fonts/ChakraPetch-Medium.ttf")

## Near-black violet behind everything.
const INK := Color(0.051, 0.043, 0.078)
const PANEL := Color(0.106, 0.09, 0.157)
const PANEL_HI := Color(0.165, 0.141, 0.251)
const LINE := Color(0.29, 0.25, 0.42)
## Warm white for text.
const TEXT := Color(0.965, 0.945, 0.906)
const MUTED := Color(0.64, 0.61, 0.72)
## The brand yellow of the logo, used for the one thing a screen wants pressed.
const GOLD := Color(1.0, 0.81, 0.23)
const HOT := Color(1.0, 0.24, 0.43)

## Slant shared by buttons, plates and banners.
const SKEW := 0.22


## Plain interface text.
static func label(text: String, size: int, color: Color = TEXT, font: Font = SEMI) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Comic display lettering with a heavy ink outline and a hard drop shadow.
static func title(text: String, size: int, color: Color = GOLD) -> Label:
	var node := label(text, size, color, DISPLAY)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", maxi(4, size / 5))
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_x", maxi(2, size / 14))
	node.add_theme_constant_override("shadow_offset_y", maxi(2, size / 10))
	node.add_theme_constant_override("shadow_outline_size", maxi(4, size / 5))
	return node


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0,
		radius: int = 6, skew: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.skew = Vector2(skew, 0.0)
	style.anti_aliasing = true
	return style


## A slanted menu button. It takes keyboard focus when the mouse touches it, so
## mouse, keys and gamepad always agree on what is selected.
static func button(text: String, min_size: Vector2 = Vector2(300, 52), font_size: int = 26) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	node.add_theme_font_override("font", BOLD)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_focus_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_hover_pressed_color", INK)
	var idle := box(Color(PANEL, 0.86), LINE, 2, 4, SKEW)
	var lit := box(GOLD, Color.WHITE, 2, 4, SKEW)
	lit.shadow_color = Color(GOLD, 0.35)
	lit.shadow_size = 10
	var down := box(HOT, Color.WHITE, 2, 4, SKEW)
	for style: StyleBoxFlat in [idle, lit, down]:
		style.content_margin_left = 26.0
		style.content_margin_right = 26.0
	node.add_theme_stylebox_override("normal", idle)
	node.add_theme_stylebox_override("hover", lit)
	node.add_theme_stylebox_override("focus", lit)
	node.add_theme_stylebox_override("pressed", down)
	node.add_theme_stylebox_override("disabled", idle)
	node.mouse_entered.connect(node.grab_focus)
	node.focus_entered.connect(func(): Sfx.ui("ui_move"))
	node.pressed.connect(func(): Sfx.ui("ui_select"))
	return node


## A flat panel for grouped content.
static func panel(bg: Color = Color(PANEL, 0.9), border: Color = LINE, margin: float = 18.0) -> PanelContainer:
	var node := PanelContainer.new()
	var style := box(bg, border, 2, 8)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.8
	style.content_margin_bottom = margin * 0.8
	node.add_theme_stylebox_override("panel", style)
	return node


## A small keycap chip ("W", "Shift") for control hints.
static func keycap(text: String, color: Color = TEXT) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := box(Color(PANEL_HI, 0.95), Color(color, 0.8), 2, 5)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	style.border_width_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	var text_label := label(text, 16, color, BOLD)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(text_label)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## "[key] [key] caption" laid out in a row.
static func hint(keys: Array, caption: String, color: Color = TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in keys:
		row.add_child(keycap(key, color))
	row.add_child(label(caption, 16, MUTED, MEDIUM))
	return row


## Anchors a control to its parent's full rectangle, inset by `margin`.
static func fill(node: Control, margin: float = 0.0) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_top = margin
	node.offset_right = -margin
	node.offset_bottom = -margin


## Pins a control to a preset anchor with explicit offsets on all four sides.
## (set_anchors_preset alone keeps the control's old rectangle, so a freshly
## added control would stay at its minimum size.)
static func place(node: Control, preset: Control.LayoutPreset, left: float, top: float,
		right: float, bottom: float) -> void:
	node.set_anchors_preset(preset)
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom


## A vertical black-to-clear wash, used to seat text over busy art.
static func shade(from: Color, to: Color, vertical: bool = true) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 64
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Menus animate on the render clock, so they opt out of physics interpolation.
static func no_interpolation(node: Node) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
