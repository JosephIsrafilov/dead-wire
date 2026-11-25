extends RefCounted
## One authored garment follows the existing cloth cage. Coincident vertices
## share a binding, so a UV seam or a hard normal can never tear a sleeve off.

const WOOL_ALBEDO := preload("res://assets/textures/office_surfaces/wool_albedo.png")
const WOOL_NORMAL := preload("res://assets/textures/office_surfaces/wool_normal.png")
const WOOL_ROUGHNESS := preload("res://assets/textures/office_surfaces/wool_roughness.png")

var _reference: PackedVector3Array
var _points := PackedVector3Array()
var _particles: Array[PackedInt32Array] = []
var _weights: Array[PackedFloat32Array] = []
var _surfaces: Array[Array] = []
var _surface_points: Array[PackedInt32Array] = []
var _materials: Array[Material] = []
var _names: Array[String] = []

func _init(source: PackedScene, reference: PackedVector3Array, offset: Vector3) -> void:
	_reference = reference.duplicate()
	var model := source.instantiate()
	var lookup := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = node.transform
		var parent := node.get_parent()
		while parent is Node3D:
			transform = parent.transform * transform
			parent = parent.get_parent()
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var uvs := PackedVector2Array()
			var bindings := PackedInt32Array()
			for vertex_index in indices:
				var vertex := vertices[vertex_index]
				uvs.append(source_uvs[vertex_index])
				var point: Vector3 = (transform * vertex + offset).snapped(Vector3.ONE * 0.000001)
				if not lookup.has(point):
					lookup[point] = _points.size()
					_points.append(point)
					_bind(point)
				bindings.append(lookup[point])
			arrays[Mesh.ARRAY_TANGENT] = null
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range(indices.size()))
			_surfaces.append(arrays)
			_surface_points.append(bindings)
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			_materials.append(_tailor_material(material, String(node.name)))
			_names.append(str(node.name) + ":" + str(surface))
	model.free()

func _tailor_material(source: StandardMaterial3D, part_name: String) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	var kind := material.resource_name.to_lower()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.metallic = 0.0
	material.roughness = 0.96
	if kind.contains("wool"):
		material.albedo_texture = WOOL_ALBEDO
		# Keep the face of the broadcloth dark; the grazing light catches the nap.
		material.albedo_color = Color(0.69, 0.65, 0.60)
		if kind.contains("facing"):
			material.albedo_color = Color(0.74, 0.68, 0.60)
		elif part_name.begins_with("Pocket"):
			material.albedo_color = Color(0.60, 0.56, 0.51)
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		material.rim_enabled = true
		material.rim = 0.21
		material.rim_tint = 1.0
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.normal_enabled = true
		material.normal_texture = WOOL_NORMAL
		material.normal_scale = 0.31
		material.roughness_texture = WOOL_ROUGHNESS
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif kind.contains("horn"):
		material.albedo_color = Color(0.24, 0.20, 0.16)
	elif kind.contains("lining"):
		material.albedo_color = Color(0.21, 0.19, 0.17)
	return material

func _bind(point: Vector3) -> void:
	var nearest := PackedInt32Array([-1, -1, -1, -1])
	var distances := PackedFloat32Array([INF, INF, INF, INF])
	for index in _reference.size():
		var distance := point.distance_squared_to(_reference[index])
		for slot in 4:
			if distance < distances[slot]:
				for back in range(3, slot, -1):
					distances[back] = distances[back - 1]
					nearest[back] = nearest[back - 1]
				distances[slot] = distance
				nearest[slot] = index
				break
	var weights := PackedFloat32Array()
	var total := 0.0
	for distance in distances:
		var weight := 1.0 / pow(maxf(distance, 0.000001), 2.0)
		weights.append(weight)
		total += weight
	for slot in 4:
		weights[slot] /= total
	_particles.append(nearest)
	_weights.append(weights)

func rebuild(target: ArrayMesh, positions: PackedVector3Array) -> void:
	var points := _points.duplicate()
	for index in points.size():
		for slot in 4:
			var particle := _particles[index][slot]
			points[index] += (positions[particle] - _reference[particle]) * _weights[index][slot]
	target.clear_surfaces()
	for surface in _surfaces.size():
		var arrays: Array = _surfaces[surface].duplicate()
		var vertices := PackedVector3Array()
		for point in _surface_points[surface]:
			vertices.append(points[point])
		var normals := PackedVector3Array()
		normals.resize(vertices.size())
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents := PackedFloat32Array()
		tangents.resize(vertices.size() * 4)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			var edge_b := vertices[b] - vertices[a]
			var edge_c := vertices[c] - vertices[a]
			var normal := edge_c.cross(edge_b).normalized()
			var uv_b := uvs[b] - uvs[a]
			var uv_c := uvs[c] - uvs[a]
			var orientation := -1.0 if uv_b.cross(uv_c) < 0.0 else 1.0
			var tangent := ((edge_b * uv_c.y - edge_c * uv_b.y) * orientation).normalized()
			if tangent.is_zero_approx():
				tangent = edge_b.normalized()
			for corner in range(triangle, triangle + 3):
				var index := indices[corner]
				normals[index] = normal
				var offset := index * 4
				tangents[offset] = tangent.x
				tangents[offset + 1] = tangent.y
				tangents[offset + 2] = tangent.z
				tangents[offset + 3] = -orientation
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		target.surface_set_material(surface, _materials[surface])
		target.surface_set_name(surface, _names[surface])
