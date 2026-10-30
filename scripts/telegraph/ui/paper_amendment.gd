class_name PaperAmendment
extends Node3D

## A correction entered by hand on the copy itself (plan 6.3): the copied
## lines are struck through with a ruled pen line, and the correction is
## written beneath them in the same hand, glyph by glyph. Ink lands only when
## the writer rig reports contact, exactly as it does for the copy.

## Space between the last copied row and the correction, in rows.
@export var gap_rows: float = 0.55
@export var strike_thickness: float = 0.0011

var word: String = ""
var inked: int = 0
## True while the hand is writing the correction: the sheet's contacts and
## ink belong to the correction until the pen leaves.
var active: bool = false
var _label: Label3D = null
var _strikes: Array[MeshInstance3D] = []
var _ink: StandardMaterial3D = null

func _paper() -> TranscriptPaper:
	var node := get_parent()
	while node != null and not (node is TranscriptPaper):
		node = node.get_parent()
	return node as TranscriptPaper

## The pen goes to the copy: strike the copied rows and open a line beneath.
func begin() -> void:
	clear()
	var paper := _paper()
	var copy := paper.get_label_3d() if paper != null else null
	if copy == null:
		return
	active = true
	_ink = StandardMaterial3D.new()
	_ink.albedo_color = Color(copy.modulate.r, copy.modulate.g, copy.modulate.b, 1.0)
	_ink.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var font := copy.font if copy.font != null else ThemeDB.fallback_font
	var line := font.get_height(copy.font_size)
	var rows := TranscriptPaper.layout_text(paper.get_display_text()).split("\n")
	for row in rows.size():
		var width := font.get_string_size(rows[row], HORIZONTAL_ALIGNMENT_LEFT, -1, copy.font_size).x
		if width <= 0.0:
			continue
		var strike := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width * copy.pixel_size + 0.004, strike_thickness, 0.0004)
		box.material = _ink
		strike.mesh = box
		var middle := line * row + font.get_ascent(copy.font_size) * 0.62
		var centre := Vector3(width * 0.5 * copy.pixel_size, -middle * copy.pixel_size, 0.0006)
		strike.transform = Transform3D(copy.basis, copy.position + copy.basis * centre)
		add_child(strike)
		_strikes.append(strike)
	_label = copy.duplicate() as Label3D
	_label.name = "AmendLabel"
	_label.text = ""
	_label.position = copy.position + copy.basis * Vector3(0.0, -line * (rows.size() + gap_rows) * copy.pixel_size, 0.0)
	add_child(_label)

func type_letter(letter: String) -> void:
	if active:
		word += letter

func erase_letter() -> void:
	if not active or word.is_empty():
		return
	word = word.substr(0, word.length() - 1)
	inked = mini(inked, word.length())
	_show()

func is_fully_inked() -> bool:
	return inked >= word.length()

## Ink lands on the rig's contact for glyph `index`, never before.
func ink(index: int) -> void:
	if not active or index != inked or index >= word.length():
		return
	inked += 1
	_show()

func end_writing() -> void:
	active = false

func clear() -> void:
	active = false
	word = ""
	inked = 0
	for strike in _strikes:
		strike.queue_free()
	_strikes.clear()
	if _label != null:
		_label.queue_free()
	_label = null

func get_written_text() -> String:
	return word.substr(0, inked)

func get_strike_count() -> int:
	return _strikes.size()

func get_glyph_contact(index: int) -> Vector3:
	if _label == null:
		return Vector3.ZERO
	var prefix := TranscriptPaper.layout_before_glyph(word, index)
	var font := _label.font if _label.font != null else ThemeDB.fallback_font
	var preceding := prefix.substr(prefix.rfind("\n") + 1)
	var x := font.get_string_size(preceding, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.font_size).x
	var y := font.get_height(_label.font_size) * float(prefix.count("\n")) + font.get_ascent(_label.font_size)
	return _label.position + _label.basis * Vector3(x * _label.pixel_size, -y * _label.pixel_size, 0.0005)

func _show() -> void:
	if _label != null:
		_label.text = TranscriptPaper.layout_text(word, inked)
