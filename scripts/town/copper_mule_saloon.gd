extends Node3D

const TOWN := "res://scenes/town/black_creek_exterior.tscn"
const PRINTS := preload("res://scripts/town/period_print_surface.gd")
const STOVE := preload("res://assets/models/stove_v1/stove_static.res")
const TEXTURES := "res://assets/textures/town_v2/"

var _wood: StandardMaterial3D
var _pine: StandardMaterial3D
var _brass: StandardMaterial3D
var _iron: StandardMaterial3D
var _departing := false
var _exit: Interactable

func _ready() -> void:
	_wood = _pbr("mahogany", Color("cc987a"), Vector3(3, 1.5, 1), 0.43)
	_pine = _pbr("plank", Color("c6ad91"), Vector3(3, 2, 1), 0.9)
	_brass = _paint("b68a4e", 0.46, 0.65)
	_iron = _paint("312a25", 0.65, 0.48)
	_shell()
	_bar()
	_furniture()
	_lights()
	_build_exit()

func _shell() -> void:
	var wallpaper := _pbr("plaster", Color("a35e55"), Vector3(4, 3, 1), 0.92)
	wallpaper.albedo_texture = preload("res://assets/textures/town_v2/print/damask.png")
	var tin := _paint("b18f69", 0.69, 0.33)
	var floor_mat := _pbr("plank", Color("c4aa91"), Vector3(5, 6, 1), 0.90)
	_box("Pine flooring", Vector3(0, -0.10, 0), Vector3(10.8, 0.20, 13.2), floor_mat, true)
	_box("Pressed tin field", Vector3(0, 4.30, 0), Vector3(10.8, 0.10, 13.2), tin)
	for x in range(-5, 6):
		for z in range(-6, 7):
			var p := Vector3(x, 4.231, z)
			_box("Stamped tin square", p, Vector3(0.97, 0.06, 0.97), tin)
			var jewel := _box("Embossed lozenge", p + Vector3.DOWN * 0.03, Vector3(0.54, 0.035, 0.54), tin)
			jewel.rotation_degrees.y = 45.0
	for z in [-5.6, -2.8, 0.0, 2.8, 5.6]:
		_box("Ceiling girder", Vector3(0, 4.02, z), Vector3(10.7, 0.28, 0.22), _wood)
	for x in [-5.4, 5.4]:
		_box("Papered flank", Vector3(x, 2.15, 0), Vector3(0.20, 4.3, 13.2), wallpaper, true)
		_box("Tall wainscot", Vector3(x * 0.983, 0.575, 0), Vector3(0.21, 1.15, 13.2), _wood)
		_box("Milled dado rail", Vector3(x * 0.978, 1.15, 0), Vector3(0.24, 0.10, 13.2), _wood)
		for i in 22:
			_box("Wainscot stile", Vector3(x * 0.957, 0.57, i * 0.59 - 6.2), Vector3(0.04, 1.01, 0.057), _wood)
	_box("Back wall", Vector3(0, 2.15, 6.54), Vector3(10.8, 4.3, 0.16), wallpaper, true)
	_box("Back dado", Vector3(0, 0.58, 6.42), Vector3(10.8, 1.16, 0.13), _wood)
	_front_wall(wallpaper)
	for i in 22:
		var p := Vector3(sin(i * 2.39) * (0.28 + 0.023 * i), 0.002 + i * 0.0002, -6.15 + i * 0.13)
		var mud := _paint("554333" if i % 3 == 0 else "685544", 0.96)
		mud.albedo_texture = preload("res://assets/textures/town_v2/road_albedo.png")
		var track := _disc("Tracked-in mud", p, 0.12 + sin(i * 1.2) * 0.06, 0.004, mud, 7)
		track.scale.z = 1.5

