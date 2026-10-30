extends SceneTree

## Does the simulated coat keep its shape?
##
## Prints each ring's width, depth and drop from the collar over a few hundred
## simulated steps, so a collapse is visible as numbers instead of guessed at
## from a dark screenshot.
##
##   godot --headless --audio-driver Dummy --path . --script tools/coat_probe.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var coat := load("res://scenes/office/hanging_coat.tscn").instantiate() as HangingCoat
	root.add_child(coat)
	await process_frame
	coat.set_process(false)

	print("--- particles: %d, rings %d x segments %d ---" % [
		coat.get_particle_count(), coat.rings, coat.segments])
	_report(coat, "after spawn")
	for i in 5:
		for _s in 60:
			coat.step(1.0 / 60.0)
		_report(coat, "after %d frames" % ((i + 1) * 60))
	print("--- settled: %s ---" % str(coat.is_settled()))
	coat.queue_free()
	await process_frame
	quit(0)

func _report(coat: HangingCoat, label: String) -> void:
	var line := "  %-18s" % label
	for r in [0, 3, coat.rings - 1]:
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		var min_y := INF
		for c in coat.segments:
			var p := coat.get_particle_position(r, c)
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_z = minf(min_z, p.z)
			max_z = maxf(max_z, p.z)
			min_y = minf(min_y, p.y)
		line += "  r%d w=%.3f d=%.3f y=%.3f" % [r, max_x - min_x, max_z - min_z, min_y]
	print(line)
