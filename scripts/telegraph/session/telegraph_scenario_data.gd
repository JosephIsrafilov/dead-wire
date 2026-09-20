class_name TelegraphScenarioData
extends Resource

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
@export var commit_lapsed_world_fact: String = ""
@export var commit_lapsed_knowledge_fact: String = ""
@export var consequence_event_id: String = ""
@export var consequence_delay_seconds: float = 0.0
@export var consequence_hold_seconds: float = 0.0

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

	if consequence_delay_seconds < 0.0 or not is_finite(consequence_delay_seconds):
		errors.append("consequence_delay_seconds must be non-negative finite")
	if consequence_hold_seconds < 0.0 or not is_finite(consequence_hold_seconds):
		errors.append("consequence_hold_seconds must be non-negative finite")

	return errors
