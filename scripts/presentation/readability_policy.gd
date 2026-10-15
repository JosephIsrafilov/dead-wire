# scripts/presentation/readability_policy.gd
class_name ReadabilityPolicy
extends RefCounted

enum Mode { CLASSIC, READABLE, CLEAN }

static func profile(display_height: int, mode: int) -> Dictionary:
	var height := maxi(display_height, 1)
	var selected := clampi(mode, Mode.CLASSIC, Mode.CLEAN)
	var minimum := 360 if selected == Mode.CLASSIC else 720
	var divisor := 1 if selected == Mode.CLEAN else maxi(1, int(floor(float(height) / float(minimum))))
	# READABLE never samples a cell larger than its render divisor: spatial
	# detail is already spent by the divisor, and the grade only adds color
	# depth and dither. CLASSIC keeps the strong minimum-2 PSX cell.
	var pixel_size := 1 if selected == Mode.CLEAN else (divisor if selected == Mode.READABLE else maxi(divisor, 2))
	return {
		"scale": 1.0 / float(divisor),
		"divisor": divisor,
		"pixel_size": pixel_size,
		"levels": 32.0 if selected == Mode.CLASSIC else 64.0,
		"vignette": 0.30 if selected == Mode.CLASSIC else 0.20,
		"grade_enabled": selected != Mode.CLEAN,
	}