func _front_wall(wallpaper: Material) -> void:
	var pane := _paint("c6a388", 0.24, 0.13)
	pane.emission_enabled = true
	pane.emission = Color("d0b68f")
	pane.emission_energy_multiplier = 0.62
	for x in [-3.35, 3.35]:
		_box("Front kickplate", Vector3(x, 0.45, -6.52), Vector3(4.12, 0.9, 0.20), _wood, true)
		_box("Front header", Vector3(x, 3.56, -6.52), Vector3(4.12, 1.48, 0.20), wallpaper, true)
		var glass := _box("Drawn cylinder glass", Vector3(x, 1.86, -6.58), Vector3(4.08, 1.92, 0.06), pane, true)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(-2, 3):
			_box("Shop window mullion", Vector3(x + i * 1.03, 1.86, -6.46), Vector3(0.09, 2.01, 0.14), _wood)
		for y in [0.87, 2.36, 2.86]:
			_box("Window transom rail", Vector3(x, y, -6.46), Vector3(4.16, 0.09, 0.14), _wood)
	_box("Door frame", Vector3(0, 2.99, -6.47), Vector3(2.58, 2.63, 0.19), _wood, true)
	_box("Vestibule backing", Vector3(0, 1.12, -6.80), Vector3(2.57, 2.25, 0.10), _iron, true)
	for x in [-0.67, 0.67]:
		_box("Spring-hinged door leaf", Vector3(x, 1.0, -6.51), Vector3(1.13, 1.06, 0.065), _wood)
		_box("Batwing curved shoulder", Vector3(x * 1.26, 1.53, -6.51), Vector3(0.77, 0.10, 0.063), _wood)
		for dx in [-0.33, 0.0, 0.33]:
			_box("Raised stile", Vector3(x + dx, 1, -6.46), Vector3(0.055, 0.89, 0.037), _wood)

func _bar() -> void:
	var p := Vector3(2.40, 0, 3.78)
	_box("Counter cabinet", p + Vector3.UP * 0.51, Vector3(5.02, 1.02, 0.75), _wood, true)
	_box("Rounded bar cap", p + Vector3.UP * 1.017, Vector3(5.20, 0.106, 0.95), _wood)
	_box("Bar skirting", p + Vector3.UP * 0.09, Vector3(5.12, 0.18, 0.81), _wood)
	for i in 7:
		var a := p + Vector3(-2.14 + i * 0.71, 0.57, -0.39)
		_box("Mahogany panel surround", a, Vector3(0.62, 0.70, 0.063), _wood)
		_box("Raised panel", a + Vector3.FORWARD * 0.04, Vector3(0.47, 0.53, 0.058), _wood)
	_rod("Brass foot rail", Vector3(-0.12, 0.18, 3.16), Vector3(4.94, 0.18, 3.16), 0.034, _brass)
	for x in [0.02, 1.60, 3.19, 4.83]:
		_rod("Foot-rail mounting bracket", Vector3(x, 0.18, 3.16), Vector3(x, 0.10, 3.48), 0.027, _brass)
	_box("Back bar case", Vector3(2.38, 1.86, 6.06), Vector3(5.14, 3.46, 0.49), _wood, true)
	var silver := _paint("aaa8a0", 0.13, 0.91)
	for x in [0.81, 2.38, 3.95]:
		_box("Bevelled silvered plate", Vector3(x, 2.21, 5.792), Vector3(1.34, 1.50, 0.034), silver)
		for y in [1.43, 3.01]:
			_box("Gilt mirror edge", Vector3(x, y, 5.769), Vector3(1.42, 0.034, 0.07), _brass)
	for y in [1.09, 1.75, 2.35, 3.21, 3.46]:
		_box("Backbar moulding", Vector3(2.38, y, 5.71), Vector3(5.22, 0.10, 0.66), _wood)
	for x in [-0.11, 1.56, 3.16, 4.88]:
		_disc("Turned pilaster", Vector3(x, 2.26, 5.63), 0.081, 1.92, _wood, 12)
		for y in [1.35, 3.15]:
			_box("Capital", Vector3(x, y, 5.61), Vector3(0.22, 0.14, 0.24), _wood)
	for shelf in [1.15, 1.81, 2.41]:
		for i in 20:
			if i % 5 == 2 and shelf > 2.0:
				continue
			_bottle(Vector3(0.12 + i * 0.237, shelf, 5.59 - 0.03 * cos(i * 3)), i)
	_disc("Copper spittoon", Vector3(0.21, 0.09, 2.91), 0.20, 0.18, _brass, 14)
	_disc("Spittoon rim", Vector3(0.21, 0.193, 2.91), 0.21, 0.025, _brass, 14)
	_box("Silver Spur mount", Vector3(4.18, 1.14, 3.75), Vector3(0.63, 0.13, 0.58), _wood)
	_frame("Slate price board", Vector3(-1.15, 2.29, 6.38), Vector2(1.23, 1.14),
		preload("res://assets/textures/town_v2/print/menu.png"))

