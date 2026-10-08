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
## the desk.
##
## Proportions are an adult right hand writing a tripod grip, not a set of tubes
## (see docs/art/state_2026-10-08/hand_anatomy/01_defects_measured.md for the
## measurements the pose is chosen from):
##   wrist -> grip       ~100 mm   (a hand-length; was 148)
##   wrist -> knuckles    ~74 mm   (palm; was 98)
##   knuckles -> grip     ~28 mm
##   thumb CMC -> tip     ~72 mm   (was 135, rooted at the sleeve)
## The hand is emitted as ONE mesh with ONE SURFACE PER PART (palm, index,
## middle, ring, little, thumb) so a test can name the part a vertex belongs to
## instead of guessing it from a direction.
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

## The pose the whole hand is built around, measured from the nib tip (sheet
## space). These three constants are the public contract the hand test reads.
const WRIST_OFF := Vector3(0.052, 0.026, 0.104)
const KNUCKLE_DIR := Vector3(-0.42, 0.10, -0.90)
const PALM_LEN := 0.074
## The generator's sheet-space direction from the Wrist joint to the elbow
## (shared by the cuff and the sleeve).
const ELBOW_DIR := Vector3(0.13, 0.0, 0.30)
## How far up the pen axis from the nib tip the fingers close on the shaft.
const GRIP_HEIGHT := 0.026
## The writer_hand_test's grip band: the grip sits 43 mm below the Pen origin
## along the shaft axis (26 mm up from the nib tip).
const GRIP_BELOW_PEN := -0.043
## Clearance the finger pads leave to the shaft surface: the tip centreline
## sits this far outside the barrel, and the low cap closes the rest of the gap.
const GAP := 0.0012
const ROLL_DEG := 24.0

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
var _hand_mesh: ArrayMesh
## The shaft's axis and span in sheet space, for the grip tips and the
## upper-clearance guard. Taken from the scene's real Shaft node, so the
## generator and writer_hand_test measure in exactly the same frame.
var _axis_origin: Vector3
var _axis_dir: Vector3
var _shaft_half: float
var _shaft_r_bottom: float
var _shaft_r_top: float
var _grip_along: float
var _upper_from: float
var _upper_to: float
var _worst_clearance: float = INF
var _moved: int = 0
var _worst_move: float = 0.0

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
	_upper_from = _grip_along + 0.028
	_upper_to = 0.105
	# --- hand frame: resting on the little-finger edge, wrist low ------------
	var wrist := nib_tip + WRIST_OFF
	var knuckles := wrist + KNUCKLE_DIR.normalized() * PALM_LEN
	var fwd := (knuckles - wrist).normalized()
	var roll := deg_to_rad(ROLL_DEG)
	var tilt := Vector3(sin(roll), cos(roll), 0.0)
	_back = (tilt - fwd * fwd.dot(tilt)).normalized()
	var thumb_side := _back.cross(fwd).normalized()
	if thumb_side.x > 0.0:
		thumb_side = -thumb_side
	_thumb_side = thumb_side
	var k_index := knuckles + thumb_side * 0.034 + fwd * 0.002 + _back * 0.004
	var k_middle := knuckles + thumb_side * 0.011 + fwd * 0.006 + _back * 0.004
	var k_ring := knuckles - thumb_side * 0.012 + fwd * 0.003 + _back * 0.003
	var k_little := knuckles - thumb_side * 0.035 - fwd * 0.006 + _back * 0.002

	# --- the pen lies in the web between thumb and index -------------------------
	# Its line runs from the nib over the web just behind the index knuckle,
	# which is what points the cap back toward the shoulder. The web is set far
	# enough back (dorsally) that the shaft clears the knuckle ridge.
	var web := k_index - fwd * 0.022 + _back * 0.026 + thumb_side * 0.024
	var a := (web - nib_tip).normalized()
	var grip := nib_tip + a * GRIP_HEIGHT
	var pen_up := (Vector3.UP - a * a.dot(Vector3.UP)).normalized()
	var pen_left := a.cross(pen_up).normalized()
	if pen_left.x > 0.0:
		pen_left = -pen_left
	print("PEN elevation %.1f deg" % rad_to_deg(asin(a.y)))
	print("REACH wrist->grip %.1f mm  wrist->knuckles %.1f mm  knuckles->grip %.1f mm" % [
		wrist.distance_to(grip) * 1000.0, wrist.distance_to(knuckles) * 1000.0, knuckles.distance_to(grip) * 1000.0])
	_hand_mesh = ArrayMesh.new()

	# Palm: wrist -> knuckle ridge. Sections widen and flatten; the thenar
	# swells on the thumb side and the knuckle ridge domes where the fingers
	# leave it. It starts inside the cuff with a full, round wrist.
	var palm_rings := [[wrist + ELBOW_DIR.normalized() * 0.024, 0.028, 0.021]]
	for i in 7:
		var t := float(i) / 6.0
		var c := wrist.lerp(knuckles, t) + _back * 0.004 * sin(t * PI)
		# The thenar (thumb-side) mass, largest just past the wrist.
		var thenar := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.45, 0.95, t))
		c += thumb_side * 0.006 * thenar
		var rx := lerpf(0.030, 0.040, smoothstep(0.0, 0.72, t))
		var ry := lerpf(0.017, 0.012, t)
		# A shallow knuckle ridge, not a slab edge.
		rx *= 1.0 + 0.06 * smoothstep(0.78, 1.0, t)
		palm_rings.append([c, rx, ry])
	_part(palm_rings, fwd, _back, _palm_color, true, true)

	# Index: arches over the pen, its tip pad on the shaft's upper face.
	var i_tip := _grip_tip(0.010, pen_up, GAP)
	# Middle: curls further under; the side of its last joint supports the
	# shaft from below-left.
	var m_tip := _grip_tip(-0.002, (-pen_up * 0.72 - pen_left * 0.78).normalized(), GAP)
	# Thumb: CMC on the thenar, not at the sleeve; its pad wraps the shaft's
	# left face.
	var t_tip := _grip_tip(0.002, pen_left, GAP)
	var cmc := wrist + fwd * 0.030 + thumb_side * 0.026 + _back * 0.004

	# Surfaces are emitted in the order the hand test names them:
	# palm, index, middle, ring, little, thumb.
	_part(_finger_chain(k_index, i_tip, pen_up, 0.011), fwd, _back, _inked_finger_color, false, false, 0.0100, 0.0072, true)
	_part(_finger_chain(k_middle, m_tip, (-pen_up * 0.72 - pen_left * 0.78).normalized(), 0.009), fwd, _back, _inked_finger_color, false, false, 0.0100, 0.0070, true)

	# Ring and little: tucked into the palm, their middle knuckles on the paper.
	for pair in [[k_ring, 0.0082, 0.032, 0.011], [k_little, 0.0070, 0.028, 0.010]]:
		var k: Vector3 = pair[0]
		var r0: float = pair[1]
		var f1: float = pair[2]
		var f2: float = pair[3]
		var pip: Vector3 = k + fwd * f1
		pip.y = r0 * 0.95
		var dip: Vector3 = pip + fwd * f2 - _back * 0.005
		dip.y = r0 * 0.70
		var tip: Vector3 = dip - fwd * 0.005 - _back * 0.003
		tip.y = r0 * 0.58
		_part([k, pip, dip, tip], fwd, _back, _finger_color, false, false, r0, r0 * 0.80, true)

	_part(_finger_chain(cmc, t_tip, pen_left, 0.012), thumb_side, _back, _finger_color, false, false, 0.0130, 0.0098, true)

	_save(_hand_mesh, "hand_v3", _material(1.0))
	print("CLEARANCE guard: rings moved %d, worst move %.2f mm, min upper clearance %.2f mm" % [
		_moved, _worst_move * 1000.0, _worst_clearance * 1000.0])

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

	# --- shirt sleeve (Sleeve-local): over the near edge, down onto the desk --
	var sleeve := SurfaceTool.new()
	sleeve.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := wrist + ELBOW_DIR.normalized() * 0.035
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
	_loft(sleeve, rings, ELBOW_DIR.normalized(), Vector3.UP, _sleeve_color, true, false, _sleeve_inv)
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

