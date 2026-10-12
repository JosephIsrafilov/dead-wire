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
	var path := "res://scripts/presentation/readability_policy.gd"
	if not require(FileAccess.file_exists(path), "Readability policy script exists"): return
	var policy = load(path)
	var a: Dictionary = policy.profile(720, 1)
	if not require(is_equal_approx(a.scale, 1.0), "Readable720 uses native720, not360 lines"): return
	var b: Dictionary = policy.profile(1080, 1)
	if not require(is_equal_approx(b.scale, 1.0), "Readable1080 keeps integer native scale"): return
	var c: Dictionary = policy.profile(1440, 1)
	if not require(is_equal_approx(c.scale, 0.5), "Readable1440 uses 2x nearest upscale"): return
	var d: Dictionary = policy.profile(2160, 1)
	if not require(is_equal_approx(d.scale, 1.0 / 3.0), "Readable4K retains 720 internal lines"): return
	if not require(is_equal_approx(policy.profile(720, 0).scale, 0.5), "Classic remains optional 360-line mode"): return
	if not require(is_equal_approx(policy.profile(1080, 2).scale, 1.0), "Clean uses full native rendering"): return
	if not require(policy.profile(0, 1).scale == 1.0, "Invalid height cannot divide by zero"): return
	if not require(policy.profile(1080, 1).levels >= 64.0, "Readable grade does not crush small text to 32 levels"): return
	if not require(policy.profile(1080, 2).grade_enabled == false, "Clean can disable screen grade"): return
	print("Readability policy assertions: ", passed)
	quit(0)
