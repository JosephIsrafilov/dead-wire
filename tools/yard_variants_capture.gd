extends SceneTree

## The yard from the chair with and without snow in the switch lamp (plan 3.12,
## an experiment that ships OFF). Nothing here changes the game.
##
##   godot --path . --script tools/yard_variants_capture.gd
##
## Windowed only. Writes to .dream-loop/yard_variants/.

var out_dir := "res://.dream-loop/yard_variants"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	(office.get_node("LampLife") as LampLife).set_wick_immediate(0.3)
	var snow := office.get_node("YardSnow") as GPUParticles3D
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await create_timer(1.0).timeout
	var direction := Vector3(-1.5, 1.45, -2.36) - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	for variant in ["no_snow", "snow"]:
		snow.visible = variant == "snow"
		snow.emitting = variant == "snow"
		if snow.emitting:
			snow.restart()
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(out_dir)
		root.get_texture().get_image().save_png(out_dir.path_join(variant + ".png"))
		print("shot ", variant)
	quit(0)
