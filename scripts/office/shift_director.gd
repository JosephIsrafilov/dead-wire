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

## Telegrapher's sign-off, sent once the night's traffic is done. A clean watch
## gets good night. A watch with a hole in it gets asked where the train is —
## which is the objective world answering, not Elias's own record of himself.
@export var closing_sign: String = "GN"
@export var closing_sign_trouble: String = "OS 17"
@export var closing_delay_seconds: float = 4.0

const PROMPT_OPEN_LINE: String = "Open the Line (Begin Shift)"
const PROMPT_LINE_QUIET: String = "Line Quiet"
const PROMPT_ANSWER_CALL: String = "Answer the Call"
const PROMPT_RECEIVING: String = "Line Busy (Receiving)"
const PROMPT_AWAITING_ROUTE: String = "Sender Waiting — Set the Route"
const PROMPT_CLOSING: String = "Line Closing"
const PROMPT_SHIFT_OVER: String = "Line Closed — Shift Over"
const PROMPT_NOT_SEATED: String = "Sit to Work the Key"

var _phase: Phase = Phase.PRE_SHIFT
var _slot_index: int = -1
var _phase_timer: float = 0.0
var _calls_sent: int = 0
var _call_window_seconds: float = 0.0
var _nags_sent: int = 0
var _lapsed_slot: int = -1
var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()

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
		# The wire owns the key from here on.
		session.allow_key_start = false
		if not session.transmission_finished.is_connected(_on_transmission_finished):
			session.transmission_finished.connect(_on_transmission_finished)
		if not session.session_completed.is_connected(_on_session_completed):
			session.session_completed.connect(_on_session_completed)
		if not session.routing_requested.is_connected(_on_route_requested):
			session.routing_requested.connect(_on_route_requested)
		if not session.routing_resolved.is_connected(_on_routing_resolved):
			session.routing_resolved.connect(_on_routing_resolved)

		var key := session.telegraph_key
		if key != null and not key.key_pressed.is_connected(_on_key_pressed):
			key.key_pressed.connect(_on_key_pressed)

	_apply_key_state()

## Re-applies the key prompt. The seat calls this when the operator sits or stands.
func refresh_key_state() -> void:
	_apply_key_state()

func is_operator_seated() -> bool:
	return seat != null and seat.is_seated

func get_phase() -> Phase:
	return _phase

func get_slot_index() -> int:
	return _slot_index

func get_phase_timer() -> float:
	return _phase_timer

func is_shift_over() -> bool:
	return _phase == Phase.SHIFT_OVER

## Seconds left on the routing deadline, or -1.0 when no deadline is running.
func get_route_seconds_remaining() -> float:
	if _phase != Phase.AWAITING_ROUTE:
		return -1.0
	return maxf(0.0, route_deadline_seconds - _phase_timer)

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
			if _phase_timer >= route_deadline_seconds:
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
	_advance_to_slot(0)
	return true

func _advance_to_slot(index: int) -> void:
	var scenarios := _scenario_count()
	if index >= scenarios:
		_begin_closing()
		return

	_slot_index = index
	_calls_sent = 0
	_nags_sent = 0
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

func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	if not enabled:
		return
	var scenario := _current_scenario()
	if scenario != null:
		var knowledge := _knowledge_state()
		if knowledge != null:
			knowledge.learn(StringName("copied_%s" % _scenario_identifier(scenario)))

func _on_session_completed(_scenario: TelegraphScenarioData) -> void:
	if not enabled:
		return
	var scenario := _current_scenario()
	if scenario != null and scenario.requires_routing:
		var knowledge := _knowledge_state()
		if knowledge != null:
			var identifier := _scenario_identifier(scenario)
			if _lapsed_slot == _slot_index:
				knowledge.learn(StringName("lapsed_%s" % identifier))
			else:
				knowledge.learn(StringName("filed_%s" % identifier))
	_advance_to_slot(_slot_index + 1)

func _on_routing_resolved(action: String, is_correct: bool) -> void:
	if not is_correct and action != default_route_action:
		routes_misdirected += 1

## True when the night left something for the division to ask about.
func had_trouble() -> bool:
	return messages_missed > 0 or routes_defaulted > 0 or routes_misdirected > 0

func _on_route_requested(_expected_action: String) -> void:
	_nags_sent = 0
	_set_phase(Phase.AWAITING_ROUTE)
	route_deadline_started.emit(_slot_index, route_deadline_seconds)

func _maybe_nag() -> void:
	if route_nag_interval_seconds <= 0.0:
		return
	var due := int(_phase_timer / route_nag_interval_seconds)
	if due > _nags_sent and _phase_timer < route_deadline_seconds:
		_nags_sent = due
		# The sender asks again on the wire rather than through an on-screen timer.
		_play_on_wire(call_sign)

func _default_route() -> void:
	var scenario := _current_scenario()
	routes_defaulted += 1
	_lapsed_slot = _slot_index
	route_defaulted.emit(_slot_index, scenario)
	if session != null:
		# Not a valid action, so it lands as an incorrect decision and its
		# consequence goes into WorldState. The shift moves on either way.
		session.submit_routing_decision(default_route_action)

func _begin_closing() -> void:
	_slot_index = _scenario_count()
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
		Phase.RECEIVING:
			key.set_prompt_message(PROMPT_RECEIVING)
			key.set_enabled(false)
		Phase.AWAITING_ROUTE:
			key.set_prompt_message(PROMPT_AWAITING_ROUTE)
			key.set_enabled(false)
		Phase.CLOSING:
			key.set_prompt_message(PROMPT_CLOSING)
			key.set_enabled(false)
		Phase.SHIFT_OVER:
			key.set_prompt_message(PROMPT_SHIFT_OVER)
			key.set_enabled(false)
	_apply_urgency()

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
