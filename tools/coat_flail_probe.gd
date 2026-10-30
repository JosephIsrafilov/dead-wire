extends SceneTree

## Why does the coat flail when the operator stands next to it?
##
## Drives the real coat with a real player body parked beside it and prints, per
## second: how far the hem is swinging, how many rustles fired, and whether the
## cloth ever comes to rest. A coat that is being blown apart by a stationary man
## shows up as a large amplitude with rustles ticking.
##
##   godot --headless --audio-driver Dummy --path . --script tools/coat_flail_probe.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 8:
		await process_frame
	var coat := office.get_node_or_null("HangingCoat") as HangingCoat
	var player := office.get_node("Player") as Node3D
	if coat == null:
		print("NO COAT")
		quit(1)
		return
	coat.set_process(false)

	var rustles: Array[float] = []
	coat.rustled.connect(func(strength: float) -> void: rustles.append(strength))

	# Park the body where the player actually stands to look at the coat. At
	# 0.55 m the coat is just out of contact — this is the "standing next to it"
	# case, which must produce nothing at all.
	var hang := coat.get_hang_position()
	player.global_position = Vector3(hang.x + 0.05, 0.0, hang.z - 0.75)
	print("player at %s, coat centre %s, distance %.2f m" % [
		str(player.global_position.snapped(Vector3.ONE * 0.01)),
		str(hang.snapped(Vector3.ONE * 0.01)),
		Vector2(player.global_position.x - hang.x, player.global_position.z - hang.z).length()])

	print("--- standing still nearby, 4 s ---")
	_report(coat, "still")

	# Now the real case: the body brushes INTO the coat. Driven through the same
	# path the game uses (_maybe_disturb_from_player), not by calling disturb.
	print("--- walking INTO the coat at 1.35 m/s, 5 passes with 3 s between ---")
	player.global_position = Vector3(hang.x - 0.30, 0.0, hang.z - 0.42)
	player.set("velocity", Vector3(1.0, 0.0, 0.9).normalized() * 1.35)
	for pass_index in 5:
		coat._in_range = false
		coat._pass_cooldown = 0.0
		coat._maybe_disturb_from_player()
		for _f in 180:
			coat.step(1.0 / 60.0)
		_report(coat, "pass %d +3 s" % (pass_index + 1))
	print("--- rustles fired: %d ---" % rustles.size())
	print("--- authored hem width 0.397; drift from it is the ratchet check ---")
	office.queue_free()
	await process_frame
	quit(0)

func _report(coat: HangingCoat, label: String) -> void:
	var hem := coat.rings - 1
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var min_y := INF
	var max_y := -INF
	for c in coat.segments:
		var p := coat.get_particle_position(hem, c)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	print("  %-12s hem w=%.3f d=%.3f  y %.3f..%.3f  settled=%s  frozen=%s" % [
		label, max_x - min_x, max_z - min_z, min_y, max_y,
		coat.is_settled(), coat.get("_frozen")])
