extends SceneTree
## B07 readability evidence capture (windowed, serial, real framebuffer).
## An AUTHORING FIXTURE, not a playtest: wire and paper content are staged
## explicitly and lighting/mechanics are frozen. Copy states are produced by the
## real TranscriptPaper API (begin_writing / set_writing_progress / advance_paper /
## close_incomplete), never by truncating strings. Nothing here is evidence of
## human readability, real-time FPS, or visual approval.
##   godot --path . --script res://tools/readability_capture.gd   (via with_preserved_settings.py)

const OFFICE_SCENE := "res://scenes/office/m1_office.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const HEIGHTS := [720, 1080, 1440]
const MODES := [0, 1, 2]
const MODE_NAMES := ["CLASSIC", "READABLE", "CLEAN"]
const SCALES := [1.0, 1.2, 1.5]
const WIRE_SHORT := "WATER"
const WIRE_LONG := "WATER WATCHER WATER WATCHER WATER WATCHER"
const COPY_TEXT := "WATCHER"
const INCOMPLETE_WRITTEN := 4
## Real scenario copy (data/scenarios/m1_scenario_1_baseline.tres written_transcript).
const REAL_COPY := "TRAIN 17 CLEAR EAST"
const REAL_INCOMPLETE_WRITTEN := 12
const MAX_TAB_STEPS := 80
const FRAME := 1.0 / 60.0
const DRIVE_LIMIT := 20000

var failures := 0
var manifest: Array[Dictionary] = []
var layout: Array[Dictionary] = []
var drives: Array[Dictionary] = []
var office: M1OfficeController = null
var paper: TranscriptPaper = null
var register: TapeRegisterController = null
var fixture_scheduler: MorseRuntimeScheduler = null
var out := ""
var focused := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: Readability capture requires a real framebuffer")
		quit(2)
		return
	out = "res://docs/art/readable_pass/capture_%d" % Time.get_ticks_usec()
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		printerr("FAIL: Capture directory cannot be created")
		quit(1)
		return
	office = load(OFFICE_SCENE).instantiate() as M1OfficeController
	root.add_child(office)
	for i in 5:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.session_controller.scheduler.auto_process = false
	office.get_node("LampLife").set_wick_immediate(1.0)
	for node in office.find_children("*", "Node", true, false):
		node.set_process(false)
		node.set_physics_process(false)
		node.set_process_input(false)
	office.set_process(false)
	paper = office._get_transcript_paper()
	office.copy_commit_desk.configure(office.scenario_3.commit_options)
	office.copy_commit_desk.set_enabled(true)
	fixture_scheduler = MorseRuntimeScheduler.new()
	fixture_scheduler.auto_process = false
	root.add_child(fixture_scheduler)
	register = office.session_controller.get_tape_register()
	office.document_viewer.open_duration = 0.0
	if not _play_wire(WIRE_SHORT):
		printerr("FAIL: Short wire fixture cannot compile/start")
		failures += 1

	# Focused B07 pan evidence: 720 READABLE, real-length copy at 1.2/1.5,
	# pan-top (Home) and pan-min (End) via keyboard only.
	focused = "b07_pan" in OS.get_cmdline_user_args()
	if focused:
		await _focused_pan_pass()
		register.disconnect_scheduler()
		office.queue_free()
		fixture_scheduler.queue_free()
		await process_frame
		_write_manifest()
		var expected_focused: int = 8
		print("CAPTURE_FAILURES ", failures, " SHOTS ", manifest.size(), " EXPECTED ", expected_focused,
		" LAYOUT ", layout.size(), " OUT ", out)
		quit(1 if failures > 0 or manifest.size() != expected_focused else 0)
		return

	for h in HEIGHTS:
		await _set_window(h)
		await _capture_main_menu(h)
	for h in HEIGHTS:
		await _set_window(h)
		await _capture_pause(h)

	# Pass 1: complete copy (real paper state READY_TO_INSPECT), short tape, card.
	drives.append(_drive_copy(COPY_TEXT, -1, "b07_fixture_complete"))
	await _doc_pass(["whole_card", "tape_short", "copy_complete"])

	# Pass 2: real incomplete copy: partial glyphs, then the paper's own close.
	drives.append(_drive_copy(COPY_TEXT, INCOMPLETE_WRITTEN, "b07_fixture_incomplete"))
	await _doc_pass(["copy_incomplete"])

	# Pass 3: long tape, timing/width evidence.
	if not _play_wire(WIRE_LONG):
		printerr("FAIL: Long wire fixture cannot compile/start")
		failures += 1
	await _doc_pass(["tape_long"])

	register.disconnect_scheduler()
	office.queue_free()
	fixture_scheduler.queue_free()
	await process_frame
	_write_manifest()
	var expected := HEIGHTS.size() * 3 + HEIGHTS.size() * MODES.size() * SCALES.size() * 5
	print("CAPTURE_FAILURES ", failures, " SHOTS ", manifest.size(), " EXPECTED ", expected,
		" LAYOUT ", layout.size(), " OUT ", out)
	quit(1 if failures > 0 or manifest.size() != expected else 0)

