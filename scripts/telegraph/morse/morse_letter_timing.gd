class_name MorseLetterTiming
extends RefCounted

## Pure timing helper: where each letter of a message ends on the wire,
## expressed as a fraction of the message's total duration. The reveal cues
## and the perception whisper both use it so the hand and the voice stay
## locked to the letters the sounder actually sent. Gap rules are the
## encoder's own (INTER_LETTER_GAP_UNITS / INTER_WORD_GAP_UNITS); a message
## containing a symbol the alphabet cannot encode yields no fractions.

## One fraction per non-space glyph: the end of its last MARK, normalized by
## the message's total unit count. Empty when the message does not encode.
static func letter_end_fractions(message: String, alphabet: AmericanMorseAlphabetData) -> PackedFloat32Array:
	var ends := PackedFloat32Array()
	if alphabet == null or message.is_empty():
		return ends
	var units := 0
	var words := message.split(" ")
	for w_idx in range(words.size()):
		var word := words[w_idx]
		for c_idx in range(word.length()):
			var sequence := alphabet.get_sequence(word[c_idx])
			if sequence == null:
				return PackedFloat32Array()
			units += sequence.total_duration_units()
			ends.append(float(units))
			if c_idx < word.length() - 1:
				units += AmericanMorseEncoder.INTER_LETTER_GAP_UNITS
		if w_idx < words.size() - 1:
			units += AmericanMorseEncoder.INTER_WORD_GAP_UNITS
	if units <= 0:
		return PackedFloat32Array()
	for i in range(ends.size()):
		ends[i] = ends[i] / float(units)
	return ends
