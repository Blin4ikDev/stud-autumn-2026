extends Control
## Demo: cycles through the planet types so you can see what the shader makes.
## Open shaders/pixel_planet.gdshader's material on the "Planet" node to play by hand.

const SEGMENTS := [
	{"name": "Terran", "type": 0, "seed": 3.0, "pixels": 64, "rings": false},
	{"name": "Desert", "type": 1, "seed": 11.0, "pixels": 64, "rings": false},
	{"name": "Ice", "type": 2, "seed": 5.0, "pixels": 64, "rings": false},
	{"name": "Lava", "type": 3, "seed": 8.0, "pixels": 64, "rings": false},
	{"name": "Gas giant + rings", "type": 4, "seed": 2.0, "pixels": 96, "rings": true},
	{"name": "Moon", "type": 5, "seed": 4.0, "pixels": 64, "rings": false},
]
const SEGMENT_TIME := 4.0

@onready var planet: ColorRect = $Planet
@onready var info: Label = $Info

var t := 0.0


func _process(delta: float) -> void:
	t += delta
	var s: Dictionary = SEGMENTS[int(t / SEGMENT_TIME) % SEGMENTS.size()]
	var mat := planet.material as ShaderMaterial
	mat.set_shader_parameter("planet_type", s["type"])
	mat.set_shader_parameter("seed", s["seed"])
	mat.set_shader_parameter("pixels", s["pixels"])
	mat.set_shader_parameter("rings", s["rings"])
	info.text = "%s  |  pixels %d  |  seed %.0f" % [s["name"], s["pixels"], s["seed"]]
