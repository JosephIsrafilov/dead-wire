extends SceneTree
## Phase B: what the boot landed on decides what it sounds like.
##
##   - every surface bank is built from registered recorded one-shots, never
##     from a generated sine or noise sweep: real, audible, non-silent samples;
##   - the resolver answers in a fixed order: explicit override, tagged collider,
##     zone, then the scene's own context material;
##   - the player keeps its public contract (`footstep_played(index)`, 0..2) while
##     the stream comes from the bank of the material under the foot;
##   - no surface plays the same voice twice running.
##   godot --headless --audio-driver Dummy --path . --script tests/audio/footstep_surface_test.gd

const CONFIG_PATH := "res://data/audio/footstep_surfaces.tres"
const EXPECTED_SURFACES: Array[StringName] = [
	&"wood_office", &"wood_saloon", &"boardwalk", &"wood_bridge", &"stairs",
	&"carpet", &"wet_mud", &"dirt", &"ballast", &"rail", &"stone",
]

var _assertions: int = 0
var _world: Node3D = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Footstep Surface Test Suite ---")
	_world = Node3D.new()
	_world.name = "SurfaceWorld"
	root.add_child(_world)

	if not await _banks_are_audio(): return
	if not await _resolver_priorities(): return
	if not await _shuffle_bag(): return
	if not await _canonical_metadata(): return
	if not await _player_contract(): return

	_world.queue_free()
	for _frame in 4:
		await process_frame
	print("--- All Footstep Surface Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

# --- the banks ---------------------------------------------------------------

func _banks_are_audio() -> bool:
	var config := load(CONFIG_PATH) as FootstepSurfaceConfig
	if not _a(config != null, "The surface config loads (%s)" % CONFIG_PATH): return false
	if not _a(config.banks.size() == EXPECTED_SURFACES.size(),
			"The config declares all %d walkable materials" % EXPECTED_SURFACES.size()): return false
	for wanted in EXPECTED_SURFACES:
		if not _a(config.has_surface(wanted), "Material '%s' has a bank" % wanted): return false

	var total_samples := 0
	for bank in config.banks:
		if not _a(bank.streams.size() >= 3,
				"'%s' has at least three voices (%d)" % [bank.surface, bank.streams.size()]): return false
		for index in bank.streams.size():
			var stream := bank.streams[index]
			if not _a(stream != null, "'%s' voice %d is a real stream" % [bank.surface, index]): return false
			var wav := stream as AudioStreamWAV
			if not _a(wav != null, "'%s' voice %d is a WAV one-shot" % [bank.surface, index]):
				return false
			if not _a(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED,
					"'%s' voice %d is a one-shot, not a loop" % [bank.surface, index]): return false
			if not _a(wav.get_length() >= 0.08 and wav.get_length() <= 0.60,
					"'%s' voice %d is a single contact (%.2fs)" % [bank.surface, index, wav.get_length()]):
				return false
			# The payload itself must exist: an all-zero or unimported stream is
			# silence with a filename. The recorded character (crest, onset, no
			# pure tone) is measured against the source WAVs in
			# tools/footstep_surface_banks_test.py.
			if not _a(not wav.data.is_empty(),
					"'%s' voice %d carries audio data (%d bytes)" % [bank.surface, index, wav.data.size()]):
				return false
			total_samples += 1
		if not _a(bank.pitch_center > 0.9 and bank.pitch_center < 1.1,
				"'%s' stays near concert pitch" % bank.surface): return false
	if not _a(total_samples >= 35, "The banks hold %d recorded contacts" % total_samples): return false

	# The shuffle bag never repeats even at 3, but 5+ is where a walk stops
	# sounding like a loop. Every non-office bank is 3–4 voices today; report it
	# rather than fail, so topping a bank up is an improvement and not a break.
	var thin: Array[String] = []
	for bank in config.banks:
		if bank.streams.size() < 5:
			thin.append("%s(%d)" % [bank.surface, bank.streams.size()])
	print("  NOTE: %d/%d banks have fewer than 5 voices: %s"
			% [thin.size(), config.banks.size(), ", ".join(thin)])

	# One source per material: a single take reused for two surfaces would make
	# the deck and the bridge indistinguishable by ear.
	var first_voice: Dictionary = {}
	for bank in config.banks:
		var key := _stream_key(bank.streams[0])
		if not _a(not first_voice.has(key),
				"'%s' opens on its own recording, not '%s'" % [bank.surface, first_voice.get(key, "")]):
			return false
		first_voice[key] = bank.surface
	return _a(true, "Eleven materials, each with its own recorded voices")

# --- the resolver ------------------------------------------------------------

func _resolver_priorities() -> bool:
	var config := load(CONFIG_PATH) as FootstepSurfaceConfig
	var resolver := FootstepSurfaceResolver.new()
	resolver.config = config
	_world.add_child(resolver)
	await process_frame

	if not _a(resolver.get_current_surface() == &"wood_office", "Indoors, an untagged floor is the office boards"):
		return false
	resolver.set_indoor(false)
	if not _a(resolver.surface_at(Vector3.ZERO) == &"dirt", "Outdoors, an untagged patch is ground"):
		return false
	resolver.set_indoor(true)
	var boards := resolver.surface_at(Vector3.ZERO)
	if not _a(boards == &"wood_office", "Back indoors the boards return"): return false

	# 1. An explicit override wins over everything physical.
	resolver.set_override(&"carpet")
	if not _a(resolver.surface_at(Vector3.ZERO) == &"carpet", "An override outranks the floor"): return false
	resolver.clear_override()
	if not _a(resolver.surface_at(Vector3.ZERO) == &"wood_office", "Clearing the override restores the floor"):
		return false

	# 2. A tagged collider outranks the zone and the context.
	var stone := _floor_body(Vector3(-10.0, -0.25, 0.0), &"stone")
	var zone := _zone(Vector3(-10.0, 0.12, 0.0), &"wet_mud", 0)
	await _settle()
	var hit := resolver.resolve_at(Vector3(-10.0, 0.05, 0.0))
	if not _a(hit["surface"] == &"stone", "The tagged collider under the boot wins (got '%s')" % hit["surface"]):
		return false
	if not _a(hit["bank"] != null and hit["bank"].surface == &"stone", "The answer carries the matching bank"):
		return false

	# 3. With the collider untagged, the zone claims the patch.
	stone.remove_from_group(&"surface_stone")
	stone.remove_meta(&"footstep_surface")
	stone.remove_meta(&"surface")
	await _settle()
	if not _a(resolver.surface_at(Vector3(-10.0, 0.05, 0.0)) == &"wet_mud", "An untagged floor falls to the zone"):
		return false

	# 4. Tagged geometry still outranks a zone over it, even at higher priority.
	var carpet := _zone(Vector3(-10.0, 0.12, 0.0), &"carpet", 5)
	await _settle()
	if not _a(resolver.surface_at(Vector3(-10.0, 0.05, 0.0)) == &"carpet", "The higher-priority zone wins the tie"):
		return false
	FootstepSurfaceResolver.tag(stone, &"stone")
	await _settle()
	if not _a(resolver.surface_at(Vector3(-10.0, 0.05, 0.0)) == &"stone",
			"A tagged deck still outranks the carpet laid over it"): return false

	# 5. Outside every zone and tag, the scene context answers.
	zone.position = Vector3(-10.0, 0.12, 0.0)
	carpet.queue_free()
	stone.remove_from_group(&"surface_stone")
	stone.remove_meta(&"footstep_surface")
	stone.remove_meta(&"surface")
	await _settle()
	resolver.set_context_surface(&"wood_saloon")
	if not _a(resolver.surface_at(Vector3.ZERO) == &"wood_saloon", "A scene names its own floor material"):
		return false

	# 6. No voice repeats twice running on one surface.
	var bank := config.bank(&"boardwalk")
	var previous := -1
	var repeats := 0
	for _i in 24:
		var stream := resolver.next_stream(bank)
		if stream == null:
			_a(false, "A bank always yields a voice")
			return false
		var index := bank.streams.find(stream)
		if index == previous:
			repeats += 1
		previous = index
	if not _a(repeats == 0, "Walking a deck never repeats the same step twice running"): return false

	# 7. An unknown surface is never invented: it falls back to a real bank.
	var mystery := resolver.resolve_at(Vector3(500.0, 0.05, 500.0))
	if not _a(config.has_surface(mystery["surface"]), "A stray probe still answers with a real material"):
		return false

	resolver.queue_free()
	return true

# --- the shuffled bag ---------------------------------------------------------

func _shuffle_bag() -> bool:
	var config := load(CONFIG_PATH) as FootstepSurfaceConfig
	var resolver := FootstepSurfaceResolver.new()
	resolver.config = config
	_world.add_child(resolver)
	await process_frame

	# A bank of 3 is the weakest case the town actually has (deck, bridge,
	# stairs): a bag must give every voice once per three steps, and never open
	# a refilled bag on the voice that just played.
	var bank := config.bank(&"boardwalk")
	if not _a(bank.streams.size() == 3, "The deck bank is the three-voice case (%d)" % bank.streams.size()):
		return false
	var steps := 96
	var counts: Dictionary = {}
	var previous := -1
	var penultimate := -1
	var repeats := 0
	var windows := 0
	var perfect_windows := 0
	var run: Array[int] = []
	for _i in steps:
		var stream := resolver.next_stream(bank)
		if stream == null:
			_a(false, "A bag always yields a voice")
			return false
		var index := bank.streams.find(stream)
		if index < 0:
			_a(false, "A bag yields a voice that belongs to the bank")
			return false
		if index == previous or index == penultimate:
			repeats += 1
		penultimate = previous
		previous = index
		counts[index] = int(counts.get(index, 0)) + 1
		run.append(index)
		if run.size() == 3:
			windows += 1
			var uniq: Dictionary = {}
			for entry in run:
				uniq[entry] = true
			if uniq.size() == 3:
				perfect_windows += 1
			run.clear()
	if not _a(repeats == 0, "Ninety-six deck steps never repeat either previous voice (%d repeats)" % repeats):
		return false
	if not _a(perfect_windows == windows,
			"Every three-step window uses all three voices (%d/%d)" % [perfect_windows, windows]):
		return false
	if not _a(counts.size() == 3, "Every deck voice is heard (%d of 3)" % counts.size()):
		return false
	var spread := 0
	for index in counts:
		spread = maxi(spread, absi(int(counts[index]) - steps / 3))
	if not _a(spread <= 1, "The bag balances the voices within one step (worst skew %d)" % spread):
		return false

	# Across many refills, no seam may repeat — this is the bug the bag fixes.
	var seam_repeats := 0
	for _trial in 12:
		var fresh := FootstepSurfaceResolver.new()
		fresh.config = config
		fresh.set_physics_process(false)
		var last := -1
		for _i in 30:
			var index := fresh.config.bank(&"boardwalk").streams.find(fresh.next_stream(bank))
			if index == last:
				seam_repeats += 1
			last = index
		fresh.free()
	if not _a(seam_repeats == 0, "Ten bag refills in a row never repeat over a seam (%d)" % seam_repeats):
		return false

	# The bag is per surface: a deck's order must not be spent by the road.
	var deck := config.bank(&"boardwalk")
	var dirt := config.bank(&"dirt")
	var deck_seen: Array[int] = []
	for _i in 3:
		deck_seen.append(deck.streams.find(resolver.next_stream(deck)))
		resolver.next_stream(dirt)
	if not _a(deck_seen.size() == 3 and not deck_seen.has(-1), "Interleaved dirt steps leave the deck bag intact"):
		return false

	# Two voices can only alternate; one voice has to repeat. Both are honest.
	var pair := FootstepSurfaceBank.new()
	pair.surface = &"pair_probe"
	var pair_streams: Array[AudioStream] = [deck.streams[0], deck.streams[1]]
	pair.streams = pair_streams
	var solo_previous := -1
	var solo_repeats := 0
	for _i in 10:
		var index := pair.streams.find(resolver.next_stream(pair))
		if index == solo_previous:
			solo_repeats += 1
		solo_previous = index
	if not _a(solo_repeats == 0, "A two-voice bank alternates rather than repeating"):
		return false
	var solo := FootstepSurfaceBank.new()
	solo.surface = &"solo_probe"
	var solo_streams: Array[AudioStream] = [deck.streams[0]]
	solo.streams = solo_streams
	var exhausted := 0
	for _i in 3:
		if resolver.next_stream(solo) == solo.streams[0]:
			exhausted += 1
	if not _a(exhausted == 3, "A one-voice bank plays its only contact every step"):
		return false

	# A respawn starts a fresh walk rather than continuing the last life's order.
	resolver.reset_walk()
	var after_reset := deck.streams.find(resolver.next_stream(bank))
	if not _a(after_reset >= 0, "A reset walk still yields a real voice"):
		return false
	var repeats_after_reset := 0
	var last := after_reset
	for _i in 11:
		var index := deck.streams.find(resolver.next_stream(bank))
		if index == last:
			repeats_after_reset += 1
		last = index
	if not _a(repeats_after_reset == 0, "A reset walk restarts clean and still never repeats"):
		return false

	resolver.queue_free()
	return _a(true, "The shuffle bag never repeats a step across a refill")

# --- the canonical meta name --------------------------------------------------

func _canonical_metadata() -> bool:
	var config := load(CONFIG_PATH) as FootstepSurfaceConfig
	var resolver := FootstepSurfaceResolver.new()
	resolver.config = config
	_world.add_child(resolver)
	await process_frame

	if not _a(FootstepSurfaceResolver.TAG_META == &"footstep_surface",
			"The canonical meta is 'footstep_surface'"): return false

	# A scene file can carry the canonical key alone; that must be enough.
	var paved := _floor_body(Vector3(60.0, -0.25, 0.0), &"stone")
	FootstepSurfaceResolver.tag(paved, &"stone")
	if not _a(paved.has_meta(&"footstep_surface") and paved.has_meta(&"surface"),
			"tag() writes the canonical and legacy meta names"): return false
	paved.remove_from_group(&"surface_stone")
	paved.remove_meta(&"surface")
	await _settle()
	if not _a(resolver.surface_at(Vector3(60.0, 0.05, 0.0)) == &"stone",
			"A collider tagged only with 'footstep_surface' still answers"): return false

	# The legacy spelling keeps older scenes and hand-tagged props audible.
	var legacy := _floor_body(Vector3(66.0, -0.25, 0.0), &"stone")
	legacy.remove_from_group(&"surface_stone")
	legacy.remove_meta(&"footstep_surface")
	legacy.set_meta(&"surface", &"carpet")
	await _settle()
	if not _a(resolver.surface_at(Vector3(66.0, 0.05, 0.0)) == &"carpet",
			"A collider tagged only with legacy 'surface' still answers"): return false

	# Canonical wins when both are present and disagree.
	legacy.set_meta(&"footstep_surface", &"stone")
	await _settle()
	if not _a(resolver.surface_at(Vector3(66.0, 0.05, 0.0)) == &"stone",
			"The canonical meta outranks the legacy spelling"): return false

	# An ancestor's meta is inherited, either spelling, and a group still works.
	var parent := Node3D.new()
	parent.position = Vector3(72.0, -0.25, 0.0)
	_world.add_child(parent)
	var child := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.5, 6.0)
	shape.shape = box
	child.add_child(shape)
	parent.add_child(child)
	parent.set_meta(&"footstep_surface", &"wood_saloon")
	await _settle()
	if not _a(resolver.surface_at(Vector3(72.0, 0.05, 0.0)) == &"wood_saloon",
			"An ancestor's canonical meta is inherited by the collider"): return false

	# Priority ranks overlapping tagged colliders when the down-ray finds nothing
	# tagged: two thin slabs flanking the probe, both inside the fallback sphere,
	# so the ranking alone decides.
	var wall_low := _wall(Vector3(77.88, 0.30, 0.0), &"dirt")
	var wall_high := _wall(Vector3(78.12, 0.30, 0.0), &"stone")
	FootstepSurfaceResolver.set_priority(wall_low, 0)
	FootstepSurfaceResolver.set_priority(wall_high, 4)
	# The legacy key alone must still rank a collider (older scenes).
	wall_high.remove_meta(&"footstep_surface_priority")
	wall_high.set_meta(&"surface_priority", 4)
	await _settle()
	if not _a(resolver.surface_at(Vector3(78.0, 0.05, 0.0)) == &"stone",
			"Collider priority ranks overlapping bodies (legacy key read too)"): return false
	if not _a(FootstepSurfaceResolver.priority_of(wall_high) == 4, "priority_of reads the legacy key"):
		return false
	# Canonical priority wins when both keys are present: if the legacy 9 were
	# read, 'stone' would win; reading the canonical 1 lets the dirt slab win.
	FootstepSurfaceResolver.set_priority(wall_low, 5)
	wall_high.set_meta(&"footstep_surface_priority", 1)
	wall_high.set_meta(&"surface_priority", 9)
	await _settle()
	if not _a(resolver.surface_at(Vector3(78.0, 0.05, 0.0)) == &"dirt",
			"Canonical 'footstep_surface_priority' outranks the legacy key"): return false

	# The spelling that matters for scene files: a .tscn writes metadata as
	# `metadata/footstep_surface = &"stone"` with no alias. That must resolve
	# without any runtime tag() call, or a builder's work is silently lost.
	var hand := load("res://tests/audio/fixtures/hand_tagged_deck.tscn").instantiate() as StaticBody3D
	hand.position = Vector3(84.0, -0.25, 0.0)
	_world.add_child(hand)
	await _settle()
	if not _a(hand.has_meta(&"footstep_surface") and not hand.has_meta(&"surface"),
			"A .tscn can carry metadata/footstep_surface alone"): return false
	if not _a(FootstepSurfaceResolver.tag_of(hand) == &"stone",
			"tag_of reads a scene-file canonical meta (got '%s')" % FootstepSurfaceResolver.tag_of(hand)):
		return false
	if not _a(FootstepSurfaceResolver.priority_of(hand) == 3,
			"priority_of reads a scene-file canonical priority"): return false
	if not _a(resolver.surface_at(Vector3(84.0, 0.05, 0.0)) == &"stone",
			"A scene-file tagged deck answers from the probe"): return false
	hand.queue_free()
	await _settle()
	hand = null

	resolver.queue_free()
	return _a(true, "Canonical footstep_surface meta is accepted, legacy preserved")

