extends Node3D
## Small, phase-dependent signs of occupation; none carry gameplay cues.
##
## This is the restraint pass: a thin thread from the smithy's banked forge fire,
## low mist lying in the creek reach at dawn, the roadside grass and the hanging
## lanterns moving on the same gust, and two spatial sounds the player can
## localise — the creek from the east end of the street and one wren in the
## cottonwoods. Every clip is a licensed recording already in the project pool;
## nothing here is synthesised, and no prop sits on a walk line.

const HUM := preload("res://audio/sfx/ambience/wire_sing.wav")
const SALOON := preload("res://audio/sfx/town/saloon_through_wall.wav")
const CREEK := preload("res://audio/sfx/town/creek_rush_loop.wav")
const WREN := preload("res://audio/sfx/town/morning_birds_wake.wav")
const MIST_SHADER := preload("res://materials/shaders/yard_mist.gdshader")

## Creek mist sheets: `w` across the channel, `h` along it, laid flat on the water.
## Both sit between the water surface (y -0.10) and the bridge deck (y 0.39), so a
## sheet passing under the timbers drifts below the planks instead of slicing
## through them as a flat plane.
const MIST_LAYERS: Array[Dictionary] = [
	{"y": 0.05, "z": 18.0, "w": 9.6, "h": 52.0, "density": 0.17, "speed": 0.020, "phase": 0.6},
	{"y": 0.24, "z": 12.0, "w": 12.4, "h": 44.0, "density": 0.11, "speed": -0.013, "phase": 3.9},
]

var _steam: GPUParticles3D
var _saloon: AudioStreamPlayer3D
var _puffs: ImageTexture
var _birds: Array[Node3D] = []
var _signs: Array[Node3D] = []
var _lanterns: Array[Node3D] = []
var _lantern_rest: Array[Vector3] = []
var _grass: Array[Node3D] = []
var _mist: Array[MeshInstance3D] = []
var _wren: AudioStreamPlayer3D
var _wren_wait := 18.0
var _headless := false
var _creek_reach: AudioStreamPlayer3D
var _wire: AudioStreamPlayer3D
var _elapsed := 0.0

func build(builder: Node3D, train: Node3D, depot: Vector3, night: bool) -> void:
	# The node tree is built under the headless backend too: every contract these
	# pieces carry (a mist sheet that only shows at DAWN, a bar inside a real
	# aperture, a wren that stays quiet at dusk) has to be assertable in the suites,
	# and those all run headless. Only playback and per-frame work are gated.
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		set_process(false)
	_puffs = _soft_particle()
	if not night:
		_plume(self, depot + Vector3(2.10, 5.43, 1.55), Color(0.50, 0.51, 0.52, 0.34), 0.9, 0.43)
		_plume(self, Vector3(1.72, 9.025, 45.25), Color(0.54, 0.53, 0.52, 0.35), 1.20, 0.45)
		_plume(self, Vector3(34.58, 7.79, 40.79), Color(0.56, 0.55, 0.54, 0.34), 1.0, 0.45)
		# Kowalski's forge chimney tops out at local (-3.25, 7.73, -2.25) on a shop
		# placed at (-46, 0, 13). A banked fire gives a thin, slow thread, so this
		# plume is roughly half the width of the stove plumes above, not a bonfire.
		_plume(self, Vector3(-49.25, 7.80, 10.75), Color(0.58, 0.57, 0.55, 0.30), 0.62, 0.30)
		_steam = _plume(train, Vector3(-3.1, 0.86, 0.50), Color(0.81, 0.83, 0.85, 0.39), 1.0, 0.27)
		_steam.emitting = false
		_saloon = _loop("SaloonThroughWall", SALOON, Vector3(-0.1, 1.62, 34.6), -22.5, 12.0, 2.2)
		# The creek emitter lives on the bridge (36 m reach). A second, quieter bed
		# at the southern reach makes the water audible from the east boardwalk long
		# before the player reaches the timbers.
		_creek_reach = _loop("CreekReach", CREEK, Vector3(45.4, 0.16, 2.0), -19.0, 40.0, 7.0)
		if not _headless:
			_creek_reach.play()
		_wren = _one_shot("CottonwoodWren", WREN, Vector3(56.5, 5.20, 19.5), -20.0, 62.0, 8.5)
		_creek_mist()
		for i in 3:
			_birds.append(_crow())
		_bind_sign(builder.find_child("CopperMuleSaloon", true, false), "Print_saloon", Vector3(3.96, 2.875, -8.69))
		_bind_sign(builder.find_child("MillerMercantile", true, false), "Print_post", Vector3(3.30, 2.875, -7.99))
	_collect_wind_catchers(builder)
	_wire = _loop("DepotWire", HUM, depot + Vector3(-5.0, 3.6, 4.0), -22.0, 21.0, 4.8)
	if not _headless:
		_wire.play()

