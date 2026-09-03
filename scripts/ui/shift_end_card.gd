class_name ShiftEndCard
extends CanvasLayer

## Closes the slice when the operator walks out at dawn.
##
## The card is Elias's own record of the night, not the game's. It is built from
## the duty sheet, which reads KnowledgeState and nothing else, so a player who
## missed traffic walks out holding an incomplete account and is never told what
## he actually did to the railroad.

signal fade_completed()

const TITLE_SCENE: String = "res://scenes/ui/main_menu.tscn"
const OFFICE_SCENE: String = "res://scenes/office/m1_office.tscn"

@export var fade_duration: float = 1.6
@export var card_delay: float = 0.5

var fade_rect: ColorRect = null
var title_label: Label = null
var body_label: RichTextLabel = null
var footer_label: Label = null
var card_root: Control = null
var again_button: Button = null
var title_button: Button = null

var _is_running: bool = false

func _ready() -> void:
	# The end card outlives the world it reports on, so it must keep running even
	# if something else stops the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_find_nodes()
	_connect_buttons()
	if fade_rect != null:
		fade_rect.color.a = 0.0
	if card_root != null:
		card_root.modulate.a = 0.0

func _find_nodes() -> void:
	if fade_rect == null:
		fade_rect = get_node_or_null("Fade") as ColorRect
	if card_root == null:
		card_root = get_node_or_null("CenterContainer") as Control
	if title_label == null:
		title_label = get_node_or_null("CenterContainer/VBoxContainer/TitleLabel") as Label
	if body_label == null:
		body_label = get_node_or_null("CenterContainer/VBoxContainer/BodyLabel") as RichTextLabel
	if footer_label == null:
		footer_label = get_node_or_null("CenterContainer/VBoxContainer/FooterLabel") as Label
	if again_button == null:
		again_button = get_node_or_null("CenterContainer/VBoxContainer/ButtonRow/AgainButton") as Button
	if title_button == null:
		title_button = get_node_or_null("CenterContainer/VBoxContainer/ButtonRow/TitleButton") as Button

func _connect_buttons() -> void:
	if again_button != null and not again_button.pressed.is_connected(stand_another_watch):
		again_button.pressed.connect(stand_another_watch)
	if title_button != null and not title_button.pressed.is_connected(return_to_title):
		title_button.pressed.connect(return_to_title)

## Both routes clear WorldState and KnowledgeState. A second watch must not begin
## holding the first watch's facts.
func stand_another_watch() -> bool:
	return _go_to(OFFICE_SCENE)

func return_to_title() -> bool:
	return _go_to(TITLE_SCENE)

func _go_to(path: String) -> bool:
	MainMenu.clear_state()
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	tree.paused = false
	return tree.change_scene_to_file(path) == OK

func is_running() -> bool:
	return _is_running

## Fades the world out, then brings up the operator's record of the watch.
func play(title: String, record: String, footer: String = "") -> void:
	if _is_running:
		return
	_is_running = true
	_find_nodes()

	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = record
	if footer_label != null and not footer.is_empty():
		footer_label.text = footer

	visible = true
	# The operator has walked out; he needs a cursor to decide what happens next.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if again_button != null:
		again_button.grab_focus()
	if not is_inside_tree():
		_snap_to_end()
		return

	var tween := create_tween()
	if fade_rect != null:
		tween.tween_property(fade_rect, "color:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)
	if card_root != null:
		tween.tween_interval(card_delay)
		tween.tween_property(card_root, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: fade_completed.emit())

## Used when there is no tree to run a tween on, such as in tests.
func _snap_to_end() -> void:
	if fade_rect != null:
		fade_rect.color.a = 1.0
	if card_root != null:
		card_root.modulate.a = 1.0
	fade_completed.emit()
