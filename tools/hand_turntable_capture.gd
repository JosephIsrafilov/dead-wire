extends SceneTree

## Art review of the writing hand and the copy sheet, isolated from the room.
##
##   godot --path . --script tools/hand_turntable_capture.gd
##
## Windowed only. Neutral light, fixed cameras around the transcript sheet in
## its own local frame (+X across the sheet, +Z toward the operator, +Y up off
## the paper). Writes .dream-loop/hand_turntable/*.png.

const OUT_DIR := "res://.dream-loop/hand_turntable"

## name -> [eye (sheet-local), look-at (sheet-local)]
const VIEWS := {
	"t1_operator_eye": [Vector3(0.02, 0.36, 0.42), Vector3(0.0, 0.03, 0.02)],
	"t2_top_down": [Vector3(0.0, 0.5, 0.05), Vector3(0.0, 0.0, 0.0)],
	"t3_right_side": [Vector3(0.38, 0.12, 0.05), Vector3(0.0, 0.04, 0.02)],
	"t4_left_side": [Vector3(-0.36, 0.12, 0.05), Vector3(0.0, 0.04, 0.02)],
	"t5_front_low": [Vector3(0.0, 0.08, -0.4), Vector3(0.0, 0.04, 0.05)],
	"t6_hand_macro": [Vector3(0.06, 0.16, 0.2), Vector3(0.0, 0.03, 0.0)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.52)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.6, 0.0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	stage.add_child(key)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.3, 0.5, -0.2)
	lamp.light_color = Color(1, 0.81, 0.61)
	lamp.light_energy = 1.2
	lamp.omni_range = 2.0
	stage.add_child(lamp)

	var paper: TranscriptPaper = load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
	stage.add_child(paper)
	await process_frame
	var rig := paper.get_node("WriterRig") as WriterRig
	rig._apply_visibility(true)
	var cam := Camera3D.new()
	cam.fov = 50.0
	stage.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for name in VIEWS:
		var view: Array = VIEWS[name]
		cam.global_position = paper.to_global(view[0])
		cam.look_at(paper.to_global(view[1]), Vector3.UP)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		print("SHOT ", name, " ", root.get_texture().get_image().save_png(OUT_DIR.path_join(name + ".png")))
	quit(0)
