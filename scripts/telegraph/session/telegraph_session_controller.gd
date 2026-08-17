class_name TelegraphSessionController
extends Node

enum State {
	IDLE,
	READY,
	RECEIVING,
	AWAITING_ROUTE,
	COMPLETE
}

signal session_state_changed(new_state: State, previous_state: State)
signal scenario_loaded(scenario: TelegraphScenarioData)
signal transmission_started(scenario: TelegraphScenarioData)
signal transmission_finished(scenario: TelegraphScenarioData)
signal routing_requested(expected_action: String)
signal routing_resolved(action_taken: String, is_correct: bool)
signal session_completed(scenario: TelegraphScenarioData)
signal attention_event_triggered(event_id: String)

@export var alphabet: AmericanMorseAlphabetData = preload("res://data/morse/m1_american_morse_alphabet.tres")
@export var playback_profile: MorsePlaybackProfileData = preload("res://data/morse/m1_morse_playback_profile.tres")
@export var scheduler: MorseRuntimeScheduler = null
@export var sounder: SounderController = null
@export var telegraph_key: TelegraphKey = null
@export var transcript_paper: TranscriptPaper = null
@export var world_state: WorldStateStore = null

var _state: State = State.IDLE
var _current_scenario: TelegraphScenarioData = null
var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()
var _attention_event_fired: bool = false

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

	_set_state(State.RECEIVING)
	transmission_started.emit(_current_scenario)
	return true

func _on_playback_time_advanced(prev_time: float, curr_time: float) -> void:
	if _state == State.RECEIVING and _current_scenario != null:
		if not _current_scenario.attention_event_id.is_empty() and not _attention_event_fired:
			var target_time: float = _current_scenario.attention_event_start_time
			if prev_time < target_time + 0.00001 and curr_time >= target_time - 0.00001:
				_attention_event_fired = true
				attention_event_triggered.emit(_current_scenario.attention_event_id)

func _on_scheduler_completed(_schedule: MorsePlaybackScheduleData) -> void:
	if _state != State.RECEIVING or _current_scenario == null:
		return

	# Fallback check for attention event before completion
	if not _current_scenario.attention_event_id.is_empty() and not _attention_event_fired:
		_attention_event_fired = true
		attention_event_triggered.emit(_current_scenario.attention_event_id)

	transmission_finished.emit(_current_scenario)

	# Pass written transcript to paper
	if transcript_paper != null:
		transcript_paper.set_transcript_text(_current_scenario.transmission_data.written_transcript)
		transcript_paper.reveal_transcript()

	if _current_scenario.requires_routing:
		_set_state(State.AWAITING_ROUTE)
		routing_requested.emit(_current_scenario.expected_routing_action)
	else:
		_record_completion_fact()
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
	_set_state(State.IDLE)

func _record_completion_fact() -> void:
	if _current_scenario != null and not _current_scenario.completion_fact.is_empty():
		var world := _get_world_state()
		if world != null:
			world.set_fact(StringName(_current_scenario.completion_fact), true)

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

func _on_key_pressed() -> void:
	if _state == State.READY:
		start_transmission()

func _set_state(new_state: State) -> void:
	if _state != new_state:
		var prev := _state
		_state = new_state
		session_state_changed.emit(_state, prev)
