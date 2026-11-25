class_name BoardingRoomBuilder
extends Node3D

## Places Room 4 in the north-east bay of Hargrove House, with a real window opening.
## Geometry comes from the same Blender plan as the exterior.

signal interactable_triggered(id: StringName)

const ROOM_SHELL := preload("res://assets/models/town/hargrove_room04_shell.glb")
const ROOM_DETAILS := preload("res://assets/models/town/hargrove_room04_details.glb")
const CHIMNEY_GLASS := preload("res://materials/shaders/hargrove_chimney_glass.gdshader")
const ROOM_DESK := preload("res://assets/models/town/hargrove_room04_desk.glb")
const BED_SCENE := preload("res://assets/models/town/room04_iron_bed.glb")
const WASHSTAND_SCENE := preload("res://assets/models/town/room04_washstand.glb")
const CHAIR_MESH := preload("res://assets/models/office_props_v1/chair_static.res")
const PERIOD_PRINT := preload("res://scripts/town/period_print_surface.gd")
const PRINT_PATH := "res://assets/textures/town_v2/print/"
const HILLSIDE := preload("res://scripts/town/black_creek_hillside.gd")

var _mats: Dictionary = {}
var _interactables: Dictionary = {}
var _desk_lamp_light: TownOilLight = null
var _vista_light: DirectionalLight3D

func build_room() -> void:
	if get_child_count() > 0:
		return
	_build_shell()
	add_child(ROOM_DETAILS.instantiate())
	_prop_collision(self, Vector3(-1.04, 0.21, 0.42), Vector3(0.83, 0.43, 0.40))
	_prop_collision(self, Vector3(0.84, 0.43, -0.02), Vector3(0.38, 0.86, 0.38))
	var stool := Vector3(0.01, 0.602, -1.79)
	_prop_collision(self, stool - Vector3.UP * 0.301, Vector3(0.42, 0.602, 0.36))
	var candle := TownOilLight.CHAMBERSTICK.instantiate() as Node3D
	candle.position = stool
	add_child(candle)
	_build_window_vista()
	_build_iron_bed()
	_build_washstand()
	_build_desk_and_notebook()
	_build_door_and_calendar()
	var chair := MeshInstance3D.new()
	chair.name = "DeskChair"
	chair.mesh = CHAIR_MESH
	chair.position = Vector3(0.84, 0.0, -0.02)
	chair.rotation_degrees.y = 95.0
	add_child(chair)
	BoardingMaterialLibrary.apply_recursive(self)
	refresh_locale()

func refresh_locale() -> void:
	for id_key in _interactables:
		var act := _interactables[id_key] as Interactable
		if act == null:
			continue
		match id_key:
			&"bed":
				act.prompt_text = GameLocale.pick("Лечь спать до полудня", "Sleep Until Morning")
			&"washstand":
				act.prompt_text = GameLocale.pick("Умыться холодной водой", "Wash Face at Basin")
			&"notebook":
				act.prompt_text = GameLocale.pick("Открыть тетрадь записей", "Read Case Notebook")
			&"calendar":
				act.prompt_text = GameLocale.pick("Посмотреть календарь (Апрель 1890)", "Inspect April 1890 Calendar")
			&"landlady_note":
				act.prompt_text = GameLocale.pick("Поднять записку под дверью", "Read Mrs. Hargrove's Note")

func set_room_day_mode(is_day: bool) -> void:
	if _desk_lamp_light != null:
		_desk_lamp_light.visible = not is_day
	if _vista_light != null:
		_vista_light.light_color = Color("ffe9cc") if is_day else Color("a2b6ce")
		_vista_light.light_energy = 1.0 if is_day else 0.34

func get_room_interactable(id: StringName) -> Interactable:
	return _interactables.get(id, null) as Interactable

