class_name Win10Theme
extends RefCounted

## Shared Windows 10 (dark) styling used by the desktop, windows and explorer.
## Everything here is generated in code so the desktop stays consistent even
## when the scene is rebuilt or extended.

const ACCENT := Color("0078d7")
const ACCENT_LIGHT := Color("4cc2ff")
const WINDOW_BG := Color("202020")
const WINDOW_BORDER_ACTIVE := Color("4d4d4d")
const WINDOW_BORDER_INACTIVE := Color("333333")
const TITLE_TEXT := Color("ffffff")
const TITLE_TEXT_INACTIVE := Color("b0b0b0")
const CLOSE_HOVER := Color("e81123")
const CLOSE_PRESSED := Color("f1707a")
const HOVER := Color(1, 1, 1, 0.09)
const PRESSED := Color(1, 1, 1, 0.16)
const SELECTION := Color(0.0, 0.47, 0.84, 0.35)
const SELECTION_BORDER := Color(0.3, 0.72, 1.0, 0.85)


static func flat(
	bg: Color,
	border_color := Color(0, 0, 0, 0),
	border_width := 0,
	radius := 0,
	content_margin := 0.0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border_color
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_right = radius
	box.corner_radius_bottom_left = radius
	box.content_margin_left = content_margin
	box.content_margin_top = content_margin
	box.content_margin_right = content_margin
	box.content_margin_bottom = content_margin
	box.anti_aliasing = true
	return box


static func window_panel(active: bool) -> StyleBoxFlat:
	var border := WINDOW_BORDER_ACTIVE if active else WINDOW_BORDER_INACTIVE
	return flat(WINDOW_BG, border, 1)


static func titlebar() -> StyleBoxFlat:
	var box := flat(Color("202020"))
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	return box


static func taskbar_app_button(active: bool) -> StyleBoxFlat:
	var box := flat(Color("2a2a2a") if active else Color(0, 0, 0, 0))
	if active:
		box.border_width_bottom = 2
		box.border_color = ACCENT_LIGHT
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	return box


static func item_normal() -> StyleBoxFlat:
	var box := flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2)
	box.content_margin_left = 2.0
	box.content_margin_top = 2.0
	box.content_margin_right = 2.0
	box.content_margin_bottom = 2.0
	return box


static func item_hover() -> StyleBoxFlat:
	return flat(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), 1, 2, 2.0)


static func item_selected() -> StyleBoxFlat:
	return flat(SELECTION, SELECTION_BORDER, 1, 2, 2.0)


static func explorer_toolbar() -> StyleBoxFlat:
	var box := flat(Color("2d2d2d"))
	box.content_margin_left = 6.0
	box.content_margin_top = 0.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 0.0
	return box


static func explorer_sidebar() -> StyleBoxFlat:
	var box := flat(Color("252525"))
	box.content_margin_left = 8.0
	box.content_margin_top = 6.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 6.0
	return box


static func explorer_background() -> StyleBoxFlat:
	return flat(Color("1e1e1e"))


static func explorer_status() -> StyleBoxFlat:
	var box := flat(Color("1f1f1f"))
	box.border_width_top = 1
	box.border_color = Color("333333")
	box.content_margin_left = 10.0
	box.content_margin_top = 2.0
	box.content_margin_right = 10.0
	box.content_margin_bottom = 2.0
	return box


static func address_bar() -> StyleBoxFlat:
	var box := flat(Color("1b1b1b"), Color("4a4a4a"), 1, 2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	return box


static func apply_flat_button(button: Button, hover_bg := HOVER, pressed_bg := PRESSED) -> void:
	button.add_theme_stylebox_override("normal", flat(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", flat(hover_bg))
	button.add_theme_stylebox_override("pressed", flat(pressed_bg))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Adds a fixed-size, aspect-preserving texture centered inside a control.
## Used instead of Button.icon so large source textures do not inflate the
## button's minimum size.
static func add_centered_texture(control: Control, texture: Texture2D, icon_size := 16.0) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = 0.5
	rect.anchor_top = 0.5
	rect.anchor_right = 0.5
	rect.anchor_bottom = 0.5
	rect.offset_left = -icon_size * 0.5
	rect.offset_top = -icon_size * 0.5
	rect.offset_right = icon_size * 0.5
	rect.offset_bottom = icon_size * 0.5
	control.add_child(rect)
	return rect


## Adds a left-aligned icon + label row inside a button.
static func add_icon_label_row(
	button: Button,
	texture: Texture2D,
	text: String,
	font_size := 12,
	icon_size := 16.0,
	left_pad := 8.0
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = left_pad
	row.offset_right = -6.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6e6e6"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row
