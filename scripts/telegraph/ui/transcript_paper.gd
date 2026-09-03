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

## Characters currently on the pad. -1 means the whole transcript is written.
var _visible_characters: int = -1
var _is_writing: bool = false

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

func is_writing() -> bool:
	return _is_writing

func get_visible_character_count() -> int:
	if _visible_characters < 0:
		return _transcript_text.length()
	return mini(_visible_characters, _transcript_text.length())

## Starts Elias's hand writing. The whole hook of the game is that the player can
## watch WATCHER appear on the pad while WATER is still coming out of the
## sounder; dumping the finished text at the end of the message hides the one
## moment the design exists for.
func begin_writing(text: String) -> void:
	_transcript_text = text
	_is_revealed = true
	_is_writing = true
	_visible_characters = 0
	_update_display()

## Progress is driven by the Morse schedule, not a private timer, so the hand
## keeps pace with the signal exactly.
func set_writing_progress(ratio: float) -> void:
	if not _is_writing or _transcript_text.is_empty():
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	var target := int(floor(clamped * float(_transcript_text.length()) + 0.0001))
	if target > _visible_characters:
		_visible_characters = target
		_update_display()

func set_transcript_text(text: String) -> void:
	_transcript_text = text
	_update_display()

func reveal_transcript() -> void:
	_is_revealed = true
	_is_writing = false
	_visible_characters = -1
	_update_display()

func clear_transcript() -> void:
	_transcript_text = ""
	_is_revealed = false
	_is_writing = false
	_visible_characters = -1
	_update_display()

## What is physically on the pad right now, which during a transmission is less
## than the full transcript.
func get_display_text() -> String:
	if not _is_revealed or _transcript_text.is_empty():
		return empty_placeholder
	if _visible_characters < 0 or _visible_characters >= _transcript_text.length():
		return _transcript_text
	return _transcript_text.substr(0, _visible_characters)

func _update_display() -> void:
	var lbl := get_label_3d()
	if lbl != null:
		lbl.text = get_display_text()

func _on_interacted() -> void:
	transcript_inspected.emit(get_display_text())
