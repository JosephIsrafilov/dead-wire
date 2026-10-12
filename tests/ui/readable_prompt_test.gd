extends SceneTree
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print((("  PASS: " if ok else "  FAIL: ")) + description)
	if not ok:
		quit(1)
		return false
	assertions += 1
	return true
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate()
	root.add_child(player)
	await process_frame
	var prompt := player.get_node("InteractionUI/PromptLabel") as Label
	if not check(prompt != null, "Player prompt label exists"): return
	if not check(prompt.get_theme_font_size("font_size") == 18, "Interaction prompt uses 18px font"): return
	if not check(prompt.autowrap_mode == TextServer.AUTOWRAP_WORD, "Interaction prompt wraps long instructions at word boundaries"): return
	if not check(prompt.offset_left == -420.0 and prompt.offset_right == 420.0, "Interaction prompt is 840px wide for two lines"): return
	if not check(prompt.offset_top == -112.0 and prompt.offset_bottom == -60.0, "Interaction prompt sits above the bottom edge with two-line height"): return
	if not check(absf(prompt.get_theme_color("font_shadow_color").a - 0.85) < 0.01 and prompt.get_theme_constant("shadow_offset_x") == 1, "Interaction prompt keeps its readable shadow"): return
	player.queue_free()
	await process_frame
	print("Readable prompt assertions: ", assertions)
	quit(0)
