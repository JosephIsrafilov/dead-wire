extends SceneTree

## Drives a complete night shift with a hand-cranked clock.
##
## The point of the director is that the wire decides when work arrives, so these
## assertions are mostly about pressure being real: that a call goes unanswered if
## you are across the room, that an unanswered call costs something, and that the
## cost lands in WorldState while Elias's paperwork only ever shows what he knows.

var _assertions_passed: int = 0
var _phases: Array[int] = []
var _calls: Array[int] = []
var _missed: Array[String] = []
var _defaults: Array[String] = []

const PLAYER_SPEED_M_PER_S: float = 3.0
const ROOM_DIAGONAL_M: float = 7.4

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Shift Director Test Suite ---")

	var office := _fresh_office()
	if office == null: return
	var director := office.shift_director
	var session := office.session_controller

	# 1. The director is present in the production scene and owns the key.
	if not assert_condition(director != null, "Production scene contains a ShiftDirector"): return
	if not assert_condition(director.enabled, "ShiftDirector is enabled in the production scene"): return
	if not assert_condition(office.is_shift_directed(), "Office reports the shift is directed"): return
	if not assert_condition(not session.allow_key_start, "Session hands key ownership to the director"): return

	# 2. The key is worked from the chair. Standing at the desk is not working.
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.PRE_SHIFT, "Shift starts in PRE_SHIFT"): return
	var key := session.telegraph_key
	var seat := office.operator_seat
	if not assert_condition(seat != null, "Production scene has an operator seat"): return
	if not assert_condition(not seat.is_seated, "Operator starts on his feet"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_NOT_SEATED, "Standing operator is told to sit, got '%s'" % key.prompt_message): return
	if not assert_condition(not key.is_enabled, "Key is dead while the operator is standing"): return
	key.press()
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.PRE_SHIFT, "A standing operator cannot open the line"): return

	seat.approach_duration = 0.0
	if not assert_condition(seat.sit(), "Operator can sit at the desk"): return
	if not assert_condition(office.player.is_movement_locked, "Sitting locks walking"): return
	if not assert_condition(not office.player.is_look_locked, "Sitting leaves the head free"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_OPEN_LINE, "Seated operator is invited to open the line"): return
	if not assert_condition(key.is_enabled, "Key is actionable once seated"): return

	director.advance(120.0)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.PRE_SHIFT, "Time alone never opens the line"): return

	# 3. Opening the line loads the first booked message but does not play it.
	key.press()
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.WAITING, "Pressing the key opens the line"): return
	if not assert_condition(director.get_slot_index() == 0, "Shift begins at traffic slot 0"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.READY, "First message is loaded and waiting"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_LINE_QUIET, "Key reports a quiet line while waiting"): return
	if not assert_condition(not key.is_enabled, "Operator cannot start his own traffic"): return

	var sounder := session.sounder
	sounder.reset_telemetry()

	# 4. The wire stays quiet for the booked interval, then calls on its own.
	director.advance(director.wait_seconds_before_call[0] - 1.0)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.WAITING, "Line is still quiet before the interval elapses"): return
	if not assert_condition(sounder.down_clicks_played == 0, "Sounder is silent while the line is quiet"): return

	director.advance(1.1)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.CALLING, "Wire calls without any player action"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_ANSWER_CALL, "Key asks the operator to answer"): return
	if not assert_condition(key.is_enabled, "Key is actionable during a call"): return
	if not assert_condition(sounder.down_clicks_played > 0, "The call is physically audible on the sounder"): return

	# 5. Morse integrity: the call is real American Morse from the M1 alphabet.
	var encoder := AmericanMorseEncoder.new()
	var call_sequence := encoder.encode(director.call_sign, director.alphabet)
	if not assert_condition(call_sequence != null, "Call sign encodes in American Morse"): return

	# 6. Fairness: the total answering window must comfortably beat a walk across
	#    the room, or the game would be hiding a required message behind reflexes.
	var compiler := MorseScheduleCompiler.new()
	var call_schedule := compiler.compile(call_sequence, director.playback_profile)
	if not assert_condition(call_schedule != null, "Call sign compiles to a playable schedule"): return
	var one_call := call_schedule.total_duration_seconds
	var total_window := one_call * director.max_calls_per_message \
		+ director.call_repeat_gap_seconds * maxf(0.0, director.max_calls_per_message - 1) \
		+ director.answer_grace_seconds
	var crossing_time := ROOM_DIAGONAL_M / PLAYER_SPEED_M_PER_S
	if not assert_condition(total_window > crossing_time * 2.0, "Answer window exceeds two room crossings (%.1fs vs %.1fs)" % [total_window, crossing_time * 2.0]): return

	# 7. Ignoring the wire costs the message.
	director.call_started.connect(func(_slot: int, number: int) -> void: _calls.append(number))
	director.traffic_missed.connect(func(_slot: int, scenario: TelegraphScenarioData) -> void: _missed.append(scenario.scenario_id))
	director.advance(total_window + 5.0)

	var world := _world_state()
	var knowledge := _knowledge_state()
	if not assert_condition(_missed.size() == 1 and _missed[0] == "baseline_train_17", "An unanswered call is recorded as missed traffic"): return
	if not assert_condition(world.has_fact(&"telegram_missed_baseline_train_17"), "WorldState records the objective miss"): return
	if not assert_condition(knowledge.knows(&"missed_call_baseline_train_17"), "Elias knows he missed the call"): return
	if not assert_condition(not knowledge.knows(&"copied_baseline_train_17"), "Elias never learns what the missed message said"): return
	if not assert_condition(director.get_slot_index() == 1, "The shift moves on to the next booked message"): return
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.WAITING, "Missed traffic does not stall the shift"): return

	# 8. A missed message is a consequence, not a game over: the line keeps working.
	if not assert_condition(session.get_state() == TelegraphSessionController.State.READY, "Next message loads normally after a miss"): return

	print("  -- restarting with a fresh office for the answered path --")
	office = _fresh_office()
	if office == null: return
	director = office.shift_director
	session = office.session_controller
	key = session.telegraph_key
	knowledge = _knowledge_state()
	world = _world_state()
	# A settled operator: the R7 gate suspends ink while the sit transition is
	# still running, and this suite steps time without frames.
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	if not assert_condition(office.operator_seat.sit(), "Operator sits for the answered path"): return

	# 9. Answering the call starts the real transmission.
	key.press()
	director.advance(director.wait_seconds_before_call[0] + 0.1)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.CALLING, "Wire calls on the fresh shift"): return
	key.press()
	# Etiquette beat: the operator has answered; the sender draws breath first.
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.ANSWERING, "Answering the call opens a short beat before the message"): return
	if not assert_condition(session.get_state() != TelegraphSessionController.State.RECEIVING, "The sender has not started inside the beat"): return
	if not assert_condition(not key.is_enabled, "The key is inert inside the beat"): return
	director.advance(director.answer_beat_seconds + 0.05)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.RECEIVING, "Answering moves the shift into RECEIVING"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Session is receiving the real message"): return
	if not assert_condition(not key.is_enabled, "Key is inert while copy is coming in"): return

	# 10. Completing the message hands over to a routing deadline. The key
	# reports the session's work at each step, not a blanket "receiving" (R1).
	session.scheduler.advance_time(30.0)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.COPYING, "t0 leaves the physical copy open"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_FINISHING_COPY, "The key reports the copy being finished"): return
	_drain_paper(session.transcript_paper)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.VERIFYING, "Message completion waits for transcript verification"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_READ_COPY, "The key reports the finished copy waiting to be read"): return
	if not assert_condition(session.mark_transcript_verified(), "Transcript inspection unlocks route deadline"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Message ends awaiting a route"): return
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.AWAITING_ROUTE, "Director opens the routing deadline"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_AWAITING_ROUTE, "The key reports the route decision once the copy is verified"): return
	if not assert_condition(knowledge.knows(&"copied_baseline_train_17"), "Elias knows he copied the message"): return
	if not assert_condition(director.get_route_seconds_remaining() > 0.0, "Routing deadline is counting"): return

	# 11. The sender prods on the wire rather than through an on-screen timer.
	sounder = session.sounder
	sounder.reset_telemetry()
	_advance_night(session, director, director.route_nag_interval_seconds + 0.1)
	if not assert_condition(sounder.down_clicks_played > 0, "Sender asks again on the wire while waiting for a route"): return
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.AWAITING_ROUTE, "A prod does not end the deadline"): return

	# 12. A correct route inside the deadline files the message.
	session.submit_routing_decision("CLEAR EAST")
	if not assert_condition(world.has_fact(&"train_17_routed_clear"), "Correct route records the objective outcome"): return
	if not assert_condition(knowledge.knows(&"filed_baseline_train_17"), "Elias knows he filed the message"): return
	if not assert_condition(director.get_slot_index() == 1, "Shift advances to the second message"): return

	# 13. Letting the deadline run out is a decision the world acts on.
	director.advance(director.wait_seconds_before_call[1] + 0.1)
	key.press()
	director.advance(director.answer_beat_seconds + 0.05)
	session.scheduler.advance_time(60.0)
	_drain_paper(session.transcript_paper)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.VERIFYING, "Second message waits for transcript verification"): return
	session.mark_transcript_verified()
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.AWAITING_ROUTE, "Second message also awaits a route"): return
	director.route_defaulted.connect(func(_slot: int, scenario: TelegraphScenarioData) -> void: _defaults.append(scenario.scenario_id))
	_advance_night(session, director, director.route_deadline_seconds + 0.1)
	if not assert_condition(_defaults.size() == 1 and _defaults[0] == "attention_hold_freight", "Expired deadline defaults the route"): return
	if not assert_condition(not knowledge.knows(&"filed_attention_hold_freight"), "A defaulted route is not a filed message"): return
	if not assert_condition(knowledge.knows(&"lapsed_attention_hold_freight"), "Elias knows the freight order lapsed"): return
	if not assert_condition(director.get_slot_index() == 2, "Shift advances after a defaulted route"): return

	# 14. The final message is the core-hook commit, then closes the night.
	director.advance(director.wait_seconds_before_call[2] + 0.1)
	key.press()
	director.advance(director.answer_beat_seconds + 0.05)
	session.scheduler.advance_time(30.0)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.COPYING, "Final message leaves the copy open at t0"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_FINISHING_COPY, "The key reports the final copy being finished"): return
	_drain_paper(session.transcript_paper)
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_READ_COPY, "The key reports the final copy waiting to be read"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.VERIFYING, "Final message waits for transcript verification"): return
	if not assert_condition(session.mark_transcript_verified(), "Final transcript inspection unlocks the commit"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Final message opens the commit desk"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_FILE_COPY, "The key reports the filing decision"): return
	var phase_before_commit_wait := director.get_phase()
	_advance_night(session, director, 10.0)
	if not assert_condition(director.get_phase() == phase_before_commit_wait and director.get_slot_index() == 2, "Commit inspection pauses call pacing while the deadline runs"): return
	# (R8) A warning on a busy wire is deferred, never played over traffic, and
	# is dropped once its slot resolves.
	if not assert_condition(director._play_on_wire("E") > 0.0, "A service signal occupies the wire for the deferral case"): return
	session.advance_post_signal(10.15)
	if not assert_condition(director._pending_warning != &"", "A warning on a busy wire is deferred, not played over traffic"): return
	if not assert_condition(session.submit_commit(&"file_water"), "Final message accepts an authored commit inside the deadline"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Final message enters its consequence beat"): return
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_STAND_BY, "The key reports a neutral standby during the consequence beat"): return
	director.advance(0.3)
	if not assert_condition(director._pending_warning == &"", "A deferred warning is dropped once its slot is resolved"): return
	session.advance_consequence(1.0)
	session.notify_consequence_visible()
	session.advance_consequence(office.scenario_3.consequence_hold_seconds)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.CLOSING, "Last message closes the line"): return
	director.advance(director.closing_delay_seconds + 0.1)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.SHIFT_OVER, "Shift reaches SHIFT_OVER"): return
	if not assert_condition(director.is_shift_over(), "is_shift_over() agrees"): return
	if not assert_condition(not key.is_enabled, "Key is dead once the line closes"): return
	var closing_clock := office.get_node_or_null("OfficeStorytellingProps/StationClock") as StationClock
	if not assert_condition(closing_clock != null and closing_clock.get_station_hours() <= 30.0, "Closing never overshoots 6 A.M."): return
	# (H1) No snap at the close: the hands keep their own bounded speed toward
	# 06:00 instead of teleporting there the moment the line closes.
	var closing_hours := closing_clock.get_station_hours()
	if not assert_condition(key.prompt_message == ShiftDirector.PROMPT_SHIFT_OVER, "Key reports the shift is over"): return

	director.advance(300.0)
	if not assert_condition(director.get_phase() == ShiftDirector.Phase.SHIFT_OVER, "The night does not loop back around"): return
	if not assert_condition(closing_clock.get_station_hours() >= closing_hours, "The hands never ran backward across the close"): return
	if not assert_condition(closing_clock.get_station_time_text() == "6:00 A.M.", "The hands reach 6 A.M. at their bounded speed, got %s" % closing_clock.get_station_time_text()): return
	if not assert_condition(closing_clock.get_progress() == 1.0, "The clock rests at the end of the watch"): return

	# 15. The duty sheet is the goal surface, written from knowledge alone.
	var sheet := office.get_node_or_null("DutySheet") as DutySheet
	if not assert_condition(sheet != null, "Production scene contains the duty sheet"): return
	if not assert_condition(sheet.get_interactable() != null, "Duty sheet is interactable"): return

	var text := sheet.get_sheet_text()
	if not assert_condition(text.contains("TRAIN 17"), "Duty sheet lists the booked passenger traffic"): return
	if not assert_condition(text.contains(DutySheet.STATUS_FILED), "Duty sheet shows the filed message"): return
	if not assert_condition(text.contains("UNSCHEDULED TRAFFIC"), "Unbooked traffic appears once it has been copied"): return
	if not assert_condition(not text.contains("WATCHER") and not text.contains("WATER"), "Duty sheet never leaks message content"): return

	# 16. The sheet reports Elias, not the world. He believes he handled the
	#     freight; WorldState knows the route was never given.
	if not assert_condition(world.has_fact(&"freight_no_order_sent"), "WorldState recorded the defaulted freight route as no order sent"): return
	if not assert_condition(not world.has_fact(&"freight_cleared_in_error"), "A defaulted route is not a misdirected one"): return
	if not assert_condition(sheet.get_status_for(office.get_scenario_list()[1]) == DutySheet.STATUS_LAPSED, "Defaulted freight reads as no order sent"): return

	# 17. The night has to visibly move. The station clock is the only reading of
	#     how far through the watch the operator is.
	var props := office.get_node_or_null("OfficeStorytellingProps")
	if not assert_condition(props != null, "Storytelling props are present"): return
	var clock := props.get_node_or_null("StationClock") as StationClock
	if not assert_condition(clock != null, "Station clock is driven by a script"): return
	if not assert_condition(clock.minute_hand != null and clock.hour_hand != null, "Clock hands resolve"): return
	if not assert_condition(clock.director == office.shift_director, "Clock follows the shift director"): return

	# A fresh watch reads the head of the shift and holds there until the line opens.
	var fresh_office := _fresh_office()
	if fresh_office == null: return
	var fresh_clock := fresh_office.get_node_or_null("OfficeStorytellingProps/StationClock") as StationClock
	if not assert_condition(fresh_clock != null, "Fresh office has a station clock"): return
	if not assert_condition(fresh_clock.get_station_time_text() == "11:00 P.M.", "Watch begins at 11 P.M., got %s" % fresh_clock.get_station_time_text()): return
	fresh_clock.advance(60.0)
	if not assert_condition(fresh_clock.get_progress() == 0.0, "Hands do not move before the line is opened"): return

	fresh_office.operator_seat.sit_duration = 0.0
	fresh_office.operator_seat.approach_duration = 0.0
	fresh_office.operator_seat.sit()
	fresh_office.session_controller.telegraph_key.press()
	# (H1) The hands are monotone across phase changes: the old bug wound them
	# backward whenever a wait ended and a call began, and again at the close.
	var h_wait: float = fresh_office.shift_director.get_station_hours()
	fresh_office.shift_director.advance(fresh_office.shift_director.get_current_wait_seconds() + 0.1)
	var h_call: float = fresh_office.shift_director.get_station_hours()
	if not assert_condition(h_call >= h_wait, "The call beginning never rewinds the hands"): return
	fresh_office.session_controller.telegraph_key.press()
	fresh_office.shift_director.advance(2.0)
	var h_receive: float = fresh_office.shift_director.get_station_hours()
	if not assert_condition(h_receive >= h_call, "Answering the call never rewinds the hands"): return
	fresh_office.session_controller.scheduler.auto_process = false
	fresh_office.session_controller.scheduler.advance_time(30.0)
	_drain_paper(fresh_office.session_controller.transcript_paper)
	fresh_office.session_controller.mark_transcript_verified()
	fresh_office.session_controller.submit_routing_decision("CLEAR EAST")
	fresh_clock.advance(0.016)
	# Slot 0 resolved: the authored target is 02:00 and the display chases it
	# at a bounded speed instead of snapping onto it.
	if not assert_condition(absf(fresh_office.shift_director.get_station_target_hours() - 26.0) < 0.001, "Slot 0 resolved targets 02:00"): return
	var h_slot0: float = fresh_clock.get_station_hours()
	if not assert_condition(h_slot0 > 23.0 and h_slot0 < 26.0, "The display moved toward 02:00 without snapping, got %.2f" % h_slot0): return
	if not assert_condition(fresh_clock.get_station_time_text() != "11:00 P.M.", "The dial has left the start"): return

	var midnight_rotation := fresh_clock.minute_hand.rotation.x
	# Run the remaining slots through to the close.
	for slot in 2:
		fresh_office.shift_director.advance(fresh_office.shift_director.get_current_wait_seconds() + 0.1)
		fresh_office.session_controller.telegraph_key.press()
		fresh_office.shift_director.advance(2.0)
		fresh_office.session_controller.scheduler.advance_time(30.0)
		_drain_paper(fresh_office.session_controller.transcript_paper)
		fresh_office.session_controller.mark_transcript_verified()
		if slot == 0:
			fresh_office.session_controller.submit_routing_decision("HOLD")
		else:
			fresh_office.session_controller.submit_commit(&"file_water")
			fresh_office.session_controller.advance_consequence(1.5)
			fresh_office.session_controller.notify_consequence_visible()
			fresh_office.session_controller.advance_consequence(30.0)
	fresh_office.shift_director.advance(fresh_office.shift_director.closing_delay_seconds + 0.1)
	if not assert_condition(fresh_office.shift_director.is_shift_over(), "Fresh watch reaches SHIFT_OVER"): return
	# The hands had not crossed 06:00 at the moment the shift ended.
	if not assert_condition(fresh_clock.get_station_hours() <= 29.3 + 0.001, "The hands never crossed 06:00 before the shift ended, got %.2f" % fresh_clock.get_station_hours()): return
	# The hands do not wait for the player and are not waited for: they keep
	# their bounded speed toward 06:00 and stop there on their own.
	fresh_office.shift_director.advance(200.0)
	fresh_clock.advance(0.016)
	if not assert_condition(fresh_clock.get_station_time_text() == "6:00 A.M.", "Watch ends at 6 A.M., got %s" % fresh_clock.get_station_time_text()): return
	if not assert_condition(not is_equal_approx(fresh_clock.minute_hand.rotation.x, midnight_rotation), "The minute hand actually turned"): return
	if not assert_condition(fresh_clock.get_progress() == 1.0, "The clock stops at the end of the watch"): return

	# 17. (R8) A grace warning and a route nag landing in the same breath are
	# one wire call, and the grace still closes the slot on time.
	var merge_office: M1OfficeController = (ResourceLoader.load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	if not assert_condition(merge_office != null, "Merge-case office instantiates"): return
	root.add_child(merge_office)
	await process_frame
	await process_frame
	merge_office.get_node("IntroCard").skip_immediately()
	var merge_session := merge_office.session_controller
	var merge_director := merge_office.shift_director
	merge_director.set_process(false)
	merge_session.set_process(false)
	merge_session.scheduler.auto_process = false
	merge_office.operator_seat.sit_duration = 0.0
	merge_office.operator_seat.approach_duration = 0.0
	merge_office.operator_seat.sit()
	merge_session.telegraph_key.press()
	if not assert_condition(merge_director.get_phase() == ShiftDirector.Phase.WAITING, "Merge case opens the line"): return
	merge_director.advance(merge_director.wait_seconds_before_call[0] + 0.1)
	if not assert_condition(merge_director.get_phase() == ShiftDirector.Phase.CALLING, "Merge case reaches the call"): return
	merge_session.telegraph_key.press()
	merge_director.advance(merge_director.answer_beat_seconds + 0.05)
	if not assert_condition(merge_session.get_state() == TelegraphSessionController.State.RECEIVING, "Merge case answers the call"): return
	merge_session.scheduler.advance_time(30.0)
	if not assert_condition(merge_session.get_state() == TelegraphSessionController.State.COPYING, "Merge case leaves the copy open at t0"): return
	if not assert_condition(merge_director.get_phase() == ShiftDirector.Phase.AWAITING_ROUTE, "Merge case runs the route deadline from t0"): return
	# The grace warning (20 s - 5 s) and the first nag (15 s) land together.
	var wire_calls: Array[int] = [0]
	merge_session.scheduler.playback_started.connect(func(_schedule: MorsePlaybackScheduleData): wire_calls[0] += 1)
	_advance_night(merge_session, merge_director, 15.2)
	if not assert_condition(wire_calls[0] == 1, "Warning and nag in the same breath are a single wire call, got %d" % wire_calls[0]): return
	if not assert_condition(merge_director._nags_sent == 1, "The merged nag is still counted as delivered"): return
	# The grace then closes the open copy and the shift moves on.
	_advance_night(merge_session, merge_director, 6.0)
	if not assert_condition(merge_director.get_slot_index() == 1, "Grace expiry moves the shift to the next slot"): return
	merge_office.queue_free()

	print("--- All Shift Director Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

var _live_offices: Array[Node] = []

func _fresh_office() -> M1OfficeController:
	# A previous shift left running would keep its own ambience and sounder alive.
	for stale in _live_offices:
		if is_instance_valid(stale):
			root.remove_child(stale)
			stale.queue_free()
	_live_offices.clear()

	_world_state().reset_for_new_game()
	_knowledge_state().reset_for_new_game()

	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return null
	root.add_child(office)
	_live_offices.append(office)
	# Hand-crank both clocks so the shift is deterministic.
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	office.session_controller.scheduler.auto_process = false
	office.set_process(false)
	office.shift_director.set_process(false)
	return office

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

## Session and director advance one production-like step at a time: the shared
## post-signal clock and the deadline owner must never see each other ahead.
func _advance_night(session: TelegraphSessionController, director: ShiftDirector, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 0.25)
		session._process(step)
		director.advance(step)
		remaining -= step

func _world_state() -> WorldStateStore:
	return root.get_node_or_null("WorldState") as WorldStateStore

func _knowledge_state() -> KnowledgeStateStore:
	return root.get_node_or_null("KnowledgeState") as KnowledgeStateStore

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
