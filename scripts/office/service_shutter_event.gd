class_name ServiceShutterEvent
extends Node3D

## Brakeman H. Miller's midnight yard clearance delivery at the south door.
##
## Strictly a living railroad worker (never the Listener — GDD §10), arriving in
## the quiet stretch before Slot 3 while the wire is idle (GDD §7). Knocks softly,
## casts a brief warm lantern spill beneath the door, shows an exterior voice
## banner on its own layer (never colliding with MurmurCaption), and slides a
## yellow Form 31 yard clearance slip onto the floorboards for Elias to retrieve.

signal clearance_slip_delivered()
signal clearance_slip_read()

const KNOCK_STREAM := preload("res://audio/sfx/foley/board_door.wav")
const PAPER_STREAM := preload("res://audio/sfx/foley/paper_sheet.mp3")
const FONT_VOICE := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const BANNER_HOLD_SECONDS := 7.0
const BANNER_FADE_SECONDS := 1.0

var _director: ShiftDirector = null
var _scheduler: MorseRuntimeScheduler = null
var _doc_viewer: DocumentViewer = null

var _slip_root: Node3D = null
var _slip_interact: Interactable = null
var _lantern: OmniLight3D = null
var _knock_player: AudioStreamPlayer3D = null
var _paper_player: AudioStreamPlayer = null

var _banner_layer: CanvasLayer = null
var _banner_panel: PanelContainer = null
var _banner_label: Label = null
var _banner_elapsed: float = -1.0

var _armed: bool = false
var _wait_timer: float = 0.0
var _delivered: bool = false
var _slip_read: bool = false
var _knock_queue: Array[float] = []
var _lantern_timer: float = -1.0

func _ready() -> void:
	_build_slip_and_light()
	_build_banner()
	_resolve_refs()
	_connect_signals()

func _resolve_refs() -> void:
	var office := get_parent()
	if office == null:
		return
	_director = office.get_node_or_null("ShiftDirector") as ShiftDirector
	_scheduler = office.get_node_or_null("MorseRuntimeScheduler") as MorseRuntimeScheduler
	_doc_viewer = office.get_node_or_null("DocumentViewer") as DocumentViewer

func _connect_signals() -> void:
	if _director != null and not _director.phase_changed.is_connected(_on_phase_changed):
		_director.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(new_phase: ShiftDirector.Phase, _prev: ShiftDirector.Phase) -> void:
	if _delivered:
		return
	if new_phase == ShiftDirector.Phase.WAITING and _director.get_slot_index() >= 2:
		_armed = true
		_wait_timer = 0.0

func has_unread_slip() -> bool:
	return _delivered and not _slip_read

func is_delivered() -> bool:
	return _delivered

func trigger_delivery_now() -> void:
	if _delivered:
		return
	_delivered = true
	_armed = false
	_knock_queue = [0.0, 0.24, 0.48]
	_lantern_timer = 0.0
	if _lantern != null:
		_lantern.light_energy = 0.85
	if _slip_root != null:
		_slip_root.visible = true
	if _slip_interact != null:
		_slip_interact.enabled = true
		_slip_interact.is_actionable = true
		_slip_interact.collision_layer = 2
	_show_banner()
	clearance_slip_delivered.emit()

func _show_banner() -> void:
	if _banner_panel == null:
		return
	_banner_elapsed = 0.0
	_banner_panel.visible = true
	_banner_panel.modulate.a = 1.0

func _hide_banner() -> void:
	_banner_elapsed = -1.0
	if _banner_panel != null:
		_banner_panel.visible = false
		_banner_panel.modulate.a = 0.0

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _armed and not _delivered:
		if _director == null or _director.get_phase() == ShiftDirector.Phase.WAITING:
			_wait_timer += delta
			if _wait_timer >= 3.0 and _wire_idle():
				trigger_delivery_now()
	if not _knock_queue.is_empty():
		var next_queue: Array[float] = []
		for t in _knock_queue:
			var rem := t - delta
			if rem <= 0.0:
				_play_knock()
			else:
				next_queue.append(rem)
		_knock_queue = next_queue
	if _lantern_timer >= 0.0 and _lantern != null:
		_lantern_timer += delta
		var t := clampf(_lantern_timer / 4.2, 0.0, 1.0)
		var rest := 0.0 if _slip_read else 0.16
		_lantern.light_energy = lerpf(0.85, rest, t)
		if t >= 1.0:
			_lantern_timer = -1.0
	if _banner_elapsed >= 0.0 and _banner_panel != null:
		_banner_elapsed += delta
		if _banner_elapsed >= BANNER_HOLD_SECONDS:
			var fade := (_banner_elapsed - BANNER_HOLD_SECONDS) / BANNER_FADE_SECONDS
			if fade >= 1.0:
				_hide_banner()
			else:
				_banner_panel.modulate.a = 1.0 - fade

