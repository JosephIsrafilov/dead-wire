extends SceneTree
## The night's three text channels stack: whisper above thought above prompt.
## None of them may overlap the others, or the player reads one text twice.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/text_channel_layout_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Text Channel Layout Test Suite ---")
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
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	var office := scene.instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	await process_frame

	var thought := (office.get_node("NightGuidance") as NightGuidanceController)._label
	var murmur := (office.get_node("MurmurCaption") as MurmurCaption)._label
	var prompt := office.player.get_node("InteractionUI/PromptLabel") as Label
	if not _a(thought != null and murmur != null and prompt != null,
		"Whisper, thought and prompt labels all resolve in the production scene"): return
	await process_frame

	var thought_rect := thought.get_global_rect()
	var murmur_rect := murmur.get_global_rect()
	var prompt_rect := prompt.get_global_rect()
	if not _a(not murmur_rect.intersects(thought_rect),
		"The whisper band sits clear of the thought band"): return
	if not _a(not thought_rect.intersects(prompt_rect),
		"The thought band sits clear of the prompt band"): return
	if not _a(not murmur_rect.intersects(prompt_rect),
		"The whisper band sits clear of the prompt band"): return
	if not _a(murmur_rect.position.y < thought_rect.position.y and thought_rect.position.y < prompt_rect.position.y,
		"The stack reads whisper above thought above prompt"): return

	office.queue_free()
	await process_frame
	await process_frame
	print("--- All Text Channel Layout Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
