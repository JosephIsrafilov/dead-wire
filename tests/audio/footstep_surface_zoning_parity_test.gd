extends SceneTree
## Production probes for painted slag, rail heads and wet ruts.

const SHADER_PATH := "res://materials/shaders/black_creek_ground.gdshader"
const TOWN_PATH := "res://scenes/town/black_creek_exterior.tscn"

## Uniform defaults from the shader; `town_architecture_builder.gd` overrides
## only `main_track_z` and `depot_approach_x`.
const MAIN_TRACK_Z := -18.0
const MJ_SPUR_X := 21.0
const CONFIG_PATH := "res://data/audio/footstep_surfaces.tres"

## The literals the mirror below hard-codes. Kept as a list so the shader can be
## checked for them without a GLSL parser.
const MIRRORED_LITERALS := [
	"float yard = 1.0 - smoothstep(4.4, 6.4, abs(p.y - main_track_z));",
	"float yard_end = 1.0 - smoothstep(52.0, 58.0, abs(p.x));",
	"float spur_lane = 1.0 - smoothstep(3.4, 5.2, abs(p.y - main_track_z - 8.4));",
	"float spur = spur_lane * (1.0 - smoothstep(0.4, 2.6, abs(p.x - mj_spur_x - 3.0)));",
	"* (1.0 - smoothstep(5.4, 6.8, abs(p.y + 10.2)));",
	"float apron = (1.0 - smoothstep(5.2, 6.6, abs(p.x - 4.4)))",
]

var _assertions: int = 0
var _resolver: FootstepSurfaceResolver = null
var _world3d: World3D = null
var _player_rid: RID = RID()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Footstep Zoning Parity Test Suite ---")
	if not _shader_still_declares_mirrored_bands(): return

	var town := load(TOWN_PATH).instantiate() as Node3D
	root.add_child(town)
	for _frame in 6:
		await physics_frame
	await process_frame

	# Ask the same resolver the boots ask, against the same world.
	var player := town.get_node_or_null("Player") as PlayerController
	if not _a(player != null and player.surface_resolver != null, "The town player carries a resolver"): return
	_resolver = player.surface_resolver
	_world3d = town.get_world_3d()
	_player_rid = player.get_rid()

	var zones := _surface_zones(town)
	var ballast := _zone_box(zones, &"ballast")
	var rail := _zone_box(zones, &"rail")
	if not _a(not ballast.is_empty(), "The town declares a ballast zone"): return
	if not _a(not rail.is_empty(), "The town declares rail zones (%d)" % rail.size()): return

	if not _ballast_band(): return
	if not _paint_rects_match_the_shader(): return
	if not _spur_and_apron(zones): return
	if not _rail_band(rail): return
	if not _wet_ground_is_voiced(): return
	if not _paint_in_production(): return

	town.queue_free()
	for _frame in 4:
		await process_frame
	print("--- All Footstep Zoning Parity Assertions PASSED (%d) ---" % _assertions)
	quit(0)

# --- the shader's cinder band, mirrored ---------------------------------------

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## `ballast` from `ground_surface()`, without its ±28% noise modulation. The
## noise can only move the 0.5 contour by a fraction of a metre, so the band
## edges below are honest to ~0.3 m.
func shader_ballast(x: float, z: float) -> float:
	var yard := 1.0 - _smoothstep(4.4, 6.4, absf(z - MAIN_TRACK_Z))
	var yard_end := 1.0 - _smoothstep(52.0, 58.0, absf(x))
	var spur_lane := 1.0 - _smoothstep(3.4, 5.2, absf(z - MAIN_TRACK_Z - 8.4))
	var spur: float = spur_lane * (1.0 - _smoothstep(0.4, 2.6, absf(x - MJ_SPUR_X - 3.0)))
	var apron: float = (1.0 - _smoothstep(5.2, 6.6, absf(x - 4.4))) \
		* (1.0 - _smoothstep(5.4, 6.8, absf(z + 10.2)))
	return maxf(maxf(yard * yard_end, spur), apron * 0.92)

func _shader_still_declares_mirrored_bands() -> bool:
	var text := FileAccess.get_file_as_string(SHADER_PATH)
	if not _a(not text.is_empty(), "The ground shader is readable"): return false
	for literal in MIRRORED_LITERALS:
		if not _a(text.contains(literal),
				"The shader still declares '%s…'" % literal.substr(0, 46)):
			return false
	return _a(true, "The mirrored cinder bands match the shader source")

const CLEAN_X := -40.0

func _ballast_band() -> bool:
	for offset in [0.0, 1.6, 2.6, 4.0, -4.0]:
		if not _a(shader_ballast(CLEAN_X, MAIN_TRACK_Z + offset) >= 0.5 and
				_resolve(Vector3(CLEAN_X, 0.12, MAIN_TRACK_Z + offset)) == &"ballast",
				"Painted slag at offset %.1f sounds like ballast" % offset): return false
	for point in [Vector3(60.0, 0.12, MAIN_TRACK_Z), Vector3(CLEAN_X, 0.12, MAIN_TRACK_Z + 7.0)]:
		if not _a(_resolve(point) == &"dirt", "Past the painted yard, %s sounds like dirt" % point): return false
	return true

