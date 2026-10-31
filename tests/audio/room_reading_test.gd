extends SceneTree
## Plan 7.1-7.4, 7.10: the room can be read with the eyes closed.
##   - two boards speak under the operator, each always in its own voice, once
##     as the weight comes on;
##   - steps and knocked objects never repeat the same sample twice running;
##   - the yard is heard rarely, from beyond the north window, through glass,
##     and never over a critical copy or in a hush;
##   - the wind and the fire wander in level, and their loops are long;
##   - the room has a little air, the telegraph almost none.
##   godot --headless --audio-driver Dummy --path . --script tests/audio/room_reading_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Room Reading Test Suite ---")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _frame in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var ambience := office.get_node("OfficeAmbience") as OfficeAmbience
	ambience.set_hush_db(0.0)

	# --- 7.10 the boards ---------------------------------------------------------
	var boards := office.get_node_or_null("CreakyBoards") as CreakyBoards
	if not _a(boards != null, "The office has its speaking boards"): return
	var door_board := boards.to_global(boards.board_positions[0])
	var window_board := boards.to_global(boards.board_positions[1])
	var door_floor := (office.get_node("SouthDoor") as Node3D).global_position * Vector3(1, 0, 1)
	var window_floor := (office.get_node("NorthWindow") as Node3D).global_position * Vector3(1, 0, 1)
	if not _a(door_board.distance_to(door_floor) < 0.8 and window_board.distance_to(window_floor) < 0.8,
		"One board is just inside the door, one before the window"): return
	if not _a(boards.get_board_player(0).stream != boards.get_board_player(1).stream,
		"The two boards have different voices"): return
	boards.step_at(Vector3(0.0, 0.0, 0.5))
	if not _a(boards.creaks_played == 0, "Bare floor says nothing"): return
	boards.step_at(door_board)
	var door_stream := boards.get_board_player(0).stream
	if not _a(boards.creaks_played == 1 and boards.get_board_player(0).playing, "Weight on the door board makes it speak"): return
	boards.step_at(door_board + Vector3(0.1, 0, 0))
	if not _a(boards.creaks_played == 1, "A board speaks once as the weight comes on, not on every step"): return
	boards.step_at(Vector3(0.0, 0.0, 0.5))
	boards.step_at(door_board)
	if not _a(boards.creaks_played == 2 and boards.get_board_player(0).stream == door_stream,
		"Coming back, the same board says the same thing"): return
	if not _a(boards.get_board_player(0).bus == &"Foley", "The boards are the operator's own sounds (Foley)"): return

	# --- 7.4 steps never repeat --------------------------------------------------
	var player := office.player
	var steps: Array[AudioStream] = []
	for _i in 15:
		player._play_footstep()
		steps.append(player.footstep_player.stream)
	if not _a(_distinct(steps) >= 4, "Walking uses at least four different steps (%d)" % _distinct(steps)): return
	if not _a(not _repeats(steps), "No step sample plays twice running"): return

	# --- 7.4 knocked objects never repeat ----------------------------------------
	var foley := office.get_node("OfficeFoley")
	for kind in ["light", "heavy"]:
		var prop: LooseProp = null
		for child in office.get_node("LooseProps").get_children():
			if child is LooseProp and ((child as LooseProp).prop_mass > 0.16) == (kind == "heavy"):
				prop = child
				break
		if not _a(prop != null, "A %s loose object is in the room" % kind): return
		var source := foley.get_node(NodePath(String(prop.name) + "Impact")) as AudioStreamPlayer3D
		var knocks: Array[AudioStream] = []
		for _i in 12:
			prop.impacted.emit(1.0)
			knocks.append(source.stream)
		if not _a(_distinct(knocks) >= 3 and not _repeats(knocks), "A %s object lands three different ways, never the same twice running" % kind): return

	# --- 7.2 the yard through the glass ------------------------------------------
	var yard := office.get_node_or_null("OutsideThroughWindow") as OutsideThroughWindow
	if not _a(yard != null and yard.streams.size() >= 3, "The yard has at least three voices"): return
	yard.set_process(false)
	if not _a(yard.first_after_seconds >= 30.0 and yard.min_interval_seconds >= 30.0, "The yard is rare: never in the first half-minute, never often"): return
	yard.play_next()
	var yard_source := yard.get_player()
	if not _a(yard_source.global_position.z < -3.0 and yard_source.bus == &"Ambience", "It comes from beyond the north window, on the room's bus"): return
	if not _a(yard_source.attenuation_filter_cutoff_hz < yard.open_cutoff_hz, "Through the glass it arrives duller than through the open door"): return
	var session := office.session_controller
	session.set_process(false)
	session.scheduler.auto_process = false
	session.allow_key_start = true
	# Any traffic on the wire, plain copy included: the yard waits.
	office.load_scenario_by_index(0)
	session.start_transmission()
	if not _a(not yard.is_quiet_allowed(), "The yard waits while anything is on the wire"): return
	session.scheduler.cancel()
	# Between the answer and the first mark the sender draws breath: still no.
	var director := office.shift_director
	var phase_before: ShiftDirector.Phase = director._phase
	director._phase = ShiftDirector.Phase.ANSWERING
	if not _a(not yard.is_quiet_allowed(), "The yard waits through the answer, before the copy starts"): return
	director._phase = phase_before
	office.load_scenario_by_index(2)
	if not _a(session.start_transmission(), "A critical copy goes on the wire"): return
	var played := yard.sounds_played
	yard.advance(1000.0)
	if not _a(not yard.is_quiet_allowed() and yard.sounds_played == played, "The yard holds its peace over a critical copy"): return
	session.scheduler.cancel()
	var gate := office.get_node("FairnessGate") as FairnessGate
	gate.advance(5.0)
	ambience.set_hush_db(-20.0)
	yard.advance(1000.0)
	if not _a(yard.sounds_played == played, "The yard holds its peace in a hush"): return
	ambience.set_hush_db(0.0)
	# Waiting on the next call: never start what would run into it, or into the
	# hush that comes before the last one.
	var slot_before: int = director._slot_index
	director._slot_index = 0
	director._phase = ShiftDirector.Phase.WAITING
	director._phase_timer = director.get_current_wait_seconds() - 3.0
	if not _a(not yard.is_quiet_allowed(), "The yard does not start when the call is seconds away"): return
	director._phase_timer = 0.0
	if not _a(yard.is_quiet_allowed(), "Early in the wait, the yard may speak"): return
	director._slot_index = slot_before
	director._phase = phase_before
	director._phase_timer = 0.0
	yard.advance(1000.0)
	if not _a(yard.sounds_played == played + 1, "Once the room is itself again, the yard may speak"): return
	if not _a(yard.get_player().attenuation_filter_cutoff_hz >= 2000.0 and yard.get_player().attenuation_filter_db >= -12.0,
		"The glass dulls the yard but leaves its iron audible"): return

	# --- 7.3 the beds wander and do not loop by ear -------------------------------
	var levels: Array[float] = []
	ambience._drift_rng.seed = 1890
	for _i in 600:
		ambience.advance_drift(0.1)
		levels.append(ambience.wind_player.volume_db - ambience.wind_volume_db)
	var low: float = levels.min()
	var high: float = levels.max()
	if not _a(high - low > 1.5, "Over a minute the wind leans louder and softer (%.1f dB)" % (high - low)): return
	if not _a(low >= -ambience.wind_drift_db - 0.01 and high <= ambience.wind_drift_db + 0.01, "It never strays past its bounds"): return
	ambience.set_hush_db(-26.0)
	if not _a(ambience.wind_player.volume_db <= ambience.wind_volume_db - 26.0 + ambience.wind_drift_db + 0.01,
		"A hush still takes the wind down"): return
	ambience.set_hush_db(0.0)
	if not _a(ambience.wind_player.stream.get_length() >= 45.0 and ambience.stove_player.stream.get_length() >= 35.0,
		"The wind and the fire loops are long enough not to be heard turning over"): return

	# --- 7.1 air in the room, none on the wire ------------------------------------
	var room_verb := _reverb(&"Ambience")
	var wire_verb := _reverb(&"Telegraph")
	if not _a(room_verb != null and wire_verb != null, "The room and the wire both sit in the room's air"): return
	if not _a(wire_verb.wet <= 0.08 and wire_verb.dry >= 0.9, "The telegraph stays nearly dry: copy is read, not felt"): return

	office.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Room Reading Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _reverb(bus_name: StringName) -> AudioEffectReverb:
	var bus := AudioServer.get_bus_index(bus_name)
	for index in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, index) is AudioEffectReverb:
			return AudioServer.get_bus_effect(bus, index)
	return null

func _distinct(items: Array[AudioStream]) -> int:
	var seen := {}
	for item in items:
		seen[item] = true
	return seen.size()

func _repeats(items: Array[AudioStream]) -> bool:
	for index in range(1, items.size()):
		if items[index] == items[index - 1]:
			return true
	return false

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
