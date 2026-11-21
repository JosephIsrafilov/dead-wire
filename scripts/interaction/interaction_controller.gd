class_name InteractionController
extends Node

@export var interaction_ray: RayCast3D
@export var prompt_label: Label
@export var reticle: ColorRect

const STATUS_ALPHA: float = 0.55
## Crosshair color: warm when E acts on the target, neutral and quiet otherwise.
const ACTIONABLE_RETICLE_COLOR: Color = Color(0.95, 0.86, 0.68, 0.95)
const INACTIVE_RETICLE_COLOR: Color = Color(0.86, 0.79, 0.63, 0.45)

var current_target: Interactable = null
var is_ui_blocked: bool = false
var cursor_mode: bool = false
var _cursor_target: Interactable = null

## Shown when nothing is under the crosshair. Used by the chair: the interaction
## ray does not report a trigger it starts inside, so a seated operator would
## otherwise never be told how to get up.
var persistent_hint: String = ""

func _ready() -> void:
	if not interaction_ray:
		interaction_ray = get_node_or_null("../Head/Camera3D/InteractionRay") as RayCast3D
	if not prompt_label:
		prompt_label = get_node_or_null("../InteractionUI/PromptLabel") as Label
	if not reticle:
		reticle = get_node_or_null("../InteractionUI/Reticle") as ColorRect

	_update_prompt_ui()

func _process(_delta: float) -> void:
	if is_ui_blocked:
		current_target = null
		_update_prompt_ui()
		return

	_update_target()
	# Prompts are live state: the key, routing board, and seat can change their
	# action text while the crosshair stays on the same collider.
	_update_prompt_ui()

func set_cursor_target(target: Interactable) -> void:
	cursor_mode = true
	if target != null and not target.can_interact():
		target = null
	_cursor_target = target
	if _cursor_target != current_target:
		current_target = _cursor_target
		_update_prompt_ui()

func _unhandled_input(event: InputEvent) -> void:
	if is_ui_blocked:
		return

	if not cursor_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		_update_target()
		if current_target and current_target.can_interact():
			current_target.interact()
			get_viewport().set_input_as_handled()

func _update_target() -> void:
	if cursor_mode:
		var valid: Interactable = _cursor_target if (_cursor_target != null and _cursor_target.can_interact()) else null
		if valid != current_target:
			current_target = valid
			_update_prompt_ui()
		return
	var new_target: Interactable = null

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and interaction_ray:
		interaction_ray.force_raycast_update()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and interaction_ray and interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		if collider is Interactable and collider.can_interact():
			new_target = collider

	if new_target != current_target:
		current_target = new_target
		_update_prompt_ui()

func _update_prompt_ui() -> void:
	refresh_reticle()
	if not prompt_label:
		return

	if is_ui_blocked:
		var desk := get_tree().get_first_node_in_group(DeskAmendment.GROUP) as DeskAmendment
		prompt_label.visible = desk != null and desk.writing
		if prompt_label.visible:
			prompt_label.text = persistent_hint
			prompt_label.modulate.a = 1.0
		return

	var pointer_live := cursor_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if cursor_mode:
		prompt_label.offset_top = -98.0
		prompt_label.offset_bottom = -62.0
	var line := _cursor_prompt_line(current_target) if cursor_mode else prompt_line(current_target)
	if not line.is_empty() and pointer_live:
		prompt_label.text = line
		var bright := (current_target != null and (current_target.is_actionable or line == "The Way Out"))
		prompt_label.modulate.a = 1.0 if (not cursor_mode or bright) else STATUS_ALPHA
		prompt_label.visible = true
	elif not persistent_hint.is_empty() and pointer_live:
		prompt_label.text = persistent_hint
		prompt_label.modulate.a = STATUS_ALPHA
		prompt_label.visible = true
	else:
		prompt_label.visible = false

static func _cursor_prompt_line(target: Interactable) -> String:
	if target == null or not target.can_interact():
		return ""
	if not target.is_actionable:
		var prompt := target.get_prompt()
		if prompt in ["Write Correction at Desk First", "Locked Until the Watch Is Over", "The Way Out"]:
			return prompt
		return ""
	return target.get_prompt()

## The text printed for a target. The room shows state, overlays don't (GDD
## §35): a target E cannot act on prints nothing, and the quiet reticle says the
## rest. Its status text still lives on the Interactable for tests and tools.
static func prompt_line(target: Interactable) -> String:
	if target == null or not target.can_interact() or not target.is_actionable:
		return ""
	return "[E] %s" % target.get_prompt()

## Sets or clears the fallback prompt shown when nothing is targeted.
func set_persistent_hint(text: String) -> void:
	persistent_hint = text
	_update_prompt_ui()

## Crosshair feedback mirrors the real target. captured_override exists only so
## tests can drive the mouse state; production always reads Input.
func refresh_reticle(captured_override: Variant = null) -> void:
	if not reticle:
		return
	if cursor_mode:
		reticle.visible = false
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured_override != null:
		captured = bool(captured_override)
	if is_ui_blocked or not captured:
		reticle.visible = false
		return
	reticle.visible = true
	if current_target and current_target.can_interact() and current_target.is_actionable:
		reticle.color = ACTIONABLE_RETICLE_COLOR
	else:
		reticle.color = INACTIVE_RETICLE_COLOR

## Public refresh hook for pause/resume and other systems that change input
## capture state without moving the camera.
func refresh_prompt() -> void:
	_update_target()
	_update_prompt_ui()
