extends SceneTree

## A draft shakes the flame (plan 2.8): when the door opens the lamp's light
## shivers harder for a breath and then settles back to its ordinary flicker.
## A physical cause the player can see - the door - never the Listener.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Lamp Draft Test Suite ---")
	var holder := Node.new()
	root.add_child(holder)
	var light := OmniLight3D.new()
	light.light_energy = 2.0
	holder.add_child(light)
	var lamp := LampLife.new()
	lamp.lamp_light = light
	lamp.start_turned_down = false
	holder.add_child(lamp)
	lamp.set_process(false)
	lamp.set_wick_immediate(1.0)

	var calm := _swing(lamp, light, 2.0)
	if not _check(lamp.has_method("gust"), "The lamp can be caught by a draft"): return
	lamp.gust(1.0)
	var gusty := _swing(lamp, light, 0.8)
	if not _check(gusty > calm * 1.8, "A draft makes the light shiver harder (%.3f vs %.3f)" % [gusty, calm]): return
	_swing(lamp, light, lamp.draft_seconds + 0.5)
	var settled := _swing(lamp, light, 2.0)
	if not _check(settled < calm * 1.2, "It settles back to its ordinary flicker (%.3f)" % settled): return

	holder.queue_free()
	await process_frame
	print("--- All Lamp Draft Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

## The widest swing of the light's energy over `seconds`.
func _swing(lamp: LampLife, light: OmniLight3D, seconds: float) -> float:
	var lo := INF
	var hi := -INF
	var left := seconds
	while left > 0.0:
		lamp.advance(1.0 / 60.0)
		lo = minf(lo, light.light_energy)
		hi = maxf(hi, light.light_energy)
		left -= 1.0 / 60.0
	return hi - lo

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
