class_name MorseReferenceCard
extends Node3D

signal card_inspected(text: String)
signal card_closed()

## The operator's lookup card. One rule above all: the printed patterns come
## from the game's own American Morse alphabet resource — the same sequences
## the wire actually plays. Nothing here is typed by hand, so the card and
## the wire can never disagree again.
##
## Pattern rendering (American Morse, 1894):
##   press 1 unit  -> ·
##   press 3 units -> —
##   press 6 units -> ——— (long)   [the letter L]
##   gap 1 unit    -> single space (between marks of a character)
##   gap 2 units   -> double space (the distinguishing INTERNAL pause of
##                    American Morse: C, O, R — a real phoneme, not layout)

@export var prompt_message: String = "Inspect Morse Reference Card"

## The card's printed face: compact table for the desk.
const CARD_HEADER: String = "AMERICAN MORSE CODE 1894"
const CARD_PIXEL_SIZE: float = 0.0016
const CARD_FONT_SIZE: int = 13
const CARD_WIDTH: float = 0.30
const CARD_DEPTH: float = 0.34

## The viewer's printed face: the wide mono table.
const VIEWER_HEADER: String = "AMERICAN MORSE CODE (1894)"

const ALPHABET_PATH: String = "res://data/morse/m1_american_morse_alphabet.tres"
## Reading order as the viewer has always shown it: two columns, nine rows.
const LEFT_COLUMN: Array[String] = ["A", "C", "D", "E", "F", "G", "H", "I", "L"]
const RIGHT_COLUMN: Array[String] = ["N", "O", "R", "S", "T", "U", "W", "1", "7"]

var interactable: Interactable = null
var label_3d: Label3D = null
var _alphabet: AmericanMorseAlphabetData = null

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D
	_alphabet = load(ALPHABET_PATH) as AmericanMorseAlphabetData

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	if label_3d != null:
		# The whole table is printed on the physical card: a working operator
		# can check a glyph against the wall of his own desk without opening
		# the viewer. Nothing here singles out the final answer's letters.
		label_3d.text = get_card_text()

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

## The pattern of one character, derived from the wire's own data. This is
## the ONLY place a sequence becomes printed ink.
static func render_pattern(sequence: MorseSequenceData) -> String:
	if sequence == null:
		return "?"
	var out := ""
	for event in sequence.events:
		if event == null:
			continue
		if event.kind == 0:
			match event.duration_units:
				1: out += "·"
				3: out += "—"
				6: out += "——— (long)"
				_: out += "·%d·" % event.duration_units
		else:
			match event.duration_units:
				1: out += " "
				2: out += "  "
				_: out += "   "
	return out

## Rows of the table: "A · —   N — ·" pairs in the wire's own reading order.
static func render_rows(alphabet: AmericanMorseAlphabetData) -> Array[String]:
	var rows: Array[String] = []
	for index in LEFT_COLUMN.size():
		var left := LEFT_COLUMN[index]
		var right := RIGHT_COLUMN[index] if index < RIGHT_COLUMN.size() else ""
		var row := "%s %s" % [left, render_pattern(alphabet.get_sequence(left))]
		if not right.is_empty():
			row += "   %s %s" % [right, render_pattern(alphabet.get_sequence(right))]
		rows.append(row)
	return rows

## The desk card's face: header plus the pattern rows.
func get_card_text() -> String:
	return "%s\n%s" % [CARD_HEADER, "\n".join(render_rows(_load_alphabet()))]

## The viewer's face: the wide mono table. render_pattern already annotates
## the long dash, so both faces carry the same annotation from one source.
func get_reference_text() -> String:
	var header := VIEWER_HEADER
	var divider := "─".repeat(28)
	var rows := render_rows(_load_alphabet())
	return "%s\n%s\n%s" % [header, divider, "\n".join(rows)]

func _load_alphabet() -> AmericanMorseAlphabetData:
	if _alphabet == null:
		_alphabet = load(ALPHABET_PATH) as AmericanMorseAlphabetData
	return _alphabet

func _on_interacted() -> void:
	card_inspected.emit(get_reference_text())
