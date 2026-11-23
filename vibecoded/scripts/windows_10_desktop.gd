class_name Windows10Desktop
extends Control

## Recreates a Windows 10 (dark) desktop as a Control UI.
##
## Show-operator API (all safe to call from a bound script):
##   open_folder(path, items, position)  -> opens an Explorer window
##   close_folder(path) / close_window(window) / close_all_windows()
##   set_filesystem(tree)                -> replace the virtual filesystem
##   set_desktop_icons(icons)            -> replace desktop shortcut icons
##   set_wallpaper_colors(top, bottom)   -> recolor the wallpaper shader
##   open_start_menu() / close_start_menu() / toggle_start_menu()
##   minimize_all() / show_desktop()
##   get_desktop_icon_position(path_or_name) -> Vector2  (walk-to target)
##   get_desktop_icon_rect(path_or_name) -> Rect2
##   get_desktop_icons() / get_desktop_icon_positions() / find_desktop_icon()
##   activate_desktop_icon(path_or_name) -> bool  (open without a click)
##   canvas_to_world(canvas_point, item) -> Vector2  (only for transformed 2D)
##
## Signals: folder_opened, folder_closed, folder_navigated, file_activated,
## window_focused, start_menu_toggled.

signal folder_opened(path: String)
signal folder_closed(path: String)
signal folder_navigated(path: String)
signal file_activated(file_path: String, item: Dictionary)
signal window_focused(window: DesktopWindow)
signal start_menu_toggled(opened: bool)

const TASKBAR_HEIGHT := 40.0

# Desktop shortcut geometry (must match the icon nodes in the .tscn).
const ICON_BUTTON_SIZE := Vector2(270, 288)
const ICON_PICTURE_SIZE := Vector2(144, 144)
const ICON_FONT_SIZE := 36

const ICONS := {
	"folder": preload("res://vibecoded/assets/icons/win10/folder.svg"),
	"this_pc": preload("res://vibecoded/assets/icons/win10/this_pc.svg"),
	"recycle_bin": preload("res://vibecoded/assets/icons/win10/recycle_bin.svg"),
	"documents": preload("res://vibecoded/assets/icons/win10/documents.svg"),
	"pictures": preload("res://vibecoded/assets/icons/win10/pictures.svg"),
	"music": preload("res://vibecoded/assets/icons/win10/music.svg"),
	"videos": preload("res://vibecoded/assets/icons/win10/videos.svg"),
	"settings": preload("res://vibecoded/assets/icons/win10/settings.svg"),
	"file": preload("res://vibecoded/assets/icons/win10/file.svg"),
	"windows_logo": preload("res://vibecoded/assets/icons/win10/windows_logo.svg"),
	"search": preload("res://vibecoded/assets/icons/win10/search.svg"),
	"task_view": preload("res://vibecoded/assets/icons/win10/task_view.svg"),
	"wifi": preload("res://vibecoded/assets/icons/win10/wifi.svg"),
	"volume": preload("res://vibecoded/assets/icons/win10/volume.svg"),
	"notification": preload("res://vibecoded/assets/icons/win10/notification.svg"),
	"chevron_up": preload("res://vibecoded/assets/icons/win10/chevron_up.svg"),
	"user": preload("res://vibecoded/assets/icons/win10/user.svg"),
	"power": preload("res://vibecoded/assets/icons/win10/power.svg"),
	"menu": preload("res://vibecoded/assets/icons/win10/menu.svg"),
}

const START_APPS := [
	{"label": "File Explorer", "path": "This PC", "icon": "this_pc"},
	{"label": "This PC", "path": "This PC", "icon": "this_pc"},
	{"label": "Documents", "path": "Documents", "icon": "documents"},
	{"label": "Downloads", "path": "Downloads", "icon": "folder"},
	{"label": "Pictures", "path": "Pictures", "icon": "pictures"},
	{"label": "Music", "path": "Music", "icon": "music"},
	{"label": "Videos", "path": "Videos", "icon": "videos"},
	{"label": "Recycle Bin", "path": "Recycle Bin", "icon": "recycle_bin"},
]