## Grass tufts and hanging lanterns take the same gust, so the street reads as one
## windy place instead of a set of independently animated props.
func _collect_wind_catchers(builder: Node3D) -> void:
	for tuft in get_tree().get_nodes_in_group(&"town_sway_grass"):
		if tuft is Node3D and builder.is_ancestor_of(tuft):
			_grass.append(tuft as Node3D)
	for flame in get_tree().get_nodes_in_group(&"town_oil_flame"):
		if not (flame is Node3D) or not builder.is_ancestor_of(flame):
			continue
		# `TownOilLight.cage()` and `.mount()` both hang the fixture under its own
		# hook, and that fixture node is the flame's parent — so yawing it swings
		# lantern and wick together about the hanger. Interior lamps are skipped:
		# they sit south of z 36, inside the boarding house or the saloon.
		var hang := flame.get_parent() as Node3D
		if hang == null or (flame as Node3D).global_position.z > 35.0:
			continue
		_lanterns.append(hang)
		_lantern_rest.append(hang.rotation)

func _bind_sign(building: Node3D, mesh_prefix: String, hinge: Vector3) -> void:
	if building == null:
		return
	var parts: Array[Node3D] = []
	for mesh in building.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).begins_with(mesh_prefix):
			parts.append(mesh)
	if parts.is_empty():
		return
	var pivot := Node3D.new()
	pivot.position = hinge
	building.add_child(pivot)
	for part in parts:
		part.reparent(pivot, true)
	_signs.append(pivot)

func apply_preset(preset: StringName) -> void:
	if _steam != null:
		_steam.emitting = preset == &"DAWN"
	for plane in _mist:
		plane.visible = preset == &"DAWN"
	if _saloon != null:
		if preset in [&"DAY_CLEAR", &"DAY_GOLDEN", &"DUSK"]:
			if not _saloon.playing and not _headless:
				_saloon.play()
		else:
			_saloon.stop()
	if _wren != null and preset in [&"NIGHT_APPROACH", &"DUSK"]:
		_wren.stop()
		_wren_wait = 18.0

