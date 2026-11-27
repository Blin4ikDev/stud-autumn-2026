class_name Puppet
extends CharacterBody2D


enum ActionState {
	DONE,
	PENDING
}

@abstract class Action:
	var id: String
	@abstract func do(puppet: Puppet, delta: float) -> ActionState

class MoveAction extends Action:
	var target: Vector2
	var speed_ms: float
	
	func _init(target: Vector2, speed_ms: float):
		self.target = target
		self.speed_ms = speed_ms
	func do(puppet: Puppet, delta: float) -> ActionState:
		if (target.distance_to(puppet.position) < speed_ms * delta * 1.1):
			puppet.sprite.animation = "idle"
			return ActionState.DONE
		
		var direction = (target - puppet.position).normalized()
		var sign_x = sign(direction.x)
		if sign_x == 0 or sign_x == 1:
			puppet.sprite.animation = "walk_right"
		elif sign_x == -1:
			puppet.sprite.animation = "walk_left"
		
		puppet.velocity = direction * self.speed_ms
		puppet.move_and_slide()
		
		return ActionState.PENDING

class JumpAction extends Action:
	var velocity: float
	var initial_velocity: float
	const G: float = 9.8
	
	func _init(initial_velocity: float):
		self.velocity = initial_velocity
		self.initial_velocity = initial_velocity
	func do(puppet: Puppet, delta: float) -> ActionState:
		puppet.velocity.x = 0
		if (abs(self.initial_velocity + self.velocity) <= 0.1):
			puppet.velocity.y = 0
			return ActionState.DONE
		
		self.velocity -= G * delta
		
		puppet.velocity.y = -self.velocity * 70.0
		puppet.move_and_slide()
		
		return ActionState.PENDING





signal action_done(id: String)



@export var sprite: AnimatedSprite2D
@export var chatbox: AnimatedSprite2D

var actions_queue: Array
var current_action: Action

func act(action: Action):
	self.actions_queue.push_back(action)

func _ready():
	sprite.play("idle")
	chatbox.play("default")

func _physics_process(delta: float) -> void:
	if self.current_action == null:
		self.current_action = self.actions_queue.pop_back()
	
	if self.current_action != null and self.current_action.do(self, delta) == ActionState.DONE:
		self.action_done.emit(self.current_action.id)
		self.current_action = null
