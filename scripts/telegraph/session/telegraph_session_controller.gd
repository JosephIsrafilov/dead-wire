class_name TelegraphSessionController
extends Node

enum State {
	IDLE,
	READY,
	RECEIVING,
	VERIFYING,
	AWAITING_ROUTE,
	AWAITING_COMMIT,
	CONSEQUENCE,
	COMPLETE
}

signal session_state_changed(new_state: State, previous_state: State)
signal scenario_loaded(scenario: TelegraphScenarioData)
signal transmission_started(scenario: TelegraphScenarioData)
signal transmission_finished(scenario: TelegraphScenarioData)
signal verification_requested()
signal routing_requested(expected_action: String)
signal routing_resolved(action_taken: String, is_correct: bool)
signal commit_requested(options: Array[TelegraphCommitOption])
signal commit_resolved(action_id: StringName, result_text: String)
signal consequence_started(event_id: String, hold_seconds: float)
signal session_completed(scenario: TelegraphScenarioData)
signal attention_event_triggered(event_id: String)

@export var alphabet: AmericanMorseAlphabetData = preload("res://data/morse/m1_american_morse_alphabet.tres")
@export var playback_profile: MorsePlaybackProfileData = preload("res://data/morse/m1_morse_playback_profile.tres")
@export var scheduler: MorseRuntimeScheduler = null
@export var sounder: SounderController = null
@export var telegraph_key: TelegraphKey = null
@export var transcript_paper: TranscriptPaper = null
@export var world_state: WorldStateStore = null
## A commit scenario cannot strand the shift forever if the player walks away.
## Zero disables the deadline for authored experiments.
@export var commit_deadline_seconds: float = 30.0
## Maximum extra wait when a consequence figure remains pending in the watched
## camera. This keeps an inattentive player from stranding shift progression.
@export var consequence_visibility_timeout_seconds: float = 6.0

## When a ShiftDirector is running the night, the wire decides when a message
## arrives and the key means "answer the call". Clearing this hands ownership of
## the key to the director so the operator cannot start his own traffic early.
@export var allow_key_start: bool = true

var _state: State = State.IDLE
var _current_scenario: TelegraphScenarioData = null
var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()
var _attention_event_fired: bool = false
var _transcript_verified: bool = false
var _commit_resolved: bool = false
var _commit_elapsed: float = 0.0
var _consequence_elapsed: float = 0.0
var _consequence_started: bool = false
var _consequence_requires_visibility: bool = false
var _consequence_visible: bool = false
var _consequence_visibility_timeout: float = 0.0

const LAPSED_ACTION_ID: StringName = &"lapsed"
const LAPSED_RESULT_TEXT: String = "UNFILED"

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

	if telegraph_key != null:
		if not telegraph_key.key_pressed.is_connected(_on_key_pressed):
			telegraph_key.key_pressed.connect(_on_key_pressed)

	if transcript_paper != null:
		if not transcript_paper.transcript_inspected.is_connected(_on_transcript_inspected):
			transcript_paper.transcript_inspected.connect(_on_transcript_inspected)

