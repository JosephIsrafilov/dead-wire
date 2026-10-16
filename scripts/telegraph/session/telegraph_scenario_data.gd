class_name TelegraphScenarioData
extends Resource

## Commit-outcome ids for per-outcome consequence events (ROADMAP 2.2). One
## registry: the session resolves decisions to these, scenario .tres files map
## them to attention-event ids, and no code hardcodes an outcome string.
const OUTCOME_FILED_AS_COPIED := &"filed_as_copied"
const OUTCOME_AMENDED_TRUE := &"amended_true"
const OUTCOME_AMENDED_OTHER := &"amended_other"
const OUTCOME_LAPSED := &"lapsed"
const OUTCOME_IDS := [
	OUTCOME_FILED_AS_COPIED, OUTCOME_AMENDED_TRUE,
	OUTCOME_AMENDED_OTHER, OUTCOME_LAPSED,
]

@export var scenario_id: String = ""
@export var transmission_data: TransmissionData = null
@export var requires_routing: bool = false
@export var expected_routing_action: String = ""
@export var correct_world_fact: String = ""
@export var incorrect_world_fact: String = ""
## A routing lapse ("NO ORDER") is its own outcome, not a wrong order. Legacy
## resources may leave these empty; M1 routing scenarios fill them.
@export var routing_lapsed_world_fact: String = ""
@export var routing_lapsed_knowledge_fact: String = ""
@export var attention_event_id: String = ""
@export var attention_event_start_time: float = 0.0
@export var completion_fact: String = ""

## Legacy scenarios may leave this false. M1 scenarios opt into the universal
## inspect-before-decision gate explicitly.
@export var requires_transcript_verification: bool = false
## Normalized timestamps for each non-space glyph in written_transcript.
## An empty array keeps the legacy ratio fallback for unmigrated resources.
@export var transcript_reveal_cues: PackedFloat32Array = PackedFloat32Array()
@export var commit_options: Array[TelegraphCommitOption] = []
## Seconds the sender waits after t0 before releasing the line. Negative
## defers to the session's fallback; zero disables the deadline.
@export var commit_deadline_seconds: float = -1.0
@export var commit_lapsed_world_fact: String = ""
@export var commit_lapsed_knowledge_fact: String = ""
@export var consequence_event_id: String = ""
@export var consequence_delay_seconds: float = 0.0
@export var consequence_hold_seconds: float = 0.0
## Consequence event per commit outcome (keys = OUTCOME_* ids, values =
## attention-event ids). An outcome missing from the map falls back to
## consequence_event_id, so legacy scenarios keep working untouched.
@export var consequence_events_by_outcome: Dictionary = {}
## The sender's parting word per commit outcome (keys = OUTCOME_* ids, values
## = wire text, optionally a "{word}" template quoting the filed word). Rides
## out with the closing sign as one schedule; a template the M1 alphabet
## cannot carry falls back to wire_reply_fallback.
@export var wire_reply_by_outcome: Dictionary = {}
@export var wire_reply_fallback: String = ""
## An amendment's unknown/wrong valid text remains a terminal choice, not a fallback.
@export var amendment_wrong_world_fact: String = ""
@export var amendment_knowledge_fact: String = ""
@export var filed_word_world_fact: String = ""
@export var filed_word_knowledge_key: String = ""
@export var amendment_result_text: String = "CORRECTION FILED"
@export var critical_copy: bool = false

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if scenario_id.is_empty():
		errors.append("scenario_id cannot be empty")

	if transmission_data == null:
		errors.append("transmission_data cannot be null")
	else:
		var trans_errors := transmission_data.get_validation_errors()
		for err in trans_errors:
			errors.append("Invalid transmission_data: %s" % err)

	if requires_routing:
		if expected_routing_action.is_empty():
			errors.append("requires_routing is true but expected_routing_action is empty")
		if correct_world_fact.is_empty():
			errors.append("requires_routing is true but correct_world_fact is empty")
		if incorrect_world_fact.is_empty():
			errors.append("requires_routing is true but incorrect_world_fact is empty")

	if not attention_event_id.is_empty():
		if attention_event_start_time < 0.0 or not is_finite(attention_event_start_time):
			errors.append("attention_event_start_time must be non-negative finite")

	if not transcript_reveal_cues.is_empty() and transmission_data != null:
		var glyph_count := 0
		for character in transmission_data.written_transcript:
			if character not in [" ", "\t", "\n", "\r"]:
				glyph_count += 1
		if transcript_reveal_cues.size() != glyph_count:
			errors.append("transcript_reveal_cues must contain one cue per non-space glyph (%d expected)" % glyph_count)
		var previous := -1.0
		for cue in transcript_reveal_cues:
			if not is_finite(cue) or cue < 0.0 or cue > 1.0:
				errors.append("transcript_reveal_cues must contain finite values in [0, 1]")
				break
			if cue < previous:
				errors.append("transcript_reveal_cues must be monotonic")
				break
			previous = cue

	var commit_ids := {}
	if not commit_options.is_empty() and not requires_transcript_verification:
		errors.append("commit_options require transcript verification")
	if commit_options.size() == 1:
		errors.append("commit_options must contain at least two options")
	for option in commit_options:
		if option == null:
			errors.append("commit_options cannot contain null")
			continue
		for err in option.get_validation_errors():
			errors.append("Invalid commit option: %s" % err)
		if commit_ids.has(option.action_id):
			errors.append("commit_options action_id values must be unique")
		commit_ids[option.action_id] = true

	if not is_finite(commit_deadline_seconds):
		errors.append("commit_deadline_seconds must be finite")
	if consequence_delay_seconds < 0.0 or not is_finite(consequence_delay_seconds):
		errors.append("consequence_delay_seconds must be non-negative finite")
	if consequence_hold_seconds < 0.0 or not is_finite(consequence_hold_seconds):
		errors.append("consequence_hold_seconds must be non-negative finite")
	for outcome_key in consequence_events_by_outcome.keys():
		if StringName(str(outcome_key)) not in OUTCOME_IDS:
			errors.append("consequence_events_by_outcome has unknown outcome '%s'" % str(outcome_key))
		var event_value: Variant = consequence_events_by_outcome[outcome_key]
		if not (event_value is String) or (event_value as String).is_empty():
			errors.append("consequence_events_by_outcome['%s'] must be a non-empty event id" % str(outcome_key))
	for reply_key in wire_reply_by_outcome.keys():
		if StringName(str(reply_key)) not in OUTCOME_IDS:
			errors.append("wire_reply_by_outcome has unknown outcome '%s'" % str(reply_key))
		var reply_value: Variant = wire_reply_by_outcome[reply_key]
		if not (reply_value is String) or (reply_value as String).is_empty():
			errors.append("wire_reply_by_outcome['%s'] must be a non-empty reply text" % str(reply_key))

	var amendment_count := 0
	for option in commit_options:
		if option != null and option.requires_correction:
			amendment_count += 1
	if amendment_count > 1:
		errors.append("Only one amendment action is supported per scenario")
	if amendment_count == 1:
		if amendment_wrong_world_fact.is_empty() or amendment_knowledge_fact.is_empty():
			errors.append("Amendment requires authored wrong outcome and neutral knowledge fact")
		if filed_word_world_fact.is_empty() or filed_word_knowledge_key.is_empty():
			errors.append("Amendment requires independent filed-word keys")
		if amendment_result_text.is_empty():
			errors.append("Amendment requires neutral result text")
	return errors
