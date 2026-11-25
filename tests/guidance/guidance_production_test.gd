extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameLocale.lock_language_for_test("en")
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var guide := office.get_node("NightGuidance") as NightGuidanceController
	_check(guide != null and guide._label != null, "Production scene contains thought overlay")
	guide.set_process(false)
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.is_empty(), "Intro suppresses automatic and manual guidance")
	office.get_node("IntroCard").skip_immediately()
	office.get_node("ShiftArrival").skip_immediately()
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.contains("from the basics"), "Standing intro gives Elias's first thought")

	var station := office.get_node("SeatedStationController") as SeatedStationController
	station.activate_station()
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(office.player.seated_station_mode and guide.current_text.contains("brass key"),
		"The seated pre-shift state tells the player how to open the line")
	office.document_viewer.open_document("test", "TEST", "A document", "Put down")
	_check(guide.current_text.is_empty(), "Opening a document clears the thought immediately")
	office.document_viewer.close_document()
	var director := office.shift_director
	director.set_process(false)
	var session := office.session_controller
	director._phase = ShiftDirector.Phase.AWAITING_ROUTE
	director._slot_index = 0
	session._state = TelegraphSessionController.State.VERIFYING
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.contains("Lift the sheet"), "The first finished copy gives the seated reading step")
	var schedule := MorseScheduleCompiler.new().compile(
		AmericanMorseEncoder.new().encode("AL", session.alphabet), session.playback_profile)
	session.scheduler.start(schedule)
	_check(guide.current_text.is_empty(), "Scheduler start clears the thought before a mark")
	session.scheduler.cancel()
	for state in [TelegraphSessionController.State.RECEIVING, TelegraphSessionController.State.COPYING]:
		session._state = state
		guide._refresh_visible_context()
		guide.repeat_current()
		_check(guide.current_text.is_empty(), "Receiving and copying suppress F1 and the overlay")

	director._slot_index = 1
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.is_empty(), "Second-slot routing has no procedural thought")
	director._slot_index = 2
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.contains("paper tape") and not guide.current_text.contains("WATCHER"),
		"Third-slot post-read guidance points at the objective tape")
	office.document_viewer.open_document(TapeRegisterController.TAPE_DOC_ID, "Tape", "Test")
	office.document_viewer.close_document()
	guide._refresh_visible_context()
	guide.repeat_current()
	_check(guide.current_text.is_empty(), "Reading the third-slot tape dismisses the reminder")

	var settings := GameSettings.new()
	settings.contextual_thoughts_enabled = false
	settings.apply(office.player)
	_check(not guide.enabled, "Applying options disables automatic thoughts live")
	_check(guide._label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Thought overlay cannot steal input")
	GameLocale.clear_test_override()
	office.queue_free()
	await process_frame
	await process_frame
	quit(int(_failed))

func _check(ok: bool, description: String) -> void:
	_failed = _failed or not ok
	print("  %s: %s" % ["PASS" if ok else "FAIL", description])
