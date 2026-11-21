class_name TapeRegisterController
extends Node3D

## The paper-tape register (design doc §4): a mechanical recorder that inks
## every delivered MARK/GAP of the objective scheduler timeline onto a continuously
## fed paper strip. It is the sounder's silent twin — same signals, no sound,
## and NO access to message text whatsoever: it cannot lie by construction.

## The strip lifts to the lamp with numbered non-ink take boundaries, never decoded text.
## Reading and comparing with the transcript is the player's own work.
signal tape_inspected(text: String)

const TAPE_DOC_ID := "tape_register"
const TAPE_TITLE := "WIRE TAPE"
const INCOMPLETE_MARK := "?"
## Strip language, 1894: takes are "strips" of the record; an interrupted
## take is broken off, a live one is running. The prefix is a named constant
## so the office's layout wrapper recognizes strip headers without a magic
## literal.
const TAKE_HEADER_PREFIX := "— STRIP "
const TAKE_HEADER_FORMAT := "— STRIP %d · %s —"
const STATUS_INTERRUPTED := "BROKEN OFF"
const STATUS_COMPLETE := "ENDED"
const STATUS_ACTIVE := "RUNNING"
## What a slack spring means to the reader: the tail waits under the rollers.
const SLACK_NOTE := "(strip held under the rollers — wind the register)"

@export var prompt_message: String = "Read Tape Register"
## The inking stylus drops onto the tape on every MARK and lifts on every GAP —
## driven by the same scheduler events it records, so what it is seen to do is
## exactly what it wrote. Cosmetic only: the record never reads it back.
@export var stylus_travel: float = 0.003
@export var stylus_speed: float = 0.25
## The spool turns while the register is on the line: the tape always crawls.
@export var spool_turn_rate: float = 0.5
## Clockwork: the spring runs down over the watch and the spool slows; the
## operator winds it at the side key. The RECORD never depends on it — the
## ink comes from the scheduler — only the mechanism's life does. The
## clockwork starts with the first playback on the line, not at scene load:
## PRE_SHIFT silence spends no spring, so the slowdown lines up with the
## watch's wire time. At the authored 360 s pace the wind prompt comes ~90 s
## after the first call and slack ~162 s, keeping the hook's take readable.
signal register_wound()
@export var spring_run_down_seconds: float = 360.0
@export var spring_floor: float = 0.35
@export var wind_prompt_below: float = 0.75
const PROMPT_WIND := "Wind the Register"
## Below this tension the feed lags the stylus: new marks stay under the
## rollers until the register is wound. Availability never goes backwards.
const SLACK_TENSION := 0.55
var spring_tension: float = 1.0
## False once the line has closed for the night: the spool stops.
var line_live: bool = true
var _wind_interactable: Interactable = null
## True once the first playback has run on the connected line: only then does
## the spring start spending itself.
var _clockwork_running: bool = false

var _stylus: Node3D = null
var _stylus_rest_y: float = 0.0
var _stylus_target_y: float = 0.0
var _spool: Node3D = null
## Plan 8.3: winding is one full turn of the side key in four quarter turns,
## each ending on a click of the ratchet (the winding sound's teeth land on
## these), the hand carrying it a hair past before the pawl takes it back.
const WIND_CLICK_SECONDS: Array[float] = [0.04, 0.24, 0.44, 0.64]
const KEY_TURN_SECONDS: float = 0.09
const KEY_OVERTURN: float = 0.1
const KEY_CATCH_SECONDS: float = 0.04
## The spool takes up the new tension over the winding rather than at once.
const SPOOL_TAKE_UP_SECONDS: float = 0.8
var _winding_key: Node3D = null
var _wind_elapsed: float = -1.0
var _wind_backlog: int = 0
var _wind_released: int = 0
var _key_angle: float = 0.0
var _spool_drive: float = 1.0

var interactable: Interactable = null

