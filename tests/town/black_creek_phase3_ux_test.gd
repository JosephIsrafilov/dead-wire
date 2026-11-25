extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign := root.get_node("CampaignState") as CampaignStateStore
	campaign.reset_for_new_game()
	campaign.phase = CampaignStateStore.PHASE_DAY_TOWN
	var town := preload("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	town.enable_psx_rendering = false
	root.add_child(town)
	await process_frame
	var paper := town.builder.get_town_interactable(&"chronicle_paper")
	_check(paper != null, "The Chronicle stand registers a street interaction")
	if paper == null:
		quit(1)
		return
	for locale in ["ru", "en"]:
		GameLocale.lock_language_for_test(locale)
		town.refresh_locale()
		var expected := GameLocale.pick("Читать газету", "Read the Chronicle")
		_check(paper.get_prompt() == expected, "Localized newspaper prompt: " + locale)
		paper.interact()
		_check(town.document_viewer.is_open() and town.is_world_view_blocked(), "Chronicle opens modally: " + locale)
		_send_key(KEY_J)
		_check(town.thoughts.get_current_text().is_empty(), "Reminder cannot spill into the reader: " + locale)
		town.document_viewer.close_document()
		_check(not town.is_world_view_blocked(), "Closing releases the street controls: " + locale)
		_send_key(KEY_J if locale == "ru" else KEY_F1)
		var hint := town.thoughts.get_current_text()
		_check(hint.contains(GameLocale.pick("типографии", "print shop")), "Localized street reminder: " + locale)
	GameLocale.clear_test_override()
	town.queue_free()
	await process_frame
	quit(int(_failures != 0))

func _send_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key)

func _check(ok: bool, label: String) -> void:
	_failures += int(not ok)
	print(("PASS: " if ok else "FAIL: ") + label)
