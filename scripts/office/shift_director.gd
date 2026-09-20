class_name ShiftDirector
extends Node

## Runs a night shift on the wire's clock instead of the player's.
##
## Without this, the operator walks to the desk, presses the key, and hears his
## own telegram start. Nothing can pull his attention away, because nothing
## happens until he decides it should. The central M1 question — "is it
## uncomfortable to turn away from the window when the sounder begins a
## transmission?" — cannot even be asked under that flow.
##
## Here the wire calls first. Black Creek's call sign rattles out of the sounder
## while the player may be at the routing board, at the ledger, or at the window.
## Answering means getting back to the key. Not answering has a cost.
##
## Every deadline in this file is generous enough to cross the room twice. The
## game competes for attention; it never makes a required message unhearable.

enum Phase {
	PRE_SHIFT,
	WAITING,
	CALLING,
	RECEIVING,
	AWAITING_ROUTE,
	CLOSING,
	SHIFT_OVER
}

signal phase_changed(new_phase: Phase, previous_phase: Phase)
signal shift_opened()
signal call_started(slot_index: int, call_number: int)
signal call_answered(slot_index: int, call_number: int)
signal traffic_missed(slot_index: int, scenario: TelegraphScenarioData)
signal route_deadline_started(slot_index: int, seconds: float)
signal route_defaulted(slot_index: int, scenario: TelegraphScenarioData)
signal shift_closed()

@export var enabled: bool = true
@export var office: M1OfficeController = null
@export var session: TelegraphSessionController = null
@export var seat: OperatorSeat = null

@export var alphabet: AmericanMorseAlphabetData = preload("res://data/morse/m1_american_morse_alphabet.tres")
@export var playback_profile: MorsePlaybackProfileData = preload("res://data/morse/m1_morse_playback_profile.tres")

## Quiet stretch before each message. The first is long on purpose: the player
## needs unpressured time to learn the room before the room starts pressing back.
@export var wait_seconds_before_call: PackedFloat32Array = PackedFloat32Array([14.0, 9.0, 7.0])

## Black Creek's office call. Restricted to the 18 characters M1 supports.
@export var call_sign: String = "CR CR"
@export var call_repeat_gap_seconds: float = 3.5
@export var max_calls_per_message: int = 3

## Time the operator still has to answer after the final call dies away.
@export var answer_grace_seconds: float = 4.0

@export var route_deadline_seconds: float = 45.0
@export var route_nag_interval_seconds: float = 15.0
@export var default_route_action: String = "NO ORDER"

## Station time targets per plan §8: the director owns the night's clock.
## Stage events set targets; the display chases them monotonically at a
## bounded speed. Nothing here snaps, and the hands never run backward.
const STATION_OPEN_LINE_HOURS: float = 23.0
const STATION_CLOSING_HOURS: float = 29.3
const STATION_SHIFT_OVER_HOURS: float = 30.0
## Ordinary pace: roughly seven station hours across a 300-second watch.
const STATION_NORMAL_SPEED: float = 7.0 / 300.0
## Upper bound on catch-up after a stage target jumps (hours per real second).
const STATION_CATCHUP_SPEED: float = 0.04

## Displayed station time (monotone, bounded speed).
var _station_display_hours: float = STATION_OPEN_LINE_HOURS
## Where the display is heading: stage events raise it; inside a stage it
## drifts up toward the stage ceiling at the ordinary pace.
var _station_target_hours: float = STATION_OPEN_LINE_HOURS
## The stage ceiling: the display never crosses 06:00 before closing.
var _station_ceiling_hours: float = STATION_OPEN_LINE_HOURS
var _station_clock_running: bool = false

## Telegrapher's sign-off, sent once the night's traffic is done. A clean watch
## gets good night. A watch with a hole in it gets asked where the train is —
## which is the objective world answering, not Elias's own record of himself.
@export var closing_sign: String = "GN"
@export var closing_sign_trouble: String = "OS 17"
@export var closing_delay_seconds: float = 4.0

## How close a warning and a nag may land before they count as one reminder.
@export var warning_nag_merge_seconds: float = 1.0

