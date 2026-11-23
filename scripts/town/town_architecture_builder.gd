class_name TownArchitectureBuilder
extends Node3D

## Procedurally assembles the 140x75 m 1890 Colorado mining-railroad town of
## Black Creek, with authored street treads and M1's northern rail alignment.

signal interactable_triggered(id: StringName)

const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")

const TELEGRAPH_LINES := preload("res://scripts/town/black_creek_telegraph_lines.gd")
const HILLSIDE := preload("res://scripts/town/black_creek_hillside.gd")
const HARGROVE_SCENE := preload("res://assets/models/town/hargrove_house_1890.glb")
const GROUND_SHADER := preload("res://materials/shaders/black_creek_ground.gdshader")
const CREEK_SHADER := preload("res://materials/shaders/creek_water.gdshader")
const CREEK_AUDIO := preload("res://audio/sfx/town/creek_rush_loop.wav")
const LOCO_SCENE := preload("res://assets/models/dawn_train/no17.glb")
const COACH_SCENE := preload("res://assets/models/dawn_train/passenger_coach.glb")

var _mats: Dictionary = {}
var _sign_labels: Array[Dictionary] = []
var _interactables: Dictionary = {}

func build_town() -> void:
	if get_child_count() > 0:
		return
	_build_ground_and_road()
	_build_creek_and_bridge()
	_build_rail_yard_and_depot()
	_build_telegraph_poles_and_lamps()
	_build_south_main_street_buildings()
	_build_north_main_street_buildings()
	_build_south_hillside_backdrop()
	_build_boundary_colliders()
	refresh_locale()

func refresh_locale() -> void:
	for entry in _sign_labels:
		var label := entry["label"] as Label3D
		label.text = GameLocale.pick(String(entry["ru"]), String(entry["en"]))
	for id_key in _interactables:
		var act := _interactables[id_key] as Interactable
		if act == null:
			continue
		match id_key:
			&"boarding_door":
				act.prompt_text = GameLocale.pick("Войти в пансион Харгроув", "Enter Hargrove Boarding House")
			&"saloon_door":
				act.prompt_text = GameLocale.pick("Салун «Медный Мул»", "The Copper Mule Saloon")
			&"depot_door":
				act.prompt_text = GameLocale.pick("Дверь депо (Дневная смена)", "Depot Door (Day Watch)")
			&"depot_notices":
				act.prompt_text = GameLocale.pick("Прочитать объявления станции", "Read Station Noticeboard")
			&"mj_gate":
				act.prompt_text = GameLocale.pick("Осмотреть ворота ветки MJ", "Inspect MJ Spur Gate")
			&"clinic_plaque":
				act.prompt_text = GameLocale.pick("Осмотреть табличку врача", "Read Physician's Shingle")
			&"horse_trough":
				act.prompt_text = GameLocale.pick("Умыться у конского корыта", "Splash Face at Water Trough")

func get_town_interactable(id: StringName) -> Interactable:
	return _interactables.get(id, null) as Interactable

func _mat(tex_name: String, uv_scale: Vector3 = Vector3.ONE, albedo_tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex_name, str(uv_scale), albedo_tint.to_html()]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	var tex := load("res://assets/textures/town_v1/" + tex_name) as Texture2D
	mat.albedo_texture = tex
	mat.albedo_color = albedo_tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = uv_scale
	mat.roughness = 0.88
	_mats[key] = mat
	return mat

