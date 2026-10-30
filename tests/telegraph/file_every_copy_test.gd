extends SceneTree

## Plan 4.4: every copy is filed by the same ritual. After the route lever the
## routed copies 1-2 go to the filing desk with the same two choices the third
## copy has; the interface never singles the third out. An amendment on 1-2
## answers only on the wire, never in the window.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting File Every Copy Test Suite ---")
	var s1 := load("res://data/scenarios/m1_scenario_1_baseline.tres") as TelegraphScenarioData
	var s2 := load("res://data/scenarios/m1_scenario_2_attention.tres") as TelegraphScenarioData
	var s3 := load("res://data/scenarios/m1_scenario_3_core_hook.tres") as TelegraphScenarioData

	# --- 1. Same choices on every copy ---------------------------------------
	var hook_labels := _labels(s3)
	for scenario in [s1, s2]:
		if not _a(scenario.get_validation_errors().is_empty(), "%s stays valid with filing" % scenario.scenario_id): return
		if not _a(_labels(scenario) == hook_labels, "%s offers the same filing choices as the third copy %s" % [scenario.scenario_id, str(hook_labels)]): return
		if not _a(scenario.consequence_event_id.is_empty() and scenario.consequence_events_by_outcome.is_empty(),
			"%s has no window consequence" % scenario.scenario_id): return
		if not _a(not str(scenario.wire_reply_by_outcome.get("amended_other", "")).is_empty()
			and str(scenario.wire_reply_by_outcome.get("filed_as_copied", "")).is_empty(),
			"%s answers an amendment on the wire and a plain filing with silence" % scenario.scenario_id): return

	# --- 2. Route, then file -------------------------------------------------
	var session := _session(s1)
	var requested: Array = []
	var completed: Array = []
	session.commit_requested.connect(func(_o): requested.append(1))
	session.session_completed.connect(func(_s): completed.append(1))
	session._post_signal_elapsed = 25.0
	if not _a(session.submit_routing_decision("CLEAR EAST"), "The route goes out"): return
	if not _a(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT and requested.size() == 1,
		"After the route the copy waits to be filed"): return
	if not _a(completed.is_empty(), "The slot is not over until the copy is filed"): return
	if not _a(session.get_post_signal_elapsed() < 0.01, "The filing gets its own clock, not the route's leftovers"): return
	var file_id := _plain_option(s1)
	if not _a(session.submit_commit(file_id), "Filing as copied is accepted"): return
	# The stamp stays on the desk for a breath before the night moves on, and
	# the whole ritual stays short (plan 4.4: no more than about five seconds).
	if not _a(completed.is_empty() and session.get_state() == TelegraphSessionController.State.CONSEQUENCE,
		"The filed copy stays on the desk for a moment"): return
	if not _a(s1.consequence_delay_seconds + s1.consequence_hold_seconds <= 5.0, "Filing a routed copy takes no more than five seconds"): return
	session.advance_consequence(s1.consequence_hold_seconds)
	if not _a(completed.size() == 1 and session.get_state() == TelegraphSessionController.State.COMPLETE,
		"A routed copy completes the slot once filed, with no window to wait for"): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_FILED_AS_COPIED, "The outcome is filed as copied"): return
	session.queue_free()

	# --- 3. An amendment on a routed copy ------------------------------------
	var amend_session := _session(s2)
	amend_session.submit_routing_decision(s2.expected_routing_action)
	if not _a(amend_session.submit_amendment("FREIGHT"), "A routed copy can be amended too"): return
	amend_session.advance_consequence(s2.consequence_hold_seconds)
	if not _a(amend_session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_OTHER
		and amend_session.get_state() == TelegraphSessionController.State.COMPLETE,
		"The amendment resolves the slot as amended"): return
	amend_session.queue_free()

	# --- 4. A route lapse files nothing ----------------------------------------
	var lapse_session := _session(s1)
	var lapse_requested: Array = []
	lapse_session.commit_requested.connect(func(_o): lapse_requested.append(1))
	lapse_session.lapse_routing()
	if not _a(lapse_requested.is_empty() and lapse_session.get_state() == TelegraphSessionController.State.COMPLETE,
		"No order sent means no copy to file: the slot ends"): return
	lapse_session.queue_free()

	# --- 5. Walking away from the desk lapses the filing ----------------------
	var walk_session := _session(s2)
	walk_session.submit_routing_decision(s2.expected_routing_action)
	walk_session.advance_post_signal(walk_session.get_commit_deadline_seconds() + 0.1)
	walk_session.advance_consequence(s2.consequence_hold_seconds)
	if not _a(walk_session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_LAPSED
		and walk_session.get_state() == TelegraphSessionController.State.COMPLETE,
		"An unfiled routed copy lapses and the night goes on"): return
	walk_session.queue_free()

	# --- 6. Before the order goes out, the filing clock does not run --------
	var early_session := _session(s1)
	early_session.advance_post_signal(early_session.get_commit_deadline_seconds() + 5.0)
	if not _a(early_session.get_state() == TelegraphSessionController.State.AWAITING_ROUTE
		and early_session.get_resolved_outcome() == &"",
		"The filing deadline never lapses a copy whose route is still awaited"): return
	if not _a(early_session.lapse_routing() and not early_session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_LAPSED,
		"Only the route deadline can end an unrouted slot"): return
	early_session.queue_free()

	await process_frame
	print("--- All File Every Copy Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _session(scenario: TelegraphScenarioData) -> TelegraphSessionController:
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world != null:
		world.reset_for_new_game()
	var session := TelegraphSessionController.new()
	root.add_child(session)
	session.set_process(false)
	session.load_scenario(scenario)
	# The office always asks for a visible consequence; an empty one must not wait.
	session.set_consequence_visibility_required(true)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	session._post_signal_elapsed = 0.0
	return session

func _labels(scenario: TelegraphScenarioData) -> Array:
	var labels: Array = []
	for option in scenario.commit_options:
		labels.append(option.display_label)
	labels.sort()
	return labels

func _plain_option(scenario: TelegraphScenarioData) -> StringName:
	for option in scenario.commit_options:
		if not option.requires_correction:
			return option.action_id
	return StringName()

func _a(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
