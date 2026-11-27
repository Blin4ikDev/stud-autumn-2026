extends Button

## Collapses/expands the control panel, LibreOffice-style: a thin strip on the
## left edge of the panel. Attach to a Button placed just before the panel.

@export var panel_path: NodePath = ^"../MenuPanel"
@export var panel_tooltip_show := "Показать панель"
@export var panel_tooltip_hide := "Скрыть панель"

@onready var _panel: Control = get_node_or_null(panel_path) as Control


func _ready() -> void:
	_sync()
	pressed.connect(_toggle)


func _toggle() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	_sync()


func _sync() -> void:
	if _panel == null:
		return
	var shown := _panel.visible
	text = ">" if shown else "<"
	tooltip_text = panel_tooltip_hide if shown else panel_tooltip_show
