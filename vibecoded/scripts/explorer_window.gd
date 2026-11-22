class_name ExplorerWindow
extends DesktopWindow

## File Explorer style window. Navigation is driven by the desktop's
## virtual filesystem (see Windows10Desktop.get_folder_items).

const QUICK_ACCESS: Array[Dictionary] = [
	{"label": "Desktop", "path": "Desktop", "icon": "folder"},
	{"label": "Downloads", "path": "Downloads", "icon": "folder"},
	{"label": "Documents", "path": "Documents", "icon": "documents"},
	{"label": "Pictures", "path": "Pictures", "icon": "pictures"},
	{"label": "Music", "path": "Music", "icon": "music"},
	{"label": "Videos", "path": "Videos", "icon": "videos"},
	{"label": "", "path": "", "icon": ""},
	{"label": "This PC", "path": "This PC", "icon": "this_pc"},
	{"label": "Recycle Bin", "path": "Recycle Bin", "icon": "recycle_bin"},
]

var _address_label: Label
var _items_container: HFlowContainer
var _status_label: Label
var _scroll: ScrollContainer
var _search_field: LineEdit
var _back_button: Button
var _forward_button: Button
var _up_button: Button
var _history: Array[String] = []
var _history_index := -1
var _current_items: Array = []
var _filter := ""
var _item_group: ButtonGroup
var _last_item_button: Button = null
var _last_item_time := 0


func _build_content(root: Control) -> void:
	var layout := VBoxContainer.new()
	layout.name = "ExplorerLayout"
	layout.add_theme_constant_override("separation", 0)
	root.add_child(layout)

	layout.add_child(_build_toolbar())
	layout.add_child(_build_body())
	layout.add_child(_build_status_bar())

	_history = []
	_history_index = -1
	var initial := folder_path if not folder_path.is_empty() else "This PC"
	navigate_to(initial, false)


func _build_toolbar() -> Control:
	var toolbar := PanelContainer.new()
	toolbar.name = "Toolbar"
	toolbar.custom_minimum_size = Vector2(0, 42)
	toolbar.add_theme_stylebox_override("panel", Win10Theme.explorer_toolbar())

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.add_theme_constant_override("margin_top", 0)
	toolbar.add_child(bar)

	_back_button = _make_tool_button("\u2190", "Back")
	_back_button.pressed.connect(_go_back)
	bar.add_child(_back_button)

	_forward_button = _make_tool_button("\u2192", "Forward")
	_forward_button.pressed.connect(_go_forward)
	bar.add_child(_forward_button)

	_up_button = _make_tool_button("\u2191", "Up")
	_up_button.pressed.connect(_go_up)
	bar.add_child(_up_button)

	var refresh_button := _make_tool_button("\u21bb", "Refresh", 14)
	refresh_button.pressed.connect(func() -> void: navigate_to(folder_path, false))
	bar.add_child(refresh_button)

	var address := PanelContainer.new()
	address.name = "AddressBar"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	address.custom_minimum_size = Vector2(0, 28)
	address.add_theme_stylebox_override("panel", Win10Theme.address_bar())
	bar.add_child(address)

	_address_label = Label.new()
	_address_label.clip_text = true
	_address_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_address_label.add_theme_font_size_override("font_size", 12)
	address.add_child(_address_label)

	_search_field = LineEdit.new()
	_search_field.custom_minimum_size = Vector2(170, 28)
	_search_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_field.placeholder_text = "Search"
	_search_field.add_theme_font_size_override("font_size", 12)
	_search_field.add_theme_color_override("font_placeholder_color", Color("9a9a9a"))
	_search_field.add_theme_stylebox_override("normal", Win10Theme.address_bar())
	_search_field.add_theme_stylebox_override("focus", Win10Theme.flat(Color("1b1b1b"), Win10Theme.ACCENT, 1, 2, 0.0))
	_search_field.text_changed.connect(_on_search_changed)
	bar.add_child(_search_field)

	return toolbar


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)

	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(184, 0)
	sidebar.add_theme_stylebox_override("panel", Win10Theme.explorer_sidebar())
	body.add_child(sidebar)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 1)
	sidebar.add_child(nav)

	var header := Label.new()
	header.text = "Quick access"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("9a9a9a"))
	header.custom_minimum_size = Vector2(0, 26)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(header)

	for entry in QUICK_ACCESS:
		if str(entry["label"]).is_empty():
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 8)
			nav.add_child(spacer)
			continue
		var nav_button := _make_sidebar_button(str(entry["label"]), str(entry["path"]), str(entry["icon"]))
		nav.add_child(nav_button)

	var content := PanelContainer.new()
	content.name = "ContentPanel"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", Win10Theme.explorer_background())
	body.add_child(content)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)

	_items_container = HFlowContainer.new()
	_items_container.name = "Items"
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("h_separation", 4)
	_items_container.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_items_container)

	return body


func _build_status_bar() -> Control:
	var status := PanelContainer.new()
	status.name = "StatusBar"
	status.custom_minimum_size = Vector2(0, 24)
	status.add_theme_stylebox_override("panel", Win10Theme.explorer_status())

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color("a8a8a8"))
	status.add_child(_status_label)

	return status


func _make_tool_button(glyph: String, tip: String, font_size := 15) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tip
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(32, 28)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))
	Win10Theme.apply_flat_button(button)
	return button


