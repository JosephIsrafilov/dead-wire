class_name BoardingHouseCommon
extends Node3D

signal common_interactable_triggered(id: StringName)

const MODEL := preload("res://assets/models/town/hargrove_common_1890.glb")
const FIREPLACE_MODEL := preload("res://assets/models/town/hargrove_fireplace.glb")
const SETTEE_MODEL := preload("res://assets/models/town/hargrove_victorian_settee.glb")
const ARMCHAIR_MODEL := preload("res://assets/models/town/hargrove_victorian_armchair.glb")
const PARLOR_TABLE_MODEL := preload("res://assets/models/town/hargrove_parlor_table.glb")
const DINING_TABLE_MODEL := preload("res://assets/models/town/hargrove_dining_table.glb")
const CHINA_HUTCH_MODEL := preload("res://assets/models/town/hargrove_china_hutch.glb")
const COOKSTOVE_MODEL := preload("res://assets/models/town/hargrove_cookstove.glb")
const RECEPTION_PROPS_MODEL := preload("res://assets/models/town/hargrove_reception_props.glb")

const PH_TABLE_SCENE := preload("res://scenes/props/m1/ph_table.tscn")
const PH_CHAIR_SCENE := preload("res://scenes/props/m1/ph_chair.tscn")
const PH_VOLUMES_SCENE := preload("res://scenes/props/m1/ph_ledger_volumes.tscn")
const COAT_MODEL := preload("res://assets/models/office_props_v1/coat_tailored.glb")

const STOVE_MESH := preload("res://assets/models/stove_v1/stove_static.res")
const CHAIR_MESH := preload("res://assets/models/office_props_v1/chair_static.res")
const BOOKCASE_MESH := preload("res://assets/models/office_furniture_v1/bookcase_static.res")
const CABINET_MESH := preload("res://assets/models/office_furniture_v1/cabinet_static.res")
const CLOCK_CASE_MESH := preload("res://assets/models/office_props_v1/clock_static.res")
const CLOCK_DIAL_MAT := preload("res://materials/style_tests/clock_dial.tres")
const OIL_LAMP_MESH := preload("res://assets/models/office_props_v1/oil_lamp_static.res")
const LAMP_GLASS_MESH := preload("res://assets/models/office_props_v1/lamp_glass_static.res")
const INK_BOTTLE_MESH := preload("res://assets/models/office_props_v1/ink_bottle.res")
const TIN_CUP_MESH := preload("res://assets/models/office_props_v1/tin_cup.res")
const WALL_FRAME_MESH := preload("res://assets/models/office_props_v1/division_map_frame_static.res")
const EMBER_TEX := preload("res://assets/textures/office_surfaces/ember_coals.png")

const PERIOD_PRINT := preload("res://scripts/town/period_print_surface.gd")
const PRINT_PATH := "res://assets/textures/town_v2/print/"
const FONT := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const UPPER := 2.71
const ROOM_ANCHOR := Vector3(2.17, UPPER, -2.20)
const ENTRY := Vector3(-1.46, 0.035, -3.72)

var _common_interactables: Dictionary = {}

func build() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	_build_architecture_colliders()
	_build_furniture_and_colliders()
	_build_wall_dressing()
	_build_lights()
	_build_interactables()
	BoardingMaterialLibrary.apply_recursive(model)
	refresh_locale()

func _build_architecture_colliders() -> void:
	# Ground floor & Kitchen slabs
	_floor(-3.87, 3.87, -4.24, 4.24, 0.0, true)
	_floor(-3.84, -0.10, 4.20, 6.82, -0.13)

	# Second floor slabs leaving exact stairwell opening: x in [-0.85,+0.35], z in [-0.85,+3.00]
	_floor(-3.85, 3.85, 3.00, 4.24, UPPER, true)
	_floor(-3.85, -0.85, -4.24, 3.00, UPPER)
	_floor(0.35, 3.85, -4.24, 3.00, UPPER)
	_floor(-0.85, 0.35, -4.24, -0.85, UPPER)

	# Stair treads ascending from z = -0.85 (y=0) south to z = +3.00 (y=2.71)
	var steps_n := 16
	var step_d := 3.85 / float(steps_n)
	for i in range(steps_n):
		var top := (i + 1) * UPPER / float(steps_n)
		_box(Vector3(-0.25, top - 0.085, -0.85 + (float(i) + 0.5) * step_d),
			Vector3(1.18, 0.17, step_d + 0.015), true)
	for x in [-0.84, 0.34]:
		_box(Vector3(x, 3.13, 1.075), Vector3(0.08, 0.84, 3.85))
		for i in range(steps_n):
			var top := (i + 1) * UPPER / float(steps_n)
			_box(Vector3(x, top + 0.22, -0.85 + (float(i) + 0.5) * step_d),
				Vector3(0.075, 0.82, step_d + 0.015))
	_box(Vector3(-0.25, 3.13, -0.84), Vector3(1.22, 0.84, 0.08))

	# Perimeter walls (Godot z = -Blender y)
	for x in [-3.95, 3.95]:
		_box(Vector3(x, 2.68, 0), Vector3(0.15, 5.36, 8.60))
	_box(Vector3(0, 2.68, -4.30), Vector3(7.90, 5.36, 0.15))
	_wall_x(-3.95, -2.41, 4.30, 0.0, UPPER)
	_wall_x(-1.31, 3.95, 4.30, 0.0, UPPER)
	_wall_x(-2.41, -1.31, 4.30, 2.28, UPPER)
	_wall_x(-3.95, 3.95, 4.30, UPPER, 5.33)
	for x in [-3.84, -0.10]:
		_box(Vector3(x, 0.96, 5.56), Vector3(0.15, 2.18, 2.54))
	_box(Vector3(-1.97, 0.97, 6.82), Vector3(3.74, 2.20, 0.15))

	# Stairwell side cheek walls + open colonnade pillars
	_wall_y(-0.85, 3.00, -0.88, 0, 2.61)
	_wall_y(-0.85, 3.00, 0.38, 0, 2.61)
	for col_pos in [Vector3(0.45, 1.305, -1.17), Vector3(0.45, 1.305, -4.12),
			Vector3(-0.95, 1.305, -1.17), Vector3(-0.95, 1.305, -4.12)]:
		_box(col_pos, Vector3(0.18, 2.61, 0.20))

	# Upstairs partition walls
	_wall_y(-4.24, -0.10, 0.43, UPPER, 5.33)
	_wall_y(0.70, 4.24, 2.55, UPPER, 5.33)
	_wall_x(2.55, 3.85, 0.70, UPPER, 5.33)
	_wall_y(-4.24, 4.24, -1.68, UPPER, 5.33)

