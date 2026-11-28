# studclub — interactive show background

Show: **«Студ Осень 2026»** (Stud Autumn 2026).

This project is an **interactive background for a live show**: a Windows 10 (dark)
desktop recreated with Godot UI nodes. Show code binds to the desktop root and drives
it (open folders, swap icons, recolor wallpaper, etc.).

## Main scene
`res://vibecoded/Windows-10-desktop.tscn` — root `Control` named `Windows-10-desktop`
(script: `res://vibecoded/scripts/windows_10_desktop.gd`, `class_name Windows10Desktop`).

Structure:
- `Wallpaper` — ColorRect with the procedural shader `vibecoded/assets/shaders/win10_wallpaper.gdshader`
- `DesktopIcons/IconFlow` — `VFlowContainer` of desktop shortcuts
- `WindowLayer` — runtime Explorer windows live here
- `Taskbar` — start, search, task view, app buttons, tray, live clock
- `StartMenu` — tiles + all-apps list (hidden by default)

Supporting scripts:
 - `vibecoded/scripts/desktop_window.gd` (`DesktopWindow`) — drag, minimize, maximize, close, resize corner
 - `vibecoded/scripts/explorer_window.gd` (`ExplorerWindow`) — navigation, sidebar, search filter
 - `vibecoded/scripts/win10_theme.gd` (`Win10Theme`) — shared dark styleboxes/helpers

UI style: **Windows 10 dark** from `res://themes/windows_10_dark/theme.tres`.
Do not modify the vendored theme; override styles in `Win10Theme` or per node.

## Show API (on the root node)
```gdscript
open_folder(path, items := [], window_position := Vector2.INF, window_id := 0) -> ExplorerWindow
  # path: String ("This PC/Documents") or Array of segments
  # items: optional Array of item dictionaries; also registers override
  # window_id: 0 = auto; pass take_window_id() when the window is created remotely
set_folder_items(path, items)      # replace one folder's contents
clear_folder_items(path)           # fall back to base filesystem
set_filesystem(tree)               # replace whole virtual FS {path: [items]}
get_folder_items(path) -> Array
set_desktop_icons(icons)           # [{name, path, icon}]
set_wallpaper_colors(top, bottom)
close_folder(path) / close_window(window) / close_all_windows()
restore_window(window) / focus_window(window)
minimize_all() / show_desktop()
open_start_menu() / close_start_menu() / toggle_start_menu() / is_start_menu_open()
get_open_folders() -> Array[String]
# window ids: stable identity, use them for RPC instead of NodePath
get_window_id(window) -> int        # 0 if not registered
get_window_by_id(window_id) -> DesktopWindow   # null if closed
get_windows() -> Array[DesktopWindow]
take_window_id() -> int             # reserve id for a window created on the peer
# desktop icon geometry (canvas space; use as walk-to targets)
get_desktop_icon_position(path_or_name) -> Vector2   # icon picture center, INF if missing
get_desktop_icon_rect(path_or_name) -> Rect2
find_desktop_icon(path_or_name) -> Dictionary       # {} if missing
get_desktop_icons() -> Array[Dictionary]            # {name, path, rect, center, icon_center, button}
get_desktop_icon_positions() -> Dictionary          # {path: Vector2}
activate_desktop_icon(path_or_name) -> bool         # open + select without a click
canvas_to_world(canvas_point, item) -> Vector2      # only for transformed 2D nodes
```

`open_folder()` returns the `ExplorerWindow`, so window chrome can be queried
directly (`kind` = `"minimize"`, `"maximize"` or `"close"`):

```gdscript
window.get_window_button_position(kind) -> Vector2  # center, INF if missing
window.get_window_button_rect(kind) -> Rect2
window.get_window_button(kind) -> Button
```

**Coordinate space:** icon geometry is in canvas space — the desktop's own
1152×648 design space (`canvas_items` stretch), origin top-left. A Camera2D does
not affect it, and `Node2D.global_position` uses the same space, so values work
directly as 2D walk targets. Use `canvas_to_world()` only when the 2D node has a
non-identity transform or sits under a `CanvasLayer`.
Signals on the desktop: `window_opened(window)`, `window_closed(window)`,
`window_focused(window)`, `start_menu_toggled(open)`.

