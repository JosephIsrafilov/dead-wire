extends SceneTree

## The station call is an exchange, not a noise.
##
## Churchill (Theory and Practice of the Electric Telegraph, 1875, pp. 69–70)
## describes the real shape: a station hears its own call sign, ANSWERS, the
## caller repeats and signs its own call, and the message begins only after the
## receiving operator has answered. M1 had the first and last beats — a call
## sign and a message — and no acknowledgement in between: the operator pressed
## the key and the sender simply started talking.
##
## Pinned here: the office answers with a signal of its own on the same wire,
## the answer rides the same encoder the traffic does (so it is real American
## Morse and inks the same register), and a message cannot begin before it.
## There is deliberately no telephone bell anywhere in this procedure.
##
##   godot --headless --audio-driver Dummy --path . --script tests/office/station_call_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Station Call Test Suite ---")
	if not await _signs_are_sendable(): return
	if not await _answer_precedes_the_message(): return
	if not await _unanswered_call_never_receives(): return
	print("--- All Station Call Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Both service signals have to be spellable in the eighteen characters M1
## carries, or the call is silence on a wire the player is meant to read.
func _signs_are_sendable() -> bool:
	var director := ShiftDirector.new()
	root.add_child(director)
	var encoder := AmericanMorseEncoder.new()
	var call_sequence := encoder.encode(director.call_sign, director.alphabet)
	if not _a(call_sequence != null, "The call sign is sendable in the M1 alphabet ('%s')" % director.call_sign): return false
	var answer_sequence := encoder.encode(director.answer_sign, director.alphabet)
	if not _a(answer_sequence != null, "The operator's answer is sendable ('%s')" % director.answer_sign): return false
	if not _a(not director.answer_sign.is_empty(), "The office has an answer sign at all"): return false
	if not _a(director.answer_sign != director.call_sign,
			"Answering is not the same act as being called ('%s' vs '%s')" % [director.answer_sign, director.call_sign]): return false
	director.queue_free()
	await process_frame
	return true

## The real exchange, driven through the director's own phases.
func _answer_precedes_the_message() -> bool:
	var office := await _office()
	if office == null: return false
	var director := office.shift_director
	if not _a(director != null, "The office carries a shift director"): return false
	director.enabled = true
	director.open_line()
	await process_frame
	if not _a(director.get_phase() == ShiftDirector.Phase.WAITING, "Opening the line starts the watch"): return false

	var calls: Array[int] = []
	var answers: Array[int] = []
	# Phases seen, in order. A GDScript lambda captures ints by value, so the
	# record has to be an array.
	var phases: Array[int] = []
	director.call_started.connect(func(_slot: int, _n: int) -> void: calls.append(1))
	director.call_answered.connect(func(_slot: int, _n: int) -> void: answers.append(1))
	director.phase_changed.connect(func(next: ShiftDirector.Phase, _prev: ShiftDirector.Phase) -> void: phases.append(int(next)))
	# The wire's own record: the acknowledgement must be a real take.
	var register := office.session_controller.get_tape_register()
	if not _a(register != null, "The office carries a tape register"): return false
	var takes_before: int = register.get_record().size()
	if not _a(takes_before >= 0, "The register reports its ink"): return false

	director.advance(director.wait_seconds_before_call[0] + 0.1)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING, "The wire calls"): return false
	if not _a(calls.size() >= 1, "A call was sent (%d)" % calls.size()): return false
	if not _a(answers.is_empty(), "Nobody has answered yet"): return false

	# The operator answers with the key. This is the act the player performs.
	director._on_key_pressed()
	await process_frame
	if not _a(answers.size() == 1, "Pressing the key answers the call exactly once"): return false
	if not _a(director.get_phase() == ShiftDirector.Phase.ANSWERING,
			"Answering opens its own beat before the message (phase %d)" % director.get_phase()): return false
	# The acknowledgement is on the wire, not in the director's head: it is a
	# real schedule the same sounder plays and the same register inks.
	if not _a(office.session_controller.scheduler.is_playing(),
			"The office's answer is a transmission of its own"): return false
	var answered_schedule := office.session_controller.scheduler.get_active_schedule()
	if not _a(answered_schedule != null and answered_schedule.total_duration_seconds > 0.0,
			"The answer is a compiled schedule, not a placeholder"): return false
	var answer_seconds: float = answered_schedule.total_duration_seconds

	# And the message waits for it.
	if not _a(director.get_phase() != ShiftDirector.Phase.RECEIVING,
			"The message has not begun during the acknowledgement"): return false
	# The beat is counted from the END of the acknowledgement, so the wait is the
	# answer's own duration plus the beat. Step it in frames rather than in one
	# leap, so the ordered phase record below is the real sequence.
	var stepped := 0.0
	var limit := answer_seconds + director.answer_beat_seconds + 2.0
	while stepped < limit and not phases.has(int(ShiftDirector.Phase.RECEIVING)):
		director.advance(1.0 / 30.0)
		stepped += 1.0 / 30.0
	if not _a(phases.has(int(ShiftDirector.Phase.RECEIVING)),
			"The message begins after the acknowledgement is done (saw %s)" % str(phases)): return false
	# And in that order: ANSWERING is reached before RECEIVING, never after.
	var answer_index := phases.find(int(ShiftDirector.Phase.ANSWERING))
	var receive_index := phases.find(int(ShiftDirector.Phase.RECEIVING))
	if not _a(answer_index >= 0 and receive_index > answer_index,
			"The acknowledgement comes before the message, not after it"): return false
	# And the answer really inked: the tape now holds more than it did.
	var takes_after: int = register.get_record().size()
	if not _a(takes_after > takes_before,
			"The operator's answer inks the register (%d -> %d events)" % [takes_before, takes_after]): return false
	office.queue_free()
	await process_frame
	return true

## An ignored call is still never received: the acknowledgement is the gate.
func _unanswered_call_never_receives() -> bool:
	var office := await _office()
	if office == null: return false
	var director := office.shift_director
	director.enabled = true
	director.open_line()
	await process_frame
	director.advance(director.wait_seconds_before_call[0] + 0.1)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING, "The wire calls"): return false
	# Never press the key. Let the whole call window run out.
	for _i in 40:
		director.advance(0.25)
	if not _a(director.get_phase() != ShiftDirector.Phase.RECEIVING,
			"An unanswered call never turns into a received message"): return false
	office.queue_free()
	await process_frame
	return true

func _office() -> M1OfficeController:
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not _a(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not _a(office != null, "Office instantiates"): return null
	root.add_child(office)
	await process_frame
	await process_frame
	return office

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
