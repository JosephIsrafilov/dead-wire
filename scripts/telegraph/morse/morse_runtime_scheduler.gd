class_name MorseRuntimeScheduler
extends Node

enum State {
	IDLE,
	PLAYING,
	COMPLETED
}

signal playback_started(schedule: MorsePlaybackScheduleData)
signal timing_event_started(event: MorseScheduledEvent)
signal timing_event_finished(event: MorseScheduledEvent)
signal playback_time_advanced(previous_seconds: float, current_seconds: float)
signal playback_completed(schedule: MorsePlaybackScheduleData)
signal playback_cancelled(schedule: MorsePlaybackScheduleData, elapsed_seconds: float)

const TIME_EPSILON: float = 0.00001

@export var auto_process: bool = true

var _state: State = State.IDLE
var _active_schedule: MorsePlaybackScheduleData = null
var _elapsed_seconds: float = 0.0
var _current_event_index: int = -1
var _active_event_started: bool = false

func get_playback_state() -> State:
	return _state

func is_playing() -> bool:
	return _state == State.PLAYING

func get_active_schedule() -> MorsePlaybackScheduleData:
	return _active_schedule

func get_current_event() -> MorseScheduledEvent:
	if _active_schedule == null or _current_event_index < 0 or _current_event_index >= _active_schedule.events.size():
		return null
	return _active_schedule.events[_current_event_index]

func get_current_event_index() -> int:
	return _current_event_index

func get_elapsed_seconds() -> float:
	return _elapsed_seconds

func get_total_duration_seconds() -> float:
	if _active_schedule != null:
		return _active_schedule.total_duration_seconds
	return 0.0

func start(schedule: MorsePlaybackScheduleData) -> bool:
	if _state == State.PLAYING:
		return false
	if schedule == null:
		return false
	var errs: PackedStringArray = schedule.get_validation_errors()
	if not errs.is_empty():
		return false

	_active_schedule = schedule
	_elapsed_seconds = 0.0
	_current_event_index = -1
	_active_event_started = false
	_state = State.PLAYING
	playback_started.emit(_active_schedule)

	# Process initial timestamp at t = 0.0
	advance_time(0.0)
	return true

func cancel() -> void:
	if _state == State.PLAYING:
		var sched := _active_schedule
		var elapsed := _elapsed_seconds
		_state = State.IDLE
		_active_schedule = null
		_current_event_index = -1
		_active_event_started = false
		playback_cancelled.emit(sched, elapsed)

func reset() -> void:
	_state = State.IDLE
	_active_schedule = null
	_elapsed_seconds = 0.0
	_current_event_index = -1
	_active_event_started = false

func _process(delta: float) -> void:
	if auto_process and _state == State.PLAYING:
		advance_time(delta)

func advance_time(delta: float) -> void:
	if _state != State.PLAYING or _active_schedule == null:
		return

	var prev_time := _elapsed_seconds
	_elapsed_seconds += delta
	var curr_time := _elapsed_seconds

	playback_time_advanced.emit(prev_time, curr_time)

	while _state == State.PLAYING and _active_schedule != null:
		var next_idx: int = _current_event_index if _active_event_started else _current_event_index + 1

		if next_idx >= _active_schedule.events.size():
			if _elapsed_seconds >= _active_schedule.total_duration_seconds - TIME_EPSILON:
				var finished_sched := _active_schedule
				_state = State.COMPLETED
				playback_completed.emit(finished_sched)
			break

		var target_ev: MorseScheduledEvent = _active_schedule.events[next_idx]

		if not _active_event_started:
			if _elapsed_seconds >= target_ev.start_seconds - TIME_EPSILON:
				_current_event_index = next_idx
				_active_event_started = true
				timing_event_started.emit(target_ev)
			else:
				break

		if _active_event_started:
			if _elapsed_seconds >= target_ev.end_seconds - TIME_EPSILON:
				_active_event_started = false
				timing_event_finished.emit(target_ev)
			else:
				break
