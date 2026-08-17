class_name DocumentViewer
extends CanvasLayer

signal document_opened(doc_id: String)
signal document_closed(doc_id: String)

@export var default_footer: String = "[E / Esc] Put Down Document"

var _current_doc_id: String = ""
var _is_open: bool = false
var _just_opened_frame: int = -1

var panel_container: PanelContainer = null
var title_label: Label = null
var body_label: RichTextLabel = null
var footer_label: Label = null

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
		body_label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyLabel") as RichTextLabel
	if footer_label == null:
		footer_label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FooterLabel") as Label

func is_open() -> bool:
	return _is_open

func get_current_doc_id() -> String:
	return _current_doc_id

func open_document(doc_id: String, title: String, body: String, footer: String = "") -> void:
	_find_nodes()
	_current_doc_id = doc_id
	_is_open = true
	_just_opened_frame = Engine.get_process_frames()

	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = body
	if footer_label != null:
		footer_label.text = footer if not footer.is_empty() else default_footer

	visible = true
	document_opened.emit(_current_doc_id)

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

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close_document()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
