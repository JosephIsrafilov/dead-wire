extends SceneTree
## The playable churchyard is on a low shelf and its toll remains attached
## to the bronze bell. See chapel_access_test.gd for the continuous walk.

const TOWN := "res://scenes/town/black_creek_exterior.tscn"
const CHAPEL := TownArchitectureBuilder.CHAPEL_ORIGIN

## Pieces that must reach the surface they stand on. Matched by base name because
## Godot appends an index to duplicated glTF node names ("Picket", "Picket2").
const GROUNDED := [
	"Churchyard forecourt", "Churchyard walk west", "Churchyard walk east",
	"Churchyard walk south", "Gate threshold", "Grave plot", "Grave earth",
	"Headstone plinth", "GraveCross foot", "Fence post", "Picket",
	"Gate post", "Masonry footing", "Post footing", "Entry plinth",
	"Threshold step", "Threshold landing", "Plinth cheek",
]

## Pieces that sit on another piece or legitimately in the air; not judged against
## the bench surface. Plot borders are here because a kerb *stands proud* of the
## sunken plot it frames, so its underside is legitimately above the bench; the
## vertex-level generator audit (`.dream-loop/phaseC_found_check.py`) is what proves
## those kerbs are bedded, and it reports zero floating pieces.
const NOT_JUDGED := [
	"Revetment ", "Path ", "Path fill", "Landing ", "Paving joint", "Walk joint",
	"Capstone joint", "Plinth joint", "Lapped clapboard", "Fence rail",
	"Post cap", "Gate post cap", "Gate leaf", "Headstone", "Incised ",
	"GraveCross ", "Plot border", "Porch ", "Entry canopy", "Corner casing",
	"Eave fascia", "Gable bargeboard", "Overhanging shingle roof",
	"Weatherboard gables", "Belfry ", "Bell ", "Clapper ", "Shingled steeple",
	"Cross ", "Lancet ", "Milled lancet casing", "Recessed lancet panel",
	"Raised door stile", "Door lock plate", "Weatherboard apron",
]

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS: " + what)
	else:
		print("  FAIL: " + what)
		_fails += 1

## glTF duplicates arrive as "Picket2" or "Milled lancet casing17"; compare the stem.
func _base(node_name: String) -> String:
	return node_name.rstrip("0123456789")

func _matches(node_name: String, options: Array) -> bool:
	var base := _base(node_name)
	for opt in options:
		if base.begins_with(String(opt)):
			return true
	return false

