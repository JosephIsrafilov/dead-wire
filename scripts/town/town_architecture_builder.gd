class_name TownArchitectureBuilder
extends Node3D

## Procedurally assembles the 140x75 m 1890 Colorado mining-railroad town of
## Black Creek, with authored street treads and M1's northern rail alignment.

signal interactable_triggered(id: StringName)
signal creek_waded()

# M1's office axes are the west room datum; the main line stays shared with MineYard.
const RAIL_LAYOUT := preload("res://scripts/town/black_creek_rail_layout.gd")
const DEPOT_ORIGIN := RAIL_LAYOUT.DEPOT_ORIGIN
const DEPOT_DOOR := Vector3(-1.6, 1.42, 2.51)
const DEPOT_SOUTH_SPAWN := DEPOT_ORIGIN + Vector3(-1.6, 0.30, 3.70)
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")

const TELEGRAPH_LINES := preload("res://scripts/town/black_creek_telegraph_lines.gd")
const HILLSIDE := preload("res://scripts/town/black_creek_hillside.gd")
## Low shelf on the southwest edge, inside the playable valley.
const CHAPEL_ORIGIN := Vector3(-46.0, 0.62, 39.0)
const STREET_DRESSING := preload("res://scripts/town/black_creek_street_dressing.gd")
const STREET_SIGNS := preload("res://scripts/town/black_creek_street_signs.gd")
const HARGROVE_SCENE := preload("res://assets/models/town/hargrove_house_1890.glb")
const GROUND_SHADER := preload("res://materials/shaders/black_creek_ground.gdshader")
const CREEK_SHADER := preload("res://materials/shaders/creek_water.gdshader")
const CREEK_AUDIO := preload("res://audio/sfx/town/creek_rush_loop.wav")
const LOCO_SCENE := preload("res://assets/models/dawn_train/no17.glb")
const COACH_SCENE := preload("res://assets/models/dawn_train/passenger_coach.glb")

var _mats: Dictionary = {}
var _sign_labels: Array[Dictionary] = []
var _interactables: Dictionary = {}
var _night_approach_mode: bool = false
var _yard_locomotive: Node3D
var _yard_coach: Node3D
var _street: Node3D
var _street_signs: Node3D

func set_night_approach_mode(enabled: bool) -> void:
	_night_approach_mode = enabled
	refresh_locale()
	if enabled:
		set_approach_train_time(0.0)

func set_approach_train_time(seconds: float) -> void:
	var x := 27.0 - 8.5 * seconds
	_yard_locomotive.position.x = x
	_yard_coach.position.x = x + 13.0
	for car in [_yard_locomotive, _yard_coach]:
		car.rotation.y = PI
		car.visible = x > -92.0

func build_town(night_approach: bool = false) -> void:
	if get_child_count() > 0:
		return
	_street = STREET_DRESSING.new()
	_street.name = "StreetDressing"
	add_child(_street)
	_build_ground_and_road()
	_street.build()
	_build_creek_and_bridge()
	_build_rail_yard_and_depot()
	_build_telegraph_poles_and_lamps()
	_build_south_main_street_buildings()
	_build_north_main_street_buildings()
	_street_signs = STREET_SIGNS.new()
	_street_signs.name = "StreetSigns"
	add_child(_street_signs)
	_street_signs.build(_street.timber)
	_static_box(_street_signs, "NewspaperStand", Vector3(-11.1, 0.65, 13.93), Vector3(0.78, 0.70, 0.43))
	_static_box(_street_signs, "Guidepost", Vector3(3.95, 1.15, 26.4), Vector3(0.17, 2.30, 0.17))
	var paper := _add_interactable(_street_signs, &"chronicle_paper", Vector3(-11.1, 1.05, 14.13),
		Vector3(0.84, 0.48, 0.44))
	paper.collision_layer = 2
	paper.collision_mask = 0
	_build_south_hillside_backdrop()
	_build_boundary_colliders()
	var life := preload("res://scripts/town/black_creek_street_life.gd").new()
	life.name = "StreetLife"
	add_child(life)
	life.build(self, _yard_locomotive, DEPOT_ORIGIN, night_approach)
	refresh_locale()

