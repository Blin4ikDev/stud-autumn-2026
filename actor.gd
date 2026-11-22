class_name Actor
extends Node

@export var joy: int = 0
@export var axis: int = JOY_AXIS_LEFT_X
@export var action_button: int = JOY_BUTTON_B

var x_velocity: float = 0.0
var action_triggered: bool = false

signal trigger_action()

func bind_to_joy(joy: int):
	self.joy = joy

func _ready():
	self.x_velocity = 0.0
	self.action_triggered = false

func _physics_process(_delta: float) -> void:
	self.x_velocity = Input.get_joy_axis(self.joy, self.axis)
	if abs(self.x_velocity) < 0.18:
		self.x_velocity = 0
	
	var is_button_pressed = Input.is_key_pressed(KEY_W)
	if is_button_pressed and not self.action_triggered:
		trigger_action.emit()
		self.action_triggered = true
	elif not is_button_pressed:
		self.action_triggered = false
