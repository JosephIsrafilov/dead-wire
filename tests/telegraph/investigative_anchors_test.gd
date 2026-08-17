extends SceneTree

func _init() -> void:
	print("--- Starting Investigative Anchors Test Suite (Gate 13B) ---")

	# 1. Test Morse Reference Card Scene
	var card_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/morse_reference_card.tscn")
	if not assert_condition(card_scene != null, "morse_reference_card.tscn loads"): return
	var card_node: MorseReferenceCard = card_scene.instantiate() as MorseReferenceCard
	if not assert_condition(card_node != null and card_node is MorseReferenceCard, "instantiates as MorseReferenceCard"): return
	root.add_child(card_node)

	var card_act: Interactable = card_node.get_interactable()
	if not assert_condition(card_act != null, "card has Interactable component"): return
	if not assert_condition(card_act.prompt_text == "Inspect Morse Reference Card", "card prompt text matches"): return

	var ref_text := card_node.get_reference_text()
	var m1_chars := ["A", "C", "D", "E", "F", "G", "H", "I", "L", "N", "O", "R", "S", "T", "U", "W", "1", "7"]
	var has_all_chars := true
	for c in m1_chars:
		if not ref_text.contains(c):
			has_all_chars = false
			break
	if not assert_condition(has_all_chars, "Reference card contains all 18 M1 characters"): return

	var card_inspected_fired: Array[String] = []
	card_node.card_inspected.connect(func(t: String): card_inspected_fired.append(t))
	card_node._on_interacted()
	if not assert_condition(card_inspected_fired.size() == 1, "card interaction emits card_inspected"): return

	# 2. Test Dispatch Ledger Scene
	var ledger_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/dispatch_ledger.tscn")
	if not assert_condition(ledger_scene != null, "dispatch_ledger.tscn loads"): return
	var ledger_node: DispatchLedger = ledger_scene.instantiate() as DispatchLedger
	if not assert_condition(ledger_node != null and ledger_node is DispatchLedger, "instantiates as DispatchLedger"): return
	root.add_child(ledger_node)

	var ledger_act: Interactable = ledger_node.get_interactable()
	if not assert_condition(ledger_act != null, "ledger has Interactable component"): return
	if not assert_condition(ledger_act.prompt_text == "Inspect Dispatch Ledger", "ledger prompt text matches"): return

	var ledger_text := ledger_node.get_ledger_text()
	if not assert_condition(ledger_text.contains("TRAIN 17") and ledger_text.contains("CLEAR EAST"), "Ledger contains Train 17 rule"): return
	if not assert_condition(ledger_text.contains("Rule 44") and ledger_text.contains("HOLD"), "Ledger contains Rule 44 rule"): return

	var ledger_inspected_fired: Array[String] = []
	ledger_node.ledger_inspected.connect(func(t: String): ledger_inspected_fired.append(t))
	ledger_node._on_interacted()
	if not assert_condition(ledger_inspected_fired.size() == 1, "ledger interaction emits ledger_inspected"): return

	# Clean up
	card_node.queue_free()
	ledger_node.queue_free()

	print("--- All Investigative Anchors Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
