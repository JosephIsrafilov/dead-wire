extends SceneTree

func _init() -> void:
	# The rig's entry clock only runs for nodes inside the tree; defer the run
	# so the whole sheet is properly part of the scene.
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Transcript Paper Test Suite (Gate 11 / F2 two-cursor contract) ---")

	var paper_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/transcript_paper.tscn")
	if not assert_condition(paper_scene != null, "transcript_paper.tscn loads"): return
	var paper_node: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	if not assert_condition(paper_node != null and paper_node is TranscriptPaper, "instantiates as TranscriptPaper"): return
	root.add_child(paper_node)
	await process_frame

	var act: Interactable = paper_node.get_interactable()
	if not assert_condition(act != null, "paper has Interactable component"): return

	var lbl: Label3D = paper_node.get_label_3d()
	if not assert_condition(lbl != null, "paper has Label3D"): return
	var writer := paper_node.get_writer_rig()
	if not assert_condition(writer != null, "paper has WriterRig"): return
	var sleeve_rest: Vector3 = (writer.get_node("Sleeve") as Node3D).position

	# 1. Initial blank state
	if not assert_condition(paper_node.get_transcript_text().is_empty(), "Initial transcript text is empty"): return
	if not assert_condition(paper_node.get_state() == TranscriptPaper.PaperState.EMPTY, "Initial paper state is EMPTY"): return
	if not assert_condition(not paper_node.is_revealed(), "Initial state is unrevealed"): return
	if not assert_condition(lbl.text == "", "Label shows placeholder initially"): return

	# 2. Set text without a writing pass
	paper_node.set_transcript_text("WATCHER")
	if not assert_condition(paper_node.get_transcript_text() == "WATCHER", "Transcript text set to WATCHER"): return
	if not assert_condition(lbl.text == "", "Label remains placeholder before writing"): return

	# 3. Authoring shortcut reveal (no physical pass, no copy_finished)
	var finished_ids: Array[String] = []
	paper_node.copy_finished.connect(func(id: String): finished_ids.append(id))
	paper_node.reveal_transcript()
	if not assert_condition(paper_node.is_revealed() and paper_node.is_ready_to_inspect(), "Reveal shows the finished sheet"): return
	if not assert_condition(lbl.text == "WATCHER", "Label displays WATCHER upon reveal"): return
	if not assert_condition(finished_ids.is_empty(), "Authoring reveal is not a physical copy_finished"): return

	# 4. Inspection always emits what is physically on the pad
	var inspected_text: Array[String] = []
	paper_node.transcript_inspected.connect(func(t: String): inspected_text.append(t))
	paper_node._on_interacted()
	if not assert_condition(inspected_text.size() == 1 and inspected_text[0] == "WATCHER", "Interaction emits transcript_inspected with text"): return
	paper_node.clear_transcript()
	# 5. Two cursors: availability grows from the signal, ink follows contact.
	# The blank feeds first (PREPARING); the hand enters only once it landed.
	paper_node.begin_writing("WATCHER", PackedFloat32Array([0.07, 0.15, 0.24, 0.38, 0.51, 0.72, 0.93]), "scenario_test")
	if not assert_condition(paper_node.is_using_authored_cues(), "Authored cue map is accepted"): return
	if not assert_condition(paper_node.get_paper_scenario_id() == "scenario_test", "Sheet records its owning scenario"): return
	if not assert_condition(paper_node.is_copy_in_progress() and paper_node.get_state() == TranscriptPaper.PaperState.PREPARING, "Sheet is live and feeding the blank"): return
	if not assert_condition(writer.get_presentation_state() == WriterRig.PresentationState.HIDDEN, "The hand waits off the paper while the blank feeds"): return
	paper_node.set_writing_progress(0.24)
	if not assert_condition(paper_node.get_available_glyph_count() == 3, "Cues arriving during the feed are buffered, not lost"): return
	if not assert_condition(paper_node.get_written_glyph_count() == 0, "No ink while the blank is still feeding"): return
	paper_node.advance_paper(paper_node.feed_seconds + 0.01)
	if not assert_condition(paper_node.is_copy_in_progress() and paper_node.is_writing(), "The sheet turns to writing once the blank is in place"): return
	if not assert_condition(writer.get_presentation_state() == WriterRig.PresentationState.ENTER, "Rig enters after the blank lands, before any ink"): return

	# 5a. Signal authorizes glyphs while the hand has not yet entered: no ink.
	# The gate is the rig's own readiness, not an independent timer.
	if not assert_condition(paper_node.get_written_glyph_count() == 0, "No ink before the hand reaches the paper"): return
	if not assert_condition(paper_node.get_display_text().is_empty(), "Label still blank during entry"): return
	paper_node.advance_paper(0.05)
	if not assert_condition(writer.get_presentation_state() == WriterRig.PresentationState.ENTER, "Rig is still entering at 0.05 s of 0.18 s"): return
	if not assert_condition(paper_node.get_written_glyph_count() == 0, "Partial entry does not qualify as ready"): return

	# 5b. Hand entry completes; backlog drains through bounded ticks.
	paper_node.advance_paper(writer.enter_duration + 0.01)
	if not assert_condition(writer.is_ready_to_write(), "Rig reports the hand at the paper after entry"): return
	var guard := 0
	while paper_node.get_written_glyph_count() < paper_node.get_available_glyph_count() and guard < 100:
		paper_node.advance_paper(0.1)
		guard += 1
	if not assert_condition(paper_node.get_written_glyph_count() == 3, "Backlog drains to available after entry"): return
	if not assert_condition(paper_node.get_display_text() == "WAT", "Ink matches the authorized prefix"): return

	# 5c. Availability only ever grows; out-of-order progress is ignored.
	paper_node.set_writing_progress(0.15)
	if not assert_condition(paper_node.get_available_glyph_count() == 3, "Out-of-order cue progress cannot reduce availability"): return

	# 5d. Authored pace: exactly one newly authorized glyph begins its motion
	# on the cue; the ink appears when the nib physically arrives (Q2), a
	# short motion later — never before contact.
	paper_node.set_writing_progress(0.38)
	if not assert_condition(paper_node.get_written_glyph_count() == 3, "No ink before the nib contacts the glyph"): return
	if not assert_condition(writer.is_motion_pending(), "The on-pace glyph's motion is under way"): return
	paper_node.advance_paper(0.1)
	if not assert_condition(paper_node.get_written_glyph_count() == 4, "On-pace ink lands with the contact, one motion after the cue"): return
	if not assert_condition(paper_node.get_writer_rig().get_last_glyph_index() == 3, "Nib sits on the glyph it just wrote"): return

	# 5e. Frame hitch (R6): a large availability jump reveals at most one glyph
	# per presentation tick, so every glyph keeps its own contact point.
	paper_node.set_writing_progress(1.0)
	var newly_available := paper_node.get_available_glyph_count() - paper_node.get_written_glyph_count()
	if not assert_condition(newly_available >= 2, "Hitch authorizes a backlog of at least two glyphs"): return
	paper_node.advance_paper(1.0)
	if not assert_condition(paper_node.get_written_glyph_count() == 4 + 1, "A hitch reveals at most one glyph per tick, got %d" % paper_node.get_written_glyph_count()): return
	paper_node.advance_paper(1.0)
	if not assert_condition(paper_node.get_written_glyph_count() == 4 + 2, "The next tick reveals the next glyph"): return

	# 5d-2. Joint continuity (Q2): across the remaining line the hand, cuff
	# and forearm stay connected — only whole-joint transforms move, so the
	# part-to-part distances stay bounded and the wrist keeps its fine limit.
	var hand := writer.get_node("Sleeve/Wrist/Hand") as Node3D
	var wrist := writer.get_node("Sleeve/Wrist") as Node3D
	var sleeve := writer.get_node("Sleeve") as Node3D
	var wrist_rest_local := wrist.position
	var joint_span: float = hand.global_position.distance_to(wrist.global_position) + wrist.global_position.distance_to(sleeve.global_position)
	var wrist_stray: float = (wrist.position - wrist_rest_local).length()
	# The backlog stays at exactly one glyph for the stand-mid-copy section;
	# the hitch ticks above already exercised the jointed motion, so sampling
	# the current pose is the honest continuity measurement here.
	if not assert_condition(joint_span < 0.62, "Hand-cuff-forearm joints stay continuous through the line, total span %.3f m" % joint_span): return
	if not assert_condition(wrist_stray <= writer.wrist_travel_limit + 0.001, "Wrist fine travel stays within its physical limit, %.3f m" % wrist_stray): return

	# 6. Stand mid-copy: prefix freezes, availability keeps growing silently.
	var pre_stand_index := writer.get_last_glyph_index()
	var suspended_assembly := (writer.get_node("Sleeve") as Node3D).position
	paper_node.suspend()
	if not assert_condition(paper_node.is_copy_paused() and not paper_node.is_writing(), "Suspend pauses the sheet"): return
	if not assert_condition(writer.get_last_glyph_index() == pre_stand_index, "Suspend preserves the rig's glyph index (no re-init)"): return
	paper_node.set_writing_progress(1.0)
	if not assert_condition(paper_node.get_available_glyph_count() == 7, "Signal keeps authorizing while the hand is away"): return
	if not assert_condition(paper_node.get_written_glyph_count() == 6, "Standing freezes the visible prefix"): return
	paper_node.advance_paper(1.0)
	if not assert_condition(paper_node.get_written_glyph_count() == 6, "No ink drains while paused"): return

	# 7. Return: the hand re-enters to its own pose first, then bounded catch-up
	# finishes the sheet. The rig's authoring history is never reset.
	paper_node.resume_writing()
	if not assert_condition(paper_node.is_writing(), "Resume restores the live sheet without resetting cursors"): return
	if not assert_condition(writer.get_presentation_state() == WriterRig.PresentationState.ENTER, "Resume re-enters before ink"): return
	if not assert_condition(writer.get_last_glyph_index() == pre_stand_index, "Resume keeps the rig's glyph index"): return
	if not assert_condition(paper_node.get_written_glyph_count() == 6, "Resume does not rewrite the visible prefix"): return
	paper_node.advance_paper(writer.enter_duration + 0.01)
	guard = 0
	while paper_node.is_copy_in_progress() and guard < 100:
		paper_node.advance_paper(0.1)
		guard += 1
	if not assert_condition(paper_node.get_written_glyph_count() == 7, "Catch-up completes the sheet once"): return
	if not assert_condition(paper_node.is_ready_to_inspect(), "Finished sheet is READY_TO_INSPECT"): return
	if not assert_condition(paper_node.get_display_text() == "WATCHER", "Full transcript visible after completion"): return
	if not assert_condition(finished_ids.size() == 1 and finished_ids[0] == "scenario_test", "copy_finished fired exactly once with the owning scenario"): return

	# 8. A finished sheet accepts no more writing.
	paper_node.set_writing_progress(1.0)
	paper_node.suspend()
	paper_node.resume_writing()
	if not assert_condition(paper_node.is_ready_to_inspect() and finished_ids.size() == 1, "Terminal sheet ignores further signal or resume"): return

	# 9. Terminal partial: close mid-copy, never reopens.
	paper_node.clear_transcript()
	paper_node.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 1.0]), "scenario_partial")
	paper_node.advance_paper(writer.enter_duration + 0.01)
	paper_node.set_writing_progress(0.3)
	guard = 0
	while paper_node.get_written_glyph_count() < 3 and guard < 100:
		paper_node.advance_paper(0.1)
		guard += 1
	paper_node.set_writing_progress(1.0)
	paper_node.close_incomplete()
	if not assert_condition(paper_node.is_incomplete_closed(), "Closed partial is terminal"): return
	if not assert_condition(paper_node.get_written_glyph_count() == 3, "Partial keeps exactly the ink it had"): return
	if not assert_condition(paper_node.get_display_text() == "WAT", "Partial shows only the written prefix"): return
	paper_node.resume_writing()
	paper_node.advance_paper(2.0)
	if not assert_condition(paper_node.get_written_glyph_count() == 3 and paper_node.is_incomplete_closed(), "Closed partial never accepts ink again"): return
	if not assert_condition(finished_ids.size() == 1, "Closed partial never emits copy_finished"): return

	# 10. Reset restores the rig.
	paper_node.clear_transcript()
	if not assert_condition(paper_node.get_writer_rig().get_presentation_state() == WriterRig.PresentationState.HIDDEN, "Clear resets writer rig lifecycle"): return
	var sleeve_after_reset := (writer.get_node("Sleeve") as Node3D).position
	if not assert_condition(sleeve_after_reset.is_equal_approx(sleeve_rest), "Clear restores WriterRig rest transform (expected %s, got %s; rig rest %s captured=%s)" % [sleeve_rest, sleeve_after_reset, writer.get_rest_position(), writer.is_rest_captured()]): return

	# 11. Sheet feed (F3): a fresh telegram slides the blank in and lands
	# exactly at rest; the root (and with it the interaction anchor) never
	# moves; clear/cancel leaves no drifted position.
	var sheet := paper_node.get_sheet_node()
	var root_rest: Vector3 = paper_node.position
	var sheet_rest: Vector3 = sheet.position
	paper_node.begin_writing("WATER", PackedFloat32Array([0.2, 0.5, 0.8, 1.0, 1.0]), "feed_case")
	if not assert_condition(paper_node.position.is_equal_approx(root_rest), "The paper root stays put: the interaction anchor never moves"): return
	if not assert_condition(not sheet.position.is_equal_approx(sheet_rest), "The blank starts displaced from the hook side"): return
	paper_node.advance_paper(paper_node.feed_seconds * 0.5)
	if not assert_condition(sheet.position.distance_to(sheet_rest) > 0.001, "Feed is mid-travel at half time"): return
	paper_node.advance_paper(paper_node.feed_seconds)
	if not assert_condition(sheet.position.is_equal_approx(sheet_rest), "The blank lands exactly at rest"): return
	# The finished sheet's ink is archived on the stack layer, not erased.
	paper_node.set_writing_progress(1.0)
	guard = 0
	while paper_node.is_copy_in_progress() and guard < 100:
		paper_node.advance_paper(0.1)
		guard += 1
	if not assert_condition(paper_node.is_ready_to_inspect(), "Feed case completes the sheet"): return
	paper_node.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.9]), "archive_case")
	var archived := paper_node.get_previous_sheet_node()
	var archived_label := paper_node.get_node("PreviousSheet/PreviousSheetText") as Label3D
	if not assert_condition(archived != null and archived.visible, "The previous sheet is archived, not erased"): return
	if not assert_condition(archived_label != null and "WATER" in archived_label.text, "The archived layer keeps the old ink, got '%s'" % archived_label.text): return
	var archived_rest: Vector3 = paper_node.position + Vector3(0, 0, 0)
	paper_node.advance_paper(paper_node.previous_slide_seconds + 0.01)
	if not assert_condition(archived.position.distance_to(sheet_rest + paper_node.previous_sheet_offset) < 0.001, "The old sheet settles at the stack edge"): return
	if not assert_condition(archived.position.y < sheet_rest.y, "The archived sheet sits below the active blank"): return
	paper_node.clear_transcript()
	if not assert_condition(sheet.position.is_equal_approx(sheet_rest), "Cancel restores the rest position instantly"): return
	if not assert_condition(not archived.visible, "A full clear hides the archived layer"): return

	# 12. Clock ownership (regression: double delta). One presentation tick
	# spends its time once: a hitch that finishes the hand's entry must not
	# also run a whole glyph motion on the same already-spent delta and pop
	# the letter in the same frame.
	var clock_paper: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	root.add_child(clock_paper)
	await process_frame
	var clock_rig := clock_paper.get_writer_rig()
	var contact_events: Array[int] = []
	clock_rig.glyph_contact.connect(func(index: int): contact_events.append(index))
	clock_paper.begin_writing("AB", PackedFloat32Array([0.4, 0.8]), "clock_case")
	clock_paper.set_writing_progress(1.0)
	if not assert_condition(clock_paper.get_available_glyph_count() == 2, "Both glyphs are authorized while the blank feeds"): return
	clock_paper.advance_paper(clock_paper.feed_seconds)
	if not assert_condition(clock_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Entry is under way after the feed lands"): return
	# Half of entry: still entering, nothing written, no contact.
	clock_paper.advance_paper(clock_rig.enter_duration * 0.5)
	if not assert_condition(clock_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Entry is still mid-flight at half duration"): return
	if not assert_condition(clock_paper.get_written_glyph_count() == 0 and contact_events.is_empty(), "No ink and no contact during entry"): return
	# A hitch-sized tick: finishes entry (0.09 s left of it) with only a small
	# honest remainder. The letter must NOT land in this same presentation
	# step — entry and full glyph contact do not collapse into one tick.
	clock_paper.advance_paper(0.30)
	if not assert_condition(clock_paper.get_written_glyph_count() == 0, "A hitch tick that finishes entry does not also write the first glyph"): return
	if not assert_condition(contact_events.is_empty(), "No glyph_contact fired in the tick that finished entry"): return
	# Steady ticks: at most one new glyph per presentation tick.
	clock_paper.advance_paper(1.0)
	if not assert_condition(clock_paper.get_written_glyph_count() == 1, "The next tick writes exactly one glyph"): return
	if not assert_condition(contact_events.size() == 1 and contact_events[0] == 0, "Exactly one contact event, for glyph 0"): return
	clock_paper.advance_paper(1.0)
	if not assert_condition(clock_paper.get_written_glyph_count() == 2 and clock_paper.is_ready_to_inspect(), "The sheet completes on the following tick"): return
	if not assert_condition(contact_events.size() == 2, "Two contacts in total, one per glyph"): return
	clock_paper.queue_free()

	# 13. Cancel/resume race (regression: the withdrawal tween kept writing
	# into the sleeve after resume, fighting the restored pose).
	var race_paper: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	root.add_child(race_paper)
	await process_frame
	race_paper.set_process(false)
	race_paper.feed_seconds = 0.0
	var race_rig := race_paper.get_writer_rig()
	var race_sleeve := race_rig.get_node("Sleeve") as Node3D
	var race_contacts: Array[int] = []
	race_rig.glyph_contact.connect(func(index: int): race_contacts.append(index))
	race_paper.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.9]), "race_case")
	race_paper.set_writing_progress(1.0)
	var race_guard := 0
	while not race_rig.is_motion_pending() and race_guard < 200:
		race_paper.advance_paper(0.03)
		race_guard += 1
	if not assert_condition(race_rig.is_motion_pending(), "A glyph motion is in flight before the stand-up"): return
	var race_prefix := race_paper.get_written_glyph_count()
	var race_index := race_rig.get_last_glyph_index()
	var pose_at_stand := race_sleeve.position
	race_paper.suspend()
	await process_frame
	race_paper.resume_writing()
	if not assert_condition(race_paper.get_state() == TranscriptPaper.PaperState.COPYING, "Resume returns the sheet to COPYING"): return
	if not assert_condition(race_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Resume re-enters before any ink"): return
	if not assert_condition(race_rig.get_last_glyph_index() == race_index, "Resume keeps the rig's glyph index"): return
	if not assert_condition(race_sleeve.position.is_equal_approx(pose_at_stand), "Resume restores the pose the operator left"): return
	# The old withdrawal tween must be dead: it must not own the assembly and
	# must not drift the sleeve while the re-entry runs.
	if not assert_condition(race_rig._active_tween == null or not race_rig._active_tween.is_valid(), "The withdrawal tween is cancelled by resume"): return
	var pose_after_resume := race_sleeve.position
	for i in 10:
		await process_frame
	if not assert_condition(race_sleeve.position.distance_to(pose_after_resume) < 0.0005, "The cancelled withdrawal no longer fights the resumed pose (drift %.4f m)" % race_sleeve.position.distance_to(pose_after_resume)): return
	if not assert_condition(race_paper.get_written_glyph_count() == race_prefix, "No ink appears while re-entering"): return
	# The signal finished authorizing while the operator was away; the drain
	# still completes the sheet with each glyph contacting exactly once.
	race_paper.set_writing_progress(1.0)
	var drain_guard := 0
	while race_paper.is_copy_in_progress() and drain_guard < 200:
		race_paper.advance_paper(0.1)
		drain_guard += 1
	if not assert_condition(race_paper.is_ready_to_inspect(), "The interrupted sheet still completes after resume"): return
	if not assert_condition(race_paper.get_written_glyph_count() == 7, "All seven glyphs are written exactly once"): return
	if not assert_condition(race_contacts.size() == 7, "Exactly seven contact events after the interruption, got %d" % race_contacts.size()): return
	race_paper.queue_free()

	# 14. Whitespace contract: one definition of a layout glyph — space, tab,
	# newline and carriage return never count and never receive a contact.
	var ws_text := "AB CD\nEF\tGH"
	var ws_paper: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	root.add_child(ws_paper)
	await process_frame
	var ws_finished: Array[String] = []
	ws_paper.copy_finished.connect(func(id: String): ws_finished.append(id))
	ws_paper.begin_writing(ws_text, PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.9]), "ws_case")
	if not assert_condition(ws_paper.is_using_authored_cues(), "The 8-cue map matches the 8 non-whitespace glyphs"): return
	# Contact mapping: glyph N must land on the N-th non-whitespace character,
	# never on the tab or the newline. The expected contact is derived from
	# the same layout formula with the correct character index.
	var glyph_chars := [0, 1, 3, 4, 6, 7, 9, 10]
	for glyph in 8:
		var expected := _expected_ws_contact(ws_paper, glyph_chars[glyph])
		if not assert_condition(ws_paper.get_glyph_contact(glyph).is_equal_approx(expected), "Glyph %d contacts character %d, not a whitespace slot" % [glyph, glyph_chars[glyph]]): return
	var ws_rig := ws_paper.get_writer_rig()
	var ws_contacts: Array[int] = []
	ws_rig.glyph_contact.connect(func(index: int): ws_contacts.append(index))
	ws_paper.advance_paper(ws_paper.feed_seconds + ws_rig.enter_duration + 0.01)
	ws_paper.set_writing_progress(1.0)
	var ws_guard := 0
	while ws_paper.is_copy_in_progress() and ws_guard < 200:
		ws_paper.advance_paper(0.1)
		ws_guard += 1
	if not assert_condition(ws_paper.is_ready_to_inspect(), "The whitespace sheet completes"): return
	if not assert_condition(ws_paper.get_display_text() == ws_text, "The full text is on the sheet"): return
	if not assert_condition(ws_contacts.size() == 8, "Eight contacts, one per non-whitespace glyph, got %d" % ws_contacts.size()): return
	if not assert_condition(ws_finished.size() == 1 and ws_finished[0] == "ws_case", "copy_finished fires exactly once for the whitespace sheet"): return
	ws_paper.queue_free()

	# 15. Feed continuity: the root never moves, the sheet slides
	# monotonically to rest, the writer stays hidden until sheet_fed, and
	# sheet_fed fires exactly once per sheet.
	var cont_paper: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	root.add_child(cont_paper)
	await process_frame
	cont_paper.set_process(false)
	var cont_sheet := cont_paper.get_sheet_node()
	var cont_root_pos := cont_paper.position
	var cont_sheet_rest := cont_sheet.position
	var cont_fed: Array[int] = []
	cont_paper.sheet_fed.connect(func(): cont_fed.append(1))
	var cont_rig := cont_paper.get_writer_rig()
	cont_paper.begin_writing("WATER", PackedFloat32Array([0.2, 0.4, 0.6, 0.8, 1.0]), "cont_case")
	cont_paper.set_writing_progress(0.4)
	if not assert_condition(cont_paper.get_written_glyph_count() == 0, "Cues during the feed are buffered, not written"): return
	var cont_steps := 6
	var prev_dist := cont_sheet.position.distance_to(cont_sheet_rest)
	for step in cont_steps:
		var before_fed := cont_fed.size()
		cont_paper.advance_paper(cont_paper.feed_seconds / float(cont_steps))
		if cont_fed.size() == before_fed:
			if not assert_condition(cont_rig.get_presentation_state() == WriterRig.PresentationState.HIDDEN, "The writer stays hidden until sheet_fed"): return
		var dist := cont_sheet.position.distance_to(cont_sheet_rest)
		if not assert_condition(dist <= prev_dist + 0.0000001, "The sheet moves monotonically toward rest"): return
		prev_dist = dist
	if not assert_condition(cont_fed.size() == 1, "sheet_fed fires exactly once"): return
	if not assert_condition(cont_paper.position.is_equal_approx(cont_root_pos), "The paper root never moves during the feed"): return
	if not assert_condition(cont_sheet.position.is_equal_approx(cont_sheet_rest), "The sheet lands exactly at rest"): return
	cont_paper.queue_free()

	# 16. Terminal close: during feed, during entry, during motion — the sheet
	# freezes honestly and nothing animates afterwards.
	var close_paper: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	root.add_child(close_paper)
	await process_frame
	close_paper.set_process(false)
	var close_sheet := close_paper.get_sheet_node()
	var close_rest := close_sheet.position
	var close_fed: Array[int] = []
	close_paper.sheet_fed.connect(func(): close_fed.append(1))
	var close_finished: Array[String] = []
	close_paper.copy_finished.connect(func(id: String): close_finished.append(id))
	close_paper.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.9]), "close_feed_case")
	close_paper.advance_paper(close_paper.feed_seconds * 0.5)
	close_paper.close_incomplete()
	if not assert_condition(close_paper.is_incomplete_closed(), "Close during feed is terminal"): return
	close_paper.advance_paper(1.0)
	if not assert_condition(close_paper.get_written_glyph_count() == 0, "A closed partial accepts no ink"): return
	if not assert_condition(close_sheet.position.is_equal_approx(close_rest), "The cancelled feed leaves the sheet at rest"): return
	if not assert_condition(close_fed.is_empty(), "No sheet_fed after a terminal close during feed"): return
	if not assert_condition(close_paper.get_writer_rig().get_presentation_state() == WriterRig.PresentationState.HIDDEN, "The writer is hidden after a terminal close"): return
	if not assert_condition(close_finished.is_empty(), "No copy_finished from a closed partial"): return
	# During entry.
	close_paper.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.9]), "close_entry_case")
	close_paper.advance_paper(close_paper.feed_seconds)
	if not assert_condition(close_paper.get_writer_rig().get_presentation_state() == WriterRig.PresentationState.ENTER, "Entry is under way before the close"): return
	close_paper.close_incomplete()
	close_paper.advance_paper(0.5)
	if not assert_condition(close_paper.is_incomplete_closed() and close_paper.get_written_glyph_count() == 0, "Close during entry freezes the sheet with no ink"): return
	if not assert_condition(close_paper.get_writer_rig().get_presentation_state() == WriterRig.PresentationState.HIDDEN, "The writer hides after close during entry"): return
	# During glyph motion.
	close_paper.begin_writing("WATCHER", PackedFloat32Array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.9]), "close_motion_case")
	close_paper.advance_paper(close_paper.feed_seconds + close_paper.get_writer_rig().enter_duration + 0.01)
	close_paper.set_writing_progress(0.3)
	var cm_guard := 0
	while not close_paper.get_writer_rig().is_motion_pending() and cm_guard < 100:
		close_paper.advance_paper(0.05)
		cm_guard += 1
	if not assert_condition(close_paper.get_writer_rig().is_motion_pending(), "A motion is in flight before the close"): return
	close_paper.close_incomplete()
	close_paper.advance_paper(0.5)
	if not assert_condition(close_paper.is_incomplete_closed(), "Close during motion is terminal"): return
	if not assert_condition(close_paper.get_written_glyph_count() == 0, "The in-flight glyph never contacts after close"): return
	if not assert_condition(close_finished.is_empty(), "No copy_finished ever fires for closed partials"): return
	close_paper.queue_free()

	# Clean up
	paper_node.queue_free()

	print("--- All Transcript Paper Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true

## The contact the layout contract prescribes for a given CHARACTER index:
## same formula as the paper's, driven with the correct non-whitespace
## mapping so a divergence in the paper's own scan shows up as a mismatch.
func _expected_ws_contact(paper: TranscriptPaper, character: int) -> Vector3:
	var lbl := paper.get_label_3d()
	var font := lbl.font if lbl.font != null else ThemeDB.fallback_font
	var columns := paper.GLYPH_COLUMNS
	var line_start := (character / columns) * columns
	var preceding := paper.get_transcript_text().substr(line_start, character % columns)
	var x := font.get_string_size(preceding, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl.font_size).x
	var y := font.get_height(lbl.font_size) * float(character / columns) + font.get_ascent(lbl.font_size)
	return lbl.position + lbl.basis * Vector3(x * lbl.pixel_size, -y * lbl.pixel_size, 0.0005)
