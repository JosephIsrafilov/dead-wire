class_name TelegraphSessionController
extends Node

enum State {
	IDLE,
	READY,
	RECEIVING,
	COPYING,
	VERIFYING,
	AWAITING_ROUTE,
	AWAITING_COMMIT,
	CONSEQUENCE,
	COMPLETE
}

## A route outcome is an event, not a boolean. "NO ORDER" is not a wrong order.
enum RoutingOutcome {
	CORRECT,
	INCORRECT,
	LAPSED,
}

signal session_state_changed(new_state: State, previous_state: State)
signal scenario_loaded(scenario: TelegraphScenarioData)
signal transmission_started(scenario: TelegraphScenarioData)
## t0: the objective signal of the active telegram ended. Exactly once.
signal transmission_finished(scenario: TelegraphScenarioData)
## The last glyph of this sheet was physically written. Exactly once.
signal copy_finished(scenario_id: String)
signal verification_requested()
signal routing_requested(expected_action: String)
signal routing_resolved(action_taken: String, outcome: RoutingOutcome)
signal commit_requested(options: Array[TelegraphCommitOption])
signal commit_resolved(action_id: StringName, result_text: String)
signal consequence_started(event_id: String, hold_seconds: float)
signal session_completed(scenario: TelegraphScenarioData)
signal attention_event_triggered(event_id: String)
signal deadline_warning(kind: StringName)

@export var alphabet: AmericanMorseAlphabetData = preload("res://data/morse/m1_american_morse_alphabet.tres")
@export var playback_profile: MorsePlaybackProfileData = preload("res://data/morse/m1_morse_playback_profile.tres")
@export var scheduler: MorseRuntimeScheduler = null
@export var sounder: SounderController = null
@export var telegraph_key: TelegraphKey = null
@export var transcript_paper: TranscriptPaper = null
@export var tape_register: TapeRegisterController = null
@export var world_state: WorldStateStore = null
## A commit scenario cannot strand the shift forever if the player walks away.
## Zero disables the deadline for authored experiments.
## Runs from t0 (end of the objective signal) through COPYING, VERIFYING and
## AWAITING_COMMIT; inspection never restarts or extends it.
@export var commit_deadline_seconds: float = 30.0
## If the sheet is still unfinished at t0, the sender releases the line after
## this many seconds. Cancelled the moment the copy physically completes.
## Zero disables the grace for authored experiments.
@export var unfinished_copy_grace_seconds: float = 20.0
## One warning before a deadline expires, so the limit is felt rather than
## discovered post factum. Zero disables the respective warning.
@export var commit_warning_seconds: float = 10.0
@export var copy_grace_warning_seconds: float = 5.0
## Maximum extra wait when a consequence figure remains pending in the watched
## camera. This keeps an inattentive player from stranding shift progression.
@export var consequence_visibility_timeout_seconds: float = 6.0

## When a ShiftDirector is running the night, the wire decides when a message
## arrives and the key means "answer the call". Clearing this hands ownership of
## the key to the director so the operator cannot start his own traffic early.
@export var allow_key_start: bool = true

const LAPSED_ACTION_ID: StringName = &"lapsed"
const LAPSED_RESULT_TEXT: String = "UNFILED"
const WARNING_COMMIT: StringName = &"commit"
const WARNING_COPY_GRACE: StringName = &"copy_grace"

var _state: State = State.IDLE
var _current_scenario: TelegraphScenarioData = null
var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()
var _attention_event_fired: bool = false
var _transcript_verified: bool = false
var _commit_resolved: bool = false
var _consequence_elapsed: float = 0.0
var _consequence_started: bool = false
var _consequence_requires_visibility: bool = false
var _consequence_visible: bool = false
var _consequence_visible_elapsed: float = 0.0
var _consequence_visibility_timeout: float = 0.0

## The compiled schedule of the active telegram. Service signals (calls, nags,
## closing) run on the same scheduler; their completion must never be mistaken
## for the telegram ending.
var _active_schedule: MorsePlaybackScheduleData = null
## Seconds since t0, advanced exactly once per simulation tick. Negative means
## the signal has not ended. Commit deadline, grace and the director's route
## deadline all read this one clock so there is a single t0.
var _post_signal_elapsed: float = -1.0
var _grace_active: bool = false
## One deadline warning per scenario, whichever threshold comes first: an
## unfinished-copy grace warning replaces the later commit warning, exactly as
## the plan requires. Inspect, resume and stand/return never re-arm it.
var _deadline_warning_fired: bool = false

