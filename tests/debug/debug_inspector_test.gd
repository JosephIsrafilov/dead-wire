extends SceneTree

func _init() -> void:
	print("--- Starting Debug Inspector Test ---")
	
	# Instantiate autoloads if not present in root (e.g. during standalone --script)
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
		
	var knowledge: KnowledgeStateStore = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	
	# 1. Debug Inspector scene loads
	var inspector_scene: PackedScene = load("res://scenes/debug/debug_inspector.tscn")
	if not assert_condition(inspector_scene != null, "DebugInspector scene loads"): return
	
	var inspector: DebugInspector = inspector_scene.instantiate() as DebugInspector
	if not assert_condition(inspector != null, "DebugInspector instantiates"): return
	root.add_child(inspector)
	inspector._connect_signals()
	inspector._refresh_display()
	
	# 2. Inspector is hidden by default
	if not assert_condition(inspector.visible == false, "Inspector is hidden by default"): return
	
	# 3. Initial empty stores render as <EMPTY>
	var output: RichTextLabel = inspector.get_node("PanelContainer/MarginContainer/Output") as RichTextLabel
	if not assert_condition(output != null, "Output RichTextLabel found"): return
	
	var initial_text: String = output.text
	if not assert_condition(initial_text.contains("WORLDSTATE:\n<EMPTY>"), "Initial WorldState shows <EMPTY>"): return
	if not assert_condition(initial_text.contains("KNOWLEDGESTATE:\n<EMPTY>"), "Initial KnowledgeState shows <EMPTY>"): return
	if not assert_condition(initial_text.contains("CURRENT PHASE:\nM1 OFFICE PROTOTYPE"), "Shows CURRENT PHASE"): return
	if not assert_condition(initial_text.contains("MORSE STATE:\nNOT IMPLEMENTED"), "Shows MORSE STATE NOT IMPLEMENTED"): return
	
	# 4. WorldState fact appears in WORLDSTATE section
	world.set_fact(&"alpha_fact", true)
	world.set_fact(&"beta_fact", 42)
	inspector._refresh_display()
	
	var text_after_world: String = output.text
	if not assert_condition(text_after_world.contains("alpha_fact = true"), "WorldState fact alpha_fact appears"): return
	if not assert_condition(text_after_world.contains("beta_fact = 42"), "WorldState fact beta_fact appears"): return
	
	# 5. This fact does not appear as KnowledgeState knowledge
	if not assert_condition(text_after_world.contains("KNOWLEDGESTATE:\n<EMPTY>"), "KnowledgeState remains <EMPTY> after WorldState mutation"): return
	if not assert_condition(not text_after_world.contains("KNOWLEDGESTATE:\nalpha_fact"), "KnowledgeState does not contain alpha_fact"): return
	
	# 6. After KnowledgeState.learn(), fact appears in KNOWLEDGESTATE section
	knowledge.learn(&"alpha_fact")
	inspector._refresh_display()
	var text_after_know: String = output.text
	if not assert_condition(text_after_know.contains("KNOWLEDGESTATE:\nalpha_fact"), "KnowledgeState contains alpha_fact after learn"): return
	
	# 7. Keys are displayed in stable sorted order
	world.set_fact(&"zebra_fact", "last")
	world.set_fact(&"middle_fact", "mid")
	knowledge.learn(&"zebra_know")
	knowledge.learn(&"beta_know")
	inspector._refresh_display()
	
	var sorted_text: String = output.text
	var alpha_pos = sorted_text.find("alpha_fact")
	var beta_pos = sorted_text.find("beta_fact")
	var mid_pos = sorted_text.find("middle_fact")
	var zebra_pos = sorted_text.find("zebra_fact")
	if not assert_condition(alpha_pos < beta_pos and beta_pos < mid_pos and mid_pos < zebra_pos, "WorldState keys are sorted in alphabetical order"): return
	
	var beta_k_pos = sorted_text.find("beta_know")
	var zebra_k_pos = sorted_text.find("zebra_know")
	if not assert_condition(beta_k_pos < zebra_k_pos, "KnowledgeState keys are sorted in alphabetical order"): return
	
	# 8. F3 toggles inspector visible
	var f3_event: InputEventKey = InputEventKey.new()
	f3_event.physical_keycode = KEY_F3
	f3_event.pressed = true
	f3_event.echo = false
	
	inspector._input(f3_event)
	if not assert_condition(inspector.visible == true, "F3 press shows inspector"): return
	
	# 9. Repeated F3 hides inspector
	inspector._input(f3_event)
	if not assert_condition(inspector.visible == false, "Second F3 press hides inspector"): return
	
	# 10. Keyboard echo does not toggle visibility
	var echo_event: InputEventKey = InputEventKey.new()
	echo_event.physical_keycode = KEY_F3
	echo_event.pressed = true
	echo_event.echo = true
	
	inspector.visible = false
	inspector._input(echo_event)
	if not assert_condition(inspector.visible == false, "Keyboard echo does not toggle visibility"): return
	
	# 11. Inspector does not change mouse mode
	var initial_mouse_mode = Input.mouse_mode
	inspector.visible = true
	inspector._refresh_display()
	if not assert_condition(Input.mouse_mode == initial_mouse_mode, "Inspector does not modify mouse mode"): return
	
	# 12. Inspector does not modify state itself
	if not assert_condition(world.get_fact(&"alpha_fact") == true, "Inspector does not mutate WorldState"): return
	if not assert_condition(knowledge.knows(&"alpha_fact") == true, "Inspector does not mutate KnowledgeState"): return
	
	# 13. State cleanup after test
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	inspector._refresh_display()
	if not assert_condition(world.snapshot().is_empty(), "WorldState cleared after test"): return
	if not assert_condition(knowledge.snapshot().is_empty(), "KnowledgeState cleared after test"): return
	if not assert_condition(output.text.contains("WORLDSTATE:\n<EMPTY>"), "Inspector reflects cleared WorldState"): return
	if not assert_condition(output.text.contains("KNOWLEDGESTATE:\n<EMPTY>"), "Inspector reflects cleared KnowledgeState"): return
	
	inspector.queue_free()
	world.queue_free()
	knowledge.queue_free()
	
	print("--- All Debug Inspector Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
