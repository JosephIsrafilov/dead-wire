extends SceneTree
## Deterministic rendered demonstration, not a human/pacing playtest.
var office: M1OfficeController
func _initialize() -> void: _run.call_deferred()
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func _type(code: int, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func _run() -> void:
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for i in 5: await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.get_node("LampLife").set_wick_immediate(1.0)
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	office.load_scenario_by_index(2)
	var session := office.session_controller
	session.start_transmission()
	await _wait(4.8)
	var paper := session.transcript_paper
	var guard := 0
	while paper.is_copy_in_progress() and guard < 300:
		await process_frame
		guard += 1
	paper.get_interactable().interact()
	await _wait(1.4)
	office.document_viewer.close_document()
	session.get_tape_register().get_interactable().interact()
	await _wait(2.5)
	office.document_viewer.close_document()
	await _wait(0.25)
	office.copy_commit_desk.select_option(0)
	await _wait(1.25)
	for character in "WAITER":
		await _type(character.unicode_at(0), character.to_lower().unicode_at(0))
		await _wait(0.13)
	await _wait(1.1)
	await _type(KEY_ENTER)
	await _wait(0.9)
	office.dawn_evidence.reveal()
	office.dawn_evidence.get_interactable().interact()
	await _wait(2.0)
	var ok: bool = root.get_node("WorldState").get_fact(&"core_hook_filed_word") == "WAITER" \
		and office.dawn_evidence.get_document_text().contains("WAITER")
	print("MECHANICS DEMO exact-choice preserved: ", ok)
	office.queue_free()
	await process_frame
	quit(0 if ok else 1)
