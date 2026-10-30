extends SceneTree
## The bookshelf is a reading surface, not scenery.
##
## The east wall had exactly one thing worth walking to: the routing board. The
## shelf of division volumes gives that wall a second reason to be looked at, and
## it has to behave like every other document surface in the room — the prompt
## names it, E hands the office a block of print, and the viewer opens it under
## its own title.
##
## What it must NOT do is read the night. This text is the same on every watch:
## general orders, the tariff, a quarantine notice nobody withdrew, and a
## newspaper cutting about the mine. It never mentions the operator, the copy or
## anything that happened tonight.
##
##   godot --headless --audio-driver Dummy --path . --script tests/office/bookshelf_inspect_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Bookshelf Inspect Test Suite ---")
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"): return
	root.add_child(office)
	for _i in 6:
		await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()

	var shelf := office.get_node_or_null("Bookcase/BookshelfInspect") as BookshelfInspect
	if not _a(shelf != null, "The bookcase carries an inspectable shelf"): return

	var act := shelf.get_interactable()
	if not _a(act != null, "The shelf exposes an Interactable"): return
	if not _a(act.prompt_text == "Inspect Bookshelf",
			"The shelf prompt names what the operator is doing (got '%s')" % act.prompt_text): return
	if not _a(act.is_actionable, "The shelf can be interacted with"): return

	# It has to be reachable from the room: the bookcase stands on the east wall,
	# so its interaction volume must sit on the room side of it, not inside the
	# wall. Measured in world space because the bookcase instance is rotated.
	var shelf_point := act.global_position
	if not _a(shelf_point.x < 2.62,
			"The shelf's interaction volume sits inside the room, not in the wall (x %.2f)"
				% shelf_point.x): return
	if not _a(shelf_point.y > 0.7 and shelf_point.y < 1.9,
			"The volume is at a person's reach (y %.2f)" % shelf_point.y): return

	# Pressing E has to reach the document viewer through the office, the same
	# path the ledger and duty sheet use.
	var viewer := office.document_viewer
	if not _a(viewer != null, "The office has a document viewer"): return
	var opened: Array[String] = []
	viewer.document_opened.connect(func(id: String) -> void: opened.append(id))
	shelf.get_interactable().interacted.emit()
	await process_frame
	if not _a(opened.has("bookshelf"),
			"Pressing E on the shelf opens a document (opened %s)" % str(opened)): return

	# The print is standing orders, so nothing in it may mention the night.
	var text := shelf.get_shelf_text()
	for secret in ["WATER", "WATCHER", "TRAIN 17", "FREIGHT 71", "CORRECTION FILED"]:
		if not _a(not text.contains(secret),
				"The shelf never mentions '%s' — it is standing orders, not tonight" % secret): return
	for expected in ["GENERAL ORDER", "TARIFF", "QUARANTINE"]:
		if not _a(text.contains(expected),
				"The shelf carries the division paperwork ('%s' present)" % expected): return
	# Plan 4.12: "44" is the ledger's freight rule and nothing else in the office;
	# a second "order 44" sent new operators to the wrong paper.
	if not _a(not text.contains("44"), "The shelf's general order is not numbered 44"): return

	office.queue_free()
	await process_frame
	print("--- All Bookshelf Inspect Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
