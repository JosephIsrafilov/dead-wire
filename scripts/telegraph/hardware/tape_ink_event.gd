class_name TapeInkEvent
extends RefCounted

## Ink already delivered to the strip, never a planned scheduler event.

var kind: MorseTimingEvent.Kind = MorseTimingEvent.Kind.MARK
var duration_units: float = 0.0
var duration_seconds: float = 0.0
var is_complete: bool = false
var interrupted: bool = false

func snapshot() -> TapeInkEvent:
	var copy := TapeInkEvent.new()
	copy.kind = kind
	copy.duration_units = duration_units
	copy.duration_seconds = duration_seconds
	copy.is_complete = is_complete
	copy.interrupted = interrupted
	return copy
