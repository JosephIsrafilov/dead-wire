class_name DoorAttentionSource
extends Node3D

signal footsteps_started()
signal footsteps_completed()

@export var footstep_sound: AudioStream = preload("res://audio/sfx/foley/footstep_wood_beta.wav")
@export var step_interval: float = 0.55
@export var total_steps: int = 3
@export var volume_db: float = -9.0

var _player: AudioStreamPlayer3D = null
## Audio fairness by construction (GDD §7): a step never lands on a Morse
## MARK. A step only starts when its whole sample fits in the current gap,
## and a MARK that arrives mid-sample cuts the optional foley short.
var scheduler: MorseRuntimeScheduler = null
var _bound_scheduler: MorseRuntimeScheduler = null
var is_active: bool = false
var steps_played: int = 0
var _step_timer: float = 0.0

## Someone heavier than the operator, heard through a closed door: lower,
## muffled.
const PITCH_VARIATIONS: Array[float] = [0.84, 0.88, 0.82]
const THROUGH_DOOR_CUTOFF_HZ: float = 1400.0
const FOLEY_SAFETY_MARGIN: float = 0.08

func _ready() -> void:
	_setup_audio_player()

func _setup_audio_player() -> void:
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.name = "FootstepPlayer"
		_player.stream = footstep_sound
		_player.volume_db = volume_db
		_player.pitch_scale = 1.0
		_player.max_distance = 12.0
		_player.attenuation_filter_cutoff_hz = THROUGH_DOOR_CUTOFF_HZ
		_player.attenuation_filter_db = -18.0
		_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
		add_child(_player)

func trigger_footsteps() -> void:
	if is_active:
		return
	is_active = true
	steps_played = 0
	_step_timer = 0.0
	footsteps_started.emit()
	_bind_fairness()
	if not _can_start_next_step():
		return
	_play_step()

func _play_step() -> void:
	var pitch_idx := steps_played % PITCH_VARIATIONS.size()
	if _player != null:
		_player.pitch_scale = PITCH_VARIATIONS[pitch_idx]
		if is_inside_tree():
			_player.play()

	steps_played += 1
	_step_timer = step_interval

	if steps_played >= total_steps:
		is_active = false
		footsteps_completed.emit()

func _process(delta: float) -> void:
	_bind_fairness()
	if is_active and steps_played < total_steps:
		_step_timer -= delta
		if _step_timer <= 0.0 and _can_start_next_step():
			_play_step()

## True when a sample of [param seconds] (plus safety margin) finishes before
## the next MARK. Only a GAP with enough room left admits optional foley.
func can_fit_foley(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0.0:
		return false
	if scheduler == null or not scheduler.is_playing():
		return true
	var event := scheduler.get_current_event()
	if event == null or event.kind != MorseTimingEvent.Kind.GAP:
		return false
	return event.end_seconds - scheduler.get_elapsed_seconds() >= seconds + FOLEY_SAFETY_MARGIN

func _can_start_next_step() -> bool:
	if footstep_sound == null:
		return true
	var pitch := PITCH_VARIATIONS[steps_played % PITCH_VARIATIONS.size()]
	return can_fit_foley(footstep_sound.get_length() / maxf(pitch, 0.01))

func _bind_fairness() -> void:
	if _bound_scheduler == scheduler:
		return
	if is_instance_valid(_bound_scheduler) and _bound_scheduler.timing_event_started.is_connected(_on_wire_event):
		_bound_scheduler.timing_event_started.disconnect(_on_wire_event)
	_bound_scheduler = scheduler
	if scheduler != null:
		scheduler.timing_event_started.connect(_on_wire_event)

func _on_wire_event(event: MorseScheduledEvent) -> void:
	if event.kind == MorseTimingEvent.Kind.MARK and _player != null and _player.playing:
		_player.stop()
