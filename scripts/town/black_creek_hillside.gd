extends RefCounted
## Visual-only terrain outside the authored collision envelope.
##
## The mesh is a coarse 2 m grid on purpose: it is background, not walkable, and
## the spruce cluster hides most of the faceting. What it must not do is show the
## geometry's own UVs. Those quads are metres wide in y and tens of metres in
## x/z, so a planar projection smears into contour bands — the "stretched" streaks
## visible from the aerial cameras. Every surface here therefore samples the
## town's CC0 stone and clay triplanar from world space through
## black_creek_ground.gdshader in `triplanar_slope` mode, and every open mesh
## border gets a skirt so no camera can see the hill's underside.

const SPRUCE := preload("res://assets/models/town/black_creek_spruce.glb")
const COTTAGES := [
	preload("res://assets/models/town/black_creek_cottage_a.glb"),
	preload("res://assets/models/town/black_creek_cottage_b.glb"),
]
const LOT_X := [-34.0, -12.0, 12.0, 34.0]
const LOT_Z := [58.0, 61.0, 58.0, 60.0]
const LOT_Y := [3.1, 4.2, 3.8, 4.6]
## The valley floor is a half-metre box whose top face sits at y = 0, so the hill
## must dive below that plane or its rim reads as a slot from an aerial camera.
const GRID := 2.0
const SKIRT := -4.0
const COLUMNS := 120
const ROWS := 53

static func build(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 18900414
	_slope(parent, random)
	for i in LOT_X.size():
		var cottage := COTTAGES[i % 2].instantiate() as Node3D
		cottage.position = Vector3(LOT_X[i], LOT_Y[i] - 0.05, LOT_Z[i])
		cottage.rotation.y = random.randf_range(-0.20, 0.20)
		parent.add_child(cottage)
	for i in 128:
		var x := random.randf_range(-107, 99)
		var z := random.randf_range(48, 131)
		if absf(x - 47) < 5 or _near_lot(x, z):
			continue
		var size := random.randf_range(0.49, 1.42)
		var tree_height := size * random.randf_range(0.84, 1.23)
		var yaw := random.randf() * TAU
		var tree := SPRUCE.instantiate() as Node3D
		tree.position = Vector3(x, mesh_grade(x, z) - 0.26, z)
		tree.scale = Vector3(size, tree_height, size)
		tree.rotation.y = yaw
		parent.add_child(tree)
	build_ridge(parent, 177.0, 44.0)
	build_ridge(parent, -164.0, 43.0)
	build_ridge(parent, 153.0, 31.0, true)
	build_ridge(parent, -156.0, 41.0, true)

static func mesh_grade(x: float, z: float) -> float:
	# Interpolate the same triangles as _slope, not the unsampled height function.
	var gx := floorf(x / GRID) * GRID
	var gz := floorf(z / GRID) * GRID
	var u := (x - gx) / GRID
	var v := (z - gz) / GRID
	var b := _grade(gx + GRID, gz)
	var c := _grade(gx, gz + GRID)
	if u + v <= 1.0:
		return _grade(gx, gz) * (1.0 - u - v) + b * u + c * v
	return _grade(gx + GRID, gz + GRID) * (u + v - 1.0) + b * (1.0 - v) + c * (1.0 - u)

static func _near_lot(x: float, z: float) -> bool:
	for i in LOT_X.size():
		if absf(x - LOT_X[i]) < 6.4 and absf(z - LOT_Z[i]) < 5.5:
			return true
	return false

static func _grade(x: float, z: float) -> float:
	var rise := maxf(0.0, z - 46.8)
	var height := minf(37.0, rise * (0.35 + sin(x * 0.080) * 0.075))
	height += smoothstep(0, 12, rise) * (sin(x * 0.21 + z * 0.17) * 1.4 + sin(x * 0.37) * 0.7)
	height += 5.2 * exp(-pow((x + 54) / 19.0, 2)) * smoothstep(1, 14, rise)
	for i in LOT_X.size():
		var radius := maxf(absf(x - LOT_X[i]) / 7.0, absf(z - LOT_Z[i]) / 6.0)
		height = lerpf(LOT_Y[i], height, smoothstep(0.76, 1.45, radius))
	# The creek cut stays, but its rim feathers over 9 m instead of ripping at
	# 4.6 m per metre. That gradient is what read as a torn slot beside the chapel
	# terrace, not missing geometry.
	var creek_fade := lerpf(0.17, 1.0, smoothstep(2.0, 19.0, absf(x - 47.0)))
	var outer_fade := 1.0 - smoothstep(104.0, 120.0, absf(x))
	return height * creek_fade * outer_fade - 0.065


static func _slope(parent: Node3D, random: RandomNumberGenerator) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for iz in ROWS:
		for ix in COLUMNS:
			var x := -120.0 + ix * GRID
			var z := 46.0 + iz * GRID
			var a := Vector3(x, _grade(x, z), z)
			var b := Vector3(x + GRID, _grade(x + GRID, z), z)
			var c := Vector3(x, _grade(x, z + GRID), z + GRID)
			var d := Vector3(x + GRID, _grade(x + GRID, z + GRID), z + GRID)
			_triangle(surface, a, b, c, random.randf())
			_triangle(surface, b, d, c, random.randf())
	_skirt(surface)
	_finish(parent, "GraniteThawTerraces", surface, _slope_material())

## The old grid stopped dead at its outline; from any aerial camera the open
## underside showed as a pale slot beside the chapel terrace. Three borders are
## unshared (the north edge meets the valley floor), so each gets a wall down
## below the floor plane, closed at the lip.
static func _skirt(surface: SurfaceTool) -> void:
	var west := -120.0
	var east := -120.0 + COLUMNS * GRID
	var south := 46.0 + ROWS * GRID
	for ix in COLUMNS:
		var x0 := west + ix * GRID
		var x1 := x0 + GRID
		_wall(surface, Vector3(x1, _grade(x1, 46.0), 46.0), Vector3(x0, _grade(x0, 46.0), 46.0),
			Vector3(0, 0, -1))
		_wall(surface, Vector3(x0, _grade(x0, south), south), Vector3(x1, _grade(x1, south), south),
			Vector3(0, 0, 1))
	for iz in ROWS:
		var z0 := 46.0 + iz * GRID
		var z1 := z0 + GRID
		_wall(surface, Vector3(west, _grade(west, z0), z0), Vector3(west, _grade(west, z1), z1),
			Vector3(-1, 0, 0))
		_wall(surface, Vector3(east, _grade(east, z1), z1), Vector3(east, _grade(east, z0), z0),
			Vector3(1, 0, 0))

static func _wall(surface: SurfaceTool, a: Vector3, b: Vector3, _outward: Vector3) -> void:
	var a_low := Vector3(a.x, SKIRT, a.z)
	var b_low := Vector3(b.x, SKIRT, b.z)
	var rock := Color("554b3e")
	var front_verts := [a_low, b_low, b, a_low, b, a]
	var back_verts := [a_low, b, b_low, a_low, a, b]
	for tris in [front_verts, back_verts]:
		surface.set_color(rock)
		for p: Vector3 in tris:
			surface.set_uv(Vector2(p.x + p.z, p.y) * 0.2)
			surface.add_vertex(p)

static func _slope_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/shaders/black_creek_ground.gdshader")
	mat.set_shader_parameter("triplanar_slope", true)
	mat.set_shader_parameter("slope_scale", 0.23)
	mat.set_shader_parameter("rock_albedo", load("res://assets/textures/town_v2/stone_albedo.png"))
	mat.set_shader_parameter("dirt_albedo", load("res://assets/textures/town_v2/road_albedo.png"))
	return mat

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, variation: float) -> void:
	var cliff := 1.0 - (c - a).cross(b - a).normalized().y
	var base := Color("5e6647").lerp(Color("8d8272"), clampf(cliff * 2.4, 0, 1))
	base = base.lightened(variation * 0.13)
	for p: Vector3 in [a, b, c]:
		surface.set_color(base)
		surface.set_uv(Vector2(p.x + p.y * 0.55, p.z - p.y) * 0.21)
		surface.add_vertex(p)

