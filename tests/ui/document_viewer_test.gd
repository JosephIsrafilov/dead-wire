extends SceneTree

func _init() -> void:
	print("--- Starting Document Viewer Test Suite (Phase D) ---")

	var viewer_scene: PackedScene = ResourceLoader.load("res://scenes/ui/document_viewer.tscn")
	if not assert_condition(viewer_scene != null, "document_viewer.tscn loads"): return
	var viewer: DocumentViewer = viewer_scene.instantiate() as DocumentViewer
	if not assert_condition(viewer != null and viewer is DocumentViewer, "instantiates as DocumentViewer"): return
	root.add_child(viewer)

	# 1. Initial closed state
	if not assert_condition(not viewer.is_open(), "Initially not open"): return
	if not assert_condition(not viewer.visible, "Initially not visible"): return

	# 2. Open document
	var opened_docs: Array[String] = []
	var closed_docs: Array[String] = []
	viewer.document_opened.connect(func(id: String): opened_docs.append(id))
	viewer.document_closed.connect(func(id: String): closed_docs.append(id))

	viewer.open_document("doc_test_1", "TEST TITLE", "Test body paragraph content.", "[E / Esc] Custom Close")
	if not assert_condition(viewer.is_open(), "is_open() is true after open_document()"): return
	if not assert_condition(viewer.visible, "visible is true after open_document()"): return
	if not assert_condition(viewer.get_current_doc_id() == "doc_test_1", "current_doc_id matches"): return
	if not assert_condition(opened_docs.size() == 1 and opened_docs[0] == "doc_test_1", "document_opened signal emitted"): return
	if not assert_condition(viewer.title_label.text == "TEST TITLE", "title_label text matches"): return
	if not assert_condition(viewer.body_label.text == "Test body paragraph content.", "body_label text matches"): return
	if not assert_condition(viewer.footer_label.text == "[E / Esc] Custom Close", "footer_label text matches"): return

	# 3. Prevent instant close on same frame
	var ev_e: InputEventKey = InputEventKey.new()
	ev_e.physical_keycode = KEY_E
	ev_e.pressed = true
	viewer._unhandled_input(ev_e)
	if not assert_condition(viewer.is_open(), "Viewer does not immediately close on same opening frame"): return

	# 4. Close document
	viewer.close_document()
	if not assert_condition(not viewer.is_open(), "is_open() is false after close_document()"): return
	if not assert_condition(not viewer.visible, "visible is false after close_document()"): return
	if not assert_condition(closed_docs.size() == 1 and closed_docs[0] == "doc_test_1", "document_closed signal emitted"): return

	# Clean up
	viewer.queue_free()

	print("--- All Document Viewer Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