func _process(delta: float) -> void:
	if _state == State.CONSEQUENCE:
		advance_consequence(delta)
	elif _state in [State.VERIFYING, State.AWAITING_COMMIT] and not _commit_resolved and _has_commit_options() and commit_deadline_seconds > 0.0:
		_commit_elapsed += maxf(delta, 0.0)
		if _commit_elapsed >= commit_deadline_seconds:
			lapse_commit()

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
	_commit_elapsed = 0.0
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

	# Elias starts writing as the signal starts arriving, not after it ends.
	if transcript_paper != null:
		transcript_paper.begin_writing(
			_current_scenario.transmission_data.written_transcript,
			_current_scenario.transcript_reveal_cues
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

func _on_scheduler_completed(_schedule: MorsePlaybackScheduleData) -> void:
	if _state != State.RECEIVING or _current_scenario == null:
		return

	# Fallback check for attention event before completion
	if not _current_scenario.attention_event_id.is_empty() and _current_scenario.consequence_event_id != _current_scenario.attention_event_id and not _attention_event_fired:
		_attention_event_fired = true
		attention_event_triggered.emit(_current_scenario.attention_event_id)

	transmission_finished.emit(_current_scenario)

	# Pass written transcript to paper
	if transcript_paper != null:
		transcript_paper.set_transcript_text(_current_scenario.transmission_data.written_transcript)
		transcript_paper.reveal_transcript()

	if _current_scenario.requires_transcript_verification:
		_commit_elapsed = 0.0
		_set_state(State.VERIFYING)
		verification_requested.emit()
	elif _current_scenario.requires_routing:
		_set_state(State.AWAITING_ROUTE)
		routing_requested.emit(_current_scenario.expected_routing_action)
	else:
		_record_completion_fact()
		_set_state(State.COMPLETE)
		session_completed.emit(_current_scenario)

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
		_set_state(State.COMPLETE)
		session_completed.emit(_current_scenario)
	return true

func get_commit_options() -> Array[TelegraphCommitOption]:
	if _current_scenario == null:
		return []
	return _current_scenario.commit_options

## Files one authored commit option exactly once. Unknown and out-of-order input
## are deliberately no-ops so a stale control cannot alter WorldState.
func submit_commit(action_id: StringName) -> bool:
	if _state != State.AWAITING_COMMIT or _current_scenario == null or _commit_resolved:
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
	if _state not in [State.VERIFYING, State.AWAITING_COMMIT] or _current_scenario == null or _commit_resolved or not _has_commit_options():
		return false
	_commit_resolved = true
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
	if _state == State.CONSEQUENCE and _consequence_started:
		_consequence_visible = true

func notify_consequence_expired() -> void:
	if _state == State.CONSEQUENCE and _consequence_started and _consequence_visible:
		_complete_consequence()

## Advances the delayed event and observable hold. Runtime uses _process; tests
## and a deadline owner can drive this method deterministically.
func advance_consequence(delta: float) -> void:
	if _state != State.CONSEQUENCE or delta < 0.0:
		return
	_consequence_elapsed += delta
	var delay := _current_scenario.consequence_delay_seconds if _current_scenario != null else 0.0
	var hold := _current_scenario.consequence_hold_seconds if _current_scenario != null else 0.0
	if not _consequence_started and _consequence_elapsed >= delay:
		_consequence_started = true
		_consequence_visibility_timeout = delay + hold + maxf(consequence_visibility_timeout_seconds, 0.0)
		consequence_started.emit(_current_scenario.consequence_event_id, hold)
	if _consequence_started and _consequence_requires_visibility and not _consequence_visible and _consequence_elapsed >= _consequence_visibility_timeout:
		_complete_consequence()
	elif _consequence_started and (not _consequence_requires_visibility or _consequence_visible) and _consequence_elapsed >= delay + hold:
		_complete_consequence()

func _complete_consequence() -> void:
	if _state != State.CONSEQUENCE or _current_scenario == null:
		return
	_set_state(State.COMPLETE)
	session_completed.emit(_current_scenario)

func submit_routing_decision(action: String) -> bool:
	if _state != State.AWAITING_ROUTE or _current_scenario == null:
		return false

	var is_correct := (action == _current_scenario.expected_routing_action)
	var world := _get_world_state()

	if is_correct:
		if world != null and not _current_scenario.correct_world_fact.is_empty():
			world.set_fact(StringName(_current_scenario.correct_world_fact), true)
	else:
		if world != null and not _current_scenario.incorrect_world_fact.is_empty():
			world.set_fact(StringName(_current_scenario.incorrect_world_fact), true)

	routing_resolved.emit(action, is_correct)
	_record_completion_fact()
	_set_state(State.COMPLETE)
	session_completed.emit(_current_scenario)
	return true

func reset_session() -> void:
	if scheduler != null:
		scheduler.cancel()
		scheduler.reset()

	if transcript_paper != null:
		transcript_paper.clear_transcript()

	_current_scenario = null
	_attention_event_fired = false
	_transcript_verified = false
	_commit_resolved = false
	_commit_elapsed = 0.0
	_consequence_elapsed = 0.0
	_consequence_started = false
	_consequence_requires_visibility = false
	_consequence_visible = false
	_consequence_visibility_timeout = 0.0
	_set_state(State.IDLE)

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

func _on_transcript_inspected(_text: String) -> void:
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