const PROMPT_OPEN_LINE: String = "Open the Line (Begin Shift)"
const PROMPT_LINE_QUIET: String = "Line Quiet"
const PROMPT_ANSWER_CALL: String = "Answer the Call"
const PROMPT_RECEIVING: String = "Line Busy (Receiving)"
const PROMPT_FINISHING_COPY: String = "Finishing the Copy"
const PROMPT_READ_COPY: String = "Read the Finished Copy"
const PROMPT_AWAITING_ROUTE: String = "Sender Waiting — Set the Route"
const PROMPT_FILE_COPY: String = "File One Copy"
const PROMPT_STAND_BY: String = "Stand By"
const PROMPT_CLOSING: String = "Line Closing"
const PROMPT_SHIFT_OVER: String = "Line Closed — Shift Over"
const PROMPT_NOT_SEATED: String = "Sit to Work the Key"

var _phase: Phase = Phase.PRE_SHIFT
var _slot_index: int = -1
var _phase_timer: float = 0.0
var _calls_sent: int = 0
var _call_window_seconds: float = 0.0
var _nags_sent: int = 0
var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()
## A deadline warning waiting for the wire to free up. Never extends anything;
## dropped the moment the situation it described is gone.
var _pending_warning: StringName = &""
## Post-signal time of the last nag, so a warning landing in the same breath as
## a nag does not rattle the sounder twice for one reminder.
var _last_nag_elapsed: float = -1.0
## Post-signal time of the last warning that actually played, so the reverse
## order — a warning first, the nag due a moment later — also merges.
var _last_warning_elapsed: float = -1.0

var calls_sent_total: int = 0
var messages_missed: int = 0
var routes_defaulted: int = 0
var routes_misdirected: int = 0

func _ready() -> void:
	_bind()

func _bind() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	if session == null and office != null:
		session = office.session_controller
	if seat == null and office != null:
		seat = office.get_node_or_null("Chair/OperatorSeat") as OperatorSeat

	if not enabled:
		return

	if session != null:
		if not session.verification_requested.is_connected(_on_verification_requested):
			session.verification_requested.connect(_on_verification_requested)
		# The wire owns the key from here on.
		session.allow_key_start = false
		if not session.transmission_finished.is_connected(_on_transmission_finished):
			session.transmission_finished.connect(_on_transmission_finished)
		if not session.copy_finished.is_connected(_on_copy_finished):
			session.copy_finished.connect(_on_copy_finished)
		if not session.session_completed.is_connected(_on_session_completed):
			session.session_completed.connect(_on_session_completed)
		if not session.routing_requested.is_connected(_on_route_requested):
			session.routing_requested.connect(_on_route_requested)
		if not session.routing_resolved.is_connected(_on_routing_resolved):
			session.routing_resolved.connect(_on_routing_resolved)
		if not session.deadline_warning.is_connected(_on_deadline_warning):
			session.deadline_warning.connect(_on_deadline_warning)
		# The key reports the work, and the work lives in the session: COPYING,
		# VERIFYING and the decision states each say what they are instead of a
		# blanket "receiving".
		if not session.session_state_changed.is_connected(_on_session_state_changed):
			session.session_state_changed.connect(_on_session_state_changed)

		var key := session.telegraph_key
		if key != null and not key.key_pressed.is_connected(_on_key_pressed):
			key.key_pressed.connect(_on_key_pressed)

	_apply_key_state()

## Re-applies the key prompt. The seat calls this when the operator sits or stands.
func refresh_key_state() -> void:
	_apply_key_state()

## Session work states change without a director phase change (COPYING,
## VERIFYING, the decision states); the key must follow them.
func _on_session_state_changed(_new_state: TelegraphSessionController.State, _prev_state: TelegraphSessionController.State) -> void:
	_apply_key_state()

func is_operator_seated() -> bool:
	return seat != null and seat.is_seated

func get_phase() -> Phase:
	return _phase

## Booked traffic count for the night (public: the station clock paces its
## hands to the slots themselves).
func get_scenario_count() -> int:
	return _scenario_count()

## Seconds the current slot waits before its call (public, same purpose).
func get_current_wait_seconds() -> float:
	return _current_wait_seconds()

func get_slot_index() -> int:
	return _slot_index

func get_phase_timer() -> float:
	return _phase_timer

func is_shift_over() -> bool:
	return _phase == Phase.SHIFT_OVER

## Seconds since t0 from the session's single post-signal clock, so the route
## deadline cannot drift from the commit deadline or the copy grace.
func _route_elapsed() -> float:
	if session != null and session.get_post_signal_elapsed() >= 0.0:
		return session.get_post_signal_elapsed()
	# No session clock (tests without a live signal): keep the phase timer as
	# the honest fallback rather than freezing the deadline.
	return _phase_timer

