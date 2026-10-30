extends SceneTree

## The register's paper moves (plan 4.5): the strip under the stylus is drawn
## from the register's own record - MARK and GAP and their durations, never
## text - newest ink at the stylus, older ink carried out toward the coil, and
## the coil grows as the night's paper winds onto it.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Strip View Test Suite ---")
	var script: Variant = load("res://scripts/telegraph/hardware/tape_strip_view.gd")
	if not _check(script != null, "The register has a strip view"): return

	var events: Array[TapeInkEvent] = []
	events.append(_ink(MorseTimingEvent.Kind.MARK, 0.1))
	events.append(_ink(MorseTimingEvent.Kind.GAP, 0.1))
	events.append(_ink(MorseTimingEvent.Kind.MARK, 0.3))
	var rows: PackedByteArray = script.render_rows(events, 40.0, 64)
	if not _check(rows[0] == 1 and rows[11] == 1, "The newest mark is inked at the stylus end"): return
	if not _check(rows[13] == 0 and rows[15] == 0, "The gap before it is clean paper"): return
	if not _check(rows[17] == 1 and rows[19] == 1, "The older mark has been carried along the strip"): return
	if not _check(rows[25] == 0 and rows[63] == 0, "Paper beyond the record is blank"): return

	events.append(_ink(MorseTimingEvent.Kind.GAP, 0.2))
	var moved: PackedByteArray = script.render_rows(events, 40.0, 64)
	if not _check(moved[0] == 0 and moved[9] == 1, "Time on the wire moves the paper even through a gap"): return

	if not _check(script.coil_radius(0.0) < script.coil_radius(600.0), "The coil grows as paper winds onto it"): return
	if not _check(script.coil_radius(1.0e7) <= 0.031, "The coil never outgrows the tray"): return

	await process_frame
	print("--- All Tape Strip View Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _ink(kind: MorseTimingEvent.Kind, seconds: float) -> TapeInkEvent:
	var ink := TapeInkEvent.new()
	ink.kind = kind
	ink.duration_seconds = seconds
	ink.is_complete = true
	return ink

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