func _ready() -> void:
	_bind_components()

func _bind_components() -> void:
	if scheduler != null:
		if not scheduler.playback_completed.is_connected(_on_scheduler_completed):
			scheduler.playback_completed.connect(_on_scheduler_completed)
		if not scheduler.playback_time_advanced.is_connected(_on_playback_time_advanced):
			scheduler.playback_time_advanced.connect(_on_playback_time_advanced)

	if sounder != null and scheduler != null:
		sounder.connect_scheduler(scheduler)

	if get_tape_register() != null and scheduler != null:
		tape_register.connect_scheduler(scheduler)

	if telegraph_key != null:
		if not telegraph_key.key_pressed.is_connected(_on_key_pressed):
			telegraph_key.key_pressed.connect(_on_key_pressed)

	if transcript_paper != null:
		if not transcript_paper.transcript_inspected.is_connected(_on_transcript_inspected):
			transcript_paper.transcript_inspected.connect(_on_transcript_inspected)
		if not transcript_paper.copy_finished.is_connected(_on_paper_copy_finished):
			transcript_paper.copy_finished.connect(_on_paper_copy_finished)

func get_tape_register() -> TapeRegisterController:
	if tape_register == null:
		tape_register = get_node_or_null("TapeRegister") as TapeRegisterController
	return tape_register

func _process(delta: float) -> void:
	if _state == State.CONSEQUENCE:
		advance_consequence(delta)
	elif _post_signal_elapsed >= 0.0 and _state in [State.COPYING, State.VERIFYING, State.AWAITING_ROUTE, State.AWAITING_COMMIT]:
		advance_post_signal(delta)

## The single post-signal clock: grace, commit deadline, the director's route
## deadline and warnings all read this. Public so a deadline owner or a test
## can drive it deterministically.
func advance_post_signal(delta: float) -> void:
	if _post_signal_elapsed < 0.0 or delta < 0.0:
		return
	_post_signal_elapsed += maxf(delta, 0.0)

	# Unfinished-copy grace: cancelled the instant the copy completes, so it
	# only ticks while the sheet is still open.
	if _state == State.COPYING and _grace_active:
		if not _deadline_warning_fired \
				and unfinished_copy_grace_seconds > 0.0 and copy_grace_warning_seconds >= 0.0 \
				and _post_signal_elapsed >= unfinished_copy_grace_seconds - copy_grace_warning_seconds:
			_deadline_warning_fired = true
			deadline_warning.emit(WARNING_COPY_GRACE)
		if unfinished_copy_grace_seconds > 0.0 and _post_signal_elapsed >= unfinished_copy_grace_seconds:
			_close_incomplete_copy()
			return

	# Commit deadline. One warning per scenario: if the grace warning already
	# spoke, this stays silent and the deadline itself still runs.
	if _has_commit_options() and not _commit_resolved and commit_deadline_seconds > 0.0:
		if not _deadline_warning_fired and commit_warning_seconds > 0.0 \
				and _post_signal_elapsed >= commit_deadline_seconds - commit_warning_seconds:
			_deadline_warning_fired = true
			deadline_warning.emit(WARNING_COMMIT)
		if _post_signal_elapsed >= commit_deadline_seconds:
			lapse_commit()

## Status line for guidance while a deadline warning is live. Empty otherwise.
func get_deadline_warning_text() -> String:
	if not _deadline_warning_fired:
		return ""
	if _state == State.COPYING and _grace_active:
		return "Finish the copy — the sender is waiting"
	if not _commit_resolved and _has_commit_options() \
			and commit_deadline_seconds > 0.0 and _post_signal_elapsed < commit_deadline_seconds \
			and _state in [State.COPYING, State.VERIFYING, State.AWAITING_COMMIT]:
		return "The sender is about to release the line"
	return ""

func get_post_signal_elapsed() -> float:
	return _post_signal_elapsed

func get_state() -> State:
	return _state

func get_current_scenario() -> TelegraphScenarioData:
	return _current_scenario

