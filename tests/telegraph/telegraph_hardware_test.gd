extends SceneTree

func _init() -> void:
	print("--- Starting Telegraph Hardware Scene Test Suite (Gate 10 / Gate 20A) ---")

	# 1. Load sounder scene
	var sounder_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/sounder.tscn")
	if not assert_condition(sounder_scene != null, "sounder.tscn loads"): return
	var sounder_node: Node3D = sounder_scene.instantiate() as Node3D
	if not assert_condition(sounder_node != null and sounder_node is SounderController, "sounder instantiates as SounderController"): return
	root.add_child(sounder_node)

	# 2. Load telegraph key scene
	var key_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/telegraph_key.tscn")
	if not assert_condition(key_scene != null, "telegraph_key.tscn loads"): return
	var key_node: TelegraphKey = key_scene.instantiate() as TelegraphKey
	if not assert_condition(key_node != null, "telegraph_key instantiates as TelegraphKey"): return
	root.add_child(key_node)

	var act: Interactable = key_node.get_interactable()
	if not assert_condition(act != null, "key has Interactable component"): return
	if not assert_condition(act.prompt_text == "Answer the Line", "key interactable prompt text matches"): return

	# 3. Test enabled press
	var key_pressed_count: Array[int] = [0]
	key_node.key_pressed.connect(func(): key_pressed_count[0] += 1)

	act.interact()
	if not assert_condition(key_pressed_count[0] == 1, "key interact() triggers key_pressed signal when enabled"): return
	if not assert_condition(key_node.press_count == 1, "key.press_count is 1"): return

	# 4. Test disabled physical press with visible prompt
	key_node.set_prompt_message("Line Busy (Receiving Telegram)")
	key_node.set_enabled(false)
	if not assert_condition(act.prompt_text == "Line Busy (Receiving Telegram)", "Prompt updated to Line Busy"): return
	if not assert_condition(act.can_interact(), "Interactable remains enabled for prompt visibility"): return

	act.interact()
	if not assert_condition(key_pressed_count[0] == 1, "interact() on disabled key does NOT emit key_pressed"): return
	if not assert_condition(key_node.press_count == 1, "press_count does not increase when disabled"): return

	# Re-enable
	key_node.set_enabled(true)
	key_node.set_prompt_message("Answer the Line")
	act.interact()
	if not assert_condition(key_pressed_count[0] == 2, "interact() after re-enabling emits key_pressed"): return

	# 5. Load composite telegraph station scene
	var station_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/telegraph_station.tscn")
	if not assert_condition(station_scene != null, "telegraph_station.tscn loads"): return
	var station_node: Node3D = station_scene.instantiate() as Node3D
	if not assert_condition(station_node != null, "telegraph_station instantiates"): return
	root.add_child(station_node)

	var station_sounder := station_node.get_node_or_null("Sounder")
	var station_key := station_node.get_node_or_null("TelegraphKey")
	if not assert_condition(station_sounder != null and station_sounder is SounderController, "station contains Sounder"): return
	if not assert_condition(station_key != null and station_key is TelegraphKey, "station contains TelegraphKey"): return

	# Clean up
	sounder_node.queue_free()
	key_node.queue_free()
	station_node.queue_free()

	print("--- All Telegraph Hardware Scene Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
