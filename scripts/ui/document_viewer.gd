class_name DocumentViewer
extends CanvasLayer

signal document_opened(doc_id: String)
signal document_closed(doc_id: String)

@export var default_footer: String = "[E / Esc] Put Down Document"
## Plan 6.4: a document is lifted from the desk toward the eye, and put down
## the same way: it rises into view and sinks out of it, never pops.
## Bounded (tests/interaction/bounded_responsiveness_test.gd): a lift is quick.
@export var open_duration: float = 0.16
@export var put_down_duration: float = 0.22
## How far below its reading place the sheet starts and ends (pixels), and
## the small tilt of a hand-held page.
@export var lift_rise: float = 150.0
@export var lift_tilt_degrees: float = 2.5
var _motion_tween: Tween = null
var _putting_down: bool = false

var _current_doc_id: String = ""
var _is_open: bool = false
var _just_opened_frame: int = -1
## The footer the document was opened with; a live status line may temporarily
## replace it, and closing the situation restores it without reopening.
var _opened_footer: String = ""
## The live status currently replacing the footer ("" = none). Kept so layout
## refreshes (text scale, resize) re-present it instead of the opened footer.
var _live_footer: String = ""

var panel_container: PanelContainer = null
var title_label: Label = null
var body_label: RichTextLabel = null
var footer_label: Label = null
var text_scale: float = 1.2
var _copy_pan_y: float = 32.0
var _copy_reading_footer: Label = null
var _copy_incomplete := false

## Bundled faces only — never the host's fallback. Printed forms are letterpress;
## the transcript is Elias's own hand, which is the whole point of reading it.
const PAPER_FONT = preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const HAND_FONT = preload("res://assets/fonts/elias_working/elias_working.fnt")
const HAND_DOC_ID := "transcript_paper"
const HAND_FONT_SIZE := 18.0
const HAND_PIXEL_SIZE := 0.00148
const COPY_FACE = preload("res://materials/style_tests/textures/psx/form_night_copy.png")
const MORSE_FONT = preload("res://assets/fonts/courierprime/CourierPrime-Regular.ttf")
## Tape body = measured widest line + inner padding; card chrome = side margins.
const TAPE_LINE_PADDING := 12.0
const CARD_CHROME_WIDTH := 56.0
const CARD_MIN_WIDTH := 620.0
const BODY_MIN_WIDTH := 560.0

func _ready() -> void:
	visible = false
	_is_open = false
	_find_nodes()
	text_scale = GameSettings.load_settings().text_scale
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

func _find_nodes() -> void:
	if panel_container == null:
		panel_container = get_node_or_null("CenterContainer/PanelContainer") as PanelContainer
	if title_label == null:
		title_label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel") as Label
	if body_label == null:
		var body_path := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyScroll/BodyLabel"
		body_label = get_node_or_null(body_path) as RichTextLabel
	if footer_label == null:
		var footer_path := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FooterLabel"
		footer_label = get_node_or_null(footer_path) as Label
	if panel_container != null:
		panel_container.texture_filter = Control.TEXTURE_FILTER_NEAREST
	var copy_sheet := get_node_or_null("TranscriptSheet") as TextureRect
	if copy_sheet != null:
		copy_sheet.texture_filter = Control.TEXTURE_FILTER_NEAREST

func is_open() -> bool:
	return _is_open

func get_current_doc_id() -> String:
	return _current_doc_id

func open_document(doc_id: String, title: String, body: String, footer: String = "") -> void:
	_find_nodes()
	_current_doc_id = doc_id
	_is_open = true
	_just_opened_frame = Engine.get_process_frames()
	_opened_footer = footer if not footer.is_empty() else default_footer
	_live_footer = ""

	if title_label != null:
		title_label.text = title
	if body_label != null:
		var font: Font = PAPER_FONT
		var font_size := 17
		if doc_id in ["morse_reference", "tape_register", "timetable_card"]:
			font = MORSE_FONT
			font_size = 16
		elif doc_id in [HAND_DOC_ID, "previous_transcript"]:
			font = HAND_FONT
			font_size = 24
		body_label.add_theme_font_override("normal_font", font)
		body_label.add_theme_font_size_override("normal_font_size", int(round(font_size * text_scale)))
		body_label.autowrap_mode = TextServer.AUTOWRAP_OFF if doc_id == "tape_register" else TextServer.AUTOWRAP_WORD_SMART
		body_label.fit_content = false
		body_label.text = body
		_fit_body_width()
		body_label.scroll_to_line(0)
		if doc_id == "tape_register":
			show_latest_tape.call_deferred()
	if footer_label != null:
		footer_label.text = _opened_footer

	_present_copy(doc_id, body)
	_apply_lamp_light_to_paper()
	visible = true
	_animate_in()
	document_opened.emit(_current_doc_id)

