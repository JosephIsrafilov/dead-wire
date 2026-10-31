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
## Plan 9.2: the hour has begun to strike (12-hour dial hour).
signal clock_struck(hour: int)
## One stroke of the gong, counted from 1 within the hour.
signal stroke_sounded(index: int)

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
## 0.016 rad is a 1.8 cm throw on a 0.18 m rod — physically right, and invisible
## from across a dark room. 0.055 rad is still a small, believable swing but it
## reads at the distance the player actually stands at, which is the point of
## putting a clock on the wall.
@export var pendulum_swing: float = 0.055
@export var pendulum_period_seconds: float = 2.0

## Plan 9.2: the regulator strikes two and three, the hours the night is
## known by. A stroke never lands on a busy wire or in a hush; it waits.
@export var strike_stream: AudioStream = preload("res://audio/sfx/foley/clock_strike.wav")
@export var striking_hours: PackedFloat32Array = PackedFloat32Array([26.0, 27.0])
@export var stroke_interval_seconds: float = 1.6
@export var strike_volume_db: float = -6.0

var _fallback_hours: float = -1.0
var _last_hours: float = -1.0
## The hour owed to the gong: only the latest, a clock strikes the hour it is.
var _owed_hour: int = 0
var _strokes_left: int = 0
var _stroke_index: int = 0
var _stroke_timer: float = 0.0
var _strike_player: AudioStreamPlayer3D = null
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
	# The dial faces +X: the bob swings in the YZ plane about the X axis. The
	# escapement strikes at whole seconds; cosine puts each strike at a swing
	# extreme — tick at one end, tock at the other (plan 7.9).
	_pendulum.rotation.x = cos(phase) * pendulum_swing

func _mechanical_elapsed() -> float:
	if ambience != null:
		return ambience.get_mechanical_elapsed()
	return _own_mechanical_elapsed

## Presentation tick: pulls the display from the director when one owns the
## night; otherwise paces itself at the ordinary speed. Deterministic for
## tests, which call it directly.
func advance(delta: float) -> void:
	_resolve_nodes()
	_advance_strike(delta)
	if director != null:
		# The director owns station time; this display only renders it. It
		# learns from the dial whether anyone is looking (plan 9.2).
		director.set_station_watched(is_dial_in_view())
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

## The dial is in the frame of the camera that renders the room.
func is_dial_in_view() -> bool:
	if minute_hand == null or not minute_hand.is_inside_tree():
		return false
	var camera := minute_hand.get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(minute_hand.global_position)

func _advance_strike(delta: float) -> void:
	if _strokes_left == 0:
		if _owed_hour == 0 or not _room_quiet():
			return
		_strokes_left = _owed_hour
		_stroke_index = 0
		_stroke_timer = 0.0
		clock_struck.emit(_owed_hour)
		_owed_hour = 0
	# A stroke held back mid-hour waits for the wire like the first one.
	if not _room_quiet():
		return
	_stroke_timer -= delta
	if _stroke_timer > 0.0:
		return
	_stroke_timer = stroke_interval_seconds
	_strokes_left -= 1
	_stroke_index += 1
	_sound_stroke()
	stroke_sounded.emit(_stroke_index)

func _room_quiet() -> bool:
	if director != null and not director.is_room_quiet():
		return false
	return ambience == null or not ambience.clock_muted

func _sound_stroke() -> void:
	if strike_stream == null or minute_hand == null or not minute_hand.is_inside_tree():
		return
	if _strike_player == null:
		_strike_player = AudioStreamPlayer3D.new()
		_strike_player.name = "StrikePlayer"
		_strike_player.stream = strike_stream
		_strike_player.volume_db = strike_volume_db
		_strike_player.bus = &"Ambience"
		_strike_player.max_distance = 12.0
		_strike_player.unit_size = 3.0
		# Each stroke rings on under the next.
		_strike_player.max_polyphony = 3
		minute_hand.get_parent().add_child(_strike_player)
		_strike_player.global_position = minute_hand.global_position
	_strike_player.play()

func apply_station_time(hours: float) -> void:
	_resolve_nodes()
	if _last_hours >= 0.0:
		for strike_at in striking_hours:
			if _last_hours < strike_at and hours >= strike_at:
				_owed_hour = posmod(int(strike_at) - 1, 12) + 1
	_last_hours = hours
	# The dial faces +X, so the hands sweep in the YZ plane about the X axis.
	# Negative rotation reads as clockwise from inside the room.
	if minute_hand != null:
		var minute_turns := fmod(hours, 1.0)
		minute_hand.rotation = Vector3(-TAU * minute_turns, 0.0, 0.0)
	if hour_hand != null:
		var hour_turns := fmod(hours, 12.0) / 12.0
		hour_hand.rotation = Vector3(-TAU * hour_turns, 0.0, 0.0)
	station_time_changed.emit(hours)
