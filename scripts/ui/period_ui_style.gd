class_name PeriodUIStyle
extends RefCounted

## Period 1890s UI styling helpers: walnut/leather ledger panels, brass hairlines,
## custom round brass slider grabs and square brass checkboxes (never default grey).

static var _knob_normal: ImageTexture = null
static var _knob_hover: ImageTexture = null
static var _check_off: ImageTexture = null
static var _check_on: ImageTexture = null
static var _radio_off: ImageTexture = null
static var _radio_on: ImageTexture = null

const INK_CREAM := Color(0.92, 0.86, 0.72, 1.0)
const INK_WARM := Color(0.84, 0.77, 0.62, 1.0)
const INK_MUTED := Color(0.60, 0.54, 0.43, 1.0)
const INK_FAINT := Color(0.42, 0.37, 0.29, 1.0)
const BRASS := Color(0.76, 0.61, 0.36, 1.0)
const BRASS_DIM := Color(0.48, 0.39, 0.24, 0.85)
const LEDGER_BG := Color(0.065, 0.055, 0.045, 0.94)
const FIELD_BG := Color(0.11, 0.09, 0.07, 0.95)
const FIELD_HOVER := Color(0.16, 0.13, 0.095, 0.98)

static func ensure_textures() -> void:
	if _knob_normal == null:
		_knob_normal = _make_circle_tex(14, Color(0.78, 0.63, 0.37, 1.0), Color(0.24, 0.17, 0.09, 1.0))
	if _knob_hover == null:
		_knob_hover = _make_circle_tex(16, Color(0.95, 0.83, 0.56, 1.0), Color(0.32, 0.22, 0.10, 1.0))
	if _check_off == null:
		_check_off = _make_box_tex(15, false)
	if _check_on == null:
		_check_on = _make_box_tex(15, true)
	if _radio_off == null:
		_radio_off = _make_toggle_tex(28, 14, false)
	if _radio_on == null:
		_radio_on = _make_toggle_tex(28, 14, true)

static func style_options_ledger(panel: PanelContainer) -> void:
	if panel == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = LEDGER_BG
	box.border_color = BRASS_DIM
	box.set_border_width_all(1)
	box.border_width_top = 2
	box.set_corner_radius_all(2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", box)

static func style_menu_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.068, 0.055, 0.35) if primary else Color(0, 0, 0, 0)
	normal.border_width_bottom = 1
	normal.border_width_left = 2 if primary else 0
	normal.border_color = Color(0.68, 0.55, 0.34, 0.72) if primary else Color(0.52, 0.45, 0.34, 0.45)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.86, 0.76, 0.56, 0.09)
	hover.border_width_left = 3
	hover.border_width_bottom = 1
	hover.border_color = BRASS

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.86, 0.76, 0.56, 0.16)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", INK_CREAM if primary else INK_WARM)
	button.add_theme_color_override("font_hover_color", Color(0.98, 0.93, 0.80, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.98, 0.93, 0.80, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.84, 1.0))

static func style_tab_button(button: Button, active: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.09, 0.92) if active else Color(0.06, 0.05, 0.04, 0.4)
	normal.border_width_bottom = 2 if active else 1
	normal.border_width_top = 1 if active else 0
	normal.border_color = BRASS if active else Color(0.35, 0.29, 0.21, 0.6)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.19, 0.155, 0.11, 0.95)
	hover.border_color = BRASS

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", INK_CREAM if active else INK_MUTED)
	button.add_theme_color_override("font_hover_color", INK_CREAM)
	button.add_theme_color_override("font_focus_color", INK_CREAM)

static func style_locale_pill(button: Button, active: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.085, 0.92) if active else Color(0.04, 0.035, 0.03, 0.55)
	normal.set_border_width_all(1)
	normal.border_color = BRASS if active else Color(0.36, 0.30, 0.22, 0.55)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 9.0
	normal.content_margin_right = 9.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = BRASS
	hover.bg_color = Color(0.20, 0.16, 0.11, 0.96)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", INK_CREAM if active else INK_MUTED)
	button.add_theme_color_override("font_hover_color", INK_CREAM)
	button.add_theme_font_size_override("font_size", 12)

static func style_controls_recursive(root: Node) -> void:
	if root == null:
		return
	ensure_textures()
	for child in root.get_children():
		if child is HSlider:
			_style_slider(child as HSlider)
		elif child is CheckButton:
			_style_check_button(child as CheckButton)
		elif child is CheckBox:
			_style_checkbox(child as CheckBox)
		elif child is OptionButton:
			_style_option_button(child as OptionButton)
		elif child is Button and not String(child.name).begins_with("Tab"):
			_style_small_button(child as Button)
		elif child is Label:
			var lbl := child as Label
			if lbl.name == "Value":
				lbl.add_theme_color_override("font_color", BRASS)
			else:
				lbl.add_theme_color_override("font_color", INK_WARM)
			lbl.add_theme_font_size_override("font_size", 13)
		style_controls_recursive(child)

static func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.22, 0.18, 0.13, 0.9)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.56, 0.31, 0.95)
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 2.0
	fill.content_margin_bottom = 2.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _knob_normal)
	slider.add_theme_icon_override("grabber_highlight", _knob_hover)
	slider.add_theme_icon_override("grabber_disabled", _knob_normal)

static func _style_checkbox(box: CheckBox) -> void:
	var empty := StyleBoxEmpty.new()
	box.add_theme_stylebox_override("normal", empty)
	box.add_theme_stylebox_override("hover", empty)
	box.add_theme_stylebox_override("pressed", empty)
	box.add_theme_stylebox_override("focus", empty)
	box.add_theme_color_override("font_color", INK_WARM)
	box.add_theme_color_override("font_hover_color", INK_CREAM)
	box.add_theme_color_override("font_pressed_color", INK_CREAM)
	box.add_theme_font_size_override("font_size", 13)
	box.add_theme_icon_override("unchecked", _check_off)
	box.add_theme_icon_override("checked", _check_on)
	box.add_theme_icon_override("unchecked_disabled", _check_off)
	box.add_theme_icon_override("checked_disabled", _check_on)

static func _style_check_button(btn: CheckButton) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_color_override("font_color", INK_WARM)
	btn.add_theme_color_override("font_hover_color", INK_CREAM)
	btn.add_theme_color_override("font_pressed_color", INK_CREAM)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_icon_override("unchecked", _radio_off)
	btn.add_theme_icon_override("checked", _radio_on)

static func _style_option_button(opt: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = FIELD_BG
	normal.set_border_width_all(1)
	normal.border_color = Color(0.45, 0.36, 0.24, 0.85)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = FIELD_HOVER
	hover.border_color = BRASS
	opt.add_theme_stylebox_override("normal", normal)
	opt.add_theme_stylebox_override("hover", hover)
	opt.add_theme_stylebox_override("focus", hover)
	opt.add_theme_stylebox_override("pressed", hover)
	opt.add_theme_color_override("font_color", INK_WARM)
	opt.add_theme_color_override("font_hover_color", INK_CREAM)
	opt.add_theme_font_size_override("font_size", 13)
	var popup := opt.get_popup()
	if popup != null:
		var pop_bg := StyleBoxFlat.new()
		pop_bg.bg_color = Color(0.08, 0.065, 0.05, 0.98)
		pop_bg.set_border_width_all(1)
		pop_bg.border_color = BRASS_DIM
		var pop_hi := StyleBoxFlat.new()
		pop_hi.bg_color = Color(0.24, 0.19, 0.12, 0.95)
		popup.add_theme_stylebox_override("panel", pop_bg)
		popup.add_theme_stylebox_override("hover", pop_hi)
		popup.add_theme_color_override("font_color", INK_WARM)
		popup.add_theme_color_override("font_hover_color", INK_CREAM)
		popup.add_theme_font_size_override("font_size", 13)

static func _style_small_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = FIELD_BG
	normal.set_border_width_all(1)
	normal.border_color = Color(0.45, 0.36, 0.24, 0.8)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 9.0
	normal.content_margin_right = 9.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = FIELD_HOVER
	hover.border_color = BRASS
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", INK_WARM)
	btn.add_theme_color_override("font_hover_color", INK_CREAM)
	btn.add_theme_font_size_override("font_size", 13)

static func _make_circle_tex(size: int, fill: Color, rim: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.46
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length()
			if d <= r - 1.2:
				var shade := 1.08 - 0.18 * ((float(x) - c + float(y) - c) / maxf(r, 1.0))
				img.set_pixel(x, y, Color(
					clampf(fill.r * shade, 0.0, 1.0),
					clampf(fill.g * shade, 0.0, 1.0),
					clampf(fill.b * shade, 0.0, 1.0),
					1.0
				))
			elif d <= r:
				img.set_pixel(x, y, rim)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func _make_box_tex(size: int, checked: bool) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var border := BRASS if checked else Color(0.50, 0.41, 0.27, 0.9)
	var bg := Color(0.14, 0.11, 0.08, 1.0)
	for y in size:
		for x in size:
			var is_edge := x == 0 or y == 0 or x == size - 1 or y == size - 1
			img.set_pixel(x, y, border if is_edge else bg)
	if checked:
		for y in range(3, size - 3):
			for x in range(3, size - 3):
				img.set_pixel(x, y, Color(0.84, 0.68, 0.40, 1.0))
	return ImageTexture.create_from_image(img)

static func _make_toggle_tex(width: int, height: int, checked: bool) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var border := BRASS if checked else Color(0.45, 0.37, 0.25, 0.9)
	var bg := Color(0.20, 0.16, 0.11, 1.0) if checked else Color(0.09, 0.075, 0.06, 1.0)
	for y in height:
		for x in width:
			var is_edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
			img.set_pixel(x, y, border if is_edge else bg)
	var kx0 := width - height + 2 if checked else 2
	var kx1 := width - 3 if checked else height - 3
	var knob := Color(0.90, 0.75, 0.46, 1.0) if checked else Color(0.52, 0.44, 0.32, 1.0)
	for y in range(2, height - 2):
		for x in range(kx0, kx1 + 1):
			img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)
