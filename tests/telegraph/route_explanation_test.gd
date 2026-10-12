extends SceneTree
## The route prompt says what each order physically does, and what Esc does to the
## board, without changing any route authority.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/route_explanation_test.gd

const EXPECTED_TEXT := "[1] CLEAR EAST — send on the main line\n[2] HOLD — keep on the siding\n[Esc] Put down board; the line clock keeps running"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Route Explanation Test Suite ---")
	var scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/routing_board.tscn")
	if not assert_condition(scene != null, "routing_board.tscn loads"): return
	var board := scene.instantiate() as RoutingBoard
	root.add_child(board)

	var panel := board.get_node_or_null("RoutePromptUI/Panel") as Control
	var label := board.get_node_or_null("RoutePromptUI/Panel/Label") as Label
	if not assert_condition(panel != null and label != null, "Route prompt panel and label exist"): return
	var text := label.text

	if not assert_condition(not panel.visible, "Route prompt stays hidden until a decision is pending"): return
	if not assert_condition(text == EXPECTED_TEXT, "Route prompt text matches the approved explanation exactly"): return
	if not assert_condition(text.find("CORRECT") == -1 and text.find("WRONG") == -1, "Route explanation does not grade the pending choice"): return
	if not assert_condition(label.get_theme_font_size("font_size") == 18, "Route prompt uses the 18px font"): return
	if not assert_condition(panel.offset_left == 350.0 and panel.offset_top == 558.0 and panel.offset_right == 930.0 and panel.offset_bottom == 678.0, "Route prompt panel uses the planned bounds (350, 558, 930, 678)"): return
	if not assert_condition(label.offset_left == 14.0 and label.offset_top == 8.0 and label.offset_right == 566.0 and label.offset_bottom == 68.0, "Route prompt label uses the inset bounds leave room for mouse buttons (14, 8, 566, 68)"): return

	board.free()
	print("--- All Route Explanation Tests PASSED ---")
	quit(0)

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok
