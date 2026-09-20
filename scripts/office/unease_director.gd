class_name UneaseDirector
extends Node3D

## Atmosphere, not events.
##
## Two techniques, both from how horror games actually build dread rather than
## from jump scares:
##
## 1. **The delayed creak.** When the operator stops moving, the building settles
##    a beat later. The canonical example in the literature is a floorboard
##    creaking about two seconds after the player stops — long enough that it
##    reads as a separate thing happening, not as his own footstep.
##
## 2. **Silence before the wire.** A continuous ambient bed conditions the player
##    and dulls fear; well-placed silence makes them distrust their own ears.
##    Once per watch — before the first call of the first message — the room goes
##    quiet so the sounder breaks silence rather than competing with wind.
##
## Neither is the Listener. GDD §10 holds: nothing here moves an object, and a
## settling timber building is a complete explanation on its own.

signal creaked(position: Vector3)

@export var office: M1OfficeController = null
@export var ambience: OfficeAmbience = null
@export var director: ShiftDirector = null

## Physical places a building can settle: Marker3D children of this node
## (floorboards, a beam, corners, a wall section). Empty when wired to a scene
## without markers, in which case creaks are skipped rather than invented.
@export var creak_anchor_paths: Array[NodePath] = []

@export var creak_streams: Array[AudioStream] = [
	preload("res://audio/sfx/foley/floor_creak_1.wav"),
	preload("res://audio/sfx/foley/floor_creak_2.wav"),
	preload("res://audio/sfx/foley/floor_creak_3.wav")
]
@export var creak_bus: StringName = &"Ambience"
@export var creak_volume_db: float = -14.0

## How long the operator must be still before the building answers.
@export var creak_dwell_seconds: float = 2.0
## Not every stop creaks. A guaranteed creak is a mechanic; an occasional one is
## a house.
@export var creak_chance: float = 0.45
## A creak never repeats the previous anchor.
@export var creak_min_separation: float = 1.4
@export var creak_cooldown_seconds: float = 9.0
## An anchor this close to the operator's own feet is not a candidate: the
## building settles elsewhere, not under him.
@export var creak_min_player_distance: float = 0.8

## Duck the bed to near-silence this long before the first call lands.
@export var pre_call_hush_seconds: float = 2.2
@export var hush_depth_db: float = -26.0
@export var hush_recover_seconds: float = 1.6

var creaks_played: int = 0
var is_hushed: bool = false
## The pre-call hush happens once per watch, before the first call of slot 0.
var first_call_hush_done: bool = false

var _dwell: float = 0.0
var _cooldown: float = 0.0
var _armed: bool = false
var _creak_anchors: Array[Marker3D] = []
var _last_creak_index: int = -1
var _last_creak_position: Vector3 = Vector3(9999.0, 0.0, 9999.0)
var _rng := RandomNumberGenerator.new()
var _creak_player: AudioStreamPlayer3D = null
var _hush_tween: Tween
var _hush_elapsed: float = 0.0

func _ready() -> void:
	_rng.seed = 18940414
	_resolve()
	_build_player()

func _resolve() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	if office == null:
		return
	if ambience == null:
		ambience = office.get_node_or_null("OfficeAmbience") as OfficeAmbience
	if director == null:
		director = office.shift_director

## Anchors are real places in the room. One chosen anchor is one physical
## source; the selection never moves a point outside the room or invents one.
func _resolve_anchors() -> void:
	if not _creak_anchors.is_empty():
		return
	if not creak_anchor_paths.is_empty():
		for path in creak_anchor_paths:
			var marker := get_node_or_null(path) as Marker3D
			if marker != null:
				_creak_anchors.append(marker)
		return
	for child in get_children():
		if child is Marker3D:
			_creak_anchors.append(child)

func get_creak_anchors() -> Array[Marker3D]:
	_resolve_anchors()
	return _creak_anchors

func _build_player() -> void:
	if _creak_player != null:
		return
	_creak_player = AudioStreamPlayer3D.new()
	_creak_player.name = "CreakPlayer"
	_creak_player.bus = creak_bus
	_creak_player.volume_db = creak_volume_db
	_creak_player.max_distance = 12.0
	_creak_player.unit_size = 4.0
	add_child(_creak_player)