func _build_furniture_and_colliders() -> void:
	# Entry foyer console table (Poly Haven) + open register/bell/keys/valise
	var console := _place_scene(PH_TABLE_SCENE, Vector3(-0.30, 0.0, -3.96), 0.0, Vector3(0.84, 0.96, 0.60))
	if console != null:
		_box(Vector3(-0.30, 0.40, -3.96), Vector3(0.96, 0.80, 0.44))
	_place_hero(RECEPTION_PROPS_MODEL, Vector3(-0.30, 0.768, -3.96))
	_place_mesh(INK_BOTTLE_MESH, Vector3(-0.02, 0.768, -3.91), -15.0)
	var reg_tex := _print_tex("notebook")
	if reg_tex != null:
		PERIOD_PRINT.place(self, "GuestRegisterPages", Vector3(-0.32, 0.806, -3.96),
			Vector2(0.32, 0.23), reg_tex, Vector3(-90.0, 0.0, 0.0), 0.002)

	# Tailored wool coat hanging on entry west peg rail (y = 1.65 -> collar ~1.985)
	_place_glb(COAT_MODEL, Vector3(-3.70, -0.33, -3.65), -90.0)

	# West Parlor: fireplace + mirror, tufted velvet settee, wingback armchair, round table, bookcase
	_place_hero(FIREPLACE_MODEL, Vector3(-3.62, 0.0, -0.85))
	_box(Vector3(-3.55, 1.05, -0.85), Vector3(0.56, 2.10, 1.48))
	_place_hero(SETTEE_MODEL, Vector3(-1.30, 0.0, -0.85))
	_box(Vector3(-1.30, 0.45, -0.85), Vector3(0.56, 0.90, 1.42))
	_place_hero(ARMCHAIR_MODEL, Vector3(-3.30, 0.0, -2.35), -48.0)
	_box(Vector3(-3.30, 0.43, -2.35), Vector3(0.56, 0.92, 0.56))
	_place_hero(PARLOR_TABLE_MODEL, Vector3(-1.38, 0.0, 0.42))
	_box(Vector3(-1.38, 0.37, 0.42), Vector3(0.68, 0.74, 0.68))

	# Real depot bookcase with encyclopedia volumes
	_place_mesh(BOOKCASE_MESH, Vector3(-3.66, 0.0, 2.55), 90.0)
	_box(Vector3(-3.60, 0.82, 2.55), Vector3(0.42, 1.64, 0.96))
	for shelf_y in [0.47, 0.87, 1.22]:
		_place_scene(PH_VOLUMES_SCENE, Vector3(-3.66, shelf_y, 2.40 + shelf_y * 0.14), 90.0)

	# East Dining Room: communal spread, 6 Windsor/farmhouse chairs, china hutch, potbelly stove
	_place_hero(DINING_TABLE_MODEL, Vector3(2.38, 0.0, -0.65))
	_box(Vector3(2.38, 0.38, -0.65), Vector3(1.24, 0.76, 2.42))
	var row_idx := 0
	for cy in [-1.37, -0.65, 0.07]:
		var yaw_w := 90.0 + float((row_idx % 3) - 1) * 3.5
		var yaw_e := -90.0 - float(((row_idx + 1) % 3) - 1) * 4.0
		_place_mesh(CHAIR_MESH, Vector3(1.69, 0.0, cy), yaw_w)
		_place_mesh(CHAIR_MESH, Vector3(3.14, 0.0, cy), yaw_e)
		_box(Vector3(1.69, 0.43, cy), Vector3(0.38, 0.86, 0.38))
		_box(Vector3(3.14, 0.43, cy), Vector3(0.38, 0.86, 0.38))
		row_idx += 1
	_place_hero(CHINA_HUTCH_MODEL, Vector3(1.50, 0.0, 3.99)).scale = Vector3(0.68, 0.94, 0.86)
	_box(Vector3(1.50, 0.94, 3.99), Vector3(0.92, 1.88, 0.44))

	# Dining potbelly coal heater cleanly seated against south-east solid wall
	var stove := _place_mesh(STOVE_MESH, Vector3(3.38, 0.0, 1.62), 90.0, Vector3.ONE * 0.92)
	if stove != null:
		_add_stove_ember(stove)
	_box(Vector3(3.38, 0.46, 1.62), Vector3(0.66, 0.92, 0.64))

	# Rear Kitchen: cast-iron cookstove with copper kettle, prep table, pantry cabinet
	_place_hero(COOKSTOVE_MODEL, Vector3(-3.28, -0.13, 5.68))
	_box(Vector3(-3.28, 0.35, 5.68), Vector3(0.76, 0.96, 0.86))
	_place_scene(PH_TABLE_SCENE, Vector3(-2.12, -0.13, 6.36), 0.0, Vector3(1.05, 0.98, 0.68))
	_place_mesh(TIN_CUP_MESH, Vector3(-1.82, 0.654, 6.32), 22.0)
	_box(Vector3(-2.12, 0.27, 6.36), Vector3(1.22, 0.80, 0.52))
	_place_mesh(CABINET_MESH, Vector3(-0.42, -0.13, 5.40), -90.0)
	_box(Vector3(-0.42, 0.76, 5.40), Vector3(0.52, 1.78, 0.98))

	# Upstairs hallway window reading chair
	_place_scene(PH_CHAIR_SCENE, Vector3(-2.45, UPPER, 3.65), 156.0)
	_box(Vector3(-2.45, UPPER + 0.45, 3.65), Vector3(0.46, 0.90, 0.48))

