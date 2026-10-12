extends SceneTree
## Bounded responsiveness defaults stay distinct from physical approach and intro presentation.
## godot --headless --audio-driver Dummy --path . --script tests/interaction/bounded_responsiveness_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seat := OperatorSeat.new()
	_check(is_equal_approx(seat.approach_duration, 0.34), "Seat approach retains its physical 0.34-second glide")
	_check(is_equal_approx(seat.sit_duration, 0.45), "Seat head settle is bounded to 0.45 seconds")
	_check(is_equal_approx(seat.stand_duration, 0.45), "Standing transition is bounded to 0.45 seconds")
	seat.free()

	var viewer := DocumentViewer.new()
	_check(is_equal_approx(viewer.open_duration, 0.16), "Document lift-in is bounded to 0.16 seconds")
	viewer.free()

	var intro := IntroCard.new()
	_check(is_equal_approx(intro.skip_fade_duration, 0.35), "Explicit intro skip has its own 0.35-second transition")
	_check(is_equal_approx(intro.fade_duration, 2.2), "Normal intro fade retains its authored presentation")
	intro.free()
	quit(1 if _failures else 0)

var _failures := 0
func _check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		_failures += 1