@export var open_icons_on_single_click := false
@export var wallpaper_top_color := Color("0a2347")
@export var wallpaper_bottom_color := Color("0a5c9c")

@onready var wallpaper: ColorRect = %Wallpaper
@onready var icon_flow: VFlowContainer = %IconFlow
@onready var window_layer: Control = %WindowLayer
@onready var app_buttons: HBoxContainer = %AppButtons
@onready var start_button: Button = %StartButton
@onready var start_menu: PanelContainer = %StartMenu
@onready var tiles_grid: GridContainer = %TilesGrid
@onready var app_list: VBoxContainer = %AppList
@onready var time_label: Label = %TimeLabel
@onready var date_label: Label = %DateLabel
@onready var show_desktop_button: Button = %ShowDesktop

var filesystem: Dictionary = {}
var _folder_overrides: Dictionary = {}
var _windows: Array[DesktopWindow] = []
var _taskbar_buttons: Dictionary = {}
var _active_window: DesktopWindow = null
var _icon_group: ButtonGroup
var _icon_hover_style: StyleBoxFlat
var _icon_selected_style: StyleBoxFlat
var _start_menu_open := false
var _start_tween: Tween
var _clock_accumulator := 0.0
var _last_icon_button: Button = null
var _last_icon_time := 0


func _ready() -> void:
	_fit_to_host()
	filesystem = default_filesystem()
	_icon_group = ButtonGroup.new()
	_icon_group.allow_unpress = true
	_icon_hover_style = Win10Theme.flat(Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.35), 1, 2)
	_icon_selected_style = Win10Theme.flat(Color(0.1, 0.45, 0.8, 0.55), Color(0.4, 0.75, 1.0, 0.9), 1, 2)

	_apply_wallpaper()
	_bind_static_desktop_icons()
	_bind_start_menu()
	_build_app_list()
	start_button.pressed.connect(toggle_start_menu)
	show_desktop_button.pressed.connect(show_desktop)
	start_menu.visible = false
	resized.connect(_layout_maximized_windows)
	get_viewport().size_changed.connect(_fit_to_host)
	_update_clock()
	set_process(true)


## The root uses full-rect anchors, which need a parent rect to resolve.
## A Control parent, a CanvasLayer and the viewport all provide one; a Node2D
## parent does not, so the layout would collapse to 0x0. In that case the
## desktop sizes itself to the viewport instead.
func _fit_to_host() -> void:
	if not is_inside_tree():
		return
	var host := get_parent()
	if host is Control or (is_instance_valid(host) and host is CanvasLayer):
		return
	if host == null or host == get_viewport():
		return
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_clock_accumulator += delta
	if _clock_accumulator >= 1.0:
		_clock_accumulator = 0.0
		_update_clock()


func _input(event: InputEvent) -> void:
	if _start_menu_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close_start_menu()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos := get_global_mouse_position()
			var inside_menu := start_menu.get_global_rect().has_point(mouse_pos)
			var inside_start := start_button.get_global_rect().has_point(mouse_pos)
			if not inside_menu and not inside_start:
				close_start_menu()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Opens an Explorer window. `path` accepts a String ("This PC/Documents") or
## an Array of segments. `items` optionally supplies the folder contents
## directly (and registers them for later navigation).
func open_folder(path: Variant = "This PC", items: Array = [], window_position := Vector2.INF) -> Control:
	var normalized := _normalize_path(path)
	if normalized.is_empty():
		normalized = "This PC"
	if not items.is_empty():
		_folder_overrides[normalized] = items.duplicate(true)

	var window := ExplorerWindow.new()
	window.desktop = self
	window.folder_path = normalized
	window.window_title = _display_name(normalized)
	window.window_icon = icon_texture("folder")
	window_layer.add_child(window)
	window.size = _default_window_size()
	if window_position == Vector2.INF:
		window.position = _next_window_position(window.size)
	else:
		var area := desktop_rect()
		var target := window_position
		target.x = clampf(target.x, area.position.x + 8.0, maxf(area.position.x + 8.0, area.position.x + area.size.x - window.size.x - 8.0))
		target.y = clampf(target.y, area.position.y + 8.0, maxf(area.position.y + 8.0, area.position.y + area.size.y - window.size.y - 8.0))
		window.position = target
	_register_window(window)
	window.force_layout()
	return window


