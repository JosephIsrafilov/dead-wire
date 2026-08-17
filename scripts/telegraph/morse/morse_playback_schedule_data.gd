class_name MorsePlaybackScheduleData
extends RefCounted

var events: Array[MorseScheduledEvent] = []
var total_duration_seconds: float = 0.0

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if events.is_empty():
		errors.append("Schedule events array cannot be empty")
		return errors

	if events[0].kind != MorseTimingEvent.Kind.MARK:
		errors.append("First scheduled event must be MARK")

	if events[events.size() - 1].kind != MorseTimingEvent.Kind.MARK:
		errors.append("Last scheduled event must be MARK")

	if not is_equal_approx(events[0].start_seconds, 0.0):
		errors.append("First scheduled event start_seconds must be 0.0, got %f" % events[0].start_seconds)

	for i in range(events.size()):
		var ev: MorseScheduledEvent = events[i]
		if ev == null:
			errors.append("Scheduled event at index %d is null" % i)
			continue

		if ev.event_index != i:
			errors.append("Scheduled event at index %d has mismatched event_index %d" % [i, ev.event_index])

		if ev.duration_units <= 0:
			errors.append("Scheduled event %d must have duration_units > 0, got %d" % [i, ev.duration_units])

		if ev.duration_seconds <= 0.0 or not is_finite(ev.duration_seconds):
			errors.append("Scheduled event %d duration_seconds must be positive finite, got %f" % [i, ev.duration_seconds])

		if not is_finite(ev.start_seconds) or ev.start_seconds < 0.0:
			errors.append("Scheduled event %d start_seconds must be non-negative finite, got %f" % [i, ev.start_seconds])

		if not is_finite(ev.end_seconds) or not is_equal_approx(ev.end_seconds, ev.start_seconds + ev.duration_seconds):
			errors.append("Scheduled event %d end_seconds (%f) does not match start + duration (%f)" % [i, ev.end_seconds, ev.start_seconds + ev.duration_seconds])

		if i > 0:
			var prev_ev: MorseScheduledEvent = events[i - 1]
			if prev_ev != null:
				if ev.kind == prev_ev.kind:
					errors.append("Scheduled events %d and %d have identical kind (strictly alternating invariant violated)" % [i - 1, i])
				if not is_equal_approx(ev.start_seconds, prev_ev.end_seconds):
					errors.append("Timeline discontinuity between event %d (end %f) and event %d (start %f)" % [i - 1, prev_ev.end_seconds, i, ev.start_seconds])

	var expected_total: float = events[events.size() - 1].end_seconds if not events.is_empty() and events[events.size() - 1] != null else 0.0
	if not is_equal_approx(total_duration_seconds, expected_total):
		errors.append("total_duration_seconds (%f) does not match last event end_seconds (%f)" % [total_duration_seconds, expected_total])

	return errors
