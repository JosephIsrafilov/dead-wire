extends SceneTree
## Plan 6.5: the train-order signal is worked in the room. No 2D overlay is
## drawn over it, an E aimed at the backboard opens nothing, the order is
## given at the lever's notches, the notch plates keep their names whole, the
## repeater shows what the arm outside shows, and the rules hang beside it.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/routing_board_overlay_test.gd

var _assertions: int = 0

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

	# --- 1. Nothing is drawn over the room ---------------------------------
	if not _a(board.find_children("*", "CanvasLayer", true, false).is_empty(),
		"The signal draws no 2D overlay of its own"): return
	board.set_awaiting_route(true)
	var face := board.get_interactable()
	if not _a(face != null and not face.is_actionable, "The backboard is status, not an action"): return
	face.interact()
	if not _a(not board.is_open, "An E on the backboard opens nothing"): return

	# --- 2. The order is given at a notch --------------------------------------
	var clear_stop := board.get_node_or_null("ClearStopInteractable") as Interactable
	var hold_stop := board.get_node_or_null("HoldStopInteractable") as Interactable
	if not _a(clear_stop != null and hold_stop != null and clear_stop.enabled and hold_stop.enabled,
		"Both notches take an order while one is awaited"): return
	if not _a(clear_stop.position.x < 0.0 and hold_stop.position.x > 0.0,
		"CLEAR EAST and HOLD sit on opposite sides of the quadrant"): return

	# --- 3. The notch plates keep their names whole -----------------------------
	_check_plate(board, "ClearEastLabel3D", "PlateClear")
	_check_plate(board, "HoldLabel3D", "PlateHold")

	# --- 4. The repeater answers the lever like the arm outside ---------------
	var blade := board.get_node_or_null("IndicatorPivot") as Node3D
	if not _a(blade != null and is_zero_approx(blade.rotation.z), "At rest the repeater stands at STOP"): return
	var detached := scene.instantiate() as RoutingBoard
	detached._throw_lever("CLEAR EAST")
	var clear_blade: float = (detached.get_node("IndicatorPivot") as Node3D).rotation.z
	detached._throw_lever("HOLD")
	var hold_blade: float = (detached.get_node("IndicatorPivot") as Node3D).rotation.z
	if not _a(clear_blade < -0.5 and is_zero_approx(hold_blade),
		"CLEAR drops the blade, HOLD stands it level (%.2f / %.2f rad)" % [clear_blade, hold_blade]): return
	detached.free()

	# --- 5. The rules hang beside it, strict and readable ---------------------
	if not _a(board.rules_text.contains("221.") and board.rules_text.contains("STOP"),
		"The signal rules are authored beside the lever"): return
	var rules_label := board.get_node_or_null("SignalRules/Text") as Label3D
	if not _a(rules_label != null and rules_label.text.begins_with(board.rules_title),
		"The framed sheet carries the rules"): return
	var rules_act := board.get_node_or_null("SignalRules/Interactable") as Interactable
	if not _a(rules_act != null and rules_act.is_actionable, "The rules can be taken up and read"): return

	board.queue_free()
	await process_frame
	print("--- All Routing Board Overlay Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## A notch plate's text, measured with real font metrics, fits its enamel.
func _check_plate(board: RoutingBoard, label_name: String, plate_name: String) -> void:
	var label := board.get_node_or_null(label_name) as Label3D
	var plate := board.get_node_or_null(plate_name) as CSGBox3D
	if not _a(label != null and plate != null, "%s sits on %s" % [label_name, plate_name]): return
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
	_a(width <= plate.size.x - 0.01 and absf(label.position.x - plate.position.x) < 0.005,
		"%s keeps its whole name on the plate (%.3f m of %.3f m)" % [label_name, width, plate.size.x])

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
