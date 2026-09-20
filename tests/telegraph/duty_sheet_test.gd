extends SceneTree

## Verifies that the duty sheet exposes the core-hook consequence from
## KnowledgeState without reading or leaking WorldState.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Duty Sheet Test Suite ---")
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if not assert_condition(knowledge != null, "KnowledgeState autoload is available"): return
	if not assert_condition(world != null, "WorldState autoload is available"): return

	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	var sheet := DutySheet.new()
	root.add_child(sheet)

	# A world consequence alone must not appear on Elias's paperwork.
	world.set_fact(&"core_hook_filed_water", true)
	if not assert_condition(sheet.get_core_hook_outcome_status().is_empty(), "WorldState alone does not create a core-hook sheet status"): return
	if not assert_condition(not sheet.get_sheet_text().contains(DutySheet.CORE_HOOK_OUTCOME_LABEL), "WorldState alone does not add a core-hook record line"): return

	# Each knowledge fact resolves to its own status and reaches the rendered
	# sheet. Reset between cases to keep the lookup mutually exclusive.
	knowledge.learn(&"committed_water_core_hook")
	if not assert_condition(sheet.get_core_hook_outcome_status() == DutySheet.STATUS_CORE_HOOK_WATER, "Water commit maps to the heard-copy status"): return
	if not assert_condition(sheet.get_sheet_text().contains(DutySheet.STATUS_CORE_HOOK_WATER), "Water commit is visible on the duty sheet"): return
	if not assert_condition(not sheet.get_sheet_text().contains("WATER") and not sheet.get_sheet_text().contains("WATCHER"), "Core-hook status does not leak message content"): return

	knowledge.reset_for_new_game()
	knowledge.learn(&"committed_watcher_core_hook")
	if not assert_condition(sheet.get_core_hook_outcome_status() == DutySheet.STATUS_CORE_HOOK_WATCHER, "Watcher commit maps to the written-copy status"): return
	if not assert_condition(sheet.get_sheet_text().contains(DutySheet.STATUS_CORE_HOOK_WATCHER), "Watcher commit is visible on the duty sheet"): return

	knowledge.reset_for_new_game()
	knowledge.learn(&"core_hook_commit_lapsed")
	if not assert_condition(sheet.get_core_hook_outcome_status() == DutySheet.STATUS_CORE_HOOK_LAPSED, "Lapsed commit maps to the unfiled status"): return
	if not assert_condition(sheet.get_sheet_text().contains(DutySheet.STATUS_CORE_HOOK_LAPSED), "Lapsed outcome is visible on the duty sheet"): return

	# An unfinished copy is its own state, distinct from copied, filed and
	# nothing-at-all. It is reported after a lapse so the terminal outcome a
	# slot ended on is never masked by an earlier fact.
	knowledge.reset_for_new_game()
	knowledge.learn(&"incomplete_copy_baseline_train_17")
	var scen1: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_1_baseline.tres")
	if not assert_condition(sheet.get_status_for(scen1) == DutySheet.STATUS_INCOMPLETE, "incomplete_copy_ fact maps to the COPY INCOMPLETE status"): return
	knowledge.learn(&"lapsed_baseline_train_17")
	if not assert_condition(sheet.get_status_for(scen1) == DutySheet.STATUS_LAPSED, "A lapse outranks an incomplete copy on the sheet"): return
	knowledge.reset_for_new_game()
	knowledge.learn(&"filed_baseline_train_17")
	if not assert_condition(sheet.get_status_for(scen1) == DutySheet.STATUS_FILED, "A filed route outranks an incomplete copy on the sheet"): return

	sheet.queue_free()

	# Repeat the check through the production scene: the same record appears
	# after a real core-hook commit reaches COMPLETE, rather than only after a
	# test manually teaches the fact.
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	var office_scene := ResourceLoader.load("res://scenes/office/m1_office.tscn") as PackedScene
	if not assert_condition(office_scene != null, "Production office scene loads for consequence check"): return
	var office := office_scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Production office instantiates for consequence check"): return
	root.add_child(office)
	await process_frame
	await process_frame
	office.shift_director.enabled = false
	office.session_controller.allow_key_start = true
	# The hand only writes from the chair: sit before answering the line.
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	if not assert_condition(office.load_scenario_by_index(2), "Production office loads the core-hook scenario"): return
	var key := office.session_controller.telegraph_key
	key.get_interactable().interact()
	office.session_controller.scheduler.auto_process = false
	office.session_controller.scheduler.advance_time(30.0)
	var paper := office.get_node_or_null("TranscriptPaper") as TranscriptPaper
	_drain_paper(paper)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Core-hook production session reaches verification"): return
	if not assert_condition(paper != null and paper.get_interactable() != null, "Production transcript is available for verification"): return
	paper.get_interactable().interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Production transcript inspection opens the commit gate"): return
	if not assert_condition(office.session_controller.submit_commit(&"file_water"), "Production core-hook commit resolves"): return
	# Production consequence waits for the observer's visible hold. This test is
	# interested in the completed duty-sheet fact, so acknowledge the figure
	# explicitly instead of relying on the bounded unattended fallback.
	office.session_controller.advance_consequence(1.0)
	office.session_controller.notify_consequence_visible()
	office.session_controller.advance_consequence(6.1)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COMPLETE, "Production consequence completes the shift segment"): return
	var production_sheet := office.get_node_or_null("DutySheet") as DutySheet
	if not assert_condition(production_sheet != null, "Production office exposes its duty sheet"): return
	if not assert_condition(production_sheet.get_core_hook_outcome_status() == DutySheet.STATUS_CORE_HOOK_WATER, "Completed production commit resolves the sheet status"): return
	if not assert_condition(production_sheet.get_sheet_text().contains(DutySheet.STATUS_CORE_HOOK_WATER), "Completed production commit is visible on the rendered duty sheet"): return

	# --- the ledger shares the sheet's vocabulary, and invents nothing -----
	# (H7) One knowledge-backed status computation for both documents; the
	# ledger shows what actually went out and shows unknown as unknown.
	var ledger := office.get_node_or_null("DispatchLedger") as DispatchLedger
	if not assert_condition(ledger != null, "Production office exposes its dispatch ledger"): return
	var entries := ledger._night_entries_text()
	if not assert_condition(entries.contains("NIGHT ENTRIES — APRIL 1894"), "The entries header agrees with the night's date"): return
	if not assert_condition(not ledger.get_ledger_text().contains("23 APRIL"), "No day of month is invented anywhere in the setting"): return
	# The production night above committed WATER: the sealed-copy vocabulary is
	# shared with the duty sheet.
	if not assert_condition(entries.contains("HEARD COPY SEALED"), "The core-hook entry uses the shared sealed-copy vocabulary"): return
	if not assert_condition(not entries.contains("WATER") and not entries.contains("WATCHER"), "The ledger never leaks message content"): return

	# filed without a route fact: the order went out, but the record does not
	# say which way — the ledger must not turn that into HOLD.
	knowledge.reset_for_new_game()
	knowledge.learn(&"filed_baseline_train_17")
	if not assert_condition(not ledger._night_entries_text().contains("HOLD"), "A filed record without a route fact invents no direction"): return
	knowledge.learn(&"route_hold_baseline_train_17")
	if not assert_condition(ledger._night_entries_text().contains("FILED    HOLD"), "The recorded route shows the action that actually went out"): return
	knowledge.reset_for_new_game()
	knowledge.learn(&"incomplete_copy_attention_hold_freight")
	knowledge.learn(&"lapsed_attention_hold_freight")
	if not assert_condition(ledger._night_entries_text().contains("COPY INCOMPLETE / NO ORDER SENT"), "An incomplete lapse reads as exactly what happened"): return
	knowledge.reset_for_new_game()
	knowledge.learn(&"incomplete_copy_core_hook_water_watcher")
	knowledge.learn(&"core_hook_commit_lapsed")
	if not assert_condition(ledger._night_entries_text().contains("COPY INCOMPLETE / UNFILED"), "An incomplete unfiled commit is its own honest outcome"): return
	knowledge.reset_for_new_game()
	knowledge.learn(&"missed_call_baseline_train_17")
	if not assert_condition(ledger._night_entries_text().contains("NO COPY"), "A missed call leaves no copy and no invented content"): return

	office.queue_free()
	await process_frame

	print("--- All Duty Sheet Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	_assertions_passed += 1
	print("  PASS: %s" % description)
	return true
