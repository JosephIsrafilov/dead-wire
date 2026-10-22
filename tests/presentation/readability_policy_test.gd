# tests/presentation/readability_policy_test.gd
extends SceneTree

var passed := 0

func _init() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true

func _run() -> void:
	var policy = load("res://scripts/presentation/readability_policy.gd")
	if not require(policy != null, "Readability policy loads"): return
	for height in [540, 720, 1080, 1440, 2160, 4320]:
		for mode in [0, 1]:
			var profile: Dictionary = policy.profile(height, mode)
			if not require(profile.get("content_size", Vector2i.ZERO) == Vector2i(960, 540),
					"Mode %d keeps a 960x540 frame at %d" % [mode, height]): return
			if not require(int(profile.get("integer_scale", 0)) == maxi(1, height / 540),
					"Mode %d uses an integer fit at %d" % [mode, height]): return
			if not require(profile.scale == 1.0 and int(profile.pixel_size) == 1,
					"Mode %d grades the render grid once at %d" % [mode, height]): return
			if not require(profile.grade_enabled,
					"Mode %d keeps its grade at %d" % [mode, height]): return
		var clean: Dictionary = policy.profile(height, 2)
		if not require(clean.get("content_size", Vector2i.ZERO) == Vector2i.ZERO
				and clean.scale == 1.0 and not clean.grade_enabled,
				"CLEAN renders natively without a grade at %d" % height): return
	for height in [0, 1, 320]:
		var tiny: Dictionary = policy.profile(height, 1)
		var size: Vector2i = tiny.get("content_size", Vector2i.ZERO)
		if not require(size.x > 0 and size.y > 0 and size.y <= maxi(height, 1),
				"A small window does not render above its native height: %d" % height): return
		if not require(tiny.scale == 1.0 and int(tiny.get("integer_scale", 0)) == 1,
				"A small window cannot divide by zero or add a second reduction: %d" % height): return
	if not require(not policy.profile(1080, 99).grade_enabled, "Invalid high modes clamp to CLEAN"): return
	if not require(policy.profile(1080, -1).grade_enabled, "Invalid low modes clamp to CLASSIC"): return
	print("Readability policy assertions: ", passed)
	quit(0)
