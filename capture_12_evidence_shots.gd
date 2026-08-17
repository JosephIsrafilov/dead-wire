extends SceneTree

const REQUIRED_SIZE := Vector2i(1280, 720)
const CANONICAL_FILES := [
	"01_spawn_hero.png", "02_full_room_overview.png", "03_operator_workstation.png",
	"04_chair_clearance.png", "05_telegraph_equipment.png", "06_north_window_idle.png",
	"07_north_window_figure.png", "08_south_door.png", "09_routing_board.png",
	"10_stove_storage.png", "11_real_morse_document.png", "12_scenario3_debug_telemetry.png"
]
const COMPARISON_PAIRS := [
	"01_spawn_hero.png", "02_full_room_overview.png",
	"07_north_window_figure.png", "09_routing_board.png", "10_stove_storage.png"
]

var office_scene := preload("res://scenes/office/m1_office.tscn")
var office_node: M1OfficeController
var captured_hashes: Dictionary = {}
var output_directory := "res://docs/art/m1_visual_acceptance/final"
var diagnostic_only := false

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if not _configure_output_directory():
		return
	if not _prepare_output_directory():
		return
	office_node = office_scene.instantiate() as M1OfficeController
	if office_node == null:
		_fail("Could not instantiate production office scene")
		return
	root.add_child(office_node)

	var camera := office_node.get_node_or_null("Player/Head/Camera3D") as Camera3D
	if camera == null:
		_fail("Missing required production camera at Player/Head/Camera3D")
		return
	camera.current = true

	await _wait_for_rendered_frames(8)
	var shots: Array[Dictionary] = [
		{"file": "01_spawn_hero.png", "position": Vector3(0.0, 1.65, 1.5), "target": Vector3(-1.2, 0.85, -1.0), "fov": 90.0},
		{"file": "02_full_room_overview.png", "position": Vector3(-2.25, 1.65, 1.75), "target": Vector3(0.6, 0.85, -0.2), "fov": 94.0},
		{"file": "03_operator_workstation.png", "position": Vector3(-1.16, 1.34, -0.6), "target": Vector3(-2.35, 0.73, -0.63), "fov": 61.0},
		{"file": "04_chair_clearance.png", "position": Vector3(-0.58, 1.0, -0.04), "target": Vector3(-1.72, 0.43, -0.6), "fov": 62.0},
		{"file": "05_telegraph_equipment.png", "position": Vector3(-1.68, 1.12, -0.94), "target": Vector3(-2.38, 0.75, -0.92), "fov": 55.0},
		{"file": "06_north_window_idle.png", "position": Vector3(0.62, 1.5, -1.25), "target": Vector3(1.05, 1.55, -2.36), "fov": 58.0},
		{"file": "07_north_window_figure.png", "position": Vector3(0.62, 1.5, -1.25), "target": Vector3(0.72, 1.58, -2.62), "fov": 58.0, "scenario_3": true},
		{"file": "08_south_door.png", "position": Vector3(-1.6, 1.55, -0.3), "target": Vector3(-1.6, 1.05, 2.36), "fov": 55.0},
		{"file": "09_routing_board.png", "position": Vector3(1.45, 1.42, -0.85), "target": Vector3(2.7, 1.34, -0.85), "fov": 50.0, "board_open": true},
		{"file": "10_stove_storage.png", "position": Vector3(0.18, 1.55, -0.1), "target": Vector3(2.25, 0.9, 1.32), "fov": 70.0},
		{"file": "11_real_morse_document.png", "position": Vector3(0.0, 1.65, 0.0), "target": Vector3(-1.75, 0.8, -0.9), "fov": 68.0, "document": true},
		{"file": "12_scenario3_debug_telemetry.png", "position": Vector3(0.0, 1.65, 0.0), "target": Vector3(-1.75, 0.8, -0.9), "fov": 68.0, "debug": true}
	]
	if diagnostic_only:
		shots = shots.filter(func(shot: Dictionary) -> bool: return shot["file"] in ["01_spawn_hero.png", "02_full_room_overview.png", "07_north_window_figure.png", "09_routing_board.png", "10_stove_storage.png"])
		# Explicit names keep the written review independent of canonical numbering.
		var diagnostic_names := ["diagnostic_spawn.png", "diagnostic_overview.png", "diagnostic_window_figure.png", "diagnostic_routing_board.png", "diagnostic_stove_storage.png"]
		for index in shots.size():
			shots[index]["file"] = diagnostic_names[index]

	for shot in shots:
		if not await _capture_shot(camera, shot):
			return

	if captured_hashes.size() != shots.size():
		_fail("Capture hashes were not unique")
		return
	if not _write_comparisons():
		return
	print("Captured ", shots.size(), " validated evidence shots to ", output_directory)
	quit(0)

