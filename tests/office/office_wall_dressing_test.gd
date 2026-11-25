extends SceneTree
## Roadmap 0.2: the old west-wall wire tail and the soot of a lamp that no longer
## hangs there are gone, and everything the office actually uses is still there.
##
## What was orphaned: AuthoredWireRun strung the line along the west wall
## (x = 2.82, z = 0.31 .. 1.74) behind the desk's OLD position; LineDropA/B and
## LineLeadIn dropped it to a lead-in block that is now 1.1 m away from the desk
## in the north bay; LampSmoke was soot on a wall with no lamp on it.
##
## What must survive: the authored wall fittings, the owner's own in-flight
## changes (the Denver crate stencil, the clock, the joinery), the desk's lead
## block in the north bay, and the wear patches other tests read.
##   godot --headless --audio-driver Dummy --path . --script tests/office/office_wall_dressing_test.gd

const OFFICE_SCENE := "res://scenes/office/m1_office.tscn"
const WEAR_SCENE := "res://scenes/office/office_wear.tscn"
const PROPS_SCENE := "res://scenes/style_tests/props/office_storytelling_props.tscn"

## The old west-wall line, by name. None of these may exist as nodes any more:
## hiding them would keep the dead geometry in the file for the next reader.
const REMOVED_NODES := ["LineDropA", "LineDropB", "LineLeadIn", "AuthoredWireRun"]

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> bool:
	if ok:
		print("  PASS: " + description)
		_passed += 1
	else:
		print("  FAIL: " + description)
		_failed += 1
	return ok

func _find_named(root: Node, node_name: String) -> Array[Node]:
	var hits: Array[Node] = []
	if String(root.name) == node_name:
		hits.append(root)
	for child in root.get_children():
		hits.append_array(_find_named(child, node_name))
	return hits

func _run() -> void:
	var office_scene := load(OFFICE_SCENE) as PackedScene
	if not _check(office_scene != null, "The M1 office scene loads"):
		return _finish()
	var office := office_scene.instantiate()
	root.add_child(office)
	await process_frame

	# 1. The old west-wall line is gone outright, not merely hidden.
	for node_name in REMOVED_NODES:
		var hits := _find_named(office, node_name)
		_check(hits.is_empty(), "%s no longer exists in the office" % node_name)

	# 2. Nothing of the old run is left strung on the west wall: no node anywhere
	#    under the office still draws the authored wire-run mesh, and no thin
	#    wire-shaped strip hangs on the west wall at picture-rail height.
	var wire_mesh_users := _mesh_users(office, "wire_run_static")
	_check(wire_mesh_users.is_empty(),
		"No node in the office still draws the west-wall wire run (%s)" % str(wire_mesh_users))
	var west_wire := _west_wall_wires(office)
	_check(west_wire.is_empty(),
		"No wire-shaped strip hangs on the west wall above the desk line (%s)" % str(west_wire))

	# 3. The old soot is gone from the wear layer, and so is its texture.
	var wear := load(WEAR_SCENE) as PackedScene
	if _check(wear != null, "The office wear layer loads"):
		var wear_root := wear.instantiate()
		var smoke := _find_named(wear_root, "LampSmoke")
		_check(smoke.is_empty(), "LampSmoke soot is gone from the wear layer")
		_check(not FileAccess.get_file_as_string(WEAR_SCENE).contains("lamp_smoke.png"),
			"The wear layer no longer carries the lamp-smoke texture")
		# The wear patches that are still wanted, and that a test reads by path.
		for kept in ["SillRunoff", "StoveSoot", "WallpaperRepair"]:
			_check(_find_named(wear_root, kept).size() == 1, "%s stays in the wear layer" % kept)
		wear_root.free()

	# 4. The authored wall fittings and the owner's in-flight changes survive.
	var props := _find_named(office, "OfficeStorytellingProps")
	if _check(props.size() == 1, "OfficeStorytellingProps is still instanced once"):
		var wall_props := props[0].get_node_or_null("AuthoredWallProps") as MeshInstance3D
		_check(wall_props != null and wall_props.mesh != null,
			"The authored wall fittings (coat rack, hatch, tray) are untouched")
		_check(props[0].get_node_or_null("DenverCrateStencil") != null,
			"The owner's Denver crate stencil is preserved")
		var clock_case := props[0].get_node_or_null("AuthoredClockCase") as MeshInstance3D
		var clock_face := props[0].get_node_or_null("StationClockFace") as CSGCylinder3D
		_check(clock_case != null and clock_face != null and clock_face.visible,
			"The regulator clock keeps its case, bezel and driven face")
		_check(props[0].get_node_or_null("FilingDeskSconceBack") != null,
			"The filing desk sconce the door test measures is preserved")
		_check(props[0].get_node_or_null("RoutingBoardSconceBack") != null,
			"The routing board sconce is preserved")

	# 5. The working lead block on the desk in the north bay is preserved.
	var desk := _find_named(office, "DeskSetup")
	if _check(desk.size() == 1, "The operator's desk is still in the scene"):
		var lead := desk[0].get_node_or_null("WireLeadBlock") as CSGBox3D
		_check(lead != null,
			"The desk's wire lead block survives: the entry point for the new line")
		var station := _find_named(office, "TelegraphStation")
		_check(station.size() == 1, "The instruments are still on the desk")
		var authored_desk := desk[0].get_node_or_null("AuthoredDesk") as MeshInstance3D
		_check(authored_desk != null and authored_desk.mesh != null,
			"The authored desk mesh (its own lead block and pens) is untouched")

	# 6. The owner's other in-flight structure is untouched.
	for kept_node in ["OfficeJoinery", "WindowFigureStaging", "NorthWindow"]:
		_check(_find_named(office, kept_node).size() >= 1, "%s is preserved" % kept_node)

	office.queue_free()
	await process_frame
	_finish()

## Any node still drawing the given authored mesh, by resource file name.
func _mesh_users(node: Node, mesh_file: String) -> Array[String]:
	var found: Array[String] = []
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var path := mesh_instance.mesh.resource_path
		if path.get_file().begins_with(mesh_file):
			found.append(String(mesh_instance.name))
	for child in node.get_children():
		found.append_array(_mesh_users(child, mesh_file))
	return found

## A wire reads as a hairline strip: two dimensions under 2 cm, one over 40 cm,
## hung on the west wall at picture-rail height. The routing board's own hanger
## rods live on that same plane and are a working mechanism, so that subtree is
## skipped; CSG AABBs include their children's unions, so only leaf
## MeshInstances and CSGBox3Ds are measured.
func _west_wall_wires(node: Node) -> Array[String]:
	var found: Array[String] = []
	if String(node.name) == "RoutingBoard":
		return found
	if node is CSGBox3D or (node is MeshInstance3D and not node.get_children().any(
			func(child: Node) -> bool: return child is VisualInstance3D)):
		var visual := node as VisualInstance3D
		if visual.is_visible_in_tree():
			var world: AABB = (node as Node3D).global_transform * visual.get_aabb()
			var dims: Array[float] = [world.size.x, world.size.y, world.size.z]
			dims.sort()
			var on_west_plane: bool = world.position.x < -2.70 and absf(world.position.x) < 3.00
			var overhead: bool = world.position.y + world.size.y > 2.15
			if on_west_plane and overhead and dims[0] < 0.02 and dims[1] < 0.05 \
					and dims[2] > 0.40:
				found.append(String(node.name))
	for child in node.get_children():
		found.append_array(_west_wall_wires(child))
	return found

func _finish() -> void:
	print("Office wall dressing assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
