extends Node
class_name DesktopSync

@export var desktop: Windows10Desktop

func init_client():
	self.desktop.window_opened.connect(self._on_desktop_window_opened)
	self.desktop.window_focused.connect(self._on_desktop_window_focused)
	self.desktop.start_menu_toggled.connect(self._on_desktop_start_menu_toggled)

func _on_desktop_window_opened(window: DesktopWindow):
	window.closed.connect(self._on_window_closed)
	# window.focus_requested.connect(_on_window_focus_requested)
	window.minimized.connect(self._on_window_minimized)
	window.restored.connect(self._on_window_restored)
	window.title_changed.connect(self._on_window_title_changed)
	window.maximized_changed.connect(self._on_window_maximized_changed)
	window.position_changed.connect(self._on_window_position_changed)
	
	if window is ExplorerWindow:
		window.navigated.connect(func(path: String): _on_explorer_navigated_to(window, path))
	if _online() and window is ExplorerWindow:
		rpc(
			"command_open_window",
			"explorer",
			{ "path": window.folder_path },
			window.window_id,
			window.position, 
			window.size
		)



############################
## Desktop handlers
############################

func _on_desktop_window_focused(window: DesktopWindow):
	if _online():
		rpc("command_window_focus", window.window_id)

func _on_desktop_start_menu_toggled(opened: bool):
	if !_online():
		return
	if opened:
		rpc("command_start_menu_open")
	else:
		rpc("command_start_menu_close")


############################
## Explorer handlers
############################

func _on_explorer_navigated_to(window: ExplorerWindow, path: String):
	if _online():
		rpc("command_explorer_window_navigate", window.window_id, path)


############################
## Window handlers
############################

func _on_window_closed(window: DesktopWindow):
	if _online():
		rpc("command_close", window.window_id)

func _on_window_minimized(window: DesktopWindow):
	if _online():
		rpc("command_set_minimized", window.window_id)

func _on_window_restored(window: DesktopWindow):
	if _online():
		rpc("command_restore_window", window.window_id)

func _on_window_title_changed(window: DesktopWindow, new_title: String):
	if _online():
		rpc("command_set_title", window.window_id, new_title)

func _on_window_maximized_changed(window: DesktopWindow, value: bool):
	if _online():
		rpc("command_set_maximized", window.window_id, value)

func _on_window_position_changed(window: DesktopWindow, new_position: Vector2):
	if _online():
		rpc("command_set_rect", window.window_id, new_position, window.size)


##################################
## Window creation rootines
##################################
var window_kinds := {
	"explorer": func(payload: Dictionary, window_id: int, position: Vector2, size: Vector2) -> DesktopWindow:
		var window := self.desktop.open_folder(payload["path"], [], position, window_id)
		window.size = size
		return window
}

##################################
## RPC commands
##################################

@rpc("any_peer", "call_remote", "reliable")
func command_start_menu_open():
	self.desktop.open_start_menu()

@rpc("any_peer", "call_remote", "reliable")
func command_start_menu_close():
	self.desktop.close_start_menu()

@rpc("any_peer", "call_remote", "reliable")
func command_open_window(kind: String, payload: Dictionary, window_id: int, position: Vector2, size: Vector2):
	self.window_kinds[kind].call(payload, window_id, position, size)

@rpc("any_peer", "call_remote", "reliable")
func command_explorer_window_navigate(window_id: int, navigated_to: String):
	var window := _window(window_id)
	if window is ExplorerWindow:
		window.navigate_to(navigated_to)

@rpc("any_peer", "call_remote", "reliable")
func command_set_minimized(window_id: int):
	var window := _window(window_id)
	if window:
		window.minimize()

@rpc("any_peer", "call_remote", "reliable")
func command_set_maximized(window_id: int, value: bool):
	var window := _window(window_id)
	if window:
		window.set_maximized(value)

@rpc("any_peer", "call_remote", "reliable")
func command_set_title(window_id: int, new_title: String):
	var window := _window(window_id)
	if window:
		window.window_title = new_title

@rpc("any_peer", "call_remote", "reliable")
func command_set_rect(window_id: int, position: Vector2, size: Vector2):
	var window := _window(window_id)
	if window == null:
		return
	window.position = position
	window.size = size
	window.report_moved()

@rpc("any_peer", "call_remote", "reliable")
func command_restore_window(window_id: int):
	var window := _window(window_id)
	if window:
		window.restore()

@rpc("any_peer", "call_remote", "reliable")
func command_window_focus(window_id: int):
	var window := _window(window_id)
	if window:
		self.desktop.focus_window(window)

@rpc("any_peer", "call_remote", "reliable")
func command_close(window_id: int):
	var window := _window(window_id)
	if window:
		desktop.close_window(window)

########################################
## Helpers
########################################

func _window(window_id) -> DesktopWindow:
	return self.desktop.get_window_by_id(window_id)

func _online() -> bool:
	return multiplayer.has_multiplayer_peer()