func apply_wick_dimming(wick_level: float) -> void:
	var factor := clampf(lerpf(0.68, 1.0, clampf(wick_level, 0.0, 1.0)), 0.68, 1.0)
	var tint := Color(factor, factor * 0.97 + 0.03, factor * 0.92 + 0.08, 1.0)
	if panel_container != null:
		panel_container.self_modulate = tint
	var copy := get_node_or_null("TranscriptSheet") as Control
	if copy != null:
		copy.self_modulate = tint

func _apply_lamp_light_to_paper() -> void:
	var office := get_parent()
	var lamp_life := office.get_node_or_null("LampLife") as LampLife if office != null else null
	if lamp_life != null:
		apply_wick_dimming(lamp_life.wick)
	else:
		apply_wick_dimming(1.0)

func show_latest_tape() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _current_doc_id != "tape_register":
		return
	var opened_frame := _just_opened_frame
	await get_tree().process_frame
	if _is_open and _current_doc_id == "tape_register" and opened_frame == _just_opened_frame \
		and not is_queued_for_deletion():
		body_label.scroll_to_line(maxi(body_label.get_line_count() - 1, 0))

## Lift the same A4-like printed stock instead of inventing another wide card.
## The hidden logical body remains exact for document consumers and inspection tests.
func set_text_scale(value: float) -> void:
	text_scale = clampf(value, 1.0, 1.5)
	if not _is_open or body_label == null:
		return
	var base := 16 if _current_doc_id in ["morse_reference", "tape_register", "timetable_card"] else 17
	if _current_doc_id in [HAND_DOC_ID, "previous_transcript"]:
		base = 24
	body_label.add_theme_font_size_override("normal_font_size", int(round(base * text_scale)))
	_fit_body_width()
	_present_copy(_current_doc_id, body_label.text)

## Timing ink is never clipped: the tape card grows to the measured widest line
## (bundled mono face, current size), bounded by the viewport. Wider strips scroll
## sideways inside the card; marks are never hidden or silently shrunk.
func _fit_body_width() -> void:
	var scroll_path := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyScroll"
	var scroll := get_node_or_null(scroll_path) as ScrollContainer
	if body_label == null or scroll == null or panel_container == null:
		return
	if _current_doc_id != "tape_register":
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body_label.custom_minimum_size.x = BODY_MIN_WIDTH
		panel_container.custom_minimum_size.x = CARD_MIN_WIDTH
		return
	var area := _view_area()
	var font := body_label.get_theme_font("normal_font")
	var font_size := body_label.get_theme_font_size("normal_font_size")
	var widest := 0.0
	for line in body_label.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var vbar_width := body_label.get_v_scroll_bar().get_combined_minimum_size().x
	var body_width := maxf(BODY_MIN_WIDTH, ceilf(widest) + vbar_width + TAPE_LINE_PADDING)
	var viewport_limit := maxf(area.x - 48.0, 1.0)
	panel_container.custom_minimum_size.x = minf(maxf(CARD_MIN_WIDTH, body_width + CARD_CHROME_WIDTH), viewport_limit)
	body_label.custom_minimum_size.x = body_width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

func _copy_footer(text: String) -> void:
	if _copy_reading_footer == null:
		# Opaque dark backing: light footer ink must never sit on pale paper.
		var backing := ColorRect.new()
		backing.name = "CopyReadingFooterBacking"
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.color = Color(0.07, 0.06, 0.05, 1.0)
		add_child(backing)
		_copy_reading_footer = Label.new()
		_copy_reading_footer.name = "CopyReadingFooter"
		_copy_reading_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_copy_reading_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_copy_reading_footer.add_theme_color_override("font_color", Color(0.86, 0.79, 0.63, 1.0))
		_copy_reading_footer.add_theme_font_size_override("font_size", 16)
		add_child(_copy_reading_footer)
	var area := _view_area()
	var backing := get_node("CopyReadingFooterBacking") as ColorRect
	backing.position = Vector2(0, area.y - 52)
	backing.size = Vector2(area.x, 40)
	backing.visible = _is_open and _current_doc_id in [HAND_DOC_ID, "previous_transcript"]
	_copy_reading_footer.position = Vector2(24, area.y - 48)
	_copy_reading_footer.size = Vector2(maxf(area.x - 48, 1), 32)
	var status := "COPY INCOMPLETE  ·  " if _copy_incomplete else ""
	_copy_reading_footer.text = status + text + "  ·  [Wheel / PgUp PgDn Home End] Move sheet"
	_copy_reading_footer.visible = _is_open and _current_doc_id in [HAND_DOC_ID, "previous_transcript"]

