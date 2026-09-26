extends SceneTree

## Authors the operator's writing hand, shirt cuff and shirt sleeve (v4).
##
##   godot --headless --path . --script tools/build_writer_hand.gd
##
## Everything is designed in the SHEET's own space — y = 0 is the paper, +Z is
## toward the operator, +X across the sheet — and only then converted into each
## rig joint's local space using the scene's real rest transforms. So contact is
## a fact, not a hope: the heel of the hand and the tucked fingers rest on the
## paper, the nib touches it, and the forearm drapes over the near edge onto
## the desk. Adult proportions (palm ~10 cm, hand ~19 cm).
##
## Prints the Pen node transform (Hand-local) the grip was built around;
## transcript_paper.tscn must use exactly that transform.

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

const SKIN := Color(0.52, 0.42, 0.36)
const SKIN_DORSAL := Color(0.55, 0.43, 0.37)
const SKIN_KNUCKLE := Color(0.62, 0.42, 0.37)
const NAIL := Color(0.70, 0.60, 0.54)
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
	# --- hand frame: resting on the little-finger edge, wrist low ------------
	var wrist := nib_tip + Vector3(0.088, 0.028, 0.142)
	var knuckles := nib_tip + Vector3(0.050, 0.040, 0.052)
	var fwd := (knuckles - wrist).normalized()
	var roll := deg_to_rad(24.0)
	var tilt := Vector3(sin(roll), cos(roll), 0.0)
	_back = (tilt - fwd * fwd.dot(tilt)).normalized()
	var thumb_side := _back.cross(fwd).normalized()
	if thumb_side.x > 0.0:
		thumb_side = -thumb_side
	_thumb_side = thumb_side
	var k_index := knuckles + thumb_side * 0.030 + fwd * 0.002 + _back * 0.004

	# --- the pen lies in the web between thumb and index -------------------------
	# Its line runs from the nib over the web just behind the index knuckle,
	# which is what points the cap back toward the shoulder.
	var web := k_index - fwd * 0.024 + _back * 0.016 + thumb_side * 0.020
	var a := (web - nib_tip).normalized()
	var grip := nib_tip + a * 0.026
	var pen_up := (Vector3.UP - a * a.dot(Vector3.UP)).normalized()
	var pen_left := a.cross(pen_up).normalized()
	if pen_left.x > 0.0:
		pen_left = -pen_left
	print("PEN elevation %.1f deg" % rad_to_deg(asin(a.y)))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Palm: wrist -> knuckle ridge; sections widen and flatten.
	# The palm starts inside the cuff with a full, round wrist — no thin neck
	# where the hand meets the sleeve.
	var elbow_dir0 := Vector3(0.13, 0.0, 0.30).normalized()
	var palm_rings := [[wrist + elbow_dir0 * 0.024, 0.029, 0.022]]
	for i in 7:
		var t := float(i) / 6.0
		var c := wrist.lerp(knuckles, t) + _back * 0.004 * sin(t * PI)
		palm_rings.append([c, lerpf(0.031, 0.046, smoothstep(0.0, 0.7, t)), lerpf(0.021, 0.012, t)])
	_loft(st, palm_rings, fwd, _back, _palm_color, true, true, _hand_inv)

	# Knuckle heads along the ridge (thumb side higher because of the roll).
	# Knuckle heads stand a little proud of the back of the hand.
	var k_middle := knuckles + thumb_side * 0.010 + fwd * 0.006 + _back * 0.004
	var k_ring := knuckles - thumb_side * 0.011 + fwd * 0.003 + _back * 0.003
	var k_little := knuckles - thumb_side * 0.029 - fwd * 0.006 + _back * 0.002

	# Index: arches high, pad lies on the pen's upper face.
	var i_tip := grip + a * 0.015 + pen_up * 0.0078
	_chain(st, [k_index, k_index.lerp(i_tip, 0.40) + _back * 0.020, k_index.lerp(i_tip, 0.74) + _back * 0.009, i_tip],
		0.0088, 0.0070, _inked_finger_color)
	# Middle: curls under; the side of its last joint supports the shaft.
	var m_tip := grip - a * 0.004 + (-pen_up * 0.6 - pen_left * 0.8).normalized() * 0.0078
	_chain(st, [k_middle, k_middle.lerp(m_tip, 0.40) + _back * 0.012, k_middle.lerp(m_tip, 0.74) + _back * 0.005, m_tip],
		0.0088, 0.0068, _inked_finger_color)
	# Ring and little: tucked into the palm, their middle knuckles on the paper.
	for k in [k_ring, k_little]:
		var r0: float = 0.0082 if k == k_ring else 0.0070
		var pip: Vector3 = k + fwd * 0.026
		pip.y = r0 * 0.95
		var dip: Vector3 = k + fwd * 0.012
		dip.y = r0 * 0.85
		var tip: Vector3 = k - fwd * 0.006
		tip.y = r0 * 0.95
		_chain(st, [k, pip, dip, tip], r0, r0 * 0.82, _finger_color)
	# Thumb: from the heel of the palm, pad closing on the pen's left side.
	var t_base := wrist + thumb_side * 0.022 + fwd * 0.012 - _back * 0.004
	var t_tip := grip + a * 0.004 + pen_left * 0.0090
	var t_mcp := t_base.lerp(t_tip, 0.45) + thumb_side * 0.012 - _back * 0.004
	var t_ip := t_base.lerp(t_tip, 0.78) + thumb_side * 0.005
	_chain(st, [t_base, t_mcp, t_ip, t_tip], 0.0125, 0.0095, _finger_color)
	st.generate_normals()
	_save(st.commit(), "hand_v3", _material(0.74))

	# --- shirt cuff (Wrist-local): long enough to slide inside the sleeve ----
	var elbow_dir := Vector3(0.13, 0.0, 0.30).normalized()
	var cuff := SurfaceTool.new()
	cuff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuff_rings := []
	for i in 5:
		var t := float(i) / 4.0
		var r := 0.0335 if i > 0 else 0.031
		cuff_rings.append([wrist + elbow_dir * lerpf(0.004, 0.062, t), r, r * 0.84])
	_loft(cuff, cuff_rings, elbow_dir, Vector3.UP, _cuff_color, true, false, _wrist_inv)
	var btn := wrist + elbow_dir * 0.03 + Vector3(0.031, 0.012, 0.0)
	_loft(cuff, [[btn, 0.0042, 0.0042], [btn + Vector3(0.004, 0.002, 0), 0.0036, 0.0036]],
		Vector3(0.9, 0.4, 0).normalized(), Vector3.UP, _button_color, true, true, _wrist_inv)
	cuff.generate_normals()
	_save(cuff.commit(), "cuff_v3", _material(1.0))

	# --- shirt sleeve (Sleeve-local): over the near edge, down onto the desk --
	var sleeve := SurfaceTool.new()
	sleeve.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := wrist + elbow_dir * 0.035
	var elbow := start + Vector3(0.12, 0.0, 0.27)
	var rings := []
	for i in 13:
		var t := float(i) / 12.0
		var c := start.lerp(elbow, t)
		var r := lerpf(0.039, 0.050, t) * (1.0 + 0.07 * sin(t * 29.0) * smoothstep(0.1, 0.4, t))
		# Rest on the sheet, then on the desk in front of it; past the desk's
		# front edge the elbow hangs toward the operator's lap.
		var ground := _ground(c.z)
		c.y = maxf(lerpf(c.y, ground + r * 0.86, smoothstep(0.0, 0.5, t)), ground + r * 0.86)
		rings.append([c, r, r * 0.86])
	# Upper arm: from the elbow to the operator's real shoulder — just right of
	# and below the seated eye — so it foreshortens toward the camera.
	var elbow_c: Vector3 = rings[rings.size() - 1][0]
	var shoulder := await _seated_shoulder_in_sheet_space()
	for i in range(1, 6):
		var t := float(i) / 5.0
		var r := lerpf(0.050, 0.056, t)
		rings.append([elbow_c.lerp(shoulder, t), r, r * 0.9])
	_loft(sleeve, rings, elbow_dir, Vector3.UP, _sleeve_color, true, false, _sleeve_inv)
	sleeve.generate_normals()
	_save(sleeve.commit(), "forearm_v3", _material(1.0))

	# --- report ---------------------------------------------------------------
	var pen_sheet := Transform3D(Basis(Quaternion(Vector3.UP, a)), nib_tip + a * 0.069)
	var pen_local := _hand_inv * pen_sheet
	var e := pen_local.basis.get_euler()
	var pos_line := "position = Vector3(%.4f, %.4f, %.4f)" % [pen_local.origin.x, pen_local.origin.y, pen_local.origin.z]
	var rot_line := "rotation = Vector3(%.4f, %.4f, %.4f)" % [e.x, e.y, e.z]
	print("PEN ", pos_line, "  ", rot_line)
	_write_pen_transform(pos_line, rot_line)
	print("NIB tip (sheet) = ", nib_tip, "  wrist (sheet) = ", wrist, "  elbow (sheet) = ", elbow)
	# The rig swings the arm around its elbow pivot for glyph travel. That pivot
	# must be the real elbow on the desk, or the forearm lifts off it.
	var sleeve_rest: Vector3 = (to_sheet * sleeve_node.global_transform).origin
	var elbow_on_desk: Vector3 = rings[12][0]
	var off := elbow_on_desk - sleeve_rest
	_write_node_property('[node name="WriterRig" type="Node3D" parent="."]', "elbow_offset_rig",
		"elbow_offset_rig = Vector3(%.4f, %.4f, %.4f)" % [off.x, off.y, off.z])
	quit(0)

