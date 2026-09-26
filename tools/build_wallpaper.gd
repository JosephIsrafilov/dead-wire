extends SceneTree

## Generates the office's upper-wall paper: a tired 1890s stripe with a small
## diamond sprig between the stripes, darkened by lamp soot and water streaks.
##
##   godot --headless --path . --script tools/build_wallpaper.gd
##
## 128x128, tileable in both axes (the noise is seamless, the pattern is on an
## integer grid), nearest-sampled like every other PSX texture. Deterministic.

const SIZE := 128
const OUT := "res://materials/style_tests/textures/psx/psx_wallpaper_stripe_128.png"

const BASE := Color(0.40, 0.36, 0.26)
const STRIPE := Color(0.30, 0.27, 0.20)
const PIN := Color(0.52, 0.45, 0.30)
const SPRIG := Color(0.47, 0.40, 0.27)

func _initialize() -> void:
	var grime := FastNoiseLite.new()
	grime.seed = 1894
	grime.frequency = 0.035
	grime.fractal_octaves = 4
	var grime_img := grime.get_seamless_image(SIZE, SIZE)
	var streak := FastNoiseLite.new()
	streak.seed = 1889
	streak.frequency = 0.09
	var streak_img := streak.get_seamless_image(SIZE, SIZE)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			# Four stripe periods across the tile: wide field, dark band, gold pin.
			var sx := x % 32
			var c := BASE
			if sx >= 20 and sx < 28:
				c = STRIPE
			elif sx == 19 or sx == 28:
				c = PIN
			else:
				# Diamond sprig centred in each field, staggered row to row.
				var cx := 9.5
				var row := int(y / 16)
				var cy := 8.0 + (4.0 if row % 2 == 1 else 0.0)
				var dx := absf(float(sx) - cx)
				var dy := absf(float((y % 16)) - fmod(cy, 16.0))
				var d := dx + dy
				if d <= 3.0 and d > 1.5:
					c = SPRIG
				elif d <= 0.5:
					c = PIN
			# Soot and damp: broad grime plus vertical streaks from the ceiling.
			var g := grime_img.get_pixel(x, y).r
			var s := streak_img.get_pixel(x, (y / 8) % SIZE).r
			var shade := 0.78 + 0.30 * g - 0.18 * maxf(s - 0.55, 0.0) * 2.0
			# Per-texel paper grain, deterministic.
			var grain := (float((x * 73 + y * 151) % 17) / 17.0 - 0.5) * 0.05
			img.set_pixel(x, y, Color(c.r * shade + grain, c.g * shade + grain, c.b * shade + grain))
	var err := img.save_png(OUT)
	print("SAVED ", OUT, " err=", err)
	quit(0)
