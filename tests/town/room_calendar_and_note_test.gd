extends SceneTree
## Roadmap 0.4: the wall calendar and Clara's note are the room's clock, so both
## read CampaignState.day_index instead of reciting one fixed April.
##
## The week the campaign plays is Monday 14 April 1890 through Sunday 20 April
## 1890. Day 1 is Monday the 14th at dawn, day 3 is Wednesday the 16th, when the
## week's board ($4.00) falls due, and day 7 is Sunday the 20th, when the court
## sits on the key at 08:00. Every day already spent is struck through; the two
## dated obligations are ringed; nothing after today is struck.
##   godot --headless --audio-driver Dummy --path . --script tests/town/room_calendar_and_note_test.gd

const STRIKE := "\u0336"
const RU := "ru"
const EN := "en"
const DAY_PROBES := [
	# day_index, weekday+date the calendar must name for that day
	[1, "Пн, 14 апр."],
	[2, "Вт, 15 апр."],
	[3, "Ср, 16 апр."],
	[4, "Чт, 17 апр."],
	[5, "Пт, 18 апр."],
	[6, "Сб, 19 апр."],
	[7, "Вс, 20 апр."],
]
const EN_DAY_PROBES := [
	[1, "Mon, Apr 14"],
	[7, "Sun, Apr 20"],
]

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> bool:
	if ok:
		print("  PASS: " + description)
		_passed += 1
	else:
		print("  FAIL: " + description)
		_failed += 1
	return ok

func _line_with(text: String, needle: String) -> String:
	## A struck date no longer reads as a contiguous string, so compare on the
	## de-struck line and return the original: tests can then ask both "is this
	## line present?" and "is it struck?".
	for line in text.split("\n"):
		if line.replace(STRIKE, "").contains(needle):
			return line
	return ""

func _ensure_campaign() -> CampaignStateStore:
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign == null:
		campaign = CampaignStateStore.new()
		campaign.name = "CampaignState"
		root.add_child(campaign)
	campaign.reset_for_new_game()
	return campaign

