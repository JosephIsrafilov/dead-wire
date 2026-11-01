extends SceneTree

## Plan 10.6 (ROADMAP 2.8): a local playtest log, no network. A watch begun
## from the title writes one JSON line per moment that matters to a playtest:
## the night's phases, documents, the tape, the route and the filing (with
## the time since the copy finished), the figure, the whisper, pauses, the
## exit. The corrected word itself is never written, only its length. A
## watch not begun from the title (every test, every capture tool) writes
## nothing, and the player can switch the log off.

const DIR := "user://playtest_telemetry_test"
var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> bool:
	if condition:
		_passed += 1
		print("  PASS: " + description)
		return true
	print("  FAIL: " + description)
	quit(1)
	return false

func _files() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	return DirAccess.get_files_at(DIR)

func _clear() -> void:
	for name in _files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(name)))

func _office() -> M1OfficeController:
	var office := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.add_child(office)
	return office

func _run() -> void:
	print("--- Playtest telemetry ---")
	var script := load("res://scripts/office/playtest_telemetry.gd") as GDScript
	if not check(script != null, "The telemetry script exists"): return
	_clear()
	script.call("set_directory", DIR)

	# Not begun from the title: nothing written.
	var quiet := _office()
	await process_frame
	await process_frame
	quiet.queue_free()
	await process_frame
	if not check(_files().is_empty(), "A watch not begun from the title writes no log"): return

	# Begun from the title.
	var settings := GameSettings.load_settings()
	settings.set("playtest_telemetry_enabled", true)
	settings.save()
	script.call("arm")
	var office := _office()
	await process_frame
	await process_frame
	if not check(_files().size() == 1, "A watch begun from the title opens one session file"): return
	office.shift_director.open_line()
	office.document_viewer.open_document("dispatch_ledger", "LEDGER", "TEXT")
	office.session_controller.copy_finished.emit("core_hook")
	office.session_controller.routing_resolved.emit("HOLD", TelegraphSessionController.RoutingOutcome.INCORRECT)
	office.session_controller.commit_recorded.emit("core_hook", &"file_amended", "WATER")
	office.window_observation.visibility_started.emit()
	(office.get_node("PauseMenu") as Node).emit_signal("paused")
	office.office_door.player_left_office.emit()
	office.queue_free()
	await process_frame
	await process_frame

	var path := DIR.path_join(_files()[0])
	var text := FileAccess.get_file_as_string(path)
	var events: Array[String] = []
	var all_json := true
	var line_count := 0
	for line in text.split("\n", false):
		line_count += 1
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary) or not (parsed as Dictionary).has("t") or not (parsed as Dictionary).has("event"):
			all_json = false
			continue
		events.append(String((parsed as Dictionary)["event"]))
	if not check(line_count > 0 and all_json, "Every line is one JSON event with its time"): return
	for wanted in ["session_start", "night_start", "phase", "document_opened", "route", "filing", "figure_visible", "paused", "exit"]:
		if not check(wanted in events, "The log records %s" % wanted): return
	if not check(not text.contains("WATER"), "The corrected word itself is never written"): return
	if not check(text.contains("\"word_length\":5") and text.contains("\"outcome\":\"INCORRECT\"") and text.contains("since_copy_s"),
		"The filing keeps its length, the route its outcome and both their time since the copy"): return

	# Switched off: armed or not, nothing is written.
	_clear()
	settings.set("playtest_telemetry_enabled", false)
	settings.save()
	script.call("arm")
	var off := _office()
	await process_frame
	await process_frame
	off.queue_free()
	await process_frame
	if not check(_files().is_empty(), "With the log switched off nothing is written"): return
	if not check(not bool(script.call("is_armed")), "Arming is spent by the watch it was for"): return
	_clear()
	print("--- %d assertions passed ---" % _passed)
	quit(0)