func _capture_main_menu(h: int) -> void:
	office.visible = false
	var menu := load(MAIN_MENU_SCENE).instantiate() as MainMenu
	root.add_child(menu)
	for i in 3:
		await process_frame
	menu.begin_button.grab_focus()
	layout.append({"screen": "main_menu_closed", "height": h, "window": _window_str(), "controls": _control_bounds(menu)})
	await _shot("main_menu_closed", h, -1, {"screen": "main_menu_closed"})
	var closed_cycle: Dictionary = await _tab_cycle()
	layout.append({"screen": "main_menu_closed_tab_cycle", "height": h, "cycle": closed_cycle})

	menu.options_button.pressed.emit()
	for i in 3:
		await process_frame
	menu.begin_button.grab_focus()
	layout.append({"screen": "main_menu_options_open", "height": h, "window": _window_str(),
		"controls": _control_bounds(menu)})
	await _shot("main_menu_options_open", h, -1, {"screen": "main_menu_options_open"})
	var open_cycle: Dictionary = await _tab_cycle()
	layout.append({"screen": "main_menu_options_tab_cycle", "height": h, "cycle": open_cycle})
	menu.queue_free()
	await process_frame
	office.visible = true

func _capture_pause(h: int) -> void:
	var pause_menu := office.get_node("PauseMenu") as PauseMenu
	if not pause_menu.pause():
		printerr("FAIL: Pause menu did not open")
		failures += 1
		return
	for i in 3:
		await process_frame
	layout.append({"screen": "pause_menu_open", "height": h, "window": _window_str(),
		"controls": _control_bounds(pause_menu)})
	await _shot("pause_menu_open", h, -1, {"screen": "pause_menu_open"})
	pause_menu.resume_button.grab_focus()
	var cycle: Dictionary = await _tab_cycle()
	layout.append({"screen": "pause_menu_tab_cycle", "height": h, "cycle": cycle})
	pause_menu.resume()

func _doc_pass(kinds: Array) -> void:
	for h in HEIGHTS:
		await _set_window(h)
		for mode in MODES:
			office.apply_presentation_mode(mode)
			await process_frame
			for scale in SCALES:
				for kind in kinds:
					await _doc_shot(String(kind), h, mode, scale)

func _doc_shot(kind: String, h: int, mode: int, scale: float) -> void:
	var dv := office.document_viewer
	dv.close_document()
	dv.set_text_scale(scale)
	match kind:
		"whole_card":
			office._on_card_inspected((office.get_node("MorseReferenceCard") as MorseReferenceCard).get_card_text())
		"tape_short", "tape_long":
			office._on_tape_inspected(register.get_tape_display_text())
		"copy_complete", "copy_incomplete":
			office._on_transcript_inspected(paper.get_display_text())
	for i in 3:
		await process_frame
	var opened := dv.is_open()
	if not opened:
		printerr("FAIL: document not open for ", kind)
		failures += 1
	var extra := _doc_geometry()
	extra["kind"] = kind
	extra["doc_open"] = opened
	extra["doc_id"] = dv.get_current_doc_id()
	extra["paper_state"] = _state_name()
	await _shot("%s_ts%s" % [kind, str(scale)], h, mode, extra)
	dv.close_document()