func _loop(title: String, stream: AudioStream, p: Vector3, gain: float,
		distance: float, reference: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = title
	source.stream = stream
	source.bus = &"Ambience"
	source.position = p
	source.volume_db = gain
	source.max_db = gain
	source.unit_size = reference
	source.max_distance = distance
	source.finished.connect(source.play)
	add_child(source)
	return source

func _one_shot(title: String, stream: AudioStream, p: Vector3, gain: float,
		distance: float, reference: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = title
	source.stream = stream
	source.bus = &"Ambience"
	source.position = p
	source.volume_db = gain
	source.max_db = gain
	source.unit_size = reference
	source.max_distance = distance
	add_child(source)
	return source

## Two flat sheets of the yard-mist shader laid on the reach, so the dawn creek
## has depth without a fog volume that would grey out the whole valley.
func _creek_mist() -> void:
	for spec: Dictionary in MIST_LAYERS:
		var material := ShaderMaterial.new()
		material.shader = MIST_SHADER
		material.set_shader_parameter("night_color", Color(0.30, 0.34, 0.37))
		material.set_shader_parameter("dawn_color", Color(0.62, 0.67, 0.70))
		material.set_shader_parameter("density", float(spec["density"]))
		material.set_shader_parameter("drift_speed", float(spec["speed"]))
		material.set_shader_parameter("noise_scale", 1.7)
		material.set_shader_parameter("phase_offset", float(spec["phase"]))
		material.set_shader_parameter("dawn_amount", 1.0)
		material.set_shader_parameter("moon_dim", 0.0)
		var quad := QuadMesh.new()
		quad.size = Vector2(float(spec["w"]), float(spec["h"]))
		quad.material = material
		var sheet := MeshInstance3D.new()
		# Sibling names must stay unique, or the second sheet is renamed on add and
		# the DAWN gate cannot find it by name.
		sheet.name = "CreekMist%d" % _mist.size()
		sheet.mesh = quad
		sheet.position = Vector3(47.0, float(spec["y"]), float(spec["z"]))
		sheet.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.visible = false
		add_child(sheet)
		_mist.append(sheet)

func _plume(parent: Node3D, p: Vector3, color: Color, width: float, speed: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = p
	particles.amount = 19
	particles.lifetime = 6.2
	particles.preprocess = 5.5
	particles.visibility_aabb = AABB(Vector3(-2, -1, -3), Vector3(8, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.54, 1.0, -0.18)
	process.spread = 23.0
	process.gravity = Vector3(0.10, 0.035, -0.03)
	process.initial_velocity_min = speed * 0.62
	process.initial_velocity_max = speed * 1.48
	process.scale_min = 0.45
	process.scale_max = 0.91
	process.color = color
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.13, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.05), Color.WHITE, Color(1, 1, 1, 0.62), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var expand := Curve.new()
	expand.add_point(Vector2(0, 0.35))
	expand.add_point(Vector2(1, 1.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = expand
	process.scale_curve = scale_curve
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puffs
	var quad := QuadMesh.new()
	quad.size = Vector2(width * 2.0, width * 1.28)
	quad.material = material
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	return particles

func _soft_particle() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var p := (Vector2(x, y) - Vector2(31.5, 31.5)) / 31.5
			var edge := p.length() * (1.02 + 0.15 * sin(p.x * 12.0 + p.y * 5.0))
			img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(1.0 - edge, 0.0), 1.55)))
	return ImageTexture.create_from_image(img)

func _crow() -> Node3D:
	var bird := Node3D.new()
	bird.visible = false
	add_child(bird)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.045, 0.046, 0.06)
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var root_pt := Vector3(0, 0, -0.19)
		var tip := Vector3(side * 0.65, -0.04, 0.13)
		var wrist := Vector3(side * 0.36, 0.05, -0.19)
		var tail := Vector3(0, 0, 0.31)
		var trailing := Vector3(side * 0.32, -0.015, 0.14)
		for v in [root_pt, wrist, trailing, wrist, tip, trailing, root_pt, trailing, tail]:
			st.add_vertex(v)
		st.generate_normals()
		st.set_material(ink)
		var wing := MeshInstance3D.new()
		wing.mesh = st.commit()
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bird.add_child(wing)
	return bird

func _process(delta: float) -> void:
	_elapsed += delta
	# One wind, sampled once: two slow swells and a quick flutter, normalised to
	# roughly -1..1 so every follower shares the same gust envelope.
	var gust := sin(_elapsed * 0.37) * 0.5 + sin(_elapsed * 0.71 + 1.3) * 0.3 + sin(_elapsed * 1.63) * 0.2
	for i in _signs.size():
		_signs[i].rotation.x = sin(_elapsed * 1.15 + i * 0.58) * (0.018 + 0.012 * gust)
	for i in _lanterns.size():
		var rest := _lantern_rest[i]
		_lanterns[i].rotation = Vector3(
			rest.x + sin(_elapsed * 1.31 + i * 0.83) * 0.009 * (1.0 + gust),
			rest.y,
			rest.z + sin(_elapsed * 0.97 + i * 1.21) * 0.007 * (1.0 + gust))
	for i in _grass.size():
		_grass[i].rotation = Vector3(
			sin(_elapsed * 1.09 + i * 0.67) * 0.030 * (1.0 + gust), 0.0,
			sin(_elapsed * 1.47 + i * 0.41) * 0.045 * (1.0 + gust))
	for i in _birds.size():
		var time := fposmod(_elapsed - i * 1.4 + 26.0, 67.0) - 26.0
		var bird := _birds[i]
		bird.visible = time > 0.0 and time < 32.0
		if bird.visible:
			bird.position = Vector3(-93.0 + time * 5.0, 25.0 + i * 1.3 + sin(time * 0.39), -73.0 - i * 4.0)
			bird.rotation.y = -PI * 0.5
			for j in 2:
				(bird.get_child(j) as Node3D).rotation.z = (j * 2.0 - 1.0) * sin(time * 10.8) * 0.40
	_tick_wren(delta)

## One wren call every 26-54 s. The recording is a real Carolina wren (TDC, CC0)
## already shipped for the boarding house; the long gaps and the -20 dB placement
## keep it a distant neighbour rather than a soundtrack loop.
func _tick_wren(delta: float) -> void:
	if _wren == null:
		return
	_wren_wait -= delta
	if _wren_wait > 0.0:
		return
	_wren_wait = 26.0 + fposmod(_elapsed * 7.31, 28.0)
	if _wren.stream != null and not _headless:
		_wren.play()
