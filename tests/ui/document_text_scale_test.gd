# tests/ui/document_text_scale_test.gd
extends SceneTree
var failures:=0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ")+text)
	if not ok: failures+=1
func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event
func _run() -> void:
	root.size=Vector2i(1280,720)
	var viewer: Variant=load("res://scenes/ui/document_viewer.tscn").instantiate()
	root.add_child(viewer)
	await process_frame
	if not viewer.has_method("set_text_scale"):
		print("  FAIL: Visible documents have a player reading-size control")
		viewer.queue_free()
		await process_frame
		quit(1)
		return
	viewer.open_duration=0.0
	viewer.open_document("tape_register","STRIP","[WIRE TAKE1]\n.   -\n")
	viewer.call("set_text_scale",1.5)
	check(viewer.body_label.get_theme_font_size("normal_font_size")==24 \
		and viewer.body_label.text=="[WIRE TAKE1]\n.   -\n","Tape size preserves timing blanks and raw content")
	viewer.close_document()
	viewer.open_document("dispatch_ledger","LEDGER","PRINTED RECORD")
	check(viewer.body_label.get_theme_font_size("normal_font_size")==26,
		"A second printed document retains the chosen scale")
	viewer.close_document()
	viewer.open_document("transcript_paper","COPY","WATCHER")
	viewer.call("set_text_scale",1.0)
	var copy:=viewer.get_node("TranscriptSheet") as TextureRect
	var ink:=copy.get_node("Ink") as Label
	var before_size:=copy.size
	var before_ink:=ink.text
	viewer.call("set_text_scale",1.5)
	check(copy.visible and copy.size.y>before_size.y,"The visible sheet, not merely hidden body, becomes larger")
	check(ink.text==before_ink and viewer.body_label.text=="WATCHER","Magnification never changes ink or logical evidence")
	viewer.set_live_footer("Sender waiting — release due")
	var footer:=viewer.get_node("CopyReadingFooter") as Label
	check(footer.visible and footer.text.contains("Sender waiting"),"Live deadline remains on the fixed reading footer")
	var before_y:=copy.position.y
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	viewer._input(wheel)
	check(copy.position.y<before_y and ink.text==before_ink,"Wheel pans the enlarged sheet without rewriting evidence")
	var key_before:=copy.position.y
	root.set_input_as_handled()
	root.push_input(_key(KEY_PAGEDOWN))
	check(copy.position.y<key_before and ink.text==before_ink and viewer.is_open(),
		"PageDown pans the enlarged sheet from the keyboard without rewriting evidence")
	check(root.is_input_handled(),"PageDown is consumed while the copy is open")
	key_before=copy.position.y
	viewer._input(_key(KEY_PAGEUP))
	check(copy.position.y>key_before and viewer.is_open(),"PageUp pans the sheet back toward the top from the keyboard")
	viewer._input(_key(KEY_END))
	var lower := minf(32.0, viewer.get_viewport().get_visible_rect().size.y - 64.0 - copy.size.y)
	check(lower < 32.0 and is_equal_approx(copy.position.y, lower) and ink.text==before_ink,
		"End pans the sheet to its bounded lower limit")
	viewer._input(_key(KEY_HOME))
	check(copy.position.y==32.0 and viewer.is_open(),"Home returns the sheet to the top bound")
	var before_letter:=copy.position.y
	root.set_input_as_handled()
	root.push_input(_key(KEY_W))
	check(copy.position.y==before_letter and not root.is_input_handled(),
		"Letter keys (WASD) are not captured as sheet panning")
	viewer.close_document()
	check(not viewer.visible,"Closing hides the magnified sheet and fixed footer together")
	viewer.open_document("dispatch_ledger","LONG LEDGER",
		"\n".join(PackedStringArray(Array(range(120)).map(func(value): return "LEDGER ROW %d  ·  —" % value))))
	viewer.call("set_text_scale",1.5)
	for i in 3: await process_frame
	check(not viewer.body_label.fit_content and viewer.body_label.scroll_active,
		"Long printed ledger scrolls inside the body instead of growing the sheet")
	check(viewer.panel_container.size.y<=520.0,"Long printed ledger keeps the card within a bounded height at 1.5")
	check(viewer.footer_label.get_global_rect().end.y<=viewer.get_viewport().get_visible_rect().size.y,
		"Ledger footer stays on screen at 1.5")
	viewer.close_document()
	var card_lines := PackedStringArray(Array(range(120)).map(func(value): return "Line %d of instruction text." % value))
	viewer.open_document("instruction_card","INSTRUCTION","\n".join(card_lines))
	viewer.call("set_text_scale",1.5)
	for i in 3: await process_frame
	check(not viewer.body_label.fit_content and viewer.body_label.scroll_active,
		"Long instruction card scrolls inside the body at 1.5")
	check(viewer.panel_container.size.y<=520.0,"Long instruction card keeps the card within a bounded height at 1.5")
	check(viewer.footer_label.get_global_rect().end.y<=viewer.get_viewport().get_visible_rect().size.y,
		"Instruction footer stays on screen at 1.5")
	viewer.close_document()
	viewer.open_document("transcript_paper","COPY","WATCHER\n\n— COPY INCOMPLETE —")
	viewer.call("set_text_scale",1.2)
	var reading:=viewer.get_node("CopyReadingFooter") as Label
	check(reading.visible and reading.text.contains("COPY INCOMPLETE"),
		"Incomplete copy states COPY INCOMPLETE on the fixed footer at default pan")
	viewer._input(_key(KEY_END))
	await process_frame
	var view_h: float = viewer.get_viewport().get_visible_rect().size.y
	var reading_inside: bool = reading.get_global_rect().end.y <= view_h
	check(reading.visible and reading.text.contains("COPY INCOMPLETE") and reading_inside
		and copy.position.y < 32.0, "Incomplete status stays on the fixed footer at the lower pan limit")
	viewer.set_live_footer("Sender waiting — release due")
	check(reading.text.contains("COPY INCOMPLETE") and reading.text.contains("Sender waiting"),
		"Incomplete status and deadline warning share the fixed footer")
	viewer.call("set_text_scale",1.4)
	check(reading.text.contains("COPY INCOMPLETE") and reading.text.contains("Sender waiting"),
		"Text scale change keeps the live deadline and incomplete status on the footer")
	root.size_changed.emit()
	for i in 3: await process_frame
	check(reading.text.contains("COPY INCOMPLETE") and reading.text.contains("Sender waiting"),
		"Viewport resize keeps the live deadline and incomplete status on the footer")
	viewer.close_document()
	viewer.open_document("transcript_paper","COPY","WATCHER","[E / Esc] Put Down Transcript")
	check(reading.visible and not reading.text.contains("COPY INCOMPLETE"),
		"A complete copy never claims COPY INCOMPLETE on the footer")
	check(not reading.text.contains("Sender waiting"),
		"A new document never inherits the previous document's live deadline")
	viewer.set_live_footer("Sender waiting — release due")
	viewer.set_live_footer("")
	check(reading.text.contains("[E / Esc] Put Down Transcript") and not reading.text.contains("Sender waiting"),
		"An empty live footer restores the footer the document opened with")
	viewer.close_document()
	viewer.queue_free()
	await process_frame
	quit(1 if failures else 0)
