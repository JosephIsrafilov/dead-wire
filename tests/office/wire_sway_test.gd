extends SceneTree

## The wires outside sway a little in the wind (plan 3.9): they move, never
## further than a few millimetres, and never in step with each other.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Wire Sway Test Suite ---")
	var holder := Node3D.new()
	root.add_child(holder)
	for wire_name in ["ExteriorWireHigh", "ExteriorWireLow"]:
		var wire := Node3D.new()
		wire.name = wire_name
		holder.add_child(wire)
	var sway := WireSway.new()
	holder.add_child(sway)
	sway.set_process(false)
	var moved := false
	var widest := 0.0
	var apart := false
	for _step in 400:
		sway.advance(0.05)
		var a := sway.get_offset(0)
		var b := sway.get_offset(1)
		moved = moved or a > 0.001
		widest = maxf(widest, maxf(a, b))
		apart = apart or absf(a - b) > 0.002
	if not _check(moved, "The wires move in the wind"): return
	if not _check(widest <= sway.lift_metres + 0.0001, "Never more than a few millimetres (%.4f m)" % widest): return
	if not _check(apart, "The two wires are not in step"): return
	holder.queue_free()
	await process_frame
	print("--- All Wire Sway Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
