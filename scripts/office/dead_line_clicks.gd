class_name DeadLineClicks
extends Node

## The dead line's own noise (plan 4.10, horror layer §5): once in each of the
## first two silences the sounder drops a single stray mark. It goes out as real
## traffic through the scheduler, so the sounder clicks and the register inks
## one honest MARK - the register still knows no text. One dot is not a call
## ("CR CR"), it never plays over a live telegram or in a hush, and silence 3
## stays clean for what happens there.

@export var click_text: String = "E"
## Seconds into silence 1 and silence 2 (by slot index) for the stray click.
@export var click_after_seconds: PackedFloat32Array = PackedFloat32Array([9.0, 33.0])

var director: ShiftDirector = null
var clicks_sent: int = 0

var _played: Dictionary = {}

func _ready() -> void:
	var office := get_parent()
	if director == null and office != null:
		director = office.get_node_or_null("ShiftDirector") as ShiftDirector

func _process(_delta: float) -> void:
	if director == null or director.get_phase() != ShiftDirector.Phase.WAITING:
		return
	update(director.get_slot_index(), director.get_phase_timer())

## True when the click went out on the wire this call.
func update(slot: int, seconds_into_silence: float) -> bool:
	if director == null or slot < 0 or slot >= click_after_seconds.size() or _played.has(slot):
		return false
	if seconds_into_silence < click_after_seconds[slot]:
		return false
	if director.send_stray_on_wire(click_text) <= 0.0:
		return false
	_played[slot] = true
	clicks_sent += 1
	return true
