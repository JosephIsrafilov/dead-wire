extends SceneTree
## Elias's morning paper reads ONLY what Elias knows: the handover is built
## from KnowledgeState, never from the objective world, and the margin note
## appears only when his own record says he watched the window. Filing the
## word he heard seals its own knowledge fact.
##   godot --headless --audio-driver Dummy --path . --script tests/office/dawn_evidence_source_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Dawn Evidence Source Test Suite ---")
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()

	# --- 1. The source itself never reaches for the world ---
	var source := FileAccess.get_file_as_string("res://scripts/office/dawn_evidence.gd")
	if not _a(source.length() > 0, "The dawn evidence source is readable"): return
	if not _a(not source.contains("WorldState") and not source.contains("world_state") \
			and not source.contains("get_fact"),
		"The handover source never mentions the objective world"): return

	var dawn := load("res://scenes/office/dawn_evidence.tscn").instantiate() as DawnEvidence
	if not _a(dawn != null, "The handover sheet instantiates"): return
	root.add_child(dawn)

	# --- 2. A world-only record changes nothing on Elias's paper ---
	world.set_fact(&"core_hook_filed_watcher", true)
	world.set_fact(&"core_hook_filed_word", "WATCHER")
	dawn.reveal()
	if not _a(dawn.get_variant_id() == DawnEvidence.VARIANT_LAPSED,
		"A filing recorded only in the world never reaches the handover"): return
	if not _a(dawn.get_document_text().contains("No copy filed"),
		"The world-only night hands over an open line"): return

	# --- 3. Knowledge selects the filed copy ---
	dawn.reset_for_new_watch()
	knowledge.learn(&"committed_watcher_core_hook")
	dawn.reveal()
	if not _a(dawn.get_variant_id() == DawnEvidence.VARIANT_WATCHER,
		"Filing as written is known and shows on the handover"): return
	if not _a(dawn.get_document_text().contains("WATCHER"),
		"The written copy names itself on the paper"): return

	dawn.reset_for_new_watch()
	knowledge.learn(&"amendment_entered_core_hook")
	knowledge.remember_value(&"filed_word_core_hook", "WAITER")
	dawn.reveal()
	if not _a(dawn.get_variant_id() == DawnEvidence.VARIANT_AMENDED,
		"An entered correction is known and shows as amended"): return
	if not _a(dawn.get_document_text().contains("WAITER"),
		"The handover preserves the actual entered word from knowledge"): return

	dawn.reset_for_new_watch()
	knowledge.learn(&"committed_water_core_hook")
	knowledge.remember_value(&"filed_word_core_hook", "WATER")
	dawn.reveal()
	if not _a(dawn.get_variant_id() == DawnEvidence.VARIANT_WATER,
		"Sealing the heard copy outranks the plain amendment record"): return

	dawn.reset_for_new_watch()
	knowledge.reset_for_new_game()
	knowledge.learn(&"core_hook_commit_lapsed")
	dawn.reveal()
	if not _a(dawn.get_variant_id() == DawnEvidence.VARIANT_LAPSED,
		"A lapsed night is known and hands over an open line"): return
	# Plan 9.5: the handover carries the sign-on from the ledger, or says
	# plainly that there was none — no verdict either way.
	if not _a(dawn.get_document_text().contains("NOT SIGNED ON IN THE LEDGER"),
		"A watch never signed on hands over saying so"): return
	dawn.reset_for_new_watch()
	knowledge.learn(&"signed_on")
	knowledge.remember_value(&"signed_on_at", "11:45 P.M.")
	dawn.reveal()
	if not _a(dawn.get_document_text().contains("SIGNED ON 11:45 P.M.") \
			and not dawn.get_document_text().contains("NOT SIGNED ON"),
		"The handover carries the hour Elias signed on"): return

	# --- 4. The margin note lives in knowledge too ---
	if not _a(not dawn.get_document_text().contains("NOTE IN THE MARGIN"),
		"No margin note without the window record"): return
	dawn.reset_for_new_watch()
	knowledge.learn(&"saw_window_event")
	dawn.reveal()
	if not _a(dawn.get_document_text().contains("NOTE IN THE MARGIN"),
		"Watching the window leaves a note in the margin"): return
	if not _a(not dawn.get_document_text().contains("figure"),
		"The margin note records the looking, never a confirmation"): return
	# Plan 4.7: the note matches what could have been seen. Watching the yard in
	# the last silence is its own line, before the call, and still no verdict.
	if not _a(not dawn.get_document_text().contains(DawnEvidence.YARD_MARGIN_LINE),
		"Without the silence record there is no line about the yard"): return
	dawn.reset_for_new_watch()
	knowledge.learn(SilenceThree.KNOWLEDGE_SAW_YARD)
	dawn.reveal()
	if not _a(dawn.get_document_text().contains(DawnEvidence.YARD_MARGIN_LINE),
		"Watching the yard before the last call leaves its own line"): return
	if not _a(not dawn.get_document_text().contains("figure") and not dawn.get_document_text().contains("someone"),
		"That line too records the looking, never what was there"): return
	dawn.queue_free()

	# --- 5. Sealing the heard word is knowledge, and only that word seals ---
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var session := TelegraphSessionController.new()
	root.add_child(session)
	var scenario := load("res://data/scenarios/m1_scenario_3_core_hook.tres") as TelegraphScenarioData
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.submit_amendment("WATER"), "The heard word is accepted as a correction"): return
	if not _a(knowledge.knows(&"committed_water_core_hook"),
		"Sealing the heard copy writes its own knowledge fact"): return
	if not _a(knowledge.knows(&"amendment_entered_core_hook"),
		"The amendment itself stays on the record too"): return

	knowledge.reset_for_new_game()
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.submit_amendment("WAITER"), "Another word is accepted as a correction"): return
	if not _a(not knowledge.knows(&"committed_water_core_hook"),
		"A word Elias did not hear never claims the heard-copy seal"): return
	session.queue_free()

	await process_frame
	print("--- All Dawn Evidence Source Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
