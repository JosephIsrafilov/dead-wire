# tests/ui/document_resize_test.gd
extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: failures += 1
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var viewer: Variant = load("res://scenes/ui/document_viewer.tscn").instantiate()
	root.add_child(viewer)
	await process_frame
	viewer.open_duration = 0.0
	viewer.open_document("transcript_paper", "COPY", "WATCHER")
	viewer.call("set_text_scale", 1.5)
	var copy := viewer.get_node("TranscriptSheet") as TextureRect
	var ink := copy.get_node("Ink") as Label
	var footer := viewer.get_node("CopyReadingFooter") as Label
	var backing := viewer.get_node_or_null("CopyReadingFooterBacking") as ColorRect
	check(backing != null and backing.color.a >= 0.99 and backing.color.get_luminance() < 0.2, "Fixed footer sits on an opaque dark backing, not light ink on pale paper")
	check(backing != null and backing.get_global_rect().encloses(footer.get_global_rect()), "Footer text lies fully inside its dark backing")
	copy.size = Vector2(100, 100)
	copy.position.y = -500.0
	footer.position.y = 0.0
	var before_ink := ink.text
	viewer.set_live_footer("Sender waiting — release due")
	root.size_changed.emit()
	for i in 3: await process_frame
	var area: Vector2 = viewer.get_viewport().get_visible_rect().size
	check(footer.text.contains("Sender waiting"), "Viewport resize keeps the live deadline on the fixed footer")
	check(copy.size.y > 100.0 and copy.position.y >= -500.0 and copy.position.y <= 32.0, "Viewport resize signal re-presents the open transcript sheet and re-clamps its pan")
	check(footer.get_global_rect().end.y <= area.y + 0.5 and footer.get_global_rect().position.y >= area.y - 60.0, "Viewport resize recomputes the fixed footer to the bottom of the viewport")
	check(backing != null and backing.get_global_rect().encloses(footer.get_global_rect()), "Footer backing still encloses footer after resize")
	check(ink.text == before_ink and viewer.body_label.text == "WATCHER" and viewer.get_current_doc_id() == "transcript_paper", "Resize keeps logical content and evidence unchanged")
	check(copy.position.y <= 32.0 and copy.position.y >= minf(32.0, area.y - 64.0 - copy.size.y), "Resize keeps the sheet pan within bounded limits")
	for doc_id in ["tape_register", "morse_reference", "duty_sheet", "shift_card"]:
		viewer.open_document("transcript_paper", "COPY", "WATCHER", "[E / Esc] Put Down Document")
		await process_frame
		viewer.open_document(doc_id, "OTHER", "NON COPY BODY")
		await process_frame
		var hidden_backing := viewer.get_node_or_null("CopyReadingFooterBacking") as ColorRect
		check(hidden_backing != null and not hidden_backing.visible, "Opening %s after copy hides the copy reading footer backing" % doc_id)
		check(not footer.visible and not copy.visible and viewer.get_node("CenterContainer").visible, "Opening %s after copy hides copy footer and shows the printed card" % doc_id)
		check(viewer.body_label.text == "NON COPY BODY" and viewer.get_current_doc_id() == doc_id, "Opening %s after copy keeps its logical body and doc id" % doc_id)
	viewer.queue_free()
	await process_frame
	quit(1 if failures else 0)
