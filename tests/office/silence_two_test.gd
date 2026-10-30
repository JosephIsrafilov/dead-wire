extends SceneTree

## Silence 2 teaches the window (plan 4.1): an ordinary cloud crosses the moon
## (the light in the room dims, the cloud is in the sky) and the sash creaks
## once, from the window. Nothing threatens; it happens once, only in silence 2,
## and it is weather - never the authored cloud consequence.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Silence Two Test Suite ---")
	var script: Variant = load("res://scripts/office/silence_two.gd")
	if not _check(script != null, "Silence two has a script"): return
	var holder := Node3D.new()
	root.add_child(holder)
	var light := SpotLight3D.new()
	light.light_energy = 2.0
	holder.add_child(light)
	var moon := MoonWeather.new()
	moon.moon_light = light
	holder.add_child(moon)
	moon.set_process(false)
	moon._until_cloud = 9999.0
	var silence: Node = script.new()
	silence.moon = moon
	holder.add_child(silence)
	silence.set_process(false)

	for slot in [0, 2]:
		silence.update(slot, 30.0, 38.0)
	if not _check(not moon.is_dimmed_now() and silence.creaks_played == 0, "Silences 1 and 3 are not taught this way"): return
	silence.update(1, 5.0, 38.0)
	if not _check(not moon.is_dimmed_now(), "Silence 2 begins clear"): return
	silence.update(1, silence.cloud_after_seconds + 0.1, 38.0)
	if not _check(moon.is_dimmed_now(), "In silence 2 a cloud crosses the moon"): return
	if not _check(not moon.is_consequence_running(), "It is weather, not the authored cloud consequence"): return
	if not _check(silence.creaks_played == 1, "The sash creaks once from the window"): return
	for _step in int(silence.cloud_hold_seconds * 10.0) + 30:
		moon.advance(0.1)
	if not _check(not moon.is_dimmed_now(), "The cloud passes"): return
	silence.update(1, silence.cloud_after_seconds + 2.0, 38.0)
	if not _check(silence.creaks_played == 1 and not moon.is_dimmed_now(), "It happens once a night"): return

	holder.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Silence Two Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
