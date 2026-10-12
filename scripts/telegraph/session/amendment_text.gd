class_name AmendmentText
extends RefCounted
## The editor displays uppercase explicitly. Authority never silently repairs input.
const MAX_LETTERS: int = 24
static func validation_error(word: String) -> String:
	if word.is_empty():
		return "Enter the correction you intend to file."
	if word.length() > MAX_LETTERS:
		return "Use at most 24 letters."
	for index in word.length():
		var code := word.unicode_at(index)
		if code < 65 or code > 90:
			return "Use letters A–Z only."
	return ""
