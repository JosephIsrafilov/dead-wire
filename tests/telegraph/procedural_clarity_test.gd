extends SceneTree

## D01: the paper standing orders explain how filing works, in the game's own
## terms, without naming the correct word or using the wire's sentence.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Procedural Clarity Test Suite ---")
	var header := String(load("res://scripts/telegraph/ui/duty_sheet.gd").get_script_constant_map()["HEADER"])
	if not assert_condition(header.contains("STANDING ORDERS"), "Duty sheet still carries standing orders"): return
	if not assert_condition(header.contains("AMEND COPY"), "Standing orders name the AMEND COPY action"): return
	if not assert_condition(header.contains("FILE AS COPIED"), "Standing orders name the FILE AS COPIED action"): return
	if not assert_condition(header.contains("Enter") and header.contains("Esc"), "Standing orders say what Enter and Esc do"): return
	if not assert_condition(not header.contains("WATER") and not header.contains("WATCHER"), "Standing orders never name either side of the surprise"): return
	if not assert_condition(header.contains("CLEAR EAST") and header.contains("HOLD") and header.contains("Dispatch Ledger"), "Standing orders point routing to the ledger and board"): return

	var flat := header.replace("\n", " ")
	while flat.contains("  "):
		flat = flat.replace("  ", " ")
	if not assert_condition(flat.contains("The line clock keeps running while you read or edit. A line warning means the decision is nearly due."), "Standing orders say the line clock keeps running while reading or editing"): return
	if not assert_condition(not flat.contains("sender does not wait") and not flat.contains("sender keeps waiting"), "Standing orders drop the contradictory sender-waiting claims"): return
	if not assert_condition(flat.contains("Enter sends your word to file."), "Standing orders say Enter sends the word to file"): return
	if not assert_condition(flat.contains("Esc puts the paper down and keeps your draft; nothing is filed."), "Standing orders say Esc keeps the draft and files nothing"): return
	if not assert_condition(not flat.contains("Enter files an amendment"), "Standing orders no longer use the vague Enter wording"): return

	print("--- All Procedural Clarity Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	_assertions_passed += 1
	print("  PASS: %s" % description)
	return true
