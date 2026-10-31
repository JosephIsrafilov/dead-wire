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

	# Plan 8.5: the wick wheel turns with the hand that turns the wick, and
	# only then — a wick charring down on its own leaves the wheel where it was.
	var wheel := Node3D.new()
	holder.add_child(wheel)
	lamp.wick_wheel = wheel
	lamp.set_wick_immediate(0.3)
	lamp.turn_up_wick()
	_swing(lamp, light, lamp.wick_turn_seconds * 0.5)
	var halfway := absf(wheel.rotation.x)
	_swing(lamp, light, lamp.wick_turn_seconds * 0.6)
	var turned := absf(wheel.rotation.x)
	if not _check(turned > PI * 0.5, "Turning the wick up turns its wheel (%.0f deg)" % rad_to_deg(turned)): return
	if not _check(halfway > turned * 0.3 and halfway < turned * 0.7, "The wheel turns with the wick, not in one jump"): return
	var before_char := wheel.rotation.x
	lamp.gutter(0.6, 1.0)
	_swing(lamp, light, 1.5)
	if not _check(is_equal_approx(wheel.rotation.x, before_char), "A wick charring down does not turn the wheel"): return
	lamp.turn_down_wick()
	_swing(lamp, light, lamp.wick_turn_seconds + 0.1)
	if not _check(signf(wheel.rotation.x - before_char) == -signf(before_char), "Turning it down turns the wheel back"): return
	var lamp_scene: Node3D = load("res://scenes/style_tests/props/oil_lamp_lowpoly.tscn").instantiate()
	holder.add_child(lamp_scene)
	if not _check(lamp_scene.get_node_or_null("WickWheelPivot/AuthoredWickWheel") is MeshInstance3D,
		"The lamp's wick wheel is a part of its own on its spindle"): return

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