## Real paper API: begin_writing -> authorize all glyphs -> advance the sheet's
## own presentation clock. stop_written < 0 runs to READY_TO_INSPECT; otherwise
## the paper is closed through close_incomplete(), its own terminal path.
func _drive_copy(text: String, stop_written: int, tag: String) -> Dictionary:
	paper.begin_writing(text, PackedFloat32Array(), tag)
	paper.set_writing_progress(1.0)
	var ticks := 0
	while ticks < DRIVE_LIMIT:
		if stop_written >= 0:
			if paper.get_written_glyph_count() >= stop_written:
				break
		elif paper.is_ready_to_inspect():
			break
		paper.advance_paper(FRAME)
		ticks += 1
	var reached: bool = false
	if stop_written >= 0:
		reached = paper.get_written_glyph_count() >= stop_written
	else:
		reached = paper.is_ready_to_inspect()
	if stop_written >= 0 and reached:
		paper.close_incomplete()
	var ok: bool = reached and (paper.is_incomplete_closed() if stop_written >= 0 else paper.is_ready_to_inspect())
	if not ok:
		printerr("FAIL: paper drive did not reach requested state: ", tag)
		failures += 1
	return {
		"tag": tag,
		"requested_written": stop_written,
		"written": paper.get_written_glyph_count(),
		"available": paper.get_available_glyph_count(),
		"state": _state_name(),
		"terminal": paper.is_terminal(),
		"ok": ok,
		"ticks": ticks,
		"display_text": paper.get_display_text(),
		"display_md5": paper.get_display_text().md5_text(),
	}

func _state_name() -> String:
	return TranscriptPaper.PaperState.keys()[paper.get_state()]

func _play_wire(message: String) -> bool:
	register.disconnect_scheduler()
	register.reset()
	register.connect_scheduler(fixture_scheduler)
	var sequence := AmericanMorseEncoder.new().encode(message, office.shift_director.alphabet)
	if sequence == null:
		return false
	var schedule := MorseScheduleCompiler.new().compile(sequence, office.shift_director.playback_profile)
	if schedule == null or not fixture_scheduler.start(schedule):
		return false
	fixture_scheduler.advance_time(schedule.total_duration_seconds)
	return true

func _set_window(height: int) -> void:
	var width := int(round(float(height) * 16.0 / 9.0))
	root.size = Vector2i(width, height)
	for i in 3:
		await process_frame

func _focused_pan_pass() -> void:
	await _set_window(720)
	office.apply_presentation_mode(1)
	await process_frame
	# The fixture disabled input on every office child for determinism; the
	# viewer must still receive the real keyboard pan keys.
	office.document_viewer.set_process_input(true)
	for text_case in [["complete", -1], ["incomplete", REAL_INCOMPLETE_WRITTEN]]:
		drives.append(_drive_copy(REAL_COPY, text_case[1], "b07_real_" + text_case[0]))
		for scale in [1.2, 1.5]:
			await _pan_pair("copy_real_%s" % text_case[0], scale)

func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

## Opens the real copy, shoots it at the default top pan (Home), then pans to the
## lower limit with End and shoots again. Ink text is asserted unchanged by pan.
func _pan_pair(kind: String, scale: float) -> void:
	var dv := office.document_viewer
	dv.close_document()
	dv.set_text_scale(scale)
	office._on_transcript_inspected(paper.get_display_text())
	for i in 3:
		await process_frame
	if not dv.is_open():
		printerr("FAIL: document not open for ", kind)
		failures += 1
		return
	var sheet: Control = dv.get_node("TranscriptSheet") as Control
	var ink: Label = sheet.get_node("Ink") as Label
	var status: Label = sheet.get_node("Status") as Label
	var ink_md5: String = ink.text.md5_text()
	var keys_used: Array = []
	root.push_input(_key_event(KEY_HOME))
	keys_used.append("Home")
	for i in 3:
		await process_frame
	var top_probe: Dictionary = _pan_probe(dv)
	var top_extra: Dictionary = _pan_extra(kind, "pan_top", scale, top_probe, ink_md5, keys_used)
	await _shot("%s_ts%s_pan_top" % [kind, str(scale)], 720, 1, top_extra)
	root.push_input(_key_event(KEY_END))
	keys_used.append("End")
	for i in 3:
		await process_frame
	var min_probe: Dictionary = _pan_probe(dv)
	var ink_unchanged: bool = ink.text.md5_text() == ink_md5
	var status_bottom: float = status.get_global_rect().end.y
	var backing_top: float = float(min_probe["footer_backing_top"])
	var status_above_footer: bool = status.text.contains("COPY INCOMPLETE") and status_bottom <= backing_top
	if not ink_unchanged:
		printerr("FAIL: pan changed ink text for ", kind)
		failures += 1
	if status.text.contains("COPY INCOMPLETE") and not status_above_footer:
		printerr("FAIL: COPY INCOMPLETE status not above footer at pan min for ", kind)
		failures += 1
	var min_extra: Dictionary = _pan_extra(kind, "pan_min", scale, min_probe, ink_md5, keys_used)
	min_extra["ink_unchanged_by_pan"] = ink_unchanged
	min_extra["status_above_footer_at_pan_min"] = status_above_footer
	await _shot("%s_ts%s_pan_min" % [kind, str(scale)], 720, 1, min_extra)
	dv.close_document()

