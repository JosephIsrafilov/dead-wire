extends SceneTree

## C2: the working surfaces are physically honest. The copy sheet lies flat on
## its pad on the copy board on the blotter; the reference card lies on the
## blotter; the archived sheet slides flat across the desk. No corner of any
## sheet may sink under the desk surface, hang in the air, or overhang the top.
## Also guards the Q1 readability budget: the projected letter height on the
## flat sheet must not fall below the working-read target.

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

	# --- the working surfaces lie flat: operators copied on the desk --------
	# The copy board rests on the blotter, the pad on the board, the sheet on
	# the pad; the reference card lies on the blotter. Nothing leans on wedges.
	var blotter := office.get_node_or_null("DeskBlotter") as CSGBox3D
	if not assert_condition(blotter != null, "The desk has its blotter"): return
	var blotter_y: float = blotter.global_position.y + blotter.size.y / 2.0
	var paper := office._get_transcript_paper()
	var sheet := paper.get_sheet_node()
	var corners := _sheet_corners(sheet, PAPER_HALF_X, PAPER_HALF_Z)
	var min_y := _min_corner_y(corners)
	var max_y := -INF
	for c in corners:
		max_y = maxf(max_y, c.y)
	if not assert_condition(max_y - min_y < 0.001, "The writing sheet lies flat (%.4f spread)" % (max_y - min_y)): return
	var board := paper.get_node_or_null("CopyBoard") as CSGBox3D
	if not assert_condition(board != null, "The sheet sits on a copy board"): return
	var board_bottom: float = board.global_position.y - board.size.y / 2.0
	if not assert_condition(absf(board_bottom - blotter_y) < 0.0015, "The copy board rests on the blotter (%.4f vs %.4f)" % [board_bottom, blotter_y]): return
	if not assert_condition(min_y >= board.global_position.y + board.size.y / 2.0 - 0.0005, "The sheet is on the pad, not inside the board"): return
	if not assert_condition(office.get_node_or_null("PaperSlopeSupport") == null, "No slope wedge is left behind"): return

	# The reference card is pinned upright to the wall above the desk, facing
	# the operator, clear of the desk's working surface.
	var card := office.get_node("MorseReferenceCard") as Node3D
	var card_normal := card.global_transform.basis.y.normalized()
	if not assert_condition(card_normal.dot(Vector3.RIGHT) > 0.99, "The reference card faces the operator from the wall"): return
	if not assert_condition(card.global_position.x < -2.84 and card.global_position.y > desk_y + 0.25, "The card hangs on the wall above the desk"): return
	if not assert_condition(office.get_node_or_null("CardSlopeSupport") == null, "No card wedge is left behind"): return

	# --- the desk is laid out, not piled: nothing intrudes on anything -------
	var board_rect := _footprint(board)
	var key_rect := _footprint(office.get_node("TelegraphStation/TelegraphKey/WoodBase") as VisualInstance3D)
	if not assert_condition(not board_rect.intersects(key_rect), "The telegraph key stands clear of the copy board"): return
	var rack_rect := _footprint(office.get_node("DeskSetup/OrganizerBottom") as VisualInstance3D)
	var ledger_rect := _footprint(office.get_node("DispatchLedger/BookMesh") as VisualInstance3D)
	if not assert_condition(not rack_rect.intersects(ledger_rect), "The ledger is not pushed under the pigeonholes"): return
	var rack_bottom := office.get_node("DeskSetup/OrganizerBottom") as CSGBox3D
	var rack_y: float = rack_bottom.global_position.y - rack_bottom.size.y / 2.0
	if not assert_condition(absf(rack_y - desk_y) < 0.002, "The pigeonholes stand on the desk (%.4f vs %.4f)" % [rack_y, desk_y]): return
	var flame := office.get_node("DeskSetup/OilLamp/Flame") as Node3D
	var lamp_light := office.get_node("DeskLampLight") as Node3D
	if not assert_condition(lamp_light.global_position.distance_to(flame.global_position) < 0.1, "The lamp's light comes from its flame"): return

	# --- nothing overhangs the desk: every corner is above the top's footprint
	var top_aabb := desk_top.global_transform * AABB(-desk_top.size / 2.0, desk_top.size)
	for c in corners:
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
	var prev_rect := Rect2()
	for i in prev_corners.size():
		var c: Vector3 = prev_corners[i]
		prev_rect = Rect2(Vector2(c.x, c.z), Vector2.ZERO) if i == 0 else prev_rect.expand(Vector2(c.x, c.z))
	if not assert_condition(not prev_rect.grow(-0.002).intersects(_footprint(paper2.get_node("CopyBoard") as VisualInstance3D)), "The archived sheet is set down beside the board, not under it"): return
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

## Top-down footprint (x, z) of a visual in world space.
func _footprint(node: VisualInstance3D) -> Rect2:
	var box := node.global_transform * node.get_aabb()
	return Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))

func _min_corner_y(corners: Array[Vector3]) -> float:
	var m := INF
	for c in corners:
		m = minf(m, c.y)
	return m

## The lowest edge of the sheet in world space: sample the two edges along the
## sheet's length and take the lower midpoint.
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
