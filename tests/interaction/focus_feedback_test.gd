extends SceneTree
## The reticle tells the truth about the crosshair target: warm and full when E acts,
## neutral and quiet when inactive or status-only, hidden when no captured control is possible.
## godot --headless --audio-driver Dummy --path . --script tests/interaction/focus_feedback_test.gd

const ACTIONABLE_COLOR := Color(0.95, 0.86, 0.68, 0.95)
const INACTIVE_COLOR := Color(0.86, 0.79, 0.63, 0.45)

func _init() -> void:
	call_deferred("_run")

var _owned: Array = []

func _run() -> void:
	print("--- Starting Focus Feedback Test Suite ---")
	if not _test_reticle_seam_exists(): return
	if not _test_idle_reticle(): return
	if not _test_actionable_focus(): return
	if not _test_status_target_is_inactive(): return
	if not _test_blocked_hides_reticle(): return
	if not _test_uncaptured_hides_reticle(): return
	if not _test_reticle_follows_target_change(): return
	if not _test_prompt_update_refreshes_reticle_without_label(): return
	if not _test_blocked_prompt_update_hides_reticle_without_label(): return
	_release_owned()
	print("--- All Focus Feedback Tests PASSED ---")
	quit(0)

func _track(node: Object) -> Object:
	_owned.append(node)
	return node

func _release_owned() -> void:
	for node in _owned:
		if is_instance_valid(node):
			node.free()
	_owned.clear()

func _make_controller() -> Node:
	var ctl: Node = _track(InteractionController.new())
	var reticle := ColorRect.new()
	reticle.name = "Reticle"
	ctl.add_child(reticle)
	var label := Label.new()
	label.name = "PromptLabel"
	ctl.add_child(label)
	ctl.prompt_label = label
	ctl.reticle = reticle
	root.add_child(ctl)
	return ctl

func _target(actionable: bool) -> Interactable:
	var target: Interactable = _track(Interactable.new())
	target.is_actionable = actionable
	target.prompt_text = "Train-Order Board"
	return target

func _color_matches(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) \
		and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)

func _test_reticle_seam_exists() -> bool:
	var ctl: Node = _track(InteractionController.new())
	return assert_condition(ctl.has_method("refresh_reticle"), "InteractionController exposes refresh_reticle()")

func _test_idle_reticle() -> bool:
	var ctl := _make_controller()
	ctl.refresh_reticle(true)
	var reticle: ColorRect = ctl.reticle
	var ok := assert_condition(reticle.visible, "Idle captured crosshair keeps a reticle visible")
	ok = assert_condition(_color_matches(reticle.color, INACTIVE_COLOR), "Idle reticle uses the neutral inactive color at alpha .45") and ok
	return ok

func _test_actionable_focus() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.current_target = _target(true)
	ctl.refresh_reticle(true)
	var ok := assert_condition(reticle.visible, "Actionable target keeps the reticle visible")
	ok = assert_condition(_color_matches(reticle.color, ACTIONABLE_COLOR), "Actionable target uses the warm focus color at alpha .95") and ok
	return ok

func _test_status_target_is_inactive() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.current_target = _target(false)
	ctl.refresh_reticle(true)
	var ok := assert_condition(reticle.visible, "Status-only target keeps the reticle visible so the ray stays readable")
	ok = assert_condition(_color_matches(reticle.color, INACTIVE_COLOR), "Status-only target uses the inactive color, not a dimmer alpha") and ok
	ok = assert_condition(not _color_matches(reticle.color, ACTIONABLE_COLOR), "Status target never looks like an actionable focus") and ok
	return ok

func _test_blocked_hides_reticle() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.current_target = _target(true)
	ctl.is_ui_blocked = true
	ctl.refresh_reticle(true)
	var ok := assert_condition(not reticle.visible, "UI-blocked view hides the reticle even with an actionable target")
	return ok

func _test_uncaptured_hides_reticle() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.current_target = _target(true)
	ctl.refresh_reticle(false)
	var ok := assert_condition(not reticle.visible, "Uncaptured mouse (menus, pause) hides the reticle")
	return ok

func _test_reticle_follows_target_change() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.current_target = _target(true)
	ctl.refresh_reticle(true)
	ctl.current_target = null
	ctl.refresh_reticle(true)
	var ok := assert_condition(_color_matches(reticle.color, INACTIVE_COLOR), "Losing the target returns the reticle to inactive")
	return ok

func _test_prompt_update_refreshes_reticle_without_label() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.prompt_label = null
	reticle.visible = true
	ctl.current_target = _target(true)
	ctl._update_prompt_ui()
	var ok := assert_condition(not reticle.visible, "Prompt update re-evaluates the reticle before the missing-label return (headless is uncaptured, so it hides)")
	return ok

func _test_blocked_prompt_update_hides_reticle_without_label() -> bool:
	var ctl := _make_controller()
	var reticle: ColorRect = ctl.reticle
	ctl.prompt_label = null
	ctl.current_target = _target(true)
	reticle.visible = true
	ctl.is_ui_blocked = true
	ctl._update_prompt_ui()
	var ok := assert_condition(not reticle.visible, "Blocked prompt update hides the reticle even when the prompt label is missing")
	return ok

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok
