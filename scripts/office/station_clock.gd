class_name StationClock
extends Node

## Drives the regulator clock on the west wall.
##
## The night has to visibly pass. A shift that never moves toward morning is a
## room with events in it, not a shift. The clock is the only place the player
## can read how far through the night they are, and reading it means turning away
## from the desk — the same trade every other information source in the office
## demands.
##
## It shows station time, not real time. The whole 11 P.M. to 6 A.M. watch is
## compressed into the playable shift.

signal station_time_changed(hours: float)

@export var minute_hand: Node3D = null
@export var hour_hand: Node3D = null
@export var director: ShiftDirector = null

## Station time at the head of the watch, in hours on a 24-hour clock.
@export var shift_start_hour: float = 23.0
@export var shift_end_hour: float = 30.0

## Real seconds the compressed watch is expected to take. The hands are paced to
## reach 6 A.M. as the last message closes the line, then hold there.
@export var shift_real_seconds: float = 300.0

## The hands only move once the operator has opened the line.
@export var runs_before_shift: bool = false

## The pendulum swings whether or not the shift has started — a regulator clock
## does not wait for anyone. Amplitude in metres, one full swing per second to
## match the escapement tick the ambience already emits.
@export var pendulum_swing: float = 0.016
@export var pendulum_period_seconds: float = 2.0

var _elapsed_seconds: float = 0.0
var _running: bool = false
var _pendulum: Node3D = null
var _pendulum_rest_z: float = 0.0
var _pendulum_phase: float = 0.0

func _ready() -> void:
	_resolve_nodes()
	_running = runs_before_shift
	if director != null:
		if not director.shift_opened.is_connected(_on_shift_opened):
			director.shift_opened.connect(_on_shift_opened)
		if not director.shift_closed.is_connected(_on_shift_closed):
			director.shift_closed.connect(_on_shift_closed)
	apply_station_time(get_station_hours())

func _resolve_nodes() -> void:
	var props := get_parent()
	if props == null:
		return
	if minute_hand == null:
		minute_hand = props.get_node_or_null("ClockHandMinute") as Node3D
	if hour_hand == null:
		hour_hand = props.get_node_or_null("ClockHandHour") as Node3D
	if _pendulum == null:
		_pendulum = props.get_node_or_null("ClockPendulumGlass") as Node3D
		if _pendulum != null:
			_pendulum_rest_z = _pendulum.position.z
	if director == null:
		var office := props.get_parent()
		if office != null:
			director = office.get_node_or_null("ShiftDirector") as ShiftDirector

func _on_shift_opened() -> void:
	_running = true

## The watch is over when the work is over, however long the operator took. The
## hands land on 6 A.M. as the line closes rather than drifting past it.
func _on_shift_closed() -> void:
	_elapsed_seconds = shift_real_seconds
	_running = false
	apply_station_time(get_station_hours())

func _process(delta: float) -> void:
	advance(delta)
	_swing_pendulum(delta)

func _swing_pendulum(delta: float) -> void:
	if _pendulum == null or pendulum_period_seconds <= 0.0:
		return
	_pendulum_phase += delta * TAU / pendulum_period_seconds
	_pendulum.position.z = _pendulum_rest_z + sin(_pendulum_phase) * pendulum_swing

## Separated from _process so tests can wind the clock deterministically.
func advance(delta: float) -> void:
	if not _running or delta <= 0.0:
		return
	_elapsed_seconds = minf(_elapsed_seconds + delta, shift_real_seconds)
	apply_station_time(get_station_hours())

## Station time in hours. Values past 24.0 are the small hours of the next day,
## so 30.0 reads as 6 A.M.
func get_station_hours() -> float:
	if shift_real_seconds <= 0.0:
		return shift_end_hour
	var progress := clampf(_elapsed_seconds / shift_real_seconds, 0.0, 1.0)
	return lerpf(shift_start_hour, shift_end_hour, progress)

func get_progress() -> float:
	if shift_real_seconds <= 0.0:
		return 1.0
	return clampf(_elapsed_seconds / shift_real_seconds, 0.0, 1.0)

## Formats station time the way the duty sheet writes it.
func get_station_time_text() -> String:
	var hours := get_station_hours()
	var total_minutes := int(round(hours * 60.0)) % (24 * 60)
	var display_hour := total_minutes / 60
	var display_minute := total_minutes % 60
	var suffix := "A.M." if display_hour < 12 else "P.M."
	var clock_hour := display_hour % 12
	if clock_hour == 0:
		clock_hour = 12
	return "%d:%02d %s" % [clock_hour, display_minute, suffix]

func apply_station_time(hours: float) -> void:
	_resolve_nodes()
	# The dial faces +X, so the hands sweep in the YZ plane about the X axis.
	# Negative rotation reads as clockwise from inside the room.
	if minute_hand != null:
		var minute_turns := fmod(hours, 1.0)
		minute_hand.rotation = Vector3(-TAU * minute_turns, 0.0, 0.0)
	if hour_hand != null:
		var hour_turns := fmod(hours, 12.0) / 12.0
		hour_hand.rotation = Vector3(-TAU * hour_turns, 0.0, 0.0)
	station_time_changed.emit(hours)