func _build_wall_dressing() -> void:
	# Room plaques ("4" Room 4 open doorway; "1", "2", "3" knockable upstairs doors)
	for label_data in [
		["4", Vector3(2.49, 4.89, 0.21), 0.0],
		["1", Vector3(-1.02, 4.38, 3.45), 90.0],
		["2", Vector3(-1.02, 4.38, -2.25), 90.0],
		["3", Vector3(2.42, 4.38, 1.75), -90.0],
	]:
		var plaque := Label3D.new()
		plaque.text = label_data[0]
		plaque.font = FONT
		plaque.pixel_size = 0.0024
		plaque.modulate = Color(0.76, 0.60, 0.36)
		plaque.position = label_data[1]
		plaque.rotation_degrees.y = label_data[2]
		add_child(plaque)

	# Stairwell wall regulator clock facing east dining room
	var clk := _place_mesh(CLOCK_CASE_MESH, Vector3(0.47, 2.04, -0.15), 0.0)
	if clk != null:
		var dial := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.156
		cyl.bottom_radius = 0.156
		cyl.height = 0.012
		cyl.radial_segments = 16
		dial.mesh = cyl
		dial.material_override = CLOCK_DIAL_MAT
		dial.position = Vector3(0.10, 0.0, 0.0)
		dial.rotation_degrees = Vector3(0.0, 0.0, -90.0)
		clk.add_child(dial)

	# Period framed prints along solid wall piers (clear of every window)
	for spec in [
		["depot_notices", Vector3(-3.18, 1.62, -4.17), 0.0],
		["silver_spur", Vector3(3.82, 1.66, -0.55), -90.0],
		["western_union", Vector3(-3.12, 1.66, 4.17), 180.0],
		["chronicle", Vector3(1.30, 4.32, 4.17), 180.0],
	]:
		var frame := _place_mesh(WALL_FRAME_MESH, spec[1], spec[2], Vector3(0.68, 0.68, 0.68))
		var tex := _print_tex(spec[0])
		if frame != null and tex != null:
			PERIOD_PRINT.place(frame, "Print_" + spec[0], Vector3(0.0, 0.0, 0.022),
				Vector2(0.84, 0.56), tex, Vector3.ZERO, 0.0)

func _build_lights() -> void:
	# Solid-wall oil sconces ONLY (each bracket rotates INTO the room, never into the wall!)
	for mount_cfg in [
		[Vector3(-2.52, 1.92, -4.18), 180.0, 0.85, 5.2],   # Entry north pier -> +Z (clear of key rack)
		[Vector3(-3.84, 1.80, -1.65), -90.0, 0.85, 5.0],   # Parlor west pier -> +X
		[Vector3(3.84, 1.80, 0.45), 90.0, 0.85, 5.0],      # Dining east pier -> -X
		[Vector3(-0.18, 1.55, 5.55), 90.0, 0.72, 4.0],     # Kitchen east wall -> -X
		[Vector3(-0.25, 4.42, 4.18), 0.0, 0.82, 4.6],      # Upper south landing pier -> -Z
		[Vector3(1.02, 4.42, 0.02), 180.0, 0.82, 4.6],     # Upper hallway north pier -> +Z
	]:
		var lmp := TownOilLight.mount(self, mount_cfg[0], mount_cfg[1], mount_cfg[2], mount_cfg[3])
		lmp.add_to_group(&"boarding_lamp")
		if lmp.get_parent() != null:
			BoardingMaterialLibrary.apply_recursive(lmp.get_parent())

	# Warm hearth ember glow stays alive day & night ("hearth_ember_light")
	var hearth_glow := OmniLight3D.new()
	hearth_glow.position = Vector3(-3.26, 0.30, -0.85)
	hearth_glow.light_color = Color(0.96, 0.45, 0.16)
	hearth_glow.light_energy = 1.05
	hearth_glow.omni_range = 3.8
	hearth_glow.shadow_enabled = false
	hearth_glow.add_to_group(&"hearth_ember_light")
	add_child(hearth_glow)

	# Dining center chamberstick (sits cleanly on runner at y=0.771)
	var candle := Node3D.new()
	candle.position = Vector3(2.38, 0.771, -0.65)
	add_child(candle)
	var cstick := TownOilLight.CHAMBERSTICK.instantiate() as Node3D
	candle.add_child(cstick)
	BoardingMaterialLibrary.apply_recursive(cstick)
	TownOilLight.wick(candle, Vector3(0, 0.143, 0), 0.45, 3.4).add_to_group(&"boarding_lamp")

	# Parlor side-table depot brass oil lamp + glass chimney
	var parlor_lamp := Node3D.new()
	parlor_lamp.position = Vector3(-1.38, 0.728, 0.42)
	add_child(parlor_lamp)
	var lamp_body := _place_mesh_on(parlor_lamp, OIL_LAMP_MESH, Vector3.ZERO)
	lamp_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass := _place_mesh_on(parlor_lamp, LAMP_GLASS_MESH, Vector3.ZERO)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	TownOilLight.wick(parlor_lamp, Vector3(0.0, 0.185, 0.0), 0.65, 3.6).add_to_group(&"boarding_lamp")

