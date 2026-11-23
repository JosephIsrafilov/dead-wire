class_name BlackCreekExteriorController
extends Node3D

## Controls the shared 1890 Black Creek exterior street scene across Dawn Walk,
## Sunny Day, Golden Afternoon, and Dusk transitions.

const BOARDING_ROOM_SCENE := "res://scenes/town/interiors/boarding_house_room.tscn"
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const DOOR_LATCH_SFX := preload("res://audio/sfx/foley/door_latch.wav")
const SPLASH_SFX := preload("res://audio/sfx/town/water_splash_basin.wav")
const GRAVEL_STEPS: Array[AudioStream] = [
	preload("res://audio/sfx/town/footstep_gravel_1.wav"),
	preload("res://audio/sfx/town/footstep_gravel_2.wav"),
	preload("res://audio/sfx/town/footstep_gravel_3.wav"),
]

@export var enable_psx_rendering: bool = true

@onready var psx_host: PSXPresentationHost = $PSXPresentationHost
@onready var time_of_day: TownTimeOfDay = $TownTimeOfDay
@onready var builder = $TownArchitectureBuilder
@onready var player: PlayerController = $Player
@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var thoughts: DawnWalkThoughts = $DawnWalkThoughts
@onready var sfx_player: AudioStreamPlayer = $TownSfxPlayer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var hud_label: Label = $TownHudLayer/TopStripLabel

var _transitioning: bool = false
var _dawn_thought_timer: SceneTreeTimer = null

func _ready() -> void:
	if psx_host != null:
		psx_host.enable_psx_rendering = enable_psx_rendering
	if builder != null:
		builder.build_town()
		if not builder.interactable_triggered.is_connected(_on_town_interactable):
			builder.interactable_triggered.connect(_on_town_interactable)
	_configure_outdoor_player()
	_bind_document_viewer()
	var campaign := _campaign()
	var preset := TownTimeOfDay.PRESET_DAY_CLEAR
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		preset = TownTimeOfDay.PRESET_DAWN
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DUSK:
		preset = TownTimeOfDay.PRESET_DUSK
	if time_of_day != null:
		time_of_day.apply_preset(preset, builder)
	_place_player_at_spawn()
	_style_hud()
	refresh_locale()
	_play_fade_in()
	_schedule_arrival_thoughts()

func _configure_outdoor_player() -> void:
	if player == null:
		return
	player.outdoor_mode = true
	player.step_height = 0.22
	player.floor_snap_length = 0.23
	player.footstep_step_distance = 0.92
	player.footstep_variants = GRAVEL_STEPS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _bind_document_viewer() -> void:
	if document_viewer == null:
		return
	if not document_viewer.document_opened.is_connected(_on_document_opened):
		document_viewer.document_opened.connect(_on_document_opened)
	if not document_viewer.document_closed.is_connected(_on_document_closed):
		document_viewer.document_closed.connect(_on_document_closed)

func _place_player_at_spawn() -> void:
	if player == null:
		return
	var campaign := _campaign()
	var spawn_id := campaign.pending_spawn_point if campaign != null else &"depot_south"
	if spawn_id == &"boarding_house_porch":
		player.global_position = Vector3(29.54, 0.48, 35.3)
		player.reset_physics_interpolation()
		player.aim_at(Vector3(-2.0, 2.2, 24.0))
	elif spawn_id == &"saloon_porch":
		player.global_position = Vector3(-2.0, 0.30, 32.20)
		player.reset_physics_interpolation()
		player.aim_at(Vector3(-2.0, 1.75, 22.0))
		if campaign != null:
			campaign.pending_spawn_point = &""
	else:
		player.global_position = Vector3(0.0, 0.30, 3.0)
		player.reset_physics_interpolation()
		player.aim_at(Vector3(0.0, 1.8, 30.0))

func _style_hud() -> void:
	if hud_label == null:
		return
	hud_label.add_theme_font_override("font", FONT_REG)
	hud_label.add_theme_font_size_override("font_size", 17)
	hud_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.77, 0.92))
	hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)

