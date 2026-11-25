extends Node3D
## Street furniture and the valley's near treeline. Coordinates are in the town grid.

const SPRUCE := preload("res://assets/models/town/black_creek_spruce.glb")
const WOOD := preload("res://assets/textures/town_v2/plank_albedo.png")
const NORMAL := preload("res://assets/textures/town_v2/plank_normal.png")
const ROUGH := preload("res://assets/textures/town_v2/plank_roughness.png")
const STONE := preload("res://assets/textures/town_v1/stone_foundation_128.png")

var _rng := RandomNumberGenerator.new()
var timber := StandardMaterial3D.new()
var _rock := StandardMaterial3D.new()
var _iron := StandardMaterial3D.new()

func _init() -> void:
	_rng.seed = 18900414
	timber.albedo_texture = WOOD
	timber.albedo_color = Color(0.63, 0.57, 0.48)
	timber.normal_texture = NORMAL
	timber.normal_enabled = true
	timber.normal_scale = 0.72
	timber.roughness_texture = ROUGH
	timber.roughness = 0.94
	_rock.albedo_texture = STONE
	_rock.albedo_color = Color(0.60, 0.59, 0.55)
	_rock.roughness = 1.0
	_iron.albedo_color = Color(0.14, 0.12, 0.1)
	_iron.roughness = 0.88

func build() -> void:
	for grove: Vector3 in [
		Vector3(-66, 15, -44), Vector3(-40, 11, -47), Vector3(26, 9, -49),
		Vector3(40, 8, -50), Vector3(-17, 14, -56), Vector3(4, 10, -59),
		Vector3(-68, 13, 2), Vector3(-74, 12, 35),
		Vector3(65, 10, 8), Vector3(77, 11, 20), Vector3(69, 11, 38),
	]:
		_grove(grove)
	_fence(Vector3(-58, 0, 13), Vector3(-67, 0, 7), 4)
	_fence(Vector3(62, 0, 31), Vector3(71, 0, 38), 4)
	_fence(Vector3(-32, 0, -30), Vector3(-46, 0, -28), 5)
	build_deck(self, Vector3(-0.5, 0.022, 23.0), Vector3(1.65, 0.064, 15.5), true)
	build_deck(self, Vector3(10.0, 0.022, 23.0), Vector3(1.55, 0.064, 15.3), true)
	_bench(Vector3(34.1, 0, 35.8))
	_woodpile(Vector3(-3.7, 0, -5.2))
	var crate := Vector3(11.66, 0.62, -14.35)
	_beam(crate, Vector3(1.18, 0.64, 0.82), timber)
	for y in [-0.19, 0.13]:
		_beam(crate + Vector3(0, y, -0.42), Vector3(1.16, 0.067, 0.04), timber)
	for x in [-0.5, 0.5]:
		_beam(crate + Vector3(x, 0, -0.426), Vector3(0.083, 0.62, 0.04), timber)
	for cluster: Vector2 in [Vector2(-8, 30), Vector2(3.95, 27), Vector2(12, 15.9),
			Vector2(-18, 30), Vector2(27, 30), Vector2(-34, 15), Vector2(37, 31)]:
		_verge(cluster)

func build_deck(parent: Node3D, center: Vector3, size: Vector3, across: bool = false) -> void:
	var count := maxi(1, roundi((size.z if across else size.x) / 0.26))
	var pitch := (size.z if across else size.x) / count
	var dimensions := Vector3(pitch - 0.009, minf(0.082, size.y), size.x if across else size.z)
	var board := _chamfered_board(dimensions)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = board
	batch.instance_count = count
	for i in count:
		var offset := (i + 0.5 - count / 2.0) * pitch
		var p := center + (Vector3(0, 0, offset) if across else Vector3(offset, 0, 0))
		p.y += (size.y - dimensions.y) * 0.5 + _rng.randf_range(-0.003, 0.002)
		var basis_local := Basis(Vector3.UP, PI / 2.0) if across else Basis.IDENTITY
		batch.set_instance_transform(i, Transform3D(basis_local, p))
		var fade := _rng.randf_range(0.68, 1.0)
		batch.set_instance_color(i, Color(fade, fade * _rng.randf_range(0.92, 1.0), fade * 0.97))
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	parent.add_child(visual)
	if size.y > 0.1:
		for i in maxi(1, ceili(size.x / 3.0)):
			var x := center.x - size.x * 0.5 + 0.17 + i * 3.0
			_beam(Vector3(x, center.y - 0.032, center.z),
				Vector3(0.19, size.y - 0.07, size.z - 0.05), timber, parent)