func _play_knock() -> void:
	if not _wire_idle() or DisplayServer.get_name() == "headless":
		return
	if _knock_player != null and _knock_player.is_inside_tree():
		_knock_player.play()

func _on_slip_interacted() -> void:
	if not _delivered or _slip_read:
		return
	_slip_read = true
	_hide_banner()
	if _slip_root != null:
		_slip_root.visible = false
	if _slip_interact != null:
		_slip_interact.enabled = false
		_slip_interact.collision_layer = 0
	if _lantern != null:
		_lantern.light_energy = 0.0
	if _paper_player != null and _paper_player.is_inside_tree() and DisplayServer.get_name() != "headless":
		_paper_player.play()
	var knowledge: KnowledgeStateStore = null
	if is_inside_tree():
		knowledge = get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge != null:
		knowledge.learn(&"read_brakeman_clearance_slip")
	if _doc_viewer != null:
		_doc_viewer.open_document(
			"yard_clearance_slip",
			GameLocale.pick("ФОРМА 31 — ДОКЛАД СО ДВОРА", "FORM 31 — YARD CREW CLEARANCE"),
			_build_slip_text(),
			GameLocale.pick("[E / Esc / ПКМ] Отложить записку", "[E / Esc / Right-Click] Put Down Slip")
		)
	clearance_slip_read.emit()

func _build_slip_text() -> String:
	var world := get_tree().root.get_node_or_null("WorldState") as WorldStateStore if is_inside_tree() else null
	if GameLocale.is_ru():
		var t17_ru := "  Поезд № 17 (пасс.) ...... ждёт приказа на входном участке"
		if world != null and bool(world.get_fact(&"train_17_routed_clear", false)):
			t17_ru = "  Поезд № 17 (пасс.) ...... ПРОПУЩЕН НА ВОСТОК за стрелки"
		elif world != null and bool(world.get_fact(&"train_17_held_in_error", false)):
			t17_ru = "  Поезд № 17 (пасс.) ...... ЗАДЕРЖАН НА ЗАПАДЕ у семафора"

		var f71_ru := "  Товарный № 71 ........... ждёт указаний по станции"
		if world != null and bool(world.get_fact(&"freight_held_correctly", false)):
			f71_ru = "  Товарный № 71 ........... ЗАДЕРЖАН на боковом пути (фонарь горит)"
		elif world != null and bool(world.get_fact(&"freight_cleared_in_error", false)):
			f71_ru = "  Товарный № 71 ........... ушёл на закрытую рудничную ветку"

		return """ДОКЛАД СО ДВОРА В ПОЛНОЧЬ:
%s
%s

ЗАПИСКА БРИГАДЫ (Г. Миллер, тормозной):
Дверь не открывал — видел свет твоей лампы сквозь щели.
У старого шахтного забора у 4-й версты стоит кто-то
БЕЗ ФОНАРЯ. Скажи обходчику, пусть прогонит с путей.

Не зевай на проводе после двух, Крейн.
Шахтная ветка MJ в дождь опять коротит на землю.
""" % [t17_ru, f71_ru]

	var t17_line := "  No. 17 Passenger ...... awaiting order at block limit"
	if world != null and bool(world.get_fact(&"train_17_routed_clear", false)):
		t17_line = "  No. 17 Passenger ...... CLEARED EAST past points"
	elif world != null and bool(world.get_fact(&"train_17_held_in_error", false)):
		t17_line = "  No. 17 Passenger ...... HELD WEST at board"

	var f71_line := "  No. 71 Freight ........ awaiting yard order"
	if world != null and bool(world.get_fact(&"freight_held_correctly", false)):
		f71_line = "  No. 71 Freight ........ HELD on mine siding (lamp lit)"
	elif world != null and bool(world.get_fact(&"freight_cleared_in_error", false)):
		f71_line = "  No. 71 Freight ........ pulled onto closed mine spur"

	return """BLACK CREEK & WESTERN RAILWAY — YARD MEMO
────────────────────────────────────────
TRAIN REPORT AT MIDNIGHT:
%s
%s

CREW NOTE (H. Miller, Brakeman):
Did not open the door — saw your lamp through the slats.
Somebody is standing inside the old mine fence by Milepost 4
with NO lantern. Tell the watchman to run him off the ballast.

Keep your line sharp after two o'clock, Crane.
Mine wire MJ has been grounding in the rain again.
""" % [t17_line, f71_line]