## Builds one part (palm or a finger) as its own surface of the hand mesh.
func _part(rings_pts: Array, first_dir: Vector3, up_hint: Vector3, color_fn: Callable,
		cap_start: bool, cap_end: bool, r0: float = -1.0, r1: float = -1.0, nail: bool = false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	if r0 < 0.0:
		rings = rings_pts
		_clear_rings(rings, cap_start or cap_end, false)
	else:
		# Clear the control points BEFORE smoothing, so the guard bends a joint
		# instead of punching one ring out into a spike.
		var cleared := []
		for j in rings_pts.size():
			var t := float(j) / float(rings_pts.size() - 1)
			var rj := lerpf(r0, r1, t)
			var cap := _cap_height(rj, true) if (j == 0 or j == rings_pts.size() - 1) else 0.0
			cleared.append(_clear_point(rings_pts[j], rj, _chain_dir(rings_pts, j), cap))
		var path := _smooth(cleared, 5)
		var n := path.size()
		for i in n:
			var t := float(i) / float(n - 1)
			# A shallow bulge at each joint, not a bead necklace.
			var bulge := 1.0 + 0.06 * pow(cos(t * 3.0 * PI), 10.0) * (1.0 - t * 0.6)
			var r := lerpf(r0, r1, t) * bulge
			# Clear again after smoothing: the curve cuts corners the cleared
			# control points do not bound.
			var cap := _cap_height(r, true) if (i == 0 or i == n - 1) else 0.0
			rings.append([_clear_point(path[i], r, _chain_dir(path, i), cap), r, r * 0.9])
	_loft(st, rings, first_dir, up_hint, color_fn, cap_start, cap_end, _hand_inv, r0 >= 0.0)
	if nail:
		_nail(st, rings)
	st.generate_normals()
	_hand_mesh = st.commit(_hand_mesh)
	_hand_mesh.surface_set_material(_hand_mesh.get_surface_count() - 1, _material(1.0))

## The test's contract, enforced at authoring time: in the band above the grip
## the shaft must run clear of the hand. A point whose surface would enter the
## shaft is pushed out along the shaft's radial by exactly the deficit, so a pose
## tweak can never silently pass the generator and fail the test.
func _clear_point(c: Vector3, r: float, normal: Vector3, cap_height: float) -> Vector3:
	var rel := c - _axis_origin
	var along: float = rel.dot(_axis_dir)
	# A ring's vertices span +-r along the axis from its centre, so the span is
	# padded by r: otherwise a ring just off the end still pokes a vertex in.
	if along + r < -_shaft_half or along - r > _shaft_half:
		return c
	var radial := rel - _axis_dir * along
	var dist := radial.length()
	var dir := radial.normalized() if dist > 1e-6 else Vector3.UP
	var toward: float = normal.normalized().dot(dir)
	# How far this ring reaches TOWARD the axis:
	#   - its vertices, by r x sin(angle between the ring plane and the radial);
	#   - its cap apex, by the cap height when the cap points at the barrel.
	# A ring around the barrel reaches the full r; a fingertip pad facing the
	# shaft reaches only its own cap height. Using r for both would shove a pad
	# off the pen it is meant to be touching.
	var ring_reach := r * sqrt(maxf(0.0, 1.0 - toward * toward))
	# The cap apex can point at the barrel whichever way the ring's normal runs,
	# so the cap term is taken at full height — it is small for a finger and only
	# the palm's knuckle ridge has a large one.
	var reach := maxf(ring_reach, cap_height)
	var shaft_r := _shaft_radius(along)
	# Above the grip the shaft must run CLEAR of the hand; everywhere else the
	# surface may touch it but never enter it.
	var margin := 0.0015 if (along + r > _upper_from and along - r <= _upper_to) else 0.0002
	var need := shaft_r + reach + margin
	_worst_clearance = minf(_worst_clearance, maxf(dist, need) - shaft_r - reach)
	if dist < need:
		_moved += 1
		_worst_move = maxf(_worst_move, need - dist)
		return _axis_origin + _axis_dir * along + dir * need
	return c

func _clear_rings(rings: Array, has_cap: bool, soft: bool) -> void:
	var n := rings.size()
	for i in n:
		var nxt: Vector3 = rings[mini(i + 1, n - 1)][0]
		var prv: Vector3 = rings[maxi(i - 1, 0)][0]
		var dir := nxt - prv
		dir = dir.normalized() if dir.length() > 1e-6 else _axis_dir
		var cap := _cap_height(float(rings[i][1]), soft) if (has_cap and (i == 0 or i == n - 1)) else 0.0
		rings[i][0] = _clear_point(rings[i][0], float(rings[i][1]), dir, cap)

## The ring's local direction at control point `i` of a chain.
func _chain_dir(points: Array, i: int) -> Vector3:
	var nxt: Vector3 = points[mini(i + 1, points.size() - 1)]
	var prv: Vector3 = points[maxi(i - 1, 0)]
	var dir := nxt - prv
	return dir.normalized() if dir.length() > 1e-6 else _axis_dir

## The cap's apex sits this far past its end ring (`_cap`): `0.55 x r` for a
## shallow dome, `0.28 x r` for the flattened fingertip pad.
func _cap_height(r: float, soft: bool) -> float:
	return r * (0.28 if soft else 0.55)

## The last line of defence: any hand vertex that would land inside the shaft is
## pushed to the barrel's surface (plus the upper-clearance margin above the
## grip). The ring-level guard shapes the part; this guarantees the contract on
## the vertices actually emitted — ellipse points and cap apexes included.
func _clamp_vertex(p: Vector3) -> Vector3:
	var rel := p - _axis_origin
	var along: float = rel.dot(_axis_dir)
	if along < -_shaft_half or along > _shaft_half:
		return p
	var radial := rel - _axis_dir * along
	var dist := radial.length()
	var need := _shaft_radius(along) + (0.0015 if along > _upper_from else 0.0002)
	if dist < need:
		var dir := radial.normalized() if dist > 1e-6 else Vector3.UP
		return _axis_origin + _axis_dir * along + dir * need
	return p

## Three phalanges from a knuckle to a tip, laid on a circular arc so the finger
## curls smoothly instead of looping back. The arc's sagitta is the joint
## "hump"; the tip's last segment runs along `tip_dir` (the shaft's radial), so
## the pad and its low cap face the barrel. Arc length follows the phalanx
## lengths (proximal 0.45, middle 0.30, distal 0.25 of the total), and the arc is
## capped at the straight-line distance so a short reach stays a gentle curve.
func _finger_chain(knuckle: Vector3, tip: Vector3, tip_dir: Vector3, hump: float) -> Array:
	var chord := tip - knuckle
	var length := chord.length()
	var u := chord.normalized()
	# The bow direction: perpendicular to the chord, on the dorsal side, so the
	# joint humps up over the barrel rather than away from it.
	var bow := _back - u * _back.dot(u)
	bow = bow.normalized() if bow.length() > 1e-4 else u.cross(tip_dir).normalized()
	var max_sag := minf(hump, length * 0.30)
	var centre := knuckle + chord * 0.5 + bow * max_sag
	var radius := max_sag * 0.5 + (length * length) / (8.0 * maxf(max_sag, 1e-5))
	# Sweep angles from knuckle to tip around the arc centre.
	var a0 := (knuckle - centre)
	var a1 := (tip - centre)
	var start := atan2((bow.dot(a0)), (u.dot(a0)))
	var finish := atan2((bow.dot(a1)), (u.dot(a1)))
	var phalanges := [0.45, 0.30, 0.25]
	var points := [knuckle]
	var acc := 0.0
	for f in phalanges:
		acc += f
		var ang: float = lerpf(start, finish, acc)
		points.append(centre + u * cos(ang) * radius + bow * sin(ang) * radius)
	# The last control point IS the tip, and the final segment must run along
	# tip_dir so the tip ring faces the barrel.
	points[points.size() - 1] = tip
	points[points.size() - 2] = tip + tip_dir.normalized() * (length * 0.22)
	return points
func _grip_tip(offset_along: float, dir: Vector3, r: float) -> Vector3:
	var along := _grip_along + offset_along
	return _axis_origin + _axis_dir * along + dir.normalized() * (_shaft_radius(along) + r)

func _shaft_radius(along: float) -> float:
	# `along` is measured from the shaft's own centre (origin), so the bottom cap
	# is at -half and the top at +half.
	var t: float = clampf((along + _shaft_half) / (_shaft_half * 2.0), 0.0, 1.0)
	return lerpf(_shaft_r_bottom, _shaft_r_top, t)

## A bounded nail plane on the dorsal side of a distal phalanx: a small flat
## quad, slightly proud of the tube — not a coloured whole tip.
func _nail(st: SurfaceTool, rings: Array) -> void:
	var n := rings.size()
	var tip: Vector3 = rings[n - 1][0]
	var r_tip: float = rings[n - 1][1]
	var prev: Vector3 = rings[maxi(n - 4, 0)][0]
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

## Centripetal Catmull-Rom (alpha = 0.5). Uniform Catmull-Rom overshoots and
## loops when the knots are unevenly spaced (a 41 mm joint beside a 5 mm one),
## which is what made the tucked fingers bulge; centripetal parameterisation
## cannot cusp or self-intersect.
func _smooth(points: Array, steps: int) -> Array:
	var out := []
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		var t0 := 0.0
		var t1 := t0 + pow(maxf(p1.distance_to(p0), 1e-5), 0.5)
		var t2 := t1 + pow(maxf(p2.distance_to(p1), 1e-5), 0.5)
		var t3 := t2 + pow(maxf(p3.distance_to(p2), 1e-5), 0.5)
		for s in steps:
			var t: float = lerpf(t1, t2, float(s) / float(steps))
			var a1: Vector3 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
			var a2: Vector3 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
			var a3: Vector3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
			var b1: Vector3 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
			var b2: Vector3 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
			out.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
	out.append(points[points.size() - 1])
	return out

## Loft rings [centre, rx, ry] (sheet space). `up_hint` orients the ellipses
## (ry along it); `color_fn(t, radial_dir)` colours each vertex; `to_local`
## maps the result into the owning joint's space. `soft_cap` flattens the end
## cap so a fingertip is a pad, not a ball.
func _loft(st: SurfaceTool, rings: Array, first_dir: Vector3, up_hint: Vector3, color_fn: Callable,
		cap_start: bool, cap_end: bool, to_local: Transform3D, soft_cap: bool = false) -> void:
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
			ring.append(to_local * _clamp_vertex(c + side * cos(ang) * float(rings[i][1]) + up * sin(ang) * float(rings[i][2])))
			ring_cols.append(color_fn.call(t, d))
		verts.append(ring)
		cols.append(ring_cols)
	for i in count - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			_tri(st, verts[i][k], verts[i + 1][k2], verts[i][k2], cols[i][k], cols[i + 1][k2], cols[i][k2])
			_tri(st, verts[i][k], verts[i + 1][k], verts[i + 1][k2], cols[i][k], cols[i + 1][k], cols[i + 1][k2])
	if cap_start:
		_cap(st, verts[0], cols[0], true, soft_cap)
	if cap_end:
		_cap(st, verts[count - 1], cols[count - 1], false, soft_cap)

## A cap over a ring. `soft` keeps the apex low (a fingertip pad); otherwise a
## shallow dome sits past the ring's own plane.
func _cap(st: SurfaceTool, ring: Array, cols: Array, at_start: bool, soft: bool) -> void:
	var mean := Vector3.ZERO
	for v in ring:
		mean += v
	mean /= float(ring.size())
	var normal: Vector3 = (ring[1] - ring[0]).cross(ring[2] - ring[0]).normalized()
	var radius: float = (ring[0] - mean).length()
	var height: float = radius * (0.28 if soft else 0.55)
	var apex := mean + normal * height * (-1.0 if at_start else 1.0)
	apex = _clamp_vertex(apex)
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
