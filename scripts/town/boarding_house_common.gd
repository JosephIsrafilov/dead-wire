class_name BoardingHouseCommon
extends Node3D

const MODEL := preload("res://assets/models/town/hargrove_common_1890.glb")
const HALL_PLASTER := preload("res://materials/shaders/hargrove_hall_plaster.gdshader")
const FONT := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const UPPER := 2.71
const ROOM_ANCHOR := Vector3(2.17, UPPER, -2.20)
const ENTRY := Vector3(-1.46, 0.035, -3.83)

func build() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	var plaster := ShaderMaterial.new()
	plaster.shader = HALL_PLASTER
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(surface)
			if mat != null and mat.resource_name == "HallPlaster":
				mesh.set_surface_override_material(surface, plaster)
	_floor(-3.87, 3.87, -4.24, 4.24, 0.0)
	_floor(-3.84, -0.10, 4.24, 6.82, -0.13)
	_floor(-3.85, 3.85, 1.224, 4.24, UPPER, true)
	_floor(0.46, 3.85, 0.10, 1.224, UPPER)
	_floor(-3.85, -1.55, -4.24, 1.224, UPPER)
	_floor(-0.27, 0.46, -4.24, 1.224, UPPER)
	_floor(-1.55, -0.27, -4.24, -3.30, UPPER)
	for i in range(16):
		var top := (i + 1) * UPPER / 16.0
		_box(Vector3(-0.91, top - 0.085, -3.15 + i * 0.282), Vector3(1.28, 0.17, 0.283), true)
	for x in [-1.56, -0.26]:
		_box(Vector3(x, 3.13, -0.95), Vector3(0.09, 0.84, 4.21))
		for i in range(16):
			var top := (i + 1) * UPPER / 16.0
			_box(Vector3(x, top + 0.23, -3.15 + i * 0.282), Vector3(0.073, 0.82, 0.285))
	for x in [-3.95, 3.95]:
		_box(Vector3(x, 2.68, 0), Vector3(0.15, 5.36, 8.60))
	_box(Vector3(0, 2.68, -4.30), Vector3(7.90, 5.36, 0.15))
	# The exterior door is a scene transition, not a hole out of the level.
	_wall_x(-3.95, 3.95, 4.30, 0, UPPER)
	_wall_x(-3.95, 3.95, 4.30, UPPER, 5.33)
	_wall_y(-4.30, -3.805, -0.23, 0, 2.61)
	_wall_y(-2.495, 1.34, -0.23, 0, 2.61)
	_wall_x(-3.95, -3.105, -1.46, 0, 2.61)
	_wall_x(-1.955, -1.60, -1.46, 0, 2.61)
	_wall_x(-3.85, -1.55, 1.20, UPPER, 5.33)
	_wall_x(-3.85, 3.85, 2.28, UPPER, 5.33)
	_wall_y(-4.24, 0.10, 0.43, UPPER, 5.33)
	for x in [-3.84, -0.10]:
		_box(Vector3(x, 0.96, 5.56), Vector3(0.15, 2.18, 2.54))
	_box(Vector3(-1.97, 0.97, 6.82), Vector3(3.74, 2.20, 0.15))
	_box(Vector3(1.96, 0.38, -0.15), Vector3(1.47, 0.76, 2.45))
	for x in [0.89, 3.02]:
		_box(Vector3(x, 0.23, -0.15), Vector3(0.31, 0.46, 1.90))
	_box(Vector3(3.58, 0.42, -0.29), Vector3(0.62, 0.84, 0.61))
	_box(Vector3(-2.35, 0.35, 6.18), Vector3(2.76, 0.86, 0.59))
	for label_data in [["4", Vector3(2.49, 4.89, 0.21), 0.0],
			["2", Vector3(-2.56, 4.40, 1.09), 180.0], ["3", Vector3(-0.03, 4.40, 2.18), 180.0]]:
		var plaque := Label3D.new()
		plaque.text = label_data[0]
		plaque.font = FONT
		plaque.pixel_size = 0.0024
		plaque.modulate = Color(0.72, 0.57, 0.36)
		plaque.position = label_data[1]
		plaque.rotation_degrees.y = label_data[2]
		add_child(plaque)
	var entry_light := TownOilLight.mount(self, Vector3(-3.50, 1.67, -2.50), 90.0, 0.85, 4.7)
	entry_light.add_to_group(&"boarding_lamp")
	var hall_light := TownOilLight.mount(self, Vector3(1.08, 4.42, 0.19), 180.0, 0.88, 4.0)
	hall_light.add_to_group(&"boarding_lamp")
	var candle := Node3D.new()
	candle.position = Vector3(2.35, 0.79, -0.57)
	add_child(candle)
	candle.add_child(TownOilLight.CHAMBERSTICK.instantiate())
	TownOilLight.wick(candle, Vector3(0, 0.143, 0), 0.29, 2.55).add_to_group(&"boarding_lamp")

func _wall_x(a: float, b: float, z: float, low: float, high: float) -> void:
	_box(Vector3((a + b) * 0.5, (low + high) * 0.5, z), Vector3(b - a, high - low, 0.15))

func _wall_y(a: float, b: float, x: float, low: float, high: float) -> void:
	_box(Vector3(x, (low + high) * 0.5, (a + b) * 0.5), Vector3(0.15, high - low, b - a))

func _floor(x0: float, x1: float, z0: float, z1: float, top: float, tread: bool = false) -> void:
	_box(Vector3((x0 + x1) * 0.5, top - 0.045, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.09, z1 - z0), tread)

func _box(center: Vector3, size: Vector3, tread: bool = false) -> void:
	var body := StaticBody3D.new()
	body.position = center
	if tread:
		body.add_to_group(&"street_tread")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
