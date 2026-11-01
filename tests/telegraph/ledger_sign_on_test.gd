extends SceneTree

## Plan 9.3: the operator signs on in the dispatch ledger at the head of the
## watch. It is optional and blocks nothing; the pen writes the name and the
## station time in Elias's own hand, one glyph at a time, and Elias knows he
## signed. Reading the ledger stays where it was.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> bool:
	if condition:
		_passed += 1
		print("  PASS: " + description)
		return true
	print("  FAIL: " + description)
	quit(1)
	return false

func _office() -> M1OfficeController:
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge != null:
		knowledge.reset_for_new_game()
	var office := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.add_child(office)
	return office

func _run() -> void:
	print("--- Ledger sign-on ---")
	var office := _office()
	await process_frame
	await process_frame
	var ledger := office.get_node_or_null("DispatchLedger") as DispatchLedger
	if not check(ledger != null, "The office has its dispatch ledger"): return
	var sign_area := ledger.get_node_or_null("SignInteractable") as Interactable
	if not check(sign_area != null and sign_area.enabled and sign_area.get_prompt() == "Sign On",
		"An unsigned ledger offers the pen"): return
	if not check(ledger.get_interactable().get_prompt() == "Inspect Dispatch Ledger", "Reading the ledger stays its own action"): return
	if not check(not bool(ledger.call("is_signed")), "A new watch starts unsigned"): return
	if not check(not office.shift_director.is_shift_over() and office.shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT,
		"Signing is not asked of the director: the watch is still waiting for the key"): return

	var strokes: Array[int] = []
	ledger.connect("signature_stroke", func(index: int) -> void: strokes.append(index))
	sign_area.interact()
	if not check(bool(ledger.call("is_signed")), "The pen signs on"): return
	var label := ledger.get_node_or_null("RightPage/Signature") as Label3D
	if not check(label != null and label.text.length() < "E. CRANE  11:00 P.M.".length(), "The name is written, not stamped: it is not all there at once"): return
	for i in 60:
		ledger.call("advance_signature", 0.05)
	if not check(label.text == "E. CRANE  11:00 P.M.", "Name and station time in Elias's hand, got '%s'" % label.text): return
	if not check(strokes.size() == "E.CRANE11:00P.M.".length(), "The nib touches the page once per glyph, got %d" % strokes.size()): return
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	if not check(knowledge.knows(&"signed_on") and knowledge.recall_value(&"signed_on_at") == "11:00 P.M.",
		"Elias knows he signed on, and when"): return
	if not check(not sign_area.enabled, "A signed ledger offers no second signature"): return
	if not check(sign_area.collision_layer == 0, "Once signed, the pen's zone no longer shadows the book from the ray"): return
	sign_area.interact()
	for i in 20:
		ledger.call("advance_signature", 0.05)
	if not check(strokes.size() == "E.CRANE11:00P.M.".length(), "Pressing again writes nothing more"): return

	ledger.get_interactable().interact()
	if not check(office.document_viewer.is_open() and office.document_viewer.get_current_doc_id() == "dispatch_ledger",
		"E on the book still opens the ledger"): return
	if not check(ledger.get_ledger_text().contains("ON DUTY") and ledger.get_ledger_text().contains("E. CRANE  11:00 P.M."),
		"The opened ledger carries the signature"): return

	# Signed late, the ledger says so: the time is the station clock's.
	root.remove_child(office)
	office.queue_free()
	var late := _office()
	await process_frame
	await process_frame
	var late_ledger := late.get_node("DispatchLedger") as DispatchLedger
	if not check(not late_ledger.get_ledger_text().contains("ON DUTY"), "An unsigned ledger shows no signature"): return
	late.shift_director.set("_station_display_hours", 23.75)
	(late_ledger.get_node("SignInteractable") as Interactable).interact()
	for i in 60:
		late_ledger.call("advance_signature", 0.05)
	if not check((late_ledger.get_node("RightPage/Signature") as Label3D).text == "E. CRANE  11:45 P.M.",
		"Signed late, the ledger shows the late hour"): return

	print("--- %d assertions passed ---" % _passed)
	quit(0)
