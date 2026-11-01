class_name DawnRitual
extends Node

## The end of the watch as a moment in the room, not a card.
##
## When the line closes for the night the register's clockwork stops, the
## moonlight in the north pane turns slowly into morning, the lamp is offered
## to be turned down for the day man, and the ledger to be closed. Nothing is
## forced: the operator can simply walk out, and the dawn comes anyway.

@export var director: ShiftDirector = null
@export var moon: MoonWeather = null
@export var lamp_life: LampLife = null
@export var register: TapeRegisterController = null
## Plan 9.6: the watch is closed in the ledger, by hand, if the operator wants.
@export var ledger: DispatchLedger = null

var has_begun: bool = false

func _ready() -> void:
	var office := get_parent()
	if office != null:
		if director == null:
			director = office.get_node_or_null("ShiftDirector") as ShiftDirector
		if moon == null:
			moon = office.get_node_or_null("MoonWeather") as MoonWeather
		if lamp_life == null:
			lamp_life = office.get_node_or_null("LampLife") as LampLife
		if register == null:
			register = office.get_node_or_null("TelegraphSessionController/TapeRegister") as TapeRegisterController
		if ledger == null:
			ledger = office.get_node_or_null("DispatchLedger") as DispatchLedger
	if director != null and not director.phase_changed.is_connected(_on_phase_changed):
		director.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(new_phase: ShiftDirector.Phase, _previous: ShiftDirector.Phase) -> void:
	if new_phase == ShiftDirector.Phase.SHIFT_OVER:
		begin()

func begin() -> void:
	if has_begun:
		return
	has_begun = true
	if register != null:
		register.line_live = false
	if moon != null:
		moon.begin_dawn()
	if lamp_life != null:
		lamp_life.offer_turn_down()
	if ledger != null:
		ledger.offer_close()
