class_name AmericanMorseAlphabetData
extends Resource

@export var entries: Array[AmericanMorseCharacterData] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if entries.is_empty():
		errors.append("Alphabet entries cannot be empty")
		return errors

	var seen_symbols: Dictionary = {}

	for i in range(entries.size()):
		var entry := entries[i]
		if entry == null:
			errors.append("Entry at index %d is null" % i)
			continue

		var entry_errors := entry.get_validation_errors()
		for err in entry_errors:
			errors.append("Entry at index %d ('%s') error: %s" % [i, entry.symbol, err])

		if not entry.symbol.is_empty():
			if seen_symbols.has(entry.symbol):
				errors.append(
					"Duplicate symbol '%s' at index %d (first seen at index %d)"
					% [entry.symbol, i, seen_symbols[entry.symbol]]
				)
			else:
				seen_symbols[entry.symbol] = i

	return errors

func has_symbol(symbol: String) -> bool:
	if symbol.is_empty():
		return false
	for entry in entries:
		if entry != null and entry.symbol == symbol:
			return true
	return false

func get_sequence(symbol: String) -> MorseSequenceData:
	if symbol.is_empty():
		return null
	for entry in entries:
		if entry != null and entry.symbol == symbol:
			return entry.sequence
	return null
