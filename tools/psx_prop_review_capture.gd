extends SceneTree

## Prop review stills for the PSX style pass: one frame per prop, framed the way
## the player actually meets it.
##
##   godot --path . --script tools/psx_prop_review_capture.gd [-- --tag=before]
##
## Windowed only (needs a real framebuffer). Writes to
## .dream-loop/prop_review/<tag>/<name>.png. Not gameplay evidence.

const OUT_ROOT := "res://.dream-loop/prop_review"

## name -> [eye position, look-at point]
const VIEWS := {
	"chair": [Vector3(-1.05, 1.05, 0.15), Vector3(-1.55, 0.45, -0.6)],
	"lamp": [Vector3(-1.95, 1.05, -0.45), Vector3(-2.18, 0.86, -0.44)],
	"clock": [Vector3(-1.9, 2.05, 0.2), Vector3(-2.82, 1.95, 0.62)],
	"board": [Vector3(1.25, 1.15, -0.85), Vector3(2.74, 1.05, -0.85)],
	"service_table": [Vector3(1.15, 1.15, 1.05), Vector3(0.45, 0.72, 1.85)],
	"window": [Vector3(0.30, 1.55, -0.75), Vector3(-1.5, 1.45, -2.36)],
	"window_angle": [Vector3(-0.75, 1.60, -0.55), Vector3(-1.85, 1.45, -2.36)],
	"door": [Vector3(-0.25, 1.35, 0.75), Vector3(-1.6, 1.10, 2.36)],
	"notice_board": [Vector3(1.62, 1.52, 1.28), Vector3(1.62, 1.55, 2.28)],
	"notice_board_close": [Vector3(1.62, 1.56, 1.85), Vector3(1.62, 1.56, 2.28)],
	"notice_memo_dead": [Vector3(1.400, 1.375, 2.05), Vector3(1.400, 1.375, 2.28)],
	"notice_rule_dead": [Vector3(1.840, 1.385, 2.05), Vector3(1.840, 1.385, 2.28)],
	"notice_board_wide": [Vector3(1.20, 1.62, 0.95), Vector3(1.62, 1.52, 2.28)],
	"routing_board_face": [Vector3(2.74, 1.30, 0.25), Vector3(2.74, 0.95, -0.85)],
	"coat": [Vector3(-0.35, 1.62, 1.30), Vector3(-0.35, 1.62, 2.25)],
	"coat_wide": [Vector3(-0.35, 1.50, 0.85), Vector3(-0.35, 1.62, 2.25)],
	"coat_angle": [Vector3(0.35, 1.60, 1.35), Vector3(-0.35, 1.62, 2.25)],
	"coat_low": [Vector3(-0.35, 1.15, 1.15), Vector3(-0.35, 1.45, 2.25)],
	"loose_props": [Vector3(0.55, 1.20, 1.55), Vector3(1.30, 0.05, 0.70)],
	"hat": [Vector3(-0.35, 2.05, 1.75), Vector3(-0.35, 2.04, 2.25)],
	"coat_shoulders": [Vector3(-0.35, 1.85, 1.55), Vector3(-0.35, 1.85, 2.25)],
	# Plan 8.10: where the cup and the ink bottle are set down on the desk.
	"cup_desk": [Vector3(-1.45, 1.20, 0.15), Vector3(-2.06, 0.80, -0.19)],
	"bottle_desk": [Vector3(-1.55, 1.22, -0.70), Vector3(-2.22, 0.80, -1.27)],
	# Plan 9.3: the ledger signed at the head of the watch.
	"ledger": [Vector3(-1.95, 1.25, -0.10), Vector3(-2.52, 0.76, -0.14)],
	"ledger_wide": [Vector3(-1.10, 1.45, 0.35), Vector3(-2.40, 0.76, -0.30)],
	"ledger_signed": [Vector3(-1.95, 1.25, -0.10), Vector3(-2.52, 0.76, -0.14)],
	"ledger_signed_close": [Vector3(-2.22, 1.08, -0.10), Vector3(-2.50, 0.77, -0.15)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tag := "before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	var out_dir := OUT_ROOT.path_join(tag)
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	var intro := office.get_node_or_null("IntroCard")
	if intro != null and intro.has_method("skip_immediately"):
		intro.skip_immediately()
	var lamp_life := office.get_node_or_null("LampLife")
	if lamp_life != null:
		lamp_life.set_wick_immediate(1.0)
	var director := office.get_node_or_null("ShiftDirector")
	if director != null:
		director.set("enabled", false)
	var player := office.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	DirAccess.make_dir_recursive_absolute(out_dir)
	for name in VIEWS:
		var view: Array = VIEWS[name]
		if name == "ledger_signed":
			var ledger := office.get_node_or_null("DispatchLedger")
			if ledger != null and ledger.has_method("sign_on"):
				ledger.sign_on()
				ledger.advance_signature(10.0)
		cam.global_position = view[0]
		cam.look_at(view[1], Vector3.UP)
		for _i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		print("SHOT ", name, " ", img.save_png(out_dir.path_join(name + ".png")))
	quit(0)