func _chamfered_board(size: Vector3) -> Mesh:
	var x := size.x * 0.5
	var y := size.y * 0.5
	var z := size.z * 0.5
	var b := 0.011
	var section := [Vector2(-x, -y), Vector2(x, -y), Vector2(x, y - b),
		Vector2(x - b, y), Vector2(-x + b, y), Vector2(-x, y - b)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in section.size():
		var a: Vector2 = section[i]
		var c: Vector2 = section[(i + 1) % section.size()]
		_quad(st, Vector3(a.x, a.y, -z), Vector3(a.x, a.y, z),
			Vector3(c.x, c.y, z), Vector3(c.x, c.y, -z))
	for end in [-1, 1]:
		for i in range(1, section.size() - 1):
			var a: Vector2 = section[0]
			var c: Vector2 = section[i if end < 0 else i + 1]
			var d: Vector2 = section[i + 1 if end < 0 else i]
			for q: Vector2 in [a, c, d]:
				_vertex(st, Vector3(q.x, q.y, z * end), Vector2(q.x * 4, q.y * 4))
	st.generate_normals()
	st.generate_tangents()
	var deck_material := timber.duplicate() as StandardMaterial3D
	deck_material.vertex_color_use_as_albedo = true
	st.set_material(deck_material)
	return st.commit()

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var width := a.distance_to(d)
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = [a, b, c, d][i]
		_vertex(st, p, Vector2(0.0 if i < 2 else width * 3.2, p.z * 0.55))

func _vertex(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_smooth_group(-1)
	st.set_uv(uv)
	st.add_vertex(p)

func _grove(center: Vector3) -> void:
	var ground := Vector3(center.x, 0, center.z)
	_rock_at(ground - Vector3(0, 0.64, 0), Vector3(center.y * 1.55, 2.5, 7.8))
	var prototype := SPRUCE.instantiate()
	var meshes := prototype.find_children("*", "MeshInstance3D", true, false)
	if prototype is MeshInstance3D:
		meshes.push_front(prototype)
	var trees: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 17:
		var angle := _rng.randf_range(0, TAU)
		var r := sqrt(_rng.randf())
		var p := ground + Vector3(cos(angle) * center.y * r, -0.12, sin(angle) * center.y * 0.56 * r)
		var s := _rng.randf_range(0.55, 1.5)
		var basis_local := Basis(Vector3.UP, _rng.randf_range(0, TAU))
		trees.append(Transform3D(basis_local.scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s)), p))
		colors.append(Color(0.72, 0.82, 0.70).lerp(Color(1.0, 1.0, 0.91), _rng.randf()))
	for source: MeshInstance3D in meshes:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = source.mesh
		batch.instance_count = trees.size()
		var part := source.transform
		var ancestor := source.get_parent() as Node3D
		while ancestor != null:
			part = ancestor.transform * part
			ancestor = ancestor.get_parent() as Node3D
		for i in trees.size():
			batch.set_instance_transform(i, trees[i] * part)
			batch.set_instance_color(i, colors[i])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = batch
		add_child(inst)
	prototype.free()
	for i in 7:
		var p := ground + Vector3(_rng.randf_range(-center.y, center.y), 0, _rng.randf_range(5, 8))
		_rock_at(p, Vector3(1.6, 0.95, 1.4) * _rng.randf_range(0.35, 1.3))

func _fence(start: Vector3, end: Vector3, bays: int) -> void:
	for i in range(bays + 1):
		var here := start.lerp(end, float(i) / bays)
		_beam(here + Vector3.UP * 0.53, Vector3(0.16, 1.08, 0.17), timber)
		if i == bays:
			break
		var there := start.lerp(end, float(i + 1) / bays)
		for y in [0.35, 0.75]:
			rail(here + Vector3.UP * y, there + Vector3.UP * (y + _rng.randf_range(-0.1, 0.1)))

