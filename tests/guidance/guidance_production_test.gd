extends SceneTree
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: quit(1)
	return ok
func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var guidance := office.get_node("NightGuidance") as NightGuidanceController
	if not check(guidance != null and guidance._label != null, "Production scene contains thought overlay"): return
	guidance.set_process(false)
	guidance._refresh_visible_context()
	guidance.repeat_current()
	if not check(guidance.current_text.is_empty(), "Intro suppresses manual and automatic thoughts"): return
	office.get_node("IntroCard").skip_immediately()
	guidance._refresh_visible_context()
	guidance.repeat_current()
	if not check(guidance.current_text.contains("Lamp first"), "Entry exposes only the visible work procedure"): return
	office.document_viewer.open_document("test", "TEST", "A document", "Put down")
	if not check(guidance.current_text.is_empty(), "Document opened signal clears existing thought immediately"): return
	office.document_viewer.close_document()
	guidance._refresh_visible_context()
	guidance.repeat_current()
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var session := office.session_controller
	var schedule := compiler.compile(encoder.encode("AL", session.alphabet), session.playback_profile)
	session.scheduler.start(schedule)
	if not check(guidance.current_text.is_empty(), "Scheduler start clears thoughts before a protected mark"): return
	session.scheduler.cancel()
	var settings := GameSettings.new()
	settings.contextual_thoughts_enabled = false
	settings.apply(office.player)
	if not check(not guidance.enabled, "Applying options updates live guidance without scene reload"): return
	if not check(not guidance._label.mouse_filter == Control.MOUSE_FILTER_STOP, "Thought overlay cannot steal input"): return
	office.queue_free()
	await process_frame
	await process_frame
	quit(0)
