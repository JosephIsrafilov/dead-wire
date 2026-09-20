extends SceneTree

## B2/B3/Q2: the writing rig solves in ONE space and resets its WHOLE pose.
##
## W1 — the same glyph sequence produces equivalent local joint poses and the
##       same contacts whether the sheet sits at the origin or is rigidly
##       moved and rotated (the pre-fix bug gave ~19.8° vs ~1.0° drift).
## W2 — twenty write/reset cycles return position AND basis to the authored
##       rest (the pre-fix bug kept a rotated basis forever).
## W3 — suspend/resume and cancel mid-entry/mid-motion leave no competing
##       transitions, no detached hand, no late ink.
## W4 — glyph ink appears only after the contact event, at any frame step.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Writer Rig Space Test Suite ---")
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world != null:
		world.reset_for_new_game()

	# --- W1: transform invariance ------------------------------------------
	# Two identical sheets: one at the origin, one rigidly moved and rotated.
	var origin_paper := _paper_at(Transform3D.IDENTITY)
	var moved_paper := _paper_at(Transform3D(
		Basis(Vector3.UP, PI / 2.0), Vector3(3.0, 1.0, -2.0)))
	await process_frame

	var origin_result := _write_sequence(origin_paper)
	var moved_result := _write_sequence(moved_paper)
	if not assert_condition(origin_result.ok and moved_result.ok, "Both variants write their sequences"): return

	# Local joint poses must match: the hand writes the same way wherever the
	# sheet is. This is the assertion the pre-fix mixed-space bug failed
	# (~19.80° vs ~1.00° basis drift between variants).
	var pose_delta := _pose_delta(origin_result.sleeve_basis, moved_result.sleeve_basis)
	if not assert_condition(pose_delta < 1.0, "Local sleeve pose is transform-invariant, %.2f deg between origin and moved sheets" % pose_delta): return
	var wrist_delta: float = origin_result.wrist_offset.distance_to(moved_result.wrist_offset)
	if not assert_condition(wrist_delta < 0.002, "Local wrist offset is transform-invariant, %.4f m" % wrist_delta): return

	# The nib lands on the contact in BOTH variants: world-space correctness
	# is preserved by construction, not by luck.
	if not assert_condition(origin_result.contact_error < 0.004, "Nib lands on the contact at the origin (%.4f m)" % origin_result.contact_error): return
	if not assert_condition(moved_result.contact_error < 0.004, "Nib lands on the contact on the moved sheet (%.4f m)" % moved_result.contact_error): return

	# --- W2: twenty write/reset cycles restore the full authored pose ------
	var cycle_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var rig := cycle_paper.get_writer_rig()
	var sleeve := rig.get_node("Sleeve") as Node3D
	var wrist := rig.get_node("Sleeve/Wrist") as Node3D
	var hand := rig.get_node("Sleeve/Wrist/Hand") as Node3D
	var rest_sleeve := sleeve.transform
	var rest_wrist := wrist.transform
	var rest_hand := hand.transform
	for cycle in 20:
		cycle_paper.begin_writing("WATCHER")
		cycle_paper.advance_paper(cycle_paper.feed_seconds + rig.enter_duration + 0.01)
		for glyph in 7:
			cycle_paper.set_writing_progress(1.0)
			cycle_paper.advance_paper(0.2)
		rig.reset()
	var sleeve_pos_err := sleeve.transform.origin.distance_to(rest_sleeve.origin)
	var sleeve_basis_err := _basis_angle(sleeve.transform.basis, rest_sleeve.basis)
	var wrist_err := wrist.transform.origin.distance_to(rest_wrist.origin)
	var hand_err := hand.transform.origin.distance_to(rest_hand.origin)
	if not assert_condition(sleeve_pos_err < 0.0005 and wrist_err < 0.0005 and hand_err < 0.0005, "Twenty cycles: every joint returns to its authored position (sleeve %.4f wrist %.4f hand %.4f)" % [sleeve_pos_err, wrist_err, hand_err]): return
	if not assert_condition(sleeve_basis_err < 0.5, "Twenty cycles: the sleeve basis returns too, %.2f deg" % sleeve_basis_err): return
	if not assert_condition(_basis_angle(wrist.transform.basis, rest_wrist.basis) < 0.5, "Twenty cycles: the wrist basis returns"): return
	if not assert_condition(_basis_angle(hand.transform.basis, rest_hand.basis) < 0.5, "Twenty cycles: the hand basis returns"): return

	# --- W3: suspend/resume and cancel mid-transition ----------------------
	# Cancel during entry: the arm is mid-entry, reset must clear everything.
	var cancel_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var cancel_rig := cancel_paper.get_writer_rig()
	cancel_paper.begin_writing("WATCHER")
	cancel_paper.advance_paper(cancel_paper.feed_seconds + cancel_rig.enter_duration * 0.5)
	if not assert_condition(cancel_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Entry is mid-flight before the cancel"): return
	cancel_rig.reset()
	if not assert_condition(_basis_angle(sleeve_of(cancel_rig).transform.basis, rest_basis_of(cancel_rig)) < 0.5, "Cancel during entry restores the basis"): return
	if not assert_condition(cancel_rig.get_presentation_state() == WriterRig.PresentationState.HIDDEN, "Cancel during entry hides the arm"): return

	# Suspend during ENTRY: the withdrawal tween must own the arm alone, and
	# resume must cancel it before restoring the mid-entry pose.
	var enter_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var enter_rig := enter_paper.get_writer_rig()
	enter_paper.begin_writing("WATCHER")
	enter_paper.advance_paper(enter_paper.feed_seconds + enter_rig.enter_duration * 0.5)
	if not assert_condition(enter_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Entry is mid-flight before the suspend"): return
	var enter_pose := (enter_rig.get_node("Sleeve") as Node3D).position
	enter_paper.suspend()
	await process_frame
	enter_paper.resume_writing()
	if not assert_condition(enter_rig.get_presentation_state() == WriterRig.PresentationState.ENTER, "Suspend during entry: resume re-enters"): return
	if not assert_condition(enter_rig._active_tween == null or not enter_rig._active_tween.is_valid(), "Suspend during entry: resume cancels the withdrawal tween"): return
	if not assert_condition((enter_rig.get_node("Sleeve") as Node3D).position.is_equal_approx(enter_pose), "Suspend during entry: resume restores the mid-entry pose"): return
	enter_paper.set_writing_progress(1.0)
	var enter_guard := 0
	while enter_paper.is_copy_in_progress() and enter_guard < 200:
		enter_paper.advance_paper(0.1)
		enter_guard += 1
	if not assert_condition(enter_paper.is_ready_to_inspect(), "Suspend during entry: the sheet still completes after resume"): return
	enter_paper.queue_free()

	# Suspend mid-motion: no pending motion survives, resume re-enters to the
	# pose it left and the sheet continues without rewriting the prefix.
	var mid_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var mid_rig := mid_paper.get_writer_rig()
	mid_paper.begin_writing("WATCHER")
	mid_paper.advance_paper(mid_paper.feed_seconds + mid_rig.enter_duration + 0.01)
	mid_paper.set_writing_progress(0.45)
	# Small real frame steps: catch the motion in flight, before its contact.
	var mid_guard := 0
	while not mid_rig.is_motion_pending() and mid_guard < 60:
		mid_paper.advance_paper(0.03)
		mid_guard += 1
	if not assert_condition(mid_rig.is_motion_pending(), "A glyph motion is mid-flight"): return
	var prefix_before := mid_paper.get_written_glyph_count()
	mid_paper.suspend()
	if not assert_condition(not mid_rig.is_motion_pending(), "Suspend clears the in-flight motion"): return
	if not assert_condition(not mid_rig.is_active() or mid_rig.get_presentation_state() == WriterRig.PresentationState.FINISH, "Suspend withdraws the arm"): return
	mid_paper.resume_writing()
	mid_paper.advance_paper(mid_paper.feed_seconds + mid_rig.enter_duration + 0.01)
	if not assert_condition(mid_paper.get_written_glyph_count() == prefix_before, "Resume does not rewrite the visible prefix"): return
	# The signal finishes authorizing while the hand is back at the paper.
	mid_paper.set_writing_progress(1.0)
	var finish_guard := 0
	while mid_paper.is_copy_in_progress() and finish_guard < 60:
		mid_paper.advance_paper(0.2)
		finish_guard += 1
	if not assert_condition(mid_paper.is_ready_to_inspect(), "The sheet still completes after the interruption"): return
	if not assert_condition(mid_paper.get_display_text() == "WATCHER", "The completed sheet reads the authored transcript"): return

	# --- W4: ink only after contact, at three frame steps ------------------
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		var paced_paper := _paper_at(Transform3D.IDENTITY)
		await process_frame
		var paced_rig := paced_paper.get_writer_rig()
		paced_paper.begin_writing("WATCHER")
		paced_paper.advance_paper(paced_paper.feed_seconds + paced_rig.enter_duration + 0.01)
		paced_paper.set_writing_progress(0.45)
		# Prime the request with frame-rate-sized steps until the motion is
		# under way, then verify the ink order around the contact itself.
		var prime_guard := 0
		while not paced_rig.is_motion_pending() and prime_guard < 200:
			paced_paper.advance_paper(step)
			prime_guard += 1
		if not assert_condition(paced_rig.is_motion_pending(), "At step %.4f s a motion is under way" % step): return
		paced_paper.advance_paper(paced_rig.glyph_motion_duration * 0.5)
		if paced_rig.is_motion_pending():
			# The motion is still in flight: no ink may exist yet.
			if not assert_condition(paced_paper.get_written_glyph_count() == 0, "At step %.4f s no ink before the contact" % step): return
		paced_paper.advance_paper(paced_rig.glyph_motion_duration)
		if not assert_condition(paced_paper.get_written_glyph_count() >= 1, "At step %.4f s ink lands with the contact" % step): return
		paced_paper.queue_free()

	# Joint continuity across a full line at a normal frame step.
	var line_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var line_rig := line_paper.get_writer_rig()
	var line_hand := line_rig.get_node("Sleeve/Wrist/Hand") as Node3D
	var line_wrist := line_rig.get_node("Sleeve/Wrist") as Node3D
	var line_sleeve := line_rig.get_node("Sleeve") as Node3D
	line_paper.begin_writing("WATCHER TRAIN WATCHER WATER CLEAR")
	line_paper.advance_paper(line_paper.feed_seconds + line_rig.enter_duration + 0.01)
	line_paper.set_writing_progress(1.0)
	var continuity_guard := 0
	var max_joint_break: float = 0.0
	var frames_sampled := 0
	while line_paper.is_copy_in_progress() and continuity_guard < 600:
		line_paper.advance_paper(1.0 / 60.0)
		continuity_guard += 1
		if line_rig.is_motion_pending() and frames_sampled < 12:
			# Mid-motion frame: the chain must stay connected right now, not
			# only at rest.
			var span := line_hand.global_position.distance_to(line_wrist.global_position) \
				+ line_wrist.global_position.distance_to(line_sleeve.global_position)
			max_joint_break = maxf(max_joint_break, absf(span - _rest_span(line_rig)))
			frames_sampled += 1
	if not assert_condition(line_paper.is_ready_to_inspect(), "Long line completes"): return
	if not assert_condition(frames_sampled >= 8, "Sampled %d consecutive motion frames" % frames_sampled): return
	if not assert_condition(max_joint_break < 0.004, "Joints stay connected mid-motion, worst span deviation %.4f m" % max_joint_break): return

	# --- W5: row changes have their own motion path ------------------------
	# The row comes from the paper's layout contract (GLYPH_COLUMNS), not
	# from hoping a rig-space Y delta survives the rig's own orientation.
	var row_paper := _paper_at(Transform3D.IDENTITY)
	await process_frame
	var row_rig := row_paper.get_writer_rig()
	var row_wrist := row_rig.get_node("Sleeve/Wrist") as Node3D
	row_paper.begin_writing("ABCDEFGHI")  # 9 glyphs: 0-7 on row 0, 8 on row 1
	row_paper.advance_paper(row_paper.feed_seconds + row_rig.enter_duration + 0.01)
	if not assert_condition(row_rig.is_ready_to_write(), "Row case: the hand is at the paper"): return
	if not assert_condition(row_rig.request_glyph_motion(0, "ABCDEFGHI"), "Glyph 0 motion is accepted"): return
	if not assert_condition(not row_rig._motion_is_row_change, "The first glyph is not a row change"): return
	if not assert_condition(absf(row_rig._motion_duration - row_rig.glyph_motion_duration) < 0.0001, "The first glyph uses the normal motion duration"): return
	row_rig.advance_presentation(row_rig._motion_duration * 0.5)
	var flat_mid_y: float = row_rig._motion_wrist_start.y * 0.5 + row_rig._motion_wrist_target.y * 0.5
	if not assert_condition(absf(row_wrist.position.y - flat_mid_y) < 0.0001, "A same-row glyph rides flat between poses, no lift"): return
	row_rig.advance_presentation(row_rig._motion_duration)
	if not assert_condition(not row_rig.is_motion_pending(), "Glyph 0 contact has landed"): return
	if not assert_condition(row_rig.request_glyph_motion(8, "ABCDEFGHI"), "Glyph 8 motion is accepted"): return
	if not assert_condition(row_rig._motion_is_row_change, "The first glyph of the second row is a row change"): return
	if not assert_condition(absf(row_rig._motion_duration - row_rig.row_change_duration) < 0.0001, "A row change uses the longer row-change duration"): return
	row_rig.advance_presentation(row_rig._motion_duration * 0.5)
	var lift_mid_y: float = row_rig._motion_wrist_start.y * 0.5 + row_rig._motion_wrist_target.y * 0.5 + row_rig.pause_lift
	if not assert_condition(absf(row_wrist.position.y - lift_mid_y) < 0.0001, "The wrist lifts over the finished line mid row-change"): return
	row_paper.queue_free()

	for p in [origin_paper, moved_paper, cycle_paper, cancel_paper, mid_paper, line_paper]:
		if is_instance_valid(p):
			p.queue_free()
	await process_frame
	print("--- All Writer Rig Space Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _paper_at(xform: Transform3D) -> TranscriptPaper:
	var paper := (load("res://scenes/telegraph/transcript_paper.tscn") as PackedScene).instantiate() as TranscriptPaper
	paper.transform = xform
	root.add_child(paper)
	paper.set_process(false)
	paper.feed_seconds = 0.0
	return paper

## Writes WATCHER through the paper's public path and reports the final local
## pose plus how far the nib ended from the last glyph's contact.
func _write_sequence(paper: TranscriptPaper) -> Dictionary:
	var rig := paper.get_writer_rig()
	rig.enter_duration = 0.0
	paper.begin_writing("WATCHER")
	paper.advance_paper(0.05)
	var guard := 0
	while paper.get_written_glyph_count() < 7 and guard < 100:
		paper.set_writing_progress(1.0)
		paper.advance_paper(0.3)
		guard += 1
	var sleeve := rig.get_node("Sleeve") as Node3D
	var wrist := rig.get_node("Sleeve/Wrist") as Node3D
	var nib := rig.get_node("Sleeve/Wrist/Hand/Pen/Nib") as Node3D
	var contact_world := paper.to_global(paper.get_glyph_contact(6))
	return {
		"ok": paper.get_display_text() == "WATCHER",
		"sleeve_basis": sleeve.transform.basis,
		"wrist_offset": wrist.position - rig._wrist_rest_position,
		"contact_error": nib.to_global(Vector3(0, -0.011, 0)).distance_to(contact_world),
	}

func _pose_delta(a: Basis, b: Basis) -> float:
	return _basis_angle(a, b)

func _basis_angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.orthonormalized().get_rotation_quaternion().angle_to(b.orthonormalized().get_rotation_quaternion()))

func _rest_span(rig: WriterRig) -> float:
	var hand := rig.get_node("Sleeve/Wrist/Hand") as Node3D
	var wrist := rig.get_node("Sleeve/Wrist") as Node3D
	var sleeve := rig.get_node("Sleeve") as Node3D
	return hand.global_position.distance_to(wrist.global_position) \
		+ wrist.global_position.distance_to(sleeve.global_position)

func sleeve_of(rig: WriterRig) -> Node3D:
	return rig.get_node("Sleeve") as Node3D

func rest_basis_of(rig: WriterRig) -> Basis:
	return rig._sleeve_rest_transform.basis

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