func _pan_probe(dv: Node) -> Dictionary:
	var sheet: Control = dv.get_node("TranscriptSheet") as Control
	var status: Label = sheet.get_node("Status") as Label
	var backing: ColorRect = dv.get_node("CopyReadingFooterBacking") as ColorRect
	var footer: Label = dv.get("_copy_reading_footer") as Label
	return {
		"sheet_pan_y": sheet.position.y,
		"sheet_size": [sheet.size.x, sheet.size.y],
		"status_text": status.text,
		"status_rect": _rect_arr(status.get_global_rect()),
		"footer_backing_top": backing.get_global_rect().position.y,
		"footer_rect": _rect_arr(footer.get_global_rect()),
		"footer_text": footer.text,
		"footer_visible": footer.visible,
	}

func _pan_extra(kind: String, pan: String, scale: float, probe: Dictionary, ink_md5: String, keys: Array) -> Dictionary:
	var extra: Dictionary = _doc_geometry()
	extra["kind"] = kind
	extra["pan"] = pan
	extra["doc_open"] = office.document_viewer.is_open()
	extra["doc_id"] = office.document_viewer.get_current_doc_id()
	extra["paper_state"] = _state_name()
	extra["ink_md5_at_open"] = ink_md5
	extra["keys_used"] = keys
	extra["pan_probe"] = probe
	extra["text_scale_requested"] = scale
	return extra

func _window_str() -> String:
	return "%dx%d" % [root.size.x, root.size.y]

func _window_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(root.size))

