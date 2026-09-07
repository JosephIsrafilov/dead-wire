extends SceneTree

func _init() -> void:
	print("--- Starting Copy Commit Desk Test Suite ---")
	var desk_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/copy_commit_desk.tscn")
	if not assert_condition(desk_scene != null, "copy_commit_desk.tscn loads"): return
	var desk: CopyCommitDesk = desk_scene.instantiate() as CopyCommitDesk
	if not assert_condition(desk != null, "instantiates as CopyCommitDesk"): return
	root.add_child(desk)

	var options: Array = [
		{"action_id": "file_water", "display_label": "CORRECT COPY: WATER", "result_text": "WATER FILED"},
		{"action_id": "file_watcher", "display_label": "FILE COPY: WATCHER", "result_text": "WATCHER FILED"},
	]
	desk.configure(options)
	var option_one_label := desk.get_node("OptionOneLabel") as Label3D
	var option_two_label := desk.get_node("OptionTwoLabel") as Label3D
	if not assert_condition(not option_one_label.visible and not option_two_label.visible, "Copy options stay hidden before transcript verification"): return
	desk.set_enabled(true)
	if not assert_condition(desk.is_enabled(), "Desk enables after two options are configured"): return
	if not assert_condition(option_one_label.visible and option_two_label.visible, "Both physical copy options appear when desk unlocks"): return
	var committed: Array[StringName] = []
	desk.option_committed.connect(func(action_id: StringName): committed.append(action_id))
	if not assert_condition(desk.commit_option(StringName("file_watcher")), "Valid option commits"): return
	if not assert_condition(committed == [StringName("file_watcher")], "Commit signal emits exactly once"): return
	if not assert_condition(desk.get_selected_action_id() == StringName("file_watcher"), "Selected action is retained"): return
	if not assert_condition(desk.get_result_text() == "WATCHER FILED", "Selected result feedback is retained"): return
	if not assert_condition(not desk.is_enabled(), "Desk disables after commit"): return
	if not assert_condition(option_one_label.visible and option_two_label.visible, "Both copy labels remain visible after filing"): return
	if not assert_condition(not desk.commit_option(StringName("file_water")), "Second commit is rejected"): return
	if not assert_condition(committed.size() == 1, "Duplicate commit emits no second signal"): return

	desk.reset()
	if not assert_condition(not desk.has_committed() and not desk.is_enabled(), "Reset clears commit and keeps desk disabled"): return
	desk.set_enabled(true)
	var key_one := InputEventKey.new()
	key_one.physical_keycode = KEY_1
	key_one.pressed = true
	key_one.echo = false
	desk._input(key_one)
	if not assert_condition(desk.has_committed() and desk.get_selected_action_id() == StringName("file_water"), "InputMap/numeric key commits the first option"): return
	if not assert_condition(committed.size() == 2, "Keyboard commit emits exactly one additional signal"): return

	desk.reset()
	desk.configure(options)
	desk.set_enabled(true)
	desk.show_lapsed()
	var prompt_label := desk.get_node("PromptLabel") as Label3D
	var result_label := desk.get_node("ResultLabel") as Label3D
	if not assert_condition(desk.has_committed() and not desk.is_enabled(), "Lapsed result locks the desk without selecting a copy"): return
	if not assert_condition(desk.get_selected_action_id() == StringName("lapsed"), "Lapsed result keeps a distinct action id"): return
	if not assert_condition(result_label.text == "UNFILED" and prompt_label.text == "NO COPY FILED", "Lapsed result is visible as UNFILED"): return
	if not assert_condition((option_one_label.modulate.r + option_one_label.modulate.g + option_one_label.modulate.b) < 1.0, "Copy labels use dark ink for paper contrast"): return
	if not assert_condition(option_one_label.font_size >= 16 and option_two_label.font_size >= 16, "Copy labels keep readable authored size"): return

	desk.queue_free()
	print("--- All Copy Commit Desk Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	print("  PASS: %s" % description)
	return true