## Seconds left on the routing deadline, or -1.0 when no deadline is running.
func get_route_seconds_remaining() -> float:
	if _phase != Phase.AWAITING_ROUTE:
		return -1.0
	return maxf(0.0, route_deadline_seconds - _route_elapsed())

## True when the route deadline has run out. Input arriving at or after this
## moment is rejected; the lapse resolves the slot.
func is_route_deadline_expired() -> bool:
	if _phase != Phase.AWAITING_ROUTE or route_deadline_seconds <= 0.0:
		return false
	return _route_elapsed() >= route_deadline_seconds

func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can drive a whole shift deterministically.
##
## Large deltas are consumed in bounded sub-steps. A single frame hitch must not
## swallow a whole call cycle, and a test stepping a minute at once must see the
## same sequence of events a player would.
func advance(delta: float) -> void:
	if not enabled or delta <= 0.0:
		return

	const MAX_STEP: float = 0.25
	var remaining := delta
	var guard := 0
	while remaining > 0.0 and guard < 8192:
		guard += 1
		var step := minf(remaining, MAX_STEP)
		remaining -= step
		_advance_step(step)

func _advance_step(delta: float) -> void:
	_advance_station_clock(delta)
	# A deferred warning waits for the wire to free up; the deadline itself is
	# never extended by the wait. Stale reminders are dropped, not played.
	if _pending_warning != &"":
		if not _warning_still_relevant():
			_pending_warning = &""
		elif _wire_idle():
			_play_on_wire(call_sign)
			if session != null:
				_last_warning_elapsed = session.get_post_signal_elapsed()
			_pending_warning = &""
	match _phase:
		Phase.WAITING:
			_phase_timer += delta
			if _phase_timer >= _current_wait_seconds():
				_begin_call_cycle()
		Phase.CALLING:
			_phase_timer += delta
			if _phase_timer >= _call_window_seconds:
				if _calls_sent < max_calls_per_message:
					_send_call()
				else:
					_miss_current_traffic()
		Phase.AWAITING_ROUTE:
			_phase_timer += delta
			_maybe_nag()
			if _route_elapsed() >= route_deadline_seconds:
				_default_route()
		Phase.CLOSING:
			_phase_timer += delta
			if _phase_timer >= closing_delay_seconds:
				_set_phase(Phase.SHIFT_OVER)
		_:
			pass

## The one deliberate act the player makes before the night takes over.
func open_line() -> bool:
	if not enabled or _phase != Phase.PRE_SHIFT:
		return false
	if session == null:
		_bind()
	if session == null:
		return false
	shift_opened.emit()
	_station_clock_running = true
	_station_display_hours = STATION_OPEN_LINE_HOURS
	_station_target_hours = STATION_OPEN_LINE_HOURS
	_station_ceiling_hours = _station_target_for_resolved_slot(_scenario_count(), 0)
	_advance_to_slot(0)
	return true

## The station clock the whole room reads. The display is monotone: phase
## changes (call, slot, closing) move the target, never the hands backward.
func get_station_hours() -> float:
	return _station_display_hours

func get_station_target_hours() -> float:
	return _station_target_hours

func _advance_station_clock(delta: float) -> void:
	if not _station_clock_running or delta <= 0.0:
		return
	# Inside a stage the target drifts up toward the stage ceiling at the
	# ordinary pace, so the hands keep living between events.
	if _station_target_hours < _station_ceiling_hours:
		_station_target_hours = minf(
			_station_target_hours + STATION_NORMAL_SPEED * delta,
			_station_ceiling_hours)
	var remaining := _station_target_hours - _station_display_hours
	if remaining <= 0.0:
		return
	# Rate proportional to the remaining gap, clamped between the ordinary
	# pace and the catch-up cap: smooth acceleration, bounded speed, and the
	# display can never overtake or run behind its own target.
	var speed := clampf(remaining * 0.25, STATION_NORMAL_SPEED,
		STATION_CATCHUP_SPEED)
	_station_display_hours = minf(
		_station_display_hours + speed * delta, _station_target_hours)

## Authored M1 pacing (plan §8): 02:00 once the first booked message resolves
## (answered, lapsed or missed alike), 03:00 once the second does, 05:18 at
## closing. Other traffic counts fall back to an even spread of the night.
func _station_target_for_resolved_slot(count: int, resolved_index: int) -> float:
	if count == 3:
		match resolved_index:
			0:
				return 26.0
			1:
				return 27.0
			_:
				return STATION_CLOSING_HOURS
	return lerpf(STATION_OPEN_LINE_HOURS, STATION_CLOSING_HOURS,
		float(resolved_index + 1) / float(maxi(count, 1)))

