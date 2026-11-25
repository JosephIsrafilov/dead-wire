class_name BlackCreekExteriorController
extends Node3D

## Controls the shared 1890 Black Creek exterior street scene across Dawn Walk,
## Sunny Day, Golden Afternoon, and Dusk transitions.

const ROAD_ENDS := preload("res://scripts/town/black_creek_road_ends.gd")
const CHRONICLE := preload("res://data/town/chronicle_april_14_1890.tres")
const BOARDING_ROOM_SCENE := "res://scenes/town/interiors/boarding_house_room.tscn"
const OFFICE_SCENE := "res://scenes/office/m1_office.tscn"
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const DOOR_LATCH_SFX := preload("res://audio/sfx/foley/door_latch.wav")
const SPLASH_SFX := preload("res://audio/sfx/town/water_splash_basin.wav")
const WIRE_HUM_SFX := preload("res://audio/sfx/ambience/wire_sing.wav")
const INTRO_DRONE_MUSIC := preload("res://audio/music/intro_drone.wav")
## Phase B: outdoor boots read the ground they land on. The street is dirt, the
## boardwalks, bridge, depot ramps and stairs are tagged timber, the rail bed is
## ballast and the rails themselves are steel; this scene only supplies the
## outdoor context so an untagged patch of valley still sounds like ground.
const OUTDOOR_SURFACE: StringName = &"dirt"
## The fallback set when the resolver has no bank at all: the recorded dirt
## contacts, never the synthesised `footstep_gravel_*.wav` leftovers.
const FALLBACK_SURFACE_STEPS: Array[AudioStream] = [
	preload("res://audio/sfx/foley/surfaces/dirt_1.wav"),
	preload("res://audio/sfx/foley/surfaces/dirt_2.wav"),
	preload("res://audio/sfx/foley/surfaces/dirt_3.wav"),
	preload("res://audio/sfx/foley/surfaces/dirt_4.wav"),
]

@export var enable_psx_rendering: bool = true

@onready var psx_host: PSXPresentationHost = $PSXPresentationHost
@onready var time_of_day: TownTimeOfDay = $TownTimeOfDay
@onready var builder: TownArchitectureBuilder = $TownArchitectureBuilder
@onready var player: PlayerController = $Player
@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var thoughts: DawnWalkThoughts = $DawnWalkThoughts
@onready var sfx_player: AudioStreamPlayer = $TownSfxPlayer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var hud_label: Label = $TownHudLayer/TopStripLabel

var door_knock := DoorKnockSequence.new()

var _transitioning: bool = false
var _dawn_thought_timer: SceneTreeTimer = null
var _night_intro: NightApproachIntro = null
var _wire_hum_player: AudioStreamPlayer = null
var _drone_player: AudioStreamPlayer = null
var _mist_particles: GPUParticles3D = null
var _night_bounds: Node3D = null
var _creek_splash_cooldown_msec: int = 0

func _ready() -> void:
	add_child(door_knock)
	if psx_host != null:
		psx_host.enable_psx_rendering = enable_psx_rendering
	var campaign := _campaign()
	var is_night := campaign != null and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH
	if builder != null:
		builder.build_town(is_night)
		builder.set_night_approach_mode(is_night)
		var ends := ROAD_ENDS.new()
		ends.name = "RoadClosures"
		add_child(ends)
		ends.build(builder.get_node("StreetDressing"), is_night)
		ends.approached.connect(_on_road_closure)
		if not builder.interactable_triggered.is_connected(_on_town_interactable):
			builder.interactable_triggered.connect(_on_town_interactable)
		if not builder.creek_waded.is_connected(_on_creek_waded):
			builder.creek_waded.connect(_on_creek_waded)
	_configure_outdoor_player()
	_bind_document_viewer()
	var preset := TownTimeOfDay.PRESET_DAY_CLEAR
	if is_night:
		preset = TownTimeOfDay.PRESET_NIGHT_APPROACH
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		preset = TownTimeOfDay.PRESET_DAWN
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DUSK:
		preset = TownTimeOfDay.PRESET_DUSK
	if time_of_day != null:
		time_of_day.apply_preset(preset, builder)
	_place_player_at_spawn()
	_style_hud()
	refresh_locale()
	if is_night:
		_build_night_atmosphere()
		_start_night_intro()
	else:
		_play_fade_in()
		_schedule_arrival_thoughts()

