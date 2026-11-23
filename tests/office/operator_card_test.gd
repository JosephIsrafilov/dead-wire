extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	var card: Node = office.get_node_or_null("OperatorCard")
	if card == null:
		printerr("  FAIL: Operator card exists on the desk")
		quit(1)
		return
	print("  PASS: Operator card exists on the desk")
	card.get_node("Interactable").interact()
	if not office.document_viewer.is_open():
		printerr("  FAIL: Operator card opens the document viewer")
		quit(1)
		return
	print("  PASS: Operator card opens the document viewer")
	quit(0)

