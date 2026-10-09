extends SceneTree

## Builds the operator's fixed writing pose from authored sheet-space sections.
## No runtime IK, spline fitting or collision-driven vertex displacement.
##   godot --headless --audio-driver Dummy --path . --script tools/build_writer_hand.gd

const SCENE := "res://scenes/telegraph/transcript_paper.tscn"
const OUT := "res://assets/models/operator/"
const SIDES := 10
## The sheet lies flat on a pad on the copy board on the blotter. Heights in
## sheet space: sheet 0, board top -0.004 past its edge, blotter -0.011.
const SHEET_NEAR_EDGE := 0.15
const BOARD_NEAR_EDGE := 0.168
const BLOTTER_Y := -0.011
## Where the desk top ends, measured along the sheet's +Z from its centre.
const DESK_FRONT := 0.285

## The pose the whole hand is built around, measured from the nib tip (sheet
## space). The cuff test uses the same offset.
const WRIST_OFF := Vector3(0.052, 0.026, 0.104)
## The generator's sheet-space direction from the Wrist joint to the elbow
## (shared by the cuff and the sleeve).
const ELBOW_DIR := Vector3(0.13, 0.0, 0.30)
## The writer_hand_test's grip band: the grip sits 43 mm below the Pen origin
## along the shaft axis (26 mm up from the nib tip).
const GRIP_BELOW_PEN := -0.043

## Skin sits in the lamp's direct throw next to the paper: the albedo has to
## stay under the form stock's luminance or the hand outshines the sheet it
## is writing on. Lips/rudier zones darken, never brighten, the base.
const SKIN := Color(0.46, 0.37, 0.32)
const SKIN_DORSAL := Color(0.49, 0.38, 0.33)
const SKIN_KNUCKLE := Color(0.55, 0.37, 0.32)
const SKIN_THENAR := Color(0.50, 0.37, 0.31)
const NAIL := Color(0.60, 0.51, 0.45)
const INK := Color(0.13, 0.13, 0.17)
## A dark wool coat sleeve; the white shirt cuff shows past it at the wrist.
const SHIRT := Color(0.07, 0.065, 0.06)
const SHIRT_FOLD := Color(0.04, 0.038, 0.035)
const CUFF := Color(0.58, 0.55, 0.49)
const BUTTON := Color(0.62, 0.58, 0.48)