func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can drive the dwell timer directly.
func advance(delta: float) -> void:
	_resolve()
	if is_hushed:
		_hush_elapsed += delta
		if _hush_elapsed >= pre_call_hush_seconds:
			release_hush()
	_maybe_hush_before_first_call()
	_cooldown = maxf(0.0, _cooldown - delta)

	var player := office.player if office != null else null
	if player == null:
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed > 0.2:
		# Moving. Arm the creak so it can only fire after an actual stop.
		_dwell = 0.0
		_armed = true
		return

	if not _armed:
		return

	_dwell += delta
	if _dwell < creak_dwell_seconds:
		return

	_armed = false
	_dwell = 0.0
	if _critical_writing_window():
		# The wire has the room: no decorative settling during the core hook.
		return
	if _cooldown > 0.0:
		return
	if _rng.randf() > creak_chance:
		return
	_creak_at_anchor(player.global_position)

## Candidate anchors: every physical spot that is not the previous one, not
## under the operator's feet, and not within the minimum separation of the
## last creak. No candidates means the house simply stays quiet — no fallback
## point, no search loop, no creak through a wall.
func _creak_candidates(listener_position: Vector3) -> Array[int]:
	_resolve_anchors()
	var candidates: Array[int] = []
	for index in _creak_anchors.size():
		var anchor := _creak_anchors[index]
		if index == _last_creak_index:
			continue
		if anchor == null:
			continue
		var flat_delta := Vector2(
			anchor.global_position.x - listener_position.x,
			anchor.global_position.z - listener_position.z)
		if flat_delta.length() < creak_min_player_distance:
			continue
		if anchor.global_position.distance_to(_last_creak_position) < creak_min_separation:
			continue
		candidates.append(index)
	return candidates

func _creak_at_anchor(listener_position: Vector3) -> void:
	var candidates := _creak_candidates(listener_position)
	if candidates.is_empty():
		# Nothing suitable to settle: the event is skipped, not relocated.
		return
	var pick := candidates[_rng.randi_range(0, candidates.size() - 1)]
	var spot := _creak_anchors[pick].global_position
	_last_creak_index = pick
	_last_creak_position = spot
	creaks_played += 1
	_cooldown = creak_cooldown_seconds

	if _creak_player != null and not creak_streams.is_empty():
		_creak_player.stream = creak_streams[_rng.randi_range(0, creak_streams.size() - 1)]
		_creak_player.global_position = spot
		_creak_player.pitch_scale = _rng.randf_range(0.9, 1.12)
		_creak_player.play()

	creaked.emit(spot)

## The authored episode of silence: once per watch, in the existing WAITING
## stretch, when the first call of slot 0 is pre_call_hush_seconds away. A short
## wait simply starts the available part of the envelope — no negative timers,
## and the deadline structure is untouched. Repeats and later calls get no
## second hush.
func _maybe_hush_before_first_call() -> void:
	if first_call_hush_done or is_hushed:
		return
	if director == null or ambience == null:
		return
	if director.get_slot_index() != 0:
		return
	if director.get_phase() != ShiftDirector.Phase.WAITING:
		return
	if _critical_writing_window():
		return
	var remaining := director.get_current_wait_seconds() - director.get_phase_timer()
	if remaining > pre_call_hush_seconds:
		return
	first_call_hush_done = true
	hush()

## The core-hook letter is the one moment the design exists for: from the
## first differing glyph to the end of the copy, no new decorative creaks or
## hushes may compete with the Morse (plan §line 117). For a standing player
## the window is bounded by the grace, never infinite.
func _critical_writing_window() -> bool:
	if office == null or office.session_controller == null:
		return false
	var session := office.session_controller
	if session.get_current_scenario() == null:
		return false
	if session.get_current_scenario().scenario_id != "core_hook_water_watcher":
		return false
	return session.get_state() in [TelegraphSessionController.State.RECEIVING, TelegraphSessionController.State.COPYING]

## Drops the ambience bed so the sounder breaks silence rather than competing.
func hush() -> void:
	if ambience == null or is_hushed:
		return
	if _hush_tween != null:
		_hush_tween.kill()
	is_hushed = true
	_hush_elapsed = 0.0
	ambience.set_hush_db(hush_depth_db)

func release_hush() -> void:
	if not is_hushed:
		return
	is_hushed = false
	if ambience == null:
		return
	if not is_inside_tree():
		ambience.set_hush_db(0.0)
		return
	_hush_tween = create_tween()
	_hush_tween.tween_method(ambience.set_hush_db, hush_depth_db, 0.0, hush_recover_seconds) \
		.set_trans(Tween.TRANS_SINE)
