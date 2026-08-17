class_name MorseScheduledEvent
extends RefCounted

var event_index: int = 0
var kind: MorseTimingEvent.Kind = MorseTimingEvent.Kind.MARK
var duration_units: int = 0
var start_seconds: float = 0.0
var duration_seconds: float = 0.0
var end_seconds: float = 0.0

func _to_string() -> String:
	var kind_str := "MARK" if kind == MorseTimingEvent.Kind.MARK else "GAP"
	return "MorseScheduledEvent[%d: %s(%d) start=%.3f dur=%.3f end=%.3f]" % [
		event_index, kind_str, duration_units, start_seconds, duration_seconds, end_seconds
	]
