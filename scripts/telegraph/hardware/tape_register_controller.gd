class_name TapeRegisterController
extends Node3D

## The paper-tape register (design doc §4): a mechanical recorder that inks
## every MARK/GAP of the objective scheduler timeline onto a continuously
## fed paper strip. It is the sounder's silent twin — same signals, no sound,
## and NO access to message text whatsoever: it cannot lie by construction.

## The operator lifted the strip to the lamp. The payload is raw marks only;
## reading and comparing with the transcript is the player's own work.
signal tape_inspected(text: String)

const TAPE_DOC_ID := "tape_register"
const TAPE_TITLE := "STATION REGISTER"

## Placeholder that visually separates transmissions on the strip; real pause
## length comes later from shift pacing.
const BETWEEN_TRANSMISSIONS_GAP_UNITS := 12

@export var prompt_message: String = "Read Tape Register"
## The inking stylus drops onto the tape on every MARK and lifts on every GAP —
## driven by the same scheduler events it records, so what it is seen to do is
## exactly what it wrote. Cosmetic only: the record never reads it back.
@export var stylus_travel: float = 0.003
@export var stylus_speed: float = 0.25
## The spool turns while the register is on the line: the tape always crawls.
@export var spool_turn_rate: float = 0.5

var _stylus: Node3D = null
var _stylus_rest_y: float = 0.0
var _stylus_target_y: float = 0.0
var _spool: Node3D = null

var interactable: Interactable = null

var _record: Array[MorseScheduledEvent] = []
var _connected_scheduler: MorseRuntimeScheduler = null

func _ready() -> void:
	_stylus = get_node_or_null("Body/StylusPivot") as Node3D
	if _stylus != null:
		_stylus_rest_y = _stylus.position.y
		_stylus_target_y = _stylus_rest_y
	_spool = get_node_or_null("Body/Spool") as Node3D
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
	tape_inspected.emit(get_tape_text())

func get_record() -> Array[MorseScheduledEvent]:
	return _record

func connect_scheduler(scheduler: MorseRuntimeScheduler) -> void:
	if scheduler == null:
		return
	disconnect_scheduler()
	_connected_scheduler = scheduler
	if not scheduler.timing_event_started.is_connected(_on_timing_event_started):
		scheduler.timing_event_started.connect(_on_timing_event_started)
	if not scheduler.playback_completed.is_connected(_on_playback_completed):
		scheduler.playback_completed.connect(_on_playback_completed)
	if not scheduler.playback_cancelled.is_connected(_on_playback_cancelled):
		scheduler.playback_cancelled.connect(_on_playback_cancelled)

func disconnect_scheduler() -> void:
	if _connected_scheduler == null:
		return
	if _connected_scheduler.timing_event_started.is_connected(_on_timing_event_started):
		_connected_scheduler.timing_event_started.disconnect(_on_timing_event_started)
	if _connected_scheduler.playback_completed.is_connected(_on_playback_completed):
		_connected_scheduler.playback_completed.disconnect(_on_playback_completed)
	if _connected_scheduler.playback_cancelled.is_connected(_on_playback_cancelled):
		_connected_scheduler.playback_cancelled.disconnect(_on_playback_cancelled)
	_connected_scheduler = null

func reset() -> void:
	_record.clear()

func _on_timing_event_started(event: MorseScheduledEvent) -> void:
	_record.append(event)
	_stylus_target_y = _stylus_rest_y - (stylus_travel if event.kind == MorseTimingEvent.Kind.MARK else 0.0)

func _process(delta: float) -> void:
	if _stylus != null:
		_stylus.position.y = move_toward(_stylus.position.y, _stylus_target_y, stylus_speed * delta)
	if _spool != null and _connected_scheduler != null:
		_spool.rotate_object_local(Vector3.UP, spool_turn_rate * delta)

func _on_playback_completed(_schedule: MorsePlaybackScheduleData) -> void:
	_stylus_target_y = _stylus_rest_y
	var gap := MorseScheduledEvent.new()
	gap.kind = MorseTimingEvent.Kind.GAP
	gap.duration_units = BETWEEN_TRANSMISSIONS_GAP_UNITS
	_record.append(gap)

## No between-gap here: a cancelled transmission may resume or restart, so
## only the synthetic separator is withheld — the partial ink stays.
func _on_playback_cancelled(_schedule: MorsePlaybackScheduleData, _elapsed_seconds: float) -> void:
	_stylus_target_y = _stylus_rest_y

## Ink rendering. MARK <= 2 units is a dot, >= 3 units is a dash; every GAP
## unit is one blank column — exactly how paper strips looked, and exactly
## as readable with the Morse reference card.
func get_tape_text() -> String:
	var out := ""
	for event in _record:
		if event.kind == MorseTimingEvent.Kind.MARK:
			out += "·" if event.duration_units <= 2 else "—"
		else:
			out += " ".repeat(maxi(event.duration_units, 1))
	return out