func refresh_locale() -> void:
	if _street_signs != null:
		_street_signs.refresh_locale()
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
				if _night_approach_mode:
					act.prompt_text = GameLocale.pick("Войти на станцию", "Enter the Depot")
				else:
					act.prompt_text = GameLocale.pick("Дверь депо (Дневная смена)", "Depot Door (Day Watch)")
			&"depot_notices":
				act.prompt_text = GameLocale.pick("Прочитать объявления станции", "Read Station Noticeboard")
			&"mj_gate":
				act.prompt_text = GameLocale.pick("Осмотреть ворота ветки MJ", "Inspect MJ Spur Gate")
			&"chronicle_door", &"assay_door", &"mercantile_door", &"clinic_door", &"smithy_door", &"calaboose_door":
				act.prompt_text = GameLocale.pick("Постучать", "Knock")
			&"chapel_door":
				act.prompt_text = GameLocale.pick("Дёрнуть дверь часовни", "Try Chapel Door")
			&"chronicle_paper":
				act.prompt_text = GameLocale.pick("Читать газету", "Read the Chronicle")
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

func _tread(parent: Node3D, node_name: String, center: Vector3, size: Vector3,
		mat: Material = null, surface: StringName = &"boardwalk") -> void:
	var body := _static_box(parent, node_name, center, size)
	body.add_to_group(&"street_tread")
	FootstepSurfaceResolver.tag(body, surface)
	if mat != null:
		_box(body, "Timber", Vector3.ZERO, size, mat, false)

func _street_deck(parent: Node3D, node_name: String, center: Vector3, size: Vector3,
		surface: StringName = &"boardwalk") -> void:
	var body := _static_box(parent, node_name, center, size)
	body.add_to_group(&"street_tread")
	FootstepSurfaceResolver.tag(body, surface)
	_street.build_deck(parent, center, size)

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