func _present_copy(doc_id: String, body: String) -> void:
	var copy := get_node_or_null("TranscriptSheet") as TextureRect
	var centre := get_node_or_null("CenterContainer") as Control
	if copy == null or centre == null:
		return
	var is_copy := doc_id in [HAND_DOC_ID, "previous_transcript"]
	copy.visible = is_copy
	centre.visible = not is_copy
	if _copy_reading_footer != null:
		_copy_reading_footer.visible = is_copy
	var backing := get_node_or_null("CopyReadingFooterBacking") as ColorRect
	if backing != null:
		backing.visible = is_copy
	if not is_copy:
		return
	var mark := body.find("\n\n— COPY INCOMPLETE —")
	_copy_incomplete = mark >= 0
	copy.texture = COPY_FACE
	var area := _view_area()
	var ratio := 0.23 / 0.3
	var base_height := maxf(1.0, minf(area.y - 88.0, 640.0))
	var height := minf(base_height * text_scale, maxf(1.0, (area.x - 64.0) / ratio))
	var width := height * ratio
	copy.size = Vector2(width, height)
	_copy_pan_y = 32.0
	copy.position = Vector2((area.x - width) * 0.5, _copy_pan_y)
	var ink := copy.get_node("Ink") as Label
	ink.position = Vector2(width * 0.1435, height * 0.2833)
	ink.size = Vector2(width * 0.72, height * 0.60)
	ink.add_theme_font_override("font", HAND_FONT)
	ink.add_theme_font_size_override("font_size", maxi(16, int(round(width * HAND_FONT_SIZE * HAND_PIXEL_SIZE / 0.23))))
	var written := body.substr(0, mark) if mark >= 0 else body
	ink.text = TranscriptPaper.layout_text(written)
	# During an incomplete word, preserve the pad's precomputed positions.
	var paper := get_parent().get_node_or_null("TranscriptPaper") as TranscriptPaper
	if paper != null:
		# A copy shown mid-word still wraps by the whole message the hand is
		# writing, so the word keeps the row it will end on.
		var full := paper.get_transcript_text()
		if doc_id == HAND_DOC_ID and not written.is_empty() and full.begins_with(written):
			ink.text = TranscriptPaper.layout_text(full, written.length())
		if doc_id == HAND_DOC_ID and written == paper.get_display_text():
			ink.text = paper.get_label_3d().text
		elif doc_id == "previous_transcript":
			var previous := paper.get_node_or_null("PreviousSheet/PreviousSheetText") as Label3D
			if previous != null:
				ink.text = previous.text
	_present_amendment(copy, ink, paper if doc_id == HAND_DOC_ID else null)
	var status := copy.get_node("Status") as Label
	status.text = "COPY INCOMPLETE" if mark >= 0 else ""
	(copy.get_node("Footer") as Label).visible = false
	_copy_footer(_active_footer())

