class_name RouteAction
extends RefCounted
## Shared vocabulary; authority and physical presentation both still validate input.
const CLEAR_EAST: String = "CLEAR EAST"
const HOLD: String = "HOLD"
const ACCEPTED: Array[String] = [CLEAR_EAST, HOLD]
static func is_valid(action: String) -> bool:
	return action in ACCEPTED
