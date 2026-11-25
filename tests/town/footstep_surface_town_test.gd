extends SceneTree
## Phase B: the town's own geometry declares what a boot lands on.
##
## The resolver is unit-tested in tests/audio/footstep_surface_test.gd against
## tagged bodies built on the spot. This suite walks the real Black Creek scene
## and asks the same question at places the player actually stands: the street,
## the boardwalks, the creek bridge, the depot ramps, the ballast bed and the
## running rails. If a builder loses its tag, the boot silently returns to
## interior boards — that is the regression this catches.
##  godot --headless --audio-driver Dummy --path . --script tests/town/footstep_surface_town_test.gd

const EXPECTED_TAGS: Array[StringName] = [
	&"boardwalk", &"wood_bridge", &"stairs", &"ballast", &"rail",
]

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Town Footstep Surface Test Suite ---")
	var town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	root.add_child(town)
	for _frame in 6:
		await physics_frame
	await process_frame

	var player := town.get_node_or_null("Player") as PlayerController
	if not _a(player != null and player.surface_resolver != null, "The town player carries a resolver"): return
	var resolver := player.surface_resolver
	if not _a(not resolver.indoor, "Walking the street is an outdoor context"): return
	if not _a(resolver.context_default() == &"dirt", "The scene names ground as its default material"):
		return

	for surface in EXPECTED_TAGS:
		var count := 0
		for node in town.find_children("*", "", true, false):
			if node.is_in_group(StringName("surface_" + String(surface))):
				count += 1
		if not _a(count > 0, "The town tags '%s' geometry (%d nodes)" % [surface, count]): return

	var world := town.get_world_3d()
	var probes := [
		["street between the tracks and the walk", Vector3(-6.0, 0.10, 24.0), &"wet_mud"],
		["south boardwalk deck", Vector3(-2.0, 0.34, 32.0), &"boardwalk"],
		["north boardwalk deck", Vector3(14.0, 0.34, 14.0), &"boardwalk"],
		["creek bridge deck", Vector3(46.5, 0.43, 23.0), &"wood_bridge"],
		["depot apron ramp", Vector3(4.4, 0.25, -4.95), &"stairs"],
		["south walk riser", Vector3(-2.0, 0.10, 30.22), &"stairs"],
		["ballast between the rails", Vector3(-14.0, 0.12, -18.0), &"ballast"],
		["running rail head", Vector3(-14.0, 0.12, -18.72), &"rail"],
		["visible cinders beyond the sleepers", Vector3(-40.0, 0.05, -15.0), &"ballast"],
		["slag at the MJ gate", Vector3(21.0, 0.04, -24.65), &"ballast"],
	]
	for probe in probes:
		var label: String = probe[0]
		var point: Vector3 = probe[1]
		var expected: StringName = probe[2]
		var got := resolver.surface_at(point, world, [player.get_rid()])
		if not _a(got == expected, "%s answers '%s' (got '%s')" % [label, expected, got]): return

	# The bank the answer resolves to is the recorded one, not a fallback set.
	var bridge_bank := resolver.bank_for(&"wood_bridge")
	if not _a(bridge_bank != null and bridge_bank.is_playable(), "The bridge has a playable recorded bank"):
		return
	for stream in bridge_bank.streams:
		if not _a(stream != null and (stream as AudioStreamWAV) != null,
				"Every bridge voice is an importable one-shot"): return

	# Interior scenes get their own world: the street's bodies would otherwise be
	# hit first by the probe at the same coordinates.
	town.queue_free()
	for _frame in 4:
		await process_frame

	# The two interiors name their own floor: saloon pine, lodging-house boards.
	var interiors := [
		["res://scenes/town/interiors/copper_mule_saloon.tscn", &"wood_saloon"],
		["res://scenes/town/interiors/boarding_house_room.tscn", &"wood_office"],
	]
	for entry in interiors:
		var scene: Node3D = load(entry[0]).instantiate()
		root.add_child(scene)
		for _frame in 5:
			await physics_frame
		var inner := scene.get_node("Player") as PlayerController
		if not _a(inner.surface_resolver != null and inner.surface_resolver.indoor,
				"%s is an indoor context" % entry[0].get_file()): return
		var under := inner.surface_resolver.surface_at(inner.global_position, scene.get_world_3d(),
			[inner.get_rid()])
		if not _a(under == entry[1], "%s floorboards answer '%s' (got '%s')"
				% [entry[0].get_file(), entry[1], under]): return
		scene.queue_free()
		for _frame in 3:
			await process_frame

	print("--- All Town Footstep Surface Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