## The lifted copy repeats the ink already on the physical sheet, never a hidden draft.
func _present_amendment(copy: Control, ink: Label, paper: TranscriptPaper) -> void:
	var correction := copy.get_node_or_null("AmendmentInk") as Label
	if correction == null:
		correction = ink.duplicate() as Label
		correction.name = "AmendmentInk"
		correction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(correction)
	var strikes := copy.get_node_or_null("AmendmentStrikes") as Control
	if strikes == null:
		strikes = Control.new()
		strikes.name = "AmendmentStrikes"
		strikes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(strikes)
	for child in strikes.get_children():
		strikes.remove_child(child)
		child.queue_free()
	var amendment := paper.get_amendment() if paper != null else null
	var word := amendment.get_written_text() if amendment != null else ""
	correction.visible = not word.is_empty()
	strikes.visible = correction.visible
	if word.is_empty():
		correction.text = ""
		return
	var font := ink.get_theme_font("font")
	var font_size := ink.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	var lines := ink.text.split("\n")
	correction.add_theme_font_override("font", font)
	correction.add_theme_font_size_override("font_size", font_size)
	correction.position = ink.position + Vector2(0, line_height * (lines.size() + amendment.gap_rows))
	correction.size = ink.size
	correction.text = TranscriptPaper.layout_text(word)
	for index in lines.size():
		if lines[index].is_empty():
			continue
		var stroke := ColorRect.new()
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stroke.color = ink.get_theme_color("font_color")
		stroke.position = ink.position + Vector2(0, line_height * index + font.get_ascent(font_size) * 0.62)
		stroke.size = Vector2(font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 1.0)
		strikes.add_child(stroke)

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var is_copy := _current_doc_id in [HAND_DOC_ID, "previous_transcript"]
	if event is InputEventKey and event.pressed:
		var navigated := _copy_key_pan(event) if is_copy else _scroll_printed_document(event)
		if navigated:
			get_viewport().set_input_as_handled()
		return
	if not is_copy or not event is InputEventMouseButton or not event.pressed:
		return
	var direction := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = -1.0
	else:
		return
	_pan_copy_to(_copy_pan_y + direction * 48.0)
	get_viewport().set_input_as_handled()

## The world keeps mouse capture while reading. Use the body's own scroll
## range so keyboard and wheel always continue from the same place.
func _scroll_printed_document(event: InputEventKey) -> bool:
	if body_label == null or not body_label.scroll_active:
		return false
	var bar := body_label.get_v_scroll_bar()
	var bottom := bar.max_value - bar.page
	if bottom <= bar.min_value:
		return false
	var line := float(body_label.get_line_height(0))
	var page := maxf(line, bar.page - line)
	match event.keycode:
		KEY_UP:
			bar.value -= line
		KEY_DOWN:
			bar.value += line
		KEY_PAGEUP:
			bar.value -= page
		KEY_PAGEDOWN:
			bar.value += page
		KEY_HOME:
			bar.value = bar.min_value
		KEY_END:
			bar.value = bottom
		_:
			return false
	return true

## Keyboard pan for the magnified sheet. Only page/line-navigation keys are taken
## while a copy is open; letters (WASD) stay with the game and text entry.
func _copy_key_pan(event: InputEventKey) -> bool:
	var target: float
	match event.keycode:
		KEY_PAGEUP:
			target = _copy_pan_y + 240.0
		KEY_PAGEDOWN:
			target = _copy_pan_y - 240.0
		KEY_HOME:
			target = 32.0
		KEY_END:
			target = -INF
		_:
			return false
	_pan_copy_to(target)
	return true

## The single bounded pan path shared by wheel and keyboard.
func _pan_copy_to(target: float) -> void:
	var copy := get_node("TranscriptSheet") as Control
	_copy_pan_y = clampf(target, _copy_pan_minimum(copy), 32.0)
	copy.position.y = _copy_pan_y

## The frame the viewer draws in. While the office is being moved into its
## presentation frame the viewer is briefly outside any viewport; it then lays
## out for the 960x540 frame it is about to land in.
func _view_area() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(ReadabilityPolicy.INTERNAL_SIZE)
	return viewport.get_visible_rect().size

func _copy_pan_minimum(copy: Control) -> float:
	var area := _view_area()
	return minf(32.0, area.y - 64.0 - copy.size.y)

## Resize re-presents the open sheet and fixed footer for the new viewport and
## keeps the reader's pan (clamped to the new bounds). Logical content is untouched.
func _on_viewport_resized() -> void:
	if not _is_open or body_label == null:
		return
	_fit_body_width()
	if _current_doc_id not in [HAND_DOC_ID, "previous_transcript"]:
		return
	var pan := _copy_pan_y
	_present_copy(_current_doc_id, body_label.text)
	var copy := get_node("TranscriptSheet") as Control
	_copy_pan_y = clampf(pan, _copy_pan_minimum(copy), 32.0)
	copy.position.y = _copy_pan_y

