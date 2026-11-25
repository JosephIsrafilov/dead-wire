extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameLocale.lock_language_for_test("en")
	var town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	town.enable_psx_rendering = false
	root.add_child(town)
	current_scene = town
	var knock := town.get_node_or_null("DoorKnockSequence")
	var press := town.builder.interactable_triggered
	press.emit(&"chronicle_door")
	_check(town.thoughts.get_current_text().is_empty(), "E waits before showing a door thought")
	if knock == null:
		_check(false, "Town has a spatial knock sequence")
		quit(1)
		return
	var sound := knock.get_node("DoorFoley") as AudioStreamPlayer3D
	var door := town.builder.get_town_interactable(&"chronicle_door") as Interactable
	_check(sound.playing and sound.stream.resource_path.ends_with("/door_knock_wood.wav")
		and sound.bus == &"Foley" and sound.global_position.is_equal_approx(door.global_position),
		"A recorded knock starts at the door on Foley")
	_check(not town.player.is_movement_locked, "Waiting does not lock player movement")
	var serial: int = knock._knock_serial
	await create_timer(0.55).timeout
	press.emit(&"chronicle_door")
	_check(knock._knock_serial == serial, "Repeat E on the same door does not restart the knock")
	await create_timer(0.75).timeout
	_check(town.thoughts.get_current_text().is_empty(), "Thought stays hidden during the pause")
	await create_timer(0.45).timeout
	_check(town.thoughts.get_current_text() ==
		"Dead inside. Press is cold, only stale newsprint through the keyhole.",
		"The exact Chronicle thought appears at the original deadline")

	knock.thought_delay_seconds = 0.24
	press.emit(&"chronicle_door")
	await create_timer(0.14).timeout
	press.emit(&"assay_door")
	await create_timer(0.15).timeout
	_check(town.thoughts.get_current_text().is_empty(), "A second door suppresses the first deadline")
	await create_timer(0.14).timeout
	_check(town.thoughts.get_current_text() == "Bolted tight till morning.", "Only the second door answers")
	press.emit(&"chapel_door")
	_check(sound.playing and sound.stream.resource_path.ends_with("/door_latch.wav"),
		"The chapel plays its latch")
	town.document_viewer.open_document("test", "Test", "Test", "Close")
	town.document_viewer.close_document()
	await create_timer(0.30).timeout
	_check(town.thoughts.get_current_text().is_empty(), "Opening and closing a document cancels the delayed thought")

	press.emit(&"chronicle_door")
	paused = true
	await create_timer(0.30).timeout
	paused = false
	await create_timer(0.30).timeout
	_check(town.thoughts.get_current_text().is_empty(), "Pause and resume cancels the delayed thought")
	press.emit(&"chronicle_door")
	press.emit(&"boarding_door")
	await scene_changed
	var house := current_scene as BoardingHouseRoomController
	_check(house != null and not is_instance_valid(knock), "Entering the boarding house removes the pending town sequence")
	await create_timer(0.30).timeout
	_check(house.thoughts.get_current_text().is_empty(), "The town thought cannot appear after a scene change")
	var house_knock := house.get_node("DoorKnockSequence")
	house_knock.thought_delay_seconds = 0.10
	var house_sound := house_knock.get_node("DoorFoley") as AudioStreamPlayer3D
	var expected := [
		"Baines snoring through the pine panels. Guy's got an hour left before shaft bell—leave him be.",
		"Dead quiet inside. Lindstrom's already out walking ballast with the track crew.",
		"Rusted deadbolt and dead air behind the wood. Clara hasn't rented out Room 3 since last fall.",
	]
	for index in range(3):
		var room := index + 1
		var room_door := house.get_node("HargroveCommon/room_%d_Interactable" % room) as Interactable
		room_door.interact()
		_check(house.thoughts.get_current_text().is_empty() and house_sound.playing
			and house_sound.global_position.is_equal_approx(room_door.global_position), "Room %d starts a spatial knock" % room)
		await create_timer(0.15).timeout
		_check(house.thoughts.get_current_text() == expected[index], "Room %d gives its exact thought after the pause" % room)
	house.queue_free()
	await process_frame
	GameLocale.clear_test_override()
	quit(int(_failures > 0))

func _check(success: bool, message: String) -> void:
	_failures += int(not success)
	print("  %s: %s" % ["PASS" if success else "FAIL", message])

