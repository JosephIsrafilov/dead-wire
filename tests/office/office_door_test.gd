extends SceneTree

## The south door.
##
## The first thing the owner hit on playing the slice was walking through a shut
## door and falling out of the world: the prop had no collision at all and the
## south wall has a deliberate 1 m doorway gap. These assertions exist so that
## can never come back silently.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Office Door Test Suite ---")

	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame

	var door_node := office.get_node_or_null("SouthDoor") as Node3D
	if not assert_condition(door_node != null, "South door is in the scene"): return

	# 1. The doorway is physically solid.
	var blocker := door_node.get_node_or_null("DoorBlocker") as StaticBody3D
	if not assert_condition(blocker != null, "Door carries a collision body"): return
	if not assert_condition(blocker.collision_layer & 1 != 0, "Door blocker sits on the world collision layer"): return
	var blocker_shape := blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not assert_condition(blocker_shape != null and blocker_shape.shape != null, "Door blocker has a shape"): return
	if not assert_condition(not blocker_shape.disabled, "Door blocker starts enabled"): return

	# 2. A ray straight through the doorway is stopped. This is the regression
	#    that dropped the player out of the world.
	var space := office.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-1.6, 1.0, 1.2), Vector3(-1.6, 1.0, 3.4))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if not assert_condition(not hit.is_empty(), "The closed doorway stops a ray leaving the office"): return

	# 3. There is floor beyond the door, so opening it later reveals a landing
	#    rather than the void.
	var floor_query := PhysicsRayQueryParameters3D.create(Vector3(-1.6, 1.2, 3.2), Vector3(-1.6, -0.6, 3.2))
	floor_query.collision_mask = 1
	if not assert_condition(not space.intersect_ray(floor_query).is_empty(), "There is a floor beyond the door"): return

	# 4. Locked, and trying it does something without opening it.
	var door := office.office_door
	if not assert_condition(door != null, "Door controller is wired"): return
	if not assert_condition(door.is_locked(), "Door starts locked"): return
	var interactable := door.get_interactable()
	if not assert_condition(interactable != null, "Door is interactable"): return
	if not assert_condition(interactable.prompt_text == OfficeDoor.PROMPT_LOCKED, "Locked prompt is shown"): return
	if not assert_condition(interactable.is_actionable, "Trying a locked door is still an action"): return

	interactable.interact()
	if not assert_condition(door.rattle_count == 1, "Trying the handle rattles it"): return
	if not assert_condition(not door.is_open, "Rattling does not open the door"): return
	if not assert_condition(door.is_locked(), "The door stays locked"): return

	# 5. It unlocks when the line closes, not before.
	var director := office.shift_director
	if not assert_condition(director != null, "Shift director is wired"): return
	director.shift_closed.emit()
	if not assert_condition(not door.is_locked(), "Closing the line unlocks the door"): return
	if not assert_condition(interactable.prompt_text == OfficeDoor.PROMPT_UNLOCKED, "Prompt now offers a way out"): return

	# 6. Opening swings the leaf and clears the way.
	var leaf := door_node.get_node_or_null("Leaf") as Node3D
	if not assert_condition(leaf != null, "Door leaf hangs on a hinge"): return
	var closed_rotation := leaf.rotation.y
	door.open()
	if not assert_condition(door.is_open, "The door opens"): return
	await process_frame
	await process_frame
	if not assert_condition(blocker_shape.disabled, "Opening clears the doorway collision"): return

	# The swing is a tween, so it is in progress rather than finished here.
	await create_timer_wait(0.35)
	if not assert_condition(not is_equal_approx(leaf.rotation.y, closed_rotation), "The leaf actually swings"): return

	# 7. Stepping through ends the slice with Elias's own record.
	var trigger := office.get_node_or_null("OfficeExitTrigger") as Area3D
	if not assert_condition(trigger != null, "There is a threshold trigger"): return
	var card := office.shift_end_card
	if not assert_condition(card != null, "End card is wired"): return
	if not assert_condition(not card.is_running(), "End card is idle before the operator leaves"): return

	office._on_exit_body_entered(office.player)
	if not assert_condition(card.is_running(), "Walking out plays the end card"): return
	if not assert_condition(card.visible, "End card is shown"): return
	if not assert_condition(office.player.is_movement_locked, "The operator stops walking once the slice ends"): return
	var body_text := card.body_label.text if card.body_label != null else ""
	if not assert_condition(body_text.contains("TRAIN 17"), "The record is the operator's duty sheet"): return
	if not assert_condition(not body_text.contains("WATER") and not body_text.contains("WATCHER"), "The record never leaks message content"): return

	print("--- All Office Door Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func create_timer_wait(seconds: float) -> Signal:
	return create_timer(seconds).timeout

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
