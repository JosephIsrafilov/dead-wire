# scripts/presentation/readability_policy.gd
class_name ReadabilityPolicy
extends RefCounted

## The whole frame shares one render grid. Window stretch owns the integer
## upscale; a second 3D reduction or screen-space sampling grid would spend
## the same detail twice. CLEAN keeps native rendering for accessibility.
enum Mode { CLASSIC, READABLE, CLEAN }

const INTERNAL_SIZE := Vector2i(960, 540)

static func profile(display_height: int, mode: int) -> Dictionary:
	var height := maxi(display_height, 1)
	var selected := clampi(mode, Mode.CLASSIC, Mode.CLEAN)
	var lines := mini(height, INTERNAL_SIZE.y)
	var content_size := Vector2i(maxi(1, lines * INTERNAL_SIZE.x / INTERNAL_SIZE.y), lines)
	return {
		"content_size": Vector2i.ZERO if selected == Mode.CLEAN else content_size,
		"integer_scale": maxi(1, height / lines),
		"scale": 1.0,
		"divisor": 1,
		"pixel_size": 1,
		"levels": 48.0 if selected == Mode.CLASSIC else 64.0,
		"vignette": 0.26 if selected == Mode.CLASSIC else 0.20,
		"grade_enabled": selected != Mode.CLEAN,
	}
