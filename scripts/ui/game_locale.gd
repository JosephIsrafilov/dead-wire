class_name GameLocale
extends RefCounted

## Central RU / EN localization helper for UI, documents, prompts and wire
## glosses. Defaults to Russian ("ru") unless GameSettings overrides it.

const LANG_RU := "ru"
const LANG_EN := "en"
const SUPPORTED := [LANG_RU, LANG_EN]

const WIRE_GLOSSES_RU: Dictionary = {
	"BC TRAIN 17 CLEAR EAST": "БЛЭК-КРИК: ПОЕЗД 17 — ПРОПУСТИТЬ НА ВОСТОК",
	"BC FREIGHT 71 EAST": "БЛЭК-КРИК: ТОВАРНЫЙ 71 — НА ВОСТОК",
	"MJ WATER": "МДЖ: ВОДА",
	"DN TO RS 17 ON TIME AUDITOR": "ДАНМОР → РЕДСТОУН: 17 ПО РАСПИСАНИЮ, РЕВИЗОР",
	"RS TO DN 4 DEAD WHO KEYED MJ": "РЕДСТОУН → ДАНМОР: 4-Я ЛИНИЯ МЕРТВА, КТО СТУЧАЛ С МДЖ",
	"WHERE IS 17": "ГДЕ 17-Й",
	"71 CLEARED": "71-Й ПРОПУЩЕН",
	"SAID WHAT": "ЧТО ПЕРЕДАЛИ",
	"WATER TO HAND": "ВОДА В РУКИ",
	"WHAT IS WATCHER": "КТО ТАКОЙ СМОТРЯЩИЙ",
	"LINE CLOSED": "ЛИНИЯ ЗАКРЫТА",
	"GN": "СПОКОЙНОЙ НОЧИ (КОНЕЦ СМЕНЫ)",
	"OS 17": "ОТМЕТЬТЕ 17-Й",
	"GO": "СЛУШАЮ",
	"CR CR": "ВЫЗОВ БЛЭК-КРИК",
}

static var _cached_lang: String = ""
static var _test_override: String = ""

static func current() -> String:
	if not _test_override.is_empty():
		return _test_override
	if _cached_lang.is_empty():
		_cached_lang = _normalize(GameSettings.load_settings().language)
	return _cached_lang

static func is_ru() -> bool:
	return current() == LANG_RU

static func set_language(lang: String) -> void:
	_cached_lang = _normalize(lang)

static func lock_language_for_test(lang: String) -> void:
	_test_override = _normalize(lang)
	_cached_lang = _test_override

static func clear_test_override() -> void:
	_test_override = ""
	_cached_lang = ""

static func has_test_override() -> bool:
	return not _test_override.is_empty()

static func reload() -> void:
	_cached_lang = ""

static func pick(ru_text: String, en_text: String) -> String:
	return ru_text if is_ru() else en_text

static func wire_gloss_ru(wire_text: String) -> String:
	var key := wire_text.strip_edges().to_upper()
	if WIRE_GLOSSES_RU.has(key):
		return String(WIRE_GLOSSES_RU[key])
	return ""

static func _normalize(lang: String) -> String:
	var clean := lang.strip_edges().to_lower()
	return clean if clean in SUPPORTED else LANG_RU

static func refresh_office_locale(office: Node) -> void:
	if office == null:
		return
	for node_path in [
		"SeatedStationController", "TimetableCard", "OperatorCard", "DispatchLedger",
		"DutySheet", "Bookcase/BookshelfInspect", "RoutingBoard", "CopyCommitDesk",
		"MorseReferenceCard", "DawnEvidence", "ServiceShutterEvent", "LampLife",
		"DeskAmendment", "ShiftDirector", "SouthDoor/DoorController",
		"TelegraphSessionController/TapeRegister", "RoomPropsInteract", "WindowGlassMirror",
	]:
		var n := office.get_node_or_null(node_path)
		if n != null and n.has_method("refresh_locale"):
			n.refresh_locale()
	var roster := office.get_node_or_null("OfficeStorytellingProps/DutyRosterText") as Label3D
	if roster != null:
		roster.text = pick("НОЧНОЙ НАРЯД\n23:00 — 06:00", "NIGHT ORDERS\n11 P.M. — 6 A.M.")
	var lean_act := office.get_node_or_null("DeskSetup/LeanAtWindow") as Interactable
	if lean_act != null:
		lean_act.prompt_text = pick("Прильнуть к стеклу", "Lean to the Glass")

static func open_doc(viewer: Node, doc_id: String, body: String, extra_footer: String = "") -> void:
	if viewer == null:
		return
	var title := ""
	var footer := ""
	match doc_id:
		"morse_reference":
			title = pick("АМЕРИКАНСКАЯ АЗБУКА МОРЗЕ (1890)", "AMERICAN MORSE CODE (1890)")
			footer = pick("[E / Esc / ПКМ] Отложить справочник", "[E / Esc] Put Down Reference Card")
		"dispatch_ledger":
			title = pick("СТАНЦИЯ БЛЭК-КРИК — ЖУРНАЛ СМЕНЫ", "BLACK CREEK STATION — DISPATCH LEDGER")
			footer = pick("[E / Esc / ПКМ] Отложить журнал", "[E / Esc] Put Down Ledger")
		"duty_sheet":
			title = pick("НОЧНОЙ НАРЯД", "NIGHT ORDERS")
			footer = pick("[E / Esc / ПКМ] Отложить", "[E / Esc] Put Down")
		"bookshelf":
			title = pick("БЛЭК-КРИК — КНИГИ УЧАСТКА", "BLACK CREEK — DIVISION VOLUMES")
			footer = pick("[E / Esc / ПКМ] Отложить том", "[E / Esc] Put Down the Volumes")
		"dawn_evidence":
			title = pick("БЛЭК-КРИК — ПЕРЕДАЧА СМЕНЫ", "BLACK CREEK — NIGHT HANDOVER")
			footer = pick("[E / Esc / ПКМ] Отложить передачу смены", "[E / Esc] Put Down the Night Handover")
		"division_map":
			title = pick("КАРТА УЧАСТКА — РЕВИЗИЯ 1885", "EAST DIVISION MAP — REV. 1885")
			footer = pick("[E / Esc / ПКМ] Отойти от карты", "[E / Esc] Step Back")
		"wall_notices":
			title = pick("ДОСКА ОБЪЯВЛЕНИЙ", "STATION NOTICEBOARD")
			footer = pick("[E / Esc / ПКМ] Отойти от доски", "[E / Esc] Step Back")
		_:
			title = pick("НОЧНАЯ КОПИЯ — Э. КРЕЙН", "NIGHT COPY — E. CRANE")
			footer = extra_footer if not extra_footer.is_empty() else pick("[E / Esc / ПКМ] Отложить", "[E / Esc] Put Down")
	viewer.call("open_document", doc_id, title, body, footer)
