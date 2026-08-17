class_name TelegraphScenarioData
extends Resource

@export var scenario_id: String = ""
@export var transmission_data: TransmissionData = null
@export var requires_routing: bool = false
@export var expected_routing_action: String = ""
@export var correct_world_fact: String = ""
@export var incorrect_world_fact: String = ""
@export var attention_event_id: String = ""
@export var attention_event_start_time: float = 0.0
@export var completion_fact: String = ""

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

	return errors
