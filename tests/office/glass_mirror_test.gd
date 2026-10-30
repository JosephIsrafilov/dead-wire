extends SceneTree

## Lamp against window (owner's decision, plan 3.7): the brighter the wick, the
## more the north pane is a dark mirror of the warm room and the less of the
## yard comes through; turning the lamp down, or putting a face to the glass,
## gives the yard back. Visibility is monotone in both, and the extremes are
## what the plan names.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Glass Mirror Test Suite ---")
	var script: Variant = load("res://scripts/office/window_glass_mirror.gd")
	if not _check(script != null, "The window glass has a mirror controller"): return

	var monotone_wick := true
	var previous := 2.0
	for step in 11:
		var v: float = script.yard_visibility(step / 10.0, 0.0)
		if v > previous + 0.00001:
			monotone_wick = false
		previous = v
	if not _check(monotone_wick, "A brighter wick never shows more of the yard"): return

	var monotone_lean := true
	previous = -1.0
	for step in 11:
		var v: float = script.yard_visibility(1.0, step / 10.0)
		if v < previous - 0.00001:
			monotone_lean = false
		previous = v
	if not _check(monotone_lean, "Leaning closer never shows less of the yard"): return

	if not _check(script.yard_visibility(1.0, 0.0) < 0.35, "Lamp full, sitting back: the pane is a mirror"): return
	if not _check(script.yard_visibility(0.3, 0.0) > 0.8, "Lamp turned down: the yard reads"): return
	if not _check(script.yard_visibility(1.0, 1.0) > 0.6, "Lamp full, face at the glass: the yard reads"): return

	var clear := StandardMaterial3D.new()
	var mirror := StandardMaterial3D.new()
	script.apply_to(clear, 1.0)
	script.apply_to(mirror, 0.1)
	if not _check(mirror.albedo_color.a > clear.albedo_color.a and mirror.metallic > clear.metallic,
			"A mirror pane is more opaque and more reflective than a clear one"): return

	print("--- All Glass Mirror Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
