class_name MorseTimingEvent
extends Resource

enum Kind {
	MARK,
	GAP,
}

@export var kind: Kind = Kind.MARK
@export var duration_units: int = 1

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if kind != Kind.MARK and kind != Kind.GAP:
		errors.append("Invalid event kind: %s" % str(kind))
	if duration_units <= 0:
		errors.append("duration_units must be greater than 0, got %d" % duration_units)
	return errors