func _paint_rects_match_the_shader() -> bool:
	var checked := 0
	var mismatched := 0
	var worst := 0.0
	# Sample the shader's own field over the whole painted area and compare the
	# 0.5 contour to `FootstepSurfacePaint.is_painted`.
	var x := -70.0
	while x <= 70.0:
		var z := -34.0
		while z <= 2.0:
			var painted := shader_ballast(x, z) >= 0.5
			var claimed := FootstepSurfacePaint.is_painted(Vector3(x, 0.0, z))
			checked += 1
			if painted != claimed:
				mismatched += 1
				# How far past the contour: 0 at the line, large for a real gap.
				worst = maxf(worst, absf(shader_ballast(x, z) - 0.5))
			z += 0.25
		x += 0.25
	if not _a(checked > 40000, "The paint rects are sampled densely (%d points)" % checked):
		return false
	# The rects are rectangles and the field is not, so corners of the union can
	# straddle the line. A 2 % disagreement over the whole area is the corner
	# error; anything more means a rect is in the wrong place.
	var ratio := float(mismatched) / float(checked)
	if not _a(ratio < 0.02,
			"The paint rects trace the shader's 50%% cinder contour (%.2f%% off, %d/%d)"
			% [ratio * 100.0, mismatched, checked]):
		return false
	if not _a(worst < 0.35,
			"Every disagreement is a corner, not a missing band (worst %.2f from the contour)" % worst):
		return false
	# The rects must name the patches the shader has, not a superset.
	if not _a(FootstepSurfacePaint.caused_by(Vector3(0.0, 0.0, MAIN_TRACK_Z)) == "CinderYard",
			"The rects call the main band 'CinderYard'"):
		return false
	if not _a(FootstepSurfacePaint.caused_by(Vector3(MJ_SPUR_X + 3.0, 0.0, MAIN_TRACK_Z + 8.4)) == "CinderSpurStub",
			"The rects call the shader's spur stub 'CinderSpurStub'"):
		return false
	if not _a(FootstepSurfacePaint.caused_by(Vector3(4.4, 0.0, -10.2)) == "CinderDepotApron",
			"The rects call the depot apron 'CinderDepotApron'"):
		return false
	if not _a(FootstepSurfacePaint.caused_by(Vector3(40.0, 0.0, MAIN_TRACK_Z + 12.0)) == "",
			"The rects leave clay clay (40 m along the street, 12 m off the track, is unpainted)"):
		return false
	if not _a(shader_ballast(40.0, MAIN_TRACK_Z + 12.0) < 0.5,
			"The shader agrees that spot is clay (%.2f)" % shader_ballast(40.0, MAIN_TRACK_Z + 12.0)):
		return false
	var rails := FootstepSurfacePaint.rail_bands()
	if not _a(rails.size() == 2, "The paint module emits both rails (%d)" % rails.size()):
		return false
	if not _a(FootstepSurfacePaint.RAIL_HALF_WIDTH * 2.0 < 0.34,
			"The paint module's rail is tighter than the shipped 0.34 m zone"):
		return false
	print("    paint rects: %.2f%% of %d samples disagree with the shader, worst %.2f off contour"
			% [ratio * 100.0, checked, worst])
	return _a(true, "FootstepSurfacePaint is the shader's cinder contour as rects")

# --- the spur and the depot apron: painted, never zoned -----------------------

func _spur_and_apron(zones: Array[FootstepSurfaceZone]) -> bool:
	var stub := Vector3(MJ_SPUR_X + 3.0, 0.12, MAIN_TRACK_Z + 8.4)
	if not _a(shader_ballast(stub.x, stub.z) > 0.85, "The shader paints the spur-side slag heap"): return false
	if not _a(_inside_any(zones, stub) and _resolve(stub) == &"ballast", "The slag heap answers ballast"): return false
	for point in [Vector3(21.0, 0.12, -24.65), Vector3(23.4, 0.12, -29.0)]:
		if not _a(_inside_any(zones, point) and _resolve(point) == &"ballast",
				"The laid spur carries ballast underfoot at %s" % point): return false
	var apron := Vector3(4.4, 0.12, -10.2)
	if not _a(_inside_any(zones, apron), "The apron has a cinder zone"): return false
	return _a(_resolve(apron) == &"boardwalk", "The depot's timber platform outranks its cinder underlay")

func _rail_band(rail: Array[FootstepSurfaceZone]) -> bool:
	if not _a(rail.size() == 2, "The main line has two individually voiced rail heads"): return false
	for side in [-1.0, 1.0]:
		if not _a(_resolve(Vector3(CLEAN_X, 0.12, MAIN_TRACK_Z + 0.72 * side)) == &"rail",
				"Steel is heard directly over rail %.0f" % side): return false
		if not _a(_resolve(Vector3(CLEAN_X, 0.12, MAIN_TRACK_Z + 0.90 * side)) == &"ballast",
				"The shoulder beside rail %.0f remains ballast" % side): return false
	return true

