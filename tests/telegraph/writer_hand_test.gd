extends SceneTree

## The writing hand's material and grip contracts (WS3 3.3).
##
## M1 — the hand is not the brightest thing in frame: skin material is fully
##      matte (roughness 1.0, SPECULAR_DISABLED — the same rule cloth follows),
##      the mesh actually carries vertex colours, and their average luminance
##      stays under the copy form's albedo. Empty colours must never read as a
##      false 0.0 "pass".
## M2 — the tripod grip is a fact of geometry, measured against the scene's
##      REAL Pen/Shaft node: the shaft is a tapered hexagonal prism offset from
##      the Pen origin, so penetration is tested against the actual shaft
##      volume (its own triangles), and clearance above the fingers is a real,
##      positive margin — never conflated with penetration by a constant radius.
##      Index, middle and thumb each hold the shaft in the grip band.
## M3 — the wrist disappears into the cuff: every hand vertex inside the cuff's
##      span lies within the cuff tube's radius. Axis and vertices are in ONE
##      space (Wrist-local) and the radial is a true perpendicular distance, not
##      a flattened Vector2(x, z).
## M4 — the hand, cuff and sleeve meshes keep layers = 2, and cloth keeps
##      SPECULAR_DISABLED (probe/reflection contract).
##
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/writer_hand_test.gd

const HAND_MESH := "res://assets/models/operator/hand_authored_v1.res"
const CUFF_MESH := "res://assets/models/operator/cuff_v3.res"
const SLEEVE_MESH := "res://assets/models/operator/forearm_v3.res"
const FORM_MATERIAL := "res://materials/style_tests/form_night_copy.tres"