func _solid_mat(col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := "solid|%s|%.2f|%.2f" % [col.to_html(), rough, metal]
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

func _tread(parent: Node3D, node_name: String, center: Vector3, size: Vector3, mat: Material = null) -> void:
	var body := _static_box(parent, node_name, center, size)
	body.add_to_group(&"street_tread")
	if mat != null:
		_box(body, "Timber", Vector3.ZERO, size, mat, false)

func _static_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

func _add_interactable(parent: Node3D, id: StringName, pos: Vector3, sz: Vector3) -> Interactable:
	var area := Interactable.new()
	area.name = String(id) + "_Interactable"
	area.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	shape.shape = box
	area.add_child(shape)
	area.interacted.connect(func() -> void: interactable_triggered.emit(id))
	parent.add_child(area)
	_interactables[id] = area
	return area

func _build_ground_and_road() -> void:
	var g := Node3D.new()
	g.name = "GroundAndStreet"
	add_child(g)
	# The road and shoulder share one surface; old overlay slabs caught the capsule.
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter("road_color", preload("res://assets/textures/town_v2/road_albedo.png"))
	ground.set_shader_parameter("road_normal", preload("res://assets/textures/town_v2/road_normal.png"))
	ground.set_shader_parameter("road_rough", preload("res://assets/textures/town_v2/road_roughness.png"))
	_box(g, "ValleyGroundWest", Vector3(-23.5, -0.25, 12.0), Vector3(133.0, 0.5, 160.0), ground)
	_box(g, "ValleyGroundEast", Vector3(70.5, -0.25, 12.0), Vector3(39.0, 0.5, 160.0), ground)
	# Flat decks and actual risers; static treads are the only step-up surfaces.
	var bw_mat := _mat("boardwalk_planks_128.png", Vector3(1.0, 18.0, 1.0))
	_tread(g, "SouthBoardwalk", Vector3(-2.0, 0.15, 32.0), Vector3(82.0, 0.30, 2.8), bw_mat)
	_tread(g, "NorthBoardwalkWest", Vector3(-20.0, 0.15, 14.0), Vector3(28.0, 0.30, 2.6), bw_mat)
	_tread(g, "NorthBoardwalkEast", Vector3(14.0, 0.15, 14.0), Vector3(26.0, 0.30, 2.6), bw_mat)
	for rx in [-18.0, -2.0, 15.0, 29.54]:
		_tread(g, "SouthStep_%d" % roundi(rx), Vector3(rx, 0.075, 30.22), Vector3(3.0, 0.15, 0.76), bw_mat)
	for rx in [-28.0, -10.0, 10.0, 22.0]:
		_tread(g, "NorthStep_%d" % int(rx), Vector3(rx, 0.075, 15.68), Vector3(2.8, 0.15, 0.76), bw_mat)
	_tread(g, "EastEndStep", Vector3(39.38, 0.075, 32.0), Vector3(0.76, 0.15, 2.8), bw_mat)

	# Horse trough + hitching posts along South boardwalk edge
	var timber := _mat("weathered_pine_128.png", Vector3(2.0, 1.0, 1.0))
	for hx in [-20.0, -5.0, 2.0, 27.0]:
		_box(g, "HitchPostL_%d" % int(hx), Vector3(hx - 1.1, 0.48, 29.8), Vector3(0.14, 0.96, 0.14), timber, true)
		_box(g, "HitchPostR_%d" % int(hx), Vector3(hx + 1.1, 0.48, 29.8), Vector3(0.14, 0.96, 0.14), timber, true)
		_box(g, "HitchRail_%d" % int(hx), Vector3(hx, 0.82, 29.8), Vector3(2.4, 0.10, 0.10), timber, false)
	var trough := Node3D.new()
	trough.name = "HorseTrough"
	trough.position = Vector3(23.5, 0.0, 29.4)
	g.add_child(trough)
	_static_box(trough, "TroughCollision", Vector3(0, 0.42, 0), Vector3(2.20, 0.84, 0.85))
	_add_interactable(trough, &"horse_trough", Vector3(0.0, 0.55, 0.0), Vector3(2.3, 1.0, 1.1))

func _build_creek_and_bridge() -> void:
	var c := Node3D.new()
	c.name = "CreekAndBridge"
	add_child(c)
	var stone := _mat("stone_foundation_128.png", Vector3(12.0, 2.0, 1.0))
	var water_mat := ShaderMaterial.new()
	water_mat.shader = CREEK_SHADER
	water_mat.set_shader_parameter("water_tex", load("res://assets/textures/town_v1/creek_water_128.png"))
	_box(c, "CreekBed", Vector3(47.0, -0.55, 12.0), Vector3(8.5, 0.25, 160.0), stone, true)
	var creek := CSGBox3D.new()
	creek.name = "BlackCreekStream"
	creek.position = Vector3(47.0, -0.14, 12.0)
	creek.size = Vector3(7.6, 0.08, 160.0)
	creek.material = water_mat
	c.add_child(creek)
	_box(c, "BankWest", Vector3(43.0, 0.04, 12.0), Vector3(1.1, 0.45, 160.0), stone, false)
	_box(c, "BankEast", Vector3(51.0, 0.04, 12.0), Vector3(1.1, 0.45, 160.0), stone, false)

	var bridge := Node3D.new()
	bridge.name = "TimberCreekBridge"
	bridge.position = Vector3(46.5, 0.0, 23.0)
	c.add_child(bridge)
	_add_model(bridge, "creek_bridge_trough")
	_build_bridge_treads(bridge)
	for side in [-1.0, 1.0]:
		_static_box(bridge, "BridgeRail", Vector3(0, 0.78, side * 2.16), Vector3(9.7, 0.87, 0.14))
	var audio := AudioStreamPlayer3D.new()
	audio.name = "CreekAudio"
	audio.stream = CREEK_AUDIO
	audio.bus = &"Ambience"
	audio.volume_db = -8.0
	audio.max_distance = 36.0
	audio.unit_size = 6.0
	audio.autoplay = DisplayServer.get_name() != "headless"
	bridge.add_child(audio)

func _build_bridge_treads(bridge: Node3D) -> void:
	# Match the authored GLB deck at y=.39; weld both ramps to that plane.
	const DECK_END := 4.85
	const APPROACH_END := 6.37
	const DECK_Y := 0.39
	const HALF_WIDTH := 2.30
	var profile := [Vector2(-APPROACH_END, 0), Vector2(-DECK_END, DECK_Y),
		Vector2(DECK_END, DECK_Y), Vector2(APPROACH_END, 0)]
	var faces := PackedVector3Array()
	for i in range(profile.size() - 1):
		var a := Vector3(profile[i].x, profile[i].y, -HALF_WIDTH)
		var b := Vector3(profile[i + 1].x, profile[i + 1].y, -HALF_WIDTH)
		var c := Vector3(profile[i].x, profile[i].y, HALF_WIDTH)
		var d := Vector3(profile[i + 1].x, profile[i + 1].y, HALF_WIDTH)
		faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	var body := StaticBody3D.new()
	body.name = "ContinuousBridgeTread"
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	bridge.add_child(body)

func _build_rail_yard_and_depot() -> void:
	var y := Node3D.new()
	y.name = "RailYardAndDepot"
	add_child(y)
	var plank := _mat("boardwalk_planks_128.png", Vector3(4.0, 1.5, 1.0))
	var steel := _solid_mat(Color(0.24, 0.25, 0.28), 0.45, 0.7)
	var tie_mat := _mat("weathered_pine_128.png", Vector3(1.0, 1.0, 1.0), Color(0.55, 0.48, 0.42))

	# Main Line Tracks at Z = -18 (exact M1 MineYard coordinate)
	_box(y, "MainRailSouth", Vector3(0.0, 0.06, -17.28), Vector3(150.0, 0.08, 0.08), steel, false)
	_box(y, "MainRailNorth", Vector3(0.0, 0.06, -18.72), Vector3(150.0, 0.08, 0.08), steel, false)
	for tx in range(-68, 69, 2):
		_box(y, "Tie_%d" % tx, Vector3(float(tx), 0.02, -18.0), Vector3(0.24, 0.06, 2.2), tie_mat, false)

	# Train 17 coaches visible down the east siding in daytime
	if ResourceLoader.exists("res://assets/models/dawn_train/no17.glb"):
		var loco := LOCO_SCENE.instantiate() as Node3D
		loco.name = "ParkedTrain17"
		loco.position = Vector3(-34.0, 0.08, -18.0)
		y.add_child(loco)
		var coach := COACH_SCENE.instantiate() as Node3D
		coach.name = "ParkedCoach17"
		coach.position = Vector3(-47.0, 0.08, -18.0)
		y.add_child(coach)

	# Black Creek Depot (X=0, Z=-2.5)
	var depot := Node3D.new()
	depot.name = "BlackCreekDepot"
	depot.position = Vector3(0.0, 0.0, -2.5)
	y.add_child(depot)
	_tread(depot, "Platform", Vector3(0.0, 0.15, 1.2), Vector3(12.4, 0.30, 7.6), plank)
	_tread(depot, "PlatformStep", Vector3(0.0, 0.075, 5.38), Vector3(3.6, 0.15, 0.76), plank)
	_add_model(depot, "black_creek_depot")
	_static_box(depot, "DepotShell", Vector3(0, 2.1, -0.18), Vector3(8, 3.6, 4.56))
	_static_box(depot, "TrackBay", Vector3(0, 1.86, -2.57), Vector3(2.48, 3.2, 0.79))
	_add_interactable(depot, &"depot_door", Vector3(-1.6, 1.4, 2.55), Vector3(1.4, 2.2, 1.0))
	_add_interactable(depot, &"depot_notices", Vector3(3.3, 1.8, 2.55), Vector3(1.5, 1.4, 1.0))

	var tower := _add_model(y, "water_tower", Vector3(-24, 0, -14))
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			_static_box(tower, "TimberLeg", Vector3(x, 2.5, z), Vector3(0.35, 5, 0.35))

	var mj := Node3D.new()
	mj.name = "MJSpurGate"
	mj.position = Vector3(22.0, 0.0, -14.0)
	y.add_child(mj)
	_add_model(mj, "mj_spur_gate")
	for x in [-2.21, 2.21]:
		_static_box(mj, "GatePost", Vector3(x, 1.25, 0), Vector3(0.36, 2.5, 0.36))
	_static_box(mj, "LockedSpan", Vector3(0, 1.14, 0.02), Vector3(4.12, 2.12, 0.17))
	_add_interactable(mj, &"mj_gate", Vector3(0.0, 1.2, 0.6), Vector3(3.4, 2.0, 1.6))

	_add_model(y, "mine_headframe", Vector3(10, 0, -46))

func _build_telegraph_poles_and_lamps() -> void:
	var infra := Node3D.new()
	infra.name = "TelegraphAndLamps"
	add_child(infra)
	var wood := _mat("weathered_pine_128.png")
	TELEGRAPH_LINES.build(infra)
	for x in [-42.0, -24.0, -8.0, 8.0, 24.0, 38.0]:
		_static_box(infra, "PoleCollision", Vector3(x, 3.6, 12.6), Vector3(0.22, 7.2, 0.22))

	# Only the commercial frontage and depot have pole lamps. No residential poles.
	for at: Vector3 in [Vector3(6.0, 0, 30.65), Vector3(4.35, 0, 3.66)]:
		_box(infra, "OilLampPost", at + Vector3(0, 1.23, 0), Vector3(0.095, 2.46, 0.095), wood)
		TownOilLight.cage(infra, at + Vector3(0, 2.46, 0), 0.83, 7.0).add_to_group(&"town_oil_flame")

func _add_model(parent: Node3D, stem: String, at := Vector3.ZERO) -> Node3D:
	var data := load("res://assets/models/town/%s.glb" % stem) as PackedScene
	var model := data.instantiate() as Node3D
	model.position = at
	parent.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			continue
		var mat := source.duplicate() as StandardMaterial3D
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if "glass" in mat.resource_name.to_lower() and stem in ["copper_mule", "black_creek_depot"]:
			mesh.material_override = mat
			mesh.add_to_group(&"town_saloon_window" if stem == "copper_mule" else &"town_porch_window")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mesh.set_surface_override_material(0, mat)
	return model

func _build_south_main_street_buildings() -> void:
	var sb := Node3D.new()
	sb.name = "SouthBuildings"
	add_child(sb)
	var plank := _mat("boardwalk_planks_128.png", Vector3(3.0, 1.5, 1.0))

	# 1) The Copper Mule Saloon (X=-2, Z=+41.5, facing North toward street)
	var saloon := Node3D.new()
	saloon.name = "CopperMuleSaloon"
	saloon.position = Vector3(-2.0, 0.0, 41.5)
	sb.add_child(saloon)
	_add_model(saloon, "copper_mule")
	_static_box(saloon, "SaloonShell", Vector3(0, 3.3, 0.48), Vector3(12, 6.6, 14.04))
	_tread(saloon, "SaloonPorch", Vector3(0, 0.15, -9.03), Vector3(12.27, 0.30, 3.30))
	TownOilLight.cage(saloon, Vector3(1.13, 2.68, -7.75), 0.63, 7.0).add_to_group(&"town_oil_flame")
	_add_interactable(saloon, &"saloon_door", Vector3(0.0, 1.4, -8.3), Vector3(2.4, 2.4, 1.4))

	# 2) Miller & Sons Mercantile & Post Office (X=-18, Z=+41)
	var merc := Node3D.new()
	merc.name = "MillerMercantile"
	merc.position = Vector3(-18.0, 0.0, 41.0)
	sb.add_child(merc)
	_add_model(merc, "miller_mercantile")
	_static_box(merc, "StoreShell", Vector3(0, 2.6, 0.2), Vector3(10, 5.2, 13.2))
	_tread(merc, "StorePorch", Vector3(0, 0.15, -7.15), Vector3(10.27, 0.30, 0.96))

	# 3) Dr. Arthur Crane's Closed Clinic (X=+15, Z=+40.5)
	var clinic := Node3D.new()
	clinic.name = "CraneClinic"
	clinic.position = Vector3(15.0, 0.0, 40.5)
	sb.add_child(clinic)
	_add_model(clinic, "crane_clinic")
	_static_box(clinic, "ClinicShell", Vector3(0, 2, 0.17), Vector3(8, 4, 9.66))
	_tread(clinic, "PorchFloor", Vector3(0, 0.15, -5.79), Vector3(8, 0.30, 1.85))
	_tread(clinic, "PorchStep", Vector3(0, 0.075, -7.02), Vector3(4.2, 0.15, 0.58))
	_add_interactable(clinic, &"clinic_plaque", Vector3(0.6, 1.4, -5.6), Vector3(2.4, 2.0, 1.4))

	# 4) Mrs. Hargrove's Boarding House — Elias's Lodging (X=+31, Z=+40.5)
	var bh := Node3D.new()
	bh.name = "HargroveBoardingHouse"
	bh.position = Vector3(31.0, 0.0, 40.5)
	sb.add_child(bh)
	bh.add_child(HARGROVE_SCENE.instantiate())
	_tread(bh, "PorchFloor", Vector3(0.0, 0.23, -5.38), Vector3(7.90, 0.46, 2.18))
	_tread(bh, "PorchStep", Vector3(-1.46, 0.15, -6.73), Vector3(2.20, 0.30, 0.56), plank)
	_static_box(bh, "MainHouse", Vector3(0.0, 2.94, 0.0), Vector3(7.90, 5.88, 8.60))
	_static_box(bh, "KitchenWing", Vector3(-1.90, 1.45, 5.59), Vector3(3.80, 2.90, 2.58))
	for rail in [Vector2(-3.16, 1.10), Vector2(1.72, 4.04)]:
		_static_box(bh, "PorchRail_%d" % int(rail.x), Vector3(rail.x, 0.90, -6.28),
			Vector3(rail.y, 0.86, 0.16))
	var sign := Label3D.new()
	sign.position = Vector3(-1.46, 2.79, -6.488)
	sign.rotation_degrees.y = 180.0
	sign.font = FONT_REG
	sign.font_size = 32
	sign.pixel_size = 0.00365
	sign.modulate = Color(0.94, 0.86, 0.68)
	sign.outline_size = 1
	bh.add_child(sign)
	_sign_labels.append({"label": sign, "ru": "ПАНСИОН ХАРГРОУВ", "en": "HARGROVE BOARDING HOUSE"})
	TownOilLight.mount(bh, Vector3(-0.52, 2.61, -4.43), 0.0, 1.68, 7.4).add_to_group(&"town_oil_flame")
	for pane in [Vector3(1.98, 2.05, -4.321), Vector3(-2.48, 4.76, -4.321)]:
		var backlight := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.76, 1.42)
		backlight.mesh = quad
		backlight.position = pane
		backlight.rotation_degrees.y = 180.0
		backlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(0.89, 0.62, 0.29)
		mat.emission_energy_multiplier = 0.52
		mat.albedo_color = Color(0.47, 0.31, 0.19)
		backlight.material_override = mat
		backlight.add_to_group(&"town_oil_flame")
		bh.add_child(backlight)
	_add_interactable(bh, &"boarding_door", Vector3(-1.46, 1.55, -4.64), Vector3(1.26, 2.18, 0.75))

