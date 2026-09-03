class_name IntroCard
extends CanvasLayer

## The first thirty seconds of the game.
##
## Until this existed the game opened with a player standing in an unexplained
## room in the dark with no idea who he was, when it was, or what the job was.
## None of the premise the whole design rests on — 1894, a railroad telegraph
## office, an operator whose competence is the thing that will betray him — was
## anywhere on screen.
##
## It is written as the order that put him here rather than as narration, and it
## can be skipped on any key after the first beat.

signal intro_finished()

@export var hold_seconds: float = 6.0
@export var fade_duration: float = 2.2
## Skipping is refused for this long so the first frame is never missed.
@export var skip_lockout_seconds: float = 1.0

@export var player: PlayerController = null

var fade_rect: ColorRect = null
var card_root: Control = null

var _is_running: bool = false
var _is_finished: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_nodes()
	_resolve_player()
	begin()

func _find_nodes() -> void:
	if fade_rect == null:
		fade_rect = get_node_or_null("Fade") as ColorRect
	if card_root == null:
		card_root = get_node_or_null("CenterContainer") as Control

func _resolve_player() -> void:
	if player != null:
		return
	var office := get_parent()
	if office != null:
		player = office.get_node_or_null("Player") as PlayerController

func is_running() -> bool:
	return _is_running

func is_finished() -> bool:
	return _is_finished

func begin() -> void:
	if _is_running or _is_finished:
		return
	_find_nodes()
	_resolve_player()
	_is_running = true
	_elapsed = 0.0
	visible = true
	if fade_rect != null:
		fade_rect.color.a = 1.0
	if card_root != null:
		card_root.modulate.a = 1.0
	# He is not in the room yet, so he cannot walk or look around it.
	if player != null:
		player.set_movement_locked(true)
		var interaction := player.get_node_or_null("InteractionController") as InteractionController
		if interaction != null:
			interaction.is_ui_blocked = true
			interaction.refresh_prompt()

func _process(delta: float) -> void:
	if not _is_running:
		return
	_elapsed += delta
	if _elapsed >= hold_seconds:
		finish()

func _input(event: InputEvent) -> void:
	if not _is_running or _elapsed < skip_lockout_seconds:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		finish()
		get_viewport().set_input_as_handled()

## Ends the intro with no fade. Used by tests, which must not sit through it.
func skip_immediately() -> void:
	_is_running = false
	_is_finished = true
	_release()

func finish() -> void:
	if not _is_running:
		return
	_is_running = false
	_is_finished = true

	if not is_inside_tree():
		_release()
		return

	var tween := create_tween()
	tween.set_parallel(true)
	if card_root != null:
		tween.tween_property(card_root, "modulate:a", 0.0, fade_duration * 0.45).set_trans(Tween.TRANS_SINE)
	if fade_rect != null:
		tween.tween_property(fade_rect, "color:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(_release)

func _release() -> void:
	visible = false
	if player != null:
		player.set_movement_locked(false)
		var interaction := player.get_node_or_null("InteractionController") as InteractionController
		if interaction != null:
			interaction.is_ui_blocked = false
			interaction.refresh_prompt()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	intro_finished.emit()