func _bottle(p: Vector3, i: int) -> void:
	var glass := _paint(["566344", "784930", "765e37", "55473b"][i % 4], 0.29, 0.13)
	var h := 0.18 + 0.024 * (i % 5)
	var r := 0.05 + 0.009 * (i % 3)
	_disc("Moulded bottle body", p + Vector3.UP * h * 0.5, r, h, glass, 6 + 2 * (i % 2))
	_disc("Bottleneck", p + Vector3.UP * (h + 0.037), r * 0.48, 0.077, glass, 8)
	_disc("Cork", p + Vector3.UP * (h + 0.085), r * 0.40, 0.027, _brass, 8)
	if i % 3 != 0:
		PRINTS.place(self, "Rye label", p + Vector3(0, h * 0.47, -r - 0.002), Vector2(r * 1.56, h * 0.57),
			preload("res://assets/textures/town_v2/print/whiskey.png"), Vector3(0, 180, 0))

func _furniture() -> void:
	var baize := _paint("405747", 0.98)
	_disc("Chuck-a-luck rim", Vector3(-3.58, 0.80, -0.89), 0.66, 0.11, _wood, 16)
	_disc("Green gaming cloth", Vector3(-3.58, 0.863, -0.89), 0.59, 0.017, baize, 16)
	_disc("Pedestal", Vector3(-3.58, 0.40, -0.89), 0.14, 0.78, _wood, 10)
	_box("Round table collision", Vector3(-3.58, 0.43, -0.89), Vector3(1.02, 0.86, 1.02), null, true)
	_table(Vector3(-3.57, 0, 1.56), Vector2(1.80, 0.91), baize)
	for p: Vector3 in [Vector3(2.92, 0, -3.38), Vector3(-2.84, 0, -3.77),
			Vector3(2.89, 0, -0.51), Vector3(-3.72, 0, 4.09)]:
		_table(p, Vector2(1.24, 0.92), _pine)
		_chair(p + Vector3(0, 0, 0.67), false)
		_chair(p + Vector3(0, 0, -0.69), true)
		_disc("Pewter cup", p + Vector3(0.31, 0.84, 0.21), 0.053, 0.12, _brass, 9)
	for y in [0.49, 1.06]:
		_box("Alcove banquette", Vector3(-4.87, y, 4.38), Vector3(0.68, 0.32, 2.63), _wood, true)
	_mesh("Cast-iron stove", Vector3(-4.40, 0, 5.65), STOVE, null)
	_box("Stove collision", Vector3(-4.40, 0.42, 5.65), Vector3(0.65, 0.84, 0.63), null, true)
	_rod("Cast-iron flue", Vector3(-4.40, 0.95, 5.65), Vector3(-4.40, 4.23, 5.65), 0.10, _iron)
	_piano()
	_frame("Silver Spur broadside", Vector3(-5.263, 2.18, 0.27), Vector2(0.76, 0.59),
		preload("res://assets/textures/town_v2/print/silver_spur.png"), 90)
	_frame("Imported beers broadside", Vector3(-5.263, 2.15, 2.26), Vector2(0.57, 0.47),
		preload("res://assets/textures/town_v2/print/beer.png"), 90)

