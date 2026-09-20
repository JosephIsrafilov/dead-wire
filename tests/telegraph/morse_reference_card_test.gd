extends SceneTree

## C1: the printed Morse card derives from the wire's own alphabet — no
## hand-typed patterns anywhere. Every symbol's pattern must be IDENTICAL in
## the alphabet resource, on the desk card, and in the viewer text.
## The regression traps are the exact mistakes once shipped by hand:
## W with three dashes, 1 with three dashes, O/R/C losing their
## distinguishing internal pause.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Morse Reference Card Test Suite ---")
	var alphabet := load("res://data/morse/m1_american_morse_alphabet.tres") as AmericanMorseAlphabetData
	if not assert_condition(alphabet != null and alphabet.entries.size() == 18, "Alphabet resource loads with 18 entries"): return

	var card := (load("res://scenes/telegraph/morse_reference_card.tscn") as PackedScene).instantiate() as MorseReferenceCard
	root.add_child(card)
	await process_frame
	var label := card.get_node("Label3D") as Label3D
	var card_text := label.text
	var viewer_text := card.get_reference_text()
	if not assert_condition(not card_text.is_empty() and not viewer_text.is_empty(), "Both faces render non-empty"): return

	var checked := 0
	for entry in alphabet.entries:
		if entry == null:
			continue
		var symbol := entry.symbol
		var truth := MorseReferenceCard.render_pattern(entry.sequence)
		if not assert_condition(not truth.is_empty() and truth != "?", "Symbol %s renders a pattern from its own data" % symbol): return
		if not assert_condition(_row_pattern(card_text, symbol) == truth, "Card face matches the wire for %s ('%s')" % [symbol, truth]): return
		if not assert_condition(_row_pattern(viewer_text, symbol) == truth, "Viewer face matches the wire for %s ('%s')" % [symbol, truth]): return
		checked += 1
	if not assert_condition(checked == 18, "All 18 symbols checked, got %d" % checked): return

	# Regression traps: the hand-typed mistakes must never come back.
	if not assert_condition(not card_text.contains("·———·"), "No three-dash numeral pattern on the card"): return
	if not assert_condition(card_text.contains("· — —\n") or _row_pattern(card_text, "W") == "· — —", "W keeps its two dashes"): return
	if not assert_condition(_row_pattern(card_text, "O") == "·  ·", "O keeps the distinguishing pause"): return
	if not assert_condition(_row_pattern(card_text, "R") == "·  · ·", "R keeps the distinguishing pause"): return
	if not assert_condition(_row_pattern(card_text, "C") == "· ·  ·", "C keeps the distinguishing pause"): return
	if not assert_condition(_row_pattern(card_text, "L") == "——— (long)", "L keeps the long-dash annotation"): return

	# The card and the viewer are two renderings of ONE source: neither
	# carries a private copy of any pattern.
	if not assert_condition(card.get_card_text() == card_text, "get_card_text matches the printed label"): return
	if not assert_condition(card.get_reference_text().contains("AMERICAN MORSE CODE (1894)"), "Viewer header keeps its form"): return

	card.queue_free()
	await process_frame
	print("--- All Morse Reference Card Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

## The pattern part of the row that begins with `symbol`: everything after
## the first space, up to the next column marker (three spaces) or line end.
## Spaces INSIDE the pattern are significant: the double space is the
## distinguishing pause of American Morse.
func _row_pattern(text: String, symbol: String) -> String:
	for line in text.split("\n"):
		var columns := line.split("   ")
		for column in columns:
			var trimmed := column.strip_edges()
			if trimmed.begins_with(symbol + " "):
				return trimmed.substr(symbol.length() + 1).strip_edges()
	return ""

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
