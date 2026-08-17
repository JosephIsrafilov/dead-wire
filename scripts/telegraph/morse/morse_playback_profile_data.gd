class_name MorsePlaybackProfileData
extends Resource

@export var seconds_per_unit: float = 0.10

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if is_nan(seconds_per_unit):
		errors.append("seconds_per_unit cannot be NaN")
		return errors

	if is_inf(seconds_per_unit) or not is_finite(seconds_per_unit):
		errors.append("seconds_per_unit must be a finite number")
		return errors

	if seconds_per_unit <= 0.0:
		errors.append("seconds_per_unit must be greater than 0.0, got %f" % seconds_per_unit)

	return errors