## Phase B: a patch of ground that is a different material from the collider
## under it — the cinder and ballast bed the rails are laid in has no separate
## body of its own, so the strip is described here and read by the resolver.
func _surface_zone(parent: Node3D, zone_name: String, center: Vector3, size: Vector3,
		surface: StringName, priority: int = 0) -> FootstepSurfaceZone:
	var zone := FootstepSurfaceZone.new()
	zone.name = zone_name
	zone.surface = surface
	zone.zone_priority = priority
	zone.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	parent.add_child(zone)
	return zone

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
	ground.set_shader_parameter("clay_albedo", preload("res://assets/textures/town_v2/clay_albedo.png"))
	ground.set_shader_parameter("clay_normal", preload("res://assets/textures/town_v2/clay_normal.png"))
	ground.set_shader_parameter("slag_albedo", preload("res://assets/textures/town_v2/slag_albedo.png"))
	ground.set_shader_parameter("slag_roughness", preload("res://assets/textures/town_v2/slag_roughness.png"))
	# Track and street datums the ground shader paints ballast and ruts from.
	ground.set_shader_parameter("main_track_z", RAIL_LAYOUT.MAIN_LINE_Z)
	ground.set_shader_parameter("depot_approach_x", 0.0)
	_box(g, "ValleyGroundWest", Vector3(-23.5, -0.25, 12.0), Vector3(133.0, 0.5, 160.0), ground)
	_box(g, "ValleyGroundEast", Vector3(70.5, -0.25, 12.0), Vector3(39.0, 0.5, 160.0), ground)
	for band in FootstepSurfacePaint.cinder_bands(RAIL_LAYOUT.MAIN_LINE_Z) \
			+ FootstepSurfacePaint.rail_bands(RAIL_LAYOUT.MAIN_LINE_Z):
		_surface_zone(g, band["name"], band["center"], band["size"], band["surface"], band["priority"])
	# Flat decks and actual risers; static treads are the only step-up surfaces.
	_street_deck(g, "SouthBoardwalk", Vector3(1.4, 0.15, 32.0), Vector3(75.2, 0.30, 2.8))
	_street_deck(g, "NorthBoardwalkWest", Vector3(-20.0, 0.15, 14.0), Vector3(28.0, 0.30, 2.6))
	_street_deck(g, "NorthBoardwalkEast", Vector3(14.0, 0.15, 14.0), Vector3(26.0, 0.30, 2.6))
	for rx in [-18.0, -2.0, 15.0, 29.54]:
		_street_deck(g, "SouthStep_%d" % roundi(rx), Vector3(rx, 0.075, 30.22), Vector3(3.0, 0.15, 0.76),
			&"stairs")
	for rx in [-28.0, -10.0, 10.0, 22.0]:
		_street_deck(g, "NorthStep_%d" % int(rx), Vector3(rx, 0.075, 15.68), Vector3(2.8, 0.15, 0.76),
			&"stairs")
	_street_deck(g, "EastEndStep", Vector3(39.38, 0.075, 32.0), Vector3(0.76, 0.15, 2.8), &"stairs")

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
	_box(c, "BankWest", Vector3(42.7, -0.16, 12.0), Vector3(1.2, 0.24, 160.0), stone, false)
	_box(c, "BankEast", Vector3(51.3, -0.16, 12.0), Vector3(1.2, 0.24, 160.0), stone, false)
	_build_creek_bank_ramps(c)
	_build_creek_water_trigger(c)

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
	audio.volume_db = -15.0
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
	FootstepSurfaceResolver.tag(body, &"wood_bridge")
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
	var steel := _solid_mat(Color(0.24, 0.25, 0.28), 0.45, 0.7)
	var tie_mat := _mat("weathered_pine_128.png", Vector3(1.0, 1.0, 1.0), Color(0.55, 0.48, 0.42))

	var main_z: float = RAIL_LAYOUT.MAIN_LINE_Z
	_box(y, "MainRailSouth", Vector3(0.0, 0.06, main_z + 0.72), Vector3(150.0, 0.08, 0.08), steel, false)
	_box(y, "MainRailNorth", Vector3(0.0, 0.06, main_z - 0.72), Vector3(150.0, 0.08, 0.08), steel, false)
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.24, 0.06, 2.2)
	sleeper.material = tie_mat
	var ties := MultiMesh.new()
	ties.transform_format = MultiMesh.TRANSFORM_3D
	ties.mesh = sleeper
	ties.instance_count = 200
	for i in ties.instance_count:
		ties.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-69.65 + i * 0.7, 0.025, main_z)))
	var sleepers := MultiMeshInstance3D.new()
	sleepers.multimesh = ties
	y.add_child(sleepers)

	# The same rolling stock parks west of the tower during the day.
	_yard_locomotive = LOCO_SCENE.instantiate() as Node3D
	_yard_locomotive.name = "ParkedTrain17"
	_yard_locomotive.position = Vector3(-34.0, 0.08, main_z)
	y.add_child(_yard_locomotive)
	var headlamp := SpotLight3D.new()
	headlamp.position = Vector3(3.12, 2.35, 0.0)
	headlamp.rotation = Vector3(-0.11, -PI * 0.5, 0.0)
	headlamp.light_color = Color(1.0, 0.83, 0.53)
	headlamp.light_energy = 4.1
	headlamp.spot_range = 23.0
	headlamp.spot_angle = 23.0
	headlamp.add_to_group(&"town_night_only")
	_yard_locomotive.add_child(headlamp)
	_yard_coach = COACH_SCENE.instantiate() as Node3D
	_yard_coach.name = "ParkedCoach17"
	_yard_coach.position = Vector3(-47.0, 0.08, main_z)
	y.add_child(_yard_coach)

	_build_depot(y, tie_mat)

	var tower := _add_model(y, "water_tower", Vector3(-24, 0, -14))
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			_static_box(tower, "TimberLeg", Vector3(x, 2.5, z), Vector3(0.35, 5, 0.35))

	var mj := Node3D.new()
	mj.name = "MJSpurGate"
	mj.position = Vector3(21.0, 0.0, -26.0)
	y.add_child(mj)
	_add_model(mj, "mj_spur_gate")
	for x in [-2.21, 2.21]:
		_static_box(mj, "GatePost", Vector3(x, 1.25, 0), Vector3(0.36, 2.5, 0.36))
	_static_box(mj, "LockedSpan", Vector3(0, 1.14, 0.02), Vector3(4.12, 2.12, 0.17))
	_add_interactable(mj, &"mj_gate", Vector3(0.0, 1.2, 0.6), Vector3(3.4, 2.0, 1.6))

	var switch_lamp := Node3D.new()
	switch_lamp.name = "NightMJSwitchLamp"
	switch_lamp.position = Vector3(1.45, 0.0, -21.5)
	y.add_child(switch_lamp)
	_box(switch_lamp, "SwitchPost", Vector3(0, 0.72, 0), Vector3(0.11, 1.44, 0.11), _solid_mat(Color(0.16, 0.15, 0.14)))
	var red_glass := StandardMaterial3D.new()
	red_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_glass.albedo_color = Color(0.96, 0.24, 0.14)
	red_glass.emission_enabled = true
	red_glass.emission = Color(0.95, 0.22, 0.14)
	red_glass.emission_energy_multiplier = 2.2
	_box(switch_lamp, "SwitchLens", Vector3(0, 1.52, 0), Vector3(0.16, 0.18, 0.16), red_glass, false)
	var switch_omni := OmniLight3D.new()
	switch_omni.position = Vector3(0, 1.55, 0)
	switch_omni.light_color = Color(0.96, 0.24, 0.14)
	switch_omni.light_energy = 0.85
	switch_omni.omni_range = 7.0
	switch_omni.shadow_enabled = false
	switch_omni.add_to_group(&"town_night_only")
	switch_lamp.add_child(switch_omni)

	var spur := PackedVector3Array([
		Vector3(-3.0, 0.065, main_z), Vector3(4.9, 0.065, -20.25),
		Vector3(15.3, 0.065, -23.0), Vector3(21.0, 0.065, -26.0),
		Vector3(24.0, 0.065, -33.0), Vector3(13.0, 0.065, -43.0),
	])
	for i in range(spur.size() - 1):
		var from := spur[i]
		var to := spur[i + 1]
		var yaw := atan2(to.x - from.x, to.z - from.z)
		var across := Vector3.RIGHT.rotated(Vector3.UP, yaw)
		var bed := _surface_zone(y, "SpurBallast%d" % i, (from + to) * 0.5,
			Vector3(3.4, 0.40, from.distance_to(to) + 0.25), &"ballast")
		bed.rotation.y = yaw
		for side in [-1.0, 1.0]:
			_box(y, "SpurRail", (from + to) * 0.5 + across * 0.72 * side,
				Vector3(0.07, 0.06, from.distance_to(to) + 0.22), steel, false,
				Vector3(0, rad_to_deg(yaw), 0))
		for step in range(1, ceili(from.distance_to(to) / 0.72)):
			var at := from.move_toward(to, step * 0.72) - Vector3.UP * 0.042
			_box(y, "SpurSleeper", at, Vector3(2.15, 0.06, 0.22), tie_mat, false,
				Vector3(0, rad_to_deg(yaw), 0))

	_add_model(y, "mine_headframe", Vector3(10, 0, -46))

