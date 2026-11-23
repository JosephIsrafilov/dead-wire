class_name RoomPropsInteract
extends Node

## Pre-shift and free-walk environmental storytelling interactions for the office:
## Coal stove (stoke embers), North-wall Division Map, South-wall Noticeboard,
## and Hanging Wool Coat. Keeps physical causes honest (no Listener tricks).

const STOVE_STREAM: AudioStream = preload("res://audio/sfx/ambience/stove_fire.wav")

var _office: M1OfficeController = null
var _lamp_life: LampLife = null
var _coat: HangingCoat = null

var _stove_act: Interactable = null
var _map_act: Interactable = null
var _notices_act: Interactable = null
var _coat_act: Interactable = null
var _stove_burst: AudioStreamPlayer3D = null
var _coat_comment_shown: bool = false

func _ready() -> void:
	_office = get_parent() as M1OfficeController
	_setup.call_deferred()

func _setup() -> void:
	if _office == null:
		return
	_lamp_life = _office.get_node_or_null("LampLife") as LampLife
	_coat = _office.get_node_or_null("HangingCoat") as HangingCoat

	_build_stove_interact()
	_build_map_interact()
	_build_notices_interact()
	_build_coat_interact()
	refresh_locale()

func _make_interactable(node_name: String, parent: Node, pos: Vector3, size: Vector3) -> Interactable:
	var existing := parent.get_node_or_null(node_name) as Interactable
	if existing != null:
		return existing
	var area := Interactable.new()
	area.name = node_name
	area.collision_layer = 2
	area.collision_mask = 0
	area.position = pos
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	area.add_child(shape_node)
	parent.add_child(area)
	return area

func _build_stove_interact() -> void:
	var stove := _office.get_node_or_null("CornerStove") as Node3D
	if stove == null:
		return
	_stove_act = _make_interactable(
		"StoveInteractable", stove, Vector3(0.0, 0.85, -0.10), Vector3(0.86, 1.45, 0.86)
	)
	if not _stove_act.interacted.is_connected(_on_stove_interacted):
		_stove_act.interacted.connect(_on_stove_interacted)
	if _stove_burst == null:
		_stove_burst = AudioStreamPlayer3D.new()
		_stove_burst.name = "StoveStokeSound"
		_stove_burst.stream = STOVE_STREAM
		_stove_burst.volume_db = -14.0
		_stove_burst.max_distance = 6.5
		_stove_burst.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
		_stove_burst.position = Vector3(0.0, 0.62, -0.25)
		stove.add_child(_stove_burst)

func _build_map_interact() -> void:
	var div_map := _office.get_node_or_null("DivisionMap") as Node3D
	if div_map == null:
		return
	# DivisionMap is rotated -90 deg on X, so local +Y faces +Z into room.
	_map_act = _make_interactable(
		"DivisionMapInteractable", div_map, Vector3(0.0, 0.08, 0.0), Vector3(1.02, 0.24, 0.68)
	)
	if not _map_act.interacted.is_connected(_on_map_interacted):
		_map_act.interacted.connect(_on_map_interacted)

func _build_notices_interact() -> void:
	var props := _office.get_node_or_null("OfficeStorytellingProps") as Node3D
	if props == null:
		return
	_notices_act = _make_interactable(
		"WallNoticesInteractable", props, Vector3(1.62, 1.56, 2.22), Vector3(0.90, 0.68, 0.22)
	)
	if not _notices_act.interacted.is_connected(_on_notices_interacted):
		_notices_act.interacted.connect(_on_notices_interacted)

func _build_coat_interact() -> void:
	if _coat == null:
		return
	_coat_act = _make_interactable(
		"CoatInteractable", _coat, Vector3(_coat.coat_x, 1.60, _coat.coat_z - 0.04), Vector3(0.46, 0.88, 0.28)
	)
	if not _coat_act.interacted.is_connected(_on_coat_interacted):
		_coat_act.interacted.connect(_on_coat_interacted)

func refresh_locale() -> void:
	if _stove_act != null:
		_stove_act.prompt_text = GameLocale.pick("Подбросить угля в печь", "Stoke the Coal Stove")
	if _map_act != null:
		_map_act.prompt_text = GameLocale.pick("Осмотреть карту участка", "Inspect Division Map")
	if _notices_act != null:
		_notices_act.prompt_text = GameLocale.pick("Прочесть объявления на доске", "Read Wall Notices")
	if _coat_act != null:
		_coat_act.prompt_text = GameLocale.pick("Осмотреть пальто", "Brush the Coat")
	_refresh_wall_notice_labels()

func _refresh_wall_notice_labels() -> void:
	if _office == null:
		return
	var props := _office.get_node_or_null("OfficeStorytellingProps")
	if props == null:
		return
	var font := load("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf") as Font
	var entries := {
		"NoticeTimetableText": GameLocale.pick(
			"ВОСТ. УЧАСТОК\n№ 17   6:05\n№ 22   7:15\n№ 31   ДЕРЖАТЬ",
			"EAST DIVISION\nNo. 17  6:05\nNo. 22  7:15\nNo. 31  HOLD"
		),
		"NoticeCircularText": GameLocale.pick(
			"ЦИРКУЛЯР № 12\nВсе телеграфисты\nподтверждают приём\nкаждого приказа.",
			"GENERAL ORDER 12\nAll operators will\nacknowledge receipt\nof each order."
		),
		"NoticeMemoText": GameLocale.pick(
			"Э. —\nзаводи регистр перед\nследующим вызовом.\n      — Дж.К.",
			"E. —\nwind the register\nbefore the next call.\n      — J.C."
		),
		"NoticeRuleText": GameLocale.pick(
			"ПОСТОРОННИМ\nВХОД В НОЧНЫЕ\nЧАСЫ ВОСПРЕЩЁН.",
			"NO ADMITTANCE\nBEYOND THIS\nPOINT DURING\nNIGHT HOURS."
		),
	}
	for label_name in entries:
		var lbl := props.get_node_or_null(label_name) as Label3D
		if lbl != null:
			if font != null:
				lbl.font = font
			lbl.text = String(entries[label_name])

