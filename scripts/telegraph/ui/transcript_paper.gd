class_name TranscriptPaper
extends Node3D

signal transcript_inspected(text: String)
signal transcript_closed()

@export var prompt_message: String = "Read Telegram Transcript"
@export var empty_placeholder: String = "[BLANK TELEGRAM PAD]"

var interactable: Interactable = null
var label_3d: Label3D = null

var _transcript_text: String = ""
var _is_revealed: bool = false

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_update_display()

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func get_label_3d() -> Label3D:
	if label_3d == null:
		label_3d = get_node_or_null("Label3D") as Label3D
	return label_3d

func get_transcript_text() -> String:
	return _transcript_text

func is_revealed() -> bool:
	return _is_revealed

func set_transcript_text(text: String) -> void:
	_transcript_text = text
	_update_display()

func reveal_transcript() -> void:
	_is_revealed = true
	_update_display()

func clear_transcript() -> void:
	_transcript_text = ""
	_is_revealed = false
	_update_display()

func _update_display() -> void:
	var lbl := get_label_3d()
	if lbl != null:
		if _is_revealed and not _transcript_text.is_empty():
			lbl.text = _transcript_text
		else:
			lbl.text = empty_placeholder

func _on_interacted() -> void:
	var display_text := _transcript_text if (_is_revealed and not _transcript_text.is_empty()) else empty_placeholder
	transcript_inspected.emit(display_text)