func load_scenario(scenario: TelegraphScenarioData) -> bool:
	if scenario == null:
		return false
	var errs: PackedStringArray = scenario.get_validation_errors()
	if not errs.is_empty():
		return false

	_bind_components()
	reset_session()
	_current_scenario = scenario
	_attention_event_fired = false
	_transcript_verified = false
	_commit_resolved = false
	_consequence_elapsed = 0.0
	_consequence_started = false
	_consequence_requires_visibility = false
	_consequence_visible = false
	_consequence_visibility_timeout = 0.0
	_set_state(State.READY)
	scenario_loaded.emit(_current_scenario)
	return true

func start_transmission() -> bool:
	if _state != State.READY or _current_scenario == null:
		return false

	if alphabet == null or playback_profile == null:
		return false

	# 1. Encode true message
	var seq: MorseSequenceData = _encoder.encode(_current_scenario.transmission_data.true_message, alphabet)
	if seq == null:
		return false

	# 2. Compile schedule
	var sched: MorsePlaybackScheduleData = _compiler.compile(seq, playback_profile)
	if sched == null:
		return false

	# 3. Start scheduler
	if scheduler == null:
		return false

	if not scheduler.start(sched):
		return false
	# Ownership: only this schedule's completion is the telegram ending.
	_active_schedule = sched

	# Elias starts writing as the signal starts arriving, not after it ends.
	if transcript_paper != null:
		transcript_paper.begin_writing(
			_current_scenario.transmission_data.written_transcript,
			_current_scenario.transcript_reveal_cues,
			_current_scenario.scenario_id
		)

	_set_state(State.RECEIVING)
	transmission_started.emit(_current_scenario)
	return true

func _on_playback_time_advanced(prev_time: float, curr_time: float) -> void:
	if _state == State.RECEIVING and transcript_paper != null and scheduler != null:
		var total := scheduler.get_total_duration_seconds()
		if total > 0.0:
			transcript_paper.set_writing_progress(curr_time / total)

	if _state == State.RECEIVING and _current_scenario != null:
		# A consequence event with the same id is intentionally deferred until the
		# player has inspected and resolved the transcript.
		if not _current_scenario.consequence_event_id.is_empty() and _current_scenario.attention_event_id == _current_scenario.consequence_event_id:
			return
		if not _current_scenario.attention_event_id.is_empty() and not _attention_event_fired:
			var target_time: float = _current_scenario.attention_event_start_time
			if prev_time < target_time + 0.00001 and curr_time >= target_time - 0.00001:
				_attention_event_fired = true
				attention_event_triggered.emit(_current_scenario.attention_event_id)

func _on_scheduler_completed(schedule: MorsePlaybackScheduleData) -> void:
	# Only the active telegram's own schedule ends the telegram. Calls, nags and
	# the closing sign run on the same scheduler; their end is not t0.
	if schedule != _active_schedule:
		return
	if _state != State.RECEIVING or _current_scenario == null:
		return
	_active_schedule = null

	# Fallback check for attention event before completion
	if not _current_scenario.attention_event_id.is_empty() and _current_scenario.consequence_event_id != _current_scenario.attention_event_id and not _attention_event_fired:
		_attention_event_fired = true
		attention_event_triggered.emit(_current_scenario.attention_event_id)

	# t0: the objective signal is over. The sheet keeps whatever ink it has;
	# the sender's clock starts now and is never restarted or extended.
	transmission_finished.emit(_current_scenario)
	_post_signal_elapsed = 0.0
	_deadline_warning_fired = false
	if transcript_paper != null and transcript_paper.get_paper_scenario_id() == _current_scenario.scenario_id:
		# Lock availability to the full message: whatever the scheduler's last
		# callback missed is authorized now.
		transcript_paper.set_writing_progress(1.0)

	if _is_copy_complete():
		_enter_post_copy_state()
	else:
		_grace_active = unfinished_copy_grace_seconds > 0.0
		_set_state(State.COPYING)

func _is_copy_complete() -> bool:
	return transcript_paper == null or not transcript_paper.is_copy_in_progress()

func _enter_post_copy_state() -> void:
	_grace_active = false
	if _current_scenario == null:
		return
	if _current_scenario.requires_transcript_verification:
		_set_state(State.VERIFYING)
		verification_requested.emit()
	elif _current_scenario.requires_routing:
		_set_state(State.AWAITING_ROUTE)
		routing_requested.emit(_current_scenario.expected_routing_action)
	else:
		_record_completion_fact()
		_finish_session()

