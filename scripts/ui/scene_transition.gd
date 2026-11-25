class_name SceneTransitionManager
extends CanvasLayer

## Handcrafted 1890s animated telegraph-register loading screen & threaded
## scene transition overlay. Eliminates grey flashes between scenes while keeping
## synchronous instant behavior in headless regression suites.

const FONT_BOLD := preload("res://assets/fonts/oldstandard/OldStandardTT-Bold.ttf")
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")

const BRASS := Color(0.80, 0.65, 0.38, 1.0)
const BRASS_DARK := Color(0.46, 0.36, 0.21, 0.92)
const CREAM := Color(0.94, 0.89, 0.77, 1.0)
const MUTED := Color(0.70, 0.62, 0.49, 0.92)
const PAPER := Color(0.84, 0.77, 0.62, 1.0)
const INK := Color(0.11, 0.08, 0.06, 1.0)

## Cyclic Morse pattern scrolled along the animated paper tape (units: [kind(0=gap,1=mark), len]).
const MORSE_RIBBON := [
	[1, 1], [0, 1], [1, 3], [0, 1], [1, 1], [0, 3],
	[1, 3], [0, 3],
	[1, 1], [0, 1], [1, 1], [0, 1], [1, 1], [0, 3],
	[1, 3], [0, 1], [1, 1], [0, 3],
]

class RegisterArtCanvas:
	extends Control

	var anim_time: float = 0.0
	var progress: float = 0.0
	var _tape_cycle_px: float = 0.0
	var _mark_segments: Array = []

	func _init() -> void:
		_build_ribbon_cache()

	func _build_ribbon_cache() -> void:
		var unit := 11.0
		var x := 0.0
		_mark_segments.clear()
		for item in MORSE_RIBBON:
			var kind: int = item[0]
			var w: float = float(item[1]) * unit
			if kind == 1:
				_mark_segments.append([x, w])
			x += w
		_tape_cycle_px = maxf(x, 120.0)

	func _draw() -> void:
		var sz := size
		if sz.x <= 4.0 or sz.y <= 4.0:
			return
		var center := sz * 0.5
		# Deep soot-walnut backdrop + layered warm kerosene halo (zero shaders needed).
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.032, 0.025, 0.020, 1.0), true)
		var glow_center := Vector2(center.x, center.y - 24.0)
		for step in range(8):
			var t := 1.0 - float(step) / 8.0
			var rad := maxf(sz.x, sz.y) * (0.14 + 0.34 * t)
			draw_circle(glow_center, rad, Color(0.19, 0.13, 0.07, 0.032))

		# Engraved double brass frame & corner rosettes.
		var outer_frame := Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.55)
		var inner_frame := Color(BRASS.r, BRASS.g, BRASS.b, 0.72)
		draw_rect(Rect2(Vector2(20, 20), sz - Vector2(40, 40)), outer_frame, false, 2.0)
		draw_rect(Rect2(Vector2(28, 28), sz - Vector2(56, 56)), inner_frame, false, 1.0)
		for corner in [
			Vector2(28, 28),
			Vector2(sz.x - 36, 28),
			Vector2(28, sz.y - 36),
			Vector2(sz.x - 36, sz.y - 36),
		]:
			draw_rect(Rect2(corner, Vector2(8, 8)), BRASS, true)

		# Centerpiece 1890s clockwork paper-tape register.
		var reg_y := center.y - 6.0
		var spool_pos := Vector2(center.x - 148.0, reg_y - 22.0)
		_draw_brass_spool(spool_pos, 34.0, anim_time * 1.45)

		var tape_left := spool_pos.x + 2.0
		var tape_right := center.x + 172.0
		var tape_top := reg_y - 4.0
		var tape_h := 18.0
		var tape_w := tape_right - tape_left

		# Brass guide plate & paper strip emerging from the spool.
		draw_rect(Rect2(tape_left + 18.0, tape_top + tape_h, tape_w - 22.0, 5.0), BRASS_DARK, true)
		draw_rect(Rect2(tape_left, tape_top, tape_w, tape_h), PAPER, true)
		draw_rect(Rect2(tape_left, tape_top, tape_w, 1.5), Color(0.55, 0.45, 0.32, 0.75), true)
		draw_rect(Rect2(tape_left, tape_top + tape_h - 1.5, tape_w, 1.5), Color(0.55, 0.45, 0.32, 0.75), true)

		var nib_x := spool_pos.x + 76.0
		var scroll := fmod(anim_time * 88.0, _tape_cycle_px)
		var nib_active := false

		for rep in range(-1, int(ceilf(tape_w / _tape_cycle_px)) + 2):
			var base_x := nib_x - scroll + float(rep) * _tape_cycle_px
			for seg in _mark_segments:
				var sx0: float = base_x + float(seg[0])
				var sw: float = float(seg[1])
				var sx1 := sx0 + sw
				if sx0 <= nib_x and sx1 >= nib_x:
					nib_active = true
				# Clip marks to active printed region (right of the stylus or emerging from spool).
				var cx0 := maxf(sx0, tape_left + 16.0)
				var cx1 := minf(sx1, tape_right - 4.0)
				if cx1 <= cx0:
					continue
				var fade := 1.0 - clampf((cx0 - (tape_right - 48.0)) / 44.0, 0.0, 1.0)
				var mark_col := Color(INK.r, INK.g, INK.b, 0.92 * fade)
				draw_rect(Rect2(cx0, tape_top + 6.5, cx1 - cx0, 4.5), mark_col, true)

		# Smooth gradient fade veil at right edge of paper ribbon.
		for k in range(6):
			var t := float(k) / 6.0
			draw_rect(Rect2(tape_right - 36.0 + t * 36.0, tape_top - 1.0, 7.0, tape_h + 2.0), Color(0.04, 0.03, 0.025, t), true)

		_draw_stylus_arm(Vector2(nib_x, tape_top), nib_active)
		_draw_progress_bar(Vector2(center.x, reg_y + 72.0), 340.0)

	func _draw_brass_spool(center: Vector2, radius: float, angle: float) -> void:
		draw_circle(center, radius, Color(0.32, 0.25, 0.16, 0.96))
		draw_arc(center, radius, 0.0, TAU, 36, BRASS, 2.5, true)
		draw_circle(center, radius * 0.72, Color(0.82, 0.75, 0.60, 0.92))
		draw_circle(center, radius * 0.42, Color(0.20, 0.15, 0.10, 1.0))
		for s in range(6):
			var a := angle + float(s) * TAU / 6.0
			var outer := center + Vector2(cos(a), sin(a)) * (radius - 2.0)
			draw_line(center, outer, BRASS, 2.2, true)
		draw_circle(center, 6.5, BRASS)
		draw_circle(center, 2.5, Color(0.14, 0.11, 0.08, 1.0))

	func _draw_stylus_arm(nib_point: Vector2, inked: bool) -> void:
		var pivot := nib_point + Vector2(36.0, -34.0)
		var tip := nib_point + Vector2(0.0, 6.5 if inked else -5.0)
		draw_line(pivot, tip, BRASS, 3.0, true)
		draw_circle(pivot, 5.5, BRASS)
		draw_circle(pivot, 2.0, Color(0.12, 0.09, 0.06, 1.0))
		draw_circle(tip, 2.6, Color(0.95, 0.78, 0.42, 0.95) if inked else BRASS_DARK)

	func _draw_progress_bar(center: Vector2, width: float) -> void:
		var x0 := center.x - width * 0.5
		var y0 := center.y - 4.0
		var h := 8.0
		draw_rect(Rect2(x0, y0, width, h), Color(0.08, 0.06, 0.045, 0.95), true)
		draw_rect(Rect2(x0, y0, width, h), BRASS_DARK, false, 1.2)
		var fill_w := clampf(progress, 0.0, 1.0) * (width - 4.0)
		if fill_w > 0.5:
			draw_rect(Rect2(x0 + 2.0, y0 + 2.0, fill_w, h - 4.0), Color(0.86, 0.67, 0.34, 0.95), true)
		for tick in range(9):
			var tx := x0 + width * (float(tick) / 8.0)
			var th := 6.0 if tick % 2 == 0 else 4.0
			draw_line(Vector2(tx, y0 + h + 2.0), Vector2(tx, y0 + h + 2.0 + th), BRASS_DARK, 1.0)
		var nx := x0 + 2.0 + fill_w
		var ny := center.y
		var diamond := PackedVector2Array([
			Vector2(nx, ny - 6.0),
			Vector2(nx + 4.5, ny),
			Vector2(nx, ny + 6.0),
			Vector2(nx - 4.5, ny),
		])
		draw_colored_polygon(diamond, CREAM)