## Sets (or replaces) one property line on a node block of the scene file.
func _write_node_property(header: String, prop: String, line: String) -> void:
	var path := ProjectSettings.globalize_path(SCENE)
	var text := FileAccess.get_file_as_string(path)
	var at := text.find(header)
	if at < 0:
		printerr("node not found: ", header)
		return
	var body_start := at + header.length() + 1
	var body_end := text.find("\n\n", body_start)
	var lines := text.substr(body_start, body_end - body_start).split("\n")
	var kept: PackedStringArray = []
	for existing in lines:
		if not existing.begins_with(prop + " = "):
			kept.append(existing)
	kept.append(line)
	text = text.substr(0, body_start) + "\n".join(kept) + text.substr(body_end)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("SET ", line)

## Keeps the scene's Pen node on exactly the transform the grip was built for.
func _write_pen_transform(pos_line: String, rot_line: String) -> void:
	var path := ProjectSettings.globalize_path(SCENE)
	var text := FileAccess.get_file_as_string(path)
	var header := '[node name="Pen" type="Node3D" parent="WriterRig/Sleeve/Wrist/Hand"]'
	var at := text.find(header)
	if at < 0:
		printerr("Pen node not found in ", SCENE)
		return
	var body_start := at + header.length() + 1
	var body_end := text.find("\n\n", body_start)
	var lines := text.substr(body_start, body_end - body_start).split("\n")
	var kept: PackedStringArray = [pos_line, rot_line]
	for line in lines:
		if not line.begins_with("position = ") and not line.begins_with("rotation = "):
			kept.append(line)
	text = text.substr(0, body_start) + "\n".join(kept) + text.substr(body_end)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

