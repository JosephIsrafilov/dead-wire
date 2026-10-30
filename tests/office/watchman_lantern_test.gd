extends SceneTree

## The watchman's lantern is the yard's ordinary life: it walks the mine fence
## and back, stops now and then, never comes near the window or the figure's
## column, and goes out once the dawn is up.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Watchman Lantern Test Suite ---")
	var script: Variant = load("res://scripts/office/watchman_lantern.gd")
	if not _check(script != null, "The watchman's lantern has a script"): return
	var lantern: Node3D = script.new()
	root.add_child(lantern)
	var xs: Array[float] = []
	var still_steps := [0]
	var last := lantern.position
	for _step in 1200:
		lantern.advance(0.1, 0.0)
		xs.append(lantern.position.x)
		if lantern.position.distance_to(last) < 0.0001:
			still_steps[0] += 1
		last = lantern.position
	var lo: float = xs.min()
	var hi: float = xs.max()
	if not _check(hi - lo > 4.0, "It walks the fence (%.1f m of travel)" % (hi - lo)): return
	if not _check(lo >= lantern.walk_from.x - 0.01 and hi <= lantern.walk_to.x + 0.01, "It stays on its beat"): return
	if not _check(still_steps[0] > 20, "It stops now and then"): return
	if not _check(lantern.walk_to.x < -4.0 and lantern.position.z < -10.0, "It keeps clear of the window and the figure's column"): return
	if not _check(lantern.is_lit(), "It burns through the night"): return
	for _step in 40:
		lantern.advance(0.1, 1.0)
	if not _check(not lantern.is_lit(), "It is put out once the dawn is up"): return
	lantern.queue_free()
	await process_frame
	print("--- All Watchman Lantern Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
