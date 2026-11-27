extends Control
class_name Client

@export var open_folder_button: Button
@export var close_window_button: Button
@export var start_menu_button: Button
@export var show_desktop_button: Button
@export var zoom_in_button: Button
@export var zoom_out_button: Button
@export var zoom_value_label: Label
@export var zoom_reset_button: Button
@export var status_label: Label
@export var camera: Camera2D
@export var scene: Node2D

var zoom: float = 1.0
const ZOOM_MULTIPLIER: float = 1.25

var desktop: Windows10Desktop

func _ready():
	self.desktop = scene.get_node("Desktop")
	
	self.start_menu_button.connect("pressed", func(): self.desktop.open_start_menu())
	self.show_desktop_button.connect("pressed", func(): self.desktop.show_desktop())
	self.zoom_in_button.connect("pressed", func(): self.set_zoom(self.zoom * ZOOM_MULTIPLIER))
	self.zoom_out_button.connect("pressed", func(): self.set_zoom(self.zoom / ZOOM_MULTIPLIER))
	self.zoom_reset_button.connect("pressed", func(): self.set_zoom(1.0))
	
	self.status_update(false)
	self.set_zoom(1.0)

func set_zoom(zoom: float):
	self.zoom = zoom
	self.camera.zoom = Vector2(zoom, zoom)
	self.zoom_value_label.text = "%.0f" % (zoom * 100.0)

func status_update(connected: bool, to: String = ""):
	if !connected:
		self.status_label.text = "Не подключено"
	else:
		self.status_label.text = "Подключено: %s" % to
