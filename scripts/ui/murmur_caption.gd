class_name MurmurCaption
extends CanvasLayer

## Elias murmuring under the copy: the letters he hears, spelled out as a
## quiet caption while the sounder works. This is the perception layer made
## visible — it listens to the session's whisper signal alone and never
## learns what the hand writes or what the sender truly sent, so the voice
## and the ink may disagree.

@export var session: TelegraphSessionController
## How long the finished whisper stays readable after the wire falls silent,
## and how slowly it fades afterwards.
@export var hold_seconds: float = 4.0
@export var fade_seconds: float = 1.5
## Reading the sheet or leaving the chair cuts the whisper short — faster than
## the natural fade, so the voice never doubles as a cheat sheet the player
## holds next to the ink or carries across the room.
@export var dismiss_fade_seconds: float = 0.6

## Letter and word spacing of the whispered string; a word gap is a double
## interval so two words never read as one long letter run.
const GLYPH_SEPARATOR := " · "
const WORD_SEPARATOR := "  ·  "
## Quieter than a spoken thought: the murmur stays below full attention.
const MURMUR_ALPHA := 0.55

enum VoiceState {
	SILENT,
	WHISPERING,
	HOLDING,
	FADING,
	DISMISSING,
}

var _state: VoiceState = VoiceState.SILENT
var _perception_text: String = ""
var _revealed: int = 0
var _label: Label = null
var _hold_elapsed: float = 0.0
var _fade_elapsed: float = 0.0
## Alpha the current dismissal started from, so a dismiss mid-fade never pops.
var _dismiss_from_alpha: float = 1.0

func _ready() -> void:
	# Pausing the night pauses the whisper with it (default pausable mode).
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -228.0
	_label.offset_bottom = -176.0
	_label.offset_left = 24.0
	_label.offset_right = -24.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", preload("res://assets/fonts/noto/NotoSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, MURMUR_ALPHA))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_text("")
	_bind_session()

func _bind_session() -> void:
	if session == null:
		return
	if not session.transmission_started.is_connected(_on_transmission_started):
		session.transmission_started.connect(_on_transmission_started)
	if not session.perception_glyph.is_connected(_on_perception_glyph):
		session.perception_glyph.connect(_on_perception_glyph)
	if not session.transmission_finished.is_connected(_on_transmission_finished):
		session.transmission_finished.connect(_on_transmission_finished)
	if not session.operator_stood.is_connected(_on_operator_stood):
		session.operator_stood.connect(_on_operator_stood)
	var paper: TranscriptPaper = session.transcript_paper
	if paper != null and not paper.transcript_inspected.is_connected(_on_transcript_inspected):
		paper.transcript_inspected.connect(_on_transcript_inspected)

## A new telegram clears the murmur: the voice only ever spells the message
## currently being heard.
func _on_transmission_started(scenario: TelegraphScenarioData) -> void:
	_perception_text = scenario.transmission_data.elias_perception
	_revealed = 0
	_state = VoiceState.WHISPERING
	_hold_elapsed = 0.0
	_fade_elapsed = 0.0
	_apply_text("")

func _on_perception_glyph(_scenario_id: String, index: int, _glyph: String) -> void:
	if _state != VoiceState.WHISPERING:
		return
	if index == 0:
		_revealed = 0
	_revealed = maxi(_revealed, index + 1)
	_apply_text(_render())

## The wire falls silent; the finished whisper lingers, then fades.
func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	if _state == VoiceState.WHISPERING:
		_state = VoiceState.HOLDING
		_hold_elapsed = 0.0

func _process(delta: float) -> void:
	match _state:
		VoiceState.HOLDING:
			_hold_elapsed += delta
			if _hold_elapsed >= hold_seconds:
				_state = VoiceState.FADING
				_fade_elapsed = 0.0
		VoiceState.FADING:
			_fade_elapsed += delta
			if _label != null:
				_label.modulate.a = 1.0 - clampf(_fade_elapsed / maxf(fade_seconds, 0.01), 0.0, 1.0)
			if _fade_elapsed >= fade_seconds:
				_go_silent()
		VoiceState.DISMISSING:
			_fade_elapsed += delta
			if _label != null:
				var progress := clampf(_fade_elapsed / maxf(dismiss_fade_seconds, 0.01), 0.0, 1.0)
				_label.modulate.a = _dismiss_from_alpha * (1.0 - progress)
			if _fade_elapsed >= dismiss_fade_seconds:
				_go_silent()
		_:
			pass

## The sheet is in the player's hands: the voice stops being a reference.
func _on_transcript_inspected(_text: String) -> void:
	_dismiss()

## Leaving the chair takes the ear with it.
func _on_operator_stood() -> void:
	_dismiss()

## Cut the current whisper short, from whatever alpha it has right now.
func _dismiss() -> void:
	match _state:
		VoiceState.SILENT, VoiceState.DISMISSING:
			return
		_:
			_dismiss_from_alpha = _label.modulate.a if _label != null else 1.0
			_state = VoiceState.DISMISSING
			_fade_elapsed = 0.0

func get_display_text() -> String:
	return _label.text if _label != null else ""

func is_holding() -> bool:
	return _state == VoiceState.HOLDING

func is_fading() -> bool:
	return _state == VoiceState.FADING

func is_dismissing() -> bool:
	return _state == VoiceState.DISMISSING

func is_visible_on_screen() -> bool:
	return _label != null and _label.is_visible_in_tree()

## The whispered prefix: `count` heard glyphs of the perception text, lower
## case, letter-spaced, with a double interval at word boundaries.
func _render() -> String:
	var out := ""
	var glyph_index := 0
	var word_gap_pending := false
	for i in range(_perception_text.length()):
		var character := _perception_text[i]
		if character == " ":
			word_gap_pending = true
			continue
		if glyph_index >= _revealed:
			break
		if glyph_index > 0:
			out += WORD_SEPARATOR if word_gap_pending else GLYPH_SEPARATOR
		out += character.to_lower()
		word_gap_pending = false
		glyph_index += 1
	return out

func _apply_text(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = not text.is_empty()
	_label.modulate.a = 1.0

func _go_silent() -> void:
	_state = VoiceState.SILENT
	_apply_text("")
