class_name TapeRegisterController
extends Node

## The paper-tape register (design doc §4): a mechanical recorder that inks
## every MARK/GAP of the objective scheduler timeline onto a continuously
## fed paper strip. It is the sounder's silent twin — same signals, no sound,
## and NO access to message text whatsoever: it cannot lie by construction.

var _record: Array[MorseScheduledEvent] = []
var _connected_scheduler: MorseRuntimeScheduler = null

func get_record() -> Array[MorseScheduledEvent]:
	return _record

func connect_scheduler(scheduler: MorseRuntimeScheduler) -> void:
	if scheduler == null:
		return
	disconnect_scheduler()
	_connected_scheduler = scheduler
	if not scheduler.timing_event_started.is_connected(_on_timing_event_started):
		scheduler.timing_event_started.connect(_on_timing_event_started)

func disconnect_scheduler() -> void:
	if _connected_scheduler == null:
		return
	if _connected_scheduler.timing_event_started.is_connected(_on_timing_event_started):
		_connected_scheduler.timing_event_started.disconnect(_on_timing_event_started)
	_connected_scheduler = null

func reset() -> void:
	_record.clear()

func _on_timing_event_started(event: MorseScheduledEvent) -> void:
	_record.append(event)

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
