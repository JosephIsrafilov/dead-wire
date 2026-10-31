extends SceneTree

## One-shot (plan 8.10): the room's two loose objects as recognizable shapes —
## a tin cup with a rolled rim and a handle, and a squat ink bottle with a
## shoulder, a neck, a cork and a paper label. Built here because there is no
## Blender in the loop; every profile is in metres, base at y = 0, axis +Y.
## Writes only these two files:
##
##   godot --headless --path . --script tools/build_loose_prop_meshes.gd

const CUP_PATH := "res://assets/models/office_props_v1/tin_cup.res"
const BOTTLE_PATH := "res://assets/models/office_props_v1/ink_bottle.res"
const TIN := "res://materials/style_tests/metal_oxidized.tres"
## Dark green glass, opaque on purpose: a small moving prop must not sort
## against the room, so it reads as glass only by the lamp's glint.
const GLASS := "res://materials/style_tests/ink_glass.tres"
const CORK := "res://materials/style_tests/paper_log.tres"
const LABEL := "res://materials/style_tests/paper_log.tres"
const SEGMENTS := 20
## Texels per metre the room's props sit near (64 px texture -> ~3 repeats/m).
const UV_PER_METRE := 3.0

## (radius, height) pairs walked from the centre of the base, out, up the
## outside, over the rim and down the inside.
const CUP_PROFILE := [
	Vector2(0.0, 0.002), Vector2(0.036, 0.002), Vector2(0.039, 0.0), Vector2(0.040, 0.004),
	Vector2(0.0425, 0.082), Vector2(0.0445, 0.0835), Vector2(0.0445, 0.0855), Vector2(0.0425, 0.087),
	Vector2(0.0395, 0.0855), Vector2(0.0375, 0.006), Vector2(0.0, 0.006),
]
const GLASS_PROFILE := [
	Vector2(0.0, 0.002), Vector2(0.028, 0.002), Vector2(0.031, 0.0), Vector2(0.032, 0.004),
	Vector2(0.032, 0.044), Vector2(0.029, 0.050), Vector2(0.020, 0.056), Vector2(0.013, 0.060),
	Vector2(0.012, 0.070), Vector2(0.0145, 0.071), Vector2(0.0145, 0.075), Vector2(0.0115, 0.076),
]
const CORK_PROFILE := [
	Vector2(0.0095, 0.068), Vector2(0.0095, 0.086), Vector2(0.006, 0.0872), Vector2(0.0, 0.0875),
]
const LABEL_PROFILE := [
	Vector2(0.032, 0.0115), Vector2(0.0325, 0.012), Vector2(0.0325, 0.036), Vector2(0.032, 0.0365),
]

func _initialize() -> void:
	var cup := ArrayMesh.new()
	var body := _begin()
	_lathe(body, CUP_PROFILE)
	_handle(body)
	_commit(body, cup, "dw_cup_tin", TIN)
	var bottle := ArrayMesh.new()
	for part in [[GLASS_PROFILE, "dw_bottle_glass", GLASS], [CORK_PROFILE, "dw_bottle_cork", CORK],
			[LABEL_PROFILE, "dw_bottle_label", LABEL]]:
		var tool := _begin()
		_lathe(tool, part[0])
		_commit(tool, bottle, part[1], part[2])
	var failed := false
	for entry in [[cup, CUP_PATH], [bottle, BOTTLE_PATH]]:
		var mesh: ArrayMesh = entry[0]
		var vertices := 0
		for surface in mesh.get_surface_count():
			vertices += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var result := ResourceSaver.save(mesh, entry[1])
		print("%s vertices=%d aabb=%s SAVE %d" % [entry[1], vertices, mesh.get_aabb(), result])
		failed = failed or result != OK
	quit(1 if failed else 0)

func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func _commit(tool: SurfaceTool, mesh: ArrayMesh, surface_name: String, material_path: String) -> void:
	tool.index()
	tool.commit(mesh)
	var surface := mesh.get_surface_count() - 1
	mesh.surface_set_name(surface, surface_name)
	# By path, so the .res refers to the project material instead of a copy.
	mesh.surface_set_material(surface, load(material_path))

## A surface of revolution: one band per profile edge, smooth around, hard
## between bands so every turn of the profile catches the lamp as a facet.
func _lathe(tool: SurfaceTool, profile: Array) -> void:
	var arc := 0.0
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		var edge := b - a
		var length := edge.length()
		if length < 0.000001:
			continue
		var normal_2d := Vector2(edge.y, -edge.x) / length
		for s in SEGMENTS:
			var t0 := TAU * float(s) / SEGMENTS
			var t1 := TAU * float(s + 1) / SEGMENTS
			var u0 := float(s) / SEGMENTS * TAU * maxf(a.x, b.x) * UV_PER_METRE
			var u1 := float(s + 1) / SEGMENTS * TAU * maxf(a.x, b.x) * UV_PER_METRE
			var v0 := arc * UV_PER_METRE
			var v1 := (arc + length) * UV_PER_METRE
			var corners := [
				[_ring(a, t0), _ring_normal(normal_2d, t0), Vector2(u0, v0)],
				[_ring(b, t0), _ring_normal(normal_2d, t0), Vector2(u0, v1)],
				[_ring(b, t1), _ring_normal(normal_2d, t1), Vector2(u1, v1)],
				[_ring(a, t1), _ring_normal(normal_2d, t1), Vector2(u1, v0)],
			]
			_quad(tool, corners)
		arc += length

func _ring(point: Vector2, angle: float) -> Vector3:
	return Vector3(point.x * cos(angle), point.y, point.x * sin(angle))

func _ring_normal(normal_2d: Vector2, angle: float) -> Vector3:
	return Vector3(normal_2d.x * cos(angle), normal_2d.y, normal_2d.x * sin(angle)).normalized()

## The handle: a flattened tube on a half-loop standing out on +X, its ends
## sunk into the wall so no seam shows.
func _handle(tool: SurfaceTool) -> void:
	var steps := 10
	var sides := 6
	var rings: Array = []
	for k in steps + 1:
		var t := lerpf(-PI * 0.5, PI * 0.5, float(k) / steps)
		var centre := Vector3(0.041 + 0.027 * cos(t), 0.044 + 0.024 * sin(t), 0.0)
		var tangent := Vector3(-0.027 * sin(t), 0.024 * cos(t), 0.0).normalized()
		var across := tangent.cross(Vector3.BACK).normalized()
		var ring: Array = []
		for j in sides + 1:
			var a := TAU * float(j) / sides
			var offset := across * cos(a) * 0.0025 + Vector3.BACK * sin(a) * 0.005
			ring.append([centre + offset, offset.normalized(), Vector2(float(j) / sides, float(k) / steps * 0.3)])
		rings.append(ring)
	for k in steps:
		for j in sides:
			_quad(tool, [rings[k][j], rings[k + 1][j], rings[k + 1][j + 1], rings[k][j + 1]])

## Two triangles, each wound so Godot's front face (clockwise) looks along the
## intended normal, whichever way the profile happened to run.
func _quad(tool: SurfaceTool, corners: Array) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var p: Array = [corners[tri[0]], corners[tri[1]], corners[tri[2]]]
		var face: Vector3 = (p[1][0] - p[0][0]).cross(p[2][0] - p[0][0])
		var wanted: Vector3 = p[0][1] + p[1][1] + p[2][1]
		if face.length() < 1e-12:
			continue
		if face.dot(wanted) > 0.0:
			p = [p[0], p[2], p[1]]
		for corner in p:
			tool.set_normal(corner[1])
			tool.set_uv(corner[2])
			tool.add_vertex(corner[0])