func refresh_locale() -> void:
	if builder != null:
		builder.refresh_locale()
	if pause_menu != null:
		pause_menu.refresh_locale()
	_refresh_hud()

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var campaign := _campaign()
	var day_num := campaign.day_index if campaign != null else 1
	var wallet_str := CampaignStateStore.format_cents(campaign.wallet_cents) if campaign != null else "$2.50"
	var phase := campaign.phase if campaign != null else CampaignStateStore.PHASE_DAY_TOWN
	if phase == CampaignStateStore.PHASE_DAWN_WALK:
		hud_label.text = GameLocale.pick(
			"06:15 · РАССВЕТ · БЛЭК-КРИК   |   В кармане: %s   |   Цель: Пансион Харгроув (справа в конце настила)" % wallet_str,
			"06:15 · DAWN · BLACK CREEK   |   Pocket: %s   |   Head to Hargrove Boarding House (east boardwalk)" % wallet_str
		)
	else:
		hud_label.text = GameLocale.pick(
			"ДЕНЬ %d · 11:30 · АПРЕЛЬ 1890   |   В кармане: %s" % [day_num, wallet_str],
			"DAY %d · 11:30 A.M. · APRIL 1890   |   Pocket: %s" % [day_num, wallet_str]
		)

func _play_fade_in() -> void:
	if fade_rect == null:
		return
	fade_rect.visible = true
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		fade_rect.color.a = 0.0
		fade_rect.visible = false
		return
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if fade_rect != null:
			fade_rect.visible = false)

func _schedule_arrival_thoughts() -> void:
	if thoughts == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var campaign := _campaign()
	var knowledge := _knowledge()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		var lines := DawnWalkThoughts.build_dawn_thoughts(knowledge, campaign)
		_run_thought_sequence(lines)
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DAY_TOWN:
		_dawn_thought_timer = get_tree().create_timer(1.2)
		_dawn_thought_timer.timeout.connect(func() -> void:
			if is_inside_tree() and thoughts != null:
				thoughts.show_thought(DawnWalkThoughts.build_sunny_morning_thought(), 5.5))

func _run_thought_sequence(lines: Array[String]) -> void:
	if lines.is_empty() or not is_inside_tree():
		return
	var delays := [1.6, 8.5, 16.0]
	for i in mini(lines.size(), delays.size()):
		var msg := lines[i]
		var t := get_tree().create_timer(delays[i])
		t.timeout.connect(func() -> void:
			if is_inside_tree() and thoughts != null and not _transitioning:
				thoughts.show_thought(msg, 4.8))

func _on_town_interactable(id: StringName) -> void:
	if _transitioning or is_world_view_blocked():
		return
	match id:
		&"boarding_door":
			_enter_boarding_house()
		&"saloon_door":
			_show_saloon_preview()
		&"depot_door":
			_show_depot_status()
		&"depot_notices":
			_open_depot_notices()
		&"mj_gate":
			_open_mj_gate_notice()
		&"clinic_plaque":
			_open_clinic_plaque()
		&"horse_trough":
			_splash_trough()

func _enter_boarding_house() -> void:
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
				get_tree().change_scene_to_file(BOARDING_ROOM_SCENE))
	elif is_inside_tree():
		get_tree().change_scene_to_file(BOARDING_ROOM_SCENE)

func _show_saloon_preview() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		thoughts.show_thought(GameLocale.pick(
			"Створки «Медного Мула» заперты до полудня. Сначала нужно дойти до пансиона и выспаться.",
			"The Copper Mule's batwings are bolted till noon. Better get to the boarding house and sleep first."
		))
		return
	_transitioning = true
	get_tree().change_scene_to_file("res://scenes/town/interiors/copper_mule_saloon.tscn")

func _show_depot_status() -> void:
	thoughts.show_thought(GameLocale.pick(
		"В конторе сейчас дневной сменщик Джед Мерсер. Свой стол ждёт к полуночи.",
		"Jed Mercer is on the day wire inside. My night desk waits until midnight."
	))

