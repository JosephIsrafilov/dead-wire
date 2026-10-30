extends SceneTree

## Plan 6.4: a document lifted from the desk and put back down, caught mid-
## motion. Windowed only. Writes .dream-loop/document_lift/<stage>.png.
##
##   godot --path . --resolution 1920x1080 --script tools/document_lift_capture.gd

const OUT_DIR := "res://.dream-loop/document_lift"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var viewer := office.document_viewer
	viewer.open_document("duty_sheet", "OPERATOR'S DUTY SHEET", DutySheet.new().get_sheet_text(), "[E / Esc] Put Down")
	await create_timer(viewer.open_duration * 0.4).timeout
	await _shot("1_lifting")
	await create_timer(viewer.open_duration).timeout
	await _shot("2_held")
	viewer.close_document()
	await create_timer(viewer.put_down_duration * 0.5).timeout
	await _shot("3_putting_down")
	await create_timer(viewer.put_down_duration).timeout
	await _shot("4_down")
	quit(0)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("SHOT ", label, " ", root.get_texture().get_image().save_png(OUT_DIR.path_join(label + ".png")))