## The sheet physically reached its last glyph. If the signal already ended, the
## session leaves COPYING; if it is still playing, the deadline clock still
## starts only at t0. Stale sheets from previous scenarios are no-ops.
func _on_paper_copy_finished(scenario_id: String) -> void:
	if _current_scenario == null or scenario_id != _current_scenario.scenario_id:
		return
	copy_finished.emit(scenario_id)
	_grace_active = false
	if _state == State.COPYING:
		_enter_post_copy_state()

## Grace ran out on an unfinished sheet: close it, record the honest partial
## state, and resolve the scenario through the same lapse paths a deadline uses.
func _close_incomplete_copy() -> void:
	_grace_active = false
	_close_live_sheet_for_terminal()
	if _current_scenario == null:
		return
	if _current_scenario.requires_routing:
		lapse_routing()
	elif _has_commit_options():
		lapse_commit()

## Any terminal resolution closes a still-live sheet as an honest partial with
## its fact recorded. Complete sheets are untouched.
func _close_live_sheet_for_terminal() -> void:
	if transcript_paper == null or not transcript_paper.is_copy_in_progress():
		return
	if _current_scenario == null or transcript_paper.get_paper_scenario_id() != _current_scenario.scenario_id:
		return
	transcript_paper.close_incomplete()
	var knowledge := _get_knowledge_state()
	if knowledge != null:
		knowledge.learn(StringName("incomplete_copy_%s" % _current_scenario.scenario_id))

## Records the player's inspection of the finished transcript. Decisions are not
## exposed until this method succeeds, and the gate can only be passed once.
func mark_transcript_verified() -> bool:
	if _state != State.VERIFYING or _transcript_verified or _current_scenario == null:
		return false
	_transcript_verified = true
	if _current_scenario.requires_routing:
		_set_state(State.AWAITING_ROUTE)
		routing_requested.emit(_current_scenario.expected_routing_action)
	elif not _current_scenario.commit_options.is_empty():
		_set_state(State.AWAITING_COMMIT)
		commit_requested.emit(_current_scenario.commit_options)
	else:
		_record_completion_fact()
		_finish_session()
	return true

func get_commit_options() -> Array[TelegraphCommitOption]:
	if _current_scenario == null:
		return []
	return _current_scenario.commit_options

## Files one authored commit option exactly once. Unknown input, out-of-order
## input and input after the deadline has expired are deliberately no-ops so a
## stale control cannot alter WorldState.
func submit_commit(action_id: StringName) -> bool:
	if _state != State.AWAITING_COMMIT or _current_scenario == null or _commit_resolved:
		return false
	if _is_commit_deadline_expired():
		return false
	var selected: TelegraphCommitOption = null
	for option in _current_scenario.commit_options:
		if option != null and option.action_id == action_id:
			selected = option
			break
	if selected == null:
		return false
	_commit_resolved = true
	var world := _get_world_state()
	if world != null:
		world.set_fact(StringName(selected.world_fact), true)
	var knowledge := _get_knowledge_state()
	if knowledge != null:
		knowledge.learn(StringName(selected.knowledge_fact))
	_record_completion_fact()
	_set_state(State.CONSEQUENCE)
	commit_resolved.emit(selected.action_id, selected.result_text)
	_begin_consequence()
	return true

## Explicit timeout path. It records lapsed facts without selecting either
## authored version, then uses the same neutral consequence beat.
func lapse_commit() -> bool:
	if _state not in [State.COPYING, State.VERIFYING, State.AWAITING_COMMIT] or _current_scenario == null or _commit_resolved or not _has_commit_options():
		return false
	_commit_resolved = true
	_close_live_sheet_for_terminal()
	var world := _get_world_state()
	if world != null and not _current_scenario.commit_lapsed_world_fact.is_empty():
		world.set_fact(StringName(_current_scenario.commit_lapsed_world_fact), true)
	var knowledge := _get_knowledge_state()
	if knowledge != null and not _current_scenario.commit_lapsed_knowledge_fact.is_empty():
		knowledge.learn(StringName(_current_scenario.commit_lapsed_knowledge_fact))
	_record_completion_fact()
	_set_state(State.CONSEQUENCE)
	commit_resolved.emit(LAPSED_ACTION_ID, LAPSED_RESULT_TEXT)
	_begin_consequence()
	return true