func _build_north_main_street_buildings() -> void:
	var nb := Node3D.new()
	nb.name = "NorthBuildings"
	add_child(nb)

	# 1) BC&W Brick Division & Assay Office (X=+14, Z=+8)
	var comp := Node3D.new()
	comp.name = "CompanyAssayOffice"
	comp.position = Vector3(14.0, 0.0, 8.0)
	nb.add_child(comp)
	_add_model(comp, "bcw_assay_office")
	_static_box(comp, "OfficeShell", Vector3(0, 2.8, -0.15), Vector3(9, 5.6, 9.7))
	TownOilLight.cage(comp, Vector3(1.21, 2.71, 5.17), 0.55, 6.0).add_to_group(&"town_oil_flame")

	# 2) Chronicle Print Shop (X=-13, Z=+8.5)
	var print_shop := Node3D.new()
	print_shop.name = "ChroniclePrintShop"
	print_shop.position = Vector3(-13.0, 0.0, 8.5)
	nb.add_child(print_shop)
	_add_model(print_shop, "chronicle_print_shop")
	_static_box(print_shop, "PressShell", Vector3(0, 2.5, -0.18), Vector3(6, 5, 9.2))

	var smithy := _add_model(nb, "kowalski_blacksmith", Vector3(-46, 0, 13))
	_static_box(smithy, "SmithyShell", Vector3(0, 2.04, 0), Vector3(7.7, 4.08, 6.2))
	var jail := _add_model(nb, "stone_calaboose", Vector3(26, 0, 6))
	_static_box(jail, "CalabooseShell", Vector3(0, 1.56, 0), Vector3(5, 3.12, 5.8))
	_add_model(self, "roadside_props")
	_static_box(self, "WagonCollision", Vector3(-9, 1.15, 27), Vector3(4.8, 1.8, 2.2))

func _build_south_hillside_backdrop() -> void:
	var bg := Node3D.new()
	bg.name = "HillsideBackdrop"
	add_child(bg)
	HILLSIDE.new().build(bg)
	_add_model(bg, "chapel_steeple", Vector3(-54, 9, 62))

func _build_boundary_colliders() -> void:
	var bounds := Node3D.new()
	bounds.name = "WorldBounds"
	add_child(bounds)
	var specs := [
		["North", Vector3(0.0, 2.0, -15.5), Vector3(130.0, 4.0, 1.0)],
		["South", Vector3(0.0, 2.0, 47.0), Vector3(130.0, 4.0, 1.0)],
		["West", Vector3(-56.0, 2.0, 16.0), Vector3(1.0, 4.0, 70.0)],
		["East", Vector3(54.0, 2.0, 16.0), Vector3(1.0, 4.0, 70.0)],
	]
	for spec in specs:
		var body := StaticBody3D.new()
		body.name = String(spec[0])
		body.position = spec[1]
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[2]
		cs.shape = box
		body.add_child(cs)
		bounds.add_child(body)