func _run() -> void:
	await _built_chapel()
	print("chapel contract: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(0 if _fails == 0 else 1)

## Load the production town so the model is the real instanced one, then check the
## pieces against the bench and the bell against the mesh.
func _built_chapel() -> void:
	print("== built chapel ==")
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.reset_for_new_game()
	var scene := (load(TOWN) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for i in 6:
		await process_frame
	var chapel := scene.get_node_or_null(
		"TownArchitectureBuilder/HillsideBackdrop/chapel_steeple") as Node3D
	if chapel == null:
		chapel = scene.find_child("chapel_steeple", true, false) as Node3D
	_ok(chapel != null, "chapel_steeple is instanced in the production town")
	if chapel == null:
		scene.queue_free()
		await process_frame
		return

	var origin: Vector3 = chapel.global_position
	_ok(origin.distance_to(CHAPEL) < 0.01,
		"chapel origin is %.2f,%.2f,%.2f" % [origin.x, origin.y, origin.z])

	# Grounded pieces are measured against the surface they must rest on: paving in
	# the fenced yard, the bare bench for grave plots (earth, not stone), the bench
	# for the fence and gate.
	var yard := chapel.get_node_or_null("ChurchyardGround") as StaticBody3D
	_ok(yard != null, "the churchyard has a walkable stone and earth shelf")
	var bench: float = CHAPEL.y - 0.065
	var pave: float = bench + 0.058
	var floats: Array[String] = []
	var unknown: Array[String] = []
	var judged := 0
	for node in chapel.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var piece := String(mi.name)
		if _matches(piece, NOT_JUDGED):
			continue
		if not _matches(piece, GROUNDED):
			unknown.append(piece)
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var base := _base(piece)
		var support := bench
		if base.begins_with("Churchyard") or base.begins_with("Gate threshold") \
				or base.begins_with("Entry plinth") or base.begins_with("Threshold"):
			support = pave
		judged += 1
		if box.position.y > support + 0.012:
			floats.append("%s +%.3f" % [piece, box.position.y - support])
	_ok(judged >= 45, "judged %d grounded pieces against the bench" % judged)
	_ok(unknown.is_empty(), "every mesh piece is classified %s" % str(unknown))
	_ok(floats.is_empty(), "nothing floats above its surface %s" % str(floats))

	# Bell: emitter must sit inside the bronze body, in the street-facing bay.
	var bell := chapel.get_node_or_null("ChapelBell") as AudioStreamPlayer3D
	_ok(bell != null, "ChapelBell AudioStreamPlayer3D exists")
	if bell != null:
		_ok(bell.stream != null, "ChapelBell has a stream assigned")
		_ok(bell.bus == &"Ambience", "ChapelBell plays on the Ambience bus")
		var local: Vector3 = bell.position
		_ok(local.distance_to(Vector3(0, 8.10, -3.10)) < 0.01,
			"ChapelBell at local %.2f,%.2f,%.2f" % [local.x, local.y, local.z])
		_ok(local.y > 7.30 and local.y < 8.52 and local.z > -3.54 and local.z < -2.66,
			"ChapelBell emitter is inside the bronze body")
		_ok(local.z < -2.0, "ChapelBell is in the north (street-facing) bay")
		_ok(bell.max_distance >= 150.0,
			"ChapelBell carries %d m to the street" % int(bell.max_distance))
		var toll: float = bell.stream.get_length()
		_ok(toll > 1.2 and toll < 4.0, "ChapelBell toll is %.2f s" % toll)
		_ok(bell.is_in_group(&"town_chapel_bell"), "ChapelBell joins town_chapel_bell")

	# The catalogue's interaction anchor must equal origin + local emitter, so the
	# parent's interaction wiring cannot point at a stale belfry position.
	var text := FileAccess.get_file_as_string("res://assets/models/town/phase4_asset_catalog.json")
	var anchor_ok := false
	if not text.is_empty():
		var data = JSON.parse_string(text)
		if data is Dictionary and data.has("assets"):
			for entry in data["assets"]:
				if String(entry.get("name", "")) != "chapel_steeple":
					continue
				var inter: Dictionary = entry.get("interaction", {})
				var pt: Array = inter.get("world_point", [])
				if pt.size() == 3:
					var want: Vector3 = CHAPEL + Vector3(0, 8.10, -3.10)
					anchor_ok = absf(float(pt[0]) - want.x) < 0.01 \
						and absf(float(pt[1]) - want.y) < 0.01 \
						and absf(float(pt[2]) - want.z) < 0.01
	_ok(anchor_ok, "catalogue bell anchor == origin + local emitter")

	# Timing: once at dusk, once on the daylight noon beat, never at golden hour.
	var tod := scene.get_node_or_null("TownTimeOfDay") as TownTimeOfDay
	var builder := scene.get_node_or_null("TownArchitectureBuilder") as TownArchitectureBuilder
	_ok(tod != null and builder != null, "TownTimeOfDay and builder are present")
	if tod != null and builder != null:
		tod.apply_preset(TownTimeOfDay.PRESET_DUSK, builder)
		_ok(tod.get("_bell_rung_in") == TownTimeOfDay.PRESET_DUSK, "bell rings on DUSK")
		tod.apply_preset(TownTimeOfDay.PRESET_DAY_GOLDEN, builder)
		_ok(tod.get("_bell_rung_in") == TownTimeOfDay.PRESET_DUSK,
			"bell does not re-ring at golden hour")
		tod.apply_preset(TownTimeOfDay.PRESET_DAY_CLEAR, builder)
		_ok(tod.get("_bell_rung_in") == TownTimeOfDay.PRESET_DAY_CLEAR,
			"bell rings on the daylight noon beat")

	scene.queue_free()
	await process_frame