func _run() -> void:
	var campaign := _ensure_campaign()

	# 1. Every campaign day names its real date from the 14-20 April week.
	GameLocale.lock_language_for_test(RU)
	for probe in DAY_PROBES:
		campaign.day_index = int(probe[0])
		var text := BoardingHouseRoomController.build_room_calendar_text(campaign)
		_check(text.contains(String(probe[1])),
			"Day %d calendar names %s" % [int(probe[0]), String(probe[1])])

	# 2. Rent is Wednesday the 16th and the court is Sunday the 20th at 08:00.
	campaign.day_index = 1
	var first := BoardingHouseRoomController.build_room_calendar_text(campaign)
	var rent_line := _line_with(first, "16 апр.")
	_check(rent_line.contains("Ср") and rent_line.contains("$4.00"),
		"Rent falls on Wednesday the 16th at $4.00")
	_check(rent_line.contains("[") and rent_line.contains("]"),
		"The rent date is ringed, not merely listed")
	var court_line := _line_with(first, "20 апр.")
	_check(court_line.contains("08:00") and court_line.begins_with("[")
		and court_line.strip_edges().ends_with("]"),
		"The court sits Sunday the 20th at 08:00, ringed")
	_check(court_line.to_lower().contains("суд"),
		"The Sunday obligation is named as the court")
	_check(not first.contains("четверг") and not first.contains("Четверг"),
		"The old Thursday rent line is gone")

	# 3. Nothing is struck on the first morning; every day already lived is.
	campaign.day_index = 1
	var day_one := BoardingHouseRoomController.build_room_calendar_text(campaign)
	_check(not day_one.contains(STRIKE), "Day 1 strikes nothing: the week is ahead")

	campaign.day_index = 4
	var day_four := BoardingHouseRoomController.build_room_calendar_text(campaign)
	var spent := ["14 апр.", "15 апр.", "16 апр."]
	var ahead := ["17 апр.", "18 апр.", "19 апр.", "20 апр."]
	for needle in spent:
		_check(_line_with(day_four, needle).contains(STRIKE),
			"Day 4 strikes the spent %s line" % needle)
	for needle in ahead:
		_check(not _line_with(day_four, needle).contains(STRIKE),
			"Day 4 leaves the coming %s line clean" % needle)
	_check(_line_with(day_four, "16 апр.").contains("$4.00"),
		"A struck day keeps its printed entry legible")
	_check(day_four.contains("Сегодня") and _line_with(day_four, "Сегодня").contains("17 апр."),
		"Day 4 marks today as Thursday the 17th")

	# 4. Saturday the 19th is the quiet Saturday; Sunday stays ringed on day 7.
	campaign.day_index = 6
	var day_six := BoardingHouseRoomController.build_room_calendar_text(campaign)
	_check(_line_with(day_six, "19 апр.").to_lower().contains("тихая"),
		"Day 6 keeps the quiet Saturday in the calendar")
	campaign.day_index = 7
	var day_seven := BoardingHouseRoomController.build_room_calendar_text(campaign)
	_check(_line_with(day_seven, "20 апр.").contains("08:00")
		and not _line_with(day_seven, "20 апр.").contains(STRIKE),
		"On the court's morning the 20th is still ringed and unstruck")
	_check(_line_with(day_seven, "19 апр.").contains(STRIKE),
		"The quiet Saturday is struck by Sunday morning")

	# 5. Out-of-range day indexes clamp to the week instead of inventing dates.
	campaign.day_index = 99
	_check(BoardingHouseRoomController.build_room_calendar_text(campaign) == day_seven,
		"A day index past the hearing reads as the hearing's morning")
	campaign.day_index = 0
	_check(BoardingHouseRoomController.build_room_calendar_text(campaign) == day_one,
		"A day index below the first morning reads as the first morning")
	campaign.day_index = -3
	_check(BoardingHouseRoomController.build_room_calendar_text(campaign) == day_one,
		"A negative day index reads as the first morning")

	# 6. The English calendar parses the same week, with no Russian left in it.
	GameLocale.lock_language_for_test(EN)
	campaign.day_index = 1
	var en_first := BoardingHouseRoomController.build_room_calendar_text(campaign)
	for probe in EN_DAY_PROBES:
		campaign.day_index = int(probe[0])
		_check(BoardingHouseRoomController.build_room_calendar_text(campaign)
			.contains(String(probe[1])), "EN day %d names %s" % [int(probe[0]), String(probe[1])])
	campaign.day_index = 1
	en_first = BoardingHouseRoomController.build_room_calendar_text(campaign)
	_check(_line_with(en_first, "Apr 16").contains("$4.00")
		and _line_with(en_first, "Apr 16").contains("Wed"),
		"EN rent is Wednesday, April 16, at $4.00")
	_check(_line_with(en_first, "Apr 20").contains("08:00"),
		"EN court is Sunday, April 20, at 08:00")
	_check(not en_first.contains("апр.") and not en_first.contains("Срс"),
		"EN calendar carries no Russian day names")
	_check(en_first.split("\n").size() == day_one.split("\n").size(),
		"RU and EN calendars keep the same shape")

	# 7. Clara's note carries the same date and the same Wednesday rent.
	GameLocale.lock_language_for_test(RU)
	campaign.day_index = 1
	var note_one := BoardingHouseRoomController.build_landlady_note_text(campaign)
	_check(note_one.contains("Пн, 14 апр.") and note_one.contains("1890"),
		"Clara's note is dated Monday the 14th of April 1890 on day 1")
	_check(note_one.contains("$4.00") and note_one.to_lower().contains("сред"),
		"On day 1 Clara says the board can wait until Wednesday")
	campaign.day_index = 3
	var note_three := BoardingHouseRoomController.build_landlady_note_text(campaign)
	_check(note_three.contains("Ср, 16 апр."),
		"Clara's note moves to Wednesday the 16th on day 3")
	_check(note_three.contains("$4.00") and note_three.to_lower().contains("сегодня"),
		"On the rent day Clara asks for the $4.00 today")
	campaign.day_index = 5
	var note_five := BoardingHouseRoomController.build_landlady_note_text(campaign)
	_check(note_five.contains("Пт, 18 апр."),
		"Clara's note moves to Friday the 18th on day 5")
	_check(note_five.contains("$4.00") and note_five.to_lower().contains("воскрес"),
		"After the rent day Clara squares the board on Sunday")
	_check(note_five != note_one and note_one != note_three,
		"Each day leaves a different note, not one boilerplate letter")
	_check(note_one.contains("Клара Харгроув"), "Clara signs the note")

	GameLocale.lock_language_for_test(EN)
	campaign.day_index = 3
	var en_note := BoardingHouseRoomController.build_landlady_note_text(campaign)
	_check(en_note.contains("Wed, Apr 16") and en_note.contains("$4.00"),
		"The English note is dated Wednesday, April 16, with the $4.00 board")
	_check(en_note.contains("Clara Hargrove") and not en_note.contains("апр."),
		"The English note is signed in English and carries no Russian dates")

	# 8. The live room opens both documents with those exact bodies.
	GameLocale.lock_language_for_test(RU)
	campaign.day_index = 2
	var room_scene := load("res://scenes/town/interiors/boarding_house_room.tscn") as PackedScene
	if not _check(room_scene != null, "The boarding house room scene loads"):
		return _finish(campaign)
	var room := room_scene.instantiate() as BoardingHouseRoomController
	room.enable_psx_rendering = false
	root.add_child(room)
	await process_frame
	await process_frame
	var expected_calendar := BoardingHouseRoomController.build_room_calendar_text(campaign)
	room._open_calendar()
	_check(room.document_viewer.get_current_doc_id() == "room_calendar",
		"The calendar interactable opens the room calendar document")
	_check(room.document_viewer.body_label.text == expected_calendar,
		"The opened calendar is the calendar for today, not a fixed page")
	_check(room.document_viewer.body_label.text.contains("Вт, 15 апр.")
		and room.document_viewer.body_label.text.contains(STRIKE),
		"Day 2 shows Tuesday circled as today and Monday struck")
	room.document_viewer.close_document()
	await process_frame
	var expected_note := BoardingHouseRoomController.build_landlady_note_text(campaign)
	room._open_landlady_note()
	_check(room.document_viewer.get_current_doc_id() == "landlady_note",
		"Clara's note interactable opens the note document")
	_check(room.document_viewer.body_label.text == expected_note
		and expected_note.contains("Вт, 15 апр."),
		"The opened note is dated today")
	room.document_viewer.close_document()
	await process_frame
	room.queue_free()
	await process_frame

	_finish(campaign)

func _finish(campaign: CampaignStateStore) -> void:
	if campaign != null:
		campaign.reset_for_new_game()
	GameLocale.clear_test_override()
	print("Room calendar & Clara note assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