## A live status line — a deadline warning — can replace the footer while the
## document stays open, so the warning is readable behind the paper it concerns.
## An empty text restores the footer the document was opened with. The body,
## scroll and doc_id are never touched: this is a status, not a reopen.
func set_live_footer(text: String) -> void:
	_find_nodes()
	if footer_label == null or not _is_open:
		return
	_live_footer = text
	var target := _active_footer()
	if footer_label.text != target:
		footer_label.text = target
	if _current_doc_id in [HAND_DOC_ID, "previous_transcript"]:
		_copy_footer(target)
	var copy_footer := get_node_or_null("TranscriptSheet/Footer") as Label
	if copy_footer != null:
		copy_footer.text = target

func _active_footer() -> String:
	return _live_footer if not _live_footer.is_empty() else _opened_footer

## Lifting a document into view takes a moment. Instant appearance is the single
## most common reason a first-person game reads as a slideshow of states.
func _animate_in() -> void:
	var backdrop := get_node_or_null("Backdrop") as ColorRect
	var centre := get_node_or_null("CenterContainer") as Control
	var copy := get_node_or_null("TranscriptSheet") as Control
	if copy != null and copy.visible:
		centre = copy
	_stop_motion()
	_rest_sheets()
	if not is_inside_tree():
		if centre != null:
			centre.modulate.a = 1.0
		return

	var tween := create_tween()
	_motion_tween = tween
	tween.set_parallel(true)
	if backdrop != null:
		backdrop.color.a = 0.0
		tween.tween_property(backdrop, "color:a", 0.6, open_duration).set_trans(Tween.TRANS_SINE)
	if centre != null:
		centre.modulate.a = 0.0
		centre.scale = Vector2(0.94, 0.94)
		centre.pivot_offset = centre.size * 0.5
		centre.rotation = deg_to_rad(-lift_tilt_degrees)
		tween.tween_property(centre, "modulate:a", 1.0, open_duration * 0.7).set_trans(Tween.TRANS_SINE)
		# Paper is lifted, not sprung: up from the desk, no overshoot.
		tween.tween_property(centre, "scale", Vector2.ONE, open_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(centre, "rotation", 0.0, open_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if centre is CenterContainer:
			# The transcript pans by its own position; only the card rises.
			centre.position.y = lift_rise
			tween.tween_property(centre, "position:y", 0.0, open_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func close_document() -> void:
	if not _is_open:
		return
	var closed_id := _current_doc_id
	_is_open = false
	_current_doc_id = ""
	_live_footer = ""
	# The record of closing is immediate (controls come back at once); only
	# the paper takes its moment to go back down to the desk.
	_put_down()
	document_closed.emit(closed_id)

## True while a closed sheet is still going back down to the desk.
func is_putting_down() -> bool:
	return _putting_down

## The sheet sinks back toward the desk and fades; then the layer hides.
func _put_down() -> void:
	_stop_motion()
	var centre := get_node_or_null("CenterContainer") as Control
	var copy := get_node_or_null("TranscriptSheet") as Control
	if copy != null and copy.visible:
		centre = copy
	if not is_inside_tree() or put_down_duration <= 0.0 or centre == null:
		_finish_put_down()
		return
	_putting_down = true
	var backdrop := get_node_or_null("Backdrop") as ColorRect
	var tween := create_tween()
	_motion_tween = tween
	tween.set_parallel(true)
	if backdrop != null:
		tween.tween_property(backdrop, "color:a", 0.0, put_down_duration).set_trans(Tween.TRANS_SINE)
	centre.pivot_offset = centre.size * 0.5
	var seconds := put_down_duration
	tween.tween_property(centre, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(centre, "scale", Vector2(0.94, 0.94), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(centre, "rotation", deg_to_rad(lift_tilt_degrees), seconds).set_trans(Tween.TRANS_SINE)
	if centre is CenterContainer:
		tween.tween_property(centre, "position:y", lift_rise, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_put_down)

func _finish_put_down() -> void:
	_putting_down = false
	if _is_open:
		return
	visible = false
	_rest_sheets()

func _stop_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	_putting_down = false

## Both sheets back at their reading pose (the transcript keeps its pan).
func _rest_sheets() -> void:
	var centre := get_node_or_null("CenterContainer") as Control
	if centre != null:
		centre.position.y = 0.0
		centre.rotation = 0.0
		centre.scale = Vector2.ONE
		centre.modulate.a = 1.0
	var copy := get_node_or_null("TranscriptSheet") as Control
	if copy != null:
		copy.rotation = 0.0
		copy.scale = Vector2.ONE
		copy.modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Prevent closing on the exact frame the document was opened
	if _just_opened_frame == Engine.get_process_frames():
		return

	if not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		close_document()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
