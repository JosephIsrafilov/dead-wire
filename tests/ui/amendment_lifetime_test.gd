extends SceneTree
## Still-live detached editors must not regain focus or recapture a new scene.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: failures += 1
func _run() -> void:
	var editor := load("res://scenes/ui/amendment_editor.tscn").instantiate() as AmendmentEditor
	root.add_child(editor)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	editor._restore_capture()
	root.remove_child(editor)
	await process_frame
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "A detached capture callback cannot change the next scene's mouse ownership")
	editor.free()
	editor = load("res://scenes/ui/amendment_editor.tscn").instantiate() as AmendmentEditor
	root.add_child(editor)
	await process_frame
	editor._is_open = true
	editor._focus_after_activation()
	root.remove_child(editor)
	await process_frame
	await process_frame
	check(not editor.correction.is_editing(), "A detached focus callback cannot put an off-tree input into edit mode")
	editor.free()
	print("Editor lifetime failures: ", failures)
	quit(1 if failures else 0)
