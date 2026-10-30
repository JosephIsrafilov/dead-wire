extends SceneTree

var passed := 0
func _init() -> void: _run.call_deferred()
func require(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok: quit(1); return false
	passed += 1
	return true

func _run() -> void:
	var paper := load("res://scenes/telegraph/transcript_paper.tscn").instantiate() as TranscriptPaper
	root.add_child(paper)
	paper.set_process(false)
	var text := "TRAIN 17 CLEAR EAST"
	paper.set_transcript_text(text)
	paper.reveal_transcript()
	if not require(paper.get_label_3d().text == "TRAIN 17\nCLEAR\nEAST", "A word moves whole into the next available row, and a row never outgrows the sheet"): return
	var layout := paper.get_label_3d().text
	for length in text.length() + 1:
		var prefix := paper._layout_prefix(text.substr(0, length))
		if not require(layout.begins_with(prefix), "Already written ink stays still at prefix %d" % length): return
	var rig := paper.get_writer_rig()
	if not require(rig._layout_row_of_glyph(text, 7) == 1, "The C contact uses the new row before the old hard limit"): return
	if not require(paper.get_glyph_contact(7).y < paper.get_glyph_contact(6).y or
			paper.get_glyph_contact(7).z != paper.get_glyph_contact(6).z, "The nib contact follows the wrapped row"): return
	var viewer := load("res://scenes/ui/document_viewer.tscn").instantiate() as DocumentViewer
	root.add_child(viewer)
	viewer.open_document("transcript_paper", "", text)
	if not require(viewer.get_node("TranscriptSheet/Ink").text == layout, "Lifted ink uses the same word layout as the writing pad"): return
	# A copy lifted mid-word wraps by the whole message, not by the prefix.
	viewer.open_document("transcript_paper", "", "TRAIN 17 C")
	if not require(viewer.get_node("TranscriptSheet/Ink").text == "TRAIN 17\nC", "A half-written word already sits on its final row"): return
	paper.begin_writing(text)
	paper.advance_paper(paper.feed_seconds + rig.enter_duration + 0.01)
	paper.set_writing_progress(1.0)
	var contacts: Array[int] = []
	rig.glyph_contact.connect(func(index: int): contacts.append(index))
	var one_per_tick := true
	var only_contacts := true
	for tick in 100:
		var before := paper.get_written_glyph_count()
		paper.advance_paper(0.5)
		one_per_tick = one_per_tick and paper.get_written_glyph_count() - before <= 1
		only_contacts = only_contacts and paper.get_written_glyph_count() == contacts.size()
		if paper.is_ready_to_inspect(): break
	if not require(paper.is_ready_to_inspect(), "The wrapped message finishes through the real rig"): return
	if not require(one_per_tick, "Wrapping still writes at most one glyph per presentation tick"): return
	if not require(only_contacts, "Every wrapped glyph is inked only on contact"): return
	if not require(paper.get_label_3d().text == layout, "Live writing ends at the precomputed layout"): return
	paper.queue_free()
	viewer.queue_free()
	await process_frame
	print("Transcript wrap assertions: ", passed)
	quit(0)
