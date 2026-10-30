extends SceneTree
## Plan 6.7: the title is the office at night. A frame of the room stands
## behind the menu, the menu sits in the dark half, its lines are ruled like a
## blank, a choice clicks like a key, and the far-off office call comes now
## and then, whole, and goes quiet again.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/title_mood_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Title Mood Test Suite ---")
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var mood := menu.get_mood()
	if not _a(mood != null and mood.get_backdrop() != null, "A frame of the office stands behind the title"): return
	if not _a(mood.get_index() < menu.get_node("CenterContainer").get_index(), "The frame is behind the menu, never over it"): return
	if not _a(mood.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The frame never takes a click meant for the menu"): return
	var column := menu.get_node("CenterContainer") as Control
	if not _a(is_equal_approx(column.anchor_left, 0.5), "The menu stands in the dark half of the frame"): return
	var ruled := menu.begin_button.get_theme_stylebox("normal") as StyleBoxFlat
	if not _a(ruled != null and ruled.border_width_bottom == 1 and ruled.bg_color.a == 0.0, "Its lines are ruled like a blank"): return
	if not _a(menu.begin_button.pressed.is_connected(mood.click), "Choosing a line clicks like a key"): return

	# The far-off call: silent at first, then a whole CR CR, then quiet again.
	mood._process(1.0)
	if not _a(mood._call_time < 0.0, "The title starts in the room's own quiet"): return
	for _step in 200:
		mood._process(0.1)
		if mood._call_time >= 0.0:
			break
	if not _a(mood._call_time >= 0.0, "Within its first seconds the office call comes, far off"): return
	for _step in 80:
		mood._process(0.05)
	if not _a(mood._call_time < 0.0 and mood._call_step == TitleMood.CALL_UNITS.size() * 2,
		"The call plays whole and goes quiet again"): return
	if not _a(mood._next_call >= mood.call_interval.x - 0.01 and mood._next_call <= mood.call_interval.y,
		"The next call waits a long while"): return

	menu.queue_free()
	await process_frame
	print("--- All Title Mood Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
