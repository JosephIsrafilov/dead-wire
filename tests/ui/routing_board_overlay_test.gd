extends SceneTree
## The routing board's modal overlay says one thing only: how to put the
## board down. The orders themselves are the buttons; the hint must never be
## covered by them. And the physical plates on the board face must keep their
## full text clear of the frame — a clipped "CLEAR EAS" misnames an order.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/routing_board_overlay_test.gd

var _assertions: int = 0

const HINT_TEXT := "[Esc] Put down board; the line clock keeps running"
## Inner faces of the left/right frame posts (frame at x=±0.42, width 0.12).
const FRAME_INNER_X := 0.36
## The plate tail must stay this far inside the frame: the label sits 2.2 cm
## behind the frame's front face, so a small clearance is eaten by parallax
## from any angled view (the 2026-10-09 capture shows it: "CLEAR EAS").
const FRAME_MARGIN := 0.03
## Indicator dial: centre (0, 0.215), radius 0.05, in FRONT of the plates.
const DIAL_EDGE_X := 0.05
const DIAL_MARGIN := 0.005

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Routing Board Overlay Test Suite ---")
	var scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/routing_board.tscn")
	if not _a(scene != null, "routing_board.tscn loads"): return
	var board := scene.instantiate() as RoutingBoard
	if not _a(board != null, "The board instantiates"): return
	root.add_child(board)
	await process_frame

	# --- 1. The open board shows one hint line and the two order buttons ---
	board.set_awaiting_route(true)
	board.open_board()
	await process_frame
	var panel := board.get_node_or_null("RoutePromptUI/Panel") as Control
	if not _a(panel != null and panel.visible, "The opened board shows its prompt panel"): return
	var hint := board.get_node_or_null("RoutePromptUI/Panel/Label") as Label
	if not _a(hint != null, "The hint label exists"): return
	var clear_button := board.get_node_or_null("RoutePromptUI/Panel/ClearEastButton") as Button
	var hold_button := board.get_node_or_null("RoutePromptUI/Panel/HoldButton") as Button
	if not _a(clear_button != null and hold_button != null, "Both order buttons exist on the panel"): return
	if not _a(clear_button.text == "[1] CLEAR EAST" and hold_button.text == "[2] HOLD",
		"The buttons alone carry the order names and their keys"): return
	if not _a(hint.text == HINT_TEXT,
		"The hint is the single Esc line, got '%s'" % hint.text): return
	if not _a(not hint.text.contains("\n"), "The hint is one line, not a stacked cheat sheet"): return

	# --- 2. Nothing intersects: the buttons never cover the hint ---
	var hint_rect := hint.get_global_rect()
	var clear_rect := clear_button.get_global_rect()
	var hold_rect := hold_button.get_global_rect()
	if not _a(not hint_rect.intersects(clear_rect),
		"The hint band sits clear of the CLEAR EAST button"): return
	if not _a(not hint_rect.intersects(hold_rect),
		"The hint band sits clear of the HOLD button"): return
	var font := hint.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var line_height := font.get_height(hint.get_theme_font_size("font_size"))
	if not _a(line_height <= hint_rect.size.y,
		"The hint text fits inside its own rect (no overflow under the buttons)"): return

	# --- 3. The physical plates keep their full text inside the board face ---
	_check_plate(board, "ClearEastLabel3D", -1.0)
	_check_plate(board, "HoldLabel3D", 1.0)

	board.close_board()
	board.queue_free()
	await process_frame
	print("--- All Routing Board Overlay Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Measures a plate the way the engine renders it (real font metrics × the
## label's pixel_size) and guards both occluders: the frame post in front of
## the outer edge and the indicator dial in front of the inner edge.
func _check_plate(board: RoutingBoard, node_name: String, side: float) -> void:
	var plate := board.get_node_or_null(node_name) as Label3D
	if not _a(plate != null, "%s exists on the board" % node_name): return
	var font: Font = plate.font if plate.font != null else ThemeDB.fallback_font
	var world_width := font.get_string_size(
		plate.text, HORIZONTAL_ALIGNMENT_LEFT, -1, plate.font_size).x * plate.pixel_size
	var outer_x := plate.position.x + side * world_width / 2.0
	var inner_x := plate.position.x - side * world_width / 2.0
	if not _a(side * outer_x <= FRAME_INNER_X - FRAME_MARGIN,
		"%s keeps its outer end %.0f cm inside the frame, got x=%.4f" % [node_name, FRAME_MARGIN * 100.0, outer_x]): return
	if not _a(abs(inner_x) >= DIAL_EDGE_X + DIAL_MARGIN,
		"%s stays clear of the indicator dial, inner end x=%.4f" % [node_name, inner_x]): return

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
