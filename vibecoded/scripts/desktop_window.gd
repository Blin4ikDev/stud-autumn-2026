class_name DesktopWindow
extends PanelContainer

## A draggable / minimizable / maximizable Windows 10 style window.
## Subclasses only need to override _build_content() to fill the client area.

signal closed(window: DesktopWindow)
signal focus_requested(window: DesktopWindow)
signal minimized(window: DesktopWindow)
## Emitted when a minimized window is shown again (taskbar click, restore_window, ...).
signal restored(window: DesktopWindow)
signal title_changed(window: DesktopWindow, title: String)
signal maximized_changed(window: DesktopWindow, maximized: bool)
## Emitted when the window position changes (drag, resize, maximize, restore).
signal moved(window: DesktopWindow, new_position: Vector2)
## Emitted on every frame the position changes, i.e. continuously while the
## window is being dragged. Use `moved` for "gesture finished", this one for
## live tracking.
signal position_changed(window: DesktopWindow, new_position: Vector2)

const TITLEBAR_HEIGHT := 32.0
const RESIZE_CORNER := 18.0

var desktop: Node = null
var folder_path := ""
## Stable id assigned by Windows10Desktop when the window is registered.
var window_id := 0
var window_title := "Window":
	set(value):
		window_title = value
		if is_instance_valid(_title_label):
			_title_label.text = value
		title_changed.emit(self, value)
var window_icon: Texture2D = null:
	set(value):
		window_icon = value
		if is_instance_valid(_icon_rect):
			_icon_rect.texture = value
			_icon_rect.visible = value != null

var is_maximized := false
var is_active := false

var _title_bar: PanelContainer
var _title_label: Label
var _icon_rect: TextureRect
var _content_root: Control
var _max_button: Button
var _built := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _resizing := false
var _resize_start_mouse := Vector2.ZERO
var _resize_start_size := Vector2.ZERO
var _restore_rect := Rect2()
var _visibility_tween: Tween
var _closing := false
var _corner_cursor := false
var _last_reported_position := Vector2.INF
var _last_position_sample := Vector2.INF


func _ready() -> void:
	if not _built:
		_build_chrome()
		_build_content(_content_root)
	_last_position_sample = position


func _process(_delta: float) -> void:
	if position.is_equal_approx(_last_position_sample):
		return
	_last_position_sample = position
	position_changed.emit(self, position)


## Override in subclasses to fill the client area.
func _build_content(_root: Control) -> void:
	pass


func _build_chrome() -> void:
	_built = true
	custom_minimum_size = Vector2(560, 320)
	add_theme_stylebox_override("panel", Win10Theme.window_panel(false))

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(layout)

	_title_bar = PanelContainer.new()
	_title_bar.name = "TitleBar"
	_title_bar.custom_minimum_size = Vector2(0, TITLEBAR_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_bar.add_theme_stylebox_override("panel", Win10Theme.titlebar())
	_title_bar.gui_input.connect(_on_titlebar_input)
	layout.add_child(_title_bar)

	var bar := HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 0)
	_title_bar.add_child(bar)

	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(8, 0)
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(left_pad)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "WindowIcon"
	_icon_rect.custom_minimum_size = Vector2(16, 16)
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_icon_rect.texture = window_icon
	_icon_rect.visible = window_icon != null
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_icon_rect)

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(8, 0)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icon_pad)

	_title_label = Label.new()
	_title_label.name = "WindowTitle"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.text = window_title
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Win10Theme.TITLE_TEXT_INACTIVE)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_title_label)

	var minimize_button := _make_window_button("\u2014", 12)
	minimize_button.name = "MinimizeButton"
	minimize_button.tooltip_text = "Minimize"
	minimize_button.pressed.connect(minimize)
	bar.add_child(minimize_button)

	_max_button = _make_window_button("\u25a1", 12)
	_max_button.name = "MaximizeButton"
	_max_button.tooltip_text = "Maximize"
	_max_button.pressed.connect(toggle_maximize)
	bar.add_child(_max_button)

	var close_button := _make_window_button("\u2715", 11)
	close_button.name = "CloseButton"
	close_button.tooltip_text = "Close"
	close_button.add_theme_stylebox_override("hover", Win10Theme.flat(Win10Theme.CLOSE_HOVER))
	close_button.add_theme_stylebox_override("pressed", Win10Theme.flat(Win10Theme.CLOSE_PRESSED))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	close_button.pressed.connect(request_close)
	bar.add_child(close_button)

	var content_margin := MarginContainer.new()
	content_margin.name = "Content"
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.clip_contents = true
	content_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(content_margin)
	_content_root = content_margin