func _open_depot_notices() -> void:
	if document_viewer == null:
		return
	var title := GameLocale.pick("ДОСКА ДЕПО — БЛЭК-КРИК", "BLACK CREEK DEPOT NOTICEBOARD")
	var body := GameLocale.pick(
		"ПРИКАЗ Ж.Д. BC&W № 44\n"
		+ "Пассажирский № 17 — восток, 01:15.\n"
		+ "Товарный № 71 — проверка на разъезде 02:00.\n"
		+ "Ветка MJ (Рудник): закрыта с 14 октября 1885 г.\n\n"
		+ "ОБЪЯВЛЕНИЕ САЛУНА «МЕДНЫЙ МУЛ»:\n"
		+ "Холодное пиво 5¢ · Виски 10¢ · Механический спин «Серебряная Шпора» — джекпот от $5.00.",
		"BC&W R.R. NOTICE — ORDER 44\n"
		+ "Train 17 Eastbound — 1:15 A.M.\n"
		+ "Freight 71 — Hold & check siding 2:00 A.M.\n"
		+ "MJ Mine Spur: Closed since Oct 14, 1885.\n\n"
		+ "THE COPPER MULE SALOON:\n"
		+ "Draft Beer 5¢ · Corn Whiskey 10¢ · The Silver Spur Bar Spinner — Jackpot from $5.00."
	)
	document_viewer.open_document("town_depot_notices", title, body,
		GameLocale.pick("[E / Esc] Отойти от доски", "[E / Esc] Step Back"))

func _open_mj_gate_notice() -> void:
	if document_viewer == null:
		return
	var title := GameLocale.pick("ВОРОТА ВЕТКИ MJ — КАРАНТИН", "MJ SPUR GATE — QUARANTINE")
	var body := GameLocale.pick(
		"ОГОРОЖЕНО ПО РАСПОРЯЖЕНИЮ КОМПАНИИ BC&W\n"
		+ "Июнь 1885 г. — Выход грунтовых вод в штреке № 4.\n"
		+ "Замок ржавый, но цепи на воротах свежие. Вдоль жёлоба к ручью тянется мутно-рыжий осадок.",
		"CLOSED BY ORDER OF BC&W RAILROAD CO.\n"
		+ "June 1885 — Groundwater seepage in Drift No. 4.\n"
		+ "The padlock is rusted, yet the chain links are clean. Rusty mineral silt stains the culvert toward the creek."
	)
	document_viewer.open_document("town_mj_gate", title, body,
		GameLocale.pick("[E / Esc] Отойти", "[E / Esc] Step Back"))

func _open_clinic_plaque() -> void:
	if document_viewer == null:
		return
	var title := GameLocale.pick("СТАРАЯ ВРАЧЕБНИЦА", "OLD COUNTY PHYSICIAN'S OFFICE")
	var body := GameLocale.pick(
		"Д-Р АРТУР КРЕЙН — ОКРУЖНОЙ ВРАЧ\n"
		+ "Приём прекращён с ноября 1885 года.\n\n"
		+ "На ставнях висит старый замок. Ключ хранится у миссис Харгроув в пансионе.",
		"DR. ARTHUR CRANE — COUNTY PHYSICIAN\n"
		+ "Closed since November 1885.\n\n"
		+ "Heavy shutters are latched shut. Mrs. Hargrove at the boarding house keeps the spare key."
	)
	document_viewer.open_document("town_clinic_plaque", title, body,
		GameLocale.pick("[E / Esc] Отойти", "[E / Esc] Step Back"))

func _splash_trough() -> void:
	var campaign := _campaign()
	if campaign != null:
		campaign.intoxication_level = maxf(0.0, campaign.intoxication_level - 0.35)
		campaign.washed_face_today = true
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = SPLASH_SFX
		sfx_player.play()
	thoughts.show_thought(GameLocale.pick(
		"Ледяная горная вода с ручья. Сонливость как рукой сняло.",
		"Ice-cold creek water. Cuts straight through the night shift fog."
	))

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

func _knowledge() -> KnowledgeStateStore:
	return get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore if is_inside_tree() else null