## Stage boundaries raise the target (and the ceiling to the next boundary).
## A fast player leaves the display trailing honestly; it is never teleported.
func _apply_station_stage(next_slot_index: int) -> void:
	var count := _scenario_count()
	if next_slot_index <= 0:
		return
	_station_target_hours = maxf(_station_target_hours,
		_station_target_for_resolved_slot(count, next_slot_index - 1))
	if next_slot_index < count:
		_station_ceiling_hours = maxf(_station_ceiling_hours,
			_station_target_for_resolved_slot(count, next_slot_index))
	else:
		_station_ceiling_hours = maxf(_station_ceiling_hours,
			STATION_CLOSING_HOURS)

func _advance_to_slot(index: int) -> void:
	var scenarios := _scenario_count()
	if index >= scenarios:
		_begin_closing()
		return

	_slot_index = index
	_apply_station_stage(index)
	_calls_sent = 0
	_nags_sent = 0
	_last_nag_elapsed = -1.0
	_last_warning_elapsed = -1.0
	_pending_warning = &""
	if office != null:
		office.load_scenario_by_index(_slot_index)
	_set_phase(Phase.WAITING)

func _current_wait_seconds() -> float:
	if _slot_index < 0:
		return 0.0
	if _slot_index < wait_seconds_before_call.size():
		return wait_seconds_before_call[_slot_index]
	if wait_seconds_before_call.is_empty():
		return 10.0
	return wait_seconds_before_call[wait_seconds_before_call.size() - 1]

func _begin_call_cycle() -> void:
	_calls_sent = 0
	_set_phase(Phase.CALLING)
	_send_call()

func _send_call() -> void:
	_calls_sent += 1
	calls_sent_total += 1
	var duration := _play_on_wire(call_sign)
	# The final call carries the extra grace period; earlier ones only the gap.
	var tail := answer_grace_seconds if _calls_sent >= max_calls_per_message else call_repeat_gap_seconds
	_call_window_seconds = duration + tail
	_phase_timer = 0.0
	call_started.emit(_slot_index, _calls_sent)

## Compiles text through the same encoder and scheduler the real traffic uses, so
## service signals are physically the same American Morse as the messages.
## Returns the schedule duration in seconds, or 0.0 if it could not be played.
func _play_on_wire(text: String) -> float:
	if session == null or session.scheduler == null or alphabet == null or playback_profile == null:
		return 0.0

	var sequence := _encoder.encode(text, alphabet)
	if sequence == null:
		return 0.0
	var schedule := _compiler.compile(sequence, playback_profile)
	if schedule == null:
		return 0.0

	session.scheduler.cancel()
	if not session.scheduler.start(schedule):
		return 0.0
	return schedule.total_duration_seconds

func _on_key_pressed() -> void:
	if not enabled:
		return

	match _phase:
		Phase.PRE_SHIFT:
			open_line()
		Phase.CALLING:
			_answer_call()
		_:
			pass

func _answer_call() -> void:
	if session == null:
		return

	session.scheduler.cancel()
	call_answered.emit(_slot_index, _calls_sent)
	if session.start_transmission():
		_set_phase(Phase.RECEIVING)
	else:
		# The line refused; treat it as unanswered rather than stalling the shift.
		_miss_current_traffic()

func _miss_current_traffic() -> void:
	var scenario := _current_scenario()
	messages_missed += 1

	if session != null:
		session.scheduler.cancel()

	if scenario != null:
		var identifier := _scenario_identifier(scenario)
		var world := _world_state()
		if world != null:
			world.set_fact(StringName("telegram_missed_%s" % identifier), true)
		# Elias knows the wire called and that he did not copy it. He does not
		# know what it said, so no transcript knowledge is recorded.
		var knowledge := _knowledge_state()
		if knowledge != null:
			knowledge.learn(StringName("missed_call_%s" % identifier))

	traffic_missed.emit(_slot_index, scenario)
	_advance_to_slot(_slot_index + 1)

## t0: the telegram's own signal ended. For routing scenarios the route
## deadline starts here, even if the operator is still finishing the copy; the
## deadline clock is the session's post-signal elapsed, shared with the commit
## deadline and the copy grace.
func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	if not enabled:
		return
	var scenario := _current_scenario()
	if scenario != null and scenario.requires_routing:
		_on_route_requested(scenario.expected_routing_action)

