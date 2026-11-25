extends SceneTree
## Regression: the chapel is an optional walkable landmark, not a skyline-only prop.
## Walk from Main Street through the gate to the closed door, then back.

const TOWN := "res://scenes/town/black_creek_exterior.tscn"
const ROUTE := [Vector3(-46.0, 0.0, 26.0), Vector3(-46.0, 0.0, 27.3),
	Vector3(-46.0, 0.613, 31.1), Vector3(-46.0, 0.613, 33.7),
	Vector3(-46.0, 0.613, 31.1), Vector3(-46.0, 0.0, 27.3), Vector3(-46.0, 0.0, 23.0)]

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var town := (load(TOWN) as PackedScene).instantiate() as Node3D
	root.add_child(town)
	await process_frame
	await process_frame
	var player := town.get_node_or_null("Player") as PlayerController
	_ok(player != null, "town player exists")
	if player == null:
		quit(1)
		return
	player.global_position = Vector3(-46.0, 0.05, 23.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await physics_frame
	for waypoint: Vector3 in ROUTE:
		var flat := Vector2(waypoint.x, waypoint.z)
		player.aim_at(Vector3(waypoint.x, player.global_position.y + 1.56, waypoint.z))
		Input.action_press("move_forward")
		for _tick in 720:
			await physics_frame
			if Vector2(player.global_position.x, player.global_position.z).distance_to(flat) < 0.14:
				break
		Input.action_release("move_forward")
		var actual := player.global_position
		var reached := Vector2(actual.x, actual.z).distance_to(flat) < 0.20
		_ok(reached and absf(actual.y - waypoint.y) < 0.13,
			"walking route reaches %s (actual %s)" % [waypoint, actual])
		player.velocity = Vector3.ZERO
		if not reached:
			break
	town.queue_free()
	await process_frame
	quit(1 if _fails > 0 else 0)

func _ok(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: " + description)
	else:
		print("  FAIL: " + description)
		_fails += 1