func _make_window_button(glyph: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = glyph
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(46, TITLEBAR_HEIGHT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Win10Theme.TITLE_TEXT_INACTIVE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	Win10Theme.apply_flat_button(button)
	return button


func set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	add_theme_stylebox_override("panel", Win10Theme.window_panel(active))
	var color := Win10Theme.TITLE_TEXT if active else Win10Theme.TITLE_TEXT_INACTIVE
	if is_instance_valid(_title_label):
		_title_label.add_theme_color_override("font_color", color)


func set_maximized(value: bool) -> void:
	if value == is_maximized:
		return
	is_maximized = value
	if value:
		_restore_rect = Rect2(position, size)
		var area := _desktop_area()
		position = area.position
		size = area.size
	else:
		if _restore_rect.size.x > 0.0:
			position = _restore_rect.position
			size = _restore_rect.size
	if is_instance_valid(_max_button):
		_max_button.text = "\u2750" if value else "\u25a1"
		_max_button.tooltip_text = "Restore" if value else "Maximize"
	maximized_changed.emit(self, value)
	force_layout()
	report_moved()


func toggle_maximize() -> void:
	set_maximized(not is_maximized)


# --- Title-bar button geometry (canvas space, same as desktop icons) -------
# kind: "minimize", "maximize" or "close".

## Returns the title-bar Button itself, or null when unknown/missing.
func get_window_button(kind: String) -> Button:
	var node_name := ""
	match kind.to_lower().lstrip("_").trim_suffix("button"):
		"minimize":
			node_name = "MinimizeButton"
		"maximize":
			node_name = "MaximizeButton"
		"close":
			node_name = "CloseButton"
		_:
			return null
	if not _built:
		return null
	return get_node_or_null("Layout/TitleBar/Bar/" + node_name) as Button


## Screen-space rect of a title-bar button. Empty rect when it does not exist.
func get_window_button_rect(kind: String) -> Rect2:
	var button := get_window_button(kind)
	if not is_instance_valid(button):
		return Rect2()
	return button.get_global_rect()


## Screen-space center of a title-bar button, Vector2.INF when it does not exist.
func get_window_button_position(kind: String) -> Vector2:
	var button := get_window_button(kind)
	if not is_instance_valid(button):
		return Vector2.INF
	return button.get_global_rect().get_center()


## Forces container layout immediately, so geometry queries (button rects,
## close position) are correct in the same frame the window was created,
## moved, resized or maximized. Containers normally sort on the next frame.
func force_layout() -> void:
	if not _built:
		return
	notification(Control.NOTIFICATION_RESIZED)
	_force_container_layout(self)


func _force_container_layout(node: Node) -> void:
	for child in node.get_children():
		if child is Container:
			(child as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
		_force_container_layout(child)


func minimize() -> void:
	if not visible or _closing:
		return
	if _visibility_tween:
		_visibility_tween.kill()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_visibility_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		minimized.emit(self)
	)


func restore() -> void:
	if _closing:
		return
	# Only a window that was actually hidden counts as restored.
	var was_hidden := not visible
	if _visibility_tween:
		_visibility_tween.kill()
	visible = true
	modulate.a = 0.0
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	if was_hidden:
		restored.emit(self)


func request_close() -> void:
	if _closing:
		return
	_closing = true
	if _visibility_tween:
		_visibility_tween.kill()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	closed.emit(self)
	queue_free()


## Emits `moved` if the position changed since the last report. Safe to call
## often; used by the show/network layer to push window geometry.
func report_moved() -> void:
	if position.is_equal_approx(_last_reported_position):
		return
	_last_reported_position = position
	moved.emit(self, position)


func _desktop_area() -> Rect2:
	if desktop and desktop.has_method("desktop_rect"):
		return desktop.desktop_rect()
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func _clamp_position(target: Vector2) -> void:
	var area := _desktop_area()
	var max_pos := area.position + area.size - size
	target.x = clampf(target.x, area.position.x, maxf(area.position.x, max_pos.x))
	target.y = clampf(target.y, area.position.y, maxf(area.position.y, max_pos.y))
	position = target


func _in_resize_corner(global_mouse: Vector2) -> bool:
	var rect := get_global_rect()
	var corner := Rect2(rect.end - Vector2(RESIZE_CORNER, RESIZE_CORNER), Vector2(RESIZE_CORNER, RESIZE_CORNER))
	return corner.has_point(global_mouse)


func _on_titlebar_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if mouse.double_click:
		toggle_maximize()
		return
	if is_maximized:
		set_maximized(false)
		_drag_offset = Vector2(size.x * 0.5, TITLEBAR_HEIGHT * 0.5)
	else:
		_drag_offset = get_global_mouse_position() - global_position
	_dragging = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if visible and not _closing and get_global_rect().has_point(get_global_mouse_position()):
			focus_requested.emit(self)
			if _in_resize_corner(get_global_mouse_position()) and not is_maximized:
				_resizing = true
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_size = size

	if event is InputEventMouseMotion:
		var mouse_pos := get_global_mouse_position()
		if _dragging:
			_clamp_position(mouse_pos - _drag_offset)
		elif _resizing:
			var area := _desktop_area()
			var delta := mouse_pos - _resize_start_mouse
			var new_size := _resize_start_size + delta
			new_size.x = clampf(new_size.x, custom_minimum_size.x, maxf(custom_minimum_size.x, area.size.x - position.x))
			new_size.y = clampf(new_size.y, custom_minimum_size.y, maxf(custom_minimum_size.y, area.position.y + area.size.y - position.y))
			size = new_size
		elif visible and get_global_rect().has_point(mouse_pos):
			var in_corner := _in_resize_corner(mouse_pos) and not is_maximized
			if in_corner and not _corner_cursor:
				Input.set_default_cursor_shape(Input.CURSOR_BDIAGSIZE)
				_corner_cursor = true
			elif not in_corner and _corner_cursor:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				_corner_cursor = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var was_moving := _dragging or _resizing
		_dragging = false
		_resizing = false
		if was_moving:
			report_moved()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and _corner_cursor:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_corner_cursor = false