func _build_depot(yard: Node3D, timber: Material) -> void:
	var plank := _mat("boardwalk_planks_128.png", Vector3(4.0, 1.5, 1.0), Color(0.72, 0.66, 0.60))
	var ramp_planks := _mat("boardwalk_planks_128.png", Vector3(4.0, 1.5, 1.0), Color(0.66, 0.59, 0.53))
	var depot := Node3D.new()
	depot.name = "BlackCreekDepot"
	depot.position = DEPOT_ORIGIN
	yard.add_child(depot)
	_add_model(depot, "black_creek_depot")
	_static_box(depot, "DepotShell", Vector3(4.4, 1.76, -0.24), Vector3(15.2, 2.92, 5.27))
	_static_box(depot, "TrackBay", Vector3(-1.5, 1.46, -3.33), Vector3(1.6, 2.35, 0.9))
	for side in [-1.0, 1.0]:
		var cheek := _static_box(depot, "BayCheek", Vector3(-1.5 + side * 1.08, 1.46, -3.33),
			Vector3(0.12, 2.35, 1.05))
		cheek.rotation.y = -side * atan2(0.57, 0.9)
		_static_box(depot, "PorchPost", Vector3(-1.595 + side * 1.165, 1.67, 3.08),
			Vector3(0.16, 2.74, 0.16))
	_static_box(depot, "FreightCases", Vector3(11.0, 0.82, -4.18), Vector3(1.02, 1.04, 0.56))
	_static_box(depot, "FreightTruck", Vector3(9.12, 0.56, -4.37), Vector3(0.83, 0.52, 1.19))
	_static_box(depot, "FreightBarrel", Vector3(10.9, 0.70, 3.05), Vector3(0.57, 0.8, 0.57))
	_static_box(depot, "SignalMast", Vector3(-3.48, 3.4, -3.58), Vector3(0.16, 6.2, 0.16))

	_tread(depot, "Platform", Vector3(4.4, 0.15, -0.67), Vector3(17.6, 0.30, 10.34))
	_box(depot, "PlankDeck", Vector3(4.4, 0.255, -0.67), Vector3(17.6, 0.09, 10.34), plank, false)
	for x in range(-4, 14):
		for z in [-5.65, 4.30]:
			_box(depot, "DeckPier", Vector3(x, 0.105, z), Vector3(0.17, 0.22, 0.19), timber, false)
	for z in [-5.71, 4.37]:
		_box(depot, "RimJoist", Vector3(4.4, 0.208, z), Vector3(17.6, 0.095, 0.14), timber, false)
	for x in [-4.35, 13.15]:
		_box(depot, "EndSill", Vector3(x, 0.106, -0.67), Vector3(0.10, 0.216, 10.34), ramp_planks, false)
	_depot_ramp(depot, "EastFreightRamp", Vector3(13.2, 0.30, -3.4), Vector3.RIGHT, 1.78, 3.8, ramp_planks, timber)
	_depot_ramp(depot, "WestFreightRamp", Vector3(-4.4, 0.30, -0.9), Vector3.LEFT, 1.78, 3.8, ramp_planks, timber)
	_depot_ramp(depot, "SouthApron", Vector3(4.4, 0.30, 4.5), Vector3.BACK, 0.78, 17.6, plank, timber)
	_depot_ramp(depot, "NorthApron", Vector3(4.4, 0.30, -5.84), Vector3.FORWARD, 0.65, 17.6, plank, timber)

	_add_interactable(depot, &"depot_door", DEPOT_DOOR, Vector3(1.34, 2.22, 0.26))
	_add_interactable(depot, &"depot_notices", Vector3(2.96, 1.68, 2.54), Vector3(1.29, 1.06, 0.2))
	TownOilLight.mount(depot, Vector3(-1.6, 2.89, 2.61), 180.0, 1.05, 8.0).add_to_group(&"town_oil_flame")

	var beacon := OmniLight3D.new()
	beacon.name = "DepotPorchBeacon"
	beacon.position = Vector3(-1.6, 2.74, 3.15)
	beacon.light_color = Color(1.0, 0.72, 0.36)
	beacon.light_energy = 1.2
	beacon.omni_range = 11.0
	beacon.add_to_group(&"town_night_only")
	depot.add_child(beacon)

	var bay_lamp := OmniLight3D.new()
	bay_lamp.position = Vector3(-1.5, 1.71, -4.01)
	bay_lamp.light_color = Color(1.0, 0.69, 0.38)
	bay_lamp.light_energy = 0.52
	bay_lamp.omni_range = 4.5
	bay_lamp.add_to_group(&"town_night_lamp")
	depot.add_child(bay_lamp)

