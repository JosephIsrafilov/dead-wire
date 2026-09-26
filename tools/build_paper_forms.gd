extends SceneTree

## Bakes the printed paper the operator works on:
##   - the railway's NIGHT COPY telegraph blank (transcript sheet face), with
##     its ruling computed from the handwriting font so every written row sits
##     on a printed line;
##   - the buff card stock of the Morse reference card.
##
##   godot --path . --script tools/build_paper_forms.gd     (windowed: needs a GPU)
##
## Layout is authored in the sheet's own metres and mapped to texels, so the
## form and the Label3D ink share one geometry. Deterministic.

const PRINT := preload("res://assets/fonts/imfell/IMFeENrm28P.ttf")
const HAND := preload("res://assets/fonts/cedarville/Cedarville-Cursive.ttf")

const SHEET_W := 0.23
const SHEET_H := 0.30
const FORM_PX := Vector2i(368, 480) ## 16 px per cm
## Must match the transcript Label3D in transcript_paper.tscn.
const INK_ORIGIN := Vector2(-0.082, -0.065)
const INK_PIXEL_SIZE := 0.00165
const INK_FONT_SIZE := 16

const INK_PRINT := Color(0.16, 0.12, 0.09)
const RULE := Color(0.46, 0.50, 0.58, 0.55)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _bake("res://materials/style_tests/textures/psx/form_night_copy.png", FORM_PX, _paper_image(FORM_PX, 11, Color(0.82, 0.76, 0.62)), _night_copy)
	await _bake("res://materials/style_tests/textures/psx/card_morse_stock.png", Vector2i(256, 256), _paper_image(Vector2i(256, 256), 23, Color(0.76, 0.66, 0.48)), _card_stock)
	await _bake("res://materials/style_tests/textures/psx/map_division.png", Vector2i(384, 240), _paper_image(Vector2i(384, 240), 31, Color(0.74, 0.68, 0.54)), _division_map)
	quit(0)

func _bake(path: String, size: Vector2i, base: Image, layout: Callable) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(base)
	bg.size = Vector2(size)
	vp.add_child(bg)
	layout.call(vp, Vector2(size))
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	print("BAKED ", path, " ", img.save_png(path))
	vp.queue_free()

## Aged stock: fibres, a few foxing spots, darker edges from handling.
func _paper_image(size: Vector2i, seed: int, tint: Color) -> Image:
	var fib := FastNoiseLite.new()
	fib.seed = seed
	fib.frequency = 0.08
	fib.fractal_octaves = 3
	var blot := FastNoiseLite.new()
	blot.seed = seed + 7
	blot.frequency = 0.02
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y in size.y:
		for x in size.x:
			var f := fib.get_noise_2d(x * 2.0, y * 0.6) * 0.05
			var b := maxf(blot.get_noise_2d(x, y) - 0.45, 0.0) * 0.18
			var ex := minf(float(x), float(size.x - 1 - x)) / 14.0
			var ey := minf(float(y), float(size.y - 1 - y)) / 14.0
			var edge := (1.0 - clampf(minf(ex, ey), 0.0, 1.0)) * 0.12
			var k := 1.0 + f - b - edge
			img.set_pixel(x, y, Color(tint.r * k, tint.g * k * (1.0 - b * 0.3), tint.b * k * (1.0 - b * 0.6)))
	# Foxing: small rust spots, deterministic.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for _i in 9:
		var c := Vector2i(rng.randi_range(8, size.x - 8), rng.randi_range(8, size.y - 8))
		var r := rng.randi_range(1, 3)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					var p := img.get_pixelv(c + Vector2i(dx, dy))
					img.set_pixelv(c + Vector2i(dx, dy), p.lerp(Color(0.55, 0.40, 0.25), 0.35))
	return img

func _to_px(sheet: Vector2, px: Vector2) -> Vector2:
	return Vector2((sheet.x + SHEET_W * 0.5) / SHEET_W * px.x, (sheet.y + SHEET_H * 0.5) / SHEET_H * px.y)

