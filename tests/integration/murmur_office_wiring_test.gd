extends SceneTree
## The whisper is really wired into the production office: a broken scene path
## must fail here, not silence the murmur unnoticed.
##   godot --headless --audio-driver Dummy --path . --script tests/integration/murmur_office_wiring_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Murmur Office Wiring Test Suite ---")
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

	var office_scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not _a(office_scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = office_scene.instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()

	var murmur := office.get_node_or_null("MurmurCaption") as MurmurCaption
	if not _a(murmur != null and murmur is MurmurCaption, "The production scene carries a MurmurCaption node"): return
	if not _a(murmur.session == office.session_controller,
		"The whisper's session export resolves to the office session controller"): return
	if not _a(office.session_controller.perception_glyph.is_connected(murmur._on_perception_glyph),
		"The whisper is subscribed to the session's perception signal"): return
	if not _a(murmur.layer < office.document_viewer.layer,
		"An open document draws over the whisper (layer %d under the viewer's %d)" % [murmur.layer, office.document_viewer.layer]): return

	office.queue_free()
	await process_frame
	await process_frame
	print("--- All Murmur Office Wiring Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