## Replaces the contents of a folder in the virtual filesystem.
func set_folder_items(path: Variant, items: Array) -> void:
	_folder_overrides[_normalize_path(path)] = items.duplicate(true)


## Removes a folder override, falling back to the base filesystem.
func clear_folder_items(path: Variant) -> void:
	_folder_overrides.erase(_normalize_path(path))


## Replaces the whole virtual filesystem. Keys are folder paths
## (e.g. "This PC/Documents"), values are Arrays of item dictionaries:
##   {"name": "Overlays", "type": "folder", "icon": "folder", "path": "..."}
func set_filesystem(tree: Dictionary) -> void:
	filesystem = tree.duplicate(true)
	_folder_overrides.clear()


## Returns the items registered for a folder path.
func get_folder_items(path: Variant) -> Array:
	var normalized := _normalize_path(path)
	if _folder_overrides.has(normalized):
		return _folder_overrides[normalized]
	if filesystem.has(normalized):
		return filesystem[normalized]
	return []


## Rebuilds the desktop shortcuts. Each entry:
##   {"name": "Documents", "path": "Documents", "icon": "documents"}
func set_desktop_icons(icons: Array) -> void:
	for child in icon_flow.get_children():
		icon_flow.remove_child(child)
		child.queue_free()
	for spec in icons:
		if not spec is Dictionary:
			continue
		var display := str(spec.get("name", spec.get("label", "Folder")))
		var path := str(spec.get("path", display))
		icon_flow.add_child(_make_desktop_icon(display, path, spec.get("icon", "folder")))


## Recolors the procedural wallpaper.
func set_wallpaper_colors(top: Color, bottom: Color) -> void:
	wallpaper_top_color = top
	wallpaper_bottom_color = bottom
	_apply_wallpaper()


func close_folder(path: Variant) -> void:
	var normalized := _normalize_path(path)
	for window in _windows.duplicate():
		if is_instance_valid(window) and window.folder_path == normalized:
			window.request_close()


func close_window(window: DesktopWindow) -> void:
	if is_instance_valid(window):
		window.request_close()


func close_all_windows() -> void:
	for window in _windows.duplicate():
		if is_instance_valid(window):
			window.request_close()


func restore_window(window: DesktopWindow) -> void:
	if not is_instance_valid(window):
		return
	window.restore()
	_focus_window(window)


func focus_window(window: DesktopWindow) -> void:
	_focus_window(window)


func minimize_all() -> void:
	for window in _windows:
		if is_instance_valid(window):
			window.minimize()


func show_desktop() -> void:
	minimize_all()


func get_open_folders() -> Array[String]:
	var result: Array[String] = []
	for window in _windows:
		if is_instance_valid(window):
			result.append(window.folder_path)
	return result


func open_start_menu() -> void:
	if _start_menu_open:
		return
	_start_menu_open = true
	if _start_tween:
		_start_tween.kill()
	start_menu.visible = true
	start_menu.modulate.a = 0.0
	_start_tween = create_tween()
	_start_tween.tween_property(start_menu, "modulate:a", 1.0, 0.12)
	start_menu_toggled.emit(true)


func close_start_menu() -> void:
	if not _start_menu_open:
		return
	_start_menu_open = false
	if _start_tween:
		_start_tween.kill()
	_start_tween = create_tween()
	_start_tween.tween_property(start_menu, "modulate:a", 0.0, 0.1)
	_start_tween.tween_callback(func() -> void: start_menu.visible = false)
	start_menu_toggled.emit(false)


func toggle_start_menu() -> void:
	if _start_menu_open:
		close_start_menu()
	else:
		open_start_menu()