func _rect_arr(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _describe(n: Node) -> String:
	if n == null:
		return "none"
	return "%s@%s" % [n.get_class(), str(root.get_path_to(n))]

func _press_tab() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = true
	root.push_input(event)

## Tab from the current focus owner, one step per frame, until focus returns to
## the start (closed cycle), stops advancing ("stuck"), or the step cap is hit.
func _tab_cycle() -> Dictionary:
	var start: Control = root.gui_get_focus_owner()
	var steps: Array = []
	var seen := {}
	var prev: Control = null
	var closed := false
	var stuck := false
	for i in MAX_TAB_STEPS:
		_press_tab()
		await process_frame
		var f: Control = root.gui_get_focus_owner()
		var desc := _describe(f)
		seen[desc] = true
		var inside: bool = f != null and _window_rect().encloses(f.get_global_rect())
		steps.append({"step": i + 1, "focus": desc, "inside_window": inside})
		if f != null and f == start:
			closed = true
			break
		if f != null and f == prev:
			stuck = true
			break
		prev = f
	return {"start": _describe(start), "closed_cycle": closed, "stuck_at_last": stuck,
		"unique_focus_count": seen.size() - (1 if seen.has("none") else 0), "steps": steps}

func _control_bounds(scope: Node) -> Array[Dictionary]:
	var bounds: Array[Dictionary] = []
	var window_rect := _window_rect()
	for node in scope.find_children("*", "Control", true, false):
		if not (node is BaseButton or node is Range or node is Label):
			continue
		var c := node as Control
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		var minimum := c.get_combined_minimum_size()
		var entry := {
			"path": _describe(c),
			"rect": _rect_arr(r),
			"inside_window": window_rect.encloses(r),
			"min_size": [minimum.x, minimum.y],
			"fits_min_size": r.size.x >= minimum.x - 0.5 and r.size.y >= minimum.y - 0.5,
		}
		if c is OptionButton:
			var ob := c as OptionButton
			entry["selected_text"] = ob.get_item_text(ob.selected)
		elif c is Range:
			entry["value"] = (c as Range).value
		elif c is BaseButton:
			entry["text"] = (c as BaseButton).text
		elif c is Label:
			entry["text"] = (c as Label).text.left(60)
		bounds.append(entry)
	return bounds

func _add_rect(g: Dictionary, key: String, node: Variant, win: Rect2) -> void:
	var c := node as Control
	if c == null or not c.is_visible_in_tree():
		g[key] = null
		return
	var r := c.get_global_rect()
	g[key] = {"rect": _rect_arr(r), "inside_window": win.encloses(r)}

func _doc_geometry() -> Dictionary:
	var dv := office.document_viewer
	var win := _window_rect()
	var g := {"viewport_px": [root.size.x, root.size.y], "text_scale": dv.text_scale}
	_add_rect(g, "panel", dv.panel_container, win)
	_add_rect(g, "title", dv.title_label, win)
	_add_rect(g, "body", dv.body_label, win)
	_add_rect(g, "footer", dv.footer_label, win)
	var sheet := dv.get_node_or_null("TranscriptSheet") as Control
	_add_rect(g, "copy_sheet", sheet, win)
	_add_rect(g, "copy_footer_backing", dv.get_node_or_null("CopyReadingFooterBacking"), win)
	_add_rect(g, "copy_reading_footer", dv.get("_copy_reading_footer"), win)
	var ink := sheet.get_node_or_null("Ink") as Label if sheet != null else null
	_add_rect(g, "copy_ink", ink, win)
	if ink != null:
		g["ink_text"] = ink.text
		g["ink_text_md5"] = ink.text.md5_text()
		g["ink_line_count"] = ink.get_line_count()
	if dv.body_label != null and dv.body_label.is_visible_in_tree():
		var body := dv.body_label
		var font := body.get_theme_font("normal_font")
		var fs := body.get_theme_font_size("normal_font_size")
		g["body_text_md5"] = body.text.md5_text()
		g["body_text_utf8_bytes"] = body.text.to_utf8_buffer().size()
		var width_px: float = -1.0
		if font != null:
			width_px = font.get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		g["body_text_width_px"] = width_px
		g["body_content_height_px"] = body.get_content_height()
	return g

func _shot(stem: String, height: int, mode: int, extra: Dictionary) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var mode_str := "na" if mode < 0 else str(mode)
	var path := out.path_join("h%d_mode%s_%s.png" % [height, mode_str, stem])
	var error := ERR_INVALID_DATA if image == null or image.is_empty() else image.save_png(path)
	var saved := error == OK and FileAccess.file_exists(path)
	if not saved:
		failures += 1
	var image_size := "missing" if image == null else "%dx%d" % [image.get_width(), image.get_height()]
	var entry := {
		"stem": stem,
		"requested_height": height,
		"requested_width": int(round(float(height) * 16.0 / 9.0)),
		"mode": mode,
		"mode_name": "n/a" if mode < 0 else MODE_NAMES[mode],
		"text_scale": office.document_viewer.text_scale,
		"actual_window": _window_str(),
		"window_matches_request": root.size == Vector2i(int(round(float(height) * 16.0 / 9.0)), height),
		"render_scale": root.scaling_3d_scale,
		"image_size": image_size,
		"saved": saved,
		"error": error,
		"path": path,
	}
	entry.merge(extra, true)
	manifest.append(entry)
	print("SHOT ", path, " saved=", saved, " actual_window=", _window_str(), " image=", image_size)

func _write_manifest() -> void:
	var file := FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		printerr("FAIL: manifest.json cannot be written")
		return
	file.store_string(JSON.stringify({
		"fixture_staged_not_playtest": true,
		"focused_b07_pan": focused,
		"copy_driver": "TranscriptPaper.begin_writing + set_writing_progress + advance_paper + close_incomplete (real API)",
		"godot_version": Engine.get_version_info()["string"],
		"display_driver": DisplayServer.get_name(),
		"drives": drives,
		"shots": manifest,
		"layout": layout,
		"failures": failures,
	}, "\t"))
	file.close()
