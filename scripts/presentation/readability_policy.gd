# scripts/presentation/readability_policy.gd
class_name ReadabilityPolicy
extends RefCounted

enum Mode { CLASSIC, READABLE, CLEAN }

static func profile(display_height: int, mode: int) -> Dictionary:
	var height := maxi(display_height, 1)
	var selected := clampi(mode, Mode.CLASSIC, Mode.CLEAN)
	var minimum := 360 if selected == Mode.CLASSIC else 720
	var divisor := 1 if selected == Mode.CLEAN else maxi(1, int(floor(float(height) / float(minimum))))
	return {
		"scale": 1.0 / float(divisor),
		"divisor": divisor,
		"levels": 32.0 if selected == Mode.CLASSIC else 64.0,
		"vignette": 0.30 if selected == Mode.CLASSIC else 0.12,
		"grade_enabled": selected != Mode.CLEAN,
	}