var _record: Array[TapeInkEvent] = []
var _segments: Array[Dictionary] = []
var _active_segment: Dictionary = {}
var _connected_scheduler: MorseRuntimeScheduler = null
var _started_event: MorseScheduledEvent = null
var _active_ink: TapeInkEvent = null
var _seconds_per_unit: float = 0.0
## Viewer-visible event count per wire take number: the paper feed cursor.
## It only ever grows (events inked while the clockwork keeps up, plus winding);
## a run-down spring holds the tail back, it never rewinds the strip. Kept
## apart from _record so public snapshots stay schema-identical.
var _feed_cursors: Dictionary = {}

func _ready() -> void:
	_stylus = get_node_or_null("Body/StylusPivot") as Node3D
	if _stylus != null:
		_stylus_rest_y = _stylus.position.y
		_stylus_target_y = _stylus_rest_y
	_spool = get_node_or_null("Body/Spool") as Node3D
	_winding_key = get_node_or_null("Body/WindingKeyPivot") as Node3D
	_spool_drive = spring_tension
	_wind_interactable = get_node_or_null("WindInteractable") as Interactable
	if _wind_interactable != null:
		_wind_interactable.prompt_text = PROMPT_WIND
		_wind_interactable.enabled = false
		if not _wind_interactable.interacted.is_connected(wind):
			_wind_interactable.interacted.connect(wind)
	var act := get_interactable()
	if act != null:
		act.prompt_text = prompt_message

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func _on_interacted() -> void:
	tape_inspected.emit(get_tape_text_for_viewer())

func get_record() -> Array[TapeInkEvent]:
	return _snapshot_events(_record)

func get_strip_count() -> int:
	return _segments.size()

func _snapshot_events(events: Array[TapeInkEvent]) -> Array[TapeInkEvent]:
	var snapshots: Array[TapeInkEvent] = []
	for ink in events:
		snapshots.append(ink.snapshot())
	return snapshots

func get_segment_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for segment in _segments:
		snapshots.append({"number": segment.number, "interrupted": segment.interrupted,
			"complete": segment.complete, "events": _snapshot_events(segment.events)})
	return snapshots

func connect_scheduler(scheduler: MorseRuntimeScheduler) -> void:
	if scheduler == null:
		return
	disconnect_scheduler()
	_connected_scheduler = scheduler
	if not scheduler.playback_started.is_connected(_on_playback_started):
		scheduler.playback_started.connect(_on_playback_started)
	if not scheduler.timing_event_started.is_connected(_on_timing_event_started):
		scheduler.timing_event_started.connect(_on_timing_event_started)
	if not scheduler.timing_event_finished.is_connected(_on_timing_event_finished):
		scheduler.timing_event_finished.connect(_on_timing_event_finished)
	if not scheduler.playback_time_advanced.is_connected(_on_playback_time_advanced):
		scheduler.playback_time_advanced.connect(_on_playback_time_advanced)
	if not scheduler.playback_completed.is_connected(_on_playback_completed):
		scheduler.playback_completed.connect(_on_playback_completed)
	if not scheduler.playback_cancelled.is_connected(_on_playback_cancelled):
		scheduler.playback_cancelled.connect(_on_playback_cancelled)

func disconnect_scheduler() -> void:
	if _connected_scheduler == null:
		return
	if _connected_scheduler.playback_started.is_connected(_on_playback_started):
		_connected_scheduler.playback_started.disconnect(_on_playback_started)
	if _connected_scheduler.timing_event_started.is_connected(_on_timing_event_started):
		_connected_scheduler.timing_event_started.disconnect(_on_timing_event_started)
	if _connected_scheduler.timing_event_finished.is_connected(_on_timing_event_finished):
		_connected_scheduler.timing_event_finished.disconnect(_on_timing_event_finished)
	if _connected_scheduler.playback_time_advanced.is_connected(_on_playback_time_advanced):
		_connected_scheduler.playback_time_advanced.disconnect(_on_playback_time_advanced)
	if _connected_scheduler.playback_completed.is_connected(_on_playback_completed):
		_connected_scheduler.playback_completed.disconnect(_on_playback_completed)
	if _connected_scheduler.playback_cancelled.is_connected(_on_playback_cancelled):
		_connected_scheduler.playback_cancelled.disconnect(_on_playback_cancelled)
	_connected_scheduler = null