func _is_commit_deadline_expired() -> bool:
	return commit_deadline_seconds > 0.0 \
		and _post_signal_elapsed >= 0.0 \
		and _post_signal_elapsed >= commit_deadline_seconds \
		and _state in [State.COPYING, State.VERIFYING, State.AWAITING_COMMIT] \
		and _has_commit_options() and not _commit_resolved

func _begin_consequence() -> void:
	_consequence_elapsed = 0.0
	_consequence_started = false
	_consequence_visible = false
	_consequence_visibility_timeout = 0.0
	advance_consequence(0.0)

## Office presentation registers that this consequence has a real visible
## target. Without an observer (for example in logic-only tests), the legacy
## delay+hold path remains deterministic.
func set_consequence_visibility_required(required: bool) -> void:
	_consequence_requires_visibility = required

func notify_consequence_visible() -> void:
	if _state == State.CONSEQUENCE and _consequence_started and not _consequence_visible:
		_consequence_visible = true
		_consequence_visible_elapsed = 0.0

func notify_consequence_expired() -> void:
	if _state == State.CONSEQUENCE and _consequence_started and _consequence_visible:
		_complete_consequence()

## Advances the delayed event and observable hold. Runtime uses _process; tests
## and a deadline owner can drive this method deterministically.
func advance_consequence(delta: float) -> void:
	if _state != State.CONSEQUENCE or delta < 0.0:
		return
	_consequence_elapsed += delta
	if _consequence_visible:
		_consequence_visible_elapsed += delta
	var delay := _current_scenario.consequence_delay_seconds if _current_scenario != null else 0.0
	var hold := _current_scenario.consequence_hold_seconds if _current_scenario != null else 0.0
	if not _consequence_started and _consequence_elapsed >= delay:
		_consequence_started = true
		_consequence_visibility_timeout = delay + hold + maxf(consequence_visibility_timeout_seconds, 0.0)
		consequence_started.emit(_current_scenario.consequence_event_id, hold)
	if _consequence_started and _consequence_requires_visibility and not _consequence_visible and _consequence_elapsed >= _consequence_visibility_timeout:
		_complete_consequence()
	elif _consequence_started and ((_consequence_requires_visibility and _consequence_visible and _consequence_visible_elapsed >= hold) or (not _consequence_requires_visibility and _consequence_elapsed >= delay + hold)):
		_complete_consequence()

func _complete_consequence() -> void:
	if _state != State.CONSEQUENCE or _current_scenario == null:
		return
	_finish_session()

func _finish_session() -> void:
	# A completion listener may synchronously load the next scenario. Passing
	# the member itself lets later listeners see that replacement resource.
	var completed_scenario := _current_scenario
	_set_state(State.COMPLETE)
	session_completed.emit(completed_scenario)

## A deadline can close an unread order without pretending it was verified.
## "NO ORDER" is a distinct outcome: not correct, not incorrect.
func lapse_routing(action: String = "NO ORDER") -> bool:
	if _current_scenario == null or not _current_scenario.requires_routing or _state not in [State.COPYING, State.VERIFYING, State.AWAITING_ROUTE]:
		return false
	return _resolve_routing(action, true)

func submit_routing_decision(action: String) -> bool:
	if _state != State.AWAITING_ROUTE or _current_scenario == null:
		return false
	return _resolve_routing(action, false)

func _resolve_routing(action: String, is_lapse: bool) -> bool:
	var outcome: RoutingOutcome = RoutingOutcome.LAPSED if is_lapse \
		else (RoutingOutcome.CORRECT if action == _current_scenario.expected_routing_action else RoutingOutcome.INCORRECT)
	_close_live_sheet_for_terminal()
	var world := _get_world_state()

	match outcome:
		RoutingOutcome.CORRECT:
			if world != null and not _current_scenario.correct_world_fact.is_empty():
				world.set_fact(StringName(_current_scenario.correct_world_fact), true)
		RoutingOutcome.INCORRECT:
			if world != null and not _current_scenario.incorrect_world_fact.is_empty():
				world.set_fact(StringName(_current_scenario.incorrect_world_fact), true)
		RoutingOutcome.LAPSED:
			if world != null and not _current_scenario.routing_lapsed_world_fact.is_empty():
				world.set_fact(StringName(_current_scenario.routing_lapsed_world_fact), true)

	var knowledge := _get_knowledge_state()
	if knowledge != null:
		var identifier := _current_scenario.scenario_id
		if not is_lapse:
			# The journal records what was actually sent, not what was expected.
			if action == "CLEAR EAST":
				knowledge.learn(StringName("route_clear_east_%s" % identifier))
			elif action == "HOLD":
				knowledge.learn(StringName("route_hold_%s" % identifier))
			knowledge.learn(StringName("filed_%s" % identifier))
		elif not _current_scenario.routing_lapsed_knowledge_fact.is_empty():
			knowledge.learn(StringName(_current_scenario.routing_lapsed_knowledge_fact))

	routing_resolved.emit(action, outcome)
	_record_completion_fact()
	_finish_session()
	return true

