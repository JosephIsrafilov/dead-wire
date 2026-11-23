class_name BoardingHouseRoomController
extends Node3D

## Elias Crane's Room #4 in Mrs. Hargrove's Boarding House (April 1890).
## Handles Dawn->Sleep->Sunny Morning transition, washstand, April 1890 calendar,
## Mrs. Hargrove's note, and the KnowledgeState-only Case Notebook.

const TOWN_EXTERIOR_SCENE := "res://scenes/town/black_creek_exterior.tscn"
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const BED_CREAK_SFX := preload("res://audio/sfx/town/bed_creak_sleep.wav")
const SPLASH_SFX := preload("res://audio/sfx/town/water_splash_basin.wav")
const BIRDS_WAKE_SFX := preload("res://audio/sfx/town/morning_birds_wake.wav")
const DOOR_LATCH_SFX := preload("res://audio/sfx/foley/door_latch.wav")

@export var enable_psx_rendering: bool = true

@onready var psx_host: PSXPresentationHost = $PSXPresentationHost
@onready var room_builder: BoardingRoomBuilder = $BoardingRoomBuilder
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var window_sun: DirectionalLight3D = $WindowSunLight

@onready var player: PlayerController = $Player
@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var thoughts: DawnWalkThoughts = $DawnWalkThoughts
@onready var room_ambience: AudioStreamPlayer = $RoomAmbiencePlayer
@onready var sfx_player: AudioStreamPlayer = $RoomSfxPlayer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var sleep_title_label: Label = $TransitionLayer/SleepTitleLabel
@onready var hud_label: Label = $RoomHudLayer/TopStripLabel

var _transitioning: bool = false
var _is_day_mode: bool = false
var _common: BoardingHouseCommon

func _ready() -> void:
	if psx_host != null:
		psx_host.enable_psx_rendering = enable_psx_rendering
	_common = BoardingHouseCommon.new()
	_common.name = "HargroveCommon"
	add_child(_common)
	_common.build()
	var exit := Interactable.new()
	exit.position = Vector3(-1.46, 1.14, -4.22)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.20, 2.19, 0.15)
	collision.shape = shape
	exit.add_child(collision)
	add_child(exit)
	exit.prompt_text = GameLocale.pick("Выйти на крыльцо", "Step onto the Porch")
	exit.interacted.connect(_step_outside)
	if room_builder != null:
		room_builder.position = BoardingHouseCommon.ROOM_ANCHOR
		room_builder.build_room()
		if not room_builder.interactable_triggered.is_connected(_on_room_interactable):
			room_builder.interactable_triggered.connect(_on_room_interactable)
	_bind_document_viewer()
	_configure_player()
	var campaign := _campaign()
	var day_now := campaign != null and campaign.phase != CampaignStateStore.PHASE_DAWN_WALK
	apply_room_time_mode(day_now)
	_style_hud()
	refresh_locale()
	if room_ambience != null and DisplayServer.get_name() != "headless" and not room_ambience.playing:
		room_ambience.play()
	_play_fade_in()

func _configure_player() -> void:
	if player == null:
		return
	player.outdoor_mode = false
	player.step_height = 0.22
	player.floor_snap_length = 0.23
	player.global_position = BoardingHouseCommon.ENTRY
	player.reset_physics_interpolation()
	player.aim_at(Vector3(-0.91, 1.6, -1.4))
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _bind_document_viewer() -> void:
	if document_viewer == null:
		return
	if not document_viewer.document_opened.is_connected(_on_document_opened):
		document_viewer.document_opened.connect(_on_document_opened)
	if not document_viewer.document_closed.is_connected(_on_document_closed):
		document_viewer.document_closed.connect(_on_document_closed)

func apply_room_time_mode(is_day: bool) -> void:
	_is_day_mode = is_day
	if room_builder != null:
		room_builder.set_room_day_mode(is_day)
	if psx_host != null:
		psx_host.apply_grade_preset(&"DAY_CLEAR" if is_day else &"DAWN")
	if world_env != null and world_env.environment != null:
		if not world_env.environment.has_meta(&"room_env_unique"):
			world_env.environment = world_env.environment.duplicate(true) as Environment
			world_env.environment.set_meta(&"room_env_unique", true)
		var env := world_env.environment
		env.volumetric_fog_enabled = false
		env.ambient_light_color = Color(0.95, 0.88, 0.74) if is_day else Color(0.48, 0.52, 0.60)
		env.ambient_light_energy = 0.39 if is_day else 0.27
		env.tonemap_exposure = 1.15 if is_day else 1.05
		env.background_color = Color(0.55, 0.69, 0.78) if is_day else Color(0.27, 0.34, 0.43)
	if window_sun != null:
		window_sun.visible = is_day
		window_sun.light_energy = 1.65 if is_day else 0.25
		window_sun.rotation_degrees = Vector3(-42.0, 53.0, 0.0)
		window_sun.light_angular_distance = 1.15
	if _common != null:
		for source in get_tree().get_nodes_in_group(&"boarding_lamp"):
			if _common.is_ancestor_of(source):
				(source as Node3D).visible = not is_day
	_refresh_hud()