func reset() -> void:
	_record.clear()
	_segments.clear()
	_active_segment = {}
	_started_event = null
	_active_ink = null
	_seconds_per_unit = 0.0
	_feed_cursors.clear()
	_wind_elapsed = -1.0
	_wind_backlog = 0
	_wind_released = 0
	_set_key_angle(0.0)
	_stylus_target_y = _stylus_rest_y
	_clockwork_running = false

func _on_playback_started(_schedule: MorsePlaybackScheduleData) -> void:
	var events: Array[TapeInkEvent] = []
	_active_segment = {"number": _segments.size() + 1, "interrupted": false, "complete": false, "events": events}
	_segments.append(_active_segment)
	# The first signal on the line starts the mechanism's watch.
	_clockwork_running = true

func _on_timing_event_started(event: MorseScheduledEvent) -> void:
	# Controlled hardware fixtures may deliver events without a scheduler start signal.
	if _active_segment.is_empty():
		_on_playback_started(null)
	var ink := TapeInkEvent.new()
	ink.kind = event.kind
	_record.append(ink)
	_active_segment.events.append(ink)
	# The paper feeds out only while the clockwork keeps up: this mark reaches
	# the readable strip immediately, or waits under the rollers for a winding.
	if spring_tension >= SLACK_TENSION and _wind_elapsed < 0.0:
		_advance_feed_cursor(_active_segment, _active_segment.events.size())
	_started_event = event
	_active_ink = ink
	_seconds_per_unit = event.duration_seconds / float(event.duration_units) if event.duration_units > 0 else 0.0
	# A hitch advances the clock before emitting later starts; only that elapsed time is ink.
	if _connected_scheduler != null:
		_update_active_ink(_connected_scheduler.get_elapsed_seconds())
	_stylus_target_y = _stylus_rest_y - (stylus_travel if event.kind == MorseTimingEvent.Kind.MARK else 0.0)

func _on_playback_time_advanced(_previous_seconds: float, current_seconds: float) -> void:
	_update_active_ink(current_seconds)

func _update_active_ink(elapsed_seconds: float) -> void:
	if _started_event == null or _active_ink == null:
		return
	_active_ink.duration_seconds = clampf(elapsed_seconds - _started_event.start_seconds,
		0.0, _started_event.duration_seconds)
	_active_ink.duration_units = _active_ink.duration_seconds / _seconds_per_unit if _seconds_per_unit > 0.0 else 0.0

func _on_timing_event_finished(event: MorseScheduledEvent) -> void:
	if event != _started_event or _active_ink == null:
		return
	_active_ink.duration_seconds = event.duration_seconds
	_active_ink.duration_units = float(event.duration_units)
	_active_ink.is_complete = true
	_started_event = null
	_active_ink = null
	_seconds_per_unit = 0.0

func _process(delta: float) -> void:
	if _stylus != null:
		_stylus.position.y = move_toward(_stylus.position.y, _stylus_target_y, stylus_speed * delta)
	_advance_winding(delta)
	if _connected_scheduler != null and line_live and _clockwork_running:
		spring_tension = maxf(spring_tension - delta / maxf(spring_run_down_seconds, 0.01), spring_floor)
		if _spool != null:
			_spool.rotate_object_local(Vector3.UP, spool_turn_rate * _spool_drive * delta)
		if _wind_interactable != null:
			_wind_interactable.enabled = needs_winding()

## The clockwork is turning (the line is live and the movement released). Read
## by the register's own whir (7.11); it says nothing about the record.
func is_clockwork_running() -> bool:
	return _connected_scheduler != null and line_live and _clockwork_running

## The clockwork has run down far enough that the side key is due. Mirrors the
## wind interactable's enable condition, for callers that should not reach into
## the node tree for it.
func needs_winding() -> bool:
	return spring_tension < wind_prompt_below