func reset_session() -> void:
	# An abandoned live sheet closes as an honest partial rather than
	# vanishing. Terminal sheets are kept: the night's record is the paper on
	# the desk until the next telegram physically replaces it.
	if transcript_paper != null and transcript_paper.is_copy_in_progress():
		if _current_scenario != null:
			var knowledge := _get_knowledge_state()
			if knowledge != null:
				knowledge.learn(StringName("incomplete_copy_%s" % _current_scenario.scenario_id))
		transcript_paper.close_incomplete()
	_active_schedule = null
	_post_signal_elapsed = -1.0
	_grace_active = false
	_deadline_warning_fired = false

	if scheduler != null:
		scheduler.cancel()
		scheduler.reset()

	_current_scenario = null
	_attention_event_fired = false
	_transcript_verified = false
	_commit_resolved = false
	_consequence_elapsed = 0.0
	_consequence_started = false
	_consequence_requires_visibility = false
	_consequence_visible = false
	_consequence_visible_elapsed = 0.0
	_consequence_visibility_timeout = 0.0
	_set_state(State.IDLE)

## The operator stood up: the hand leaves the paper and the visible prefix
## freezes. The signal, deadlines and grace all keep running.
func notify_operator_stood() -> void:
	if transcript_paper == null or _current_scenario == null:
		return
	if transcript_paper.get_paper_scenario_id() == _current_scenario.scenario_id \
			and transcript_paper.is_copy_in_progress():
		transcript_paper.suspend()

## The operator is back in the chair and the sit transition finished: the hand
## re-enters and the backlog drains at a bounded rate. Deadlines are not reset.
func notify_operator_seated() -> void:
	if transcript_paper == null or _current_scenario == null:
		return
	if transcript_paper.get_paper_scenario_id() == _current_scenario.scenario_id \
			and transcript_paper.is_copy_paused():
		transcript_paper.resume_writing()

func _record_completion_fact() -> void:
	if _current_scenario != null and not _current_scenario.completion_fact.is_empty():
		var world := _get_world_state()
		if world != null:
			world.set_fact(StringName(_current_scenario.completion_fact), true)

func _has_commit_options() -> bool:
	return _current_scenario != null and not _current_scenario.commit_options.is_empty()

func _get_world_state() -> WorldStateStore:
	if world_state != null:
		return world_state
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var ws := tree.root.get_node_or_null("WorldState") as WorldStateStore
			if ws != null:
				return ws
	var curr: Node = get_parent()
	while curr != null:
		var ws := curr.get_node_or_null("WorldState") as WorldStateStore
		if ws != null:
			return ws
		curr = curr.get_parent()
	return null

func _get_knowledge_state() -> KnowledgeStateStore:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var knowledge := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
			if knowledge != null:
				return knowledge
	var curr: Node = get_parent()
	while curr != null:
		var knowledge := curr.get_node_or_null("KnowledgeState") as KnowledgeStateStore
		if knowledge != null:
			return knowledge
		curr = curr.get_parent()
	return null

## Inspection verifies the current scenario's finished sheet exactly once. A
## closed partial or a sheet from an earlier telegram reads, but never
## verifies, the session in progress.
func _on_transcript_inspected(_text: String) -> void:
	if transcript_paper == null or _current_scenario == null:
		return
	if transcript_paper.get_paper_scenario_id() != _current_scenario.scenario_id:
		return
	if not transcript_paper.is_ready_to_inspect():
		return
	mark_transcript_verified()

func _on_key_pressed() -> void:
	if not allow_key_start:
		return
	if _state == State.READY:
		start_transmission()

func _set_state(new_state: State) -> void:
	if _state != new_state:
		var prev := _state
		_state = new_state
		session_state_changed.emit(_state, prev)