func is_start_menu_open() -> bool:
	return _start_menu_open


func desktop_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, maxf(size.y - TASKBAR_HEIGHT, 200.0)))


func icon_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	return ICONS.get(str(value), ICONS["file"])


# ---------------------------------------------------------------------------
# Desktop icon geometry (for show choreography, e.g. a walking character)
# ---------------------------------------------------------------------------
# Coordinate space: CANVAS space, i.e. the desktop's own 1152x648 design space
# (origin top-left) after the `canvas_items` stretch is applied. A Camera2D does
# not change it. Node2D uses the same space for global_position, so these values
# are directly usable as 2D movement targets when the character sits at the
# scene root with an identity transform. If the character lives under a
# transformed parent or a CanvasLayer, convert with canvas_to_world().

## Every desktop shortcut with its on-screen geometry:
##   {"name", "path", "rect", "center", "icon_center", "button"}
## "rect" is the whole shortcut button, "center" its middle, "icon_center" the
## middle of the 48 px icon picture (the point to walk to).
func get_desktop_icons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in icon_flow.get_children():
		if child is Button:
			result.append(_desktop_icon_info(child as Button))
	return result


## Shortcut positions keyed by folder path: {"Documents": Vector2, ...}.
func get_desktop_icon_positions() -> Dictionary:
	var result := {}
	for info in get_desktop_icons():
		result[str(info["path"])] = info["icon_center"] as Vector2
	return result


## Finds a shortcut by folder path or display name (case-insensitive).
## Returns {} when there is no such shortcut.
func find_desktop_icon(path_or_name: Variant) -> Dictionary:
	var needle := _normalize_path(path_or_name).to_lower()
	if needle.is_empty():
		return {}
	for child in icon_flow.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		if _normalize_path(button.get_meta("desktop_path", "")).to_lower() == needle:
			return _desktop_icon_info(button)
		if str(button.get_meta("desktop_name", "")).to_lower() == needle:
			return _desktop_icon_info(button)
	return {}


## Point a character should walk to before opening this folder.
## Returns Vector2.INF when no matching shortcut exists.
func get_desktop_icon_position(path_or_name: Variant) -> Vector2:
	var info := find_desktop_icon(path_or_name)
	return info.get("icon_center", Vector2.INF)


## Rect of the whole shortcut button. Returns Rect2() when it does not exist.
func get_desktop_icon_rect(path_or_name: Variant) -> Rect2:
	var info := find_desktop_icon(path_or_name)
	return info.get("rect", Rect2())


## Opens the folder behind a shortcut without a mouse click and highlights it.
## Handy for scripted shows. Returns false when there is no such shortcut.
func activate_desktop_icon(path_or_name: Variant) -> bool:
	var info := find_desktop_icon(path_or_name)
	if info.is_empty():
		return false
	var button := info["button"] as Button
	if is_instance_valid(button):
		button.set_pressed_no_signal(true)
	open_folder(info["path"])
	return true


## Converts a desktop-canvas point into the space of a 2D item
## (Node2D character, Sprite2D, Control, ...). Only needed when that item has a
## non-identity transform or lives under a CanvasLayer; otherwise canvas space
## and 2D world space are the same.
func canvas_to_world(canvas_point: Vector2, reference: CanvasItem) -> Vector2:
	return reference.get_global_transform_with_canvas().affine_inverse() * canvas_point


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _desktop_icon_info(button: Button) -> Dictionary:
	var rect := button.get_global_rect()
	var icon_center := rect.get_center()
	for node in button.find_children("*", "TextureRect", true, false):
		var tex_rect := node as TextureRect
		if tex_rect.is_visible_in_tree():
			icon_center = tex_rect.get_global_rect().get_center()
			break
	return {
		"name": str(button.get_meta("desktop_name", button.tooltip_text)),
		"path": _normalize_path(button.get_meta("desktop_path", "")),
		"rect": rect,
		"center": rect.get_center(),
		"icon_center": icon_center,
		"button": button,
	}