var _root: Control = null
var _canvas: RegisterArtCanvas = null
var _brand_label: Label = null
var _title_label: Label = null
var _status_label: Label = null
var _is_transitioning: bool = false
var _display_progress: float = 0.0
var _anim_time: float = 0.0

static func go(tree: SceneTree, scene_path: String, label_ru: String = "", label_en: String = "") -> bool:
	if tree == null:
		return false
	var mgr := tree.root.get_node_or_null("SceneTransition") if tree.root != null else null
	if mgr != null and mgr.has_method("transition_to"):
		return bool(mgr.call("transition_to", scene_path, label_ru, label_en))
	tree.paused = false
	return tree.change_scene_to_file(scene_path) == OK

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_canvas = RegisterArtCanvas.new()
	_canvas.name = "RegisterArt"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_canvas)

	_brand_label = _make_label("FORM 19   ·   B. C. & W. RY.", 15, FONT_BOLD, MUTED)
	_brand_label.anchor_top = 0.5
	_brand_label.anchor_bottom = 0.5
	_brand_label.offset_top = -170.0
	_brand_label.offset_bottom = -138.0
	_root.add_child(_brand_label)

	_title_label = _make_label("", 28, FONT_BOLD, CREAM)
	_title_label.anchor_top = 0.5
	_title_label.anchor_bottom = 0.5
	_title_label.offset_top = -134.0
	_title_label.offset_bottom = -86.0
	_root.add_child(_title_label)

	_status_label = _make_label("", 17, FONT_REG, MUTED)
	_status_label.anchor_top = 0.5
	_status_label.anchor_bottom = 0.5
	_status_label.offset_top = 92.0
	_status_label.offset_bottom = 126.0
	_root.add_child(_status_label)

