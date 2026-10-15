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
const TAPE_TITLE := "STATION REGISTER"
const INCOMPLETE_MARK := "?"

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
## ink comes from the scheduler — only the mechanism's life does.
signal register_wound()
@export var spring_run_down_seconds: float = 240.0
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

var _stylus: Node3D = null
var _stylus_rest_y: float = 0.0
var _stylus_target_y: float = 0.0
var _spool: Node3D = null

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
	_stylus_target_y = _stylus_rest_y

func _on_playback_started(_schedule: MorsePlaybackScheduleData) -> void:
	var events: Array[TapeInkEvent] = []
	_active_segment = {"number": _segments.size() + 1, "interrupted": false, "complete": false, "events": events}
	_segments.append(_active_segment)

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
	if spring_tension >= SLACK_TENSION:
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
	if _connected_scheduler != null and line_live:
		spring_tension = maxf(spring_tension - delta / maxf(spring_run_down_seconds, 0.01), spring_floor)
		if _spool != null:
			_spool.rotate_object_local(Vector3.UP, spool_turn_rate * spring_tension * delta)
		if _wind_interactable != null:
			_wind_interactable.enabled = spring_tension < wind_prompt_below

func wind() -> void:
	spring_tension = 1.0
	# Winding transports the whole strip in one motion: every mark still under
	# the feed rollers is carried out. The record itself never changes.
	for segment in _segments:
		_advance_feed_cursor(segment, segment.events.size())
	if _wind_interactable != null:
		_wind_interactable.enabled = false
	register_wound.emit()

## Monotonic feed cursor for one take: never shrinks, never exceeds the record.
func _advance_feed_cursor(segment: Dictionary, available: int) -> void:
	_feed_cursors[segment.number] = maxi(int(_feed_cursors.get(segment.number, 0)), available)

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
		var status := "INTERRUPTED" if segment.interrupted else ("COMPLETE" if segment.complete else "ACTIVE")
		takes.append("[WIRE TAKE %d | %s | NON-INK BOUNDARY]\n%s"
			% [segment.number, status, _render_ink(segment.events)])
	return "\n".join(takes)

## Viewer-facing strip: the paper feeds out only while the clockwork keeps up.
## Marks inked on a slack spring stay under the feed rollers until the register
## is wound, and the strip never rewinds — what has been fed out stays
## readable. The objective _record and get_tape_display_text() are untouched.
func get_tape_text_for_viewer() -> String:
	var takes: PackedStringArray = []
	for segment in _segments:
		var status := "INTERRUPTED" if segment.interrupted else ("COMPLETE" if segment.complete else "ACTIVE")
		var evs: Array[TapeInkEvent] = segment.events
		var visible_count := mini(int(_feed_cursors.get(segment.number, 0)), evs.size())
		if visible_count < evs.size():
			# Real backlog: these recorded marks are still under the rollers.
			var slice_events: Array[TapeInkEvent] = evs.slice(0, visible_count)
			takes.append("[WIRE TAKE %d | %s | NON-INK BOUNDARY]\n%s\n[SPRING SLACK — WIND REGISTER TO ADVANCE STRIP]"
				% [segment.number, status, _render_ink(slice_events)])
		else:
			takes.append("[WIRE TAKE %d | %s | NON-INK BOUNDARY]\n%s"
				% [segment.number, status, _render_ink(evs)])
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
