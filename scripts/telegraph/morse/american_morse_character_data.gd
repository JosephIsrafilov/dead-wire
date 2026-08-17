class_name AmericanMorseCharacterData
extends Resource

@export var symbol: String = ""
@export var sequence: MorseSequenceData

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if symbol.is_empty():
		errors.append("Symbol cannot be empty")
	elif symbol.length() != 1:
		errors.append("Symbol must be exactly 1 character long, got %d ('%s')" % [symbol.length(), symbol])
	else:
		if symbol.strip_edges().is_empty():
			errors.append("Symbol cannot be whitespace")
		elif symbol != symbol.to_upper():
			errors.append("Symbol must be uppercase, got '%s'" % symbol)

	if sequence == null:
		errors.append("Sequence cannot be null for symbol '%s'" % symbol)
	else:
		var seq_errors := sequence.get_validation_errors()
		for err in seq_errors:
			errors.append("Sequence error for symbol '%s': %s" % [symbol, err])

	return errors
