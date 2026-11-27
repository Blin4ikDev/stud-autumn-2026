extends Control
class_name InputRelay

@export var client_ui: Client

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		event.global_position
	elif event is InputEventScreenTouch:
		pass
