extends SceneTree
## Plan 6.9: captions for the sounds that are not the wire. Off by default;
## when on, a heard sound is described, never its source, and it fades.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/sound_captions_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Sound Captions Test Suite ---")
	GameLocale.lock_language_for_test("en")
	if not _a(not GameSettings.new().sound_captions, "Sound captions start off"): return
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	var captions := office.get_node_or_null("SoundCaptions") as SoundCaptions
	if not _a(captions != null, "The office carries sound captions"): return
	if not _a(not captions.enabled, "They follow the setting and stay off"): return

	office.door_attention.footsteps_started.emit()
	if not _a(captions.current_text.is_empty(), "Off, a sound leaves no caption"): return

	captions.enabled = true
	office.door_attention.footsteps_started.emit()
	if not _a(captions.current_text == "[steps beyond the door]", "On, the steps are captioned as heard"): return
	(office.get_node("UneaseDirector") as UneaseDirector).creaked.emit(Vector3.ZERO)
	if not _a(captions.current_text == "[timber creaks]", "A creak is captioned as a sound"): return
	office.shift_director.call_started.emit(0, 1)
	if not _a(captions.current_text == "[the sounder calls]", "The office call is captioned"): return
	captions._process(SoundCaptions.CAPTION_SECONDS + 0.1)
	if not _a(captions.current_text.is_empty(), "A caption fades on its own"): return

	# The player can be reading the dispatch rules when a real call repeats.
	var director := office.shift_director
	director.set_process(false)
	var viewer := office.document_viewer
	var ledger := office.get_node("DispatchLedger") as DispatchLedger
	ledger.get_interactable().interact()
	if not _a(viewer.is_open(), "The dispatch ledger is raised during the watch"): return
	if not _a(director.open_line(), "The office opens the wire"): return
	director.advance(director.wait_seconds_before_call[0] + 0.1)
	if not _a(captions.current_text == "[the sounder calls]", "The first live call is captioned over the ledger"): return
	captions._process(SoundCaptions.CAPTION_SECONDS + 0.1)
	director.advance(director._call_window_seconds)
	if not _a(captions.current_text == "[the sounder calls]", "The repeated live call is captioned while reading"): return
	if not _a(viewer.is_open() and captions.layer > viewer.layer,
		"The call stays clear of document dimming and leaves the ledger open"): return
	if not _a(captions.layer < (office.get_node("PauseMenu") as PauseMenu).layer,
		"Pause keeps its foreground layer"): return

	# Described, never explained: no caption names a source.
	for text in SoundCaptions.CAPTIONS.values():
		for source in ["someone", "watchman", "listener", "figure", "man", "WATER", "WATCHER"]:
			if not _a(not (text as String).to_lower().contains(source.to_lower()),
				"'%s' does not name a source ('%s')" % [text, source]): return

	office.queue_free()
	for _frame in 5:
		await process_frame
	print("--- All Sound Captions Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
