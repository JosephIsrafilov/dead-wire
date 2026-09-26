class_name DoorAttentionSource
extends Node3D

signal footsteps_started()
signal footsteps_completed()

@export var footstep_sound: AudioStream = preload("res://audio/sfx/foley/footstep_wood.wav")
@export var step_interval: float = 0.55
@export var total_steps: int = 3
@export var volume_db: float = -9.0

var _player: AudioStreamPlayer3D = null
var is_active: bool = false
var steps_played: int = 0
var _step_timer: float = 0.0

## Someone heavier than the operator, heard through a closed door: lower,
## muffled.
const PITCH_VARIATIONS: Array[float] = [0.84, 0.88, 0.82]
const THROUGH_DOOR_CUTOFF_HZ: float = 1400.0

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
	if is_active and steps_played < total_steps:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_step()