func _on_stove_interacted() -> void:
	if _lamp_life != null:
		_lamp_life.stoke_stove()
	if _stove_burst != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		_stove_burst.play()
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if is_instance_valid(_stove_burst) and _stove_burst.playing:
				_stove_burst.stop()
		)
	_show_quiet_murmur(
		GameLocale.pick(
			"Угли вспыхнули. На пару часов тепла хватит.",
			"The coals catch. Enough warmth for a couple of hours."
		),
		3.6
	)

func _on_map_interacted() -> void:
	if _office == null or _office.document_viewer == null:
		return
	var body := GameLocale.pick(
		"ВОСТОЧНЫЙ УЧАСТОК — РЕВИЗИЯ ОКТЯБРЯ 1885 Г.\n\n"
		+ "• ДАНМОР (DN) — 14 миль на запад по главному пути.\n"
		+ "• БЛЭК-КРИК (CR) — ваша станция, узловая стрелка.\n"
		+ "• РЕДСТОУН (RS) — 19 миль на восток.\n"
		+ "----------------------------------------\n"
		+ "ВЕТКА № 4 — ШАХТА МАЙН-ДЖАНКШН (MJ):\n"
		+ "Закрыта после затопления забоя в октябре 1885 г.\n"
		+ "Стрелка зашита; у старого переезда горит лишь красный фонарь.",
		"BLACK CREEK & WESTERN RY. — EAST DIVISION (REV. 1885)\n\n"
		+ "• DUNMORE (DN) — 14 miles west on the main line.\n"
		+ "• BLACK CREEK (CR) — this station, junction switch.\n"
		+ "• REDSTONE (RS) — 19 miles east on the main line.\n"
		+ "----------------------------------------\n"
		+ "SPUR LINE NO. 4 — MINE JUNCTION (MJ):\n"
		+ "Closed after the October 1885 pit flooding.\n"
		+ "Points spiked shut; only the red switch lamp still burns."
	)
	GameLocale.open_doc(_office.document_viewer, "division_map", body)

func _on_notices_interacted() -> void:
	if _office == null or _office.document_viewer == null:
		return
	var body := GameLocale.pick(
		"ДОСКА ОБЪЯВЛЕНИЙ У ЮЖНОЙ СТЕНЫ\n\n"
		+ "1) РАСПИСАНИЕ (ВОСТ. УЧАСТОК):\n"
		+ "   Поезд № 17 — 06:05  |  Поезд № 22 — 07:15\n"
		+ "   Поезд № 31 — ДЕРЖАТЬ ДО РАСПОРЯЖЕНИЯ.\n\n"
		+ "2) ЦИРКУЛЯР № 12:\n"
		+ "   Все дежурные телеграфисты обязаны лично\n"
		+ "   подтверждать приём каждого поездного приказа.\n\n"
		+ "3) ЗАПИСКА НА ПОЛЯХ (КАРАНДАШОМ):\n"
		+ "   «Э. — не забывай заводить часовой регистр\n"
		+ "    перед следующим вызовом.   — Дж. Коул»\n\n"
		+ "4) УСТАВ СТАНЦИИ:\n"
		+ "   Посторонним вход за стойку в ночные часы воспрещён.",
		"SOUTH WALL NOTICEBOARD\n\n"
		+ "1) EAST DIVISION TIMETABLE:\n"
		+ "   No. 17 — 6:05  |  No. 22 — 7:15\n"
		+ "   No. 31 — HOLD FOR ORDERS.\n\n"
		+ "2) GENERAL ORDER 12:\n"
		+ "   All operators will acknowledge receipt\n"
		+ "   of each train order in the ledger.\n\n"
		+ "3) PENCILED NOTE:\n"
		+ "   \"E. — wind the register before the next call.\n"
		+ "    — J.C.\"\n\n"
		+ "4) STATION RULE:\n"
		+ "   No admittance beyond this point during night hours."
	)
	GameLocale.open_doc(_office.document_viewer, "wall_notices", body)

func _on_coat_interacted() -> void:
	if _coat != null:
		_coat.draft(Vector3(_coat.coat_x, 1.55, _coat.coat_z - 0.25), Vector3(0.35, 0.0, 0.28), 0.55)
	if not _coat_comment_shown:
		_coat_comment_shown = true
		_show_quiet_murmur(
			GameLocale.pick(
				"Сырая шерсть ещё пахнет угольным дымом с платформы.",
				"Damp wool. Still smells of coal smoke from the platform."
			),
			3.8
		)

func _show_quiet_murmur(text: String, duration: float) -> void:
	if _office == null:
		return
	var sched := _office.session_controller.scheduler if _office.session_controller != null else null
	if sched != null and sched.is_playing():
		return
	var murmur := _office.get_node_or_null("MurmurCaption") as MurmurCaption
	if murmur != null:
		murmur.show_outside_line(text, duration)