func _make_sidebar_button(text: String, path: String, icon_name: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 28)
	button.tooltip_text = text
	Win10Theme.apply_flat_button(button)
	var texture: Texture2D = null
	if desktop and desktop.has_method("icon_texture"):
		texture = desktop.icon_texture(icon_name)
	Win10Theme.add_icon_label_row(button, texture, text, 12, 16.0, 4.0)
	button.pressed.connect(func() -> void: navigate_to(path))
	return button


func navigate_to(path: String, record := true) -> void:
	var normalized := _normalize(path)
	if normalized.is_empty():
		normalized = "This PC"

	if record:
		if _history_index + 1 < _history.size():
			_history.resize(_history_index + 1)
		if _history.is_empty() or _history[_history_index] != normalized:
			_history.append(normalized)
			_history_index = _history.size() - 1
	else:
		_history.clear()
		_history.append(normalized)
		_history_index = 0

	folder_path = normalized
	window_title = _display_name(normalized)
	_current_items = []
	if desktop and desktop.has_method("get_folder_items"):
		_current_items = desktop.get_folder_items(normalized)
	_rebuild_items()
	_update_address()
	_update_nav_buttons()

	if desktop and desktop.has_method("notify_folder_navigation"):
		desktop.notify_folder_navigation(self, normalized)


func _normalize(path: String) -> String:
	var value := path.strip_edges().replace("\\", "/")
	while value.contains("//"):
		value = value.replace("//", "/")
	return value.trim_suffix("/")


func _display_name(path: String) -> String:
	if path.is_empty():
		return "This PC"
	var parts := path.split("/", false)
	return str(parts[parts.size() - 1])


func _update_address() -> void:
	if is_instance_valid(_address_label):
		_address_label.text = folder_path.replace("/", "  \u203a  ")


func _update_nav_buttons() -> void:
	if is_instance_valid(_back_button):
		_back_button.disabled = _history_index <= 0
	if is_instance_valid(_forward_button):
		_forward_button.disabled = _history_index >= _history.size() - 1
	if is_instance_valid(_up_button):
		_up_button.disabled = folder_path.is_empty() or folder_path == "This PC"


func _rebuild_items() -> void:
	if not is_instance_valid(_items_container):
		return
	for child in _items_container.get_children():
		child.queue_free()

	_item_group = ButtonGroup.new()
	_item_group.allow_unpress = true

	var shown := 0
	for item in _current_items:
		if not item is Dictionary:
			continue
		var item_name := str(item.get("name", ""))
		if not _filter.is_empty() and not item_name.to_lower().contains(_filter):
			continue
		_items_container.add_child(_make_item_button(item))
		shown += 1

	if is_instance_valid(_status_label):
		_status_label.text = "1 item" if shown == 1 else "%d items" % shown


func _make_item_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 100)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = _item_group
	button.tooltip_text = str(item.get("name", ""))
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_theme_stylebox_override("normal", Win10Theme.item_normal())
	button.add_theme_stylebox_override("hover", Win10Theme.item_hover())
	button.add_theme_stylebox_override("pressed", Win10Theme.item_selected())
	button.add_theme_stylebox_override("hover_pressed", Win10Theme.item_selected())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if desktop and desktop.has_method("icon_texture"):
		icon.texture = desktop.icon_texture(item.get("icon", "folder"))
	box.add_child(icon)

	var label := Label.new()
	label.text = str(item.get("name", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(88, 30)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("ededed"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	button.pressed.connect(_on_item_pressed.bind(button, item))
	return button


func _on_item_pressed(button: Button, item: Dictionary) -> void:
	var single_click := false
	if desktop:
		single_click = bool(desktop.get("open_icons_on_single_click"))
	var now := Time.get_ticks_msec()
	if single_click or (_last_item_button == button and now - _last_item_time <= 400):
		_last_item_button = null
		button.set_pressed_no_signal(true)
		_activate_item(item)
	else:
		_last_item_button = button
		_last_item_time = now


func _activate_item(item: Dictionary) -> void:
	var resolved := _resolve_item_path(item)
	if str(item.get("type", "folder")) == "folder":
		navigate_to(resolved)
	elif desktop and desktop.has_method("notify_file_activated"):
		desktop.notify_file_activated(resolved, item.duplicate(true))


func _resolve_item_path(item: Dictionary) -> String:
	var explicit := str(item.get("path", "")).strip_edges()
	if not explicit.is_empty():
		return _normalize(explicit)
	return _normalize(folder_path.path_join(str(item.get("name", ""))))


func _on_search_changed(text: String) -> void:
	_filter = text.strip_edges().to_lower()
	_rebuild_items()


func _go_back() -> void:
	if _history_index <= 0:
		return
	_history_index -= 1
	navigate_to(_history[_history_index], false)
	_update_nav_buttons()


func _go_forward() -> void:
	if _history_index >= _history.size() - 1:
		return
	_history_index += 1
	navigate_to(_history[_history_index], false)
	_update_nav_buttons()


func _go_up() -> void:
	if folder_path.is_empty() or folder_path == "This PC":
		return
	var parts := folder_path.split("/", false)
	if parts.size() <= 1:
		navigate_to("This PC")
	else:
		var parent_parts := parts.slice(0, parts.size() - 1)
		navigate_to("/".join(parent_parts))
