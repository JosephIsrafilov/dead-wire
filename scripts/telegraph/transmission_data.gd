class_name TransmissionData
extends Resource

@export var transmission_id: StringName = &""
@export_multiline var true_message: String = ""
@export_multiline var elias_perception: String = ""
@export_multiline var written_transcript: String = ""

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if transmission_id.is_empty():
		errors.append("transmission_id is empty")
	if true_message.is_empty():
		errors.append("true_message is empty")
	if elias_perception.is_empty():
		errors.append("elias_perception is empty")
	if written_transcript.is_empty():
		errors.append("written_transcript is empty")
	return errors