# --- the player contract ------------------------------------------------------

func _player_contract() -> bool:
	MainMenu.clear_state()
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.set_physics_process(false)
	# The controller owns a resolver built from the shared config even when the
	# scene says nothing.
	if player.get_node_or_null("FootstepSurfaceResolver") != null:
		pass
	_world.add_child(player)
	player.global_position = Vector3(-30.0, 0.0, 0.0)
	player.reset_physics_interpolation()
	await _settle()

	if not _a(player.surface_resolver != null, "The player carries a surface resolver"): return false
	if not _a(player.surface_resolver.config != null, "The resolver is wired to the shared config"): return false

	var indices: Array[int] = []
	var streams: Array[AudioStream] = []
	var handler := func(index: int) -> void:
		indices.append(index)
		if player.footstep_player != null:
			streams.append(player.footstep_player.stream)
	player.footstep_played.connect(handler)
	for _i in 6:
		player._play_footstep()
	if not _a(indices.size() == 6, "Every step still announces itself through footstep_played (%d)" % indices.size()):
		return false
	if not _a(indices[0] == 0 and indices[1] == 1 and indices[2] == 2 and indices[3] == 0,
			"The step index keeps its 0,1,2 cycle for the creak boards"): return false
	if not _a(streams.all(func(s: AudioStream) -> bool: return s != null), "Each announced step has a stream"):
		return false

	# A tagged stone yard under the boots: the player must reach for that bank.
	var yard := _floor_body(Vector3(-30.0, -0.25, 0.0), &"stone")
	player.global_position = Vector3(-30.0, 0.0, 0.0)
	player.reset_physics_interpolation()
	await _settle()
	player.configure_footstep_surface(false)
	var stone_bank := player.surface_resolver.config.bank(&"stone")
	if not _a(stone_bank != null, "The stone bank is reachable from the player"): return false
	var played_stone := 0
	for _i in 8:
		player._play_footstep()
		if player.footstep_player.stream in stone_bank.streams:
			played_stone += 1
	if not _a(played_stone == 8, "Every step on the stone yard uses the recorded stone contacts (%d/8)" % played_stone):
		return false

	# Back on the untagged valley floor, the outdoor context returns.
	yard.remove_from_group(&"surface_stone")
	yard.remove_meta(&"footstep_surface")
	yard.remove_meta(&"surface")
	await _settle()
	if not _a(player.surface_resolver.surface_at(Vector3(-30.0, 0.05, 0.0)) == &"dirt",
			"An untagged yard outdoors is ground"): return false
	player._play_footstep()
	var dirt_bank := player.surface_resolver.config.bank(&"dirt")
	if not _a(player.footstep_player.stream in dirt_bank.streams, "The step now uses the recorded dirt contacts"):
		return false

	player.footstep_played.disconnect(handler)
	player.queue_free()
	return _a(true, "The player keeps footstep_played(index) and follows the ground")

# --- helpers -----------------------------------------------------------------

func _floor_body(at: Vector3, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.5, 6.0)
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	FootstepSurfaceResolver.tag(body, surface)
	return body

func _wall(at: Vector3, surface: StringName) -> StaticBody3D:
	## A thin upright slab the down-ray misses but the fallback sphere catches,
	## so only collider priority can decide between two of them.
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.06, 1.2, 1.2)
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	FootstepSurfaceResolver.tag(body, surface)
	return body

func _zone(at: Vector3, surface: StringName, priority: int) -> FootstepSurfaceZone:
	var zone := FootstepSurfaceZone.new()
	zone.surface = surface
	zone.zone_priority = priority
	zone.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.6, 4.0)
	shape.shape = box
	zone.add_child(shape)
	_world.add_child(zone)
	return zone

func _settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _stream_key(stream: AudioStream) -> String:
	return stream.resource_path if stream != null else ""

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
