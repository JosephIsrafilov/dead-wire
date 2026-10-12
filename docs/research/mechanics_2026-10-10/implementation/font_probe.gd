extends SceneTree
func _initialize() -> void:
	var font: Font = load("res://assets/fonts/courierprime/CourierPrime-Regular.ttf")
	for symbol in ["·", "—", "◌"]:
		print("FONT_GLYPH ", symbol, " ", font.has_char(symbol.unicode_at(0)))
	quit(0)
