extends SceneTree

const REQUIRED_SIZE := Vector2i(1280, 720)
const OUTPUT_DIRECTORY := "res://docs/art/m1_visual_acceptance/luna_completion"

var office_scene := preload("res://scenes/office/m1_office.tscn")
var office: M1OfficeController
var camera: Camera3D
var captured: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _prepare_output_directory():
		return
	office = office_scene.instantiate() as M1OfficeController
	if office == null:
		_fail("Could not instantiate production office")
		return
	root.add_child(office)
	await _frames(8)
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	camera = office.get_node_or_null("Player/Head/Camera3D") as Camera3D
	if camera == null:
		_fail("Production camera is missing")
		return
	camera.current = true
	if office.shift_director != null:
		office.shift_director.enabled = false
	if office.session_controller == null or office.session_controller.telegraph_key == null:
		_fail("Production session/key is missing")
		return
	office.session_controller.scheduler.auto_process = false
	# Drive both scheduler and consequence timing manually so render awaits do
	# not consume authored delays between assertions.
	office.session_controller.set_process(false)

	# Capture a live authored-writing pose before the transcript is complete.
	if not _load_core_hook_and_start():
		return
	office.session_controller.scheduler.advance_time(1.45)
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING, "writer capture stays in RECEIVING"):
		return
	if not _check(office.session_controller.transcript_paper.get_writer_rig().is_active(), "writer rig is active during live writing"):
		return
	await _capture("01_writer_mid.png", Vector3(-1.2, 1.22, -0.06), Vector3(-2.12, 0.79, -0.72), 55.0)

	# Finish the signal, verify the transcript, then expose both physical choices.
	office.session_controller.scheduler.advance_time(3.0)
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "finished signal enters VERIFYING"):
		return
	var desk := office.copy_commit_desk
	var option_one := desk.get_node("OptionOneLabel") as Label3D
	var option_two := desk.get_node("OptionTwoLabel") as Label3D
	if not _check(not option_one.visible and not option_two.visible, "copy labels remain hidden before inspection"):
		return
	office.session_controller.mark_transcript_verified()
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "inspection enters AWAITING_COMMIT"):
		return
	if not _check(desk.is_enabled() and option_one.visible and option_two.visible, "both copy labels appear after inspection (enabled=%s one=%s two=%s state=%s)" % [desk.is_enabled(), option_one.visible, option_two.visible, office.session_controller.get_state()]):
		return
	await _capture("02_commit_ready.png", Vector3(-0.86, 1.16, 0.92), Vector3(-1.15, 0.78, 1.35), 58.0)

	# Branch result is a stamped physical line; the other line is visibly void.
	if not _check(desk.commit_option(&"file_water"), "water option commits"):
		return
	if not _check(desk.has_committed() and not desk.is_enabled(), "desk locks after one commit"):
		return
	await _capture("03_commit_water_stamped.png", Vector3(-0.86, 1.16, 0.92), Vector3(-1.15, 0.78, 1.35), 58.0)
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "commit enters neutral consequence"):
		return
	office.session_controller.advance_consequence(0.99)
	if not _check(not office.window_observation.is_active, "figure waits through consequence delay"):
		return
	office.session_controller.advance_consequence(0.02)
	if not _check(office.window_observation.is_active, "figure starts after neutral delay"):
		return
	await _capture("04_consequence_figure.png", Vector3(0.62, 1.5, -1.25), Vector3(0.72, 1.58, -2.62), 58.0)

	# Re-run the hook for the alternate authored copy so the evidence set covers
	# both physical decisions, not only the first branch.
	if not _load_core_hook_and_start():
		return
	office.session_controller.scheduler.advance_time(4.0)
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "watcher branch reaches VERIFYING"):
		return
	office.session_controller.mark_transcript_verified()
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "watcher branch exposes commit desk"):
		return
	if not _check(desk.commit_option(&"file_watcher"), "watcher option commits"):
		return
	await _capture("05_commit_watcher_stamped.png", Vector3(-0.86, 1.16, 0.92), Vector3(-1.15, 0.78, 1.35), 58.0)

	# Explicit lapse is a resolved physical desk state, not a silent fallback.
	if not _load_core_hook_and_start():
		return
	office.session_controller.scheduler.advance_time(4.0)
	if not _check(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "lapsed branch reaches VERIFYING"):
		return
	office.session_controller.mark_transcript_verified()
	if not _check(office.session_controller.lapse_commit(), "lapsed branch resolves without selecting a copy"):
		return
	if not _check(desk.get_result_text() == "UNFILED", "lapsed branch displays UNFILED"):
		return
	await _capture("06_commit_lapsed.png", Vector3(-0.86, 1.16, 0.92), Vector3(-1.15, 0.78, 1.35), 58.0)
	office.session_controller.advance_consequence(1.01)
	if not _check(office.window_observation.is_active, "lapsed consequence figure starts after delay"):
		return

	# Reset must cancel the pending consequence/figure and restore the blank desk.
	office.window_observation.reset_state()
	office.copy_commit_desk.reset_for_new_transmission()
	if not _check(not office.window_observation.is_active, "reset clears pending window figure"):
		return
	if not _check(not option_one.visible and not option_two.visible and not desk.has_committed(), "reset clears commit presentation"):
		return
	await _capture("07_reset_idle.png", Vector3(0.0, 1.65, 1.5), Vector3(-1.2, 0.85, -1.0), 90.0)

	print("Captured ", captured.size(), " Luna completion evidence PNGs to ", OUTPUT_DIRECTORY)
	quit(0)

func _load_core_hook_and_start() -> bool:
	if not office.load_scenario_by_index(2):
		_fail("Could not load scenario 3")
		return false
	office.session_controller.allow_key_start = true
	office.session_controller.telegraph_key.press()
	if office.session_controller.get_state() != TelegraphSessionController.State.RECEIVING:
		_fail("Could not start scenario 3 from production key")
		return false
	return true

func _capture(filename: String, position: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	camera.fov = fov
	await _frames(6)
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != REQUIRED_SIZE:
		_fail("Invalid image size for %s" % filename)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY.path_join(filename))
	if image.save_png(path) != OK:
		_fail("Could not save %s" % path)
		return
	var digest := _sha256(path)
	if digest.is_empty() or captured.has(digest):
		_fail("Duplicate or missing digest for %s" % filename)
		return
	captured[digest] = filename
	print("Captured ", filename, " ", REQUIRED_SIZE, " ", digest)

func _prepare_output_directory() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if error != OK:
		_fail("Could not create output directory")
		return false
	return true

func _frames(count: int) -> void:
	for _frame in count:
		await process_frame

func _check(condition: bool, description: String) -> bool:
	if not condition:
		_fail(description)
		return false
	print("PASS: ", description)
	return true

func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	file.close()
	return context.finish().hex_encode()

func _fail(message: String) -> void:
	printerr("CAPTURE ERROR: ", message)
	quit(1)