var _hand_inv: Transform3D
var _wrist_inv: Transform3D
var _sleeve_inv: Transform3D
var _back: Vector3
var _thumb_side: Vector3
var _fwd: Vector3
var _hand_mesh: ArrayMesh
## The shaft's axis and span in sheet space, taken from the real Shaft, so the
## generator and writer_hand_test measure in exactly the same frame.
var _axis_origin: Vector3
var _axis_dir: Vector3
var _shaft_half: float
var _shaft_r_bottom: float
var _shaft_r_top: float
var _grip_along: float

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var paper: Node3D = load(SCENE).instantiate()
	root.add_child(paper)
	await process_frame
	var to_sheet := paper.global_transform.affine_inverse()
	var sleeve_node := paper.get_node("WriterRig/Sleeve") as Node3D
	var wrist_node := paper.get_node("WriterRig/Sleeve/Wrist") as Node3D
	var hand_node := paper.get_node("WriterRig/Sleeve/Wrist/Hand") as Node3D
	var nib := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen/Nib") as Node3D
	_sleeve_inv = (to_sheet * sleeve_node.global_transform).affine_inverse()
	_wrist_inv = (to_sheet * wrist_node.global_transform).affine_inverse()
	_hand_inv = (to_sheet * hand_node.global_transform).affine_inverse()

	# --- the pen: nib on the paper where the rig already rests it ------------
	var old_tip: Vector3 = to_sheet * nib.to_global(Vector3(0, -0.011, 0))
	var nib_tip := Vector3(old_tip.x, 0.0006, old_tip.z)
	# The pen shaft's real frame in sheet space — the SAME frame the hand test
	# measures in (its centre, its axis, its taper), so the grip tips and the
	# clearance guard are placed on the actual barrel rather than on a guess.
	var shaft_node := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen/Shaft") as MeshInstance3D
	var pen_node := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen") as Node3D
	var cyl := shaft_node.mesh as CylinderMesh
	_axis_origin = to_sheet * shaft_node.global_position
	_axis_dir = (to_sheet.basis * shaft_node.global_transform.basis.y).normalized()
	_shaft_half = cyl.height * 0.5
	_shaft_r_bottom = cyl.bottom_radius
	_shaft_r_top = cyl.top_radius
	var pen_along: float = ((to_sheet * pen_node.global_position) - _axis_origin).dot(_axis_dir)
	_grip_along = pen_along + GRIP_BELOW_PEN

	var wrist := nib_tip + WRIST_OFF
	_fwd = Vector3(-0.28, 0.05, -0.96).normalized()
	_back = Vector3(0.15, 0.98, 0.06).normalized()
	_thumb_side = Vector3.LEFT
	_hand_mesh = ArrayMesh.new()
	# Keep the measured pen frame; the mesh is authored around it, never vice versa.
	var a := _axis_dir
	var pen_up := (Vector3.UP - a * a.y).normalized()
	var pen_left := a.cross(pen_up).normalized()
	if pen_left.x > 0.0:
		pen_left = -pen_left

	# Broad dorsal bridge with a narrow radial edge: the web is open, not excavated by a clamp.
	_part([
		[wrist + ELBOW_DIR.normalized() * 0.024, 0.027, 0.020],
		[wrist, 0.024, 0.016],
		[nib_tip + Vector3(0.044, 0.031, 0.086), 0.030, 0.018],
		[nib_tip + Vector3(0.038, 0.035, 0.066), 0.031, 0.016],
		[nib_tip + Vector3(0.033, 0.037, 0.049), 0.027, 0.013],
	], _fwd, _back, _palm_color, true, true)

	# MCP / PIP / DIP / pad, in metres relative to the nib. These are the source pose.
	var i_tip := _grip_tip(0.006, pen_up, 0.0040)
	_part(_pose_rows(nib_tip, [Vector3(0.019, 0.044, 0.058), Vector3(0.010, 0.058, 0.040),
		Vector3(-0.010, 0.062, 0.036), i_tip - nib_tip + pen_up * 0.015,
		i_tip - nib_tip], [0.0100, 0.0090, 0.0093, 0.0078, 0.0065]),
		_fwd, _back, _inked_finger_color, false, true, true)
	var m_dir := (-pen_up * 0.45 - pen_left * 0.90).normalized()
	var m_tip := _grip_tip(-0.003, m_dir, 0.0040)
	_part(_pose_rows(nib_tip, [Vector3(0.029, 0.040, 0.046),
		Vector3(0.022, 0.036, 0.017), m_tip - nib_tip + m_dir * 0.014,
		m_tip - nib_tip], [0.0085, 0.0088, 0.0075, 0.0065]),
		_fwd, _back, _inked_finger_color, false, true, true)
	_part(_pose_rows(nib_tip, [Vector3(0.047, 0.033, 0.049),
		Vector3(0.044, 0.021, 0.018), Vector3(0.035, 0.010, 0.008),
		Vector3(0.031, 0.009, 0.022)], [0.0082, 0.0082, 0.0068, 0.0060]),
		_fwd, _back, _finger_color, false, true, true)
	_part(_pose_rows(nib_tip, [Vector3(0.061, 0.026, 0.056),
		Vector3(0.062, 0.016, 0.031), Vector3(0.054, 0.009, 0.021),
		Vector3(0.050, 0.008, 0.033)], [0.0070, 0.0070, 0.0058, 0.0052]),
		_fwd, _back, _finger_color, false, true, true)
	var t_tip := _grip_tip(0.001, pen_left, 0.0100)
	_part(_pose_rows(nib_tip, [Vector3(0.018, 0.028, 0.088),
		Vector3(-0.009, 0.032, 0.068), Vector3(-0.024, 0.030, 0.044),
		t_tip - nib_tip], [0.0140, 0.0120, 0.0100, 0.0085]),
		_thumb_side, _back, _finger_color, false, true, true)
	var names := ["palm", "index", "middle", "ring", "little", "thumb"]
	for s in names.size():
		_hand_mesh.surface_set_name(s, names[s])
	_save(_hand_mesh, "hand_v3", _material(1.0))

	# --- shirt cuff (Wrist-local): long enough to slide inside the sleeve ----
	var cuff := SurfaceTool.new()
	cuff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuff_rings := []
	for i in 5:
		var t := float(i) / 4.0
		var r := 0.0335 if i > 0 else 0.031
		cuff_rings.append([wrist + ELBOW_DIR.normalized() * lerpf(0.004, 0.062, t), r, r * 0.84])
	_loft(cuff, cuff_rings, ELBOW_DIR.normalized(), Vector3.UP, _cuff_color, true, false, _wrist_inv)
	var btn := wrist + ELBOW_DIR.normalized() * 0.03 + Vector3(0.031, 0.012, 0.0)
	_loft(cuff, [[btn, 0.0042, 0.0042], [btn + Vector3(0.004, 0.002, 0), 0.0036, 0.0036]],
		Vector3(0.9, 0.4, 0).normalized(), Vector3.UP, _button_color, true, true, _wrist_inv)
	cuff.generate_normals()
	_save(cuff.commit(), "cuff_v3", _material(1.0))

	# Cloth segments are authored at actual bone lengths, never normalized
	# one-metre meshes stretched between two unrelated points at runtime.
	var forearm := SurfaceTool.new()
	forearm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var forearm_rows := []
	for i in 9:
		var t := float(i) / 8.0
		var r := lerpf(0.037, 0.048, t)
		forearm_rows.append([Vector3(0, 0, t * 0.27), r, r * 0.88])
	_loft(forearm, forearm_rows, Vector3.BACK, Vector3.UP, _sleeve_color,
		true, true, Transform3D.IDENTITY)
	forearm.generate_normals()
	_save(forearm.commit(), "forearm_v3", _material(1.0))
	var upper := SurfaceTool.new()
	upper.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper_rows := []
	for i in 9:
		var t := float(i) / 8.0
		var r := lerpf(0.054, 0.048, t)
		upper_rows.append([Vector3(0, 0, t * 0.30), r, r * 0.9])
	_loft(upper, upper_rows, Vector3.BACK, Vector3.UP, _sleeve_color,
		true, true, Transform3D.IDENTITY)
	upper.generate_normals()
	_save(upper.commit(), "upper_arm_v1", _material(1.0))
	var cuff_anchor := _wrist_inv * (wrist + ELBOW_DIR.normalized() * 0.042)
	_write_node_property('[node name="CuffAnchor" type="Marker3D" parent="WriterRig/Sleeve/Wrist"]',
		"position", "position = Vector3(%.6f, %.6f, %.6f)" % [cuff_anchor.x, cuff_anchor.y, cuff_anchor.z])

	# --- report ---------------------------------------------------------------
	var pen_sheet := Transform3D(Basis(Quaternion(Vector3.UP, a)), nib_tip + a * 0.069)
	var pen_local := _hand_inv * pen_sheet
	var e := pen_local.basis.get_euler()
	var pos_line := "position = Vector3(%.4f, %.4f, %.4f)" % [pen_local.origin.x, pen_local.origin.y, pen_local.origin.z]
	var rot_line := "rotation = Vector3(%.4f, %.4f, %.4f)" % [e.x, e.y, e.z]
	print("PEN ", pos_line, "  ", rot_line)
	_write_pen_transform(pos_line, rot_line)
	print("NIB tip (sheet) = ", nib_tip, " wrist (sheet) = ", wrist)
	paper.queue_free()
	await process_frame
	quit(0)

