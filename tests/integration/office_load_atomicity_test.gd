extends SceneTree
## A rejected office load is a no-op, including all presentation state.
var passed := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: quit(1); return false
	passed += 1
	return true
func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var session := office.session_controller
	session.set_process(false)
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	var desk := office.copy_commit_desk
	var observation := office.window_observation
	var attempts: Array = []
	var captured: Array = []
	session.commit_recorded.connect(func(_id, _action, _word):
		var enabled_before := desk.is_enabled()
		var options_before := desk.get_options()
		var index_before := office.get_current_scenario_index()
		var window_before := observation.is_active
		attempts.append(office.load_scenario_by_index(0))
		captured.append(office.get_current_scenario_index() == index_before \
			and desk.is_enabled() == enabled_before and desk.get_options() == options_before \
			and observation.is_active == window_before))
	if not check(session.submit_amendment("WAITER"), "Explicit amendment is accepted"): return
	if not check(attempts == [false], "Office refuses reentrant load during resolution"): return
	if not check(captured == [true], "Refused load changes no office attribution, desk or window state"): return
	if not check(office.get_current_scenario_index() == 2 and desk.get_selected_action_id() == &"amend_copy", "Old-slot feedback is applied only to its original desk"): return
	if not check(session.get_current_scenario() == office.scenario_3, "Office and session keep the same scenario after rejection"): return
	var invalid := office.scenario_1.duplicate(true) as TelegraphScenarioData
	invalid.transmission_data = null
	office._scenario_list[0] = invalid
	var slot_before := office.get_current_scenario_index()
	var selected_before := desk.get_selected_action_id()
	if not check(not office.load_scenario_by_index(0), "Invalid scenario data is refused before presentation changes"): return
	if not check(office.get_current_scenario_index() == slot_before and desk.get_selected_action_id() == selected_before, "Rejected invalid data also preserves attribution and accepted desk result"): return
	session.reset_session()
	session.load_scenario(office.scenario_3)
	session._state = TelegraphSessionController.State.VERIFYING
	session._post_signal_elapsed = 0.0
	var reset_attempts: Array = []
	session.commit_resolved.connect(func(_id, _text): reset_attempts.append(office.load_scenario_by_index(1)))
	if not check(session.lapse_commit(), "Original deadline can resolve an unfiled copy"): return
	if not check(reset_attempts == [false] and office.get_current_scenario_index() == 2, "Lapse acknowledgement also rejects reentrant office scenario replacement"): return
	office.queue_free()
	await process_frame
	print("Office load atomicity assertions: ", passed)
	quit(0)