func _style_hud() -> void:
	if hud_label != null:
		hud_label.add_theme_font_override("font", FONT_REG)
		hud_label.add_theme_font_size_override("font_size", 17)
		hud_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.77, 0.92))
		hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
		hud_label.add_theme_constant_override("shadow_offset_x", 1)
		hud_label.add_theme_constant_override("shadow_offset_y", 2)
	if sleep_title_label != null:
		sleep_title_label.add_theme_font_override("font", FONT_REG)
		sleep_title_label.add_theme_font_size_override("font_size", 24)
		sleep_title_label.add_theme_color_override("font_color", Color(0.92, 0.87, 0.74, 1.0))

func refresh_locale() -> void:
	if room_builder != null:
		room_builder.refresh_locale()
	if pause_menu != null:
		pause_menu.refresh_locale()
	_refresh_hud()

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var campaign := _campaign()
	var day_num := campaign.day_index if campaign != null else 1
	var wallet_str := CampaignStateStore.format_cents(campaign.wallet_cents) if campaign != null else "$2.50"
	if _is_day_mode:
		hud_label.text = GameLocale.pick(
			"ПАНСИОН · КОМНАТА № 4 · 11:30 (ДЕНЬ %d)   |   В кармане: %s" % [day_num, wallet_str],
			"BOARDING HOUSE · ROOM 4 · 11:30 A.M. (DAY %d)   |   Pocket: %s" % [day_num, wallet_str]
		)
	else:
		hud_label.text = GameLocale.pick(
			"ПАНСИОН · КОМНАТА № 4 · РАССВЕТ   |   В кармане: %s   |   Осмотрите стол или ложитесь спать" % wallet_str,
			"BOARDING HOUSE · ROOM 4 · DAWN   |   Pocket: %s   |   Check your desk or sleep" % wallet_str
		)

func _play_fade_in() -> void:
	if fade_rect == null:
		return
	fade_rect.visible = true
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	if sleep_title_label != null:
		sleep_title_label.visible = false
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		fade_rect.color.a = 0.0
		fade_rect.visible = false
		return
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if fade_rect != null:
			fade_rect.visible = false)

func _on_room_interactable(id: StringName) -> void:
	if _transitioning or is_world_view_blocked():
		return
	match id:
		&"bed":
			trigger_sleep()
		&"washstand":
			trigger_wash_face()
		&"notebook":
			_open_notebook()
		&"calendar":
			_open_calendar()
		&"landlady_note":
			_open_landlady_note()

func trigger_wash_face() -> void:
	var campaign := _campaign()
	if campaign != null:
		campaign.washed_face_today = true
		campaign.intoxication_level = 0.0
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = SPLASH_SFX
		sfx_player.play()
	if thoughts != null:
		thoughts.show_thought(GameLocale.pick(
			"Холодная вода из кувшина. Голова проясняется.",
			"Cold pitcher water. Clears the head right out."
		))

func trigger_sleep() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase != CampaignStateStore.PHASE_DAWN_WALK:
		if thoughts != null:
			thoughts.show_thought(GameLocale.pick(
				"Выспался до полудня. Пора выйти в город — заглянуть в «Медный Мул».",
				"Already rested till noon. Time to step out into town and check The Copper Mule."
			))
		return
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		complete_sleep_immediate("")
		return
	_transitioning = true
	if player != null:
		player.set_movement_locked(true)
	if sfx_player != null:
		sfx_player.stream = BED_CREAK_SFX
		sfx_player.play()
	if fade_rect != null:
		fade_rect.visible = true
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if sleep_title_label != null:
		sleep_title_label.text = GameLocale.pick(
			"11:30 — АПРЕЛЬ 1890 · БЛЭК-КРИК",
			"11:30 A.M. — APRIL 1890 · BLACK CREEK"
		)
		sleep_title_label.modulate.a = 0.0
		sleep_title_label.visible = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sleep_title_label, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		complete_sleep_immediate()
		if sfx_player != null:
			sfx_player.stream = BIRDS_WAKE_SFX
			sfx_player.play())
	tw.tween_interval(1.25)
	tw.tween_property(sleep_title_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_transitioning = false
		if sleep_title_label != null:
			sleep_title_label.visible = false
		if fade_rect != null:
			fade_rect.visible = false
		if player != null:
			player.set_movement_locked(false)
		if thoughts != null:
			thoughts.show_thought(GameLocale.pick(
				"Солнце уже высоко. Пора выйти на улицу Блэк-Крика.",
				"The mountain sun is already high. Time to step out onto Black Creek street."
			)))