func _depot_ramp(parent: Node3D, ramp_name: String, top: Vector3, outward: Vector3,
		run: float, width: float, material: Material, timber: Material) -> void:
	const THICKNESS := 0.075
	var down := outward * run - Vector3.UP * top.y
	var along := down.normalized()
	var across := Vector3.UP.cross(outward)
	var up := along.cross(across).normalized()
	var body := _static_box(parent, ramp_name, top + down * 0.5 - up * THICKNESS * 0.5,
		Vector3(width, THICKNESS, down.length()))
	body.basis = Basis(across, up, along)
	body.add_to_group(&"street_tread")
	FootstepSurfaceResolver.tag(body, &"stairs")
	_box(body, "RampPlanks", Vector3.ZERO, Vector3(width, THICKNESS, down.length()), material, false)
	for edge in [-1.0, 1.0]:
		var skirt := CSGPolygon3D.new()
		skirt.name = ramp_name + "Skirt"
		skirt.polygon = PackedVector2Array([Vector2.ZERO, Vector2(run, 0), Vector2(0, top.y)])
		skirt.depth = 0.075
		skirt.material = material
		skirt.basis = Basis(outward, Vector3.UP, -across)
		var offset := width * 0.5 - (skirt.depth if edge > 0.0 else 0.0) - 0.008
		skirt.position = top - Vector3.UP * (top.y + 0.02) + across * edge * offset
		parent.add_child(skirt)
		_box(skirt, "SkirtBrace", Vector3(0.09, 0.105, -0.037), Vector3(0.12, 0.23, 0.11), timber, false)

