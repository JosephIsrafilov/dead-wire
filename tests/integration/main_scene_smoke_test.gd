extends SceneTree

func _init() -> void:
	print("--- Starting Main Scene Smoke Test ---")

	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	if not assert_condition(world != null and knowledge != null, "State autoloads are present"): return
	world.reset_for_new_game()
	knowledge.reset_for_new_game()

	var menu_scene: PackedScene = ResourceLoader.load("res://scenes/ui/main_menu.tscn")
	if not assert_condition(menu_scene != null, "Main menu scene loads"): return
	var menu := menu_scene.instantiate() as MainMenu
	if not assert_condition(menu != null, "Main menu instantiates"): return
	root.add_child(menu)
	await process_frame
	if not assert_condition(menu.begin_button != null and menu.begin_button.text == "Begin the Watch", "Main menu exposes the watch entry point"): return

	if not assert_condition(menu.begin_watch(), "Begin the Watch changes scene successfully"): return
	await process_frame
	await process_frame
	var office := current_scene as M1OfficeController
	if not assert_condition(office != null, "Main menu lands in the production office scene"): return
	if not assert_condition(office.session_controller != null and office.shift_director != null, "Office startup wires session and shift director"): return
	if not assert_condition(office.shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT, "Office starts before the line is opened"): return
	if not assert_condition(world.snapshot().is_empty() and knowledge.snapshot().is_empty(), "Starting a watch clears prior world and knowledge facts"): return

	office.queue_free()
	print("--- Main Scene Smoke Test PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	print("  PASS: %s" % description)
	return true