func _configure_outdoor_player() -> void:
	if player == null:
		return
	player.outdoor_mode = true
	var interaction := player.get_node("InteractionController") as InteractionController
	interaction.interaction_ray.target_position.z = -2.7
	player.step_height = 0.34
	player.floor_snap_length = 0.36
	player.footstep_step_distance = 0.92
	player.footstep_variants = FALLBACK_SURFACE_STEPS
	player.configure_footstep_surface(false, OUTDOOR_SURFACE)
	player.surface_resolver.ground_surface_at = FootstepSurfacePaint.avenue_surface
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
	elif spawn_id == &"night_arrival":
		player.global_position = Vector3(-10.5, 0.05, 22.0)
		player.reset_physics_interpolation()
		player.aim_at(TownArchitectureBuilder.DEPOT_ORIGIN + TownArchitectureBuilder.DEPOT_DOOR)
		if campaign != null:
			campaign.pending_spawn_point = &""
	else:
		player.global_position = TownArchitectureBuilder.DEPOT_SOUTH_SPAWN
		player.reset_physics_interpolation()
		player.aim_at(Vector3(0.0, 1.8, 30.0))

func _style_hud() -> void:
	if hud_label == null:
		return
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(PeriodUIStyle.LEDGER_BG, 0.88)
	backing.border_color = PeriodUIStyle.BRASS_DIM
	backing.border_width_left = 2
	backing.border_width_bottom = 1
	backing.content_margin_left = 10.0
	backing.content_margin_right = 10.0
	backing.content_margin_top = 5.0
	backing.content_margin_bottom = 4.0
	hud_label.add_theme_stylebox_override("normal", backing)
	hud_label.add_theme_font_override("font", FONT_REG)
	hud_label.add_theme_font_size_override("font_size", 15)
	hud_label.add_theme_color_override("font_color", PeriodUIStyle.INK_CREAM)
	hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)

func refresh_locale() -> void:
	if builder != null:
		builder.refresh_locale()
	if pause_menu != null:
		pause_menu.refresh_locale()
	if _night_intro != null:
		_night_intro.refresh_locale()
	_refresh_hud()

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var campaign := _campaign()
	var day_num := campaign.day_index if campaign != null else 1
	var wallet_str := CampaignStateStore.format_cents(campaign.wallet_cents) if campaign != null else "$2.50"
	var phase := campaign.phase if campaign != null else CampaignStateStore.PHASE_DAY_TOWN
	match phase:
		CampaignStateStore.PHASE_NIGHT_APPROACH:
			hud_label.text = GameLocale.pick("НОЧЬ · 00:45  /  К депо", "NIGHT · 12:45 AM  /  Depot")
		CampaignStateStore.PHASE_DAWN_WALK:
			hud_label.text = GameLocale.pick("РАССВЕТ · 06:15  /  К пансиону", "DAWN · 06:15 AM  /  Boarding house")
		CampaignStateStore.PHASE_DUSK:
			hud_label.text = GameLocale.pick("СУМЕРКИ  /  К депо", "DUSK  /  Depot")
		_:
			hud_label.text = GameLocale.pick("ДЕНЬ %d · 11:30", "DAY %d · 11:30 AM") % day_num
	hud_label.text += "   ·   %s   |   J / F1" % wallet_str
	hud_label.reset_size()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or is_world_view_blocked():
		return
	if event.physical_keycode != KEY_J and event.keycode != KEY_J and not event.is_action_pressed(&"repeat_thought"):
		return
	var campaign := _campaign()
	var phase := campaign.phase if campaign != null else CampaignStateStore.PHASE_DAY_TOWN
	var note: String
	match phase:
		CampaignStateStore.PHASE_NIGHT_APPROACH, CampaignStateStore.PHASE_DUSK:
			note = GameLocale.pick("К огням депо. Вход со стороны города.", "Follow the depot lights. Use the town-side door.")
		CampaignStateStore.PHASE_DAWN_WALK:
			note = GameLocale.pick("Пансион Харгроув — на восточном конце настила.",
				"Hargrove Boarding House is at the east end of the boardwalk.")
		_:
			note = GameLocale.pick("Салун на Главной улице. У типографии — свежая газета.",
				"The saloon is on Main Street. Find the latest paper outside the print shop.")
	thoughts.show_thought(note, 5.0)
	get_viewport().set_input_as_handled()

func _on_road_closure(ru: String, en: String) -> void:
	if not is_world_view_blocked():
		thoughts.show_thought(GameLocale.pick(ru, en), 3.7)