func _table(p: Vector3, dims: Vector2, face: Material) -> void:
	_box("Beaded table edge", p + Vector3.UP * 0.735, Vector3(dims.x, 0.12, dims.y), _wood, true)
	_box("Table top", p + Vector3.UP * 0.80, Vector3(dims.x - 0.04, 0.03, dims.y - 0.04), face)
	for x in [-0.42, 0.42]:
		for z in [-0.41, 0.41]:
			_box("Table leg", p + Vector3(x * dims.x, 0.35, z * dims.y), Vector3(0.074, 0.70, 0.074), _wood)

func _chair(p: Vector3, flip: bool) -> void:
	_box("Chair seat", p + Vector3.UP * 0.47, Vector3(0.42, 0.07, 0.40), _wood, true)
	var side := -1.0 if flip else 1.0
	for x in [-0.163, 0.163]:
		_box("Front chair leg", p + Vector3(x, 0.23, -0.15 * side), Vector3(0.041, 0.46, 0.041), _wood)
		_box("Back chair stile", p + Vector3(x, 0.48, 0.16 * side), Vector3(0.041, 0.96, 0.041), _wood)
	for y in [0.65, 0.91]:
		_box("Chair back rail", p + Vector3(0, y, 0.16 * side), Vector3(0.38, 0.065, 0.038), _wood)

func _piano() -> void:
	var p := Vector3(-2.9, 0, 5.93)
	_box("Upright piano cabinet", p + Vector3.UP * 0.67, Vector3(1.62, 1.34, 0.58), _wood, true)
	_box("Keybed lip", p + Vector3(0, 0.75, -0.34), Vector3(1.48, 0.15, 0.31), _wood)
	var ivory := _paint("cfbe9b", 0.74)
	for i in 41:
		var a := p + Vector3((i - 20) * 0.033, 0.84, -0.36)
		_box("Ivory key", a, Vector3(0.030, 0.031, 0.24), ivory)
		if i % 7 not in [2, 6]:
			_box("Ebony key", a + Vector3(0.014, 0.023, 0.056), Vector3(0.018, 0.04, 0.135), _iron)
	for dx in [-0.58, 0, 0.58]:
		_box("Reeded music desk", p + Vector3(dx, 1.07, -0.304), Vector3(0.34, 0.33, 0.05), _wood)
	var stool := p + Vector3(0, 0, -0.87)
	_disc("Piano stool seat", stool + Vector3.UP * 0.48, 0.26, 0.09, _wood, 12)
	_disc("Piano stool screw", stool + Vector3.UP * 0.23, 0.11, 0.46, _iron, 10)
	_box("Symphonion cabinet", Vector3(-1.68, 0.48, 5.97), Vector3(0.57, 0.96, 0.56), _wood, true)
	_frame("Framed railroad lithograph", Vector3(-2.96, 2.28, 6.37), Vector2(0.69, 0.90),
		preload("res://assets/textures/town_v2/print/calendar_april_1890.png"))

func _lights() -> void:
	var white := _paint("dec8a4", 0.58)
	white.emission_enabled = true
	white.emission = Color("ffcf8a")
	white.emission_energy_multiplier = 0.78
	for z in [-2.62, 1.82]:
		var hub := Vector3(0.32, 3.02, z)
		_rod("Chandelier suspension", hub, hub + Vector3.UP * 1.23, 0.027, _brass)
		_disc("Chandelier reservoir", hub, 0.16, 0.18, _brass, 12)
		for i in 5:
			var a := i * TAU / 5.0
			var arm := Vector3(cos(a), 0, sin(a)) * 0.64
			var bowl := hub + arm + Vector3.UP * 0.08
			_rod("Kerosene chandelier branch", hub, bowl, 0.028, _brass)
			_disc("Burner gallery", bowl, 0.11, 0.066, _brass, 12)
			var globe := MeshInstance3D.new()
			var shape := SphereMesh.new()
			shape.radius = 0.146
			shape.height = 0.225
			shape.radial_segments = 12
			shape.rings = 6
			globe.name = "MilkGlass"
			globe.mesh = shape
			globe.material_override = white
			globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			globe.position = bowl + Vector3.UP * 0.115
			add_child(globe)
		_light(hub + Vector3.DOWN * 0.15, Color("ffca92"), 1.68, 8.4)
	_light(Vector3(2.63, 2.94, 4.70), Color("ffd7a4"), 1.04, 5.4)
	_light(Vector3(-3.49, 2.35, 4.67), Color("f3c295"), 0.93, 4.8)
	for x in [-3.3, 3.3]:
		var daylight := SpotLight3D.new()
		daylight.name = "FacadeWindowDaylight"
		daylight.position = Vector3(x, 2.36, -7.35)
		daylight.light_color = Color("ffe2b9")
		daylight.light_energy = 6.2
		daylight.spot_range = 15.5
		daylight.spot_angle = 46.0
		daylight.spot_attenuation = 0.80
		daylight.shadow_enabled = true
		daylight.light_size = 0.19
		daylight.shadow_blur = 1.4
		add_child(daylight)
		daylight.look_at(Vector3(x * 0.65, 0.3, 2.4), Vector3.UP)