func rail(start: Vector3, end: Vector3, thickness: float = 0.11) -> MeshInstance3D:
	var rail_mesh := _beam((start + end) * 0.5, Vector3(thickness, thickness, start.distance_to(end)), timber)
	rail_mesh.look_at(end)
	return rail_mesh

func _bench(p: Vector3) -> void:
	for x in [-0.72, 0.72]:
		for z in [-0.19, 0.17]:
			_beam(p + Vector3(x, 0.25, z), Vector3(0.11, 0.5, 0.12), timber)
		_beam(p + Vector3(x, 0.68, 0.20), Vector3(0.075, 0.67, 0.08), timber)
	for z in [-0.18, -0.035, 0.11]:
		_beam(p + Vector3(0, 0.48, z), Vector3(1.87, 0.071, 0.132), timber)
	for y in [0.73, 0.90]:
		_beam(p + Vector3(0, y, 0.16), Vector3(1.83, 0.13, 0.058), timber)
	for x in [-0.72, 0.72]:
		_beam(p + Vector3(x, 0.9, 0.125), Vector3(0.03, 0.03, 0.02), _iron)

func _woodpile(p: Vector3) -> void:
	var cut := timber.duplicate() as StandardMaterial3D
	cut.albedo_color = Color(0.88, 0.69, 0.44)
	for row in 4:
		for i in range(7 - row):
			var log_mesh := CylinderMesh.new()
			log_mesh.height = _rng.randf_range(0.54, 0.78)
			log_mesh.top_radius = _rng.randf_range(0.055, 0.088)
			log_mesh.bottom_radius = log_mesh.top_radius * 0.94
			log_mesh.radial_segments = 5
			log_mesh.rings = 0
			var instance := MeshInstance3D.new()
			instance.mesh = log_mesh
			instance.material_override = cut if i % 3 == 0 else timber
			instance.position = p + Vector3((i + row * 0.5) * 0.15, 0.09 + row * 0.123, 0)
			instance.rotation = Vector3(PI * 0.5, _rng.randf_range(-0.12, 0.12), i * 0.47)
			add_child(instance)

func _verge(p: Vector2) -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.43, 0.36, 0.21)
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Baked around the tuft's own origin, then placed by node position, so the
	# tuft can lean on the wind without its root sliding across the verge.
	for i in 42:
		var v := Vector3(_rng.randf_range(-0.42, 0.42), 0, _rng.randf_range(-0.25, 0.25))
		var across := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf_range(0, TAU)) * 0.013
		st.add_vertex(v + across)
		st.add_vertex(v - across)
		st.add_vertex(v + Vector3.UP * _rng.randf_range(0.07, 0.28) + across * 5.0)
	st.generate_normals()
	st.set_material(grass)
	var blades := MeshInstance3D.new()
	blades.mesh = st.commit()
	blades.position = Vector3(p.x, 0.0, p.y)
	# StreetLife bends every tuft on the shared gust; the group is the contract.
	blades.add_to_group(&"town_sway_grass")
	add_child(blades)
	for i in 4:
		var point := Vector3(p.x + _rng.randf_range(-0.6, 0.6), 0.025, p.y + _rng.randf_range(-0.3, 0.3))
		_rock_at(point, Vector3(0.14, 0.12, 0.10) * _rng.randf_range(0.75, 1.6))

func _rock_at(p: Vector3, size: Vector3) -> MeshInstance3D:
	var stone := SphereMesh.new()
	stone.radial_segments = 7
	stone.rings = 2
	stone.height = 1.0
	stone.radius = 0.5
	var instance := MeshInstance3D.new()
	instance.mesh = stone
	instance.material_override = _rock
	instance.position = p
	instance.scale = size
	instance.rotation.y = _rng.randf_range(0, TAU)
	add_child(instance)
	return instance

func _beam(p: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = p
	instance.material_override = mat
	(parent if parent != null else self).add_child(instance)
	return instance