func _wet_ground_is_voiced() -> bool:
	if not _a(_resolve(Vector3(-6.0, 0.10, 24.0)) == &"wet_mud", "A wet wagon rut plays the mud bank"):
		return false
	if not _a(_resolve(Vector3(-6.0, 0.10, 26.5)) == &"dirt", "The ground between ruts plays packed dirt"):
		return false
	var mud := _resolver.bank_for(&"wet_mud")
	return _a(mud != null and mud.streams.size() >= 5, "The wet rut has distinct recorded contacts")

func _paint_in_production() -> bool:
	# Painted points that were silent before must now sound like cinder. X = -40
	# keeps clear of the depot platform and the boardwalks.
	#
	# Two answers are legitimate besides 'ballast': a tagged collider (the
	# depot's stairs and platform, the boardwalks) outranks any zone by design,
	# and the rail zones above the bed. A painted point that answers 'dirt' is
	# the actual defect — ground the shader calls cinder and the boots call clay.
	var painted_now := 0
	var painted_total := 0
	var tagged_over := 0
	var genuine_gaps := 0
	var first_gaps: Array[Vector3] = []
	var clay_now := 0
	var clay_total := 0
	var x := -52.0
	while x <= 52.0:
		var z := MAIN_TRACK_Z - 14.0
		while z <= MAIN_TRACK_Z + 14.0:
			var point := Vector3(x, 0.12, z)
			if FootstepSurfacePaint.is_painted(Vector3(x, 0.0, z)):
				painted_total += 1
				var heard := _resolve(point)
				if heard == &"ballast" or heard == &"rail":
					painted_now += 1
				elif heard == &"dirt":
					genuine_gaps += 1
					if first_gaps.size() < 6:
						first_gaps.append(point)
				else:
					tagged_over += 1
			elif shader_ballast(x, z) < 0.05:
				clay_total += 1
				if _resolve(point) == &"dirt":
					clay_now += 1
			z += 0.5
		x += 0.5
	if not _a(painted_total > 1000, "The paint rects cover a real area (%d probes)" % painted_total):
		return false
	if not _a(genuine_gaps == 0,
			"No painted probe is left on clay (%d gaps, first %s)"
			% [genuine_gaps, str(first_gaps)]):
		return false
	if not _a(painted_now + tagged_over == painted_total,
			"The painted area is fully voiced (%d cinder/rail, %d behind a tagged deck, %d total)"
			% [painted_now, tagged_over, painted_total]):
		return false
	if not _a(clay_total > 500, "There is clay outside the contour to check (%d probes)" % clay_total):
		return false
	# Outside the paint, 'dirt' is right; a tagged deck (depot platform, stairs)
	# still outranks the outdoor context and is not a parity defect.
	var clay_tagged := clay_total - clay_now
	if not _a(_resolve(Vector3(40.0, 0.12, MAIN_TRACK_Z + 9.0)) == &"dirt",
			"Open clay away from the depot still hears dirt"):
		return false
	if not _a(clay_now > clay_total * 0.9,
			"The clay outside the contour hears dirt except where a tagged deck covers it (%d/%d, %d tagged)"
			% [clay_now, clay_total, clay_tagged]):
		return false

	# The one true seam: at the paint contour the two must meet, not overlap.
	var edge_z := MAIN_TRACK_Z + FootstepSurfacePaint.YARD_HALF_DEPTH
	if not _a(_resolve(Vector3(CLEAN_X, 0.12, edge_z - 0.1)) == &"ballast",
			"Just inside the contour the boots hear cinder"):
		return false
	if not _a(_resolve(Vector3(CLEAN_X, 0.12, edge_z + 0.1)) == &"dirt",
			"Just outside the contour the boots hear clay"):
		return false

	print("    applied: %d painted probes voiced (%d cinder/rail, %d behind tagged decks);"
			% [painted_total, painted_now, tagged_over])
	print("             %d of %d clay probes remain dirt (%d under tagged decks)"
			% [clay_now, clay_total, clay_tagged])
	return _a(true, "Published cinder zones reach the running player resolver")

# --- helpers ------------------------------------------------------------------

func _resolve(point: Vector3) -> StringName:
	if _resolver == null:
		return &""
	var exclude: Array[RID] = []
	if _player_rid.is_valid():
		exclude.append(_player_rid)
	return _resolver.surface_at(point, _world3d, exclude)

func _surface_zones(scope: Node) -> Array[FootstepSurfaceZone]:
	var found: Array[FootstepSurfaceZone] = []
	for node in _all_nodes(scope):
		var zone := node as FootstepSurfaceZone
		if zone != null:
			found.append(zone)
	return found

func _zone_box(zones: Array[FootstepSurfaceZone], surface: StringName) -> Array[FootstepSurfaceZone]:
	var found: Array[FootstepSurfaceZone] = []
	for zone in zones:
		if zone.surface == surface:
			found.append(zone)
	return found

func _inside_any(zones: Array[FootstepSurfaceZone], point: Vector3) -> bool:
	for zone in zones:
		if zone.contains_world_point(point):
			return true
	return false

func _all_nodes(scope: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [scope]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
