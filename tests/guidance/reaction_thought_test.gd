extends SceneTree
## The room explaining itself in Elias's voice.
##
## The complaint this answers: "непонятно, что происходит вообще... рандомный
## набор непонятных звуков". A sound arrived, the player did not know what it
## was, and nothing in the game ever said. The guidance controller already
## existed for procedures; it had nothing to say about events.
##
## The contract these assertions protect:
##   1. A reaction is spoken for a real event and names only what the player
##      already saw, heard or did.
##   2. It never speaks over Morse, a document or a modal.
##   3. It goes stale instead of arriving late to describe a finished moment.
##   4. It never reads WorldState, so it can never reveal the answer.
##
##   godot --headless --audio-driver Dummy --path . --script tests/guidance/reaction_thought_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Reaction Thought Test Suite ---")
	var data := load("res://data/night_guidance/m1_guidance.tres") as NightGuidanceData
	if not _a(data != null, "Guidance data loads"): return

	# Plan 6.6: Elias does not explain what happened. The strange (foreign
	# traffic, a creak, a missed call) and the outcome of his own orders pass
	# in silence; the dawn handover's margin carries what he noticed. Reactions
	# stay authored content, so a later night can speak again without code.
	for kind in [&"call", &"answered", &"missed", &"signal_end", &"copy_done", &"routed", &"route_lapsed",
			&"foreign", &"creak"]:
		if not _a(data.reaction_for(kind).is_empty(), "Event '%s' passes without an explanation" % kind): return
	# The procedural thoughts that remain never quote, name or grade the answer.
	for entry in data.entries:
		var line: String = entry.get("text", "")
		for secret in ["WATER", "WATCHER", "true_message", "correct", "incorrect", "you failed", "wrong"]:
			if not _a(not line.to_lower().contains(secret.to_lower()),
					"Thought '%s' never leaks '%s'" % [entry.get("id", &""), secret]): return
	# The mechanism itself is exercised on a local night that does react.
	data = data.duplicate(true) as NightGuidanceData
	data.reactions = [
		{"id": &"call", "text": "The office call.", "duration": 7.0},
		{"id": &"signal_end", "text": "The wire is quiet.", "duration": 7.0},
		{"id": &"routed", "text": "The order is out.", "duration": 7.0},
	]

	# The unknown event is silent: no reaction is invented for a sound the
	# design did not decide to explain.
	if not _a(data.reaction_for(&"no_such_event").is_empty(), "Unknown events produce no reaction"): return

	# A reaction says only what is observable. "WATER" is the core hook's true
	# text; no reaction may quote it, name the answer, or grade the operator.
	var hidden := ["WATER", "WATCHER", "true_message", "correct", "incorrect", "you failed", "wrong"]
	for entry in data.reactions:
		var text: String = entry.get("text", "")
		for secret in hidden:
			if not _a(not text.to_lower().contains(secret.to_lower()),
					"Reaction '%s' never leaks '%s'" % [entry.get("id", &""), secret]): return

	# Behaviour: a reaction outranks a pending procedure, then clears.
	var script = load("res://scripts/office/night_guidance_controller.gd")
	var guidance = script.new()
	guidance.data = data
	guidance.set_context(&"entry", false)
	guidance.react(&"call")
	guidance.advance_guidance(0.1)
	if not _a(guidance.current_text == data.reaction_for(&"call").get("text", ""),
			"A queued reaction speaks immediately when the operator is free"): return
	if not _a(not guidance.current_text.contains("Lamp first"),
			"The reaction outranks the procedural reminder"): return

	# It expires on its own; the procedure then gets the floor back.
	guidance.advance_guidance(8.0)
	if not _a(guidance.current_text.is_empty(), "The reaction clears when its duration runs out"): return

	# Blocked: the wire owns the room. A reaction must not appear over Morse.
	guidance.set_context(&"entry", true)
	guidance.react(&"signal_end")
	guidance.advance_guidance(0.1)
	if not _a(guidance.current_text.is_empty(), "No reaction is spoken while a protected surface owns the screen"): return

	# Stale: the moment passed while blocked, so the thought is dropped rather
	# than spoken late about something already over.
	guidance.set_context(&"entry", false)
	guidance.advance_guidance(9.0)
	if not _a(guidance.current_text.is_empty() or not guidance.current_text.contains("quiet"),
			"A reaction older than the stale window is not spoken late"): return

	# Disabled help stays disabled: turning contextual thoughts off must silence
	# reactions too, not just procedures.
	guidance.enabled = false
	guidance.react(&"routed")
	guidance.advance_guidance(0.1)
	if not _a(guidance.current_text.is_empty(), "Disabling contextual thoughts suppresses reactions"): return

	guidance.free()
	print("--- All Reaction Thought Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
