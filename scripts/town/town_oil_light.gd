class_name TownOilLight
extends Node3D

const LANTERN := preload("res://assets/models/town/black_creek_oil_lantern.glb")
const BRACKET := preload("res://assets/models/town/black_creek_lantern_bracket.glb")
const CHAMBERSTICK := preload("res://assets/models/town/black_creek_chamberstick.glb")

var _lamp: OmniLight3D
var _flame: MeshInstance3D
var _energy: float
var _scale: float = 1.0
var _time: float

static func mount(parent: Node3D, at: Vector3, yaw: float, energy: float, reach: float) -> TownOilLight:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation_degrees.y = yaw
	parent.add_child(holder)
	holder.add_child(BRACKET.instantiate())
	return cage(holder, Vector3(0, -0.415, -0.302), energy, reach)

static func cage(parent: Node3D, at: Vector3, energy: float, reach: float) -> TownOilLight:
	var fixture := Node3D.new()
	fixture.position = at
	parent.add_child(fixture)
	var lantern := LANTERN.instantiate() as Node3D
	fixture.add_child(lantern)
	# The flame does not cast a large shadow from its own tiny cage or fount.
	for mesh: MeshInstance3D in lantern.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return wick(fixture, Vector3(0, 0.119, 0), energy, reach)

static func wick(parent: Node3D, at: Vector3, energy: float, reach: float) -> TownOilLight:
	var source := TownOilLight.new()
	source.position = at
	source._energy = energy
	parent.add_child(source)
	source._build(reach)
	return source

func _build(reach: float) -> void:
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.72, 0.43)
	_lamp.light_energy = _energy
	_lamp.light_size = 0.072
	_lamp.omni_range = reach
	_lamp.omni_attenuation = 1.36
	_lamp.shadow_enabled = true
	_lamp.shadow_blur = 1.7
	_lamp.shadow_bias = 0.055
	add_child(_lamp)
	_flame = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.012
	shape.height = 0.042
	shape.radial_segments = 7
	shape.rings = 4
	_flame.mesh = shape
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.76, 0.40)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.53, 0.16)
	glow.emission_energy_multiplier = 1.05
	_flame.material_override = glow
	add_child(_flame)
	_time = absf(position.x * 1.7 + position.y * 0.61)

## Adjusts overall lamp intensity while keeping subtle warm interior bounce intact.
func set_intensity_scale(scale: float) -> void:
	_scale = clampf(scale, 0.0, 1.5)
	if _lamp != null:
		_lamp.light_energy = _energy * _scale
	if _flame != null:
		_flame.visible = _scale > 0.55

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _lamp == null:
		return
	_time += delta
	var drift := sin(_time * 7.1) * 0.041 + sin(_time * 12.7 + 0.7) * 0.028 + sin(_time * 2.9) * 0.024
	var base := _energy * _scale
	_lamp.light_energy = base * (1.0 + drift)
	if _flame != null and _flame.visible:
		_flame.scale.y = 1.0 + drift * 2.7
		_flame.rotation.z = sin(_time * 6.2) * 0.13
