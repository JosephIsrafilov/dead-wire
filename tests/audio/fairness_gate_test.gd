extends SceneTree
## Plan 7.7, GDD §7: critical Morse is always readable. While a critical copy
## is on the wire, everything that is not the telegraph is ducked — the clock,
## the room, the feed, the pen, the chair, the steps of the operator — and no
## such player stays audible. The designed attention event (steps beyond the
## door) rides its own Events bus and is not ducked. A plain copy ducks nothing.
##   godot --headless --audio-driver Dummy --path . --script tests/audio/fairness_gate_test.gd

const AUDIBLE_DB := -20.0
var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Fairness Gate Test Suite ---")
	MainMenu.clear_state()
	var foley_bus := AudioServer.get_bus_index(&"Foley")
	var effects_before := AudioServer.get_bus_effect_count(foley_bus)
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var session := office.session_controller
	session.set_process(false)
	session.scheduler.auto_process = false
	session.allow_key_start = true
	var gate := office.get_node_or_null("FairnessGate") as FairnessGate
	if not _a(gate != null, "The office carries the fairness gate"): return
	gate.set_process(false)
	if not _a(is_zero_approx(gate.get_duck_db()), "Between telegrams nothing is ducked"): return

	# A plain copy (scenario 1) ducks nothing.
	office.load_scenario_by_index(0)
	session.start_transmission()
	gate.advance(1.0)
	if not _a(not gate.is_critical_live() and is_zero_approx(gate.get_duck_db()), "A plain copy ducks nothing"): return
	session.scheduler.cancel()

	# A critical copy (scenario 3) on the wire: nothing else stays audible.
	office.load_scenario_by_index(2)
	if not _a(session.start_transmission() and gate.is_critical_live(), "A critical copy is on the wire"): return
	gate.advance(1.0)
	var audible: Array[String] = []
	for node in office.find_children("*", "", true, false):
		if not (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
			continue
		var bus: StringName = node.get("bus")
		if bus not in FairnessGate.DUCKED_BUSES:
			continue
		if float(node.get("volume_db")) + gate.get_duck_db() > AUDIBLE_DB:
			audible.append("%s on %s" % [node.name, bus])
	if not _a(audible.is_empty(), "No non-telegraph player is audible under critical copy %s" % str(audible)): return
	if not _a(not (&"Telegraph" in FairnessGate.DUCKED_BUSES) and not (&"Events" in FairnessGate.DUCKED_BUSES),
		"The telegraph and the attention event are never ducked"): return
	var steps := office.door_attention.get_node_or_null("FootstepPlayer") as AudioStreamPlayer3D
	if not _a(steps != null and steps.bus == &"Events", "The steps beyond the door ride the Events bus"): return

	# The wire falls silent: the room comes back, not at once.
	session.scheduler.cancel()
	gate.advance(0.1)
	var releasing := gate.get_duck_db()
	gate.advance(2.0)
	if not _a(releasing < -1.0 and is_zero_approx(gate.get_duck_db()), "The room returns over the release, not with a jump"): return

	office.queue_free()
	for _frame in 5:
		await process_frame
	if not _a(AudioServer.get_bus_effect_count(foley_bus) == effects_before, "Leaving the office takes the gate off the buses"): return
	print("--- All Fairness Gate Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
