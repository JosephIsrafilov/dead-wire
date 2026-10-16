extends SceneTree
## The slowing register teaches itself: in the quiet between calls Elias
## thinks about winding it, ahead of the compare hint, whenever the side key
## is actually due.
##   godot --headless --audio-driver Dummy --path . --script tests/guidance/wind_guidance_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Wind Guidance Test Suite ---")
	var office := await _fresh_office()
	if office == null:
		quit(1)
		return
	var guidance := office.get_node("NightGuidance") as NightGuidanceController
	var session := office.session_controller
	var director := office.shift_director
	var register := session.get_tape_register()

	# Slot 0, line quiet: a run-down spring owns the thought.
	register.spring_tension = 0.5
	guidance._refresh_visible_context()
	if not _a(guidance._context == &"wind",
		"A run-down register takes the thought context between calls"): return
	guidance.advance_guidance(2.0)
	if not _a(guidance.current_text.contains("wind"),
		"The wind thought is spoken from guidance data, got '%s'" % guidance.current_text): return

	# The same moment on a healthy spring: no wind thought, no wind interactable.
	register.wind()
	guidance._refresh_visible_context()
	if not _a(guidance._context != &"wind" and not register.needs_winding(),
		"A healthy register leaves the wind context and the prompt alone"): return

	# Miss the first call to reach slot 1's compare window; the slowing
	# register outranks the compare hint.
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var call_sequence := encoder.encode(director.call_sign, director.alphabet)
	var call_schedule := compiler.compile(call_sequence, director.playback_profile)
	var total_window := call_schedule.total_duration_seconds * director.max_calls_per_message \
		+ director.call_repeat_gap_seconds * maxf(0.0, director.max_calls_per_message - 1) \
		+ director.answer_grace_seconds
	director.advance(director.wait_seconds_before_call[0] + total_window + 5.0)
	if not _a(director.get_phase() == ShiftDirector.Phase.WAITING and director.get_slot_index() == 1,
		"Fixture: the missed call moves the watch to slot 1's quiet"): return
	register.spring_tension = 0.5
	guidance._refresh_visible_context()
	if not _a(guidance._context == &"wind",
		"The wind hint outranks the compare hint while the register needs winding"): return
	register.wind()
	guidance._refresh_visible_context()
	if not _a(guidance._context == &"compare",
		"A wound register hands the thought back to comparing the strip"): return

	office.queue_free()
	await process_frame
	await process_frame
	print("--- All Wind Guidance Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _fresh_office() -> M1OfficeController:
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	var office := scene.instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"):
		return null
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	var guidance := office.get_node("NightGuidance") as NightGuidanceController
	guidance.set_process(false)
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	if not _a(office.operator_seat.sit(), "The operator takes the chair"):
		return null
	office.session_controller.telegraph_key.press()
	if not _a(office.shift_director.get_phase() == ShiftDirector.Phase.WAITING,
		"The line opens and the watch waits on the first call"):
		return null
	return office

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