func _build_telegraph_poles_and_lamps() -> void:
	var infra := Node3D.new()
	infra.name = "TelegraphAndLamps"
	add_child(infra)
	var wood := _mat("weathered_pine_128.png")
	TELEGRAPH_LINES.build(infra, DEPOT_ORIGIN)
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
		var material_name := mat.resource_name.to_lower()
		if stem == "black_creek_depot" and material_name == "operator bay glazing":
			mesh.material_override = mat
			mesh.add_to_group(&"town_operator_bay")
		elif "glass" in material_name and stem in ["copper_mule", "black_creek_depot"] \
			and "insulator" not in material_name:
			mesh.material_override = mat
			mesh.add_to_group(&"town_saloon_window" if stem == "copper_mule" else &"town_porch_window")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			if stem == "chapel_steeple" and mat.albedo_color.r > 0.58 \
					and mat.albedo_color.g > 0.56 and mat.albedo_color.b > 0.48:
				mat.albedo_color = mat.albedo_color * Color(0.80, 0.78, 0.72)
				mat.roughness = maxf(mat.roughness, 0.94)
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
	_add_interactable(saloon, &"saloon_door", Vector3(0.0, 1.4, -7.94), Vector3(1.8, 2.22, 0.25))

	# 2) Miller & Sons Mercantile & Post Office (X=-18, Z=+41)
	var merc := Node3D.new()
	merc.name = "MillerMercantile"
	merc.position = Vector3(-18.0, 0.0, 41.0)
	sb.add_child(merc)
	_add_model(merc, "miller_mercantile")
	_static_box(merc, "StoreShell", Vector3(0, 2.6, 0.48), Vector3(10, 5.2, 12.64))
	_add_interactable(merc, &"mercantile_door", Vector3(0, 1.40, -6.01), Vector3(1.32, 2.2, 0.25))
	_storefront_wings(merc, 10.0, -6.8, -1.0)
	_tread(merc, "StorePorch", Vector3(0, 0.15, -7.15), Vector3(10.27, 0.30, 0.96))

	# 3) Dr. Arthur Crane's Closed Clinic (X=+15, Z=+40.5)
	var clinic := Node3D.new()
	clinic.name = "CraneClinic"
	clinic.position = Vector3(15.0, 0.0, 40.5)
	sb.add_child(clinic)
	_add_model(clinic, "crane_clinic")
	_static_box(clinic, "ClinicShell", Vector3(0, 2, 0.48), Vector3(8, 4, 9.04))
	_tread(clinic, "PorchFloor", Vector3(0, 0.15, -5.79), Vector3(8, 0.30, 1.85))
	_tread(clinic, "PorchStep", Vector3(0, 0.075, -7.02), Vector3(4.2, 0.15, 0.58), null, &"stairs")
	_add_interactable(clinic, &"clinic_door", Vector3(0, 1.40, -4.20), Vector3(1.32, 2.2, 0.25))
	_add_interactable(clinic, &"clinic_plaque", Vector3(0.0, 3.13, -6.74), Vector3(3.4, 0.8, 0.24))
	_static_box(clinic, "ClinicWingsLeft", Vector3(-2.34, 1.55, -4.54), Vector3(3.32, 2.9, 0.92))
	_static_box(clinic, "ClinicWingsRight", Vector3(2.34, 1.55, -4.54), Vector3(3.32, 2.9, 0.92))

	# 4) Mrs. Hargrove's Boarding House — Elias's Lodging (X=+31, Z=+40.5)
	var bh := Node3D.new()
	bh.name = "HargroveBoardingHouse"
	bh.position = Vector3(31.0, 0.0, 40.5)
	sb.add_child(bh)
	bh.add_child(HARGROVE_SCENE.instantiate())
	_tread(bh, "PorchFloor", Vector3(0.0, 0.23, -5.38), Vector3(7.90, 0.46, 2.18))
	_tread(bh, "PorchStep", Vector3(-1.46, 0.15, -6.73), Vector3(2.20, 0.30, 0.56), plank, &"stairs")
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
	_add_interactable(bh, &"boarding_door", Vector3(-1.46, 1.55, -4.36), Vector3(1.26, 2.18, 0.25))

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
	_static_box(comp, "OfficeShell", Vector3(0, 2.8, -0.48), Vector3(9, 5.6, 9.04))
	_add_interactable(comp, &"assay_door", Vector3(0, 1.40, 4.2), Vector3(1.32, 2.2, 0.25))
	_storefront_wings(comp, 9.0, 5.0, 1.0)
	TownOilLight.cage(comp, Vector3(1.21, 2.71, 5.17), 0.55, 6.0).add_to_group(&"town_oil_flame")

	# 2) Chronicle Print Shop (X=-13, Z=+8.5)
	var print_shop := Node3D.new()
	print_shop.name = "ChroniclePrintShop"
	print_shop.position = Vector3(-13.0, 0.0, 8.5)
	nb.add_child(print_shop)
	_add_model(print_shop, "chronicle_print_shop")
	_static_box(print_shop, "PressShell", Vector3(0, 2.5, -0.48), Vector3(6, 5, 8.54))
	_add_interactable(print_shop, &"chronicle_door", Vector3(0, 1.40, 3.95), Vector3(1.32, 2.2, 0.25))
	_storefront_wings(print_shop, 6.0, 4.75, 1.0)

	var smithy := _add_model(nb, "kowalski_blacksmith", Vector3(-46, 0, 13))
	_static_box(smithy, "SmithyShell", Vector3(0, 2.75, 0), Vector3(10.4, 5.05, 8.45))
	var jail := _add_model(nb, "stone_calaboose", Vector3(26, 0, 6))
	_static_box(jail, "CalabooseShell", Vector3(0, 1.56, 0), Vector3(5, 3.12, 5.8))
	_add_interactable(smithy, &"smithy_door", Vector3(2.0, 1.85, 4.43), Vector3(3.25, 3.30, 0.26))
	_add_interactable(jail, &"calaboose_door", Vector3(0, 1.50, 3.36), Vector3(1.50, 2.35, 0.23))
	_add_model(self, "roadside_props")
	_static_box(self, "WagonCollision", Vector3(-9, 1.15, 27), Vector3(4.8, 1.8, 2.2))