func _label(parent: Node, text: String, pos: Vector2, size: int, align: HorizontalAlignment, width: float,
		color: Color = INK_PRINT) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PRINT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(width, size * 1.4)
	parent.add_child(l)

func _line(parent: Node, from: Vector2, length: float, thickness: float, color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.position = from
	r.size = Vector2(length, thickness)
	parent.add_child(r)

func _frame(parent: Node, rect: Rect2, thickness: float, color: Color) -> void:
	_line(parent, rect.position, rect.size.x, thickness, color)
	_line(parent, rect.position + Vector2(0, rect.size.y - thickness), rect.size.x, thickness, color)
	var l := ColorRect.new()
	l.color = color
	l.position = rect.position
	l.size = Vector2(thickness, rect.size.y)
	parent.add_child(l)
	var r := ColorRect.new()
	r.color = color
	r.position = rect.position + Vector2(rect.size.x - thickness, 0)
	r.size = Vector2(thickness, rect.size.y)
	parent.add_child(r)

## The railway's night copy blank.
func _night_copy(vp: Node, px: Vector2) -> void:
	var w := px.x
	_frame(vp, Rect2(10, 10, w - 20, px.y - 20), 1.0, INK_PRINT.lerp(Color(0.8, 0.75, 0.6), 0.35))
	_label(vp, "BLACK CREEK & WESTERN RAILWAY", Vector2(0, 16), 17, HORIZONTAL_ALIGNMENT_CENTER, w)
	_label(vp, "TELEGRAPH  DEPARTMENT", Vector2(0, 38), 11, HORIZONTAL_ALIGNMENT_CENTER, w)
	_line(vp, Vector2(w * 0.3, 55), w * 0.4, 1.0, INK_PRINT)
	_label(vp, "NIGHT  COPY", Vector2(0, 58), 13, HORIZONTAL_ALIGNMENT_CENTER, w)
	# Header fields.
	var fy := 84.0
	_label(vp, "No.", Vector2(22, fy), 10, HORIZONTAL_ALIGNMENT_LEFT, 40)
	_line(vp, Vector2(42, fy + 12), 60, 1.0, INK_PRINT.lerp(Color.WHITE, 0.3))
	_label(vp, "Check", Vector2(112, fy), 10, HORIZONTAL_ALIGNMENT_LEFT, 40)
	_line(vp, Vector2(145, fy + 12), 50, 1.0, INK_PRINT.lerp(Color.WHITE, 0.3))
	_label(vp, "Time", Vector2(206, fy), 10, HORIZONTAL_ALIGNMENT_LEFT, 40)
	_line(vp, Vector2(233, fy + 12), 70, 1.0, INK_PRINT.lerp(Color.WHITE, 0.3))
	_label(vp, "M.", Vector2(306, fy), 10, HORIZONTAL_ALIGNMENT_LEFT, 20)
	_line(vp, Vector2(20, 110), w - 40, 1.0, INK_PRINT.lerp(Color(0.8, 0.75, 0.6), 0.4))
	# Ruling under every handwriting row, from the font's own metrics.
	var row_h := HAND.get_height(INK_FONT_SIZE) * INK_PIXEL_SIZE
	var ascent := HAND.get_ascent(INK_FONT_SIZE) * INK_PIXEL_SIZE
	var descent := HAND.get_descent(INK_FONT_SIZE) * INK_PIXEL_SIZE
	for row in 12:
		var baseline := INK_ORIGIN.y + ascent + row * row_h + descent * 0.25
		var p := _to_px(Vector2(-SHEET_W * 0.5, baseline), px)
		if p.y > px.y - 60:
			break
		_line(vp, Vector2(22, p.y), w - 44, 1.0, RULE)
	# Margin rule where the hand starts.
	var margin := _to_px(Vector2(INK_ORIGIN.x - 0.006, 0), px)
	var m := ColorRect.new()
	m.color = Color(0.62, 0.30, 0.26, 0.45)
	m.position = Vector2(margin.x, 112)
	m.size = Vector2(1, px.y - 112 - 56)
	vp.add_child(m)
	# Footer: signature and the rule that the citations quote.
	_label(vp, "Rec'd by", Vector2(22, px.y - 50), 10, HORIZONTAL_ALIGNMENT_LEFT, 60)
	_line(vp, Vector2(70, px.y - 38), 120, 1.0, INK_PRINT.lerp(Color.WHITE, 0.3))
	_label(vp, "Messages shall be copied in full at the moment of receipt. Errors of copy", Vector2(0, px.y - 30), 7,
		HORIZONTAL_ALIGNMENT_CENTER, w, INK_PRINT.lerp(Color(0.8, 0.75, 0.6), 0.25))
	_label(vp, "against the register are chargeable to the operator.  — Rule 7.", Vector2(0, px.y - 21), 7,
		HORIZONTAL_ALIGNMENT_CENTER, w, INK_PRINT.lerp(Color(0.8, 0.75, 0.6), 0.25))

## The division map on the office wall: the line through Black Creek, the
## mine spur and the reservoir that feeds the town — the story's geography,
## hung where the operator walks past it every night.
func _division_map(vp: Node, px: Vector2) -> void:
	var ink := INK_PRINT
	var faint := INK_PRINT.lerp(Color(0.74, 0.68, 0.54), 0.45)
	_frame(vp, Rect2(6, 6, px.x - 12, px.y - 12), 2.0, ink)
	_label(vp, "BLACK CREEK & WESTERN RY. — EAST DIVISION", Vector2(0, 12), 12, HORIZONTAL_ALIGNMENT_CENTER, px.x)
	# Main line west-east with stations.
	_line(vp, Vector2(30, 120), px.x - 60, 3.0, ink)
	var stations := [[40.0, "SUMMIT"], [150.0, "BLACK CREEK"], [270.0, "HOLLIS"], [345.0, "DENVER \u2192"]]
	for st in stations:
		var x: float = st[0]
		var dot := ColorRect.new()
		dot.color = ink
		dot.position = Vector2(x - 4, 116)
		dot.size = Vector2(8, 11)
		vp.add_child(dot)
		_label(vp, String(st[1]), Vector2(x - 60, 128), 9, HORIZONTAL_ALIGNMENT_CENTER, 120)
	# Mine spur north of Black Creek, the reservoir beside it.
	var spur := ColorRect.new()
	spur.color = ink
	spur.position = Vector2(150, 58)
	spur.size = Vector2(2, 60)
	vp.add_child(spur)
	_label(vp, "MINE No. 3", Vector2(95, 42), 9, HORIZONTAL_ALIGNMENT_CENTER, 110)
	var res := ColorRect.new()
	res.color = Color(0.36, 0.42, 0.48, 0.55)
	res.position = Vector2(182, 62)
	res.size = Vector2(46, 24)
	vp.add_child(res)
	_label(vp, "RESERVOIR", Vector2(160, 88), 8, HORIZONTAL_ALIGNMENT_CENTER, 90, faint)
	_line(vp, Vector2(152, 74), 30, 1.0, faint)
	_label(vp, "Scale: one inch to four miles.   Revised Oct. 1889.", Vector2(0, px.y - 26), 8, HORIZONTAL_ALIGNMENT_CENTER, px.x, faint)

## Buff card: a double printer's rule and corner dots; the table itself is ink.
func _card_stock(vp: Node, px: Vector2) -> void:
	var c := INK_PRINT.lerp(Color(0.76, 0.66, 0.48), 0.3)
	_frame(vp, Rect2(8, 8, px.x - 16, px.y - 16), 2.0, c)
	_frame(vp, Rect2(13, 13, px.x - 26, px.y - 26), 1.0, c)
	for corner in [Vector2(13, 13), Vector2(px.x - 17, 13), Vector2(13, px.y - 17), Vector2(px.x - 17, px.y - 17)]:
		var d := ColorRect.new()
		d.color = c
		d.position = corner
		d.size = Vector2(4, 4)
		vp.add_child(d)
	_label(vp, "B. C. & W. Ry. — Telegraph Dept.", Vector2(0, px.y - 30), 8, HORIZONTAL_ALIGNMENT_CENTER, px.x, c)