func complete_sleep_immediate(save_path: String = CampaignStateStore.DEFAULT_SAVE_PATH) -> void:
	var campaign := _campaign()
	if campaign != null:
		campaign.complete_sleep_to_day(_world(), _knowledge(), save_path)
	apply_room_time_mode(true)

func _open_notebook() -> void:
	if document_viewer == null:
		return
	var body := build_case_notebook_text(_knowledge(), _campaign())
	document_viewer.open_document(
		"elias_case_notebook",
		GameLocale.pick("ТЕТРАДЬ ЭЛИАСА КРЕЙНА", "ELIAS CRANE — CASE NOTEBOOK"),
		body,
		GameLocale.pick("[E / Esc] Закрыть тетрадь", "[E / Esc] Close Notebook")
	)

## Reads ONLY KnowledgeState + CampaignState — never peeks into objective WorldState.
static func build_case_notebook_text(knowledge: KnowledgeStateStore, campaign: CampaignStateStore) -> String:
	var day_num := campaign.day_index if campaign != null else 1
	var wallet_str := CampaignStateStore.format_cents(campaign.wallet_cents) if campaign != null else "$2.50"
	var wage_str := CampaignStateStore.format_cents(campaign.last_shift_wage_cents) if campaign != null else "$2.00"
	var filed_word := knowledge.recall_value(&"filed_word_core_hook", "") if knowledge != null else ""
	var saw_window := knowledge != null and knowledge.knows(&"saw_window_event")
	var signed_at := knowledge.recall_value(&"signed_on_at", "") if knowledge != null else ""

	if GameLocale.is_ru():
		var note := "ЗАПИСИ ОПЕРАТОРА — ДЕНЬ %d (АПРЕЛЬ 1890)\n────────────────────────────────\n" % day_num
		note += "В кармане: %s (за прошлую ночную смену: %s)\n" % [wallet_str, wage_str]
		if not signed_at.is_empty():
			note += "В журнале заступил: %s\n" % signed_at
		note += "\nЧТО ОСТАЛОСЬ В ПАМЯТИ ПОСЛЕ НОЧИ:\n"
		if not filed_word.is_empty():
			note += "— Внеплановый вызов с мёртвой ветки MJ: в копию пошло «%s».\n" % filed_word
		else:
			note += "— Внеплановый вызов с ветки MJ остался без подшитой копии.\n"
		if saw_window:
			note += "— За северным окном у забора стоял человек без фонаря.\n"
		note += "\nДНЕВНЫЕ ДЕЛА В БЛЭК-КРИКЕ:\n"
		note += "• Зайти в салун «Медный Мул» — переговорить с барменом Сайласом Вэнсом.\n"
		note += "• Проверить доску объявлений у депо и ворота старой ветки MJ.\n"
		note += "• Расспросить про отца (д-р Артур Крейн) и закрытую врачебницу."
		return note

	var en := "OPERATOR NOTEBOOK — DAY %d (APRIL 1890)\n────────────────────────────────\n" % day_num
	en += "In pocket: %s (last night's shift pay: %s)\n" % [wallet_str, wage_str]
	if not signed_at.is_empty():
		en += "Signed on in ledger: %s\n" % signed_at
	en += "\nRETAINED FROM LAST NIGHT:\n"
	if not filed_word.is_empty():
		en += "— Unscheduled call on dead MJ line: copy filed as \"%s\".\n" % filed_word
	else:
		en += "— Unscheduled call on dead MJ line left unfiled.\n"
	if saw_window:
		en += "— Someone stood beyond the north glass without a lantern.\n"
	en += "\nDAYTIME LEADS IN BLACK CREEK:\n"
	en += "• Drop by The Copper Mule Saloon and talk with bartender Silas Vance.\n"
	en += "• Check the depot noticeboard and the locked MJ spur gate.\n"
	en += "• Ask about Dr. Arthur Crane's closed office across the planks."
	return en

