extends SceneTree
## E01: optional footsteps must never overlap the next critical Morse MARK.
## godot --headless --audio-driver Dummy --path . --script tests/audio/foley_timing_fairness_test.gd

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Foley Timing Fairness Test Suite (E01) ---")
	var door := DoorAttentionSource.new()
	if not door.has_method("can_fit_foley"):
		print("  FAIL: Door considers the whole sample duration")
		door.free()
		quit(1)
		return

	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	door.scheduler = scheduler
	var alphabet := load("res://data/morse/m1_american_morse_alphabet.tres") as AmericanMorseAlphabetData
	var profile := load("res://data/morse/m1_morse_playback_profile.tres") as MorsePlaybackProfileData
	var schedule := MorseScheduleCompiler.new().compile(AmericanMorseEncoder.new().encode("E E", alphabet), profile)
	scheduler.start(schedule)

	_check(not door.can_fit_foley(0.01), "Foley cannot start during MARK")
	scheduler.advance_time(0.1)
	_check(door.can_fit_foley(0.40), "Short sample plus margin fits the word gap")
	_check(not door.can_fit_foley(0.55), "Sample tail plus margin cannot hit the next MARK")
	scheduler.advance_time(0.3)
	_check(not door.can_fit_foley(0.40), "Late in the gap a previously safe sample must wait")
	scheduler.cancel()
	_check(door.can_fit_foley(1.0), "An idle wire admits optional foley")

	_check_boundaries_and_integration()

	door.free()
	scheduler.free()
	print("--- Foley Timing Fairness Tests %s ---" % ("FAILED" if _failed else "PASSED"))
	quit(1 if _failed else 0)

func _check_boundaries_and_integration() -> void:
	var door := DoorAttentionSource.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	door.scheduler = scheduler
	var alphabet := load("res://data/morse/m1_american_morse_alphabet.tres") as AmericanMorseAlphabetData
	var profile := load("res://data/morse/m1_morse_playback_profile.tres") as MorsePlaybackProfileData
	var schedule := MorseScheduleCompiler.new().compile(AmericanMorseEncoder.new().encode("E E", alphabet), profile)
	scheduler.start(schedule)
	scheduler.advance_time(0.1)
	var gap_end := scheduler.get_current_event().end_seconds
	var elapsed := scheduler.get_elapsed_seconds()
	var exact_fit := gap_end - elapsed - DoorAttentionSource.FOLEY_SAFETY_MARGIN
	_check(door.can_fit_foley(exact_fit), "Sample ending exactly at margin boundary fits")
	_check(not door.can_fit_foley(exact_fit + 0.01), "Sample 10ms past margin boundary does not fit")
	_check(not door.can_fit_foley(-0.1) and not door.can_fit_foley(INF) and not door.can_fit_foley(NAN), "Invalid durations are rejected")
	_check(is_equal_approx(scheduler.get_elapsed_seconds(), elapsed), "Fit queries never mutate the scheduler clock")

	# Real sample tail: the first step of a fresh burst must wait when its whole sample cannot fit.
	scheduler.cancel()
	scheduler.start(schedule)
	scheduler.advance_time(gap_end - 0.05 - scheduler.get_elapsed_seconds())
	var sample_len := door.footstep_sound.get_length()
	var late_gap_fits := door.can_fit_foley(sample_len / 0.84)
	_check(not late_gap_fits, "Real footstep tail near gap end is refused")

	# Integration: a trigger inside a MARK defers the step; no MARK overlap at start.
	scheduler.cancel()
	scheduler.start(schedule)
	door.trigger_footsteps()
	_check(door.steps_played == 0 and door.is_active, "Trigger during MARK defers the first step")

	# Duplicate binding must not double-connect the MARK listener.
	door._bind_fairness()
	door._bind_fairness()
	_check(scheduler.timing_event_started.get_connections().size() == 1, "Fairness binds the scheduler exactly once")

	# Swapping the scheduler rebinds and disconnects the old one.
	var other := MorseRuntimeScheduler.new()
	door.scheduler = other
	door._bind_fairness()
	_check(scheduler.timing_event_started.get_connections().size() == 0, "Old scheduler listener is released on rebind")
	other.free()
	scheduler.cancel()
	door.free()
	scheduler.free()

func _check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	_failed = _failed or not ok
