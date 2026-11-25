class_name SilenceThree
extends Node

## Silence 3: the window asks (plan 4.2, 4.9).
##
## In the quiet before the third call the lamp's own wick chars and sinks, so
## the north pane stops being a mirror of the room (WindowGlassMirror) and the
## yard comes through. Later in the same silence a figure stands in the yard:
## it appears only between observations and is held into the call, so the call
## begins while it may still be there. Trimming the wick gives the light back
## and the pane goes back to being a mirror - the player's choice, every time.
##
## Nothing here touches an object on the figure's behalf (GDD §10): the wick
## sinks because it burned; the figure stands, and is gone when no one looks.
## It runs on the shift director's own clock, so it is deterministic and stops
## when the director stops.

@export var slot_index: int = 2
## Seconds into the silence when the wick begins to char.
@export var gutter_after_seconds: float = 24.0
## How long the wick takes to sink to its floor.
@export var gutter_seconds: float = 9.0
## Seconds into the silence when the figure is put in the yard.
@export var figure_after_seconds: float = 36.0
## How long the figure is held past the first call.
@export var figure_linger_seconds: float = 10.0
## WorldState: it stood there. Separate from the filing consequence's fact.
@export var world_fact_id: StringName = &"silence_three_figure_stood"
## KnowledgeState: Elias looked out and the yard was clear to him. The handover
## margin writes its own line for this (plan 4.7).
const KNOWLEDGE_SAW_YARD: StringName = &"saw_yard_before_last_call"
@export var knowledge_fact_id: StringName = KNOWLEDGE_SAW_YARD

var lamp: LampLife = null
var figure: AttentionObservationTarget = null
var director: ShiftDirector = null

var _guttered: bool = false
var _figure_placed: bool = false

func _ready() -> void:
	var office := get_parent()
	if office == null:
		return
	if lamp == null:
		lamp = office.get_node_or_null("LampLife") as LampLife
	if figure == null:
		figure = office.get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	if director == null:
		director = office.get_node_or_null("ShiftDirector") as ShiftDirector

func _process(_delta: float) -> void:
	if director == null or director.get_phase() != ShiftDirector.Phase.WAITING:
		return
	update(director.get_slot_index(), director.get_phase_timer(), director.get_current_wait_seconds())

## Where the night is: which silence, how far into it, how long it lasts.
func update(slot: int, seconds_into_silence: float, silence_seconds: float) -> void:
	if slot != slot_index:
		return
	if not _guttered and seconds_into_silence >= gutter_after_seconds:
		_guttered = true
		if lamp != null:
			lamp.gutter(lamp.sink_floor, gutter_seconds)
	if not _figure_placed and seconds_into_silence >= figure_after_seconds:
		_figure_placed = true
		if figure != null:
			# Stage B (Stage 1.1): the close one, three to four metres beyond the
			# bay window, where the wick has just sunk and the pane has stopped
			# being a mirror. The far-fence figure belongs to Miller's knock, not
			# to this silence, so the stage is stated even though it is the default:
			# a night that has already had Stage A must not carry its position here.
			if figure.has_method("set_stage"):
				figure.call("set_stage", 0)
			var hold := maxf(silence_seconds - seconds_into_silence, 0.0) + figure_linger_seconds
			figure.trigger_event(hold, world_fact_id, knowledge_fact_id)
