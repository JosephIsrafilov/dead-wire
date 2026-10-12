extends SceneTree
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok: quit(1); return false
	assertions += 1
	return true
func _run() -> void:
	for gap in [1, 2, 3, 6, 12]:
		var input := "·".repeat(38) + " ".repeat(gap) + "—·"
		var wrapped := M1OfficeController._wrap_tape_text(input, 40)
		if not check(wrapped.replace("\n", "") == input, "Tape layout preserves every timing blank in GAP(%d)" % gap): return
	var internal := " ".repeat(36) + "· ·  ·"
	if not check(M1OfficeController._wrap_tape_text(internal).replace("\n", "") == internal, "Internal American Morse pause survives layout boundary"): return
	if not check(M1OfficeController._wrap_tape_text("·".repeat(41)).replace("\n", "").length() == 41, "No-space fallback cannot drop a mark"): return
	if not check(M1OfficeController._wrap_tape_text("") == "", "Empty tape stays empty"): return
	if not check(M1OfficeController._wrap_tape_text("·  —", 0).replace("\n", "") == "·  —", "Invalid columns cannot trap wrapping loop"): return
	var viewer := load("res://scenes/ui/document_viewer.tscn").instantiate() as DocumentViewer
	root.add_child(viewer)
	await process_frame
	viewer.open_document("tape_register", "STATION REGISTER", "·  ———   ·")
	if not check(viewer.body_label.get_theme_font("normal_font") == DocumentViewer.MORSE_FONT, "Tape and reference use the same mono timing font"): return
	var timing_font: Font = DocumentViewer.MORSE_FONT
	if not check(timing_font.has_char(63) and timing_font.has_char(183) and timing_font.has_char(8212), "Bundled font directly covers incomplete, dot and dash evidence symbols"): return
	if not check(timing_font is FontFile, "Timing font is bundled instead of a machine-specific fallback"): return
	if not check(viewer.body_label.autowrap_mode == TextServer.AUTOWRAP_OFF, "Tape never receives lossy prose wrapping from UI"): return
	if not check(not viewer.body_label.fit_content and viewer.panel_container.size.y <= 520, "Long tape stays in a bounded scrollable paper surface"): return
	if not check(viewer.has_method("show_latest_tape"), "Tape inspection can locate latest delivered ink"): return
	var displayed := M1OfficeController._wrap_tape_text("[WIRE TAKE 1 | COMPLETE | NON-INK BOUNDARY]\n" + "·".repeat(70))
	if not check(displayed.begins_with("[WIRE TAKE 1 | COMPLETE | NON-INK BOUNDARY]\n"), "Presentation boundary labels are not split into fake ink lines"): return
	root.size = Vector2i(1280, 720)
	var wide_row := "·  —".repeat(10)
	var header := "[WIRE TAKE 1 | COMPLETE | NON-INK BOUNDARY]"
	var sample := header + "\n" + wide_row + "\n" + wide_row
	var mono: Font = DocumentViewer.MORSE_FONT
	for scale in [1.0, 1.2, 1.4, 1.5]:
		viewer.open_document("tape_register", "STATION REGISTER", sample)
		viewer.call("set_text_scale", scale)
		var expected_size := int(round(16 * scale))
		if not check(viewer.body_label.get_theme_font_size("normal_font_size") == expected_size and viewer.body_label.text == sample, "Scale %.1f keeps exact tape text at font %d" % [scale, expected_size]): return
	viewer.open_document("tape_register", "STATION REGISTER", sample)
	viewer.call("set_text_scale", 1.5)
	for i in 3: await process_frame
	var widest := 0.0
	for line in sample.split("\n"):
		widest = maxf(widest, mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x)
	if not check(viewer.body_label.size.x >= widest, "Magnified 40-column timing and 43-char header are not clipped at 1280x720 (widest %.0fpx)" % widest): return
	var scroll := viewer.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyScroll") as ScrollContainer
	if not check(scroll != null, "Tape body sits in a horizontal scroll container for oversized widths"): return
	var extreme := "·  —".repeat(30)
	viewer.open_document("tape_register", "STATION REGISTER", extreme)
	viewer.call("set_text_scale", 1.5)
	for i in 3: await process_frame
	if not check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and scroll.get_h_scroll_bar().max_value > 0.0 and viewer.panel_container.get_global_rect().end.x <= 1280.0, "Unsupported 120-column tape stays reachable by horizontal scroll inside the viewport"): return
	if not check(viewer.body_label.get_theme_font_size("normal_font_size") == 24 and viewer.body_label.text == extreme, "Oversized tape keeps full font size and exact marks"): return
	viewer.open_document("tape_register", "STATION REGISTER", "\n".join(PackedStringArray(Array(range(60)).map(func(value): return str(value) + " ·  —"))))
	for i in 4: await process_frame
	if not check(viewer.body_label.get_v_scroll_bar().value > 0.0, "Opening a long strip automatically scrolls toward newest ink"): return
	var long_wide := "
".join(PackedStringArray(Array(range(60)).map(func(value): return str(value) + " " + "·  —".repeat(12))))
	viewer.open_document("tape_register", "STATION REGISTER", long_wide)
	viewer.call("set_text_scale", 1.5)
	for i in 4: await process_frame
	var wide_widest := 0.0
	for line in long_wide.split("
"):
		wide_widest = maxf(wide_widest, mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x)
	var vbar_width := viewer.body_label.get_v_scroll_bar().get_combined_minimum_size().x
	if not check(viewer.body_label.custom_minimum_size.x >= ceilf(wide_widest) + vbar_width + 12.0, "Long wide tape allows measured vertical scrollbar width (%.0fpx) plus padding beside %.0fpx ink" % [vbar_width, wide_widest]): return
	if not check(viewer.panel_container.get_global_rect().end.x <= 1280.0 and viewer.panel_container.get_global_rect().position.x >= 0.0, "Long wide tape with scrollbar allowance still fits the 1280px viewport"): return
	viewer.open_document("another", "OTHER", "not tape")
	await process_frame
	if not check(not viewer.body_label.fit_content and viewer.body_label.scroll_active and viewer.panel_container.size.y <= 520 and viewer.get_current_doc_id() == "another", "Tape-specific scrolling cannot leak into a later document; every printed body stays bounded"): return
	viewer.queue_free()
	await process_frame
	print("Tape layout assertions: ", assertions)
	quit(0)
