class_name SounderController
extends Node3D

signal sounder_clicked_down(event_index: int)
signal sounder_clacked_up(event_index: int)

@export var down_sound: AudioStream = preload("res://audio/sfx/telegraph/sounder_down.wav")
@export var up_sound: AudioStream = preload("res://audio/sfx/telegraph/sounder_up.wav")
@export var volume_db: float = -3.0
## The wire has its own bus so the transmission mix can be balanced against
## the room without touching anyone else's fader. Calls, nags and closing ride
## the same sounder and therefore the same bus.
@export var bus: StringName = &"Telegraph"
## Brass never strikes twice the same: ±1.5% pitch per stroke. Pitch only —
## onset timing, the information, is untouched.
const PITCH_SPREAD: float = 0.015

## The armature physically strikes the anvil on every mark and lifts on every
## gap. Until this existed the game's centrepiece clicked audibly while
## standing perfectly still, which is most of why the office read as a diorama.
##
## Plan 8.1: it is a lever on a trunnion at the back of the frame, not a bar
## that drops level. The magnet pulls the front down onto the anvil, it comes
## off it a hair and settles; the spring brings it back up against the stop
## screw the same way. Motion only: the click is played on the event itself,
## so MARK/GAP timing is untouched.
## Travel at the anvil, where the front of the armature strikes.
@export var armature_travel: float = 0.0048
## The trunnion, in ArmatureBar-local coordinates (the rear of the bar).
@export var armature_pivot: Vector3 = Vector3(0.0, 0.0, -0.045)
## Where the anvil meets the bar, along its length (ArmatureBar-local z).
@export var armature_strike_z: float = 0.041
## A real armature snaps: it crosses from stop to anvil in about 14 ms.
@export var armature_cross_seconds: float = 0.014
## Fraction of its speed the bar keeps coming off the anvil or the stop.
@export var armature_restitution: float = 0.3
const ARMATURE_STEP: float = 0.0005

var _player_down: AudioStreamPlayer3D = null
var _player_up: AudioStreamPlayer3D = null

var down_clicks_played: int = 0
var up_clacks_played: int = 0
var is_lever_down: bool = false
var _connected_scheduler: MorseRuntimeScheduler = null

var armature: Node3D = null
var _armature_rest: Transform3D = Transform3D.IDENTITY
var _armature_rest_captured: bool = false
var _armature_down: bool = false
var _armature_angle: float = 0.0
var _armature_velocity: float = 0.0

func _ready() -> void:
	_setup_audio_players()
	_setup_armature()

func _setup_armature() -> void:
	if armature == null:
		armature = get_node_or_null("ArmatureBar") as Node3D
	# Capture rest exactly once. Re-reading it after the bar has dropped would
	# treat the struck position as the new rest and the armature would walk down
	# the anvil one mark at a time.
	if armature != null and not _armature_rest_captured:
		_armature_rest_captured = true
		_armature_rest = armature.transform

## Driven per frame rather than by a tween: a message is dozens of marks a
## second and spawning a tween per click would thrash.
func _process(delta: float) -> void:
	if armature == null:
		return
	_advance_armature(delta)

func _max_armature_angle() -> float:
	return atan2(armature_travel, armature_strike_z - armature_pivot.z)

## A constant pull (magnet down, spring up) between two hard stops, stepped
## finely enough that a 14 ms crossing and its bounce are resolved.
func _advance_armature(delta: float) -> void:
	var max_angle := _max_armature_angle()
	var pull := 2.0 * max_angle / maxf(armature_cross_seconds * armature_cross_seconds, 0.000001)
	var settle := pull * ARMATURE_STEP * 2.0
	var left := clampf(delta, 0.0, 0.25)
	while left > 0.0:
		var step := minf(ARMATURE_STEP, left)
		left -= step
		_armature_velocity += (pull if _armature_down else -pull) * step
		_armature_angle += _armature_velocity * step
		if _armature_angle >= max_angle and _armature_velocity > 0.0:
			_armature_angle = max_angle
			_armature_velocity = -_armature_velocity * armature_restitution
		elif _armature_angle <= 0.0 and _armature_velocity < 0.0:
			_armature_angle = 0.0
			_armature_velocity = -_armature_velocity * armature_restitution
		# A bounce too small to leave the stop is the bar at rest on it.
		if absf(_armature_velocity) < settle and (_armature_angle >= max_angle or _armature_angle <= 0.0):
			_armature_velocity = 0.0
	_apply_armature()

func _apply_armature() -> void:
	if armature == null:
		return
	var turn := Transform3D(Basis(Vector3.RIGHT, _armature_angle), Vector3.ZERO)
	armature.transform = _armature_rest * Transform3D(Basis.IDENTITY, armature_pivot) * turn \
		* Transform3D(Basis.IDENTITY, -armature_pivot)

## Holds the armature at a fraction of its travel (0 = on the stop, 1 = on the
## anvil). For evidence frames; play_down/play_up drive it in play.
func set_armature_amount(amount: float) -> void:
	_setup_armature()
	_armature_angle = _max_armature_angle() * clampf(amount, 0.0, 1.0)
	_armature_velocity = 0.0
	_apply_armature()

## How far the front of the armature, where it meets the anvil, is below rest.
func get_armature_strike_drop() -> float:
	if armature == null:
		return 0.0
	var strike := Vector3(0.0, 0.0, armature_strike_z)
	return (_armature_rest * strike).y - (armature.transform * strike).y

func _setup_audio_players() -> void:
	if _player_down == null:
		_player_down = AudioStreamPlayer3D.new()
		_player_down.name = "AudioPlayerDown"
		_player_down.stream = down_sound
		_player_down.volume_db = volume_db
		_player_down.pitch_scale = 1.0
		_player_down.max_distance = 15.0
		_player_down.bus = bus
		add_child(_player_down)

	if _player_up == null:
		_player_up = AudioStreamPlayer3D.new()
		_player_up.name = "AudioPlayerUp"
		_player_up.stream = up_sound
		_player_up.volume_db = volume_db
		_player_up.pitch_scale = 1.0
		_player_up.max_distance = 15.0
		_player_up.bus = bus
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
	_setup_armature()
	_armature_down = true
	if _player_down != null and is_inside_tree():
		_player_down.pitch_scale = 1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
		_player_down.play()
	sounder_clicked_down.emit(event_index)

func play_up(event_index: int = -1) -> void:
	is_lever_down = false
	up_clacks_played += 1
	_setup_armature()
	_armature_down = false
	if _player_up != null and is_inside_tree():
		_player_up.pitch_scale = 1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
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
