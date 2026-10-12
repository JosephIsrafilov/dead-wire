extends SceneTree
## Font contract for Elias's authored working hand: one generated font serves
## live and archived paper, while the forms builder uses its metrics.
const FONT_PATH := "res://assets/fonts/elias_working/elias_working.fnt"
const ATLAS_PATH := "res://assets/fonts/elias_working/elias_working_atlas.png"
const GLYPH_SOURCE_DIR := "res://assets/fonts/elias_working"
const REQUIRED_GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?;:'-/()"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _a(ResourceLoader.exists(FONT_PATH), "Generated Elias BMFont exists"): return
	if not _a(ResourceLoader.exists(ATLAS_PATH), "Generated Elias atlas exists"): return
	var metrics := FileAccess.get_file_as_string(FONT_PATH)
	if not _a(metrics.contains("face=\"Elias Working\""), "BMFont identifies Elias Working"): return
	if not _a(metrics.contains("lineHeight=80 base=54"), "BMFont keeps explicit vertical metrics"): return
	for character in REQUIRED_GLYPHS:
		var code := character.unicode_at(0)
		if not _a(metrics.contains("char id=%d " % code), "Metrics include %s" % character): return
		var source := "glyph_space.svg" if character == " " else "glyph_u%04X.svg" % code
		if not _a(FileAccess.file_exists(GLYPH_SOURCE_DIR + "/" + source), "Editable SVG exists for %s" % character): return
	var scene_text := FileAccess.get_file_as_string("res://scenes/telegraph/transcript_paper.tscn")
	if not _a(scene_text.count(FONT_PATH) == 1, "Live and archive labels share one font resource"): return
	var forms_text := FileAccess.get_file_as_string("res://tools/build_paper_forms.gd")
	if not _a(forms_text.contains("const HAND := preload(\"%s\")" % FONT_PATH), "Forms builder uses the matching handwriting metrics"): return
	if not _a(TranscriptPaper.GLYPH_COLUMNS == 10, "Ten-column transcript layout is preserved"): return
	var scene := load("res://scenes/telegraph/transcript_paper.tscn") as PackedScene
	if not _a(scene != null, "Transcript scene loads with the generated font"): return
	var paper := scene.instantiate() as TranscriptPaper
	root.add_child(paper)
	await process_frame
	var live := paper.get_label_3d().font
	var archive := paper.get_node("PreviousSheet/PreviousSheetText") as Label3D
	if not _a(live.resource_path == FONT_PATH and archive.font.resource_path == FONT_PATH, "Both paper labels resolve the generated font"): return
	if not _a(live.get_string_size("WATCHER 71", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 0.0, "Font provides measured transcript advances"): return
	paper.queue_free()
	quit(0)

func _a(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok: quit(1)
	return ok