func _normalize_path(path: Variant) -> String:
	var value := ""
	if path is Array:
		var parts := PackedStringArray()
		for part in path:
			parts.append(str(part))
		value = "/".join(parts)
	else:
		value = str(path)
	value = value.strip_edges().replace("\\", "/")
	while value.contains("//"):
		value = value.replace("//", "/")
	return value.trim_suffix("/")


func _display_name(path: String) -> String:
	if path.is_empty():
		return "This PC"
	var parts := path.split("/", false)
	return str(parts[parts.size() - 1])


func _apply_wallpaper() -> void:
	if not is_instance_valid(wallpaper):
		return
	var shader_material := wallpaper.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("top_color", wallpaper_top_color)
		shader_material.set_shader_parameter("bottom_color", wallpaper_bottom_color)


func _bind_static_desktop_icons() -> void:
	for child in icon_flow.get_children():
		if child is Button:
			var button := child as Button
			_bind_desktop_icon(
				button,
				str(button.get_meta("desktop_path", button.name)),
				str(button.get_meta("desktop_icon", "folder"))
			)


func _bind_desktop_icon(button: Button, path: String, _icon_name: String) -> void:
	button.set_meta("desktop_path", path)
	if not button.has_meta("desktop_name"):
		var display := button.tooltip_text.strip_edges()
		if display.is_empty():
			display = button.name.trim_prefix("Icon")
		button.set_meta("desktop_name", display)
	button.toggle_mode = true
	button.button_group = _icon_group
	button.focus_mode = Control.FOCUS_NONE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Win10Theme.style(button, "hover", _icon_hover_style)
	Win10Theme.style(button, "pressed", _icon_selected_style)
	Win10Theme.style(button, "hover_pressed", _icon_selected_style)
	Win10Theme.style(button, "focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_desktop_icon_pressed.bind(button, path))


func _make_desktop_icon(display_name: String, path: String, icon_value: Variant) -> Button:
	var button := Button.new()
	button.name = "Icon_" + display_name.validate_node_name()
	button.custom_minimum_size = ICON_BUTTON_SIZE
	button.text = ""
	button.flat = true
	button.tooltip_text = display_name
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bind_desktop_icon(button, path, "folder")

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 4.0
	layout.offset_top = 6.0
	layout.offset_right = -4.0
	layout.offset_bottom = -6.0
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 4)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_PICTURE_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.texture = icon_texture(icon_value)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(icon)

	var label := Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	Win10Theme.color(label, "font_color", Color.WHITE)
	Win10Theme.color(label, "font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(label)

	return button


func _on_desktop_icon_pressed(button: Button, path: String) -> void:
	var now := Time.get_ticks_msec()
	if open_icons_on_single_click or (_last_icon_button == button and now - _last_icon_time <= 400):
		_last_icon_button = null
		button.set_pressed_no_signal(true)
		open_folder(path)
	else:
		_last_icon_button = button
		_last_icon_time = now


func _bind_start_menu() -> void:
	for tile in tiles_grid.get_children():
		if tile is Button and tile.has_meta("desktop_path"):
			var path := str(tile.get_meta("desktop_path"))
			(tile as Button).pressed.connect(func() -> void: open_folder(path))


func _build_app_list() -> void:
	for child in app_list.get_children():
		app_list.remove_child(child)
		child.queue_free()
	for entry in START_APPS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 30)
		button.tooltip_text = str(entry["label"])
		Win10Theme.apply_flat_button(button)
		Win10Theme.add_icon_label_row(button, icon_texture(entry["icon"]), str(entry["label"]), 12, 16.0, 6.0)
		var path := str(entry["path"])
		button.pressed.connect(func() -> void: open_folder(path))
		app_list.add_child(button)


func _register_window(window: DesktopWindow) -> void:
	_windows.append(window)
	window.focus_requested.connect(_on_window_focus_requested)
	window.minimized.connect(_on_window_minimized)
	window.closed.connect(_on_window_closed)
	window.title_changed.connect(_on_window_title_changed)

	var task_button := _make_taskbar_button(window)
	app_buttons.add_child(task_button)
	_taskbar_buttons[window] = task_button

	_focus_window(window)
	folder_opened.emit(window.folder_path)


