extends SceneTree

## Knowledge after a correction is a BELIEF, not a grade.
##
## When Elias types the word he heard, the room lets him believe he has copied
## the message correctly. That belief is recorded — his morning handover needs
## it — but it is never the world's verdict, and it is never derived from
## `true_message`. The two tests below are the whole distinction:
##
##   1. A night where perception and truth disagree (fixture ALPHA / BRAVO /
##      CHARLIE) must seal BRAVO — what he heard — and must leave the objective
##      facts and the world's own answer untouched.
##   2. A night where perception and truth agree seals the same fact, so the
##      seal cannot be used to tell the two nights apart. That is exactly why
##      it is not grading.
##
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/knowledge_seal_test.gd

var _assertions: int = 0

const SEAL: StringName = &"committed_water_core_hook"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Knowledge Seal Test Suite ---")
	if not await _disagreeing_night(): return
	if not await _agreeing_night(): return
	print("--- All Knowledge Seal Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Perception BRAVO, truth ALPHA. Typing BRAVO is Elias copying what he heard.
func _disagreeing_night() -> bool:
	var session := TelegraphSessionController.new()
	root.add_child(session)
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var scenario := _layered_scenario()
	if not _a(scenario != null, "The layered fixture builds a valid scenario"): return false
	if not _a(scenario.get_validation_errors().is_empty(),
			"The fixture is a well-formed scenario (%s)" % str(scenario.get_validation_errors())): return false
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.submit_amendment("BRAVO"), "The heard word is accepted as a correction"): return false
	if not _a(knowledge.knows(SEAL),
			"Typing what he heard seals his own copy, even when the wire said something else"): return false
	if not _a(knowledge.recall_value(&"filed_word_fixture") == "BRAVO",
			"The remembered word is the one he typed, not the true message"): return false
	# The objective store is the only place that knows what the wire really said,
	# and the correction did not touch it.
	if not _a(world.get_fact(&"core_hook_filed_word", "") == "BRAVO",
			"The objective filed word is exactly what was filed"): return false
	if not _a(not world.get_fact(&"fixture_filed_true", false),
			"Filing a heard word never asserts the true-message outcome"): return false
	session.queue_free()
	await process_frame
	return true

## Perception and truth agree. The same fact is sealed — so the seal is not a
## way to tell a good night from a bad one.
func _agreeing_night() -> bool:
	var session := TelegraphSessionController.new()
	root.add_child(session)
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var scenario := _layered_scenario("ALPHA")
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.submit_amendment("ALPHA"), "An agreeing word is accepted as a correction"): return false
	if not _a(knowledge.knows(SEAL), "The agreeing night seals the same fact"): return false
	if not _a(knowledge.snapshot().keys().size() == 2,
			"Both nights leave the same two knowledge facts (%s)" % str(knowledge.snapshot().keys())): return false
	session.queue_free()
	await process_frame
	return true

## ALPHA / BRAVO / CHARLIE, or ALPHA / ALPHA / CHARLIE when the perception is
## set to match the truth. Built in code so the fixture stays a three-layer
## example and never doubles as a night of the campaign.
func _layered_scenario(perception: String = "BRAVO") -> TelegraphScenarioData:
	var transmission := TransmissionData.new()
	transmission.transmission_id = &"fixture_layers"
	transmission.true_message = "ALPHA"
	transmission.elias_perception = perception
	transmission.written_transcript = "CHARLIE"
	var seal := TelegraphCommitOption.new()
	seal.action_id = &"amend_copy"
	seal.display_label = "AMEND COPY"
	seal.requires_correction = true
	seal.world_fact = "fixture_filed_heard"
	seal.knowledge_fact = String(SEAL)
	seal.result_text = "CORRECTION FILED"
	var keep := TelegraphCommitOption.new()
	keep.action_id = &"file_as_copied"
	keep.display_label = "FILE AS COPIED"
	keep.world_fact = "fixture_filed_charley"
	keep.knowledge_fact = "fixture_committed_charley"
	keep.result_text = "COPY FILED"
	var scenario := TelegraphScenarioData.new()
	scenario.scenario_id = "fixture_layered"
	scenario.transmission_data = transmission
	scenario.requires_transcript_verification = true
	scenario.commit_options = [seal, keep]
	scenario.commit_deadline_seconds = 30.0
	scenario.amendment_wrong_world_fact = "fixture_amended_other"
	scenario.amendment_knowledge_fact = "fixture_amendment_entered"
	scenario.filed_word_world_fact = "core_hook_filed_word"
	scenario.filed_word_knowledge_key = "filed_word_fixture"
	return scenario

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