func _storefront_wings(parent: Node3D, width: float, facade_z: float, facing: float) -> void:
	const VESTIBULE := 1.34
	for side in [-1.0, 1.0]:
		_static_box(parent, "WindowWing", Vector3(side * (width + VESTIBULE) / 4, 1.49,
			facade_z - facing * 0.45), Vector3((width - VESTIBULE) * 0.5, 2.98, 0.91))
	_tread(parent, "DoorLanding", Vector3(0, 0.15, facade_z - facing * 0.30), Vector3(VESTIBULE, 0.30, 1.37))

func _build_south_hillside_backdrop() -> void:
	var bg := Node3D.new()
	bg.name = "HillsideBackdrop"
	add_child(bg)
	HILLSIDE.new().build(bg)
	var chapel := _add_model(bg, "chapel_steeple", CHAPEL_ORIGIN)
	var lot := _solid_mat(Color("635b43"))
	var earth := _box(chapel, "ChurchyardBank", Vector3(0.0, -0.34, -1.0),
		Vector3(15.6, 0.55, 14.0), lot, false)
	_static_box(chapel, "ChurchyardGround", earth.position, earth.size)
	_build_chapel_collision(chapel)
	_add_interactable(chapel, &"chapel_door", Vector3(0.0, 1.35, -4.98), Vector3(1.45, 2.35, 0.35))
	_build_chapel_bell(chapel)

