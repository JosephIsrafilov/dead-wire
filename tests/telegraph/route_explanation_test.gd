extends SceneTree
## Plan 6.5: the signal explains itself in the room — its header, the names on
## its two notches and the framed rules beside it. None of it grades the
## pending choice or names tonight's trains: the rules say how the signal is
## worked, never which way tonight's order should go.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/route_explanation_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Route Explanation Test Suite ---")
	var scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/routing_board.tscn")
	if not assert_condition(scene != null, "routing_board.tscn loads"): return
	var board := scene.instantiate() as RoutingBoard
	root.add_child(board)

	if not assert_condition(board.get_node_or_null("RoutePromptUI") == null, "No overlay explains the signal from outside the room"): return
	var header := board.get_node_or_null("HeaderLabel3D") as Label3D
	if not assert_condition(header != null and header.text == "TRAIN-ORDER SIGNAL", "The signal names itself on its own card"): return
	var clear_plate := board.get_node_or_null("ClearEastLabel3D") as Label3D
	var hold_plate := board.get_node_or_null("HoldLabel3D") as Label3D
	if not assert_condition(clear_plate.text == "CLEAR EAST" and hold_plate.text == "HOLD", "Each notch carries the order it gives"): return
	var clear_stop := board.get_node_or_null("ClearStopInteractable") as Interactable
	if not assert_condition(clear_stop != null and clear_stop.prompt_text.ends_with("CLEAR EAST"), "Aiming at a notch names the order it would give"): return

	var rules := board.rules_text
	if not assert_condition(rules.contains("STOP") and rules.contains("dismissed"), "The rules are strict and say how the signal stands"): return
	if not assert_condition(rules.find("CORRECT") == -1 and rules.find("WRONG") == -1, "The rules do not grade the pending choice"): return
	for tonight in ["TRAIN 17", "FREIGHT", "71", "WATER", "WATCHER"]:
		if not assert_condition(not rules.contains(tonight), "The rules never name tonight's traffic ('%s')" % tonight): return

	board.free()
	print("--- All Route Explanation Tests PASSED ---")
	quit(0)

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok
