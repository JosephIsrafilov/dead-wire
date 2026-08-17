class_name MorseScheduleCompiler
extends RefCounted

func get_compilation_errors(
	sequence: MorseSequenceData,
	profile: MorsePlaybackProfileData
) -> PackedStringArray:
	var errors := PackedStringArray()

	if sequence == null:
		errors.append("Sequence cannot be null")
	else:
		var seq_errors := sequence.get_validation_errors()
		for err in seq_errors:
			errors.append("Invalid sequence: %s" % err)

	if profile == null:
		errors.append("Profile cannot be null")
	else:
		var prof_errors := profile.get_validation_errors()
		for err in prof_errors:
			errors.append("Invalid profile: %s" % err)

	return errors

func compile(
	sequence: MorseSequenceData,
	profile: MorsePlaybackProfileData
) -> MorsePlaybackScheduleData:
	var errors := get_compilation_errors(sequence, profile)
	if not errors.is_empty():
		return null

	var schedule := MorsePlaybackScheduleData.new()
	var scheduled_events: Array[MorseScheduledEvent] = []
	var current_time: float = 0.0
	var spu: float = profile.seconds_per_unit

	for i in range(sequence.events.size()):
		var ev: MorseTimingEvent = sequence.events[i]
		var sched_ev := MorseScheduledEvent.new()
		sched_ev.event_index = i
		sched_ev.kind = ev.kind
		sched_ev.duration_units = ev.duration_units
		sched_ev.start_seconds = current_time
		sched_ev.duration_seconds = float(ev.duration_units) * spu
		sched_ev.end_seconds = sched_ev.start_seconds + sched_ev.duration_seconds

		current_time = sched_ev.end_seconds
		scheduled_events.append(sched_ev)

	schedule.events = scheduled_events
	schedule.total_duration_seconds = current_time

	return schedule