func _light(pos: Vector3, tone: Color, energy: float, reach: float) -> void:
	var omni := OmniLight3D.new()
	omni.light_color = tone
	omni.light_energy = energy
	omni.omni_range = reach
	omni.position = pos
	add_child(omni)

func _build_exit() -> void:
	_exit = Interactable.new()
	_exit.name = "SaloonExit"
	_exit.position = Vector3(0, 1.29, -6.24)
	var shape := CollisionShape3D.new()
	var trigger := BoxShape3D.new()
	trigger.size = Vector3(2.18, 2.18, 0.36)
	shape.shape = trigger
	_exit.add_child(shape)
	add_child(_exit)
	_exit.interacted.connect(_return_to_town)
	var pause := PauseMenu.new()
	add_child(pause)
	refresh_locale()
	var player := $Player as PlayerController
	player.aim_at(Vector3(0, 1.65, 4.0))

func refresh_locale() -> void:
	_exit.prompt_text = GameLocale.pick("Выйти на Главную улицу", "Return to Main Street")

func _return_to_town() -> void:
	if _departing:
		return
	_departing = true
	var campaign := get_node_or_null("/root/CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.pending_spawn_point = &"saloon_porch"
	get_tree().change_scene_to_file(TOWN)

func _frame(title: String, at: Vector3, size: Vector2, tex: Texture2D, angle := 180.0) -> void:
	var frame := _box(title, at, Vector3(size.x + 0.14, size.y + 0.14, 0.086), _wood)
	frame.rotation_degrees.y = angle
	var normal := Vector3(sin(deg_to_rad(angle)), 0, cos(deg_to_rad(angle)))
	PRINTS.place(self, title + " print", at + normal * 0.047, size, tex, Vector3(0, angle, 0))

func _box(title: String, at: Vector3, size: Vector3, mat: Material, collide := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var mi := _mesh(title, at, shape, mat)
	mi.visible = mat != null
	if collide:
		var body := StaticBody3D.new()
		body.position = at
		var col := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		col.shape = volume
		body.add_child(col)
		add_child(body)
	return mi

func _disc(title: String, at: Vector3, radius: float, height: float, mat: Material, sides: int) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = sides
	shape.rings = 0
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return _mesh(title, at, shape, mat)

func _rod(title: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var rod := _disc(title, (a + b) / 2, radius, a.distance_to(b), mat, 8)
	rod.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _mesh(title: String, at: Vector3, shape: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.position = at
	mi.mesh = shape
	mi.material_override = mat
	add_child(mi)
	return mi

func _paint(html: String, rough: float, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(html)
	material.roughness = rough
	material.metallic = metal
	return material

func _pbr(stem: String, tint: Color, repeat: Vector3, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = rough
	mat.uv1_scale = repeat
	mat.albedo_texture = load(TEXTURES + stem + "_albedo.png") as Texture2D
	mat.normal_enabled = true
	mat.normal_texture = load(TEXTURES + stem + "_normal.png") as Texture2D
	mat.normal_scale = 0.54
	mat.roughness_texture = load(TEXTURES + stem + "_roughness.png") as Texture2D
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return mat
