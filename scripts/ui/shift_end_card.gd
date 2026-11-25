class_name ShiftEndCard
extends CanvasLayer

## Closes the slice when the operator walks out at dawn.
##
## The night's record is Elias's, in the room (plan 9.6): the ledger he closes
## at dawn and the duty sheet, both read from KnowledgeState only. Walking out
## shows the dark, the hour and the two ways on; the player is never told what
## he actually did to the railroad.

signal fade_completed()

const TITLE_SCENE: String = "res://scenes/ui/main_menu.tscn"
const OFFICE_SCENE: String = "res://scenes/office/m1_office.tscn"
const DAWN_TOWN_SCENE: String = "res://scenes/town/black_creek_exterior.tscn"

@export var fade_duration: float = 1.6
@export var card_delay: float = 0.5

var fade_rect: ColorRect = null
var title_label: Label = null
var body_label: RichTextLabel = null
var footer_label: Label = null
var card_root: Control = null
var dawn_button: Button = null
var again_button: Button = null
var title_button: Button = null

var _is_running: bool = false

func _ready() -> void:
	# The end card outlives the world it reports on, so it must keep running even
	# if something else stops the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_find_nodes()
	_apply_locale()
	_connect_buttons()
	if fade_rect != null:
		fade_rect.color.a = 0.0
	if card_root != null:
		card_root.modulate.a = 0.0

func _apply_locale() -> void:
	if dawn_button != null:
		dawn_button.text = GameLocale.pick(
			"Выйти на рассвет (Блэк-Крик)",
			"Walk Home at Dawn (Black Creek)"
		)
	if again_button != null:
		again_button.text = GameLocale.pick("Ещё одна смена", "Stand Another Watch")
	if title_button != null:
		title_button.text = GameLocale.pick("В главное меню", "Return to Title")
	if footer_label != null:
		footer_label.text = GameLocale.pick("6:00 — Станция Блэк-Крик", "6:00 A.M. — Black Creek Station")

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
	if dawn_button == null:
		dawn_button = get_node_or_null("CenterContainer/VBoxContainer/ButtonRow/DawnButton") as Button
	if again_button == null:
		again_button = get_node_or_null("CenterContainer/VBoxContainer/ButtonRow/AgainButton") as Button
	if title_button == null:
		title_button = get_node_or_null("CenterContainer/VBoxContainer/ButtonRow/TitleButton") as Button

func _connect_buttons() -> void:
	if dawn_button != null and not dawn_button.pressed.is_connected(continue_to_dawn):
		dawn_button.pressed.connect(continue_to_dawn)
	if again_button != null and not again_button.pressed.is_connected(stand_another_watch):
		again_button.pressed.connect(stand_another_watch)
	if title_button != null and not title_button.pressed.is_connected(return_to_title):
		title_button.pressed.connect(return_to_title)

## Preserves WorldState + KnowledgeState and walks out at dawn into Black Creek (M2-A).
func continue_to_dawn(save_path: String = CampaignStateStore.DEFAULT_SAVE_PATH) -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	var world := tree.root.get_node_or_null("WorldState") as WorldStateStore
	var knowledge := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var campaign := tree.root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.begin_dawn_from_shift(world, knowledge, save_path)
	tree.paused = false
	return SceneTransitionManager.go(tree, DAWN_TOWN_SCENE)

## Both routes clear WorldState and KnowledgeState. A second watch must not begin
## holding the first watch's facts.
func stand_another_watch() -> bool:
	# He has read the order once; the next watch begins in the room.
	IntroCard.spare_next_card = true
	PlaytestTelemetry.arm()
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
	return SceneTransitionManager.go(tree, path)

func is_running() -> bool:
	return _is_running

## Fades the world out, then brings up the operator's record of the watch.
func play(title: String, record: String, footer: String = "") -> void:
	if _is_running:
		return
	_is_running = true
	_find_nodes()

	# Plan 9.6: an empty title or record is not shown at all — the walk-out is
	# the dark, the hour and the two ways on.
	if title_label != null:
		title_label.text = title
		title_label.visible = not title.is_empty()
	if body_label != null:
		body_label.text = record
		body_label.visible = not record.is_empty()
	var rule := get_node_or_null("CenterContainer/VBoxContainer/HSeparator") as Control
	if rule != null:
		rule.visible = not (title.is_empty() and record.is_empty())
	if footer_label != null and not footer.is_empty():
		footer_label.text = footer

	visible = true
	# The operator has walked out; he needs a cursor to decide what happens next.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not is_inside_tree():
		_snap_to_end()
		return

	# Nothing on the card can be pressed before it can be seen.
	_set_buttons_live(false)
	var tween := create_tween()
	if fade_rect != null:
		tween.tween_property(fade_rect, "color:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)
	if card_root != null:
		tween.tween_interval(card_delay)
		tween.tween_property(card_root, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_set_buttons_live(true)
		fade_completed.emit())

func _set_buttons_live(live: bool) -> void:
	for button in [dawn_button, again_button, title_button]:
		if button == null:
			continue
		button.disabled = not live
		button.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	if live:
		if dawn_button != null and dawn_button.visible:
			dawn_button.grab_focus()
		elif again_button != null:
			again_button.grab_focus()

## Used when there is no tree to run a tween on, such as in tests.
func _snap_to_end() -> void:
	_set_buttons_live(true)
	if fade_rect != null:
		fade_rect.color.a = 1.0
	if card_root != null:
		card_root.modulate.a = 1.0
	fade_completed.emit()
