extends SceneTree

## The frame around the game: what the player sees before the office, what
## Escape does, and what the wire says about the night once it is over.
##
## Before this pass the game opened with an unexplained man in a dark room and
## Escape did nothing but drop the mouse cursor, leaving the shift running behind
## an uncaptured pointer with no way back except clicking.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Framing Test Suite ---")

	# 1. Settings round-trip through disk.
	var settings := GameSettings.new()
	settings.mouse_sensitivity = 0.0042
	settings.head_bob_enabled = false
	settings.master_volume_db = -7.0
	settings.ambience_volume_db = -12.0
	if not assert_condition(settings.save() == OK, "Settings write to disk"): return

	var reloaded := GameSettings.load_settings()
	if not assert_condition(is_equal_approx(reloaded.mouse_sensitivity, 0.0042), "Sensitivity survives a reload"): return
	if not assert_condition(reloaded.head_bob_enabled == false, "Head bob choice survives a reload"): return
	if not assert_condition(is_equal_approx(reloaded.master_volume_db, -7.0), "Master volume survives a reload"): return
	if not assert_condition(is_equal_approx(reloaded.ambience_volume_db, -12.0), "Ambience volume survives a reload"): return

	var office := _office()
	if office == null: return
	var player := office.player

	# 2. Settings actually reach the things they name. Head bob in particular has
	#    to be the player's call, not an exported constant.
	reloaded.apply(player)
	if not assert_condition(is_equal_approx(player.mouse_sensitivity, 0.0042), "Sensitivity reaches the controller"): return
	if not assert_condition(player.head_bob_enabled == false, "Head bob toggle reaches the controller"): return
	var ambience_bus := AudioServer.get_bus_index("Ambience")
	if not assert_condition(ambience_bus >= 0, "Ambience bus exists"): return
	if not assert_condition(is_equal_approx(AudioServer.get_bus_volume_db(ambience_bus), -12.0), "Ambience volume reaches the bus"): return

	# Restore defaults so a test run does not leave the game quiet.
	var defaults := GameSettings.new()
	defaults.apply(player)
	defaults.save()

	# 3. The intro holds the player still until it is done.
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if not assert_condition(intro != null, "The game opens on an intro card"): return
	if not assert_condition(intro.is_running(), "The intro is running at scene start"): return
	if not assert_condition(intro.visible, "The intro is on screen"): return
	if not assert_condition(player.is_movement_locked and player.is_look_locked, "The operator cannot move or look during the intro"): return

	intro.skip_immediately()
	if not assert_condition(not intro.is_running() and intro.is_finished(), "The intro can be skipped"): return
	if not assert_condition(not intro.visible, "The intro clears the screen"): return
	if not assert_condition(not player.is_movement_locked and not player.is_look_locked, "Skipping hands control back"): return

	# 4. Escape holds the line rather than dropping the cursor.
	var pause_menu := office.get_node_or_null("PauseMenu") as PauseMenu
	if not assert_condition(pause_menu != null, "There is a pause menu"): return
	if not assert_condition(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "The pause menu still runs while the tree is paused"): return
	if not assert_condition(not pause_menu.is_paused and not pause_menu.visible, "It starts closed"): return

	pause_menu.pause()
	if not assert_condition(pause_menu.is_paused and pause_menu.visible, "Escape holds the line"): return
	if not assert_condition(root.get_tree().paused, "The shift actually stops"): return

	pause_menu.resume()
	if not assert_condition(not pause_menu.is_paused and not pause_menu.visible, "Resuming closes the menu"): return
	if not assert_condition(not root.get_tree().paused, "The shift runs again"): return

	# 5. A document in hand takes Escape first: put the paper down before you stop
	#    the shift.
	var viewer := office.document_viewer
	if not assert_condition(viewer != null, "Document viewer is wired"): return
	viewer.open_document("test_doc", "TEST", "body")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	pause_menu._input(escape)
	if not assert_condition(not pause_menu.is_paused, "Escape with a document open does not pause"): return
	viewer.close_document()
	pause_menu._input(escape)
	if not assert_condition(pause_menu.is_paused, "Escape with empty hands pauses"): return
	pause_menu.resume()

	# 6. The controls the menu offers are the ones that exist.
	if not assert_condition(pause_menu.sensitivity_slider != null, "Sensitivity is adjustable"): return
	if not assert_condition(pause_menu.head_bob_check != null, "Head bob is toggleable by the player"): return
	if not assert_condition(pause_menu.master_slider != null and pause_menu.ambience_slider != null, "Both volumes are adjustable"): return
	if not assert_condition(pause_menu.resume_button != null and pause_menu.quit_button != null, "Resume and quit exist"): return

	# 7. The wire answers for the night. A clean watch is signed off; a watch with
	#    a hole in it gets asked where the train is. This is the objective world
	#    replying — Elias's own paperwork never learns it.
	var director := office.shift_director
	if not assert_condition(not director.had_trouble(), "A shift with nothing gone wrong reports no trouble"): return
	director.messages_missed = 1
	if not assert_condition(director.had_trouble(), "A missed message counts as trouble"): return
	director.messages_missed = 0
	director.routes_defaulted = 1
	if not assert_condition(director.had_trouble(), "A lapsed route counts as trouble"): return
	director.routes_defaulted = 0
	director.routes_misdirected = 1
	if not assert_condition(director.had_trouble(), "A wrong route counts as trouble"): return

	var encoder := AmericanMorseEncoder.new()
	if not assert_condition(encoder.encode(director.closing_sign, director.alphabet) != null, "The clean sign-off is sendable American Morse"): return
	if not assert_condition(encoder.encode(director.closing_sign_trouble, director.alphabet) != null, "The trouble query is sendable American Morse"): return
	if not assert_condition(director.closing_sign != director.closing_sign_trouble, "The two nights do not sound the same"): return

	# 8. Elias can see the gap in his own paperwork without learning what it cost.
	var sheet := office.get_node_or_null("DutySheet") as DutySheet
	if not assert_condition(sheet != null, "Duty sheet is present"): return
	var text := sheet.get_sheet_text()
	if not assert_condition(text.contains("Not every item on this sheet is closed"), "An unfinished sheet says so"): return
	if not assert_condition(not text.contains("missed") and not text.contains("WATER"), "It still never reports what actually happened"): return

	print("--- All Framing Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _office() -> M1OfficeController:
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return null
	root.add_child(office)
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)
	return office

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	if root != null and root.get_tree() != null:
		root.get_tree().paused = false
	quit(1)
	return false
