extends SceneTree

## Plan 9.6: the end of the watch is an entry in the ledger, not a screen over
## the room. At dawn the pen is offered again; Elias writes the hour, the last
## thing he heard on the wire and which watch this was, and stamps it OFF DUTY.
## Everything on the page is his knowledge. Walking out shows no record.

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
	(root.get_node("KnowledgeState") as KnowledgeStateStore).reset_for_new_game()
	(root.get_node("WorldState") as WorldStateStore).reset_for_new_game()
	var office := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.add_child(office)
	return office

func _run() -> void:
	print("--- Ledger: end of watch ---")
	var office := _office()
	await process_frame
	await process_frame
	var ledger := office.get_node("DispatchLedger") as DispatchLedger
	if not check(ledger.has_method("close_watch") and ledger.has_signal("stamped"), "The ledger can close a watch"): return
	ledger.call("reset_watch_count")
	var pen := ledger.get_node("SignInteractable") as Interactable
	if not check(pen.get_prompt() == "Sign On", "Before dawn the pen signs on, it does not close"): return
	pen.interact()
	ledger.advance_signature(10.0)
	if not check(pen.collision_layer == 0, "Signed on, the pen is put down until the morning"): return

	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	knowledge.remember_value(&"last_wire_heard", "SAID WATER GN")
	office.shift_director.set("_station_display_hours", 30.0)
	(office.get_node("DawnRitual") as DawnRitual).begin()
	if not check(pen.enabled and pen.collision_layer != 0 and pen.get_prompt() == "Close the Watch",
		"At dawn the pen is offered to close the watch"): return

	var stamps: Array[int] = []
	ledger.connect("stamped", func() -> void: stamps.append(1))
	pen.interact()
	var closing := ledger.get_node_or_null("RightPage/Closing") as Label3D
	var stamp := ledger.get_node_or_null("RightPage/OffDutyStamp") as Label3D
	if not check(closing != null and stamp != null and not stamp.visible, "The stamp waits for the pen"): return
	for i in 200:
		ledger.advance_signature(0.05)
	var written := closing.text
	if not check(written.begins_with("END OF WATCH\n6:00 A.M."), "The hour the watch ended, by the station clock: '%s'" % written): return
	if not check(written.contains("SAID WATER GN"), "The last thing Elias heard on the wire"): return
	if not check(written.contains("WATCH 1"), "Which watch this was"): return
	if not check(stamp.visible and stamps.size() == 1, "Stamped OFF DUTY once, after the writing"): return
	if not check(knowledge.knows(&"watch_closed"), "Elias knows he closed the watch"): return
	if not check(not pen.enabled and pen.collision_layer == 0, "A closed watch offers the pen no more"): return
	if not check(ledger.get_ledger_text().contains("END OF WATCH"), "The opened ledger carries the closing entry"): return

	# Stand another watch: the count goes on; a new game starts it again.
	root.remove_child(office)
	office.queue_free()
	var second := _office()
	await process_frame
	await process_frame
	var second_ledger := second.get_node("DispatchLedger") as DispatchLedger
	(second.get_node("DawnRitual") as DawnRitual).begin()
	var second_pen := second_ledger.get_node("SignInteractable") as Interactable
	if not check(second_pen.get_prompt() == "Close the Watch", "A watch never signed on can still be closed"): return
	second_pen.interact()
	for i in 200:
		second_ledger.advance_signature(0.05)
	var second_text := (second_ledger.get_node("RightPage/Closing") as Label3D).text
	if not check(second_text.contains("WATCH 2"), "The second watch stood is watch 2: '%s'" % second_text): return
	if not check(not second_text.contains("LAST ON THE WIRE"), "Nothing heard on the wire, nothing claimed"): return
	second_ledger.call("reset_watch_count")
	root.remove_child(second)
	second.queue_free()
	await process_frame
	var third := _office()
	await process_frame
	await process_frame
	var third_ledger := third.get_node("DispatchLedger") as DispatchLedger
	(third.get_node("DawnRitual") as DawnRitual).begin()
	(third_ledger.get_node("SignInteractable") as Interactable).interact()
	for i in 200:
		third_ledger.advance_signature(0.05)
	if not check((third_ledger.get_node("RightPage/Closing") as Label3D).text.contains("WATCH 1"),
		"A new game counts from the first watch again"): return

	print("--- %d assertions passed ---" % _passed)
	quit(0)
