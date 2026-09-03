extends SceneTree

var _assertions_passed: int = 0
var _tick_signal_payloads: Array[int] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Office Ambience Test Suite ---")

	# 1. The dedicated mix bus exists so ambience can be balanced against Morse.
	var ambience_bus_index := AudioServer.get_bus_index("Ambience")
	if not assert_condition(ambience_bus_index > 0, "Dedicated 'Ambience' audio bus exists"): return
	if not assert_condition(AudioServer.get_bus_send(ambience_bus_index) == "Master", "Ambience bus sends to Master"): return

	# 2. Standalone construction.
	var ambience := OfficeAmbience.new()
	root.add_child(ambience)
	await process_frame

	if not assert_condition(ambience.room_tone_player != null, "Room tone player is built"): return
	if not assert_condition(ambience.wind_player != null, "Window wind player is built"): return
	if not assert_condition(ambience.stove_player != null, "Stove fire player is built"): return
	if not assert_condition(ambience.clock_player != null, "Clock tick player is built"): return

	# 3. Every layer carries a real stream. Silence would pass a naive structural check.
	if not assert_condition(ambience.room_tone_player.stream != null, "Room tone stream is loaded"): return
	if not assert_condition(ambience.wind_player.stream != null, "Wind stream is loaded"): return
	if not assert_condition(ambience.stove_player.stream != null, "Stove stream is loaded"): return
	if not assert_condition(ambience.clock_player.stream != null, "Clock tick stream is loaded"): return

	# 4. The three beds must loop, or the room falls silent mid-shift.
	for entry in [["Room tone", ambience.room_tone_player.stream], ["Wind", ambience.wind_player.stream], ["Stove", ambience.stove_player.stream]]:
		var stream := entry[1] as AudioStreamWAV
		if not assert_condition(stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s bed is set to loop" % entry[0]): return

	# 5. The clock tick is a one-shot. A looping tick would smear into a drone.
	var tick_stream := ambience.clock_tick_stream as AudioStreamWAV
	if not assert_condition(tick_stream != null and tick_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Clock tick does not loop"): return

	# 6. Divided attention depends on direction: positional layers must be 3D and
	#    separated in space, while the room tone must stay non-positional.
	if not assert_condition(ambience.room_tone_player is AudioStreamPlayer, "Room tone is non-positional"): return
	if not assert_condition(ambience.wind_player is AudioStreamPlayer3D, "Wind is positional"): return
	if not assert_condition(ambience.stove_player is AudioStreamPlayer3D, "Stove is positional"): return
	if not assert_condition(ambience.clock_player is AudioStreamPlayer3D, "Clock is positional"): return

	var wind_to_stove := ambience.wind_player.position.distance_to(ambience.stove_player.position)
	var wind_to_clock := ambience.wind_player.position.distance_to(ambience.clock_player.position)
	var stove_to_clock := ambience.stove_player.position.distance_to(ambience.clock_player.position)
	if not assert_condition(wind_to_stove > 2.0, "Wind and stove are audibly separate positions"): return
	if not assert_condition(wind_to_clock > 2.0, "Wind and clock are audibly separate positions"): return
	if not assert_condition(stove_to_clock > 2.0, "Stove and clock are audibly separate positions"): return

	# 7. Everything routes to the ambience bus.
	for entry in [["Room tone", ambience.room_tone_player], ["Wind", ambience.wind_player], ["Stove", ambience.stove_player], ["Clock", ambience.clock_player]]:
		if not assert_condition(entry[1].bus == &"Ambience", "%s routes to the Ambience bus" % entry[0]): return

	# 8. Morse fairness: ambience must sit under the sounder, never over it.
	var sounder := SounderController.new()
	var sounder_volume: float = sounder.volume_db
	sounder.free()
	for entry in [["Room tone", ambience.room_tone_volume_db], ["Wind", ambience.wind_volume_db], ["Stove", ambience.stove_volume_db], ["Clock", ambience.clock_volume_db]]:
		if not assert_condition(entry[1] < sounder_volume, "%s sits below the sounder level" % entry[0]): return

	# 9. Escapement timing.
	ambience.clock_ticked.connect(_on_clock_ticked)
	ambience.reset_telemetry()
	if not assert_condition(ambience.ticks_played == 0, "Clock telemetry starts at zero"): return

	ambience.advance_clock(0.4)
	if not assert_condition(ambience.ticks_played == 0, "No tick before a full interval elapses"): return
	ambience.advance_clock(0.6)
	if not assert_condition(ambience.ticks_played == 1, "One tick after exactly one interval"): return
	ambience.advance_clock(3.0)
	if not assert_condition(ambience.ticks_played == 4, "Ticks accumulate one per interval"): return
	if not assert_condition(_tick_signal_payloads == [1, 2, 3, 4], "clock_ticked emits an increasing tick count"): return

	# 10. The clock can be silenced without disturbing the beds.
	ambience.clock_enabled = false
	ambience.advance_clock(5.0)
	if not assert_condition(ambience.ticks_played == 4, "Disabled clock stops ticking"): return
	ambience.clock_enabled = true

	ambience.reset_telemetry()
	if not assert_condition(ambience.ticks_played == 0, "reset_telemetry clears the tick count"): return

	# 11. start() is idempotent and stop() silences everything.
	ambience.start()
	ambience.start()
	if not assert_condition(ambience.room_tone_player.playing, "Room tone plays after start()"): return
	ambience.stop()
	if not assert_condition(not ambience.room_tone_player.playing, "stop() halts the room tone"): return
	if not assert_condition(not ambience.wind_player.playing, "stop() halts the wind"): return
	if not assert_condition(not ambience.stove_player.playing, "stop() halts the stove"): return

	# 12. The production scene actually carries the ambience node.
	var office_scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(office_scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = office_scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return
	root.add_child(office)
	await process_frame

	var scene_ambience := office.get_node_or_null("OfficeAmbience") as OfficeAmbience
	if not assert_condition(scene_ambience != null, "Production scene contains OfficeAmbience"): return
	if not assert_condition(scene_ambience.room_tone_player != null and scene_ambience.room_tone_player.playing, "Production room tone is running"): return
	if not assert_condition(scene_ambience.wind_player.playing, "Production wind bed is running"): return
	if not assert_condition(scene_ambience.stove_player.playing, "Production stove bed is running"): return

	# 13. Positional beds must sit at the physical props they belong to.
	var window := office.get_node_or_null("NorthWindow") as Node3D
	var stove := office.get_node_or_null("CornerStove") as Node3D
	if not assert_condition(window != null and stove != null, "Window and stove props exist"): return
	var wind_offset := scene_ambience.wind_player.global_position.distance_to(window.global_position)
	var stove_offset := scene_ambience.stove_player.global_position.distance_to(stove.global_position)
	if not assert_condition(wind_offset < 0.5, "Wind bed is anchored at the north window"): return
	if not assert_condition(stove_offset < 1.2, "Stove bed is anchored at the corner stove"): return

	# 14. The ambience must never grab the player's interaction focus.
	if not assert_condition(scene_ambience.get_node_or_null("Interactable") == null, "Ambience exposes no interactable"): return

	print("--- All Office Ambience Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func _on_clock_ticked(tick_count: int) -> void:
	_tick_signal_payloads.append(tick_count)

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
