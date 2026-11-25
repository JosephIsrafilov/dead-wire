class_name WindowFigureStaging
extends Node

## Where the man behind the north window stands on Night 1 (Stage 1.1).
##
## The figure itself knows how to be in two places and how to move between them
## without being caught doing it (AttentionObservationTarget.set_stage). What it
## does not know is *when*: that is this node's whole job.
##
##   Stage A - the far fence: Miller's clearance slip lands under the south door
##             and his own note says somebody is standing by the old mine fence
##             at Milepost 4 without a lantern. That is 6.8 m out, past the yard
##             fence, and it is a silhouette and nothing more.
##   Stage B - the close window: Silence 3 chars the wick, the pane stops being a
##             mirror, and the same man stands 3 m beyond the glass where a face
##             can be read. SilenceThree asks for this itself.
##
## Stage A is also the one that must not overwrite anything: Miller's knock can
## land while the filing consequence's figure is already standing, and a stage
## change under a watching player is the one thing the Listener never does.

## WorldState: somebody stood out at the fence. Separate from the filing
## consequence's fact and from Silence 3's, so the night can tell what was seen.
const STAGE_A_WORLD_FACT: StringName = &"stage_a_figure_stood"
## Long enough to be found through a window the player may not be facing, short
## enough that it is gone before the next call comes.
const STAGE_A_HOLD_SECONDS: float = 9.0
## AttentionObservationTarget.Stage.FAR_FENCE
const STAGE_FAR_FENCE: int = 1
const STAGE_CLOSE_WINDOW: int = 0
const STING_SFX := preload("res://audio/sfx/foley/figure_window_sting.wav")
const STING_VOLUME_DB: float = 0.0

var figure: AttentionObservationTarget = null
var shutter: ServiceShutterEvent = null
var _office: Node = null
var _sting_player: AudioStreamPlayer = null
var _reaction_stage_a_done: bool = false
var _reaction_stage_b_done: bool = false
var _pending_reveal_stage: int = -1

func _ready() -> void:
	_office = get_parent()
	if _office == null:
		return
	if figure == null:
		figure = _office.get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	if shutter == null:
		shutter = _office.get_node_or_null("ServiceShutterEvent") as ServiceShutterEvent
	if shutter != null and not shutter.clearance_slip_delivered.is_connected(_on_yard_knock):
		shutter.clearance_slip_delivered.connect(_on_yard_knock)
	_ensure_sting_player()
	if figure != null:
		if not figure.event_started.is_connected(_on_figure_started):
			figure.event_started.connect(_on_figure_started)
		if not figure.event_observed.is_connected(_on_figure_observed):
			figure.event_observed.connect(_on_figure_observed)

func _on_figure_started() -> void:
	if figure == null or _office == null:
		return
	var stage := int(figure.call("get_stage")) if figure.has_method("get_stage") else STAGE_CLOSE_WINDOW
	if stage == STAGE_CLOSE_WINDOW:
		var lamp_life := _office.get_node_or_null("LampLife") as LampLife
		if lamp_life != null:
			lamp_life.gust(0.55)

func _ensure_sting_player() -> void:
	if _sting_player != null:
		return
	_sting_player = get_node_or_null("WindowFigureSting") as AudioStreamPlayer
	if _sting_player == null:
		_sting_player = AudioStreamPlayer.new()
		_sting_player.name = "WindowFigureSting"
		_sting_player.stream = STING_SFX
		_sting_player.volume_db = STING_VOLUME_DB
		_sting_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
		add_child(_sting_player)

func _process(_delta: float) -> void:
	if _pending_reveal_stage >= 0 and figure != null and not _is_critical_wire_busy():
		var pending := _pending_reveal_stage
		_pending_reveal_stage = -1
		if figure.is_active and figure.is_observed:
			_fire_reveal(pending)

func _is_critical_wire_busy() -> bool:
	if _office == null:
		return false
	var sess := _office.get("session_controller") as TelegraphSessionController
	if sess != null and sess.scheduler != null and sess.scheduler.is_playing():
		return true
	var gate := _office.get_node_or_null("FairnessGate")
	if gate != null and gate.has_method("is_critical_live") and bool(gate.call("is_critical_live")):
		return true
	return false

func _on_yard_knock() -> void:
	if figure == null:
		return
	# A figure that is already standing belongs to a later beat of the night:
	# Miller's knock does not restage it.
	if figure.is_active:
		return
	if figure.has_method("set_stage"):
		figure.call("set_stage", STAGE_FAR_FENCE)
	figure.trigger_event(STAGE_A_HOLD_SECONDS, STAGE_A_WORLD_FACT)

func _on_figure_observed() -> void:
	if figure == null or _office == null:
		return
	var stage := int(figure.call("get_stage")) if figure.has_method("get_stage") else STAGE_CLOSE_WINDOW
	# GDD §7: critical Morse always stays clean; queue reveal reaction until the wire is clear.
	if _is_critical_wire_busy():
		_pending_reveal_stage = stage
		return
	_pending_reveal_stage = -1
	_fire_reveal(stage)

func _fire_reveal(stage: int) -> void:
	if _office == null:
		return
	var murmur := _office.get_node_or_null("MurmurCaption") as MurmurCaption
	if stage == STAGE_FAR_FENCE:
		if _reaction_stage_a_done:
			return
		_reaction_stage_a_done = true
		if murmur != null:
			murmur.show_outside_line(
				GameLocale.pick(
					"Постой... кто там в темноте у самого забора? Без фонаря стоит.",
					"Hold on... someone's out by the fence in the dark. No lantern on him either."
				),
				5.0
			)
		return
	if _reaction_stage_b_done:
		return
	_reaction_stage_b_done = true
	if _sting_player != null and _sting_player.is_inside_tree() and DisplayServer.get_name() != "headless":
		_sting_player.play()
	var player := _office.get("player") as PlayerController
	if player != null and player.has_method("contact_nudge"):
		player.contact_nudge(2.2)
	if murmur != null:
		murmur.show_outside_line(
			GameLocale.pick(
				"Блять... твою мать, кто это пялится в окно?!",
				"Jesus Christ... who the hell is staring straight through that glass?!"
			),
			5.4
		)
