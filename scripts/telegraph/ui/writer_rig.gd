class_name WriterRig
extends Node3D

## A small, anchored hand/pen presentation rig. It intentionally has no physics
## body: the transcript owns timing and this node only follows authored cues.
enum PresentationState {
	HIDDEN,
	ENTER,
	CONTACT,
	WRITING,
	LETTER_PAUSE,
	FINISH,
	WITHDRAWN,
}

@export var enter_duration: float = 0.18
@export var withdraw_duration: float = 0.22
@export var pause_lift: float = 0.008

var presentation_state: PresentationState = PresentationState.HIDDEN
var _active_tween: Tween = null
var _last_nib_position: Vector3 = Vector3.ZERO
var _last_glyph_index: int = -1
var _assembly_rest_position: Vector3 = Vector3.ZERO
var _assembly_rest_captured: bool = false
var _hand_rest_position: Vector3 = Vector3.ZERO
var _nib_rest_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_apply_visibility(false)
	_capture_rest_transforms()
	_last_nib_position = _get_nib_position()
	var hand := get_node_or_null("%s" % _get_hand_path()) as Node3D
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if hand != null:
		_hand_rest_position = hand.position
	if nib != null:
		_nib_rest_position = nib.position
	call_deferred("_capture_rest_transforms")

func get_presentation_state() -> PresentationState:
	return presentation_state

func is_active() -> bool:
	return presentation_state != PresentationState.HIDDEN and presentation_state != PresentationState.WITHDRAWN

func get_nib_position() -> Vector3:
	return _get_nib_position()

func get_last_glyph_index() -> int:
	return _last_glyph_index

func get_rest_position() -> Vector3:
	return _assembly_rest_position

func is_rest_captured() -> bool:
	return _assembly_rest_captured

func begin_writing(text: String = "") -> void:
	_cancel_tween()
	_capture_rest_transforms()
	_last_glyph_index = -1
	presentation_state = PresentationState.ENTER
	_apply_visibility(true)
	var assembly := _get_assembly()
	if assembly == null:
		presentation_state = PresentationState.WRITING
		return
	var rest := _assembly_rest_position
	assembly.position = rest + Vector3(0.0, 0.0, 0.11)
	if not is_inside_tree() or enter_duration <= 0.0:
		assembly.position = rest
		presentation_state = PresentationState.WRITING
		return
	_active_tween = create_tween()
	_active_tween.tween_property(assembly, "position", rest, enter_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.finished.connect(func():
		if presentation_state == PresentationState.ENTER:
			presentation_state = PresentationState.WRITING
	)

## Position the nib over the current glyph before TranscriptPaper updates its
## Label3D. A direct transform per cue keeps the motion deterministic and avoids
## spawning one Tween for every mark.
func set_writing_progress(ratio: float, text: String = "", visible_characters: int = 0) -> void:
	if presentation_state == PresentationState.HIDDEN or presentation_state == PresentationState.WITHDRAWN:
		return
	var glyph_count := _glyph_count(text)
	if glyph_count <= 0:
		return
	var target_glyph := clampi(visible_characters, 0, glyph_count - 1)
	if target_glyph < _last_glyph_index:
		return
	_last_glyph_index = target_glyph
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if nib == null:
		return
	# Move the entire arm. Moving Nib alone detached the metal tip from its pen.
	_cancel_tween()
	var paper := get_parent() as TranscriptPaper
	var assembly := _get_assembly()
	if paper != null and assembly != null and is_inside_tree():
		var contact := paper.to_global(paper.get_glyph_contact(target_glyph))
		var tip := nib.to_global(Vector3(0, -0.011, 0))
		assembly.global_position += contact - tip
	_last_nib_position = nib.global_position if is_inside_tree() else nib.position
	presentation_state = PresentationState.WRITING

func mark_letter_pause() -> void:
	if is_active():
		presentation_state = PresentationState.LETTER_PAUSE
		var hand := get_node_or_null(_get_hand_path()) as Node3D
		if hand != null:
			hand.position.y = _hand_rest_position.y + pause_lift

func finish_writing() -> void:
	if presentation_state == PresentationState.HIDDEN or presentation_state == PresentationState.WITHDRAWN:
		_apply_visibility(false)
		return
	_cancel_tween()
	presentation_state = PresentationState.FINISH
	var assembly := _get_assembly()
	if assembly == null:
		presentation_state = PresentationState.WITHDRAWN
		_apply_visibility(false)
		return
	var target := assembly.position + Vector3(0.0, 0.0, 0.11)
	if not is_inside_tree() or withdraw_duration <= 0.0:
		assembly.position = target
		presentation_state = PresentationState.WITHDRAWN
		_apply_visibility(false)
		return
	_active_tween = create_tween()
	_active_tween.tween_property(assembly, "position", target, withdraw_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.finished.connect(func():
		if presentation_state == PresentationState.FINISH:
			presentation_state = PresentationState.WITHDRAWN
			_apply_visibility(false)
	)

func reset() -> void:
	_cancel_tween()
	presentation_state = PresentationState.HIDDEN
	_last_glyph_index = -1
	_apply_visibility(false)
	var assembly := _get_assembly()
	if assembly != null and _assembly_rest_captured:
		assembly.position = _assembly_rest_position
	var hand := get_node_or_null(_get_hand_path()) as Node3D
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if hand != null:
		hand.position = _hand_rest_position
	if nib != null:
		nib.position = _nib_rest_position

func _glyph_count(text: String) -> int:
	var count := 0
	for index in text.length():
		var glyph := text.substr(index, 1)
		if glyph not in [" ", "\t", "\n", "\r"]:
			count += 1
	return count

func _get_nib_position() -> Vector3:
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if nib == null:
		return Vector3.ZERO
	return nib.global_position if is_inside_tree() else nib.position

func _apply_visibility(value: bool) -> void:
	var assembly := _get_assembly()
	if assembly != null:
		assembly.visible = value

func _get_assembly() -> Node3D:
	var assembly := get_node_or_null("Assembly") as Node3D
	if assembly != null:
		return assembly
	return get_node_or_null("Sleeve") as Node3D

func _capture_rest_transforms() -> void:
	if _assembly_rest_captured:
		return
	# Prefer the authored sleeve path so capture is independent of ready-order
	# and of optional alternate assembly nodes used by test fixtures.
	var assembly := get_node_or_null("Sleeve") as Node3D
	if assembly == null:
		assembly = get_node_or_null("Assembly") as Node3D
	if assembly != null:
		_assembly_rest_position = assembly.position
		_assembly_rest_captured = true

func _get_assembly_path() -> String:
	return "Assembly" if get_node_or_null("Assembly") != null else "Sleeve"

func _get_hand_path() -> String:
	var assembly_path := _get_assembly_path()
	return "%s/Wrist/Hand" % assembly_path if get_node_or_null("%s/Wrist/Hand" % assembly_path) != null else "%s/Hand" % assembly_path

func _cancel_tween() -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
