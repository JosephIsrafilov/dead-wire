class_name AmericanMorseEncoder
extends RefCounted

const INTER_LETTER_GAP_UNITS: int = 3
const INTER_WORD_GAP_UNITS: int = 6

func get_encoding_errors(
	message: String,
	alphabet: AmericanMorseAlphabetData
) -> PackedStringArray:
	var errors := PackedStringArray()

	if alphabet == null:
		errors.append("Alphabet cannot be null")
		return errors

	var alphabet_errors: PackedStringArray = alphabet.get_validation_errors()
	if not alphabet_errors.is_empty():
		for err in alphabet_errors:
			errors.append("Invalid alphabet: %s" % err)
		return errors

	if message.is_empty():
		errors.append("Message cannot be empty")
		return errors

	if message.begins_with(" "):
		errors.append("Message cannot have leading space")

	if message.ends_with(" "):
		errors.append("Message cannot have trailing space")

	if message.contains("  "):
		errors.append("Message cannot contain consecutive spaces")

	for i in range(message.length()):
		var c: String = message[i]
		if c == " ":
			continue
		if c in ["\n", "\r", "\t"]:
			errors.append("Unsupported whitespace character at position %d (ASCII %d)" % [i, c.unicode_at(0)])
			continue
		if c != c.to_upper() and c.to_upper() != c.to_lower():
			errors.append("Lowercase character '%s' at position %d is not permitted" % [c, i])
			continue
		if not alphabet.has_symbol(c):
			errors.append("Unsupported symbol '%s' at position %d" % [c, i])

	return errors

func encode(
	message: String,
	alphabet: AmericanMorseAlphabetData
) -> MorseSequenceData:
	var errors: PackedStringArray = get_encoding_errors(message, alphabet)
	if not errors.is_empty():
		return null

	var words: PackedStringArray = message.split(" ")
	var output_events: Array[MorseTimingEvent] = []

	for w_idx in range(words.size()):
		var word: String = words[w_idx]
		for c_idx in range(word.length()):
			var char_str: String = word[c_idx]
			var char_seq: MorseSequenceData = alphabet.get_sequence(char_str)
			if char_seq == null:
				return null

			# Deep copy every timing event from alphabet sequence
			for ev in char_seq.events:
				var new_ev := MorseTimingEvent.new()
				new_ev.kind = ev.kind
				new_ev.duration_units = ev.duration_units
				output_events.append(new_ev)

			# Insert inter-letter gap between letters within the same word
			if c_idx < word.length() - 1:
				var letter_gap := MorseTimingEvent.new()
				letter_gap.kind = MorseTimingEvent.Kind.GAP
				letter_gap.duration_units = INTER_LETTER_GAP_UNITS
				output_events.append(letter_gap)

		# Insert inter-word gap between words
		if w_idx < words.size() - 1:
			var word_gap := MorseTimingEvent.new()
			word_gap.kind = MorseTimingEvent.Kind.GAP
			word_gap.duration_units = INTER_WORD_GAP_UNITS
			output_events.append(word_gap)

	var result := MorseSequenceData.new()
	result.events = output_events
	return result
