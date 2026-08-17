class_name MorseSequenceData
extends Resource

@export var events: Array[MorseTimingEvent] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if events.is_empty():
		errors.append("Sequence cannot be empty")
		return errors
	
	for i in range(events.size()):
		var ev := events[i]
		if ev == null:
			errors.append("Event at index %d is null" % i)
			continue
		var ev_errors := ev.get_validation_errors()
		for err in ev_errors:
			errors.append("Event at index %d error: %s" % [i, err])
	
	# If any event is null or has invalid kind, alternating/boundary checks might fail or be undefined,
	# but we check boundaries and alternation systematically where events exist.
	if events[0] != null and events[0].kind != MorseTimingEvent.Kind.MARK:
		errors.append("Sequence must start with a MARK event")
	
	if events[events.size() - 1] != null and events[events.size() - 1].kind != MorseTimingEvent.Kind.MARK:
		errors.append("Sequence must end with a MARK event")
	
	for i in range(events.size() - 1):
		var curr := events[i]
		var next := events[i + 1]
		if curr != null and next != null:
			if curr.kind == next.kind:
				errors.append("Consecutive events at index %d and %d have the same kind: %s" % [i, i + 1, str(curr.kind)])
	
	return errors

func total_duration_units() -> int:
	var total: int = 0
	for ev in events:
		if ev != null:
			total += ev.duration_units
	return total