func _make_label(text: String, size_px: int, font_res: Font, color: Color) -> Label:
	var lbl := Label.new()
	lbl.anchor_left = 0.1
	lbl.anchor_right = 0.9
	lbl.offset_left = 0.0
	lbl.offset_right = 0.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = text
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _process(delta: float) -> void:
	if not visible or _canvas == null:
		return
	_anim_time += delta
	_canvas.anim_time = _anim_time
	_canvas.progress = _display_progress
	_canvas.queue_redraw()
	if _is_transitioning:
		var dots := ".".repeat((int(_anim_time * 2.5) % 3) + 1)
		_status_label.text = GameLocale.pick(
			"Настройка телеграфной линии" + dots,
			"Tuning the telegraph wire" + dots
		)

func transition_to(scene_path: String, label_ru: String = "", label_en: String = "") -> bool:
	if _is_transitioning or not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	if DisplayServer.get_name() == "headless":
		tree.paused = false
		return tree.change_scene_to_file(scene_path) == OK
	_is_transitioning = true
	_run_transition(scene_path, label_ru, label_en)
	return true

func is_transitioning() -> bool:
	return _is_transitioning

func preview_for_capture(scene_path: String, progress: float, anim_time: float) -> void:
	_apply_copy(scene_path, "", "")
	_anim_time = anim_time
	_display_progress = clampf(progress, 0.0, 1.0)
	_canvas.anim_time = _anim_time
	_canvas.progress = _display_progress
	_root.modulate.a = 1.0
	visible = true
	_status_label.text = GameLocale.pick(
		"Настройка телеграфной линии...",
		"Tuning the telegraph wire..."
	)
	_canvas.queue_redraw()

func _apply_copy(scene_path: String, label_ru: String, label_en: String) -> void:
	var pair := _destination_copy(scene_path)
	var ru_title := label_ru if not label_ru.is_empty() else pair[0]
	var en_title := label_en if not label_en.is_empty() else pair[1]
	_title_label.text = GameLocale.pick(ru_title, en_title)
	_brand_label.text = GameLocale.pick(
		"ФОРМА № 19   ·   Ж.Д. БЛЭК-КРИК",
		"FORM 19   ·   B. C. & W. RY."
	)
	_status_label.text = GameLocale.pick(
		"Настройка телеграфной линии.",
		"Tuning the telegraph wire."
	)

static func _destination_copy(scene_path: String) -> Array[String]:
	if scene_path.contains("m1_office"):
		return ["СТАНЦИЯ БЛЭК-КРИК · НОЧНАЯ СМЕНА", "BLACK CREEK DEPOT · NIGHT WATCH"]
	if scene_path.contains("copper_mule_saloon"):
		return ["САЛУН «МЕДНЫЙ МУЛ»", "THE COPPER MULE SALOON"]
	if scene_path.contains("boarding_house_room"):
		return ["ПАНСИОН ХАРГРОУВ", "HARGROVE BOARDING HOUSE"]
	if scene_path.contains("black_creek_exterior"):
		return ["БЛЭК-КРИК · ГЛАВНАЯ УЛИЦА", "BLACK CREEK · MAIN STREET"]
	if scene_path.contains("main_menu"):
		return ["ФОРМА № 19", "FORM 19"]
	return ["ЗАГРУЗКА", "LOADING"]

func _run_transition(scene_path: String, label_ru: String, label_en: String) -> void:
	var tree := get_tree()
	_apply_copy(scene_path, label_ru, label_en)
	_anim_time = 0.0
	_display_progress = 0.04
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	visible = true

	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
	await fade_in.finished

	var err := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	var progress_arr: Array = []
	var elapsed := 0.0
	var packed: PackedScene = null
	var min_hold := 0.55

	if err == OK:
		while is_inside_tree() and elapsed < 15.0:
			await tree.process_frame
			elapsed += get_process_delta_time()
			var status := ResourceLoader.load_threaded_get_status(scene_path, progress_arr)
			var raw := float(progress_arr[0]) if not progress_arr.is_empty() else 0.0
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				raw = 1.0
				_display_progress = move_toward(_display_progress, 1.0, get_process_delta_time() * 2.2)
				if elapsed >= min_hold and _display_progress >= 0.99:
					packed = ResourceLoader.load_threaded_get(scene_path) as PackedScene
					break
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			else:
				var ceiling := minf(maxf(raw, 0.12 + elapsed * 0.45), 0.92)
				_display_progress = move_toward(_display_progress, ceiling, get_process_delta_time() * 1.4)

	if is_inside_tree():
		tree.paused = false
		if packed != null:
			tree.change_scene_to_packed(packed)
		else:
			tree.change_scene_to_file(scene_path)
		await tree.process_frame
		await tree.process_frame

	_display_progress = 1.0
	if is_inside_tree():
		var fade_out := create_tween()
		fade_out.tween_property(_root, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
		await fade_out.finished

	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
