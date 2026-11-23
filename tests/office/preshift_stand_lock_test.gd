extends SceneTree

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, desc: String) -> void:
	if cond:
		print("  PASS: " + desc)
		_passed += 1
	else:
		print("  FAIL: " + desc)
		_failed += 1

func _run() -> void:
	var scene := load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := scene.instantiate() as M1OfficeController
	office.enable_psx_rendering = false
	root.add_child(office)
	await process_frame
	await process_frame

	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	await process_frame

	var arrival := office.get_node_or_null("ShiftArrival") as ShiftArrival
	if arrival != null:
		arrival._finished = false
		arrival.begin()
		for i in 22:
			arrival.advance(0.16)

	var station := office.get_node_or_null("SeatedStationController") as SeatedStationController
	var seat := office.operator_seat
	var director := office.shift_director
	var ic := office.player.get_node_or_null("InteractionController") as InteractionController
	var chair_act := office.get_node_or_null("Chair/Interactable") as Interactable
	var key := office.session_controller.telegraph_key
	var key_act := key.get_interactable()

	seat.approach_duration = 0.0
	seat.sit_duration = 0.0
	seat.stand_duration = 0.0

	# 1. Seated in PRE_SHIFT: can stand up freely and both duty strip + key tooltip warn about lock
	_check(seat.sit(), "Player sits down in PRE_SHIFT")
	await process_frame
	_check(station.is_activated() and station.can_stand_up() and station._btn_stand.visible,
		"Stand button is visible and can_stand_up() is true before opening the line")

	GameLocale.lock_language_for_test("ru")
	GameLocale.refresh_office_locale(office)
	var ru_texts := station._duty_texts()
	var ru_key_tip := station._friendly_cursor_label(key_act)
	_check(ru_texts.sub.contains("встать") and ru_texts.sub.contains("нельзя"),
		"PRE_SHIFT duty strip warns in RU that opening the line locks the post")
	_check(ru_key_tip.contains("Открыть линию") and ru_key_tip.contains("нельзя"),
		"PRE_SHIFT brass key tooltip warns in RU that opening the line locks the post")

	GameLocale.lock_language_for_test("en")
	GameLocale.refresh_office_locale(office)
	var en_texts := station._duty_texts()
	var en_key_tip := station._friendly_cursor_label(key_act)
	_check(en_texts.sub.contains("stand") and en_texts.sub.contains("cannot leave"),
		"PRE_SHIFT duty strip warns in EN that opening the line locks the post")
	_check(en_key_tip.contains("Open the Line") and en_key_tip.contains("locks you at the desk"),
		"PRE_SHIFT brass key tooltip warns in EN that opening the line locks the post")
	_check(key.prompt_message == ShiftDirector.PROMPT_OPEN_LINE,
		"ShiftDirector keeps PROMPT_OPEN_LINE unchanged for contracts")

	# 2. Stand up during PRE_SHIFT
	station._on_stand_pressed()
	await process_frame
	_check(not station.is_activated() and not office.player.seated_station_mode
		and not ic.cursor_mode and not seat.is_seated,
		"Standing up in PRE_SHIFT returns player to free-walk mode cleanly")
	_check(chair_act.can_interact() and chair_act.collision_layer == 2,
		"Chair interactable re-enables when standing up before opening the line")
	_check(not key_act.is_actionable,
		"Telegraph key disables while standing in PRE_SHIFT")

	# 3. Sit back down during PRE_SHIFT
	_check(seat.sit(), "Player can sit back down after standing in PRE_SHIFT")
	await process_frame
	_check(station.is_activated() and office.player.seated_station_mode and ic.cursor_mode,
		"Re-sitting re-activates seated workstation cleanly")
	_check(key_act.is_actionable and station.can_stand_up() and station._btn_stand.visible,
		"Brass key and pre-shift stand button both re-enable upon re-sitting")

	# 4. Opening the line locks standing and triggers timed confirmation notice
	_check(director.open_line(), "Opening the line starts active watch")
	await process_frame
	_check(not station.can_stand_up() and not station._btn_stand.visible,
		"Stand button disappears and can_stand_up() is false once the line is open")
	_check(not station.get_post_lock_notice_text().is_empty() and station._duty_sub.visible
		and not station._is_quiet_silence(),
		"Opening the line displays the active post-lock notice in duty strip")

	station._process(5.0)
	_check(station.get_post_lock_notice_text().is_empty() and station._is_quiet_silence(),
		"Opening confirmation notice clears after timer expires and restores quiet silence")

	# 5. Attempting to stand during active watch keeps player seated and warns in RU & EN
	GameLocale.lock_language_for_test("ru")
	station._on_stand_pressed()
	await process_frame
	_check(station.is_activated() and office.player.seated_station_mode and seat.is_seated,
		"Stand button click does not stand player up after line is opened")
	var ru_lock := station.get_post_lock_notice_text()
	_check(not ru_lock.is_empty() and station._duty_sub.text.contains(ru_lock),
		"Attempted stand-up shows RU lock warning in duty strip")

	station._process(4.0)
	GameLocale.lock_language_for_test("en")
	var tab_ev := InputEventKey.new()
	tab_ev.keycode = KEY_TAB
	tab_ev.pressed = true
	station._unhandled_input(tab_ev)
	await process_frame
	_check(station.is_activated() and office.player.seated_station_mode,
		"Pressing Tab during active watch does not stand player up")
	var en_lock := station.get_post_lock_notice_text()
	_check(not en_lock.is_empty() and station._duty_sub.text.contains(en_lock),
		"Pressing Tab during active watch shows EN lock warning in duty strip")

	# 6. At dawn (SHIFT_OVER), standing unlocks again
	director._set_phase(ShiftDirector.Phase.SHIFT_OVER)
	await process_frame
	_check(station.can_stand_up() and station._btn_stand.visible,
		"Stand button becomes available again when shift is over")
	station._on_stand_pressed()
	await process_frame
	_check(not station.is_activated() and not office.player.seated_station_mode and not ic.cursor_mode,
		"Standing up at dawn exits seated workstation cleanly")

	GameLocale.clear_test_override()
	office.queue_free()
	await process_frame
	print("Pre-shift stand/lock assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
