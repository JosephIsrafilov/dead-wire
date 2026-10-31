extends SceneTree

## Plan 9.2: the night passes while you are not looking.
##
## While the dial is in view the hands keep the ordinary pace, however far the
## night has run ahead of them; the hours are caught up only while the clock is
## out of frame. At 02:00 and 03:00 the clock strikes, but never over a busy
## wire or inside a hush: a stroke held back sounds once the wire lets go.

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

func _run() -> void:
	print("--- Station clock pace and strike ---")
	var office := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var director := office.shift_director
	var clock := office.get_node_or_null("OfficeStorytellingProps/StationClock") as StationClock
	if not check(director != null and clock != null and clock.minute_hand != null, "The office has a director and a driven clock"): return
	if not check(director.has_method("is_station_watched") and clock.has_signal("clock_struck") and clock.has_signal("stroke_sounded"),
		"The clock reports whether it is watched and when it strikes"): return
	if not check(director.open_line(), "The line opens"): return

	# A stage jump: the night is three hours ahead of the hands.
	director.set("_station_target_hours", 26.0)
	director.set("_station_ceiling_hours", 26.0)
	var camera := office.get_viewport().get_camera_3d()
	var dial := clock.minute_hand.global_position
	camera.look_at(dial)
	clock.advance(0.016)
	if not check(bool(director.call("is_station_watched")), "A dial in frame counts as watched"): return
	var before := director.get_station_hours()
	director.call("_advance_station_clock", 1.0)
	if not check(director.get_station_hours() - before <= ShiftDirector.STATION_NORMAL_SPEED + 0.00001,
		"Watched, the hands keep the ordinary pace with three hours owed"): return

	camera.look_at(camera.global_position * 2.0 - dial)
	clock.advance(0.016)
	if not check(not bool(director.call("is_station_watched")), "Turning away leaves the dial unwatched"): return
	before = director.get_station_hours()
	director.call("_advance_station_clock", 1.0)
	if not check(director.get_station_hours() - before > ShiftDirector.STATION_NORMAL_SPEED * 3.0,
		"Out of frame the night catches up"): return

	var struck: Array[int] = []
	var strokes: Array[int] = []
	clock.connect("clock_struck", func(hour: int) -> void: struck.append(hour))
	clock.connect("stroke_sounded", func(index: int) -> void: strokes.append(index))
	for i in 600:
		director.call("_advance_station_clock", 0.25)
		clock.advance(0.25)
		if director.get_station_hours() >= 26.0 and strokes.size() >= 2:
			break
	for i in 40:
		clock.advance(0.25)
	if not check(struck == [2], "Two o'clock strikes once, got %s" % [struck]): return
	if not check(strokes.size() == 2, "Two o'clock is two strokes, got %d" % strokes.size()): return

	# Three o'clock arrives while the wire is busy: the stroke waits for it.
	var wire_seconds: float = director.call("_play_on_wire", "CR CR CR")
	if not check(wire_seconds > 0.0 and office.session_controller.scheduler.is_playing(), "The wire is busy"): return
	director.set("_station_target_hours", 27.0)
	director.set("_station_ceiling_hours", 27.0)
	for i in 400:
		director.call("_advance_station_clock", 0.25)
		clock.advance(0.25)
		if director.get_station_hours() >= 27.0:
			break
	for i in 20:
		clock.advance(0.25)
	if not check(director.get_station_hours() >= 27.0 and struck.size() == 1 and strokes.size() == 2,
		"No stroke sounds over a busy wire"): return
	office.session_controller.scheduler.cancel()
	for i in 40:
		clock.advance(0.25)
	if not check(struck == [2, 3] and strokes.size() == 5, "Once the wire lets go, three o'clock strikes three, got %s / %d" % [struck, strokes.size()]): return

	# Before the line opens the hands hold and nothing strikes.
	var fresh := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.remove_child(office)
	office.queue_free()
	root.add_child(fresh)
	await process_frame
	var fresh_clock := fresh.get_node("OfficeStorytellingProps/StationClock") as StationClock
	var silent: Array[int] = []
	fresh_clock.connect("clock_struck", func(hour: int) -> void: silent.append(hour))
	for i in 40:
		fresh_clock.advance(0.25)
	if not check(silent.is_empty() and fresh_clock.get_station_time_text() == "11:00 P.M.", "A watch not yet begun neither moves nor strikes"): return

	print("--- %d assertions passed ---" % _passed)
	quit(0)
