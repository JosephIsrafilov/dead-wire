extends SceneTree

## Fresh ink is wet only where ink actually landed: a sheen per inked glyph,
## at most three at once, each one dries away, and a new sheet starts dry.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Wet Ink Test Suite ---")
	var paper := (load("res://scenes/telegraph/transcript_paper.tscn") as PackedScene).instantiate() as TranscriptPaper
	root.add_child(paper)
	paper.set_process(false)
	paper.feed_seconds = 0.0
	await process_frame
	var wet := paper.get_node_or_null("Sheet/WetInk") as WetInk
	if not assert_condition(wet != null, "The sheet carries a wet-ink layer"): return
	wet.set_process(false)
	var rig := paper.get_writer_rig()
	rig.set_process(false)

	paper.begin_writing("WATCHER")
	paper.advance_paper(rig.enter_duration + 0.01)
	if not assert_condition(wet.get_wet_count() == 0, "Before any contact nothing is wet"): return
	paper.set_writing_progress(1.0)
	paper.advance_paper(0.3)
	if not assert_condition(paper.get_written_glyph_count() == 1 and wet.get_wet_count() == 1, "One inked glyph leaves one sheen"): return
	var guard := 0
	while paper.get_written_glyph_count() < 5 and guard < 50:
		paper.set_writing_progress(1.0)
		paper.advance_paper(0.3)
		guard += 1
	if not assert_condition(wet.get_wet_count() == wet.max_glints, "Only the last %d letters are wet" % wet.max_glints): return

	var sheen := wet.get_child(wet.get_child_count() - 1) as MeshInstance3D
	var contact := paper.get_glyph_contact(paper.get_written_glyph_count() - 1)
	if not assert_condition(sheen.position.distance_to(contact) < 0.02, "The newest sheen sits on the newest glyph"): return

	wet.advance(wet.life_max + 0.1)
	if not assert_condition(wet.get_wet_count() == 0, "Every sheen dries within the longest drying time"): return

	paper.begin_writing("NEW")
	paper.advance_paper(rig.enter_duration + 0.01)
	paper.set_writing_progress(1.0)
	paper.advance_paper(0.3)
	if not assert_condition(wet.get_wet_count() == 1, "A new sheet starts dry, then its first glyph is wet"): return

	paper.queue_free()
	await process_frame
	print("--- All Wet Ink Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