func _build_creek_bank_ramps(parent: Node3D) -> void:
	const Z_MIN := -30.0
	const Z_MAX := 48.0
	const BED_Y := -0.44
	const GROUND_Y := 0.02
	var mud_mat := _mat("stone_foundation_128.png", Vector3(14.0, 2.0, 1.0), Color(0.68, 0.62, 0.55))
	for side_spec in [
		["WestCreekBankRamp", 42.6, GROUND_Y, 45.4, BED_Y],
		["EastCreekBankRamp", 48.6, BED_Y, 51.4, GROUND_Y],
	]:
		var x0: float = side_spec[1]
		var y0: float = side_spec[2]
		var x1: float = side_spec[3]
		var y1: float = side_spec[4]
		var faces := PackedVector3Array([
			Vector3(x0, y0, Z_MIN), Vector3(x1, y1, Z_MIN), Vector3(x0, y0, Z_MAX),
			Vector3(x1, y1, Z_MIN), Vector3(x1, y1, Z_MAX), Vector3(x0, y0, Z_MAX),
		])
		var body := StaticBody3D.new()
		body.name = String(side_spec[0])
		body.add_to_group(&"street_tread")
		FootstepSurfaceResolver.tag(body, &"wet_mud")
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in faces:
			st.set_uv(Vector2(p.x, p.z) * 0.25)
			st.add_vertex(p)
		st.generate_normals()
		var vis := MeshInstance3D.new()
		vis.name = "SlopeMesh"
		vis.mesh = st.commit()
		vis.material_override = mud_mat
		body.add_child(vis)
		parent.add_child(body)
	for stone_spec in [
		[46.0, -0.35, 17.5, Vector3(0.85, 0.22, 0.90)],
		[47.4, -0.34, 19.2, Vector3(0.75, 0.24, 0.80)],
		[46.2, -0.35, 26.8, Vector3(0.90, 0.22, 0.78)],
		[47.8, -0.34, 28.4, Vector3(0.82, 0.24, 0.88)],
	]:
		var cobble := _box(parent, "SteppingStone", Vector3(stone_spec[0], stone_spec[1], stone_spec[2]),
			stone_spec[3], mud_mat, true)
		cobble.add_to_group(&"street_tread")
		FootstepSurfaceResolver.tag(cobble, &"stone")

func _build_creek_water_trigger(parent: Node3D) -> void:
	var trigger := Area3D.new()
	trigger.name = "CreekWaterTrigger"
	trigger.position = Vector3(47.0, -0.18, 9.0)
	trigger.monitoring = true
	trigger.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.6, 0.85, 76.0)
	cs.shape = box
	trigger.add_child(cs)
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			creek_waded.emit())
	parent.add_child(trigger)

func _build_chapel_collision(chapel: Node3D) -> void:
	_static_box(chapel, "ChapelNave", Vector3(0, 2.75, 0), Vector3(7.33, 5.5, 9.82))
	for mesh: MeshInstance3D in chapel.find_children("*", "MeshInstance3D", true, false):
		var label := String(mesh.name)
		var bounds: AABB = chapel.global_transform.affine_inverse() * (mesh.global_transform * mesh.get_aabb())
		if label.begins_with("Path tread") or label.begins_with("Entry plinth") \
				or label.begins_with("Threshold") or label.begins_with("Gate threshold") \
				or label.begins_with("Churchyard "):
			_tread(chapel, "ChapelTread", bounds.get_center(), bounds.size, null, &"stone")
		elif label.begins_with("Fence rail") or label.begins_with("Revetment capstone"):
			_static_box(chapel, "ChurchyardEdge", bounds.get_center(), bounds.size)

## A cast-bell toll at noon and again at dusk, spatialised to the open belfry bay.
## The bell hangs in the lantern's south bay (local z = -3.10) facing the street, so
## the emitter is placed inside the bell throat and left unattenuated enough to
## carry 100 m to the boardwalk — it is the town's one distant landmark sound, not
## a stinger, and `_ring_chapel_bell` only fires it twice a day.
func _build_chapel_bell(chapel: Node3D) -> void:
	var bell := AudioStreamPlayer3D.new()
	bell.name = "ChapelBell"
	bell.stream = preload("res://audio/sfx/town/chapel_bell_toll.wav")
	# Inside the bell: the bronze body spans local y 7.30..8.52 at z -3.54..-2.66.
	bell.position = Vector3(0, 8.10, -3.10)
	bell.bus = &"Ambience"
	bell.unit_size = 22.0
	bell.max_distance = 190.0
	bell.volume_db = -9.0
	bell.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	bell.panning_strength = 0.85
	bell.add_to_group(&"town_chapel_bell")
	chapel.add_child(bell)

func _build_boundary_colliders() -> void:
	var bounds := Node3D.new()
	bounds.name = "WorldBounds"
	add_child(bounds)
	var specs := [
		["North", Vector3(0.0, 2.0, -29.5), Vector3(130.0, 4.0, 1.0)],
		["South", Vector3(0.0, 2.0, 47.0), Vector3(130.0, 4.0, 1.0)],
		["West", Vector3(-56.0, 2.0, 9.0), Vector3(1.0, 4.0, 80.0)],
		["East", Vector3(54.0, 2.0, 9.0), Vector3(1.0, 4.0, 80.0)],
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
