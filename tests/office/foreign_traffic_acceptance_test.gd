extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var director := ShiftDirector.new()
	director._slot_index = director.foreign_traffic_slot
	director._phase_timer = director.foreign_traffic_after_seconds
	director._maybe_foreign_traffic()
	var ok := not director.foreign_traffic_played
	print(("  PASS: " if ok else "  FAIL: ") + "Rejected foreign traffic does not consume its played flag")
	director.free()
	quit(0 if ok else 1)
