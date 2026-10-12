extends SceneTree

## D02: the filing desk's scene defaults describe actions, not the answer, and
## stay hidden until a decision exists.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var desk := (load("res://scenes/telegraph/copy_commit_desk.tscn") as PackedScene).instantiate() as CopyCommitDesk
	var label1 := desk.get_node("OptionOneLabel") as Label3D
	var label2 := desk.get_node("OptionTwoLabel") as Label3D
	var combined := label1.text + label2.text
	var checks := {
		"Default amendment describes an action, not a supplied answer": label1.text == "AMEND COPY",
		"Default filing describes retaining handwriting": label2.text == "FILE AS COPIED",
		"Scene defaults never name either side of the surprise": not combined.contains("WATER") and not combined.contains("WATCHER"),
		"Actions are hidden before a decision exists": not label1.visible and not label2.visible,
	}
	var failed := false
	for text in checks:
		print(("  PASS: " if checks[text] else "  FAIL: ") + text)
		failed = failed or not checks[text]
	desk.free()
	quit(1 if failed else 0)