static var _shift_tip_seen := false
var _street_walk_time := 0.0

func _process(delta: float) -> void:
	if _shift_tip_seen or player == null or is_world_view_blocked():
		return
	if player.velocity.length_squared() > 0.7:
		_street_walk_time += delta
	if _street_walk_time > 4.0 and not door_knock.is_pending() and thoughts.get_current_text().is_empty():
		_shift_tip_seen = true
		thoughts.show_thought(GameLocale.pick("[Shift] Быстрый шаг", "[Shift] Walk briskly"), 3.0)

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
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH:
		var lines: Array[String] = [
			GameLocale.pick(
				"Дальний путь. Ночь холодная, туман не отпускает.",
				"Long road up. Cold night, and the fog won't lift."
			),
			GameLocale.pick(
				"Вон огни депо. Джед уже сдал ключ. Пора занимать смену.",
				"There are the depot lanterns. Jed already left the key. Time to take the wire."
			),
		]
		_run_thought_sequence(lines)
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		var lines := DawnWalkThoughts.build_dawn_thoughts(knowledge, campaign)
		_run_thought_sequence(lines)
	elif campaign != null and campaign.phase == CampaignStateStore.PHASE_DAY_TOWN:
		_dawn_thought_timer = get_tree().create_timer(1.2)
		_dawn_thought_timer.timeout.connect(func() -> void:
			if is_inside_tree() and not is_world_view_blocked() and not door_knock.is_pending():
				thoughts.show_thought(DawnWalkThoughts.build_sunny_morning_thought(), 5.5))

func _run_thought_sequence(lines: Array[String]) -> void:
	if lines.is_empty() or not is_inside_tree():
		return
	var delays := [1.6, 8.5, 16.0]
	for i in mini(lines.size(), delays.size()):
		var msg := lines[i]
		var t := get_tree().create_timer(delays[i])
		t.timeout.connect(func() -> void:
			if is_inside_tree() and not is_world_view_blocked() and not door_knock.is_pending():
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
		&"chronicle_paper":
			CHRONICLE.open_in(document_viewer)
		&"chronicle_door":
			_knock_at(id, GameLocale.pick(
				"Глухо. Никого нет, станок молчит, только бумагой пахнет.",
				"Dead inside. Press is cold, only stale newsprint through the keyhole."
			))
		&"assay_door":
			_knock_at(id, GameLocale.pick(
				"Засов изнутри, нахер закрыто до утра.",
				"Bolted tight till morning."
			))
		&"mercantile_door":
			_knock_at(id, GameLocale.pick(
				"Дверь на замке. Почту Миллер всё равно в руки не отдаст раньше срока.",
				"Locked. Old Miller won't hand over the mail early anyway."
			))
		&"clinic_door":
			_knock_at(id, GameLocale.pick(
				"Никто не откликается... с восемьдесят пятого здесь ни души.",
				"Nobody answers... hasn't been a living soul inside since '85."
			))
		&"smithy_door":
			_knock_at(id, GameLocale.pick(
				"Горн остыл дотла. Кузнец давно свалил.",
				"Forge is dead cold. Smith knocked off hours ago."
			))
		&"calaboose_door":
			_knock_at(id, GameLocale.pick(
				"Железный засов толщиной в руку — слава богу, с этой стороны.",
				"Iron bar thick as a wrist—thank hell it's on this side of the cell."
			))
		&"chapel_door":
			_knock_at(id, GameLocale.pick(
				"Щеколда тяжёлая, не заперто... может, потом зайду, посидеть в тишине хоть минуту.",
				"Heavy iron latch, not locked... might step inside later just to sit out of the wind for a minute."
			), true)
		&"clinic_plaque":
			_open_clinic_plaque()
		&"horse_trough":
			_splash_trough()

func _knock_at(id: StringName, text: String, use_latch := false) -> void:
	door_knock.start(builder.get_town_interactable(id), thoughts, text, use_latch)

func _on_creek_waded() -> void:
	if _transitioning or is_world_view_blocked():
		return
	var now := Time.get_ticks_msec()
	if now < _creek_splash_cooldown_msec:
		return
	_creek_splash_cooldown_msec = now + 10000
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = SPLASH_SFX
		sfx_player.play()
	if thoughts != null:
		thoughts.show_thought(GameLocale.pick(
			"Ах, сука, ледяная вода... по самые щиколотки промок. Выбирайся нахрен.",
			"Goddammit, that water's ice... soaked clean past my boots. Get the hell out of here."
		))

func _enter_boarding_house() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH:
		_knock_at(&"boarding_door", GameLocale.pick(
			"Сейчас 00:45. Комната № 4 подождёт до рассвета — смена в депо.",
			"It's quarter to one. Room 4 waits till dawn — the depot wire needs me."
		))
		return
	door_knock.cancel()
	_transitioning = true
	if player != null:
		player.set_movement_locked(true)
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = DOOR_LATCH_SFX
		sfx_player.play()
	if fade_rect != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		fade_rect.visible = true
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			if is_inside_tree():
				SceneTransitionManager.go(get_tree(), BOARDING_ROOM_SCENE))
	elif is_inside_tree():
		SceneTransitionManager.go(get_tree(), BOARDING_ROOM_SCENE)

