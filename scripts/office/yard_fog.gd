class_name YardFog
extends Node3D

## Layered drifting mist banks in the mine yard beyond the north bay window.
## All planes sit strictly behind z = -6.0 so the window figure observation
## column (around z = -3.2) stays unobstructed.

const MIST_SHADER: Shader = preload("res://materials/shaders/yard_mist.gdshader")

const LAYER_SPECS: Array[Dictionary] = [
	{
		"name": "MistNear", "z": -7.5, "y": 1.35, "w": 26.0, "h": 3.4,
		"density": 0.20, "speed": 0.015, "scale": 2.6, "phase": 0.4,
	},
	{
		"name": "MistRails", "z": -16.5, "y": 2.15, "w": 46.0, "h": 5.2,
		"density": 0.24, "speed": -0.010, "scale": 2.1, "phase": 2.1,
	},
	{
		"name": "MistHeadframe", "z": -34.0, "y": 3.8, "w": 84.0, "h": 9.5,
		"density": 0.28, "speed": 0.007, "scale": 1.8, "phase": 4.7,
	},
	{
		"name": "MistValley", "z": -62.0, "y": 6.0, "w": 150.0, "h": 15.0,
		"density": 0.30, "speed": 0.004, "scale": 1.4, "phase": 7.3,
	},
]

@export var moon_weather: MoonWeather = null

var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if moon_weather == null and get_parent() != null:
		moon_weather = get_parent().get_node_or_null("MoonWeather") as MoonWeather
	_build_layers()
	_sync_weather()

func _build_layers() -> void:
	if not _materials.is_empty():
		return
	for spec in LAYER_SPECS:
		var mi := MeshInstance3D.new()
		mi.name = String(spec["name"])
		var quad := QuadMesh.new()
		quad.size = Vector2(float(spec["w"]), float(spec["h"]))
		mi.mesh = quad
		mi.position = Vector3(-1.5, float(spec["y"]), float(spec["z"]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var mat := ShaderMaterial.new()
		mat.shader = MIST_SHADER
		mat.set_shader_parameter("density", float(spec["density"]))
		mat.set_shader_parameter("drift_speed", float(spec["speed"]))
		mat.set_shader_parameter("noise_scale", float(spec["scale"]))
		mat.set_shader_parameter("phase_offset", float(spec["phase"]))
		mi.material_override = mat
		add_child(mi)
		_materials.append(mat)

func _process(_delta: float) -> void:
	_sync_weather()

func _sync_weather() -> void:
	var dawn_val := moon_weather.dawn if moon_weather != null else 0.0
	var dim_val := moon_weather.dim if moon_weather != null else 0.0
	for mat in _materials:
		mat.set_shader_parameter("dawn_amount", dawn_val)
		mat.set_shader_parameter("moon_dim", dim_val)

func get_layer_count() -> int:
	return _materials.size()

func get_layer_materials() -> Array[ShaderMaterial]:
	return _materials