Signals on windows (`DesktopWindow` / `ExplorerWindow`): `closed(window)`,
`focus_requested(window)`, `minimized(window)`, `restored(window)`,
`title_changed(window, title)`, `maximized_changed(window, maximized)`,
`moved(window, new_position)`, `navigated(path)`, `file_activated(file_path, item)`.

Item dictionary: `{"name", "type" ("folder"|"file"), "icon", "path"}`.
`path` is optional; when omitted it becomes `<current folder>/<name>`.
Icon names: `folder`, `this_pc`, `recycle_bin`, `documents`, `pictures`, `music`,
`videos`, `settings`, `file` (or pass a Texture2D in `icon`).

`@export open_icons_on_single_click` — false = authentic double-click; true = one click.

## Networking (host + tablet controller)

Two devices, one project. `scenes/Launch.tscn` picks a role, then loads the show
scene or the tablet control UI.

- **Host** (peer id 1) renders the show and runs `Windows-10-desktop`.
- **Tablet** (peer id 2) has its own UI and drives the show with touch.
- Transport: `ENetMultiplayerPeer` over LAN (`create_server(7777)` /
  `create_client(ip, 7777)`). ENet does not exist in web builds.

Authority split:
- **Desktop is host-authoritative.** The tablet sends commands (open folder,
  close window, start menu, desktop icons) as reliable `@rpc("any_peer")` calls to
  peer 1. The host executes them and pushes a light state snapshot back
  (open folders, focused window, icon list) for the tablet UI to render.
- The desktop scene is **not** replicated: the tablet UI is different, so no
  `MultiplayerSpawner`/`MultiplayerSynchronizer` on Explorer windows.
- **Sprites are tablet-authoritative.** On spawn the host calls
  `set_multiplayer_authority(2)`; a `MultiplayerSynchronizer` ticks
  `position`/`rotation`/`tint` at `replication_interval ≈ 1/30`. Simpler fallback:
  unreliable position RPC at 30 Hz, smoothing on the host.
- **Animations** sync as events, not frames: a reliable RPC sets the animation
  name (and start time); each side plays locally and resyncs on drift.

Open questions to test on venue Wi-Fi: packet loss, `replication_interval` coast,
and reconnect behaviour after a dropped tablet.

## Rules / gotchas
- Desktop file is generated by `/tmp/build_win10_scene.py` during this session. If
  regenerating externally, **close the scene tab first** (`scene_close`), then refresh
  and reopen — otherwise the editor's stale in-memory scene overwrites the file.
- Scripts edited while the game/editor holds stale buffers can be clobbered by the
  editor's save-before-run. Verify the file on disk; close the scene tab before
  regenerating. (Seen during initial build.)
- Theme fonts/assets live under `themes/windows_10_dark/assets/` (Segoe UI).
- Icons: `vibecoded/assets/icons/win10/*.svg` (64×64, displayed at 16/20/24/48 with linear filter).
- Renderer: Mobile, Godot 4.7, base viewport 1152×648 (stretches).

## Instancing under a Node2D
The root uses full-rect anchors. A `Control`/`CanvasLayer` parent provides the
rect; a `Node2D` parent does not, so on `_ready` the desktop sizes itself to the
viewport (`_fit_to_host`). It stays a plain Control child, so it moves/scales
with that Node2D — keep the Node2D at origin and scale 1 for accurate icon
positions.

# File ownership

Everything generated by goose lives in `vibecoded/`. This keeps AI code separate
from the user's code.

- Write new files only under `vibecoded/` (`vibecoded/scripts/`, `vibecoded/assets/`).
- Root `AGENTS.md` is the one exception — it is shared project documentation.
- Anything outside `vibecoded/` belongs to the user: do not edit or move it.
- When moving a `vibecoded/` file, update every `res://` reference to it.

# Response Length

Keep every response short. Default to under 10 lines.

- Lead with the answer. No preamble, no summary at the end.
- No walls of text. If a list grows past 5 items, cut it or use one line per item.
- No tables unless the user asks for a comparison.
- Skip explanations the user did not ask for. Offer more detail in one closing line.
- Long output belongs in a file, not in chat.
- Code blocks only for code the user asked to see.
