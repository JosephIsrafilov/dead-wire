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
	if not assert_condition(office.load_scenario_by_index(2), "Production office loads the core-hook scenario"): return
	var key := office.session_controller.telegraph_key
	key.get_interactable().interact()
	office.session_controller.scheduler.auto_process = false
	office.session_controller.scheduler.advance_time(30.0)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Core-hook production session reaches verification"): return
	var paper := office.get_node_or_null("TranscriptPaper") as TranscriptPaper
	if not assert_condition(paper != null and paper.get_interactable() != null, "Production transcript is available for verification"): return
	paper.get_interactable().interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Production transcript inspection opens the commit gate"): return
	if not assert_condition(office.session_controller.submit_commit(&"file_water"), "Production core-hook commit resolves"): return
	# Production consequence waits for the observer's visible hold. This test is
	# interested in the completed duty-sheet fact, so acknowledge the figure
	# explicitly instead of relying on the bounded unattended fallback.
	office.session_controller.advance_consequence(1.0)
	office.session_controller.notify_consequence_visible()
	office.session_controller.advance_consequence(1.1)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COMPLETE, "Production consequence completes the shift segment"): return
	var production_sheet := office.get_node_or_null("DutySheet") as DutySheet
	if not assert_condition(production_sheet != null, "Production office exposes its duty sheet"): return
	if not assert_condition(production_sheet.get_core_hook_outcome_status() == DutySheet.STATUS_CORE_HOOK_WATER, "Completed production commit resolves the sheet status"): return
	if not assert_condition(production_sheet.get_sheet_text().contains(DutySheet.STATUS_CORE_HOOK_WATER), "Completed production commit is visible on the rendered duty sheet"): return
	office.queue_free()
	await process_frame

	print("--- All Duty Sheet Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	_assertions_passed += 1
	print("  PASS: %s" % description)
	return true
