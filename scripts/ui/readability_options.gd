class_name ReadabilityOptions
extends VBoxContainer

## Shared image and reading options for both the title and pause menus.
## Each change is written to disk at once, so no exit path can drop it.

var _mode: OptionButton
var _fov: HSlider
var _text: HSlider
var _status: Label

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "IMAGE / READING"
	add_child(title)
	_mode = OptionButton.new()
	_mode.add_item("CLASSIC — stronger pixelation", 0)
	_mode.add_item("READABLE — clearer retro image", 1)
	_mode.add_item("CLEAN — full resolution", 2)
	add_child(_mode)
	var fov_label := Label.new()
	fov_label.text = "Vertical field of view (55–85 degrees)"
	add_child(fov_label)
	_fov = HSlider.new()
	_fov.min_value = 55.0
	_fov.max_value = 85.0
	_fov.step = 1.0
	add_child(_fov)
	var text_label := Label.new()
	text_label.text = "Reading size — documents and lifted sheets"
	add_child(text_label)
	_text = HSlider.new()
	_text.min_value = 1.0
	_text.max_value = 1.5
	_text.step = 0.1
	add_child(_text)
	_status = Label.new()
	_status.text = "Reading and controls stay sharp in every profile."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	refresh()
	_mode.item_selected.connect(_on_mode)
	_fov.value_changed.connect(_on_fov)
	_text.value_changed.connect(_on_text)
	visibility_changed.connect(refresh)

func refresh() -> void:
	if _mode == null or _fov == null or _text == null:
		return
	var settings := GameSettings.load_settings()
	_mode.select(settings.presentation_mode)
	_fov.set_value_no_signal(settings.vertical_fov)
	_text.set_value_no_signal(settings.text_scale)

func _on_mode(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.presentation_mode = index
	_commit(settings)

func _on_fov(value: float) -> void:
	var settings := GameSettings.load_settings()
	settings.vertical_fov = value
	_commit(settings)

func _on_text(value: float) -> void:
	var settings := GameSettings.load_settings()
	settings.text_scale = value
	_commit(settings)

func _commit(settings: GameSettings) -> void:
	settings.save()
	var ancestor: Node = self
	while ancestor != null and not (ancestor is M1OfficeController):
		ancestor = ancestor.get_parent()
	var office := ancestor as M1OfficeController
	settings.apply(office.player if office != null else null)
	if office != null:
		office.apply_presentation_mode(settings.presentation_mode)
		if office.document_viewer != null and office.document_viewer.has_method("set_text_scale"):
			office.document_viewer.set_text_scale(settings.text_scale)
