class_name FairnessGate
extends Node

## Plan 7.7, GDD §7: critical Morse is always readable. While a critical copy
## is on the wire, the buses that are not the telegraph — the room and the
## foley (clock, feed, pen, chair, the operator's own steps) — are ducked on
## a short attack and a slower release, so the room steps back while the
## sounder speaks and comes back after. The whole telegram is ducked rather
## than each mark, so nothing pumps between dots. The Events bus (the steps
## beyond the door, a designed attention beat) and the Telegraph bus are
## never touched, and the player's own bus volumes stay theirs: the gate is
## an effect of its own on each bus, taken off when the office goes.

const DUCKED_BUSES: Array[StringName] = [&"Ambience", &"Foley"]

@export var office: M1OfficeController
@export var duck_db: float = -20.0
@export var attack_seconds: float = 0.12
@export var release_seconds: float = 0.8

var _gain_db: float = 0.0
## Untyped on purpose: the buses also hold other effects (the Foley reverb),
## and a typed array refuses to be searched for them.
var _effects: Array = []

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController

## Installed on every entry, not once in _ready: the office is reparented into
## its presentation frame after it loads, and that exit takes the effects off.
func _enter_tree() -> void:
	if not _effects.is_empty():
		return
	for bus_name in DUCKED_BUSES:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0:
			continue
		var effect := AudioEffectAmplify.new()
		effect.resource_name = "FairnessGate"
		effect.volume_db = _gain_db
		AudioServer.add_bus_effect(bus, effect)
		_effects.append(effect)

func _exit_tree() -> void:
	for bus_name in DUCKED_BUSES:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0:
			continue
		for index in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, index) in _effects:
				AudioServer.remove_bus_effect(bus, index)
	_effects.clear()

func get_duck_db() -> float:
	return _gain_db

## A critical telegram (not a call, nag or closing sign) is playing now.
func is_critical_live() -> bool:
	var session := office.session_controller if office != null else null
	if session == null or session.scheduler == null:
		return false
	var scenario := session.get_current_scenario()
	var telegram := session.get_active_telegram_schedule()
	return scenario != null and scenario.critical_copy and telegram != null \
		and session.scheduler.is_playing() and session.scheduler.get_active_schedule() == telegram

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var target := duck_db if is_critical_live() else 0.0
	var seconds := attack_seconds if target < _gain_db else release_seconds
	var rate := absf(duck_db) / maxf(seconds, 0.001)
	_gain_db = move_toward(_gain_db, target, rate * maxf(delta, 0.0))
	for effect in _effects:
		effect.volume_db = _gain_db
