extends SceneTree

## Previous-copy lift/return belongs to the archived sheet, not to the fresh
## feed. Opening previous_transcript must raise the PreviousSheet itself, and
## closing it must return THAT logical document to its own transform, never
## tween the current writing Sheet (which may be mid-feed) and never to an
## absolute y=0. The paper owns the motion so feed/archive/clear cancel or
## compose with it instead of fighting over the node.
##   godot --headless --audio-driver Dummy --path . --script tests/integration/previous_copy_close_feed_test.gd

var count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await _test_previous_lift_and_close_during_preparing(): return
	if not await _test_current_sheet_untouched_during_copying(): return
	if not await _test_compose_with_active_archive_slide(): return
	if not await _test_lifetime_cases(): return
	print("Previous copy close/feed assertions: ", count)
	quit(0)

## Controlled office fixture: everything frozen except the paper's own
## deterministic ticks, with a non-zero sheet rest so "return to 0" can never
## masquerade as "return to rest".
func _make_office() -> M1OfficeController:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	var paper := office.session_controller.transcript_paper
	paper.set_process(false)
	var sheet := paper.get_sheet_node()
	sheet.position = Vector3(0.04, 0.021, 0.015)
	sheet.rotation = Vector3(0.10, 0.20, 0.05)
	paper._sheet_rest_position = sheet.position
	paper._sheet_rest_captured = true
	return office

## Drives the deterministic paper ticks while real tween time passes.
func _tick(paper: TranscriptPaper, ticks: int) -> void:
	for i in ticks:
		paper.advance_paper(1.0 / 60.0)
		await process_frame

## Tweens advance on real frame time, which is machine-speed dependent in
## headless: waits are predicates with a bounded frame budget, never fixed
## frame counts. An exhausted budget fails the assertion that follows.
func _wait_until(predicate: Callable, frame_budget: int = 4000) -> void:
	var guard := 0
	while not predicate.call() and guard < frame_budget:
		await process_frame
		guard += 1

func _prepare_two_sheets(office: M1OfficeController) -> TranscriptPaper:
	var paper := office.session_controller.transcript_paper
	# First sheet: a readable record through the existing authoring API.
	paper.begin_writing("TRAIN 17 CLEAR EAST")
	await _tick(paper, 30)
	paper.reveal_transcript()
	# Second telegram: the first sheet archives, the fresh blank feeds.
	paper.begin_writing("WATCHER")
	return paper

func _test_previous_lift_and_close_during_preparing() -> bool:
	var office := await _make_office()
	var paper := await _prepare_two_sheets(office)
	var previous := paper.get_previous_sheet_node()
	var previous_act := paper.get_node("PreviousSheet/Interactable") as Interactable
	var before: Vector3 = previous.global_position
	# The current blank is mid-feed: where the feed holds it right now.
	var sheet_before: Vector3 = paper.get_sheet_node().position
	var sheet_rotation_before: Vector3 = paper.get_sheet_node().rotation
	# The real signal chain: PreviousSheet Interactable -> office -> viewer.
	previous_act.interact()
	await process_frame
	if not check(office.document_viewer.is_open()
		and office.document_viewer.get_current_doc_id() == "previous_transcript",
		"Reading the archived sheet opens the previous copy in the viewer"):
		return false
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.0165)
	var lifted: Vector3 = previous.global_position
	if not check(lifted.y - before.y > 0.012,
			"Opening the previous copy lifts the archived sheet itself (%.4f m)" % (lifted.y - before.y)):
		return false
	# Close through the viewer's own close API (the real signal chain).
	office.document_viewer.close_document()
	await _wait_until(func() -> bool: return paper._previous_lift <= 0.0001)
	var sheet := paper.get_sheet_node()
	if not check(sheet.position == sheet_before,
			"Closing the previous read never moves the current writing sheet (%s vs %s)"
				% [str(sheet.position), str(sheet_before)]):
		return false
	if not check(previous.global_position.y - before.y < 0.002,
			"The archived sheet settles back after the close (%.4f m remaining)"
				% (previous.global_position.y - before.y)):
		return false
	if not check(sheet.rotation == sheet_rotation_before,
			"The lift/return never rewrites the sheet's rotation"):
		return false
	if not check(not office.document_viewer.is_open(), "The viewer closed through its own API"):
		return false
	office.queue_free()
	await process_frame
	return true

