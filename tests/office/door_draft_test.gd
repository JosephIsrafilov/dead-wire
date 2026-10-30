extends SceneTree

## Opening the south door moves the air, and the air moves the coat.
##
## The controller used to read `office_door.global_position`, but OfficeDoor is a
## plain Node: opening the door raised `Invalid access to property ...
## 'global_position'` and the handler aborted before the coat was ever touched.
## The same handler also passed `coat.global_position` as the impact point, and
## that is the world origin, because the coat's particles carry absolute room
## coordinates. Both halves of the link are pinned here, on the production
## scene, through the real door event rather than through a direct draft() call.
##
##   godot --headless --audio-driver Dummy --path . --script tests/office/door_draft_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Door Draft Test Suite ---")
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not _a(scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not _a(office != null, "Office instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame

	var coat := office.get_node_or_null("HangingCoat") as HangingCoat
	var door := office.office_door
	if not _a(coat != null and door != null, "Coat and door are both in the production office"): return
	# The solver is driven by hand so the assertion is about the draft, not
	# about how many frames the headless loop happened to give us.
	coat.set_process(false)
	for _i in 400:
		coat.step(1.0 / 60.0)

	# --- A closed door moves nothing ---
	var hem := coat.rings - 1
	var still_before := _hem_points(coat, hem)
	for _i in 30:
		coat.step(1.0 / 60.0)
	if not _a(_max_shift(still_before, _hem_points(coat, hem)) < 0.001,
			"A door that never opened leaves the coat hanging still"): return

	# --- The door opens: the cloth has to answer ---
	var hang := coat.get_hang_position()
	if not _a(hang.distance_to(Vector3(-0.35, 1.7, 2.2)) < 0.25,
			"The coat reports where it actually hangs (%s)" % str(hang.snapped(Vector3.ONE * 0.01))): return
	door.unlock()
	var before := _hem_points(coat, hem)
	door.open()
	if not _a(door.is_open, "The door opens"): return
	# Check the initial shove before the cloth swings back past its rest pose.
	coat.step(1.0 / 60.0)
	var kicked_mean := _mean(_hem_points(coat, hem))
	for _i in 39:
		coat.step(1.0 / 60.0)
	var after := _hem_points(coat, hem)
	var shift := _max_shift(before, after)
	if not _a(shift > 0.004, "Opening the door actually moves the coat (%.4f m)" % shift): return

	# --- And it moves AWAY from the opening, not into it ---
	var mean_before := _mean(before)
	if not _a(kicked_mean.x > mean_before.x + 0.001,
			"The hem is knocked away from the doorway, not toward it (dx %.4f)" % (kicked_mean.x - mean_before.x)): return

	# --- The door's own spatial anchor is a real place in the room ---
	var anchor: Vector3 = door.get_world_anchor()
	var doorway := (office.get_node("SouthDoor") as Node3D).global_position
	if not _a(anchor.distance_to(doorway) < 0.35,
			"The controller's world anchor sits at the doorway (%s vs %s)"
				% [str(anchor.snapped(Vector3.ONE * 0.01)), str(doorway.snapped(Vector3.ONE * 0.01))]): return
	if not _a(anchor.distance_to(Vector3.ZERO) > 0.5,
			"The anchor is the doorway, not the world origin"): return

	# --- A far-off door would not reach this coat at all ---
	if not _a(door.draft_attenuation(anchor) > 0.0 and door.draft_attenuation(anchor + Vector3(0.0, 0.0, 40.0)) == 0.0,
			"Air only carries as far as the room allows"): return

	# --- Opening it a second time is impossible, so no second shove ---
	for _i in 400:
		coat.step(1.0 / 60.0)
	var settled := _hem_points(coat, hem)
	door.open()
	for _i in 30:
		coat.step(1.0 / 60.0)
	if not _a(_max_shift(settled, _hem_points(coat, hem)) < 0.002,
			"An already-open door does not keep blowing on the coat"): return

	office.queue_free()
	await process_frame
	print("--- All Door Draft Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _hem_points(coat: HangingCoat, ring: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for c in coat.segments:
		points.append(coat.get_particle_position(ring, c))
	return points

func _max_shift(before: PackedVector3Array, after: PackedVector3Array) -> float:
	var worst := 0.0
	for i in mini(before.size(), after.size()):
		worst = maxf(worst, before[i].distance_to(after[i]))
	return worst

func _mean(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / float(maxi(points.size(), 1))

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
