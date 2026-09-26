extends SceneTree

## C2: the tilted writing surfaces are physically honest. The writing sheet
## and the reference card lean on real supports — the near edge rests exactly
## on the desk top, the far edge on its wedge, and the archived sheet slides
## FLAT across the desk. No corner of any sheet may sink under the desk
## surface or hang in the air without support.
## Also guards the Q1 readability budget: the projected letter height on the
## tilted sheet must not fall below the working-read target.

var _assertions_passed: int = 0

const PAPER_HALF_X: float = 0.115
const PAPER_HALF_Z: float = 0.15
const CARD_HALF_X: float = 0.15
const CARD_HALF_Z: float = 0.15

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Desk Geometry Test Suite ---")
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var desk_top := office.get_node("DeskSetup/DeskTop") as CSGBox3D
	var desk_y: float = desk_top.global_position.y + desk_top.size.y / 2.0
	if not assert_condition(desk_y > 0.7 and desk_y < 0.8, "Desk top surface found at %.3f m" % desk_y): return

	# --- the writing sheet: near edge on the desk, far edge on the wedge ----
	var paper := office._get_transcript_paper()
	var sheet := paper.get_sheet_node()
	var corners := _sheet_corners(sheet, PAPER_HALF_X, PAPER_HALF_Z)
	var min_y := _min_corner_y(corners)
	var near_y := _nearest_edge_y(sheet, PAPER_HALF_Z)
	var far_y := _farthest_edge_y(sheet, PAPER_HALF_Z)
	if not assert_condition(min_y >= desk_y - 0.002, "No corner of the writing sheet sinks under the desk (min %.4f vs desk %.4f)" % [min_y, desk_y]): return
	if not assert_condition(near_y <= desk_y + 0.005, "The near edge rests on the desk (%.4f)" % near_y): return
	if not assert_condition(far_y > near_y + 0.05, "The far edge is raised onto its support (%.4f > %.4f)" % [far_y, near_y]): return

	# The support itself: a solid under the far edge, top flush with it.
	var support := office.get_node_or_null("PaperSlopeSupport") as CSGBox3D
	if not assert_condition(support != null, "The writing slope has a physical support"): return
	var support_top: float = support.global_position.y + support.size.y / 2.0
	if not assert_condition(absf(support_top - far_y) < 0.004, "The support's top is flush with the far edge (support %.4f, edge %.4f)" % [support_top, far_y]): return

	# --- the reference card: same honesty -----------------------------------
	var card := office.get_node("MorseReferenceCard") as Node3D
	var card_corners := _card_corners(card)
	var card_min := _min_corner_y(card_corners)
	var card_near := _nearest_edge_y(card, CARD_HALF_Z)
	var card_far := _farthest_edge_y(card, CARD_HALF_Z)
	if not assert_condition(card_min >= desk_y - 0.002, "No corner of the reference card sinks under the desk (min %.4f)" % card_min): return
	if not assert_condition(card_near <= desk_y + 0.005, "The card's near edge rests on the desk (%.4f)" % card_near): return
	if not assert_condition(card_far > card_near + 0.04, "The card leans on its support (%.4f > %.4f)" % [card_far, card_near]):
		return
	var card_support := office.get_node_or_null("CardSlopeSupport") as CSGBox3D
	if not assert_condition(card_support != null and absf(card_support.global_position.y + card_support.size.y / 2.0 - card_far) < 0.004, "The card's support is flush with its far edge"): return

	# --- nothing overhangs the desk: every corner is above the top's footprint
	var top_aabb := desk_top.global_transform * AABB(-desk_top.size / 2.0, desk_top.size)
	for c in corners + card_corners:
		if not assert_condition(
				c.x >= top_aabb.position.x - 0.002 and c.x <= top_aabb.end.x + 0.002
				and c.z >= top_aabb.position.z - 0.002 and c.z <= top_aabb.end.z + 0.002,
				"Paper corner (%.3f, %.3f) lies over the desk top" % [c.x, c.z]):
			return

	# --- the archived sheet slides flat, never underground -------------------
	var session := office.session_controller
	office.shift_director.enabled = false
	session.allow_key_start = true
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.stand_duration = 0.0
	office.operator_seat.sit()
	office.load_scenario_by_index(0)
	session.start_transmission()
	session.scheduler.auto_process = false
	session.scheduler.advance_time(60.0)
	var paper2 := office._get_transcript_paper()
	var guard := 0
	while paper2.is_copy_in_progress() and guard < 400:
		paper2.advance_paper(0.25)
		guard += 1
	session.mark_transcript_verified()
	session.submit_routing_decision("CLEAR EAST")
	# The next slot's telegram starts: begin_writing archives the finished
	# sheet and slides it flat across the desk.
	office.load_scenario_by_index(1)
	session.start_transmission()
	session.scheduler.auto_process = false
	session.scheduler.advance_time(1.0)
	var previous := paper2.get_previous_sheet_node()
	if not assert_condition(previous != null and previous.visible, "The finished sheet archived"): return
	paper2.advance_paper(paper2.previous_slide_seconds + 0.01)
	var prev_corners := _sheet_corners(previous, PAPER_HALF_X, PAPER_HALF_Z)
	var prev_min := _min_corner_y(prev_corners)
	if not assert_condition(prev_min >= desk_y - 0.004, "The archived sheet lies flat on the desk (min %.4f)" % prev_min): return
	var prev_near := _nearest_edge_y(previous, PAPER_HALF_Z)
	if not assert_condition(absf(prev_near - desk_y) < 0.006, "The archived sheet rests on the desk surface (%.4f vs %.4f)" % [prev_near, desk_y]): return

	# --- Q1 budget survives the lift: projected letter height ---------------
	office.operator_seat.sit()
	await process_frame
	await process_frame
	var lbl := paper2.get_label_3d()
	var font := lbl.font if lbl.font != null else ThemeDB.fallback_font
	var cam := office.player.camera
	var a := cam.unproject_position(lbl.to_global(Vector3.ZERO))
	var b := cam.unproject_position(lbl.to_global(Vector3(0, -font.get_height(lbl.font_size) * lbl.pixel_size, 0)))
	var full_px := a.distance_to(b)
	if not assert_condition(full_px >= 20.0, "Live lettering keeps its projected size (%.1f px full height at 720p)" % full_px): return

	office.queue_free()
	await process_frame
	await process_frame
	print("--- All Desk Geometry Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

## World-space corners of a sheet in the XY-plane sense: the four combinations
## of the local rectangle (x across, z down the sheet).
func _sheet_corners(sheet: Node3D, half_x: float, half_z: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-half_x, half_x]:
		for sz in [-half_z, half_z]:
			out.append(sheet.to_global(Vector3(sx, 0.0, sz)))
	return out

func _card_corners(card: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-CARD_HALF_X, CARD_HALF_X]:
		for sz in [-CARD_HALF_Z, CARD_HALF_Z]:
			out.append(card.to_global(Vector3(sx, 0.0, sz)))
	return out

func _min_corner_y(corners: Array[Vector3]) -> float:
	var m := INF
	for c in corners:
		m = minf(m, c.y)
	return m

## The lowest edge of the sheet in world space: sample the two edges along the
## slope axis and take the lower midpoint (the edge nearest the desk).
func _nearest_edge_y(sheet: Node3D, half_z: float) -> float:
	var e1 := sheet.to_global(Vector3(0.0, 0.0, half_z))
	var e2 := sheet.to_global(Vector3(0.0, 0.0, -half_z))
	return minf(e1.y, e2.y)

func _farthest_edge_y(sheet: Node3D, half_z: float) -> float:
	var e1 := sheet.to_global(Vector3(0.0, 0.0, half_z))
	var e2 := sheet.to_global(Vector3(0.0, 0.0, -half_z))
	return maxf(e1.y, e2.y)

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
