extends SceneTree
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: quit(1)
	return ok
func _run() -> void:
	var card := MorseReferenceCard.new()
	var text := card.get_reference_text()
	if not check(text.contains("WORKED EXAMPLE: AL"), "Reference labels its own AL example"): return
	if not check(text.contains("letter gap: 3") and text.contains("word gap: 6"), "Card explains letter and word timing"): return
	if not check(text.contains("internal pause: 2"), "American Morse internal pause remains explicit"): return
	var alphabet := load(MorseReferenceCard.ALPHABET_PATH) as AmericanMorseAlphabetData
	var example := AmericanMorseEncoder.new().encode("AL", alphabet)
	if not check(text.contains(MorseReferenceCard.render_pattern(example)), "Example is rendered from live encoder output"): return
	if not check(text.contains("Wire take numbers") and text.contains("not decoded words"), "Wire take boundaries are not a translation"): return
	card.free()
	quit(0)