## copied_ is a fact about the paper, not the signal: the operator only knows a
## telegram once his hand physically reached its last glyph.
func _on_copy_finished(scenario_id: String) -> void:
	if not enabled or scenario_id.is_empty():
		return
	var knowledge := _knowledge_state()
	if knowledge != null:
		knowledge.learn(StringName("copied_%s" % scenario_id))

func _on_session_completed(_scenario: TelegraphScenarioData) -> void:
	if not enabled:
		return
	_advance_to_slot(_slot_index + 1)

func _on_routing_resolved(_action: String, outcome: TelegraphSessionController.RoutingOutcome) -> void:
	# A lapse is counted exactly once, here, whether it came from the route
	# deadline or from an unfinished copy closed by the grace.
	match outcome:
		TelegraphSessionController.RoutingOutcome.LAPSED:
			routes_defaulted += 1
		TelegraphSessionController.RoutingOutcome.INCORRECT:
			routes_misdirected += 1
		_:
			pass

## True when the night left something for the division to ask about.
func had_trouble() -> bool:
	return messages_missed > 0 or routes_defaulted > 0 or routes_misdirected > 0

func _on_route_requested(_expected_action: String) -> void:
	if _phase == Phase.AWAITING_ROUTE:
		return
	_nags_sent = 0
	_set_phase(Phase.AWAITING_ROUTE)
	route_deadline_started.emit(_slot_index, route_deadline_seconds)

func _on_verification_requested() -> void:
	var scenario := _current_scenario()
	if enabled and scenario != null and scenario.requires_routing:
		_on_route_requested(scenario.expected_routing_action)

func _maybe_nag() -> void:
	if route_nag_interval_seconds <= 0.0:
		return
	var due := int(_route_elapsed() / route_nag_interval_seconds)
	if due > _nags_sent and _route_elapsed() < route_deadline_seconds:
		_nags_sent = due
		_last_nag_elapsed = _route_elapsed()
		# A warning that just played in the same breath already told the
		# operator the sender is waiting; count this nag as delivered.
		if _last_warning_elapsed >= 0.0 \
				and absf(_route_elapsed() - _last_warning_elapsed) <= warning_nag_merge_seconds:
			return
		# The sender asks again on the wire rather than through an on-screen timer.
		_play_on_wire(call_sign)

## The deadline warning rides the same sounder the sender already uses. It never
## talks over an active telegram; if the line is busy it waits for a gap
## without buying the operator a single extra second. A nag in the same breath
## already said "the sender is waiting", so the two merge into one call.
func _on_deadline_warning(kind: StringName) -> void:
	if not enabled or (kind != TelegraphSessionController.WARNING_COMMIT and kind != TelegraphSessionController.WARNING_COPY_GRACE):
		return
	if not _warning_still_relevant():
		return
	if _nags_sent > 0 and _last_nag_elapsed >= 0.0 and session != null \
			and absf(session.get_post_signal_elapsed() - _last_nag_elapsed) <= warning_nag_merge_seconds:
		return
	if _wire_idle():
		_play_on_wire(call_sign)
		if session != null:
			_last_warning_elapsed = session.get_post_signal_elapsed()
	else:
		_pending_warning = kind

## A warning is only speakable while the deadline it describes still runs for
## the current slot. Resolutions, slot changes and closing all invalidate it.
func _warning_still_relevant() -> bool:
	if session == null:
		return false
	return session.get_state() in [TelegraphSessionController.State.COPYING, TelegraphSessionController.State.VERIFYING, TelegraphSessionController.State.AWAITING_COMMIT]

func _wire_idle() -> bool:
	return session == null or session.scheduler == null or not session.scheduler.is_playing()

func _default_route() -> void:
	var scenario := _current_scenario()
	route_defaulted.emit(_slot_index, scenario)
	if session != null:
		# "NO ORDER" resolves as its own outcome — the counter and lapse facts
		# come back through routing_resolved, exactly once.
		session.lapse_routing(default_route_action)

func _begin_closing() -> void:
	_slot_index = _scenario_count()
	_pending_warning = &""
	# Closing is a stage boundary like any other: 05:18, reached at the same
	# bounded speed, never a final tween from wherever the hands happen to be.
	_station_target_hours = maxf(_station_target_hours, STATION_CLOSING_HOURS)
	_station_ceiling_hours = STATION_CLOSING_HOURS
	_set_phase(Phase.CLOSING)
	_play_on_wire(closing_sign_trouble if had_trouble() else closing_sign)

