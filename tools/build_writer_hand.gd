extends SceneTree

## Authors the operator's writing hand, shirt cuff and shirt sleeve (v3).
##
##   godot --headless --path . --script tools/build_writer_hand.gd
##
## Replaces the boxy v2 meshes. The hand is built in Hand-local space around
## the pen (tripod grip: thumb left, index on top, middle beneath; ring and
## little finger tucked). Vertex colours carry skin variation and ink stains,
## so no UVs are needed. Prints the Pen node transform the grip was built for;
## transcript_paper.tscn must use exactly that transform.

const OUT := "res://assets/models/operator/"
const SIDES := 8

## Hand-local frame: origin = wrist joint, -Z toward the fingers, -Y toward the
## paper, +X toward the little finger (screen right for a right hand).
const NIB_TIP := Vector3(-0.004, -0.044, -0.118)
## Pen axis from nib to cap: leans back over the knuckles toward the shoulder.
const PEN_AXIS := Vector3(0.36, 0.70, 0.62)
const NIB_TIP_ALONG := 0.069 ## nib tip distance from the Pen node origin

const SKIN := Color(0.62, 0.45, 0.35)
const SKIN_KNUCKLE := Color(0.66, 0.42, 0.34)
const SKIN_PALM := Color(0.70, 0.52, 0.41)
const INK := Color(0.10, 0.10, 0.14)
const SHIRT := Color(0.43, 0.40, 0.34)
const SHIRT_SHADE := Color(0.35, 0.32, 0.27)
const GARTER := Color(0.12, 0.08, 0.07)

func _initialize() -> void:
	var a := PEN_AXIS.normalized()
	var grip := NIB_TIP + a * 0.030
	# Around the pen: n = side facing up/forward (index rests here), left = thumb.
	var n := (Vector3.UP - a * a.dot(Vector3.UP)).normalized()
	var left := a.cross(n).normalized()
	if left.x > 0.0:
		left = -left
	var right := -left

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- palm: wrist -> knuckle line, rolling onto the little-finger edge ----
	var palm := [
		[Vector3(0.000, 0.000, 0.018), 0.027, 0.018, 0.00],
		[Vector3(0.002, -0.004, -0.008), 0.033, 0.016, -0.15],
		[Vector3(0.004, -0.012, -0.040), 0.040, 0.015, -0.35],
		[Vector3(0.006, -0.018, -0.068), 0.040, 0.013, -0.50],
		[Vector3(0.006, -0.021, -0.078), 0.034, 0.011, -0.55],
	]
	_tube(st, palm, SKIN, SKIN_KNUCKLE, true, true)

	var roll := Basis(Vector3.BACK, -0.52)
	var kc := Vector3(0.006, -0.019, -0.074)
	var k_index := kc + roll * Vector3(-0.027, 0.004, -0.001)
	var k_middle := kc + roll * Vector3(-0.009, 0.005, -0.004)
	var k_ring := kc + roll * Vector3(0.009, 0.004, -0.001)
	var k_little := kc + roll * Vector3(0.025, 0.002, 0.006)

	# Index: arches over and lays its pad on the pen's upper face.
	var i_tip := grip + a * 0.016 + n * 0.0085
	_finger(st, [k_index, k_index.lerp(i_tip, 0.42) + Vector3(0, 0.014, 0), k_index.lerp(i_tip, 0.78) + Vector3(0, 0.006, 0), i_tip],
		0.0088, 0.0068, true)
	# Middle: curls under and supports the shaft from the right.
	var m_tip := grip - a * 0.004 + (right * 0.8 - n * 0.6).normalized() * 0.0085
	_finger(st, [k_middle, k_middle.lerp(m_tip, 0.45) + Vector3(0.002, 0.008, -0.010), k_middle.lerp(m_tip, 0.8) + Vector3(0.002, 0.0, -0.004), m_tip],
		0.0086, 0.0066, true)
	# Ring and little: tucked, tips resting back under the palm.
	for k in [k_ring, k_little]:
		var s: float = 0.0082 if k == k_ring else 0.0070
		_finger(st, [k, k + Vector3(0.001, -0.010, -0.017), k + Vector3(0.002, -0.024, -0.012), k + Vector3(0.002, -0.026, 0.001)],
			s, s * 0.8, false)
	# Thumb: from the heel of the palm, pad closing on the pen's left side.
	var t_tip := grip + a * 0.003 + left * 0.0095
	var t_base := Vector3(-0.022, -0.006, -0.004)
	_finger(st, [t_base, Vector3(-0.036, -0.014, -0.036), t_base.lerp(t_tip, 0.72) + Vector3(-0.010, 0.004, 0.0), t_tip],
		0.0115, 0.0085, false)

	st.generate_normals()
	_save(st.commit(), "hand_v3", _skin_material())

	# --- shirt cuff (Wrist-local) ---------------------------------------------
	var cuff := SurfaceTool.new()
	cuff.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(cuff, [
		[Vector3(0, -0.004, -0.030), 0.030, 0.023, 0.0],
		[Vector3(0, -0.004, -0.026), 0.033, 0.026, 0.0],
		[Vector3(0, -0.002, 0.010), 0.034, 0.027, 0.0],
		[Vector3(0, -0.002, 0.020), 0.033, 0.026, 0.0],
	], SHIRT.lightened(0.15), SHIRT.lightened(0.1), true, true)
	cuff.generate_normals()
	_save(cuff.commit(), "cuff_v3", _cloth_material())

	# --- shirt sleeve (Sleeve-local): exits bottom-right toward the shoulder --
	var sleeve := SurfaceTool.new()
	sleeve.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	var start := Vector3(0.0, -0.012, -0.006)
	var end := Vector3(0.17, 0.06, 0.34)
	for i in 10:
		var t := float(i) / 9.0
		var p := start.lerp(end, t) + Vector3(0, 0.012 * sin(t * PI), 0)
		# Loose cotton: wider toward the elbow, a soft ripple of folds.
		var r := lerpf(0.032, 0.044, t) * (1.0 + 0.06 * sin(t * 23.0))
		rings.append([p, r, r * 0.82, 0.0])
	_tube(sleeve, rings, SHIRT, SHIRT_SHADE, true, false, 0.78, 0.86)
	# Sleeve garter: the operator's elastic band that keeps the cuff off the ink.
	var g0 := start.lerp(end, 0.70) + Vector3(0, 0.012 * sin(0.70 * PI), 0)
	var g1 := start.lerp(end, 0.76) + Vector3(0, 0.012 * sin(0.76 * PI), 0)
	var gr := lerpf(0.032, 0.044, 0.73) * 1.07
	_tube(sleeve, [[g0, gr, gr * 0.84, 0.0], [g1, gr, gr * 0.84, 0.0]], GARTER, GARTER, false, false)
	sleeve.generate_normals()
	_save(sleeve.commit(), "forearm_v3", _cloth_material())

	# The Pen node the grip was built around.
	var pen_basis := Basis(Quaternion(Vector3.UP, a))
	var pen_origin := NIB_TIP + a * NIB_TIP_ALONG
	print("PEN position = Vector3(%.4f, %.4f, %.4f)" % [pen_origin.x, pen_origin.y, pen_origin.z])
	var e := pen_basis.get_euler()
	print("PEN rotation = Vector3(%.4f, %.4f, %.4f)" % [e.x, e.y, e.z])
	quit(0)

