class_name DocumentViewer
extends CanvasLayer

signal document_opened(doc_id: String)
signal document_closed(doc_id: String)

@export var default_footer: String = "[E / Esc] Put Down Document"
@export var open_duration: float = 0.16

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
		if doc_id in ["morse_reference", "tape_register"]:
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
	var base := 16 if _current_doc_id in ["morse_reference", "tape_register"] else 17
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
	var area := get_viewport().get_visible_rect().size
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
	var area := get_viewport().get_visible_rect().size
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
	var area := get_viewport().get_visible_rect().size
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
	var result := ""
	for i in written.length():
		if i > 0 and i % TranscriptPaper.GLYPH_COLUMNS == 0:
			result += "\n"
		result += written[i]
	ink.text = result
	var status := copy.get_node("Status") as Label
	status.text = "COPY INCOMPLETE" if mark >= 0 else ""
	(copy.get_node("Footer") as Label).visible = false
	_copy_footer(_active_footer())

func _input(event: InputEvent) -> void:
	if not _is_open or _current_doc_id not in [HAND_DOC_ID, "previous_transcript"]:
		return
	if event is InputEventKey and event.pressed:
		if _copy_key_pan(event):
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed:
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

func _copy_pan_minimum(copy: Control) -> float:
	var area := get_viewport().get_visible_rect().size
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
	if not is_inside_tree():
		if centre != null:
			centre.modulate.a = 1.0
		return

	var tween := create_tween()
	tween.set_parallel(true)
	if backdrop != null:
		backdrop.color.a = 0.0
		tween.tween_property(backdrop, "color:a", 0.6, open_duration).set_trans(Tween.TRANS_SINE)
	if centre != null:
		centre.modulate.a = 0.0
		centre.scale = Vector2(0.985, 0.985)
		centre.pivot_offset = centre.size * 0.5
		tween.tween_property(centre, "modulate:a", 1.0, open_duration).set_trans(Tween.TRANS_SINE)
		# Paper is lifted, not sprung: no overshoot.
		tween.tween_property(centre, "scale", Vector2.ONE, open_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func close_document() -> void:
	if not _is_open:
		return
	var closed_id := _current_doc_id
	_is_open = false
	_current_doc_id = ""
	_live_footer = ""
	visible = false
	document_closed.emit(closed_id)

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