static func build_ridge(parent: Node3D, distance: float, height: float, flank := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var relief := FastNoiseLite.new()
	relief.seed = roundi(distance * 24.0)
	relief.frequency = 0.035
	var width := absf(distance) * 1.7
	for row in 15:
		var near := row / 15.0
		var far := (row + 1) / 15.0
		for i in 120:
			var x := lerpf(-width, width, i / 120.0)
			var end := lerpf(-width, width, (i + 1) / 120.0)
			var a := _ridge_point(x, distance, height, near, relief, flank)
			var b := _ridge_point(end, distance, height, near, relief, flank)
			var c := _ridge_point(x, distance, height, far, relief, flank)
			var d := _ridge_point(end, distance, height, far, relief, flank)
			_ridge_face(surface, a, b, c, height, relief)
			_ridge_face(surface, b, d, c, height, relief)
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Baked facet lighting keeps distant relief readable without adding another sun.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	_finish(parent, "AlpineDivide", surface, mat)
	var ridge := parent.get_child(-1) as MeshInstance3D
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _ridge_point(axis: float, distance: float, height: float, row: float,
		relief: FastNoiseLite, flank: bool) -> Vector3:
	var mapped := axis * 155.0 / absf(distance)
	var crest := 0.83 + 0.25 * sin(mapped * 0.066 + distance) + 0.12 * sin(mapped * 0.14)
	crest += relief.get_noise_2d(mapped * 1.45, 13.0) * 0.24
	var run := axis + sin(mapped * 0.077) * absf(distance) * 0.055 * (1.0 - row)
	var near_ratio := 0.44 if flank else 0.52
	var forward := distance * lerpf(near_ratio, 1.0, row) + sin(mapped * 0.075) * row * absf(distance) * 0.07
	var fold := relief.get_noise_2d(mapped * 1.8, row * 76.0) * sin(row * PI) * 0.46
	var y := height * (crest * pow(row, 1.12) + fold) - 7.0 * (1.0 - row)
	return Vector3(forward, y, run) if flank else Vector3(run, y, forward)

static func _ridge_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, height: float,
		relief: FastNoiseLite) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	var shadow := normal.dot(Vector3(-0.59, 0.68, -0.44))
	for p: Vector3 in [a, b, c]:
		var grain := relief.get_noise_3d(p.x * 4, p.y * 6, p.z * 4)
		var altitude := p.y / height + grain * 0.12
		var rock := smoothstep(0.28, 0.72, altitude + (1.0 - normal.y) * 0.30)
		var snow := smoothstep(0.59, 0.91, altitude - (1.0 - normal.y) * 0.34)
		var pigment := Color("4a685b").lerp(Color("65717e"), rock).lerp(Color("d8e0e4"), snow)
		pigment *= 0.84 + shadow * 0.22 + grain * 0.14
		# Blue aerial perspective softens the foothills, not the snow on the skyline.
		surface.set_color(pigment.lerp(Color("91afc5"), lerpf(0.37, 0.15, smoothstep(0.05, 0.9, altitude))))
		surface.add_vertex(p)

static func _finish(parent: Node3D, label: String, surface: SurfaceTool, mat: Material) -> void:
	surface.generate_normals()
	var model := MeshInstance3D.new()
	model.name = label
	model.mesh = surface.commit()
	model.material_override = mat
	parent.add_child(model)