## Seats the operator in the real office and reads the eye, then offsets to
## where a right shoulder sits relative to it. Returned in the transcript
## sheet's own space.
func _seated_shoulder_in_sheet_space() -> Vector3:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	var seat = office.get("operator_seat")
	seat.sit_duration = 0.0
	seat.approach_duration = 0.0
	seat.sit()
	await process_frame
	var cam := office.get_node("Player/Head/Camera3D") as Camera3D
	var sheet := office.get_node("TranscriptPaper") as Node3D
	var basis := cam.global_transform.basis
	var right := basis.x.normalized()
	var back := basis.z.normalized()
	back.y = 0.0
	back = back.normalized()
	var shoulder_world := cam.global_position + right * 0.19 + Vector3.DOWN * 0.24 + back * 0.04
	var out := sheet.to_local(shoulder_world)
	office.queue_free()
	return out

func _ground(z: float) -> float:
	if z <= SHEET_NEAR_EDGE:
		return 0.0
	if z <= BOARD_NEAR_EDGE:
		return -0.004
	# Past the desk's front edge the arm goes down toward the operator's lap.
	return BLOTTER_Y - maxf(z - DESK_FRONT, 0.0) * 1.2

# --- colour functions: (t along the part, radial direction) -> Color ---------

func _palm_color(t: float, d: Vector3) -> Color:
	var dorsal := clampf(d.dot(_back), 0.0, 1.0)
	var col := SKIN.lerp(SKIN_DORSAL, dorsal)
	# Extensor tendons: four faint raised lines fanning to the knuckles.
	var lateral := d.dot(_thumb_side)
	var tendon := pow(absf(sin(lateral * PI * 2.0)), 8.0) * dorsal * smoothstep(0.15, 0.6, t)
	col = col.lightened(0.07 * tendon)
	# Wrist crease and the ruddier knuckle ridge.
	if t < 0.14:
		col = col.darkened(0.12 * (1.0 - t / 0.14))
	if t > 0.76:
		col = col.lerp(SKIN_KNUCKLE, clampf((t - 0.76) * 4.0, 0.0, 1.0) * dorsal)
	return col.darkened(0.2 * clampf(-d.dot(_back), 0.0, 1.0))