## A finger: a smooth tapering tube through its joints, rounded at the tip.
## Knuckle joints darken slightly; an inked finger gets a stained pad.
func _finger(st: SurfaceTool, joints: Array, r0: float, r1: float, inked: bool) -> void:
	var rings := []
	var path := _smooth(joints, 3)
	for i in path.size():
		var t := float(i) / float(path.size() - 1)
		var r := lerpf(r0, r1, t)
		rings.append([path[i], r, r * 0.88, 0.0])
	_tube(st, rings, SKIN, INK if inked else SKIN_KNUCKLE, false, true, 0.82, 1.0)

## Catmull-Rom subdivision of a joint chain.
func _smooth(points: Array, steps: int) -> Array:
	var out := []
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		for s in steps:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(steps)))
	out.append(points[points.size() - 1])
	return out

## Rings of [centre, rx, ry, roll]; ring frames by parallel transport.
## tip_color blends in over the last part of the tube (from tip_from to 1).
func _tube(st: SurfaceTool, rings: Array, color: Color, tip_color: Color, cap_start: bool, cap_end: bool,
		tip_from: float = 0.85, tip_amount: float = 0.6) -> void:
	var count := rings.size()
	var up := Vector3.UP
	var frames := []
	for i in count:
		var c: Vector3 = rings[i][0]
		var nxt: Vector3 = rings[mini(i + 1, count - 1)][0]
		var prv: Vector3 = rings[maxi(i - 1, 0)][0]
		var fwd := (nxt - prv).normalized()
		var side := up.cross(fwd)
		if side.length() < 0.001:
			side = Vector3.RIGHT
		side = side.normalized()
		up = fwd.cross(side).normalized()
		frames.append([side, up])
	var verts := []
	var cols := []
	for i in count:
		var t := float(i) / float(count - 1)
		var col := color.lerp(tip_color, clampf((t - tip_from) / maxf(1.0 - tip_from, 0.001), 0.0, 1.0) * tip_amount)
		var ring := []
		for k in SIDES:
			var ang := TAU * float(k) / float(SIDES) + float(rings[i][3])
			var side: Vector3 = frames[i][0]
			var rup: Vector3 = frames[i][1]
			ring.append(rings[i][0] + side * cos(ang) * float(rings[i][1]) + rup * sin(ang) * float(rings[i][2]))
		verts.append(ring)
		cols.append(col)
	for i in count - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			_quad(st, verts[i][k], verts[i][k2], verts[i + 1][k2], verts[i + 1][k], cols[i], cols[i + 1])
	if cap_start:
		_cap(st, verts[0], rings[0][0], frames[0], -1.0, float(rings[0][1]), cols[0], true)
	if cap_end:
		_cap(st, verts[count - 1], rings[count - 1][0], frames[count - 1], 1.0, float(rings[count - 1][1]), cols[count - 1], false)

func _cap(st: SurfaceTool, ring: Array, centre: Vector3, frame: Array, direction: float, radius: float, col: Color, flip: bool) -> void:
	var side: Vector3 = frame[0]
	var up: Vector3 = frame[1]
	var fwd := side.cross(up).normalized() * direction
	var apex := centre + fwd * radius * 0.7
	for k in SIDES:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % SIDES]
		if flip:
			_tri(st, apex, a, b, col)
		else:
			_tri(st, apex, b, a, col)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cc); st.add_vertex(c)
	st.set_color(ca); st.add_vertex(b)
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cc); st.add_vertex(d)
	st.set_color(cc); st.add_vertex(c)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _skin_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.78
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _cloth_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _save(mesh: ArrayMesh, name: String, material: Material) -> void:
	mesh.surface_set_material(0, material)
	var err := ResourceSaver.save(mesh, OUT + name + ".res")
	print("SAVED %s%s.res err=%d tris=%d" % [OUT, name, err, mesh.surface_get_array_len(0) / 3])