## Each section is deliberately authored; all section axes follow the final centres.
func _pose_rows(origin: Vector3, points: Array, radii: Array) -> Array:
	var rows := []
	for i in points.size():
		if i == 0 or i == points.size() - 1:
			rows.append([origin + points[i], radii[i], radii[i] * 0.82])
		else:
			# Convex corner bevels stay inside the authored joint neighbourhood.
			var incoming: Vector3 = points[i].lerp(points[i - 1], 0.18)
			var outgoing: Vector3 = points[i].lerp(points[i + 1], 0.18)
			for t in [0.0, 0.5, 1.0]:
				var c: Vector3 = incoming.lerp(points[i], t).lerp(points[i].lerp(outgoing, t), t)
				rows.append([origin + c, radii[i], radii[i] * 0.82])
	return rows

func _part(rows: Array, first_dir: Vector3, up_hint: Vector3, color_fn: Callable,
		cap_start: bool, cap_end: bool, nail: bool = false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rows, first_dir, up_hint, color_fn, cap_start, cap_end, _hand_inv)
	if nail:
		_nail(st, rows)
	st.generate_normals()
	_hand_mesh = st.commit(_hand_mesh)

func _grip_tip(offset_along: float, dir: Vector3, radius: float) -> Vector3:
	var along := _grip_along + offset_along
	var t := clampf((along + _shaft_half) / (_shaft_half * 2.0), 0.0, 1.0)
	return _axis_origin + _axis_dir * along + dir * (lerpf(_shaft_r_bottom, _shaft_r_top, t) + radius)

