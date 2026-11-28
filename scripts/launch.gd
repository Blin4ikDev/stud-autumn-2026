extends Control
class_name Launch

@export var launch_ui: Control
@export var client_ui: Client
@export var scene: Node2D
@export var host_button: Button
@export var ip_address: LineEdit
@export var connect_button: Button
@export var port: int = 8080

func _ready():
	self.set_node_as_active(launch_ui, true)
	self.set_node_as_active(client_ui, false)
	self.set_node_as_active(scene, false)
	host_button.connect("pressed", host_session)
	connect_button.connect("pressed", func (): connect_to_session(ip_address.text))

var initialized: bool = false
var net: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

func host_session():
	if self.initialized:
		push_error("Connection is already initialized!")
		return
	
	var err := self.net.create_server(port, 1)
	if err != OK:
		push_error(error_string(err))
		return
	
	multiplayer.multiplayer_peer = self.net
	
	self.initialized = true
	self.launch_ui.hide()
	self.set_node_as_active(self.launch_ui, false)
	self.scene.show()
	self.set_node_as_active(self.scene, true)
func connect_to_session(ip: String):
	if self.initialized:
		push_error("Connection is already initialized!")
		return
	
	var err := self.net.create_client(ip, port)
	if err != OK:
		push_error(error_string(err))
		return
	
	multiplayer.multiplayer_peer = self.net
	
	self.initialized = true
	self.launch_ui.hide()
	self.set_node_as_active(self.launch_ui, false)
	self.scene.show()
	self.set_node_as_active(self.scene, true)
	self.client_ui.show()
	self.set_node_as_active(self.client_ui, true)
	
	self.client_ui.status_update(true, ip)
	$Scene/DesktopSync.init_client()



func set_node_as_active(node: Node, active: bool):
	node.set_process(active)
	node.set_physics_process(active)
	node.set_process_input(active)
	node.set_process_unhandled_input(active)



func fetch_scene():
	pass
