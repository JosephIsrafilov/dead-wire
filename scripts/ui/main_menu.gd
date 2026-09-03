class_name MainMenu
extends Control

## Title screen, and the only place a watch is actually started.
##
## It exists for one structural reason beyond presentation: WorldState and
## KnowledgeState are autoloads and outlive a scene change. Without a single
## place that clears them, a second watch would begin holding the first watch's
## facts — Elias would remember filing a telegram he has not received yet. Every
## route into the office goes through `begin_watch()` for that reason.

signal watch_started()

const OFFICE_SCENE: String = "res://scenes/office/m1_office.tscn"

@export var office_scene_path: String = OFFICE_SCENE

var settings: GameSettings = null

var begin_button: Button = null
var options_panel: Control = null
var options_button: Button = null
var quit_button: Button = null
var sensitivity_slider: HSlider = null
var head_bob_check: CheckButton = null
var master_slider: HSlider = null
var ambience_slider: HSlider = null

func _ready() -> void:
	_find_nodes()
	settings = GameSettings.load_settings()
	settings.apply(null)
	_push_settings_to_controls()
	_connect_controls()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if options_panel != null:
		options_panel.visible = false
	if begin_button != null:
		begin_button.grab_focus()

func _find_nodes() -> void:
	var box := "CenterContainer/VBoxContainer/"
	if begin_button == null:
		begin_button = get_node_or_null(box + "BeginButton") as Button
	if options_button == null:
		options_button = get_node_or_null(box + "OptionsButton") as Button
	if quit_button == null:
		quit_button = get_node_or_null(box + "QuitButton") as Button
	if options_panel == null:
		options_panel = get_node_or_null(box + "OptionsPanel") as Control

	var options := box + "OptionsPanel/OptionsBox/"
	if sensitivity_slider == null:
		sensitivity_slider = get_node_or_null(options + "SensitivityRow/SensitivitySlider") as HSlider
	if head_bob_check == null:
		head_bob_check = get_node_or_null(options + "HeadBobCheck") as CheckButton
	if master_slider == null:
		master_slider = get_node_or_null(options + "MasterRow/MasterSlider") as HSlider
	if ambience_slider == null:
		ambience_slider = get_node_or_null(options + "AmbienceRow/AmbienceSlider") as HSlider

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
	if begin_button != null and not begin_button.pressed.is_connected(begin_watch):
		begin_button.pressed.connect(begin_watch)
	if options_button != null and not options_button.pressed.is_connected(toggle_options):
		options_button.pressed.connect(toggle_options)
	if quit_button != null and not quit_button.pressed.is_connected(quit_game):
		quit_button.pressed.connect(quit_game)

	if sensitivity_slider != null and not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if head_bob_check != null and not head_bob_check.toggled.is_connected(_on_head_bob_toggled):
		head_bob_check.toggled.connect(_on_head_bob_toggled)
	if master_slider != null and not master_slider.value_changed.is_connected(_on_master_changed):
		master_slider.value_changed.connect(_on_master_changed)
	if ambience_slider != null and not ambience_slider.value_changed.is_connected(_on_ambience_changed):
		ambience_slider.value_changed.connect(_on_ambience_changed)

func toggle_options() -> void:
	if options_panel == null:
		return
	options_panel.visible = not options_panel.visible

## Clears both state stores and opens the office. Everything that starts a watch
## must come through here.
func begin_watch() -> bool:
	clear_state()
	if settings != null:
		settings.save()
	watch_started.emit()

	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	tree.paused = false
	return tree.change_scene_to_file(office_scene_path) == OK

## Both stores reset independently, exactly as the state contract requires.
static func clear_state() -> void:
	var loop := Engine.get_main_loop()
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return
	var world := tree.root.get_node_or_null("WorldState") as WorldStateStore
	if world != null:
		world.reset_for_new_game()
	var knowledge := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge != null:
		knowledge.reset_for_new_game()

func quit_game() -> void:
	if settings != null:
		settings.save()
	if is_inside_tree() and get_tree() != null:
		get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	if settings == null:
		return
	settings.mouse_sensitivity = maxf(0.0002, value / 1000.0)
	settings.apply(null)

func _on_head_bob_toggled(pressed: bool) -> void:
	if settings == null:
		return
	settings.head_bob_enabled = pressed
	settings.apply(null)

func _on_master_changed(value: float) -> void:
	if settings == null:
		return
	settings.master_volume_db = value
	settings.apply(null)

func _on_ambience_changed(value: float) -> void:
	if settings == null:
		return
	settings.ambience_volume_db = value
	settings.apply(null)
