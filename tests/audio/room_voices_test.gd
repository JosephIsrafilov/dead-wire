extends SceneTree
## Plan 7.5 / 7.8 / 7.11: the room's new voices.
##   - the wire outside sings through the glass, low and dulled, and opens up
##     when the door does;
##   - before the last call the clock's tick drops out of hearing while its
##     movement runs on, and comes back with the room;
##   - the register's clockwork whirs while it runs and slows with its spring.
##   godot --headless --audio-driver Dummy --path . --script tests/audio/room_voices_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Room Voices Test Suite ---")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var ambience := office.get_node("OfficeAmbience") as OfficeAmbience

	# --- the singing wire -----------------------------------------------------
	var wire := ambience.wire_player
	if not _a(wire != null and wire.playing and wire.bus == &"Ambience", "The wire outside sings on the room's bus"): return
	if not _a(wire.position.z < -2.36, "The wire is outside, beyond the window wall"): return
	# The intro card's own hush fades out on a tween; measure from a quiet room.
	ambience.set_hush_db(0.0)
	var glass_db := wire.volume_db
	if not _a(is_equal_approx(wire.attenuation_filter_cutoff_hz, ambience.wire_glass_cutoff_hz), "Through the glass only its low hum reaches the room"): return
	(office.get_node("SouthDoor/DoorController")).door_opened.emit()
	if not _a(ambience.is_open_to_outside() and wire.attenuation_filter_cutoff_hz > ambience.wire_glass_cutoff_hz
		and wire.volume_db > glass_db, "With the door open the wire is nearer and brighter"): return
	var open_db := wire.volume_db
	ambience.set_hush_db(-12.0)
	if not _a(is_equal_approx(wire.volume_db, open_db - 12.0), "A hush takes the wire down with the room"): return
	ambience.set_hush_db(0.0)

	# --- the clock's silence before the last call ----------------------------
	var unease := office.get_node("UneaseDirector") as UneaseDirector
	ambience.reset_telemetry()
	ambience.clock_player.stop()
	ambience.clock_muted = true
	ambience.advance_clock(3.0)
	if not _a(ambience.ticks_played == 3 and not ambience.clock_player.playing, "Muted, the tick is gone but the movement runs on"): return
	unease.is_hushed = true
	unease.release_hush()
	if not _a(not ambience.clock_muted, "When the room comes back, so does the tick"): return
	ambience.advance_clock(1.0)
	if not _a(ambience.clock_player.playing, "The tick is heard again"): return

	# --- the register's clockwork ----------------------------------------------
	var whir := office.get_node("RegisterWhir") as RegisterWhir
	var register := office.session_controller.get_tape_register()
	if not _a(whir != null and whir.get_player() != null and whir.get_player().get_parent() == register,
		"The register carries its own whir"): return
	register.spring_tension = 1.0
	whir.advance()
	var full_pitch := whir.get_player().pitch_scale
	var full_db := whir.get_player().volume_db
	register.spring_tension = 0.2
	whir.advance()
	if not _a(whir.get_player().pitch_scale < full_pitch and whir.get_player().volume_db < full_db,
		"A tired spring is heard: slower and lower"): return
	if not _a(whir.get_player().playing == register.is_clockwork_running(), "It whirs only while the movement runs"): return

	office.queue_free()
	for _frame in 5:
		await process_frame
	print("--- All Room Voices Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
