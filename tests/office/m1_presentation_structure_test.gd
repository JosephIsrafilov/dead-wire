extends SceneTree

func _init() -> void:
	print("--- Starting M1 Presentation Structure Test Suite (Phase M) ---")

	var office_scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(office_scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = office_scene.instantiate() as M1OfficeController
	if not assert_condition(office != null and office is M1OfficeController, "instantiates as M1OfficeController"): return
	root.add_child(office)

	# 1. PSX Presentation Settings
	if not assert_condition(office.enable_psx_rendering == true, "enable_psx_rendering is true"): return
	if not assert_condition(is_equal_approx(office.render_scale, 0.75), "render_scale is 0.75 for readable PSX presentation"): return

	# 2. No placeholder nodes in production scene
	var placeholder_nodes: Array[String] = []
	_find_placeholders(office, placeholder_nodes)
	if not assert_condition(placeholder_nodes.is_empty(), "Zero placeholder nodes in m1_office.tscn"): return

	# 3. Required physical architecture nodes
	if not assert_condition(office.get_node_or_null("NorthWindow") != null, "NorthWindow exists"): return
	if not assert_condition(office.get_node_or_null("SouthDoor") != null, "SouthDoor exists"): return
	if not assert_condition(office.get_node_or_null("NorthWall_Left") != null, "NorthWall_Left exists"): return
	if not assert_condition(office.get_node_or_null("NorthWall_Right") != null, "NorthWall_Right exists"): return
	if not assert_condition(office.get_node_or_null("DeskSetup") != null, "DeskSetup exists"): return
	if not assert_condition(office.get_node_or_null("DocumentViewer") != null, "DocumentViewer exists"): return
	if not assert_condition(office.player.get_node_or_null("FootstepPlayer") != null, "Player has a spatial footstep player"): return

	# 4. Desk props exist and are distinctly placed
	var paper := office.get_node_or_null("TranscriptPaper")
	var card := office.get_node_or_null("MorseReferenceCard")
	var ledger := office.get_node_or_null("DispatchLedger")
	var station := office.get_node_or_null("TelegraphStation")
	if not assert_condition(paper != null and card != null and ledger != null and station != null, "All 4 desk props exist"): return

	# Verify non-identical positions
	if not assert_condition(paper.position != card.position, "Paper and Card have distinct positions"): return
	if not assert_condition(paper.position != ledger.position, "Paper and Ledger have distinct positions"): return
	if not assert_condition(card.position != ledger.position, "Card and Ledger have distinct positions"): return

	# 5. Routing Board orientation check (facing into room, unmirrored)
	var board: RoutingBoard = office.routing_board
	if not assert_condition(board != null, "RoutingBoard is bound"): return
	var lbl: Label3D = board.get_node_or_null("Label3D") as Label3D
	if not assert_condition(lbl != null, "RoutingBoard has Label3D"): return
	var basis: Basis = lbl.transform.basis
	var det: float = basis.determinant()
	if not assert_condition(det > 0.99 and det < 1.01, "Label3D basis has determinant +1.0 (unmirrored)"): return

	# 6. Scenario 3 has genuine window attention event configured
	var scen3: TelegraphScenarioData = office.scenario_3
	if not assert_condition(scen3 != null, "Scenario 3 is configured"): return
	if not assert_condition(scen3.attention_event_id == "window_figure", "Scenario 3 has window_figure attention event"): return
	if not assert_condition(scen3.attention_event_start_time > 0.0, "Scenario 3 attention start time > 0.0"): return
	var figure := office.get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	var visual := figure.get_visual_indicator() if figure != null else null
	if not assert_condition(visual != null and visual.get_node_or_null("Coat") != null and visual.get_node_or_null("Head") != null and visual.get_node_or_null("HatBrim") != null and visual.get_node_or_null("ShimmerLight") == null, "Window figure retains separate body, head, and hat elements without glow light"): return

	# Clean up
	office.queue_free()

	print("--- All M1 Presentation Structure Tests PASSED ---")
	quit(0)

func _find_placeholders(node: Node, results: Array[String]) -> void:
	if node.name.contains("Placeholder"):
		results.append(node.name)
	for child in node.get_children():
		_find_placeholders(child, results)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
