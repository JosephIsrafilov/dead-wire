extends SceneTree
## Phase D exterior dressing contract.
##
## The screenshot-2 bugs were all "the artwork disagrees with the world": five
## posters floating at 3.75 m with nothing under them, a wanted bill standing
## perpendicular to the wall it was pasted on, two jail lights laid over solid
## stone, and four bank stones whose flat undersides hovered over the gravel.
## These assertions are the geometric claims that stop that class of bug, plus
## the phase gating that keeps the new life restrained.

const PROPS := "res://assets/models/town/roadside_props.glb"
const JAIL := "res://assets/models/town/stone_calaboose.glb"
const LIFE := preload("res://scripts/town/black_creek_street_life.gd")
## The creek bed and the east bank tops the boulders stand on.
const BED_TOP := -0.425
const BANK_TOP := 0.265
const PLATFORM := 0.30

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS: " + what)
	else:
		print("  FAIL: " + what)
		_fails += 1

## glTF splits duplicate node names ("FrontWest", "FrontWest2") and mangles the
## minus sign in "SlitBar-1.44"; match the stem and read the box instead.
func _boxes(node: Node) -> Dictionary:
	var out := {}
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		out[String(mi.name)] = (mi as MeshInstance3D).get_aabb()
	return out

func _run() -> void:
	var props := (load(PROPS) as PackedScene).instantiate() as Node3D
	root.add_child(props)
	var jail := (load(JAIL) as PackedScene).instantiate() as Node3D
	jail.position = Vector3(26.0, 0.0, 6.0)
	root.add_child(jail)
	await process_frame
	var boxes := _boxes(props)
	var jail_boxes := _boxes(jail)

	# --- screenshot 2a: no bill may hang in the air off a telegraph pole. ---
	var pole_bills: Array[String] = []
	for name in boxes:
		if name.begins_with("PolePoster"):
			pole_bills.append(name)
	_ok(pole_bills.is_empty(), "no PolePoster survives in roadside_props %s" % str(pole_bills))
	# The eye-height, pole-wrapped broadside in black_creek_telegraph_lines.gd is
	# the replacement; its own placement is asserted where it is built.

	# --- screenshot 2b: four angular boulders bedded on the bank, not floating. ---
	var boulders: Array[String] = []
	for name in boxes:
		if name.begins_with("CreekBoulder") and name.right(1).is_valid_int():
			boulders.append(name)
	boulders.sort()
	_ok(boulders.size() == 4, "four creek boulders (%d)" % boulders.size())
	for i in boulders.size():
		var name := boulders[i]
		var box: AABB = boxes[name]
		var ground := BANK_TOP if i == 3 else BED_TOP
		_ok(absf(box.position.y - ground) < 0.02,
			"%s is bedded on its ground (base %.3f vs %.3f)" % [name, box.position.y, ground])
		_ok(box.size.y > 0.35, "%s stands above the gravel (%.2f m)" % [name, box.size.y])
		var mesh := props.find_child(name, true, false) as MeshInstance3D
		if mesh == null:
			_ok(false, "%s has a mesh" % name)
			continue
		# A drum keeps one radius per ring; a chipped block does not.
		var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var radii := {}
		for v in verts:
			if v.y > 0.02:
				radii[snappedf(Vector2(v.x, v.z).length(), 0.01)] = true
		_ok(radii.size() >= 5, "%s is faceted, not a drum (%d radii)" % [name, radii.size()])
		_ok(box.size.x > 0.5 and box.size.z > 0.5, "%s reads at street distance" % name)

	# --- screenshot 2c: the wanted bill lies in the west wall, not across it. ---
	var poster: AABB = jail_boxes.get("WantedPoster", AABB(Vector3.INF, Vector3.ZERO))
	_ok(poster.size.x < 0.002, "WantedPoster is flat in X (%.4f)" % poster.size.x)
	# WestWall is centred at x -2.38 and 0.45 thick, so its outer face is -2.605.
	_ok(absf(poster.position.x - (-2.605)) < 0.06,
		"WantedPoster sits on the west wall face (x %.3f)" % poster.position.x)
	_ok(poster.end.z < 2.60 and poster.position.z > -2.60,
		"WantedPoster stays inside the wall's z span")
	var backing: AABB = jail_boxes.get("WantedBackingBoard", AABB(Vector3.INF, Vector3.ZERO))
	_ok(backing.size.x > 0.0 and backing.size.x < 0.06 and backing.size.z > poster.size.z,
		"the bill has a sawn backing board behind it")

	# --- screenshot 2d: the jail lights are apertures, not cards on stone. ---
	# The front wall spans x -2.58..2.58, is 0.45 thick at z 3.0, and is built
	# around a 1.72 m door bay plus a 0.30 x 0.80 light at |x| 1.44.
	var lining_ok := true
	var bar_ok := true
	var split_ok := true
	for x in [-1.44, 1.44]:
		var lining := _piece(jail_boxes, "SlitLining", x)
		if lining == null:
			lining_ok = false
		else:
			lining_ok = lining_ok \
				and lining.size.x <= 0.31 and lining.position.y >= 1.74 \
				and lining.position.z > 3.0
		var bar := _piece(jail_boxes, "SlitBar", x)
		if bar == null:
			bar_ok = false
		else:
			bar_ok = bar_ok and absf(bar.get_center().x - x) < 0.05 \
				and bar.size.y > 0.5 and bar.position.y > 1.5 and bar.position.z > 3.05
	_ok(lining_ok, "both lights carry a dark lining set back inside the opening")
	_ok(bar_ok, "one upright iron bar stands inside each light")
	# Nothing may span the door opening, and nothing may lie across a light.
	for name in jail_boxes:
		if not name.begins_with("Front"):
			continue
		var box: AABB = jail_boxes[name]
		if box.position.x < -0.80 and box.end.x > 0.80:
			split_ok = false
	_ok(split_ok, "no front-wall piece spans the oak door opening")

	# --- work props: each one rests on what it stands on. ---
	for pair in [["DepotCrateA", PLATFORM], ["DepotSack", PLATFORM],
			["QuenchTub", 0.0], ["StoreHogshead", 0.0], ["StoreCrate", 0.0],
			["TroughBucket", 0.0], ["CurryBrush", 0.0]]:
		var name := String(pair[0])
		if not boxes.has(name):
			_ok(false, "%s exists" % name)
			continue
		var box: AABB = boxes[name]
		_ok(absf(box.position.y - float(pair[1])) < 0.03,
			"%s rests on its support (base %.3f)" % [name, box.position.y])
	var crate_a: AABB = boxes.get("DepotCrateA", AABB(Vector3.INF, Vector3.ZERO))
	var crate_b: AABB = boxes.get("DepotCrateB", AABB(Vector3.INF, Vector3.ZERO))
	_ok(crate_b.position.y > crate_a.position.y and crate_b.position.y < crate_a.end.y + 0.05,
		"the second depot crate stacks on the first")
	var tub: AABB = boxes.get("QuenchTub", AABB(Vector3.INF, Vector3.ZERO))
	_ok(boxes.has("QuenchWater") and (boxes["QuenchWater"] as AABB).position.y > tub.position.y,
		"the quench tub holds water")

	# --- restrained life: phase gating, licensed clips, no free physics. ---
	var life := LIFE.new()
	life.name = "StreetLifeProbe"
	root.add_child(life)
	var host := Node3D.new()
	root.add_child(host)
	life.build(host, Node3D.new(), Vector3.ZERO, false)
	var mist: Array[MeshInstance3D] = []
	var wren: AudioStreamPlayer3D = null
	var creek: AudioStreamPlayer3D = null
	for child in life.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("CreekMist"):
			mist.append(child as MeshInstance3D)
		if child.name == "CottonwoodWren":
			wren = child as AudioStreamPlayer3D
		if child.name == "CreekReach":
			creek = child as AudioStreamPlayer3D
	_ok(mist.size() == 2, "two low mist sheets lie on the creek reach (%d)" % mist.size())
	_ok(creek != null and creek.stream != null and creek.bus == &"Ambience",
		"the creek reach has its own Ambience bed emitter")
	if wren != null:
		_ok(wren.stream != null and wren.bus == &"Ambience", "the wren rides the Ambience bus")
		_ok(wren.max_distance <= 70.0, "the wren is local, not global (%.0f m)" % wren.max_distance)
		_ok(wren.stream.get_length() < 3.0,
			"the wren plays one recorded call (%.2f s), not a music bed" % wren.stream.get_length())
	life.apply_preset(&"DAWN")
	var dawn := 0
	for sheet in mist:
		dawn += int(sheet.visible)
	_ok(dawn == 2, "the mist shows at DAWN (%d)" % dawn)
	life.apply_preset(&"DAY_CLEAR")
	var day := 0
	for sheet in mist:
		day += int(sheet.visible)
	_ok(day == 0, "the mist is gone by mid-morning (%d)" % day)
	_ok(wren == null or not wren.playing, "no bird call is left running under the day preset")
	life.free()
	host.free()
	props.queue_free()
	jail.queue_free()
	print("-- Phase D dressing: %d failure(s)" % _fails)
	quit(1 if _fails else 0)

func _piece(boxes: Dictionary, stem: String, x: float) -> AABB:
	var best: AABB = AABB()
	var found := false
	for name in boxes:
		if not name.begins_with(stem):
			continue
		var box: AABB = boxes[name]
		if absf(box.get_center().x - x) > 0.05:
			continue
		if not found or box.size.y > best.size.y:
			best = box
			found = true
	return best if found else AABB()