func _build_interactables() -> void:
	_add_common_interactable(&"guest_register", Vector3(-0.32, 0.88, -3.97), Vector3(0.45, 0.25, 0.38))
	_add_common_interactable(&"room_1", Vector3(-1.08, 3.85, 3.45), Vector3(0.25, 1.9, 1.0))
	_add_common_interactable(&"room_2", Vector3(-1.08, 3.85, -2.25), Vector3(0.25, 1.9, 1.0))
	_add_common_interactable(&"room_3", Vector3(2.48, 3.85, 1.75), Vector3(0.25, 1.9, 1.0))

func _add_stove_ember(stove: MeshInstance3D) -> void:
	var coal_mat := StandardMaterial3D.new()
	coal_mat.albedo_color = Color(0.32, 0.22, 0.14, 1.0)
	coal_mat.albedo_texture = EMBER_TEX
	coal_mat.emission_enabled = true
	coal_mat.emission = Color(0.95, 0.20, 0.03, 1.0)
	coal_mat.emission_energy_multiplier = 2.4
	coal_mat.emission_texture = EMBER_TEX
	var slit := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(0.20, 0.09, 0.02)
	slit.mesh = quad
	slit.material_override = coal_mat
	slit.position = Vector3(0.0, 0.63, -0.325)
	stove.add_child(slit)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0.0, 0.63, -0.44)
	glow.light_color = Color(0.96, 0.42, 0.14)
	glow.light_energy = 0.48
	glow.omni_range = 2.2
	glow.shadow_enabled = false
	stove.add_child(glow)

func _place_hero(scene: PackedScene, at: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	inst.position = at
	inst.rotation_degrees.y = yaw_deg
	add_child(inst)
	BoardingMaterialLibrary.apply_recursive(inst)
	return inst

func _place_glb(scene: PackedScene, at: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	inst.position = at
	inst.rotation_degrees.y = yaw_deg
	add_child(inst)
	return inst

func _place_scene(scene: PackedScene, at: Vector3, yaw_deg: float = 0.0,
		scale_vec: Vector3 = Vector3.ONE) -> Node3D:
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	inst.position = at
	inst.rotation_degrees.y = yaw_deg
	inst.scale = scale_vec
	add_child(inst)
	return inst

func _place_mesh(mesh_res: Mesh, at: Vector3, yaw_deg: float = 0.0,
		scale_vec: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := _place_mesh_on(self, mesh_res, at)
	mi.rotation_degrees.y = yaw_deg
	mi.scale = scale_vec
	return mi

func _place_mesh_on(parent: Node3D, mesh_res: Mesh, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.position = at
	parent.add_child(mi)
	return mi

func _print_tex(stem: String) -> Texture2D:
	var path := PRINT_PATH + stem + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func get_common_interactable(id: StringName) -> Interactable:
	return _common_interactables.get(id) as Interactable

func refresh_locale() -> void:
	for id_key in _common_interactables:
		var act := _common_interactables[id_key] as Interactable
		if act == null:
			continue
		match id_key:
			&"guest_register":
				act.prompt_text = GameLocale.pick("Открыть книгу жильцов", "Read Guest Register")
			&"room_1":
				act.prompt_text = GameLocale.pick("Постучать в комнату № 1", "Knock on Room 1")
			&"room_2":
				act.prompt_text = GameLocale.pick("Постучать в комнату № 2", "Knock on Room 2")
			&"room_3":
				act.prompt_text = GameLocale.pick("Постучать в комнату № 3", "Knock on Room 3")

func _add_common_interactable(id: StringName, pos: Vector3, size: Vector3) -> void:
	var area := Interactable.new()
	area.name = String(id) + "_Interactable"
	area.collision_layer = 2
	area.collision_mask = 0
	area.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	area.interacted.connect(func() -> void: common_interactable_triggered.emit(id))
	add_child(area)
	_common_interactables[id] = area

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