## The grip sits 43 mm below the Pen origin along the shaft axis (26 mm up from
## the nib tip). The three fingers hold within +-20 mm of it.
const GRIP_BELOW_PEN := -0.043
const GRIP_HALF_BAND := 0.020
## From 28 mm past the grip up to the cap, the shaft must run clear of the
## hand. The margin is an honest, positive clearance above the real surface —
## not a second radius stacked on the first.
const UPPER_START_PAST_GRIP := 0.028
const UPPER_END := 0.105
const CLEARANCE_MIN := 0.0003
## A mesh vertex sits on the shaft surface when it is within one vertex step
## (~2.5 mm at SIDES = 10) of it.
const CONTACT_TOLERANCE := 0.0025
## The generator's sheet-space direction from the Wrist joint to the elbow
## (shared by the cuff and the sleeve).
const ELBOW_DIR := Vector3(0.13, 0.0, 0.30)
## The generator's sheet-space offset from the nib tip to the wrist
## (build_writer_hand.gd WRIST_OFF) — the cuff is lofted around this point.
const WRIST_OFF := Vector3(0.052, 0.026, 0.104)

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Writer Hand Test Suite ---")
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world != null:
		world.reset_for_new_game()

	var paper := (load("res://scenes/telegraph/transcript_paper.tscn") as PackedScene).instantiate() as TranscriptPaper
	root.add_child(paper)
	await process_frame

	# --- M4 first: layer and cloth contracts that other work depends on ----
	var hand_mesh := paper.get_node("WriterRig/Sleeve/Wrist/Hand/HandMesh") as MeshInstance3D
	var cuff_mesh := paper.get_node("WriterRig/Sleeve/Wrist/WristMesh") as MeshInstance3D
	var sleeve_mesh := paper.get_node("WriterRig/Sleeve/SleeveMesh") as MeshInstance3D
	if not assert_condition(hand_mesh.layers == 2 and cuff_mesh.layers == 2 and sleeve_mesh.layers == 2,
			"Hand, cuff and sleeve meshes stay on layers = 2"): return
	var cloth := cuff_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if not assert_condition(cloth != null and cloth.specular_mode == BaseMaterial3D.SPECULAR_DISABLED,
			"Cloth keeps SPECULAR_DISABLED"): return

	# --- M1: matte skin, coloured, dimmer than the form --------------------
	var skin := hand_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if not assert_condition(skin != null, "Hand mesh carries a material"): return
	if not assert_condition(skin.roughness >= 0.995,
			"Skin is matte: roughness %.2f (was 0.74 with a lamp sheen)" % skin.roughness): return
	if not assert_condition(skin.specular_mode == BaseMaterial3D.SPECULAR_DISABLED,
			"Skin keeps SPECULAR_DISABLED like the cloth"): return
	var hand_cols := _colors(hand_mesh.mesh)
	if not assert_condition(not hand_cols.is_empty(),
			"Hand mesh carries vertex colours (%d colours)" % hand_cols.size()): return
	var form := load(FORM_MATERIAL) as StandardMaterial3D
	var form_lum: float = _luminance(form.albedo_color)
	var skin_lum: float = _mesh_average_luminance(hand_mesh.mesh)
	if not assert_condition(skin_lum < form_lum,
			"Skin albedo luminance %.3f stays under the form's %.3f" % [skin_lum, form_lum]): return

	# --- M2: the tripod grip, measured on the real Shaft -------------------
	var hand := paper.get_node("WriterRig/Sleeve/Wrist/Hand") as Node3D
	var pen := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen") as Node3D
	var shaft := pen.get_node("Shaft") as MeshInstance3D
	var cyl := shaft.mesh as CylinderMesh
	var to_hand := hand.global_transform.affine_inverse()
	var pen_in_hand := to_hand * pen.global_transform
	var shaft_in_hand := to_hand * shaft.global_transform
	var axis := shaft_in_hand.basis.y.normalized()
	var axis_origin := shaft_in_hand.origin
	var half := cyl.height * 0.5
	var planes := _convex_planes(shaft.mesh, shaft_in_hand, axis_origin)

	# The test's own correctness is pinned with known points: the shaft centre
	# reads inside, a far point reads outside, and a point just off each rim
	# reads on the correct side.
	if not assert_condition(_inside_shaft(axis_origin, planes),
			"Calibration: the shaft's own centre reads inside the shaft"): return
	if not assert_condition(not _inside_shaft(axis_origin + Vector3(1.0, 0.0, 0.0), planes),
			"Calibration: a point a metre away reads outside"): return
	var perp := _any_perpendicular(axis)
	# The shaft is a hexagonal prism (radial_segments = 6), so its cross-section
	# is only `bottom_radius` wide at a VERTEX. The inradius is smaller, and an
	# arbitrary perpendicular may point at a flat face — so calibrate on the
	# inradius, not the circumradius, and inset off the cap plane so a point
	# placed exactly on a face cannot read out on a floating-point epsilon.
	var inradius := cyl.bottom_radius * cos(PI / 6.0)
	if not assert_condition(_inside_shaft(axis_origin - axis * (half - 0.001) + perp * (inradius - 0.0005), planes),
			"Calibration: a point just inside the bottom rim reads inside"): return
	if not assert_condition(not _inside_shaft(axis_origin + axis * half + perp * (cyl.top_radius + 0.0005), planes),
			"Calibration: a point just outside the top rim reads outside"): return

	var pen_along: float = (pen_in_hand.origin - axis_origin).dot(axis)
	var grip_along := pen_along + GRIP_BELOW_PEN

	# The three finger directions, exactly as the generator points them.
	var up_hand: Vector3 = (hand.global_transform.basis.inverse() * Vector3.UP).normalized()
	var pen_up: Vector3 = (up_hand - axis * axis.dot(up_hand)).normalized()
	var pen_left: Vector3 = axis.cross(pen_up).normalized()
	if pen_left.x > 0.0:
		pen_left = -pen_left
	var finger_names := ["index", "middle", "thumb"]
	var finger_dirs := [pen_up, (-pen_up * 0.72 - pen_left * 0.78).normalized(), pen_left]

	# The hand is authored as one surface per part, so a contact is attributed to
	# the part it comes from — not guessed from a direction. (Topology note: the
	# generator now emits palm/index/middle/ring/little/thumb as separate
	# surfaces; a direction-only test could not tell a curled middle finger from
	# a thumb that crossed the same sector.)
	var part_names := ["palm", "index", "middle", "ring", "little", "thumb"]
	var surface_count: int = (hand_mesh.mesh as ArrayMesh).get_surface_count()
	if not assert_condition(surface_count == part_names.size(),
			"The hand carries one named surface per part (%d)" % surface_count): return

	var skin_vertices := PackedVector3Array()
	for s in surface_count:
		skin_vertices.append_array(_surface_vertices(hand_mesh.mesh, s))
	var skin_edges := _edge_counts(skin_vertices)
	if not assert_condition(_closed_edges(skin_edges),
			"The complete skin is closed and manifold after welding named seams"): return
	if not assert_condition(_is_one_skin(skin_vertices),
			"Palm and all five fingers form one connected skin component"): return
	for s in surface_count:
		var vertices := _surface_vertices(hand_mesh.mesh, s)
		var degenerate := 0
		for t in range(0, vertices.size(), 3):
			if (vertices[t + 1] - vertices[t]).cross(vertices[t + 2] - vertices[t]).length() < 1e-12:
				degenerate += 1
		if not assert_condition(degenerate == 0,
				"The %s has no zero-area triangles (%d degenerate)" % [part_names[s], degenerate]): return
		if s > 0:
			# A named surface may end at a welded palm seam, never in open air.
			if not assert_condition(_seams_join_skin(vertices, skin_edges),
					"The %s has a closed tip and every boundary joins the skin" % part_names[s]): return

	var names_match := true
	for s in surface_count:
		names_match = names_match and hand_mesh.mesh.surface_get_name(s) == part_names[s]
	if not assert_condition(names_match, "Surface names identify palm and all five fingers"): return

	# The rejected pose had a 70 mm index arch: it read as a clenched fist.
	# This only bounds the silhouette; windowed review remains mandatory.
	var index_height := 0.0
	for v in _surface_vertices(hand_mesh.mesh, 1):
		index_height = maxf(index_height, (paper.global_transform.affine_inverse() * hand_mesh.global_transform * v).y)
	if not assert_condition(index_height < 0.058,
			"Relaxed writing index stays below a 58 mm arch (%.1f mm)" % (index_height * 1000.0)): return

	var calibration_triangle := PackedVector3Array([
		axis_origin + perp * 0.02,
		axis_origin - perp * 0.02 + axis * 0.01,
		axis_origin - perp * 0.02 - axis * 0.01,
	])
	if not assert_condition(_triangle_enters_shaft(calibration_triangle, planes),
			"Triangle calibration catches a crossing with all three vertices outside"): return
	for i in calibration_triangle.size():
		calibration_triangle[i] += perp * 0.10
	if not assert_condition(not _triangle_enters_shaft(calibration_triangle, planes),
			"Triangle calibration rejects a separate triangle"): return

	var crossing_triangles := 0
	var penetration := 0
	var worst_penetration := 0.0
	var upper_min := INF
	var grip_contacts := 0
	var part_contacts := {}
	for p in part_names:
		part_contacts[p] = 0
	for s in surface_count:
		var part: String = part_names[s]
		var part_vertices := _surface_vertices(hand_mesh.mesh, s)
		var part_crossings := 0
		for t in range(0, part_vertices.size(), 3):
			if _triangle_enters_shaft(part_vertices.slice(t, t + 3), planes):
				crossing_triangles += 1
				part_crossings += 1
		print("  GEOMETRY: %s shaft crossings=%d" % [part, part_crossings])
		for v in part_vertices:
			var signed := _signed_distance(v, planes)
			if signed < 0.0:
				penetration += 1
				worst_penetration = maxf(worst_penetration, -signed)
			var along: float = (v - axis_origin).dot(axis)
			# Upper zone: the shaft must run clear above the fingers.
			if along > grip_along + UPPER_START_PAST_GRIP and along <= UPPER_END:
				upper_min = minf(upper_min, signed)
			# Grip band: count surface contacts per named part, so the whole
			# mesh kissing the shaft cannot stand in for the tripod itself.
			if along >= grip_along - GRIP_HALF_BAND and along <= grip_along + GRIP_HALF_BAND and signed <= CONTACT_TOLERANCE:
				grip_contacts += 1
				part_contacts[part] += 1
	if not assert_condition(crossing_triangles == 0,
			"No hand triangle crosses the shaft interior (%d crossings)" % crossing_triangles): return
	if not assert_condition(penetration == 0,
			"No hand vertex enters the pen shaft (worst %.2f mm)" % (worst_penetration * 1000.0)): return
	if not assert_condition(upper_min >= CLEARANCE_MIN,
			"Shaft runs clear above the fingers: min clearance %.2f mm" % (upper_min * 1000.0)): return
	if not assert_condition(grip_contacts >= 4,
			"Hand vertices hold the shaft in the grip band (%d surface contacts)" % grip_contacts): return
	for f in finger_names.size():
		if not assert_condition(part_contacts[finger_names[f]] >= 1,
				"The %s holds the shaft from its own surface (%d contacts)" % [finger_names[f], part_contacts[finger_names[f]]]): return

	# --- M3: no bare wrist beside the cuff ---------------------------------
	var wrist := paper.get_node("WriterRig/Sleeve/Wrist") as Node3D
	var nib := pen.get_node("Nib") as Node3D
	var to_sheet := paper.global_transform.affine_inverse()
	## Reconstruct the point the generator lofted the cuff around: the same
	## sheet-space wrist the Pen transform was built from (build_writer_hand.gd's
	## WRIST_OFF).
	var old_tip: Vector3 = to_sheet * nib.to_global(Vector3(0, -0.011, 0))
	var wrist_sheet := Vector3(old_tip.x, 0.0006, old_tip.z) + WRIST_OFF
	var to_wrist := wrist.global_transform.affine_inverse()
	var cuff_origin := to_wrist * (paper.global_transform * wrist_sheet)
	var cuff_axis: Vector3 = (to_wrist.basis * (paper.global_transform.basis * ELBOW_DIR.normalized())).normalized()
	var cuff_verts := _vertices(cuff_mesh.mesh)
	var cuff_max_radius := 0.0
	for v in cuff_verts:
		var rel := v - cuff_origin
		cuff_max_radius = maxf(cuff_max_radius, (rel - cuff_axis * rel.dot(cuff_axis)).length())
	var leaks := 0
	var worst_leak := 0.0
	for s in surface_count:
		for v in _surface_vertices(hand_mesh.mesh, s):
			var vw: Vector3 = to_wrist * (hand.global_transform * v)
			var rel := vw - cuff_origin
			var along: float = rel.dot(cuff_axis)
			if along > 0.002 and along <= 0.060:
				var radial: float = (rel - cuff_axis * along).length()
				if radial > cuff_max_radius + 0.0015:
					leaks += 1
					worst_leak = maxf(worst_leak, radial - cuff_max_radius)
	if not assert_condition(leaks == 0,
			"No hand vertex leaks outside the cuff tube (%d leaks, worst %.2f mm)" % [leaks, worst_leak * 1000.0]): return

	paper.queue_free()
	await process_frame
	print("--- All Writer Hand Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _vertices(mesh: Mesh) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array

## The vertices of one named part of the hand (one surface per part).
func _surface_vertices(mesh: Mesh, surface: int) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(surface)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array

func _is_one_skin(vertices: PackedVector3Array) -> bool:
	var graph := {}
	for t in range(0, vertices.size(), 3):
		var keys := []
		for e in 3:
			keys.append(str(vertices[t + e].snapped(Vector3.ONE * 0.0000001)))
		for e in 3:
			if not graph.has(keys[e]): graph[keys[e]] = []
			graph[keys[e]].append(keys[(e + 1) % 3])
			graph[keys[e]].append(keys[(e + 2) % 3])
	var stack := [graph.keys()[0]]
	var seen := {}
	while not stack.is_empty():
		var key: String = stack.pop_back()
		if seen.has(key): continue
		seen[key] = true
		stack.append_array(graph[key])
	return seen.size() == graph.size()

func _edge_counts(vertices: PackedVector3Array) -> Dictionary:
	var edges := {}
	for t in range(0, vertices.size(), 3):
		for e in 3:
			var a := str(vertices[t + e].snapped(Vector3.ONE * 0.0000001))
			var b := str(vertices[t + (e + 1) % 3].snapped(Vector3.ONE * 0.0000001))
			var key := a + ":" + b if a < b else b + ":" + a
			edges[key] = int(edges.get(key, 0)) + 1
	return edges

func _closed_edges(edges: Dictionary) -> bool:
	for count in edges.values():
		if count != 2:
			return false
	return not edges.is_empty()

func _seams_join_skin(vertices: PackedVector3Array, all_edges: Dictionary) -> bool:
	var local := _edge_counts(vertices)
	for edge in local:
		if int(local[edge]) > 2 or int(all_edges.get(edge, 0)) != 2:
			return false
	return not local.is_empty()

func _colors(mesh: Mesh) -> PackedColorArray:
	var out := PackedColorArray()
	for s in (mesh as ArrayMesh).get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var value: Variant = arrays[Mesh.ARRAY_COLOR]
		if value != null:
			out.append_array(value as PackedColorArray)
	return out

## Outward half-space planes of the shaft's closed convex volume, in Hand space.
func _convex_planes(mesh: Mesh, xform: Transform3D, inside_ref: Vector3) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	var tri_count := (verts.size() / 3) if indices.is_empty() else (indices.size() / 3)
	var planes: Array = []
	for t in tri_count:
		var i0: int = t * 3 if indices.is_empty() else indices[t * 3]
		var i1: int = t * 3 + 1 if indices.is_empty() else indices[t * 3 + 1]
		var i2: int = t * 3 + 2 if indices.is_empty() else indices[t * 3 + 2]
		var a := xform * verts[i0]
		var b := xform * verts[i1]
		var c := xform * verts[i2]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(inside_ref - a) > 0.0:
			normal = -normal
		planes.append(Plane(normal, a))
	return planes

## Inside a convex solid: on the negative side of every outward plane.
func _triangle_enters_shaft(vertices: PackedVector3Array, planes: Array) -> bool:
	var polygon := vertices
	for plane in planes:
		var clipped := PackedVector3Array()
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			# Ignore numerical surface contact, not a visible penetration.
			var da: float = plane.distance_to(a) + 0.000001
			var db: float = plane.distance_to(b) + 0.000001
			if da <= 0.0:
				clipped.append(a)
			if (da < 0.0) != (db < 0.0):
				clipped.append(a.lerp(b, da / (da - db)))
		polygon = clipped
		if polygon.is_empty():
			return false
	return true

func _inside_shaft(point: Vector3, planes: Array) -> bool:
	for plane in planes:
		if plane.distance_to(point) > 0.0:
			return false
	return true

## Distance to the nearest surface: the largest signed plane distance.
func _signed_distance(point: Vector3, planes: Array) -> float:
	var signed := -INF
	for plane in planes:
		signed = maxf(signed, plane.distance_to(point))
	return signed

func _any_perpendicular(axis: Vector3) -> Vector3:
	var perp := axis.cross(Vector3.RIGHT)
	if perp.length() < 0.001:
		perp = axis.cross(Vector3.UP)
	return perp.normalized()

func _mesh_average_luminance(mesh: Mesh) -> float:
	var cols := _colors(mesh)
	if cols.is_empty():
		return 0.0
	var total := 0.0
	for c in cols:
		total += _luminance(c)
	return total / float(cols.size())

func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