func _make_taskbar_button(window: DesktopWindow) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, TASKBAR_HEIGHT)
	button.tooltip_text = window.window_title
	button.focus_mode = Control.FOCUS_NONE
	Win10Theme.apply_flat_button(button, Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.2))
	Win10Theme.style(button, "normal", Win10Theme.taskbar_app_button(false))
	Win10Theme.add_centered_texture(button, window.window_icon, 20.0)
	button.pressed.connect(_on_taskbar_app_pressed.bind(window))
	return button


func _on_taskbar_app_pressed(window: DesktopWindow) -> void:
	if not is_instance_valid(window):
		return
	if window.visible and _active_window == window:
		window.minimize()
	else:
		if not window.visible:
			window.restore()
		_focus_window(window)


func _on_window_focus_requested(window: DesktopWindow) -> void:
	_focus_window(window)


func _focus_window(window: DesktopWindow) -> void:
	if not is_instance_valid(window):
		return
	_active_window = window
	for other in _windows:
		if is_instance_valid(other):
			other.set_active(other == window)
	window.move_to_front()
	_update_taskbar_state()
	window_focused.emit(window)


func _on_window_minimized(window: DesktopWindow) -> void:
	if _active_window == window:
		_active_window = null
	_update_taskbar_state()


func _on_window_closed(window: DesktopWindow) -> void:
	var path := window.folder_path
	_windows.erase(window)
	var task_button: Button = _taskbar_buttons.get(window)
	_taskbar_buttons.erase(window)
	if is_instance_valid(task_button):
		task_button.queue_free()
	if _active_window == window:
		_active_window = null
		for index in range(_windows.size() - 1, -1, -1):
			var candidate := _windows[index]
			if is_instance_valid(candidate) and candidate.visible:
				_focus_window(candidate)
				break
	_update_taskbar_state()
	folder_closed.emit(path)


func _on_window_title_changed(window: DesktopWindow, title: String) -> void:
	var task_button: Button = _taskbar_buttons.get(window)
	if is_instance_valid(task_button):
		task_button.tooltip_text = title


func _update_taskbar_state() -> void:
	for key in _taskbar_buttons.keys():
		var task_button: Button = _taskbar_buttons[key]
		if not is_instance_valid(task_button):
			continue
		var window := key as DesktopWindow
		var active := window == _active_window and is_instance_valid(window) and window.visible
		Win10Theme.style(task_button, "normal", Win10Theme.taskbar_app_button(active))
		Win10Theme.style(
			task_button,
			"hover",
			Win10Theme.flat(Color(1, 1, 1, 0.16) if active else Color(1, 1, 1, 0.1))
		)


func _layout_maximized_windows() -> void:
	var area := desktop_rect()
	for window in _windows:
		if is_instance_valid(window) and window.is_maximized:
			window.position = area.position
			window.size = area.size


func _default_window_size() -> Vector2:
	var area := desktop_rect()
	return Vector2(
		minf(780.0, maxf(560.0, area.size.x - 160.0)),
		minf(500.0, maxf(320.0, area.size.y - 120.0))
	)


func _next_window_position(window_size: Vector2) -> Vector2:
	var area := desktop_rect()
	var index := _windows.size()
	var step := 28.0
	var base := area.position + Vector2(96, 64)
	var target := base + Vector2(step, step) * float(index % 6)
	var limit := area.position + area.size - window_size - Vector2(12, 12)
	target.x = clampf(target.x, area.position.x + 8.0, maxf(area.position.x + 8.0, limit.x))
	target.y = clampf(target.y, area.position.y + 8.0, maxf(area.position.y + 8.0, limit.y))
	return target