## A bounded nail plate on the dorsal side of a distal phalanx: a small flat
## quad, slightly proud of the tube — not a coloured whole tip. For a right
## hand writing, only the thumb's nail faces the camera; the fingers' nails
## point into the grip, so a small plate is the honest read.
func _nail(st: SurfaceTool, rings: Array) -> void:
	var n := rings.size()
	var tip: Vector3 = rings[n - 1][0]
	var r_tip: float = rings[n - 1][1]
	var prev: Vector3 = rings[n - 2][0]
	var along := (tip - prev).normalized()
	var dorsal := _back
	dorsal = (dorsal - along * dorsal.dot(along)).normalized()
	var side := along.cross(dorsal).normalized()
	var centre: Vector3 = tip - along * (r_tip * 0.55) + dorsal * (r_tip * 0.98)
	var half_w := r_tip * 0.62
	var half_l := r_tip * 0.95
	var q := [
		centre - along * half_l - side * half_w,
		centre - along * half_l + side * half_w,
		centre + along * half_l + side * half_w,
		centre + along * half_l - side * half_w,
	]
	var local := []
	for p in q:
		local.append(_hand_inv * p)
	var col := NAIL
	_tri(st, local[0], local[1], local[2], col, col, col)
	_tri(st, local[0], local[2], local[3], col, col, col)

## Rewrite only this exact node block. Blank lines are not scene boundaries.
func _write_node_property(header: String, prop: String, line: String) -> void:
	var path := ProjectSettings.globalize_path(SCENE)
	var text := FileAccess.get_file_as_string(path)
	var at := text.find(header)
	if at < 0:
		push_error("Node not found: " + header)
		return
	var body_start := at + header.length()
	var body_end := text.find("\n[node ", body_start)
	if body_end < 0:
		body_end = text.length()
	var kept: PackedStringArray = []
	for existing in text.substr(body_start, body_end - body_start).split("\n"):
		if not existing.strip_edges().is_empty() and not existing.begins_with(prop + " = "):
			kept.append(existing)
	kept.append(line)
	text = text.substr(0, body_start) + "\n" + "\n".join(kept) + "\n\n" + text.substr(body_end).strip_edges()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text + "\n")

func _write_pen_transform(pos_line: String, rot_line: String) -> void:
	var header := '[node name="Pen" type="Node3D" parent="WriterRig/Sleeve/Wrist/Hand"]'
	_write_node_property(header, "position", pos_line)
	_write_node_property(header, "rotation", rot_line)

# --- colour functions: (t along the part, radial direction) -> Color ---------

func _palm_color(t: float, d: Vector3) -> Color:
	var dorsal := clampf(d.dot(_back), 0.0, 1.0)
	var col := SKIN.lerp(SKIN_DORSAL, dorsal)
	# The thenar pad, on the thumb side past the wrist.
	var thenar := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.45, 0.95, t)) * clampf(d.dot(_thumb_side), 0.0, 1.0)
	col = col.lerp(SKIN_THENAR, thenar * 0.6)
	# Extensor tendons: four faint raised lines fanning to the knuckles.
	var lateral := d.dot(_thumb_side)
	var tendon := pow(absf(sin(lateral * PI * 2.0)), 8.0) * dorsal * smoothstep(0.15, 0.6, t)
	col = col.lightened(0.05 * tendon)
	# Wrist crease and the ruddier knuckle ridge.
	if t < 0.14:
		col = col.darkened(0.12 * (1.0 - t / 0.14))
	if t > 0.76:
		col = col.lerp(SKIN_KNUCKLE, clampf((t - 0.76) * 4.0, 0.0, 1.0) * dorsal)
	return col.darkened(0.2 * clampf(-d.dot(_back), 0.0, 1.0))

func _finger_color(_t: float, d: Vector3) -> Color:
	var dorsal := d.dot(_back)
	# Undersides and the folds between fingers sit in shadow.
	return SKIN.lerp(SKIN_DORSAL, clampf(dorsal, 0.0, 1.0)).darkened(0.22 * clampf(-dorsal, 0.0, 1.0))

func _inked_finger_color(t: float, d: Vector3) -> Color:
	if t > 0.78 and d.dot(_back) < -0.2:
		return INK
	return _finger_color(t, d)

func _cuff_color(_t: float, d: Vector3) -> Color:
	return CUFF.darkened(0.25 * clampf(-d.y, 0.0, 1.0))

