class_name DocumentViewer
extends CanvasLayer

signal document_opened(doc_id: String)
signal document_closed(doc_id: String)

@export var default_footer: String = "[E / Esc] Put Down Document"
@export var open_duration: float = 0.24

var _current_doc_id: String = ""
var _is_open: bool = false
var _just_opened_frame: int = -1
## The footer the document was opened with; a live status line may temporarily
## replace it, and closing the situation restores it without reopening.
var _opened_footer: String = ""

var panel_container: PanelContainer = null
var title_label: Label = null
var body_label: RichTextLabel = null
var footer_label: Label = null

## Bundled faces only — never the host's fallback. Printed forms are letterpress;
## the transcript is Elias's own hand, which is the whole point of reading it.
const PAPER_FONT = preload("res://assets/fonts/imfell/IMFeENrm28P.ttf")
const HAND_FONT = preload("res://assets/fonts/cedarville/Cedarville-Cursive.ttf")
const HAND_DOC_ID := "transcript_paper"
const MORSE_FONT = preload("res://materials/typography/morse_mono.tres")

func _ready() -> void:
	visible = false
	_is_open = false
	_find_nodes()

func _find_nodes() -> void:
	if panel_container == null:
		panel_container = get_node_or_null("CenterContainer/PanelContainer") as PanelContainer
	if title_label == null:
		title_label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel") as Label
	if body_label == null:
		var body_path := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyLabel"
		body_label = get_node_or_null(body_path) as RichTextLabel
	if footer_label == null:
		var footer_path := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FooterLabel"
		footer_label = get_node_or_null(footer_path) as Label

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

	if title_label != null:
		title_label.text = title
	if body_label != null:
		var font: Font = PAPER_FONT
		var font_size := 17
		if doc_id == "morse_reference":
			font = MORSE_FONT
			font_size = 16
		elif doc_id == HAND_DOC_ID:
			font = HAND_FONT
			font_size = 24
		body_label.add_theme_font_override("normal_font", font)
		body_label.add_theme_font_size_override("normal_font_size", font_size)
		body_label.text = body
		body_label.scroll_to_line(0)
	if footer_label != null:
		footer_label.text = _opened_footer

	visible = true
	_animate_in()
	document_opened.emit(_current_doc_id)

## A live status line — a deadline warning — can replace the footer while the
## document stays open, so the warning is readable behind the paper it concerns.
## An empty text restores the footer the document was opened with. The body,
## scroll and doc_id are never touched: this is a status, not a reopen.
func set_live_footer(text: String) -> void:
	_find_nodes()
	if footer_label == null or not _is_open:
		return
	var target := text if not text.is_empty() else _opened_footer
	if footer_label.text != target:
		footer_label.text = target

## Lifting a document into view takes a moment. Instant appearance is the single
## most common reason a first-person game reads as a slideshow of states.
func _animate_in() -> void:
	var backdrop := get_node_or_null("Backdrop") as ColorRect
	var centre := get_node_or_null("CenterContainer") as Control
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