func _capture_shot(camera: Camera3D, shot: Dictionary) -> bool:
	_reset_visual_state()
	if shot.get("scenario_3", false):
		if not _activate_scenario_3_event():
			return false
	if shot.get("board_open", false):
		office_node.routing_board.set_awaiting_route(true)
		office_node.routing_board.open_board()
	if shot.get("document", false):
		var card := office_node.get_node_or_null("MorseReferenceCard") as MorseReferenceCard
		var interactable := card.get_interactable() if card != null else null
		if card == null or interactable == null:
			_fail("MorseReferenceCard production interaction is missing")
			return false
		interactable.interact()
		if not office_node.document_viewer.is_open() or office_node.document_viewer.body_label.text != card.get_reference_text():
			_fail("MorseReferenceCard did not open its production DocumentViewer text")
			return false
		for character in ["A", "C", "D", "E", "F", "G", "H", "I", "L", "N", "O", "R", "S", "T", "U", "W", "1", "7"]:
			if not office_node.document_viewer.body_label.text.contains(character):
				_fail("MorseReferenceCard document misses required character %s" % character)
				return false
	if shot.get("debug", false):
		if not _activate_scenario_3_event():
			return false
		var inspector := office_node.get_node_or_null("DebugInspector") as DebugInspector
		if inspector == null:
			_fail("DebugInspector is missing for telemetry capture")
			return false
		inspector.visible = true
		inspector._refresh_display()

	camera.fov = float(shot["fov"])
	camera.global_position = shot["position"]
	# Camera3D looks down local -Z. Do not use model-front orientation here.
	camera.look_at(shot["target"], Vector3.UP)
	await _wait_for_rendered_frames(6)
	RenderingServer.force_draw()
	await process_frame

	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != REQUIRED_SIZE:
		_fail("Invalid viewport image for %s: expected %s, got %s" % [shot["file"], REQUIRED_SIZE, image.get_size() if image != null else Vector2i.ZERO])
		return false
	var output_path := output_directory.path_join(shot["file"])
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_fail("save_png failed for %s with error %d" % [output_path, save_error])
		return false
	var reloaded := Image.load_from_file(ProjectSettings.globalize_path(output_path))
	if reloaded == null or reloaded.get_size() != REQUIRED_SIZE or reloaded.get_width() <= 1 or reloaded.get_height() <= 1:
		_fail("Corrupt or invalid PNG written: %s" % output_path)
		return false
	var digest := _sha256(output_path)
	if digest.is_empty() or captured_hashes.has(digest):
		_fail("Missing or duplicate PNG SHA256 for %s" % output_path)
		return false
	captured_hashes[digest] = shot["file"]
	print("Captured ", shot["file"], "  ", reloaded.get_width(), "x", reloaded.get_height(), "  ", digest)
	return true

func _reset_visual_state() -> void:
	if office_node.window_observation != null:
		office_node.window_observation.reset_state()
	if office_node.routing_board != null:
		office_node.routing_board.close_board()
		office_node.routing_board.set_awaiting_route(false)
	if office_node.document_viewer != null and office_node.document_viewer.is_open():
		office_node.document_viewer.close_document()
	var inspector := office_node.get_node_or_null("DebugInspector") as DebugInspector
	if inspector != null:
		inspector.visible = false

func _activate_scenario_3_event() -> bool:
	office_node.load_scenario_by_index(2)
	var key := office_node.session_controller.telegraph_key if office_node.session_controller != null else null
	var interactable := key.get_interactable() if key != null else null
	if key == null or interactable == null:
		_fail("Scenario 3 production telegraph interaction is missing")
		return false
	interactable.interact()
	office_node.session_controller.scheduler.advance_time(1.0)
	if office_node.window_observation == null or not office_node.window_observation.is_active:
		_fail("Scenario 3 did not activate the production window event")
		return false
	return true

func _wait_for_rendered_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame

func _prepare_output_directory() -> bool:
	var absolute_directory := ProjectSettings.globalize_path(output_directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		_fail("Could not create output directory %s (error %d)" % [absolute_directory, error])
		return false
	return true

func _configure_output_directory() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			var stage := argument.trim_prefix("--stage=")
			if stage not in ["before", "round_1", "final", "focused_round"]:
				_fail("Unknown evidence stage: %s" % stage)
				return false
			output_directory = "res://docs/art/m1_visual_acceptance/" + stage
		if argument == "--diagnostic":
			diagnostic_only = true
	return true

func _write_comparisons() -> bool:
	if not output_directory.ends_with("/final") and not output_directory.ends_with("/focused_round"):
		return true
	if diagnostic_only:
		return true
	var comparison_directory := output_directory.get_base_dir().path_join("comparison_focused" if output_directory.ends_with("/focused_round") else "comparison")
	var create_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(comparison_directory))
	if create_error != OK:
		_fail("Could not create comparison directory %s (error %d)" % [comparison_directory, create_error])
		return false
	for filename in COMPARISON_PAIRS:
		var before_directory := "rejected_visual_pass/final" if output_directory.ends_with("/focused_round") else "before"
		var before := Image.load_from_file(ProjectSettings.globalize_path("res://docs/art/m1_visual_acceptance/".path_join(before_directory).path_join(filename)))
		var final := Image.load_from_file(ProjectSettings.globalize_path(output_directory.path_join(filename)))
		if before == null or final == null or before.get_size() != REQUIRED_SIZE or final.get_size() != REQUIRED_SIZE:
			_fail("Cannot compose comparison for %s" % filename)
			return false
		before.convert(Image.FORMAT_RGBA8)
		final.convert(Image.FORMAT_RGBA8)
		var comparison := Image.create(REQUIRED_SIZE.x * 2, REQUIRED_SIZE.y, false, Image.FORMAT_RGBA8)
		comparison.blit_rect(before, Rect2i(Vector2i.ZERO, REQUIRED_SIZE), Vector2i.ZERO)
		comparison.blit_rect(final, Rect2i(Vector2i.ZERO, REQUIRED_SIZE), Vector2i(REQUIRED_SIZE.x, 0))
		var output_path := comparison_directory.path_join(filename.trim_suffix(".png") + "_before_final.png")
		if comparison.save_png(output_path) != OK:
			_fail("Could not save comparison for %s" % filename)
			return false
	return true

func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()

func _fail(message: String) -> void:
	printerr("CAPTURE ERROR: ", message)
	quit(1)
