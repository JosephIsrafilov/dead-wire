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
	var unease := office.get_node_or_null("UneaseDirector") as UneaseDirector
	if not assert_condition(unease != null, "Unease director is wired"): return
	# Ink is physical: the hand enters the frame and follows the signal. Drive
	# the paper's presentation tick interleaved with the scheduler, as frames
	# would in production.
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()

	# --- the watch begins with the lamp turned down -------------------------
	# Taking the watch is a physical act: the operator turns up the wick. If he
	# opens the line without doing it, the lamp comes up with the shift anyway.
	var wick_life := office.get_node_or_null("LampLife") as LampLife
	if not assert_condition(wick_life != null and wick_life.wick < 0.5, "The lamp starts the watch turned down"): return
	var wick_act := office.get_node_or_null("DeskSetup/OilLamp/WickInteractable") as Interactable
	if not assert_condition(wick_act != null and wick_act.can_interact(), "The wick can be turned up by hand"): return
	wick_act.interact()
	for _step in 120:
		wick_life.advance(1.0 / 60.0)
	if not assert_condition(is_equal_approx(wick_life.wick, 1.0), "Turning the wick brings the lamp up to full"): return
	if not assert_condition(not wick_act.can_interact(), "A lit lamp offers no second turn"): return
	wick_life.set_wick_immediate(0.3)
	office.shift_director.open_line()
	for _step in 180:
		wick_life.advance(1.0 / 60.0)
	if not assert_condition(is_equal_approx(wick_life.wick, 1.0), "Opening the line brings a forgotten lamp up"): return

	# --- the authored silence BEFORE the first call ---------------------------
	# (A04) The room falls quiet inside the WAITING stretch, ahead of the
	# sounder — not when the call starts — and only once per watch.
	var hush_window: float = unease.pre_call_hush_seconds
	var wait0: float = office.shift_director.wait_seconds_before_call[0]
	_advance_room(office.shift_director, unease, maxf(wait0 - hush_window - 0.6, 0.0))
	if not assert_condition(not unease.is_hushed, "The room is still itself while the call is far off"): return
	_advance_room(office.shift_director, unease, 0.7)
	if not assert_condition(unease.is_hushed and unease.first_call_hush_done, "The room falls quiet ahead of the first call"): return
	_advance_room(office.shift_director, unease, hush_window + 0.4)
	if not assert_condition(office.shift_director.get_phase() == ShiftDirector.Phase.CALLING, "The call arrives after the hush, breaking it"): return
	if not assert_condition(not unease.is_hushed, "The hush is released once the call has the room"): return
	unease._maybe_hush_before_first_call()
	if not assert_condition(not unease.is_hushed, "The pre-call hush never repeats within the watch"): return


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
	session.telegraph_key.press()
	office.shift_director.advance(office.shift_director.answer_beat_seconds + 0.05)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Message is coming in"): return
	if not assert_condition(paper.is_copy_in_progress(), "The pad is being worked on during the message (feed or ink)"): return
	if not assert_condition(paper.get_visible_character_count() == 0, "The pad starts blank"): return

	var total := session.scheduler.get_total_duration_seconds()
	var half := 0.0
	while half < total * 0.5:
		session.scheduler.advance_time(0.1)
		paper.advance_paper(0.1)
		half += 0.1
	var midway := paper.get_visible_character_count()
	if not assert_condition(midway > 0, "Characters appear as the signal arrives"): return
	if not assert_condition(midway < paper.get_transcript_text().length(), "The transcript is not finished early"): return
	if not assert_condition(paper.get_display_text() != paper.get_transcript_text(), "The pad shows only what has been written so far"): return

	session.scheduler.advance_time(total)
	_drain_paper(paper)
	if not assert_condition(not paper.is_writing(), "Writing stops when the message ends"): return
	if not assert_condition(paper.get_display_text() == "TRAIN 17 CLEAR EAST", "The finished pad reads the full transcript"): return

	# --- the core hook, watched live -----------------------------------------
	var hook := office.get_scenario_list()[2]
	if not assert_condition(hook.transmission_data.true_message == "WATER", "Scenario 3 signal is WATER"): return
	if not assert_condition(hook.transmission_data.written_transcript == "WATCHER", "Scenario 3 transcript is WATCHER"): return
	paper.begin_writing(hook.transmission_data.written_transcript)
	paper.set_writing_progress(0.45)
	# The motion to each contact takes a moment; a partial drain leaves a
	# live, growing prefix — the mismatch is visible mid-write, not dumped.
	paper.advance_paper(0.6)
	var partial := paper.get_display_text()
	if partial.is_empty():
		paper.advance_paper(0.6)
		partial = paper.get_display_text()
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

	# The wick itself breathes with the light, and its rest scale never drifts.
	if not assert_condition(lamp_life.flame_mesh != null, "The lamp's flame mesh is bound in production"): return
	var flame_rest: float = lamp_life._flame_rest_scale.y
	var flame_min := flame_rest
	var flame_max := flame_rest
	for _step in 900:
		flame_min = minf(flame_min, lamp_life.flame_mesh.scale.y)
		flame_max = maxf(flame_max, lamp_life.flame_mesh.scale.y)
	if not assert_condition(flame_max > flame_min, "The flame visibly breathes"): return
	if not assert_condition(flame_min >= flame_rest * (1.0 - lamp_life.lamp_flicker_depth * 0.6 * 1.05), "The flame never shrinks past its depth"): return
	if not assert_condition(flame_max <= flame_rest * (1.0 + lamp_life.lamp_flicker_depth * 0.6 * 1.05), "The flame never flares past its depth"): return

	# --- the delayed creak ---------------------------------------------------
	unease.creaked.connect(func(spot: Vector3) -> void: _creak_positions.append(spot))
	unease.creak_chance = 1.0

	# Creaks come from real places in the room, not random polar offsets.
	var anchors := unease.get_creak_anchors()
	if not assert_condition(anchors.size() >= 4, "The room carries at least four creak anchors, got %d" % anchors.size()): return

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
	if not assert_condition(_creak_positions[0] in _anchor_positions(anchors), "The creak sounds from a physical anchor, not an invented spot"): return
	var distance := Vector2(_creak_positions[0].x - player.global_position.x, _creak_positions[0].z - player.global_position.z).length()
	if not assert_condition(distance >= unease.creak_min_player_distance * 0.99, "The creak keeps its distance from the operator's feet, got %.2f" % distance): return
	var first_anchor := _creak_positions[0]

	# Standing still forever does not turn into a metronome.
	unease.advance(30.0)
	if not assert_condition(unease.creaks_played == 1, "Standing still does not creak repeatedly"): return

	# It rearms only after moving again, and never repeats the previous anchor.
	player.velocity = Vector3(2.0, 0.0, 0.0)
	unease.advance(0.4)
	player.velocity = Vector3.ZERO
	unease.advance(unease.creak_dwell_seconds + 0.1)
	if not assert_condition(unease.creaks_played == 2, "Moving and stopping again can creak"): return
	if not assert_condition(_creak_positions[1] in _anchor_positions(anchors), "The second creak is also a physical anchor"): return
	if not assert_condition(_creak_positions[1] != first_anchor, "The building does not settle the same spot twice in a row"): return

	# No suitable anchor: the house stays quiet instead of inventing a source.
	# An explicitly wired but missing anchor list leaves no candidates at all.
	unease.creak_anchor_paths = [NodePath("DoesNotExist")]
	unease._creak_anchors.clear()
	unease._resolve_anchors()
	if not assert_condition(unease.get_creak_anchors().is_empty(), "A wired-but-missing anchor list yields no candidates"): return
	unease._creak_at_anchor(player.global_position)
	if not assert_condition(unease.creaks_played == 2, "No candidates means no creak, no loop, no error"): return

	# --- the clock: hands from the director, a real pendulum ------------------
	var clock := office.get_node_or_null("OfficeStorytellingProps/StationClock") as StationClock
	if not assert_condition(clock != null, "Station clock is wired"): return
	var pivot := clock.get_parent().get_node_or_null("ClockPendulumPivot") as Node3D
	var glass := clock.get_parent().get_node_or_null("ClockPendulumGlass") as Node3D
	if not assert_condition(pivot != null and pivot.get_node_or_null("ClockPendulumBob") != null, "The pendulum is a bob on a rod under a pivot"): return
	var glass_rest := glass.rotation if glass != null else Vector3.ZERO
	# The swing reads the ambience's escapement clock, so the mechanical rhythm
	# has exactly one phase in the whole room.
	if not assert_condition(clock.ambience != null, "The clock shares the ambience's mechanical phase"): return
	var ambience := clock.ambience
	ambience.reset_telemetry()
	var swings := 0
	for _step in 120:
		ambience.advance_clock(1.0 / 60.0)
		clock._swing_pendulum(1.0 / 60.0)
		if absf(pivot.rotation.x) > 0.002:
			swings += 1
	if not assert_condition(swings > 60, "The pendulum pivot actually swings, %d/120 frames" % swings): return
	if not assert_condition(absf(glass.rotation.x) < 0.00001 and glass.rotation == glass_rest, "The case glass never swings"): return
	# A tick lands on each swing extreme: half a pendulum period apart.
	ambience.reset_telemetry()
	ambience.advance_clock(0.99)
	clock._swing_pendulum(0.0)
	var at_tick := pivot.rotation.x
	ambience.advance_clock(0.99)
	clock._swing_pendulum(0.0)
	if not assert_condition(signf(at_tick) != signf(pivot.rotation.x), "The swing reverses each half period, in phase with the tick"): return

	# --- silence before the wire ---------------------------------------------
	var bus := AudioServer.get_bus_index(String(unease.creak_bus))
	if not assert_condition(bus >= 0, "Ambience bus exists"): return
	var rest_db := AudioServer.get_bus_volume_db(bus)
	unease.hush()
	if not assert_condition(unease.is_hushed, "The room can be hushed"): return
	if not assert_condition(unease.ambience.room_tone_player.volume_db < unease.ambience.room_tone_volume_db - 1.0, "Hushing actually drops the bed"): return
	if not assert_condition(is_equal_approx(AudioServer.get_bus_volume_db(bus), rest_db), "Hush preserves the user's ambience setting"): return
	unease.release_hush()
	if not assert_condition(not unease.is_hushed, "The hush releases"): return

	print("--- All Office Atmosphere Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func _anchor_positions(anchors: Array[Marker3D]) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in anchors:
		if anchor != null:
			positions.append(anchor.global_position)
	return positions

## Frames interleave every driver, as production frames would: the director
## paces, the unease polls, both see the same seconds.
func _advance_room(director: ShiftDirector, unease: UneaseDirector, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 0.1)
		director.advance(step)
		unease.advance(step)
		remaining -= step

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
