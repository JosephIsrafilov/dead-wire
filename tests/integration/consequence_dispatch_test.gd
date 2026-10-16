extends SceneTree
## The office routes consequence events to the right room response: the figure
## to the window observation target, the cloud shadow to the moon weather —
## and the cloud never becomes a figure. The Listener and its window event
## touch nothing physical (GDD §10); a cloud is light, not an object.
##   godot --headless --audio-driver Dummy --path . --script tests/integration/consequence_dispatch_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Consequence Dispatch Test Suite ---")
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

	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not _a(scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	await process_frame

	var moon := office.get_node_or_null("MoonWeather") as MoonWeather
	var figure := office.window_observation
	if not _a(moon != null, "The production office carries a MoonWeather node"): return
	if not _a(figure != null, "The production office carries the window observation target"): return
	var figure_events: Array[int] = []
	figure.event_started.connect(func() -> void: figure_events.append(1))

	# --- 1. A cloud shadow dims the moon and nothing else ---
	office._on_consequence_started("moon_cloud", 4.0)
	if not _a(moon.is_dimmed_now(), "The moon_cloud consequence puts a cloud across the moon"): return
	if not _a(not figure.is_active and figure_events.is_empty(),
		"A cloud is not the figure: the window event never starts"): return
	var indicator := figure.get_visual_indicator()
	if not _a(indicator == null or not indicator.visible,
		"A cloud shows nothing standing in the window"): return

	# The dim is real light: the moon's energy falls, then recovers after the
	# authored hold — a cloud passes, it does not switch the night off.
	moon.advance(2.0)
	var dimmed_energy := moon.moon_light.light_energy if moon.moon_light != null else -1.0
	if not _a(moon.moon_light == null or dimmed_energy < moon.get_rest_energy(),
		"The cloud actually dims the moonlight, got %.3f of %.3f" % [dimmed_energy, moon.get_rest_energy()]): return
	moon.advance(2.1)
	if not _a(not moon.is_dimmed_now(), "The cloud lifts after its authored hold"): return
	moon.advance(moon.dim_fade_seconds + 1.0)
	if not _a(moon.moon_light == null \
			or is_equal_approx(moon.moon_light.light_energy, moon.get_rest_energy()),
		"The moonlight returns to rest after the cloud, got %.3f" % moon.moon_light.light_energy): return

	# --- 2. The figure path is untouched ---
	office._on_consequence_started("window_figure", 4.0)
	if not _a(figure.is_active and figure_events.size() == 1,
		"The window_figure consequence still starts the window event"): return
	figure.reset_state()

	office.queue_free()
	await process_frame
	await process_frame
	print("--- All Consequence Dispatch Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
