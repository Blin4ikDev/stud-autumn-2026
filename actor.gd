extends Node

var joy: int
var x_velocity: float
var action_triggered: bool

signal trigger_action()

func _ready():
	joy = 0
	x_velocity = 0.0
	action_triggered = false

func bind(joy: int):
	self.joy = joy

func _physics_process(_delta: float) -> void:
	self.x_velocity = Input.get_joy_axis(self.joy, JOY_AXIS_LEFT_X)
	if abs(self.x_velocity) < 0.18:
		self.x_velocity = 0
	
	var is_button_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if is_button_pressed and not action_triggered:
		trigger_action.emit()
		action_triggered = true
		print("Triggering action!")
	elif not is_button_pressed:
		action_triggered = false
