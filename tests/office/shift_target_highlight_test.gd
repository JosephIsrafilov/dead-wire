extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.get_node("ShiftArrival").skip_immediately()
	var highlight := office.get_node_or_null("ShiftTargetHighlight")
	_check(highlight != null, "Production office contains the highlight controller")
	if highlight == null:
		quit(1)
		return
	var director := office.shift_director
	var session := office.session_controller
	director.set_process(false)
	session.scheduler.auto_process = false
	_targets(highlight, [&"chair"], "Standing before the watch")
	var mesh := office.get_node("Chair/AuthoredChair") as MeshInstance3D
	var base := mesh.material_override
	var surface := mesh.get_active_material(0)
	var overlay := mesh.material_overlay
	highlight._process(1.0)
	_check(mesh.material_overlay is ShaderMaterial and mesh.material_override == base
		and mesh.get_active_material(0) == surface, "Only the overlay changes on a hinted mesh")
	var interaction := office.player.get_node("InteractionController") as InteractionController
	interaction.current_target = office.get_node("Chair/Interactable") as Interactable
	highlight._process(1.0)
	_check(mesh.material_overlay == overlay, "Focusing the chair fades its overlay away")
	interaction.current_target = null
	office.player.seated_station_mode = true
	office.operator_seat.is_seated = true
	_targets(highlight, [&"key", &"timetable"], "Seated before opening the line")
	office.document_viewer.open_document("timetable_card", "Test", "Test")
	_targets(highlight, [], "Open viewer suppresses all targets")
	office.document_viewer.close_document()
	_targets(highlight, [&"key"], "Read timetable leaves only the key")
	director._slot_index = 0
	director._phase = ShiftDirector.Phase.CALLING
	_targets(highlight, [&"key"], "Answer the call on the key")
	highlight._process(1.0)
	var key_static := office.get_node("TelegraphStation/TelegraphKey/AuthoredStatic") as GeometryInstance3D
	var accent := highlight.get_node("HintAccentLight") as OmniLight3D
	_check(key_static.material_overlay is ShaderMaterial and accent.visible and accent.light_energy > 0.1,
		"Active desk key highlights whole body and engages soft accent light")
	for state in [TelegraphSessionController.State.RECEIVING, TelegraphSessionController.State.COPYING]:
		session._state = state
		_targets(highlight, [], "Live wire and writing protect the frame")
		highlight._process(0.1)
		_check(not accent.visible and accent.light_energy == 0.0, "Live wire extinguishes accent light")
	director._phase = ShiftDirector.Phase.AWAITING_ROUTE
	session._state = TelegraphSessionController.State.VERIFYING
	_targets(highlight, [&"copy"], "Read the finished sheet")
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	_targets(highlight, [&"board"], "Routing highlights only the neutral frame")
	session._state = TelegraphSessionController.State.AWAITING_COMMIT
	_targets(highlight, [&"filing"], "Both filing clips share one neutral target")
	var register := session.get_tape_register()
	register.spring_tension = 0.5
	_targets(highlight, [&"winding_key"], "A slow register takes priority in the quiet")
	register.wind()
	director._slot_index = 2
	session._state = TelegraphSessionController.State.READY
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.AWAITING_COMMIT
	_targets(highlight, [&"tape", &"pen"], "Slot 3 offers tape and pen without selecting a filing result")
	office.document_viewer.open_document(TapeRegisterController.TAPE_DOC_ID, "Test", "Test")
	office.document_viewer.close_document()
	_targets(highlight, [&"pen", &"filing"], "After reading the tape the two filing affordances remain")
	director._phase = ShiftDirector.Phase.SHIFT_OVER
	office.player.seated_station_mode = false
	office.operator_seat.is_seated = false
	_targets(highlight, [&"handover"], "Dawn sends the standing operator to the handover")
	office.dawn_evidence._inspected = true
	_targets(highlight, [&"door"], "Reading the handover points to the south door")
	office.queue_free()
	await process_frame
	quit(int(_failures > 0))

func _targets(controller: Node, expected: Array, message: String) -> void:
	var actual: Array = controller.get_active_target_ids()
	_check(actual == expected, "%s (got %s)" % [message, actual])

func _check(success: bool, message: String) -> void:
	_failures += int(not success)
	print("  %s: %s" % ["PASS" if success else "FAIL", message])

