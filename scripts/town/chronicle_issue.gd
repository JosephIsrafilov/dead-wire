extends Resource
## Localized letterpress copy for a single issue of the fictional town paper.

@export var dateline_ru: String
@export var dateline_en: String
@export_multiline var body_ru: String
@export_multiline var body_en: String

func open_in(viewer: DocumentViewer) -> void:
	viewer.open_document(&"chronicle_paper", "Black Creek Chronicle", GameLocale.pick(body_ru, body_en),
		GameLocale.pick(dateline_ru, dateline_en))
