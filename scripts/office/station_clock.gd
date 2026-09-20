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
## The director owns station time (plan §8): the hands are a display of
## ShiftDirector.get_station_hours(), which is monotone and speed-bounded. This
## node never assigns time on call, slot or closing, and never runs the hands
## backward. The pendulum is a real bob on a rod under a pivot at the case top,
## sharing its phase with the escapement tick the ambience emits, so the click
## and the swing cannot drift apart. The case glass never swings.

signal station_time_changed(hours: float)

@export var minute_hand: Node3D = null
@export var hour_hand: Node3D = null
@export var director: ShiftDirector = null
## Source of the shared mechanical phase (escapement tick). Falls back to a
## private accumulator when absent.
@export var ambience: OfficeAmbience = null

## Station time at the head of the watch, in hours on a 24-hour clock.
@export var shift_start_hour: float = 23.0
@export var shift_end_hour: float = 30.0

## Fallback pacing when no director is wired (style-test scenes): the same
## ordinary pace the director uses, toward the end of the watch.
@export var shift_real_seconds: float = 300.0

## The hands only move once the operator has opened the line (fallback path;
## with a director the pre-shift display simply holds 23:00).
@export var runs_before_shift: bool = false

## One full swing of the pendulum; the escapement ticks each half period.
@export var pendulum_swing: float = 0.016
@export var pendulum_period_seconds: float = 2.0

var _fallback_hours: float = -1.0
var _fallback_running: bool = false
var _pendulum: Node3D = null
## Private phase used only when no ambience shares the mechanical clock.
var _own_mechanical_elapsed: float = 0.0

func _ready() -> void:
	_resolve_nodes()
	_fallback_hours = shift_start_hour
	_fallback_running = runs_before_shift
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
		_pendulum = props.get_node_or_null("ClockPendulumPivot") as Node3D
	if director == null:
		var office := props.get_parent()
		if office != null:
			director = office.get_node_or_null("ShiftDirector") as ShiftDirector
	if ambience == null and props.get_parent() != null:
		ambience = props.get_parent().get_node_or_null("OfficeAmbience") as OfficeAmbience

func _on_shift_opened() -> void:
	_fallback_running = true

## The watch is over when the work is over. The hands do not snap to 6 A.M.
## here: the director's last target is 06:00 and the display keeps its bounded
## speed until it arrives, then rests.
func _on_shift_closed() -> void:
	_fallback_running = false

func _process(delta: float) -> void:
	advance(delta)
	_swing_pendulum(delta)

func _swing_pendulum(delta: float) -> void:
	if _pendulum == null or pendulum_period_seconds <= 0.0:
		return
	# One mechanical clock for the whole room: when the ambience is present
	# its escapement elapsed drives the swing, so each tick lands on a swing
	# extreme instead of drifting against it.
	if ambience == null:
		_own_mechanical_elapsed += delta
	var elapsed := _mechanical_elapsed()
	var phase := TAU * fmod(elapsed / pendulum_period_seconds, 1.0)
	# The dial faces +X: the bob swings in the YZ plane about the X axis.
	_pendulum.rotation.x = sin(phase) * pendulum_swing

func _mechanical_elapsed() -> float:
	if ambience != null:
		return ambience.get_mechanical_elapsed()
	return _own_mechanical_elapsed

## Presentation tick: pulls the display from the director when one owns the
## night; otherwise paces itself at the ordinary speed. Deterministic for
## tests, which call it directly.
func advance(delta: float) -> void:
	_resolve_nodes()
	if director != null:
		# The director owns station time; this display only renders it.
		apply_station_time(director.get_station_hours())
		return
	if not _fallback_running or delta <= 0.0:
		return
	if shift_real_seconds <= 0.0:
		_fallback_hours = shift_end_hour
	else:
		var pace := (shift_end_hour - shift_start_hour) / shift_real_seconds
		_fallback_hours = minf(_fallback_hours + pace * delta, shift_end_hour)
	apply_station_time(_fallback_hours)

## Station time in hours. Values past 24.0 are the small hours of the next day,
## so 30.0 reads as 6 A.M.
func get_station_hours() -> float:
	if director != null:
		return director.get_station_hours()
	if _fallback_hours >= 0.0:
		return _fallback_hours
	return shift_start_hour

func get_progress() -> float:
	var span := shift_end_hour - shift_start_hour
	if span <= 0.0:
		return 1.0
	return clampf((get_station_hours() - shift_start_hour) / span, 0.0, 1.0)

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
