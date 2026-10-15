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
	# The effective sampling cell (max(divisor, pixel_size)) may never enlarge
	# READABLE beyond its render divisor: every screen line survives.
	for height in [720, 1080, 1440, 2160]:
		var readable: Dictionary = policy.profile(height, 1)
		var cell: int = maxi(int(readable.divisor), int(readable.pixel_size))
		var rows: int = int(floor(float(height) / float(cell)))
		if not require(int(readable.pixel_size) >= 1 and int(readable.pixel_size) <= int(readable.divisor),
				"Readable pixel_size never exceeds the render divisor at %d (divisor %d, pixel_size %d)"
					% [height, readable.divisor, readable.pixel_size]): return
		if not require(height < 720 or rows >= 720,
				"Readable keeps at least 720 effective vertical samples at %d (got %d)" % [height, rows]): return
	var readable_720: Dictionary = policy.profile(720, 1)
	var readable_1080: Dictionary = policy.profile(1080, 1)
	if not require(int(readable_720.divisor) == 1 and int(readable_720.pixel_size) == 1,
			"Readable at 720 samples every screen line (divisor 1, cell 1)"): return
	if not require(int(readable_1080.divisor) == 1 and int(readable_1080.pixel_size) == 1,
			"Readable at 1080 samples every screen line (divisor 1, cell 1)"): return
	# CLASSIC keeps its strong pixelation; CLEAN stays native.
	for height in [720, 1080, 1440, 2160]:
		if not require(int(policy.profile(height, 0).pixel_size) >= 2,
				"Classic keeps a strong sampling cell at %d" % height): return
		if not require(int(policy.profile(height, 2).pixel_size) == 1,
				"Clean samples natively at %d" % height): return
	# A tiny window must not add degradation beyond the policy minimums.
	var tiny: Dictionary = policy.profile(320, 1)
	if not require(tiny.scale <= 1.0 and int(tiny.divisor) >= 1 and int(tiny.pixel_size) >= 1,
			"A small window degrades no further than the policy minimums"): return
	print("Readability policy assertions: ", passed)
	quit(0)