func _open_calendar() -> void:
	if document_viewer == null:
		return
	var title := GameLocale.pick("НАСТЕННЫЙ КАЛЕНДАРЬ — АПРЕЛЬ 1890", "WALL CALENDAR — APRIL 1890")
	var body := GameLocale.pick(
		"АПРЕЛЬ 1890 ГОДА · БЛЭК-КРИК, КОЛОРАДО\n────────────────────────────────\n"
		+ "Понедельник — Заступление на ночную смену (ст. Блэк-Крик)\n"
		+ "Четверг — Плата за комнату и стол миссис Харгроув ($4.00)\n"
		+ "Воскресенье, 08:00 — Ожидается вызов ревизора на линии.\n\n"
		+ "На полях карандашом обведена старая дата: «14 окт. 1885».",
		"APRIL 1890 · BLACK CREEK, COLORADO\n────────────────────────────────\n"
		+ "Monday — Begin Night Watch at Black Creek Depot\n"
		+ "Thursday — Room & Board due to Mrs. Hargrove ($4.00)\n"
		+ "Sunday, 8:00 A.M. — Division Auditor wire conference.\n\n"
		+ "Penciled lightly in the margin: \"Oct 14, 1885\"."
	)
	document_viewer.open_document("room_calendar", title, body,
		GameLocale.pick("[E / Esc] Отойти", "[E / Esc] Step Back"))

func _open_landlady_note() -> void:
	if document_viewer == null:
		return
	var title := GameLocale.pick("ЗАПИСКА ОТ КЛАРЫ ХАРГРОУВ", "NOTE FROM MRS. CLARA HARGROVE")
	var body := GameLocale.pick(
		"Мистер Крейн,\n\n"
		+ "Комната № 4 протоплена, свежая вода в кувшине на рукомойнике.\n"
		+ "Отоспитесь после дежурства. Когда выйдете на солнце, загляните напротив —\n"
		+ "Сайлас уже открыл «Медный Мул», там сегодня горячее жаркое и приличный кофе.\n"
		+ "Плата за неделю ($4.00) не горит до четверга.\n\n"
		+ "— Клара Харгроув",
		"Mr. Crane,\n\n"
		+ "Room 4 is aired and fresh pitcher water is on the washstand.\n"
		+ "Get proper rest after the wire. Once you wake to the sun, Silas has\n"
		+ "opened The Copper Mule across the road—hot stew and decent coffee.\n"
		+ "Board ($4.00) can wait until Thursday.\n\n"
		+ "— Clara Hargrove"
	)
	document_viewer.open_document("landlady_note", title, body,
		GameLocale.pick("[E / Esc] Сложить записку", "[E / Esc] Fold Note"))

func _step_outside() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		if thoughts != null:
			thoughts.show_thought(GameLocale.pick(
				"Сначала нужно поспать в койке — впереди целый день в городе и новая ночь на проводе.",
				"Need to sleep in the bed first—there's a whole day ahead before the next night watch."
			))
		return
	if campaign != null:
		campaign.pending_spawn_point = &"boarding_house_porch"
	_transitioning = true
	if player != null:
		player.set_movement_locked(true)
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = DOOR_LATCH_SFX
		sfx_player.play()
	if fade_rect != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		fade_rect.visible = true
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			if is_inside_tree():
				get_tree().change_scene_to_file(TOWN_EXTERIOR_SCENE))
	elif is_inside_tree():
		get_tree().change_scene_to_file(TOWN_EXTERIOR_SCENE)

func _on_document_opened(_doc_id: String) -> void:
	if player != null:
		player.set_movement_locked(true)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = true
			ic.refresh_prompt()

func _on_document_closed(_doc_id: String) -> void:
	if player != null:
		player.set_movement_locked(false)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = false
			ic.refresh_prompt()

func is_world_view_blocked() -> bool:
	if _transitioning:
		return true
	if document_viewer != null and document_viewer.is_open():
		return true
	if pause_menu != null and pause_menu.is_paused:
		return true
	return false

func _campaign() -> CampaignStateStore:
	return get_tree().root.get_node_or_null("CampaignState") as CampaignStateStore if is_inside_tree() else null

func _world() -> WorldStateStore:
	return get_tree().root.get_node_or_null("WorldState") as WorldStateStore if is_inside_tree() else null

func _knowledge() -> KnowledgeStateStore:
	return get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore if is_inside_tree() else null