func _solid(col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := "s|%s|%.2f|%.2f" % [col.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	_mats[key] = mat
	return mat

func _box(parent: Node3D, node_name: String, pos: Vector3, sz: Vector3, mat: Material,
		collide: bool = true, rot_deg: Vector3 = Vector3.ZERO) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.position = pos
	b.rotation_degrees = rot_deg
	b.size = sz
	b.material = mat
	b.use_collision = collide
	parent.add_child(b)
	return b

func _prop_collision(parent: Node3D, pos: Vector3, size: Vector3,
		surface: StringName = &"", box_group: StringName = &"") -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	if surface != &"":
		FootstepSurfaceResolver.tag(body, surface)
	if box_group != &"":
		body.add_to_group(box_group)

func _add_interactable(parent: Node3D, id: StringName, pos: Vector3, sz: Vector3) -> Interactable:
	var area := Interactable.new()
	area.name = String(id) + "_Interactable"
	area.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	area.add_child(cs)
	area.interacted.connect(func() -> void: interactable_triggered.emit(id))
	parent.add_child(area)
	_interactables[id] = area
	return area

func _build_shell() -> void:
	add_child(ROOM_SHELL.instantiate())
	# Phase B: the floorboards are the material the boots read in this room.
	_prop_collision(self, Vector3(0, -0.05, 0), Vector3(3.54, 0.10, 4.38), &"wood_office", &"footstep_floor")
	_prop_collision(self, Vector3(0, 2.66, 0), Vector3(3.54, 0.10, 4.38))
	# Glass does not block light, but the wall and sash still stop the capsule.
	for edge in [-1.0, 1.0]:
		_prop_collision(self, Vector3(edge * 1.68, 1.31, 0), Vector3(0.15, 2.62, 4.36))
	_prop_collision(self, Vector3(0, 1.31, -2.10), Vector3(3.36, 2.62, 0.15))
	_prop_collision(self, Vector3(-1.265, 1.31, 2.10), Vector3(0.83, 2.62, 0.15))
	_prop_collision(self, Vector3(0.975, 1.31, 2.10), Vector3(1.41, 2.62, 0.15))
	_prop_collision(self, Vector3(-0.29, 2.46, 2.10), Vector3(1.12, 0.32, 0.15))
	_prop_collision(self, Vector3(-0.87, 1.11, 1.56), Vector3(0.065, 2.22, 1.05))

func _build_window_vista() -> void:
	# The two sashes share one 3D vista, with real depth between roofs, trees and divide.
	var vista := Node3D.new()
	vista.name = "BlackCreekWindowVista"
	add_child(vista)
	HILLSIDE.build_ridge(vista, -110.0, 25.0)
	HILLSIDE.build_ridge(vista, 132.0, 29.0, true)
	for p: Vector3 in [Vector3(5.5, -5.6, -16.5), Vector3(16.5, -5.5, -14.5),
			Vector3(19.0, -5.6, 4.5), Vector3(-6.0, -5.5, -22.0)]:
		var cottage := HILLSIDE.COTTAGES[int(p.x > 10)].instantiate() as Node3D
		cottage.position = p
		cottage.rotation.y = 0.18 if p.x < 10 else -0.24
		vista.add_child(cottage)
	for p: Vector3 in [Vector3(-4, 0.92, -16), Vector3(2.4, 1.12, -23), Vector3(7, 1.05, -19),
			Vector3(10.5, 1.18, -5.0), Vector3(13, 0.95, -15), Vector3(15.5, 1.16, -2.5),
			Vector3(18, 0.96, 1.8), Vector3(23, 1.08, -7.0), Vector3(-10, 0.95, -25),
			Vector3(11, 0.88, -30), Vector3(24, 1.05, -23), Vector3(7.5, 1.24, 3.2)]:
		var tree := HILLSIDE.SPRUCE.instantiate() as Node3D
		tree.position = Vector3(p.x, -4.5, p.z)
		tree.scale = Vector3.ONE * p.y
		tree.rotation.y = p.x * 0.31
		vista.add_child(tree)
	var ground := _solid(Color("52593e"), 0.98)
	_box(vista, "Valley floor", Vector3(10, -4.46, -10), Vector3(180, 0.2, 170), ground, false)
	# Room lights are aimed in through the sashes; exterior light is isolated to the vista.
	for mesh: GeometryInstance3D in vista.find_children("*", "GeometryInstance3D", true, false):
		mesh.layers = 4
	var daylight := DirectionalLight3D.new()
	daylight.name = "Vista daylight"
	daylight.rotation_degrees = Vector3(-38, -27, 0)
	daylight.light_cull_mask = 4
	vista.add_child(daylight)
	_vista_light = daylight

func _build_iron_bed() -> void:
	var bed := Node3D.new()
	bed.name = "IronSpoolBed"
	bed.position = Vector3(-1.00, 0.0, -0.91)
	add_child(bed)
	bed.add_child(BED_SCENE.instantiate())
	_prop_collision(bed, Vector3(0.0, 0.27, 0.0), Vector3(1.23, 0.54, 2.02))
	_add_interactable(bed, &"bed", Vector3(0.0, 0.65, 0.0), Vector3(1.4, 1.0, 2.1))

func _build_washstand() -> void:
	var ws := Node3D.new()
	ws.name = "OakWashstand"
	ws.position = Vector3(1.22, 0.0, 1.63)
	add_child(ws)
	ws.add_child(WASHSTAND_SCENE.instantiate())
	_prop_collision(ws, Vector3(0.0, 0.42, 0.0), Vector3(0.77, 0.84, 0.57))
	_add_interactable(ws, &"washstand", Vector3(0.0, 0.90, 0.0), Vector3(0.9, 1.1, 0.75))

func _build_desk_and_notebook() -> void:
	var desk := Node3D.new()
	desk.name = "WritingDesk"
	desk.position = Vector3(1.25, 0.0, -0.70)
	add_child(desk)
	var model := ROOM_DESK.instantiate() as Node3D
	desk.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == &"KeroseneBurner" or mesh.name == &"KeroseneChimney":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name == &"KeroseneChimney":
			var glass := ShaderMaterial.new()
			glass.shader = CHIMNEY_GLASS
			mesh.material_override = glass
	_prop_collision(desk, Vector3(0.0, 0.37, 0.0), Vector3(0.64, 0.75, 1.09))
	var leather := _solid(Color(0.26, 0.16, 0.11), 0.76)
	var paper := _solid(Color(0.73, 0.64, 0.46), 0.92)

	_desk_lamp_light = TownOilLight.wick(desk, Vector3(0.146, 0.946, -0.37), 0.92, 4.7)

	# Open Case Notebook + silver coin saucer
	_box(desk, "NotebookCover", Vector3(0.05, 0.77, 0.05), Vector3(0.30, 0.02, 0.36), leather, false,
		Vector3(0.0, 12.0, 0.0))
	_box(desk, "NotebookPages", Vector3(0.05, 0.785, 0.05), Vector3(0.27, 0.015, 0.33), paper, false,
		Vector3(0.0, 12.0, 0.0))
	PERIOD_PRINT.place(desk, "CaseNotebookInk", Vector3(0.05, 0.794, 0.05), Vector2(0.267, 0.327),
		_print_texture("notebook"), Vector3(-90, 12, 0), 0.003)
	var saucer := CSGCylinder3D.new()
	saucer.position = Vector3(-0.08, 0.77, 0.38)
	saucer.radius = 0.07
	saucer.height = 0.02
	saucer.sides = 10
	saucer.material = _solid(Color(0.84, 0.82, 0.78), 0.3)
	desk.add_child(saucer)
	_add_interactable(desk, &"notebook", Vector3(0.05, 0.86, 0.05), Vector3(0.45, 0.35, 0.48))

func _build_door_and_calendar() -> void:

	# Folded note slipped under the door
	PERIOD_PRINT.place(self, "LandladyNotePaper", Vector3(-0.30, 0.017, 1.83), Vector2(0.20, 0.14),
		_print_texture("landlady_note"), Vector3(-90, 14, 0), 0.004)
	_add_interactable(self, &"landlady_note", Vector3(-0.30, 0.12, 1.83), Vector3(0.45, 0.35, 0.45))

	# The chromolithographic card, tin binding and perforated monthly block are separate pieces.
	var calendar := Node3D.new()
	calendar.name = "WallCalendar"
	calendar.position = Vector3(1.577, 1.59, -0.41)
	calendar.rotation_degrees.y = -90.0
	add_child(calendar)
	PERIOD_PRINT.place(calendar, "Chromolithograph", Vector3.ZERO, Vector2(0.32, 0.46),
		_print_texture("calendar_april_1890"), Vector3.ZERO, 0.006)
	var tin := _solid(Color("777165"), 0.63, 0.60)
	_box(calendar, "CrimpedTinBinding", Vector3(0, 0.229, 0.005), Vector3(0.324, 0.014, 0.016), tin, false)
	var eye := MeshInstance3D.new()
	eye.name = "SuspensionEye"
	var loop := TorusMesh.new()
	loop.inner_radius = 0.005
	loop.outer_radius = 0.010
	loop.rings = 12
	loop.ring_segments = 6
	eye.mesh = loop
	eye.material_override = tin
	eye.rotation_degrees.x = 90
	eye.position = Vector3(0, 0.245, 0.004)
	calendar.add_child(eye)
	_box(calendar, "HangingNail", Vector3(0, 0.245, 0.006), Vector3(0.008, 0.008, 0.014), tin, false)
	for layer in 3:
		_box(calendar, "PaperEdge", Vector3(0, -0.107 - layer * 0.001, 0.005 + layer * 0.003),
			Vector3(0.269, 0.180, 0.002), _solid(Color("b29e78").lightened(layer * 0.07), 0.92), false)
	PERIOD_PRINT.place(calendar, "AprilTearOffLeaf", Vector3(0, -0.107, 0.014), Vector2(0.27, 0.181),
		_print_texture("calendar_pad"), Vector3.ZERO, 0.004)
	_add_interactable(calendar, &"calendar", Vector3(0, 0, 0.035), Vector3(0.46, 0.56, 0.09))

func _print_texture(stem: String) -> Texture2D:
	var path := PRINT_PATH + stem + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