func wind() -> void:
	if _wind_elapsed >= 0.0:
		return
	spring_tension = 1.0
	_wind_backlog = 0
	_wind_released = 0
	for segment in _segments:
		_wind_backlog += segment.events.size() - _visible_event_count(segment)
	_set_key_angle(0.0)
	if _wind_interactable != null:
		_wind_interactable.enabled = false
	_wind_elapsed = 0.0
	register_wound.emit()

## The ratchet releases the backlog in wire order, in step with the key.
func _advance_winding(delta: float) -> void:
	_spool_drive = move_toward(_spool_drive, spring_tension, maxf(delta, 0.0) / SPOOL_TAKE_UP_SECONDS)
	if _wind_elapsed < 0.0:
		return
	_wind_elapsed += maxf(delta, 0.0)
	var last_click: float = WIND_CLICK_SECONDS[WIND_CLICK_SECONDS.size() - 1]
	if _wind_elapsed >= last_click + KEY_CATCH_SECONDS:
		# Ink delivered during the turn also clears the rollers at the end.
		for segment in _segments:
			_advance_feed_cursor(segment, segment.events.size())
		_wind_elapsed = -1.0
		_set_key_angle(TAU)
		return
	_set_key_angle(_key_angle_at(_wind_elapsed))
	var clicks := 0
	for click in WIND_CLICK_SECONDS:
		if _wind_elapsed >= click:
			clicks += 1
	var release_target := floori(float(_wind_backlog * clicks) / WIND_CLICK_SECONDS.size())
	var remaining := release_target - _wind_released
	if remaining <= 0:
		return
	for segment in _segments:
		var visible := _visible_event_count(segment)
		var count := mini(remaining, segment.events.size() - visible)
		_advance_feed_cursor(segment, visible + count)
		_wind_released += count
		remaining -= count
		if remaining == 0:
			break

func _key_angle_at(seconds: float) -> float:
	var quarter := TAU / 4.0
	for step in WIND_CLICK_SECONDS.size():
		var click: float = WIND_CLICK_SECONDS[step]
		var start := maxf(click - KEY_TURN_SECONDS, 0.0 if step == 0 else WIND_CLICK_SECONDS[step - 1] + KEY_CATCH_SECONDS)
		var settled := quarter * step
		if seconds < start:
			return settled
		if seconds < click:
			var turn := ease((seconds - start) / maxf(click - start, 0.001), 0.6)
			return settled + (quarter + KEY_OVERTURN) * turn
		if seconds < click + KEY_CATCH_SECONDS:
			var caught := (seconds - click) / KEY_CATCH_SECONDS
			return settled + quarter + KEY_OVERTURN * (1.0 - caught)
	return TAU

func _set_key_angle(angle: float) -> void:
	_key_angle = angle
	if _winding_key != null:
		# Clockwise to the operator, who faces this side of the case.
		_winding_key.rotation.x = -fmod(angle, TAU)

## How far the side key has turned in the current winding, in radians.
func get_key_angle() -> float:
	return _key_angle

## Holds the side key at a fraction of one turn (evidence frames only).
func set_key_turn(fraction: float) -> void:
	_set_key_angle(fraction * TAU)

## The tension the spool is actually running on: it takes up a winding over
## the turn of the key.
func get_spool_drive() -> float:
	return _spool_drive

func _visible_event_count(segment: Dictionary) -> int:
	return mini(int(_feed_cursors.get(segment.number, 0)), segment.events.size())

## Snapshot of the exposed paper, not of ink still held under the rollers.
func get_fed_record() -> Array[TapeInkEvent]:
	var exposed: Array[TapeInkEvent] = []
	for segment in _segments:
		var events: Array[TapeInkEvent] = segment.events
		for i in _visible_event_count(segment):
			exposed.append(events[i].snapshot())
	return exposed

## Monotonic feed cursor for one take: never shrinks, never exceeds the record.
func _advance_feed_cursor(segment: Dictionary, available: int) -> void:
	_feed_cursors[segment.number] = maxi(int(_feed_cursors.get(segment.number, 0)), available)