func _update_clock() -> void:
	var now := Time.get_time_dict_from_system()
	var hour: int = int(now["hour"]) % 12
	if hour == 0:
		hour = 12
	var suffix := "AM" if int(now["hour"]) < 12 else "PM"
	if is_instance_valid(time_label):
		time_label.text = "%d:%02d %s" % [hour, int(now["minute"]), suffix]
	var date := Time.get_date_dict_from_system()
	if is_instance_valid(date_label):
		date_label.text = "%d/%d/%d" % [int(date["month"]), int(date["day"]), int(date["year"])]


func notify_folder_navigation(window: DesktopWindow, path: String) -> void:
	var task_button: Button = _taskbar_buttons.get(window)
	if is_instance_valid(task_button):
		task_button.tooltip_text = _display_name(path)
	folder_navigated.emit(path)


func notify_file_activated(file_path: String, item: Dictionary) -> void:
	file_activated.emit(file_path, item)


static func default_filesystem() -> Dictionary:
	return {
		"This PC": [
			{"name": "Desktop", "type": "folder", "icon": "folder", "path": "Desktop"},
			{"name": "Documents", "type": "folder", "icon": "documents", "path": "Documents"},
			{"name": "Downloads", "type": "folder", "icon": "folder", "path": "Downloads"},
			{"name": "Pictures", "type": "folder", "icon": "pictures", "path": "Pictures"},
			{"name": "Music", "type": "folder", "icon": "music", "path": "Music"},
			{"name": "Videos", "type": "folder", "icon": "videos", "path": "Videos"},
			{"name": "Local Disk (C:)", "type": "folder", "icon": "this_pc", "path": "Local Disk (C:)"},
		],
		"Desktop": [
			{"name": "Show Assets", "type": "folder", "icon": "folder", "path": "Desktop/Show Assets"},
			{"name": "Read Me.txt", "type": "file", "icon": "file", "path": "Desktop/Read Me.txt"},
		],
		"Desktop/Show Assets": [
			{"name": "Overlays", "type": "folder", "icon": "folder", "path": "Desktop/Show Assets/Overlays"},
			{"name": "Clips", "type": "folder", "icon": "videos", "path": "Desktop/Show Assets/Clips"},
			{"name": "Cues", "type": "folder", "icon": "folder", "path": "Desktop/Show Assets/Cues"},
			{"name": "logo.png", "type": "file", "icon": "pictures", "path": "Desktop/Show Assets/logo.png"},
		],
		"Documents": [
			{"name": "Projects", "type": "folder", "icon": "folder", "path": "Documents/Projects"},
			{"name": "Notes.txt", "type": "file", "icon": "file", "path": "Documents/Notes.txt"},
		],
		"Documents/Projects": [
			{"name": "studclub", "type": "folder", "icon": "folder", "path": "Documents/Projects/studclub"},
		],
		"Downloads": [
			{"name": "wallpaper.png", "type": "file", "icon": "pictures", "path": "Downloads/wallpaper.png"},
		],
		"Pictures": [
			{"name": "Wallpapers", "type": "folder", "icon": "folder", "path": "Pictures/Wallpapers"},
			{"name": "logo.png", "type": "file", "icon": "pictures", "path": "Pictures/logo.png"},
		],
		"Music": [
			{"name": "Beds", "type": "folder", "icon": "folder", "path": "Music/Beds"},
		],
		"Videos": [
			{"name": "Loops", "type": "folder", "icon": "folder", "path": "Videos/Loops"},
		],
		"Local Disk (C:)": [
			{"name": "Users", "type": "folder", "icon": "folder", "path": "Local Disk (C:)/Users"},
			{"name": "Program Files", "type": "folder", "icon": "folder", "path": "Local Disk (C:)/Program Files"},
			{"name": "Windows", "type": "folder", "icon": "folder", "path": "Local Disk (C:)/Windows"},
		],
		"Recycle Bin": [],
		"Settings": [
			{"name": "Personalization", "type": "folder", "icon": "settings", "path": "Settings/Personalization"},
			{"name": "System", "type": "folder", "icon": "settings", "path": "Settings/System"},
			{"name": "Devices", "type": "folder", "icon": "settings", "path": "Settings/Devices"},
		],
	}
