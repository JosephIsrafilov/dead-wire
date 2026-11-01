extends SceneTree

## The room at the end of the watch (plan 9.5): the same fixed cameras at night
## and at full dawn with the lamp turned down for the day man, so a change to
## the morning can be judged against the night it ends.
##
##   godot --path . --script tools/dawn_room_capture.gd -- --tag=before
##
## Windowed only. Writes to .dream-loop/dawn_room/<tag>/.

const OUT_ROOT := "res://.dream-loop/dawn_room"
const VIEWS := {
	"room": [Vector3(1.6, 1.6, 1.7), Vector3(-1.8, 1.0, -1.4)],
	"desk": [Vector3(-0.9, 1.5, 0.7), Vector3(-2.4, 0.8, -0.6)],
	"window": [Vector3(0.3, 1.55, -0.75), Vector3(-1.5, 1.45, -2.36)],
	"door": [Vector3(-0.25, 1.35, 0.75), Vector3(-1.6, 1.10, 2.36)],
	"register": [Vector3(-1.55, 1.15, -0.85), Vector3(-2.06, 0.8, -1.15)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The dawn has to be looked at: run windowed.")
		quit(2)
		return
	var tag := "before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	var lamp := office.get_node("LampLife") as LampLife
	lamp.set_wick_immediate(1.0)
	var player := office.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	var out_dir := OUT_ROOT.path_join(tag)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _views(cam, out_dir, "night_")

	var ritual := office.get_node("DawnRitual") as DawnRitual
	ritual.begin()
	var moon := office.get_node("MoonWeather") as MoonWeather
	moon.advance(moon.dawn_seconds + 1.0)
	lamp.turn_down_wick()
	for _i in 120:
		await process_frame
	await _views(cam, out_dir, "dawn_")
	quit(0)

func _views(cam: Camera3D, out_dir: String, prefix: String) -> void:
	for view_name in VIEWS:
		var view: Array = VIEWS[view_name]
		cam.global_position = view[0]
		cam.look_at(view[1], Vector3.UP)
		for _i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		print("SHOT ", prefix + view_name, " ", image.save_png(out_dir.path_join(prefix + view_name + ".png")))