func _finger_color(t: float, d: Vector3) -> Color:
	var dorsal := d.dot(_back)
	if t > 0.72 and dorsal > 0.45:
		return NAIL
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

# --- geometry -------------------------------------------------------------------

## Phalanges through joints; joints bulge slightly.
func _chain(st: SurfaceTool, joints: Array, r0: float, r1: float, color_fn: Callable) -> void:
	var path := _smooth(joints, 4)
	var rings := []
	var n := path.size()
	for i in n:
		var t := float(i) / float(n - 1)
		var bulge := 1.0 + 0.10 * pow(cos(t * 3.0 * PI), 8.0) * (1.0 - t * 0.5)
		var r := lerpf(r0, r1, t) * bulge
		rings.append([path[i], r, r * 0.9])
	_loft(st, rings, (path[n - 1] - path[0]).normalized(), _back, color_fn, false, true, _hand_inv)

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

## Loft rings [centre, rx, ry] (sheet space). `up_hint` orients the ellipses
## (ry along it); `color_fn(t, radial_dir)` colours each vertex; `to_local`
## maps the result into the owning joint's space.
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

## A shallow dome over a ring: the apex sits past the ring's own plane.
func _cap(st: SurfaceTool, ring: Array, cols: Array, at_start: bool) -> void:
	var mean := Vector3.ZERO
	for v in ring:
		mean += v
	mean /= float(ring.size())
	var normal: Vector3 = (ring[1] - ring[0]).cross(ring[2] - ring[0]).normalized()
	var radius: float = (ring[0] - mean).length()
	var apex := mean + normal * radius * (-0.55 if at_start else 0.55)
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
	mesh.surface_set_material(0, material)
	var err := ResourceSaver.save(mesh, OUT + name + ".res")
	print("SAVED %s%s.res err=%d tris=%d" % [OUT, name, err, mesh.surface_get_array_len(0) / 3])