func _button_color(_t: float, _d: Vector3) -> Color:
	return BUTTON

func _sleeve_color(t: float, d: Vector3) -> Color:
	var fold := 0.5 + 0.5 * sin(t * 29.0 + 1.2)
	# The upper arm is in the operator's own shadow, below the lamp's reach.
	var shade := 0.35 * smoothstep(0.68, 0.9, t)
	# Worn wool: folds darker, the top of the sleeve a little shinier from use.
	return SHIRT.lerp(SHIRT_FOLD, fold * 0.5).lightened(0.08 * clampf(d.y, 0.0, 1.0)).darkened(0.3 * clampf(-d.y, 0.0, 1.0) + shade)

# --- geometry ----------------------------------------------------------------

## Loft ring rows [centre, rx, ry] or [centre, rx, ry, dir] (sheet space).
## `up_hint` orients the ellipses (ry along it); `color_fn(t, radial_dir)`
## colours each vertex; `to_local` maps the result into the owning joint's
## space. Caps are always the soft fingertip/wrist pad height (0.28 x r).
func _loft(st: SurfaceTool, rings: Array, first_dir: Vector3, up_hint: Vector3, color_fn: Callable,
		cap_start: bool, cap_end: bool, to_local: Transform3D) -> void:
	var count := rings.size()
	var verts := []
	var cols := []
	var up := up_hint
	for i in count:
		var c: Vector3 = rings[i][0]
		var nxt: Vector3 = rings[mini(i + 1, count - 1)][0]
		var prv: Vector3 = rings[maxi(i - 1, 0)][0]
		var fwd := first_dir if nxt.is_equal_approx(prv) else (nxt - prv).normalized()
		if rings[i].size() > 3:
			fwd = (rings[i][3] as Vector3).normalized()
		var side := up.cross(fwd)
		if side.length() < 0.001:
			side = fwd.cross(Vector3.RIGHT)
		side = side.normalized()
		up = fwd.cross(side).normalized()
		var t := float(i) / float(maxi(count - 1, 1))
		var ring := []
		var ring_cols := []
		for k in SIDES:
			var ang := TAU * float(k) / float(SIDES)
			var d := side * cos(ang) + up * sin(ang)
			ring.append(to_local * (c + side * cos(ang) * float(rings[i][1]) + up * sin(ang) * float(rings[i][2])))
			ring_cols.append(color_fn.call(t, d))
		verts.append(ring)
		cols.append(ring_cols)
	for i in count - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			_tri(st, verts[i][k], verts[i + 1][k2], verts[i][k2], cols[i][k], cols[i + 1][k2], cols[i][k2])
			_tri(st, verts[i][k], verts[i + 1][k], verts[i + 1][k2], cols[i][k], cols[i + 1][k], cols[i + 1][k2])
	if cap_start:
		_cap(st, verts[0], cols[0], true)
	if cap_end:
		_cap(st, verts[count - 1], cols[count - 1], false)

## A soft pad cap over a ring: the apex sits 0.28 x radius past the ring's own
## plane — a fingertip pad or the closed wrist inside the cuff, never a ball.
func _cap(st: SurfaceTool, ring: Array, cols: Array, at_start: bool) -> void:
	var mean := Vector3.ZERO
	for v in ring:
		mean += v
	mean /= float(ring.size())
	var normal: Vector3 = (ring[1] - ring[0]).cross(ring[2] - ring[0]).normalized()
	var radius: float = (ring[0] - mean).length()
	var apex := mean + normal * radius * 0.28 * (-1.0 if at_start else 1.0)
	for k in SIDES:
		var k2 := (k + 1) % SIDES
		if at_start:
			_tri(st, apex, ring[k2], ring[k], cols[k], cols[k2], cols[k])
		else:
			_tri(st, apex, ring[k], ring[k2], cols[k], cols[k], cols[k2])

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)

func _material(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	# Wool and skin are not glossy: keep probe reflections off them at grazing angles.
	m.metallic_specular = 0.15 if roughness >= 1.0 else 0.3
	if roughness >= 1.0:
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _save(mesh: ArrayMesh, name: String, material: Material) -> void:
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, material)
	var err := ResourceSaver.save(mesh, OUT + name + ".res")
	var total := 0
	for s in mesh.get_surface_count():
		total += mesh.surface_get_array_len(s) / 3
	print("SAVED %s%s.res err=%d surfaces=%d tris=%d" % [OUT, name, err, mesh.get_surface_count(), total])