func _show_saloon_preview() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH:
		_knock_at(&"saloon_door", GameLocale.pick(
			"«Медный Мул» заперт на засов. Мне туда — к депо с огнями.",
			"The Copper Mule is bolted for the night. The depot lights are up ahead."
		))
		return
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_DAWN_WALK:
		_knock_at(&"saloon_door", GameLocale.pick(
			"Створки «Медного Мула» заперты до полудня. Сначала нужно дойти до пансиона и выспаться.",
			"The Copper Mule's batwings are bolted till noon. Better get to the boarding house and sleep first."
		))
		return
	door_knock.cancel()
	_transitioning = true
	if player != null:
		player.set_movement_locked(true)
	if is_inside_tree():
		SceneTransitionManager.go(get_tree(), "res://scenes/town/interiors/copper_mule_saloon.tscn")

func _show_depot_status() -> void:
	var campaign := _campaign()
	if campaign != null and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH:
		_enter_depot_for_watch()
		return
	_knock_at(&"depot_door", GameLocale.pick(
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
		"Ледяная вода из ручья — аж зубы свело. Хоть сонную дурь из башки выбило.",
		"Ice water off the creek—stings like hell, cuts straight through the night shift fog."
	))

func _on_document_opened(_doc_id: String) -> void:
	door_knock.cancel()
	thoughts.clear_thought()
	thoughts.hide()
	if player != null:
		player.set_movement_locked(true)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = true
			ic.refresh_prompt()

func _on_document_closed(_doc_id: String) -> void:
	thoughts.show()
	if player != null:
		player.set_movement_locked(false)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = false
			ic.refresh_prompt()

func is_world_view_blocked() -> bool:
	if _transitioning:
		return true
	if _night_intro != null and _night_intro.is_running():
		return true
	if document_viewer != null and document_viewer.is_open():
		return true
	if pause_menu != null and pause_menu.is_paused:
		return true
	return false

func _start_night_intro() -> void:
	if fade_rect != null:
		fade_rect.visible = false
	_night_intro = NightApproachIntro.new()
	_night_intro.name = "NightApproachIntro"
	_night_intro.setup(self, player, hud_label)
	_night_intro.intro_finished.connect(_on_night_intro_finished, CONNECT_ONE_SHOT)
	add_child(_night_intro)
	_night_intro.begin()

func _on_night_intro_finished() -> void:
	_refresh_hud()
	_schedule_arrival_thoughts()
	if _drone_player != null:
		var fade := create_tween()
		fade.tween_property(_drone_player, "volume_db", -54.0, 3.0)
		fade.tween_callback(_drone_player.stop)

func _enter_depot_for_watch() -> void:
	door_knock.cancel()
	_transitioning = true
	if player != null:
		player.set_movement_locked(true)
	if sfx_player != null and DisplayServer.get_name() != "headless":
		sfx_player.stream = DOOR_LATCH_SFX
		sfx_player.play()
	IntroCard.spare_next_card = true
	ShiftArrival.arrived_from_town = true
	var campaign := _campaign()
	if campaign != null:
		campaign.phase = CampaignStateStore.PHASE_NIGHT
	if fade_rect != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		fade_rect.visible = true
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			if is_inside_tree():
				SceneTransitionManager.go(get_tree(), OFFICE_SCENE))
	elif is_inside_tree():
		SceneTransitionManager.go(get_tree(), OFFICE_SCENE)