func _wire_idle() -> bool:
	return _scheduler == null or not _scheduler.is_playing()

func _build_banner() -> void:
	if _banner_layer != null:
		return
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "DoorVoiceLayer"
	_banner_layer.layer = 7
	add_child(_banner_layer)

	_banner_panel = PanelContainer.new()
	_banner_panel.name = "DoorVoiceBanner"
	_banner_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_banner_panel.offset_left = -410.0
	_banner_panel.offset_right = 410.0
	_banner_panel.offset_top = -146.0
	_banner_panel.offset_bottom = -84.0
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.84)
	style.border_color = Color(0.76, 0.58, 0.30, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_banner_panel.add_theme_stylebox_override("panel", style)
	_banner_layer.add_child(_banner_panel)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.add_theme_font_override("font", FONT_VOICE)
	_banner_label.add_theme_font_size_override("font_size", 18)
	_banner_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66, 0.96))
	_banner_label.text = GameLocale.pick(
		"У ДВЕРИ — Тормозной Миллер: «Крейн? Записка под дверью. "
		+ "Скажи тому у забора, чтоб взял фонарь.»",
		"AT THE DOOR — Brakeman: \"Crane? Clearance slip under the door. "
		+ "Tell whoever's by the fence to carry a lamp.\""
	)
	_banner_panel.add_child(_banner_label)

func refresh_locale() -> void:
	if _banner_label != null:
		_banner_label.text = GameLocale.pick(
			"У ДВЕРИ — Тормозной Миллер: «Крейн? Записка под дверью. "
			+ "Скажи тому у забора, чтоб взял фонарь.»",
			"AT THE DOOR — Brakeman: \"Crane? Clearance slip under the door. "
			+ "Tell whoever's by the fence to carry a lamp.\""
		)
	if _slip_interact != null:
		_slip_interact.prompt_text = GameLocale.pick(
			"Подобрать записку со двора",
			"Pick Up Yard Clearance Slip"
		)

func _build_slip_and_light() -> void:
	if _slip_root != null:
		return
	_slip_root = Node3D.new()
	_slip_root.name = "YardSlipVisual"
	_slip_root.position = Vector3(0.0, 0.013, -0.10)
	_slip_root.rotation.y = 0.16
	_slip_root.visible = false
	add_child(_slip_root)

	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.20, 0.005, 0.26)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.82, 0.54)
	mat.roughness = 0.85
	paper.mesh = pm
	paper.material_override = mat
	_slip_root.add_child(paper)

	var ink := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(0.14, 0.006, 0.025)
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.14, 0.10, 0.08)
	ink.mesh = im
	ink.material_override = imat
	ink.position = Vector3(0.0, 0.001, -0.07)
	_slip_root.add_child(ink)

	_slip_interact = Interactable.new()
	_slip_interact.name = "Interactable"
	_slip_interact.prompt_text = GameLocale.pick(
		"Подобрать записку со двора",
		"Pick Up Yard Clearance Slip"
	)
	_slip_interact.collision_layer = 0
	_slip_interact.collision_mask = 0
	_slip_interact.enabled = false
	_slip_interact.is_actionable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 0.14, 0.36)
	shape.shape = box
	_slip_interact.add_child(shape)
	_slip_interact.interacted.connect(_on_slip_interacted)
	_slip_root.add_child(_slip_interact)

	_lantern = OmniLight3D.new()
	_lantern.name = "DoorLanternLight"
	_lantern.position = Vector3(0.0, 0.20, -0.08)
	_lantern.light_color = Color(1.0, 0.72, 0.36)
	_lantern.light_energy = 0.0
	_lantern.omni_range = 1.6
	_lantern.omni_attenuation = 1.5
	_lantern.shadow_enabled = false
	add_child(_lantern)

	_knock_player = AudioStreamPlayer3D.new()
	_knock_player.name = "KnockPlayer"
	_knock_player.stream = KNOCK_STREAM
	_knock_player.volume_db = -9.0
	_knock_player.max_distance = 10.0
	_knock_player.unit_size = 3.0
	_knock_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	add_child(_knock_player)

	_paper_player = AudioStreamPlayer.new()
	_paper_player.name = "SlipPaperPlayer"
	_paper_player.stream = PAPER_STREAM
	_paper_player.volume_db = -10.0
	_paper_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	add_child(_paper_player)
