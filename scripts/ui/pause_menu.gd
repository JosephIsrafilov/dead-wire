class_name PauseMenu
extends CanvasLayer

## Escape used to do nothing but drop the mouse cursor, leaving the game running
## behind an uncaptured pointer with no way back except clicking. This owns the
## key instead: it stops the shift, shows the options that have to be a player's
## choice rather than a designer's, and writes them to disk.

signal paused()
signal resumed()

const TITLE_SCENE: String = "res://scenes/ui/main_menu.tscn"

@export var player: PlayerController = null
@export var document_viewer: DocumentViewer = null

var settings: GameSettings = null

var is_paused: bool = false

var sensitivity_slider: HSlider = null
var head_bob_check: CheckButton = null
var master_slider: HSlider = null
var ambience_slider: HSlider = null
var resume_button: Button = null
var title_button: Button = null
var quit_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_find_nodes()
	_resolve_targets()

	settings = GameSettings.load_settings()
	settings.apply(player)
	_push_settings_to_controls()
	_connect_controls()

func _find_nodes() -> void:
	var box := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/"
	if sensitivity_slider == null:
		sensitivity_slider = get_node_or_null(box + "SensitivityRow/SensitivitySlider") as HSlider
	if head_bob_check == null:
		head_bob_check = get_node_or_null(box + "HeadBobCheck") as CheckButton
	if master_slider == null:
		master_slider = get_node_or_null(box + "MasterRow/MasterSlider") as HSlider
	if ambience_slider == null:
		ambience_slider = get_node_or_null(box + "AmbienceRow/AmbienceSlider") as HSlider
	if resume_button == null:
		resume_button = get_node_or_null(box + "ResumeButton") as Button
	if title_button == null:
		title_button = get_node_or_null(box + "TitleButton") as Button
	if quit_button == null:
		quit_button = get_node_or_null(box + "QuitButton") as Button

func _resolve_targets() -> void:
	var office := get_parent()
	if office == null:
		return
	if player == null:
		player = office.get_node_or_null("Player") as PlayerController
	if document_viewer == null:
		document_viewer = office.get_node_or_null("DocumentViewer") as DocumentViewer

func _push_settings_to_controls() -> void:
	if settings == null:
		return
	if sensitivity_slider != null:
		sensitivity_slider.set_value_no_signal(settings.mouse_sensitivity * 1000.0)
	if head_bob_check != null:
		head_bob_check.set_pressed_no_signal(settings.head_bob_enabled)
	if master_slider != null:
		master_slider.set_value_no_signal(settings.master_volume_db)
	if ambience_slider != null:
		ambience_slider.set_value_no_signal(settings.ambience_volume_db)

func _connect_controls() -> void:
	if sensitivity_slider != null and not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if head_bob_check != null and not head_bob_check.toggled.is_connected(_on_head_bob_toggled):
		head_bob_check.toggled.connect(_on_head_bob_toggled)
	if master_slider != null and not master_slider.value_changed.is_connected(_on_master_changed):
		master_slider.value_changed.connect(_on_master_changed)
	if ambience_slider != null and not ambience_slider.value_changed.is_connected(_on_ambience_changed):
		ambience_slider.value_changed.connect(_on_ambience_changed)
	if resume_button != null and not resume_button.pressed.is_connected(resume):
		resume_button.pressed.connect(resume)
	if title_button != null and not title_button.pressed.is_connected(return_to_title):
		title_button.pressed.connect(return_to_title)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit):
		quit_button.pressed.connect(_on_quit)

func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	# A document in hand takes the key first: Escape should put the paper down
	# before it stops the shift.
	if not is_paused and document_viewer != null and document_viewer.is_open():
		return

	toggle()
	get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_paused:
		resume()
	else:
		pause()

func pause() -> void:
	if is_paused:
		return
	var office := get_parent() as M1OfficeController
	if office != null:
		if office.routing_board != null and office.routing_board.is_open:
			return
		var intro := office.get_node_or_null("IntroCard") as IntroCard
		if (intro != null and intro.visible) or (office.shift_end_card != null and office.shift_end_card.is_running()):
			return
	is_paused = true
	if player != null:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_inside_tree():
		get_tree().paused = true
	if resume_button != null:
		resume_button.grab_focus()
	paused.emit()

func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	visible = false
	if is_inside_tree():
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player != null:
		var interaction := player.get_node_or_null("InteractionController") as InteractionController
		if interaction != null:
			interaction.refresh_prompt()
	_save()
	resumed.emit()

func _on_sensitivity_changed(value: float) -> void:
	if settings == null:
		return
	# The slider works in thousandths so it has a usable range on screen.
	settings.mouse_sensitivity = maxf(0.0002, value / 1000.0)
	settings.apply(player)

func _on_head_bob_toggled(pressed: bool) -> void:
	if settings == null:
		return
	settings.head_bob_enabled = pressed
	settings.apply(player)

func _on_master_changed(value: float) -> void:
	if settings == null:
		return
	settings.master_volume_db = value
	settings.apply(player)

func _on_ambience_changed(value: float) -> void:
	if settings == null:
		return
	settings.ambience_volume_db = value
	settings.apply(player)

func _save() -> void:
	if settings != null:
		settings.save()

## Abandoning a watch clears it. There is no resuming a half-finished night.
func return_to_title() -> bool:
	_save()
	MainMenu.clear_state()
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	is_paused = false
	visible = false
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return tree.change_scene_to_file(TITLE_SCENE) == OK

func _on_quit() -> void:
	_save()
	if is_inside_tree():
		get_tree().paused = false
		get_tree().quit()
