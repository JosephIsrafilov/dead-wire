extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for outcome in ["file_water", "file_watcher", "lapsed", "missed"]:
		MainMenu.clear_state()
		var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
		root.add_child(office)
		await process_frame
		office.get_node("IntroCard").skip_immediately()
		var director := office.shift_director
		var session := office.session_controller
		director.set_process(false)
		session.set_process(false)
		session.scheduler.auto_process = false
		office.operator_seat.sit_duration = 0
		office.operator_seat.approach_duration = 0
		office.operator_seat.sit()
		var paper := session.transcript_paper
		session.telegraph_key.press()
		# First order is copied but never inspected. It must lapse, not hang.
		director.advance(15.0)
		session.telegraph_key.press()
		director.advance(director.answer_beat_seconds + 0.05)
		session.scheduler.advance_time(20.0)
		_drain_paper(paper)
		check(session.get_state() == TelegraphSessionController.State.VERIFYING, "Unread first order waits for inspection")
		# The route deadline reads the session's post-signal clock; both advance
		# together in production, so interleave them here the same way.
		_advance_night(session, director, 46.0)
		check(director.get_slot_index() == 1, "Unread first order deadline advances the night")
		check(root.get_node("KnowledgeState").knows(&"lapsed_baseline_train_17"), "Unread order records lapse rather than fabricated filing")
		director.advance(10.0)
		session.telegraph_key.press()
		director.advance(director.answer_beat_seconds + 0.05)
		session.scheduler.advance_time(20.0)
		_drain_paper(paper)
		session.mark_transcript_verified()
		session.submit_routing_decision("HOLD")
		director.advance(8.0)
		if outcome == "missed":
			director.advance(40.0)
			check(not office.dawn_evidence.is_revealed(), "Missed final call does not invent a copied document")
		else:
			session.telegraph_key.press()
			director.advance(director.answer_beat_seconds + 0.05)
			session.scheduler.advance_time(4.0)
			_drain_paper(paper)
			if outcome == "lapsed":
				session._process(session.commit_deadline_seconds + 0.1)
				check(office.copy_commit_desk.get_result_text() == "UNFILED", "Uninspected final copy visibly lapses")
			else:
				session.mark_transcript_verified()
				office.copy_commit_desk.commit_option(StringName(outcome))
				check(not office.copy_commit_desk.commit_option(&"file_water"), "Terminal copy rejects duplicate filing")
			# Watch the window throughout the trigger. No popping into view.
			office.player.camera.look_at(office.window_observation.global_position)
			session.advance_consequence(1.0)
			check(not office.window_observation.get_visual_indicator().visible, "Watched window defers appearance")
			session.advance_consequence(20.0)
			check(not office.window_observation.is_active, "Bounded fallback cancels pending figure")
			check(office.dawn_evidence.is_revealed(), "Resolved copy creates handover")
			var text := office.dawn_evidence.get_document_text()
			check(not text.contains("agrees with") and not text.contains("MATCH"), "Handover does not certify an interpretation")
		director.advance(5.0)
		check(director.is_shift_over() and not office.office_door.is_locked(), "%s path reaches unlocked exit" % outcome)
		# Check pen topology remains rigid while its tip reaches the written ink.
		office.shift_director.enabled = false
		office.load_scenario_by_index(2)
		session.start_transmission()
		var writer := session.transcript_paper.get_writer_rig()
		var nib := writer.get_node("Sleeve/Wrist/Hand/Pen/Nib") as Node3D
		var nib_local := nib.transform
		session.scheduler.advance_time(1.8)
		# The hand enters, then bounded catch-up writes the authorized glyphs.
		paper.advance_paper(1.0)
		check(writer.get_last_glyph_index() >= 0, "Hand has made contact with written ink")
		check(nib.transform.is_equal_approx(nib_local), "Writing never detaches nib from shaft")
		var contact := session.transcript_paper.to_global(session.transcript_paper.get_glyph_contact(writer.get_last_glyph_index()))
		check(nib.to_global(Vector3(0, -0.011, 0)).distance_to(contact) < 0.001, "Pen tip reaches glyph position within one millimetre")
		session.reset_session()
		check(not writer.is_active() and not office.window_observation.is_active and not office.copy_commit_desk.has_committed(), "Reset clears hand, figure, and filing")
		office.queue_free()
		await process_frame
	print("Night recovery failures: ", failures)
	quit(1 if failures else 0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

## Session and director advance one production-like step at a time so the
## shared t0 clock and the deadline owner never see each other out of order.
func _advance_night(session: TelegraphSessionController, director: ShiftDirector, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 0.25)
		session._process(step)
		director.advance(step)
		remaining -= step

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