func record_manual_take(events: Array[MorseTimingEvent], seconds_per_unit: float) -> void:
	if events.is_empty() or seconds_per_unit <= 0.0:
		return
	var seg_events: Array[TapeInkEvent] = []
	var segment := {"number": _segments.size() + 1, "interrupted": false, "complete": true, "events": seg_events}
	_segments.append(segment)
	_clockwork_running = true
	for ev in events:
		if ev == null:
			continue
		var ink := TapeInkEvent.new()
		ink.kind = ev.kind
		ink.duration_units = float(ev.duration_units)
		ink.duration_seconds = float(ev.duration_units) * seconds_per_unit
		ink.is_complete = true
		_record.append(ink)
		seg_events.append(ink)
	if spring_tension >= SLACK_TENSION and _wind_elapsed < 0.0:
		_advance_feed_cursor(segment, seg_events.size())

func set_manual_stylus_down(down: bool) -> void:
	_stylus_target_y = _stylus_rest_y - (stylus_travel if down else 0.0)

func _on_playback_completed(_schedule: MorsePlaybackScheduleData) -> void:
	if not _active_segment.is_empty():
		_active_segment.complete = true
		_active_segment = {}
	_stylus_target_y = _stylus_rest_y

func _on_playback_cancelled(_schedule: MorsePlaybackScheduleData, elapsed_seconds: float) -> void:
	_update_active_ink(elapsed_seconds)
	if _active_ink != null:
		_active_ink.interrupted = true
	if not _active_segment.is_empty():
		_active_segment.interrupted = true
		_active_segment = {}
	_started_event = null
	_active_ink = null
	_seconds_per_unit = 0.0
	_stylus_target_y = _stylus_rest_y

## Only finished marks classify as Morse. Fractional blanks remain exact in snapshots.
func get_tape_text() -> String:
	var takes: PackedStringArray = []
	for segment in _segments:
		takes.append(_render_ink(segment.events))
	return "\n".join(takes)

func get_tape_display_text() -> String:
	# Boundaries describe wire takes, including service calls, not telegram identities or idle time.
	var takes: PackedStringArray = []
	for segment in _segments:
		var status := STATUS_INTERRUPTED if segment.interrupted else (STATUS_COMPLETE if segment.complete else STATUS_ACTIVE)
		takes.append("%s\n%s" % [TAKE_HEADER_FORMAT % [segment.number, status], _render_ink(segment.events)])
	return "\n".join(takes)

## Viewer-facing strip: the paper feeds out only while the clockwork keeps up.
## Marks inked on a slack spring stay under the feed rollers until the register
## is wound, and the strip never rewinds — what has been fed out stays
## readable. The objective _record and get_tape_display_text() are untouched.
func get_tape_text_for_viewer() -> String:
	var takes: PackedStringArray = []
	for segment in _segments:
		var status := STATUS_INTERRUPTED if segment.interrupted else (STATUS_COMPLETE if segment.complete else STATUS_ACTIVE)
		var evs: Array[TapeInkEvent] = segment.events
		var visible_count := _visible_event_count(segment)
		if visible_count < evs.size():
			# Real backlog: these recorded marks are still under the rollers.
			var slice_events: Array[TapeInkEvent] = evs.slice(0, visible_count)
			var note := "\n" + SLACK_NOTE if _wind_elapsed < 0.0 else ""
			takes.append("%s\n%s%s" % [TAKE_HEADER_FORMAT % [segment.number, status],
				_render_ink(slice_events), note])
		else:
			takes.append("%s\n%s" % [TAKE_HEADER_FORMAT % [segment.number, status],
				_render_ink(evs)])
	return "\n".join(takes)

func _render_ink(events: Array[TapeInkEvent]) -> String:
	var out := ""
	for event in events:
		if event.kind == MorseTimingEvent.Kind.MARK:
			if not event.is_complete or event.interrupted:
				out += INCOMPLETE_MARK
			elif event.duration_units >= 6.0:
				out += "———"
			else:
				out += "·" if event.duration_units <= 2.0 else "—"
		else:
			out += " ".repeat(maxi(int(floor(event.duration_units)), 0))
	return out
