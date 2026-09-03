extends SceneTree

## The room being alive, and the dread that comes from it.
##
## Before this pass the project contained no animation of any kind — a grep for
## Tween, AnimationPlayer or create_tween across every script and scene returned
## nothing — so every state change was an instant flip and the office read as a
## diorama. These assertions cover the moving parts that carry the atmosphere.

var _assertions_passed: int = 0
var _creak_positions: Array[Vector3] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Office Atmosphere Test Suite ---")

	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return
	root.add_child(office)
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)

	# --- the sounder actually moves -----------------------------------------
	var sounder := office.session_controller.sounder
	if not assert_condition(sounder != null, "Sounder is wired"): return
	if not assert_condition(sounder.armature != null, "Sounder has an armature bar"): return

	var rest_y := sounder.armature.position.y
	sounder.play_down()
	for _step in 30:
		sounder._process(1.0 / 60.0)
	var struck_y := sounder.armature.position.y
	if not assert_condition(struck_y < rest_y - 0.001, "The armature drops onto the anvil on a mark"): return
	if not assert_condition(absf(struck_y - (rest_y - sounder.armature_travel)) < 0.0005, "It travels the configured distance"): return

	sounder.play_up()
	for _step in 30:
		sounder._process(1.0 / 60.0)
	if not assert_condition(absf(sounder.armature.position.y - rest_y) < 0.0005, "It lifts again on a gap"): return

	# --- Elias's hand writes while the signal is still arriving --------------
	var seat := office.operator_seat
	var session := office.session_controller
	var paper := session.transcript_paper
	if not assert_condition(paper != null, "Transcript pad is wired"): return

	seat.sit()
	office.shift_director.open_line()
	office.shift_director.advance(office.shift_director.wait_seconds_before_call[0] + 0.1)
	session.telegraph_key.press()
	if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Message is coming in"): return
	if not assert_condition(paper.is_writing(), "The pad is being written on during the message"): return
	if not assert_condition(paper.get_visible_character_count() == 0, "The pad starts blank"): return

	var total := session.scheduler.get_total_duration_seconds()
	session.scheduler.advance_time(total * 0.5)
	var midway := paper.get_visible_character_count()
	if not assert_condition(midway > 0, "Characters appear as the signal arrives"): return
	if not assert_condition(midway < paper.get_transcript_text().length(), "The transcript is not finished early"): return
	if not assert_condition(paper.get_display_text() != paper.get_transcript_text(), "The pad shows only what has been written so far"): return

	session.scheduler.advance_time(total)
	if not assert_condition(not paper.is_writing(), "Writing stops when the message ends"): return
	if not assert_condition(paper.get_display_text() == "TRAIN 17 CLEAR EAST", "The finished pad reads the full transcript"): return

	# --- the core hook, watched live -----------------------------------------
	var hook := office.get_scenario_list()[2]
	if not assert_condition(hook.transmission_data.true_message == "WATER", "Scenario 3 signal is WATER"): return
	if not assert_condition(hook.transmission_data.written_transcript == "WATCHER", "Scenario 3 transcript is WATCHER"): return
	paper.begin_writing(hook.transmission_data.written_transcript)
	paper.set_writing_progress(0.45)
	var partial := paper.get_display_text()
	if not assert_condition(partial.length() > 0 and "WATCHER".begins_with(partial), "WATCHER appears letter by letter, got '%s'" % partial): return

	# --- the window figure never blinks in on screen -------------------------
	var window_event := office.window_observation
	if not assert_condition(window_event != null, "Window event is wired"): return
	window_event.reset_state()
	var indicator := window_event.get_visual_indicator()
	if not assert_condition(indicator != null and not indicator.visible, "The figure is not there to begin with"): return

	indicator.visible = false
	window_event.is_active = true
	window_event.is_observed = false
	var seen := window_event.evaluate_observation(Vector3(0.65, 1.5, -1.0), Vector3(0.0, 0.0, -1.0), false)
	if not assert_condition(not seen, "A figure that has not appeared yet cannot be observed"): return
	window_event.reset_state()

	# --- the lamp and the stove breathe, without strobing --------------------
	var lamp_life := office.get_node_or_null("LampLife") as LampLife
	if not assert_condition(lamp_life != null, "Lamp life is wired"): return
	var lamp := office.get_node_or_null("DeskLampLight") as OmniLight3D
	var stove := office.get_node_or_null("StoveEmberLight") as OmniLight3D
	if not assert_condition(lamp != null and stove != null, "Both live lights are present"): return

	var lamp_rest := lamp_life.get_lamp_rest_energy()
	var stove_rest := lamp_life.get_stove_rest_energy()
	if not assert_condition(lamp_rest > 0.0 and stove_rest > 0.0, "Rest energies were captured"): return

	var lamp_min := lamp_rest
	var lamp_max := 0.0
	var stove_min := stove_rest
	var stove_max := 0.0
	for _step in 900:
		lamp_life.advance(1.0 / 60.0)
		lamp_min = minf(lamp_min, lamp.light_energy)
		lamp_max = maxf(lamp_max, lamp.light_energy)
		stove_min = minf(stove_min, stove.light_energy)
		stove_max = maxf(stove_max, stove.light_energy)

	if not assert_condition(lamp_max > lamp_min, "The lamp flickers"): return
	if not assert_condition(stove_max > stove_min, "The stove breathes"): return
	# Flicker must never become the thing the player is looking at.
	if not assert_condition(lamp_min >= lamp_rest * (1.0 - lamp_life.lamp_flicker_depth * 1.05), "Lamp never guts out"): return
	if not assert_condition(lamp_max <= lamp_rest * (1.0 + lamp_life.lamp_flicker_depth * 1.05), "Lamp never flares"): return
	if not assert_condition(stove_min >= stove_rest * (1.0 - lamp_life.stove_pulse_depth * 1.05), "Stove never dies"): return
	if not assert_condition(stove_max <= stove_rest * (1.0 + lamp_life.stove_pulse_depth * 1.05), "Stove never flares"): return

	# --- the delayed creak ---------------------------------------------------
	var unease := office.get_node_or_null("UneaseDirector") as UneaseDirector
	if not assert_condition(unease != null, "Unease director is wired"): return
	unease.creaked.connect(func(spot: Vector3) -> void: _creak_positions.append(spot))
	unease.creak_chance = 1.0

	var player := office.player
	# Walking arms it; standing still is what the building answers.
	player.velocity = Vector3(2.0, 0.0, 0.0)
	unease.advance(0.5)
	if not assert_condition(unease.creaks_played == 0, "Nothing creaks while the operator is walking"): return

	player.velocity = Vector3.ZERO
	unease.advance(unease.creak_dwell_seconds * 0.5)
	if not assert_condition(unease.creaks_played == 0, "Nothing creaks immediately on stopping"): return

	unease.advance(unease.creak_dwell_seconds * 0.6)
	if not assert_condition(unease.creaks_played == 1, "The building answers after the dwell"): return
	if not assert_condition(_creak_positions.size() == 1, "The creak reports where it came from"): return
	var distance := Vector2(_creak_positions[0].x - player.global_position.x, _creak_positions[0].z - player.global_position.z).length()
	if not assert_condition(distance > 1.0, "The creak comes from elsewhere in the room, not underfoot"): return

	# Standing still forever does not turn into a metronome.
	unease.advance(30.0)
	if not assert_condition(unease.creaks_played == 1, "Standing still does not creak repeatedly"): return

	# It rearms only after moving again, and respects its cooldown.
	player.velocity = Vector3(2.0, 0.0, 0.0)
	unease.advance(0.4)
	player.velocity = Vector3.ZERO
	unease.advance(unease.creak_dwell_seconds + 0.1)
	if not assert_condition(unease.creaks_played == 2, "Moving and stopping again can creak"): return

	# --- silence before the wire ---------------------------------------------
	var bus := AudioServer.get_bus_index(String(unease.creak_bus))
	if not assert_condition(bus >= 0, "Ambience bus exists"): return
	var rest_db := AudioServer.get_bus_volume_db(bus)
	unease.hush()
	if not assert_condition(unease.is_hushed, "The room can be hushed"): return
	if not assert_condition(AudioServer.get_bus_volume_db(bus) < rest_db - 1.0, "Hushing actually drops the bed"): return
	unease.release_hush()
	if not assert_condition(not unease.is_hushed, "The hush releases"): return

	print("--- All Office Atmosphere Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
