class_name SounderController
extends Node3D

signal sounder_clicked_down(event_index: int)
signal sounder_clacked_up(event_index: int)

@export var down_sound: AudioStream = preload("res://audio/sfx/telegraph/sounder_down.wav")
@export var up_sound: AudioStream = preload("res://audio/sfx/telegraph/sounder_up.wav")
@export var volume_db: float = -3.0

var _player_down: AudioStreamPlayer3D = null
var _player_up: AudioStreamPlayer3D = null

var down_clicks_played: int = 0
var up_clacks_played: int = 0
var is_lever_down: bool = false
var _connected_scheduler: MorseRuntimeScheduler = null

func _ready() -> void:
	_setup_audio_players()

func _setup_audio_players() -> void:
	if _player_down == null:
		_player_down = AudioStreamPlayer3D.new()
		_player_down.name = "AudioPlayerDown"
		_player_down.stream = down_sound
		_player_down.volume_db = volume_db
		_player_down.pitch_scale = 1.0
		_player_down.max_distance = 15.0
		add_child(_player_down)

	if _player_up == null:
		_player_up = AudioStreamPlayer3D.new()
		_player_up.name = "AudioPlayerUp"
		_player_up.stream = up_sound
		_player_up.volume_db = volume_db
		_player_up.pitch_scale = 1.0
		_player_up.max_distance = 15.0
		add_child(_player_up)

func connect_scheduler(scheduler: MorseRuntimeScheduler) -> void:
	if _connected_scheduler != null:
		disconnect_scheduler()

	_connected_scheduler = scheduler
	if _connected_scheduler == null:
		return

	_connected_scheduler.timing_event_started.connect(_on_timing_event_started)
	_connected_scheduler.timing_event_finished.connect(_on_timing_event_finished)
	_connected_scheduler.playback_completed.connect(_on_playback_completed)
	_connected_scheduler.playback_cancelled.connect(_on_playback_cancelled)

func disconnect_scheduler() -> void:
	if _connected_scheduler == null:
		return

	if _connected_scheduler.timing_event_started.is_connected(_on_timing_event_started):
		_connected_scheduler.timing_event_started.disconnect(_on_timing_event_started)
	if _connected_scheduler.timing_event_finished.is_connected(_on_timing_event_finished):
		_connected_scheduler.timing_event_finished.disconnect(_on_timing_event_finished)
	if _connected_scheduler.playback_completed.is_connected(_on_playback_completed):
		_connected_scheduler.playback_completed.disconnect(_on_playback_completed)
	if _connected_scheduler.playback_cancelled.is_connected(_on_playback_cancelled):
		_connected_scheduler.playback_cancelled.disconnect(_on_playback_cancelled)

	_connected_scheduler = null

func reset_telemetry() -> void:
	down_clicks_played = 0
	up_clacks_played = 0
	is_lever_down = false

func play_down(event_index: int = -1) -> void:
	is_lever_down = true
	down_clicks_played += 1
	if _player_down != null and is_inside_tree():
		_player_down.play()
	sounder_clicked_down.emit(event_index)

func play_up(event_index: int = -1) -> void:
	is_lever_down = false
	up_clacks_played += 1
	if _player_up != null and is_inside_tree():
		_player_up.play()
	sounder_clacked_up.emit(event_index)

func _on_timing_event_started(event: MorseScheduledEvent) -> void:
	if event == null:
		return

	if event.kind == MorseTimingEvent.Kind.MARK:
		play_down(event.event_index)
	elif event.kind == MorseTimingEvent.Kind.GAP:
		play_up(event.event_index)

func _on_timing_event_finished(event: MorseScheduledEvent) -> void:
	if event == null or _connected_scheduler == null:
		return

	var sched := _connected_scheduler.get_active_schedule()
	if sched != null and not sched.events.is_empty():
		var last_idx := sched.events.size() - 1
		# If the final MARK in the schedule finishes, emit terminal release up-stroke
		if event.event_index == last_idx and event.kind == MorseTimingEvent.Kind.MARK:
			play_up(event.event_index)

func _on_playback_completed(_schedule: MorsePlaybackScheduleData) -> void:
	if is_lever_down:
		play_up(-1)

func _on_playback_cancelled(_schedule: MorsePlaybackScheduleData, _elapsed: float) -> void:
	if is_lever_down:
		play_up(-1)
