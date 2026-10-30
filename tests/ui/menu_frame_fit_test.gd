extends SceneTree

## Every menu fits the frame it is drawn in. The pause menu lives inside the
## office's 960x540 presentation frame (plan 1.1), so it must fit 540 lines;
## the title screen draws at the project's 1280x720 canvas. A clipped menu
## hides "Return to the Wire" and "Quit" below the bottom of the screen.

var passed: int = 0

func _init() -> void:
	call_deferred("_run")

func require(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true

func _run() -> void:
	print("--- Starting Menu Frame Fit Test Suite ---")

	var office_frame := _frame(ReadabilityPolicy.INTERNAL_SIZE)
	var pause := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as CanvasLayer
	office_frame.add_child(pause)
	pause.visible = true
	await process_frame
	await process_frame
	var panel := pause.get_node("CenterContainer/PanelContainer") as Control
	var frame_rect := Rect2(Vector2.ZERO, Vector2(ReadabilityPolicy.INTERNAL_SIZE))
	if not require(frame_rect.encloses(panel.get_global_rect()),
			"Pause menu fits the 960x540 office frame (%s)" % panel.get_global_rect()): return
	var quit_button := pause.get("quit_button") as Control
	if not require(quit_button != null and frame_rect.encloses(quit_button.get_global_rect()),
			"Quit to Desktop is on screen in the office frame"): return

	var title_frame := _frame(Vector2i(1280, 720))
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	title_frame.add_child(menu)
	await process_frame
	menu.call("toggle_options")
	await process_frame
	await process_frame
	var column := menu.get_node("CenterContainer/VBoxContainer") as Control
	var title_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	if not require(title_rect.encloses(column.get_global_rect()),
			"Title screen with options open fits 1280x720 (%s)" % column.get_global_rect()): return

	office_frame.queue_free()
	title_frame.queue_free()
	await process_frame
	print("Menu frame fit assertions: ", passed)
	quit(0)

func _frame(frame_size: Vector2i) -> SubViewport:
	var frame := SubViewport.new()
	frame.size = frame_size
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	return frame