func _build_night_atmosphere() -> void:
	if DisplayServer.get_name() != "headless":
		_wire_hum_player = AudioStreamPlayer.new()
		_wire_hum_player.name = "NightWireHumPlayer"
		_wire_hum_player.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
		_wire_hum_player.stream = WIRE_HUM_SFX
		_wire_hum_player.volume_db = -28.0
		add_child(_wire_hum_player)
		_wire_hum_player.play()
		_wire_hum_player.finished.connect(func() -> void:
			if is_inside_tree() and _wire_hum_player != null:
				_wire_hum_player.play())

		_drone_player = AudioStreamPlayer.new()
		_drone_player.name = "NightDronePlayer"
		_drone_player.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
		_drone_player.stream = INTRO_DRONE_MUSIC
		_drone_player.volume_db = -18.0
		add_child(_drone_player)
		_drone_player.play()
		_drone_player.finished.connect(func() -> void:
			if is_inside_tree() and _night_intro != null and _night_intro.is_running():
				_drone_player.play())

	_mist_particles = GPUParticles3D.new()
	_mist_particles.name = "NightMistParticles"
	_mist_particles.position = Vector3(0.0, 0.62, 11.0)
	_mist_particles.amount = 76
	_mist_particles.lifetime = 7.0
	_mist_particles.preprocess = 7.0
	_mist_particles.visibility_aabb = AABB(Vector3(-32, -3, -24), Vector3(64, 14, 64))
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(16.0, 0.32, 18.0)
	pmat.direction = Vector3(1.0, 0.03, -0.35)
	pmat.spread = 18.0
	pmat.initial_velocity_min = 0.22
	pmat.initial_velocity_max = 0.52
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.9
	pmat.scale_max = 1.5
	pmat.color = Color(0.24, 0.31, 0.42, 0.068)
	_mist_particles.process_material = pmat
	var qm := QuadMesh.new()
	qm.size = Vector2(8.4, 1.35)
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.albedo_texture = _make_soft_mist_texture()
	mmat.vertex_color_use_as_albedo = true
	mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	qm.material = mmat
	_mist_particles.draw_pass_1 = qm
	add_child(_mist_particles)

	var chimney_smoke := _mist_particles.duplicate() as GPUParticles3D
	chimney_smoke.name = "DepotStoveSmoke"
	chimney_smoke.position = TownArchitectureBuilder.DEPOT_ORIGIN + Vector3(2.10, 5.39, 1.55)
	chimney_smoke.amount = 18
	chimney_smoke.lifetime = 4.2
	chimney_smoke.preprocess = 3.5
	chimney_smoke.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(5, 6, 5))
	var smoke_quad := qm.duplicate() as QuadMesh
	smoke_quad.size = Vector2(3.6, 1.8)
	chimney_smoke.draw_pass_1 = smoke_quad
	var smoke := pmat.duplicate() as ParticleProcessMaterial
	smoke.emission_box_extents = Vector3(0.12, 0.08, 0.12)
	smoke.direction = Vector3(0.30, 1.0, -0.14)
	smoke.initial_velocity_min = 0.24
	smoke.initial_velocity_max = 0.48
	smoke.scale_min = 0.16
	smoke.scale_max = 0.53
	smoke.color = Color(0.47, 0.48, 0.50, 0.22)
	chimney_smoke.process_material = smoke
	add_child(chimney_smoke)

	_night_bounds = Node3D.new()
	_night_bounds.name = "NightPerimeterBounds"
	add_child(_night_bounds)
	var walls := [
		["West", Vector3(-26.0, 2.0, 5.0), Vector3(1.0, 4.0, 52.0)],
		["East", Vector3(24.0, 2.0, 5.0), Vector3(1.0, 4.0, 52.0)],
		["South", Vector3(0.0, 2.0, 30.8), Vector3(54.0, 4.0, 1.0)],
		["North", Vector3(0.0, 2.0, -20.5), Vector3(54.0, 4.0, 1.0)],
	]
	for spec in walls:
		var sb := StaticBody3D.new()
		sb.name = String(spec[0])
		sb.position = spec[1]
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = spec[2]
		cs.shape = bx
		sb.add_child(cs)
		_night_bounds.add_child(sb)

func _make_soft_mist_texture() -> ImageTexture:
	var sz := 48
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var nx := (float(x) - half) / half
			var ny := (float(y) - half) / half
			var dist := sqrt(nx * nx + ny * ny)
			var a := pow(clampf(1.0 - dist, 0.0, 1.0), 2.3)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func _campaign() -> CampaignStateStore:
	return get_tree().root.get_node_or_null("CampaignState") as CampaignStateStore if is_inside_tree() else null

func _knowledge() -> KnowledgeStateStore:
	return get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore if is_inside_tree() else null