func _set_phase(new_phase: Phase) -> void:
	if _phase == new_phase:
		return
	var previous := _phase
	_phase = new_phase
	_phase_timer = 0.0
	_apply_key_state()
	phase_changed.emit(_phase, previous)
	if _phase == Phase.SHIFT_OVER:
		# 06:00 is the last target: the hands keep their bounded speed and stop
		# there on their own; the shift does not wait for them and they do not
		# wait for the player.
		_station_target_hours = STATION_SHIFT_OVER_HOURS
		_station_ceiling_hours = STATION_SHIFT_OVER_HOURS
		shift_closed.emit()

func _apply_key_state() -> void:
	if not enabled or session == null:
		return
	var key := session.telegraph_key
	if key == null:
		return

	# The key is worked from the chair. Standing at the desk is not working.
	if seat != null and not seat.is_seated and _phase in [Phase.PRE_SHIFT, Phase.CALLING]:
		key.set_prompt_message(PROMPT_NOT_SEATED)
		key.set_enabled(false)
		_apply_urgency()
		return

	match _phase:
		Phase.PRE_SHIFT:
			key.set_prompt_message(PROMPT_OPEN_LINE)
			key.set_enabled(true)
		Phase.WAITING:
			key.set_prompt_message(PROMPT_LINE_QUIET)
			key.set_enabled(false)
		Phase.CALLING:
			key.set_prompt_message(PROMPT_ANSWER_CALL)
			key.set_enabled(true)
		Phase.RECEIVING, Phase.AWAITING_ROUTE:
			_apply_key_state_for_session(key)
		Phase.CLOSING:
			key.set_prompt_message(PROMPT_CLOSING)
			key.set_enabled(false)
		Phase.SHIFT_OVER:
			key.set_prompt_message(PROMPT_SHIFT_OVER)
			key.set_enabled(false)
	_apply_urgency()

## While a message is being worked, the session's state — not the director's
## phase — is what the operator can actually see and do. The key is never an
## available action in any of these states; it reports.
func _apply_key_state_for_session(key: TelegraphKey) -> void:
	key.set_enabled(false)
	if session == null:
		key.set_prompt_message(PROMPT_RECEIVING)
		return
	match session.get_state():
		TelegraphSessionController.State.RECEIVING:
			key.set_prompt_message(PROMPT_RECEIVING)
		TelegraphSessionController.State.COPYING:
			key.set_prompt_message(PROMPT_FINISHING_COPY)
		TelegraphSessionController.State.VERIFYING:
			key.set_prompt_message(PROMPT_READ_COPY)
		TelegraphSessionController.State.AWAITING_ROUTE:
			key.set_prompt_message(PROMPT_AWAITING_ROUTE)
		TelegraphSessionController.State.AWAITING_COMMIT:
			key.set_prompt_message(PROMPT_FILE_COPY)
		TelegraphSessionController.State.CONSEQUENCE:
			key.set_prompt_message(PROMPT_STAND_BY)
		_:
			key.set_prompt_message(PROMPT_LINE_QUIET)

## While the wire is calling, Elias is hurrying. The camera carries a little of it.
func _apply_urgency() -> void:
	if office == null or office.player == null:
		return
	office.player.set_urgency(1.0 if _phase == Phase.CALLING else 0.0)

func _scenario_count() -> int:
	if office == null:
		return 0
	return office.get_scenario_list().size()

func _current_scenario() -> TelegraphScenarioData:
	if office == null:
		return null
	var list := office.get_scenario_list()
	if _slot_index < 0 or _slot_index >= list.size():
		return null
	return list[_slot_index]

static func _scenario_identifier(scenario: TelegraphScenarioData) -> String:
	if scenario == null:
		return "unknown"
	if not scenario.scenario_id.is_empty():
		return scenario.scenario_id
	return "unnamed"

func _world_state() -> WorldStateStore:
	if session != null and session.world_state != null:
		return session.world_state
	return _find_autoload("WorldState") as WorldStateStore

func _knowledge_state() -> KnowledgeStateStore:
	return _find_autoload("KnowledgeState") as KnowledgeStateStore

func _find_autoload(node_name: String) -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var store := tree.root.get_node_or_null(node_name)
			if store != null:
				return store
	var current: Node = get_parent()
	while current != null:
		var store := current.get_node_or_null(node_name)
		if store != null:
			return store
		current = current.get_parent()
	return null