func _test_current_sheet_untouched_during_copying() -> bool:
	var office := await _make_office()
	var paper := await _prepare_two_sheets(office)
	# Feed the blank fully in: the paper reaches COPYING at its rest.
	await _tick(paper, 30)
	var sheet := paper.get_sheet_node()
	if not check(paper.get_state() == TranscriptPaper.PaperState.COPYING
		and sheet.position == paper._sheet_rest_position,
			"The blank finished feeding at the authored rest before the read"):
		return false
	var previous := paper.get_previous_sheet_node()
	var slide_destination: Vector3 = paper.to_global(paper._sheet_rest_position) + paper.previous_sheet_offset
	if not check(previous.global_position.distance_to(slide_destination) < 0.0005,
			"The archived sheet reached its archive destination"):
		return false
	var ink_before: int = paper.get_written_glyph_count()
	var previous_act := paper.get_node("PreviousSheet/Interactable") as Interactable
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.0165)
	if not check(previous.global_position.y - slide_destination.y > 0.012,
			"During COPYING the archived sheet itself rises to be read"):
		return false
	office.document_viewer.close_document()
	await _wait_until(func() -> bool: return paper._previous_lift <= 0.0001)
	if not check(sheet.position == paper._sheet_rest_position,
			"During COPYING, a previous-copy read and close leave the current sheet exactly at rest"):
		return false
	if not check(paper.get_written_glyph_count() == ink_before,
			"The read never touches the ink counters"):
		return false
	if not check(previous.global_position.distance_to(slide_destination) < 0.0005,
			"The archived sheet returns to its archive destination, not a frozen read pose"):
		return false
	office.queue_free()
	await process_frame
	return true

func _test_compose_with_active_archive_slide() -> bool:
	var office := await _make_office()
	var paper := await _prepare_two_sheets(office)
	var previous := paper.get_previous_sheet_node()
	# Read while the archive slide is still travelling.
	await _tick(paper, 4)
	var mid_slide: Vector3 = previous.global_position
	var previous_act := paper.get_node("PreviousSheet/Interactable") as Interactable
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.0165)
	if not check(previous.global_position.y - mid_slide.y > 0.012,
			"Reading mid-slide lifts the archived sheet above its travelling base"):
		return false
	office.document_viewer.close_document()
	# The slide keeps running under the returning lift, tick by tick.
	await _tick(paper, 30)
	await _wait_until(func() -> bool: return paper._previous_lift <= 0.0001)
	var slide_destination: Vector3 = paper.to_global(paper._sheet_rest_position) + paper.previous_sheet_offset
	if not check(previous.global_position.distance_to(slide_destination) < 0.0005,
			"After a mid-slide read the sheet still ends at the archive destination (%.4f away)"
				% previous.global_position.distance_to(slide_destination)):
		return false
	if not check(previous.global_position.distance_to(mid_slide) > 0.005,
			"The sheet travelled on with the slide instead of freezing at the mid-slide read pose"):
		return false
	office.queue_free()
	await process_frame
	return true

func _test_lifetime_cases() -> bool:
	var office := await _make_office()
	var paper := await _prepare_two_sheets(office)
	var previous := paper.get_previous_sheet_node()
	var previous_act := paper.get_node("PreviousSheet/Interactable") as Interactable
	# Quick open-close-open-close: one document, no stacked tweens, ends flat.
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.006)
	office.document_viewer.close_document()
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.0165)
	office.document_viewer.close_document()
	office.document_viewer.close_document()
	await _wait_until(func() -> bool: return paper._previous_lift <= 0.0001)
	var settled_y: float = paper.to_global(paper._sheet_rest_position).y
	if not check(absf(previous.global_position.y - settled_y) < 0.002,
			"A quick open-close cycle leaves the archived sheet settled, no stacked tweens (y %.4f vs %.4f, lift %.4f)"
				% [previous.global_position.y, settled_y, paper._previous_lift]):
		return false
	# A new telegram during a lift: the feed replaces the sheet, the old lift
	# is cancelled, the fresh blank still lands exactly at rest.
	var fed_count: Array = []
	paper.sheet_fed.connect(func(): fed_count.append(1))
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.006)
	paper.begin_writing("FREIGHT 71")
	await _tick(paper, 40)
	await _wait_until(func() -> bool: return paper.get_state() == TranscriptPaper.PaperState.COPYING)
	if not check(paper.get_sheet_node().position == paper._sheet_rest_position
		and paper._previous_lift == 0.0,
			"begin_writing during a lift cancels it and feeds the blank to rest"):
		return false
	if not check(fed_count.size() == 1,
			"Only the replacement blank completed its feed; the interrupted one emitted nothing (got %d)" % fed_count.size()):
		return false
	# Clear during a lift: nothing left moving, no stale tween.
	previous_act.interact()
	await _wait_until(func() -> bool: return paper._previous_lift >= 0.006)
	paper.clear_transcript()
	await process_frame
	if not check(not previous.visible and paper.get_state() == TranscriptPaper.PaperState.EMPTY
		and paper._previous_lift == 0.0 and paper._sheet_lift == 0.0,
			"clear_transcript during a lift hides the archive and empties the pad"):
		return false
	office.queue_free()
	await process_frame
	return true

func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
		return false
	count += 1
	return true
