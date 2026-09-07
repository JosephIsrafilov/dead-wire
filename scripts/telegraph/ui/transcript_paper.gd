class_name TranscriptPaper
extends Node3D

signal transcript_inspected(text: String)
signal transcript_closed()

@export var prompt_message: String = "Read Telegram Transcript"
@export var empty_placeholder: String = "[BLANK TELEGRAM PAD]"

var interactable: Interactable = null
var label_3d: Label3D = null
var writer_rig: WriterRig = null

var _transcript_text: String = ""
var _is_revealed: bool = false

## Characters currently on the pad. -1 means the whole transcript is written.
var _visible_characters: int = -1
var _is_writing: bool = false
var _reveal_cues: PackedFloat32Array = PackedFloat32Array()
var _cue_character_indices: PackedInt32Array = PackedInt32Array()
var _next_cue_index: int = 0
var _last_writing_progress: float = 0.0

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D
	writer_rig = get_node_or_null("WriterRig") as WriterRig

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

func get_writer_rig() -> WriterRig:
	if writer_rig == null:
		writer_rig = get_node_or_null("WriterRig") as WriterRig
	return writer_rig

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

func get_reveal_cues() -> PackedFloat32Array:
	return _reveal_cues

func is_using_authored_cues() -> bool:
	return not _reveal_cues.is_empty() and _reveal_cues.size() == _cue_character_indices.size()

func get_revealed_glyph_count() -> int:
	if not is_using_authored_cues():
		return get_visible_character_count()
	return _next_cue_index

## Starts Elias's hand writing. The whole hook of the game is that the player can
## watch WATCHER appear on the pad while WATER is still coming out of the
## sounder; dumping the finished text at the end of the message hides the one
## moment the design exists for.
func begin_writing(text: String, reveal_cues: PackedFloat32Array = PackedFloat32Array()) -> void:
	_cancel_writer_animation()
	_transcript_text = text
	_is_revealed = true
	_is_writing = true
	_visible_characters = 0
	_last_writing_progress = 0.0
	_set_authored_cues(reveal_cues)
	var rig := get_writer_rig()
	if rig != null:
		rig.begin_writing(_transcript_text)
	_update_display()

## Progress is driven by the Morse schedule, not a private timer, so the hand
## keeps pace with the signal exactly.
func set_writing_progress(ratio: float) -> void:
	if not _is_writing or _transcript_text.is_empty():
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped < _last_writing_progress:
		clamped = _last_writing_progress
	_last_writing_progress = clamped

	if is_using_authored_cues():
		var changed := false
		while _next_cue_index < _reveal_cues.size() and _reveal_cues[_next_cue_index] <= clamped + 0.00001:
			_visible_characters = _cue_character_indices[_next_cue_index] + 1
			_next_cue_index += 1
			changed = true
		# Spaces do not have authored cues, but they are part of the prefix once
		# the glyph before them is visible. Reveal trailing spaces at completion.
		if _next_cue_index >= _reveal_cues.size():
			_visible_characters = _transcript_text.length()
		# Move the nib first. The label update below is deliberately second so the
		# physical authoring motion leads each newly visible glyph.
		var authored_rig := get_writer_rig()
		if authored_rig != null and changed:
			authored_rig.set_writing_progress(clamped, _transcript_text, _next_cue_index - 1)
		if changed:
			_update_display()
		return

	var target := int(floor(clamped * float(_transcript_text.length()) + 0.0001))
	if target > _visible_characters:
		var legacy_rig := get_writer_rig()
		if legacy_rig != null:
			legacy_rig.set_writing_progress(clamped, _transcript_text, _glyphs_before_character(target) - 1)
		_visible_characters = target
		_update_display()

func set_transcript_text(text: String) -> void:
	_transcript_text = text
	if _is_writing:
		_set_authored_cues(_reveal_cues)
	_update_display()

func reveal_transcript() -> void:
	_is_revealed = true
	_is_writing = false
	_visible_characters = -1
	_next_cue_index = _reveal_cues.size()
	_last_writing_progress = 1.0
	var rig := get_writer_rig()
	if rig != null:
		rig.finish_writing()
	_update_display()

func clear_transcript() -> void:
	_cancel_writer_animation()
	_transcript_text = ""
	_is_revealed = false
	_is_writing = false
	_visible_characters = -1
	_reveal_cues = PackedFloat32Array()
	_cue_character_indices = PackedInt32Array()
	_next_cue_index = 0
	_last_writing_progress = 0.0
	_update_display()

func reset_for_new_transmission() -> void:
	clear_transcript()

func _set_authored_cues(cues: PackedFloat32Array) -> void:
	_reveal_cues = PackedFloat32Array()
	_cue_character_indices = PackedInt32Array()
	_next_cue_index = 0
	if cues.is_empty():
		return

	for index in _transcript_text.length():
		var glyph := _transcript_text.substr(index, 1)
		if glyph not in [" ", "\t", "\n", "\r"]:
			_cue_character_indices.append(index)
	if cues.size() != _cue_character_indices.size():
		# An invalid authored map must never strand the transcript. The legacy
		# duration ratio remains the deterministic fallback for old scenarios.
		_cue_character_indices = PackedInt32Array()
		return
	var previous := -1.0
	for cue in cues:
		if not is_finite(cue) or cue < 0.0 or cue > 1.0 or cue < previous:
			_reveal_cues = PackedFloat32Array()
			_cue_character_indices = PackedInt32Array()
			return
		_reveal_cues.append(cue)
		previous = cue

func _cancel_writer_animation() -> void:
	var rig := get_writer_rig()
	if rig != null:
		rig.reset()

func _glyphs_before_character(character_index: int) -> int:
	var count := 0
	for index in mini(character_index, _transcript_text.length()):
		var glyph := _transcript_text.substr(index, 1)
		if glyph not in [" ", "\t", "\n", "\r"]:
			count += 1
	return count

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
