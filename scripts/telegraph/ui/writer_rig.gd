class_name WriterRig
extends Node3D

## A small, anchored hand/pen presentation rig. It intentionally has no physics
## body: the transcript owns timing and this node only follows authored cues.
##
## Space contract (B2): every point and vector of the solve lives in ONE
## space — this rig's local space. World contacts enter through to_local of
## the rig itself; joint targets are computed as local transforms and applied
## as local transforms. A rigidly moved or rotated paper therefore produces an
## equivalent local pose: the hand writes the same way wherever the sheet is.
##
## Motion contract (Q2): glyphs are not teleports. Each glyph is a short,
## controlled motion from the current pose to the contact pose; the rig emits
## `glyph_contact` only when the nib has actually arrived, and the paper lets
## ink appear on that event — never on the cue alone.
##
## Reset contract (B3): full authored transforms (position AND basis) of the
## assembly and every joint are captured once and restored on reset, so no
## pose survives between sheets.
enum PresentationState {
	HIDDEN,
	ENTER,
	CONTACT,
	WRITING,
	LETTER_PAUSE,
	FINISH,
	WITHDRAWN,
}

signal glyph_contact(glyph_index: int)

@export var enter_duration: float = 0.18
@export var withdraw_duration: float = 0.22
@export var pause_lift: float = 0.008
## How far the wrist may translate from its rest position while following the
## letters (metres). Glyph travel beyond this is covered by rotating the
## forearm around its elbow instead — the hand chain (wrist->hand->pen) never
## separates because only whole-joint transforms move.
@export var wrist_travel_limit: float = 0.035
## The elbow pivot, in this rig's local space. The sleeve rotates around this
## point when a glyph lies beyond the wrist's fine travel.
@export var elbow_offset_rig: Vector3 = Vector3(0.0, 0.02, 0.0)
## One glyph's motion to its contact point: short, legible, never a jump.
@export var glyph_motion_duration: float = 0.06
## A row change is slightly longer: a small lift over the finished line.
@export var row_change_duration: float = 0.09
## Final rigid-reach bound: the whole assembly may translate this far as one
## piece when the contact's radius around the elbow differs from the nib's.
## Recomputed from the actual pose each glyph, so nothing accumulates; beyond
## this bound a residual stays VISIBLE as a solver defect.
@export var max_final_correction: float = 0.05

var presentation_state: PresentationState = PresentationState.HIDDEN
var _active_tween: Tween = null
var _last_nib_position: Vector3 = Vector3.ZERO
var _last_glyph_index: int = -1
var _assembly_rest_position: Vector3 = Vector3.ZERO
var _assembly_rest_captured: bool = false
var _hand_rest_position: Vector3 = Vector3.ZERO
var _nib_rest_position: Vector3 = Vector3.ZERO

## Full authored rests (B3): position AND basis of every moved joint.
var _sleeve_rest_transform: Transform3D = Transform3D.IDENTITY
var _wrist_rest_transform: Transform3D = Transform3D.IDENTITY
var _hand_rest_transform: Transform3D = Transform3D.IDENTITY
var _wrist_rest_position: Vector3 = Vector3.ZERO

## Manual entry clock, driven by the paper's presentation tick so "the hand has
## arrived" is one shared fact instead of two independent 0.18 s timers.
var _enter_elapsed: float = 0.0
var _enter_start: Vector3 = Vector3.ZERO
var _enter_target: Vector3 = Vector3.ZERO
## The pose the arm left when the operator stood up; resume returns to it.
var _resume_position: Vector3 = Vector3.ZERO
var _has_resume_position: bool = false
var _hand_resume_transform: Transform3D = Transform3D.IDENTITY
var _wrist_resume_transform: Transform3D = Transform3D.IDENTITY
var _sleeve_resume_transform: Transform3D = Transform3D.IDENTITY

## The glyph motion under way: start pose, target pose, clock.
var _motion_pending: bool = false
var _motion_glyph_index: int = -1
var _motion_elapsed: float = 0.0
var _motion_duration: float = 0.06
var _motion_is_row_change: bool = false
var _motion_sleeve_start: Transform3D = Transform3D.IDENTITY
var _motion_sleeve_target: Transform3D = Transform3D.IDENTITY
var _motion_wrist_start: Vector3 = Vector3.ZERO
var _motion_wrist_target: Vector3 = Vector3.ZERO
## The layout row of the last accepted glyph: a real row change is a change
## in the paper's fixed-column layout, not a rig-space Y wobble.
var _last_contact_row: int = -1

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

func _capture_rest_transforms() -> void:
	if _assembly_rest_captured:
		return
	# Prefer the authored sleeve path so capture is independent of ready-order
	# and of optional alternate assembly nodes used by test fixtures.
	var assembly := get_node_or_null("Sleeve") as Node3D
	if assembly == null:
		assembly = get_node_or_null("Assembly") as Node3D
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	var hand := get_node_or_null(_get_hand_path()) as Node3D
	if assembly != null:
		_assembly_rest_position = assembly.position
		_sleeve_rest_transform = assembly.transform
		_assembly_rest_captured = true
	if wrist != null:
		_wrist_rest_transform = wrist.transform
		_wrist_rest_position = wrist.position
	if hand != null:
		_hand_rest_transform = hand.transform

func get_presentation_state() -> PresentationState:
	return presentation_state

func is_active() -> bool:
	return presentation_state != PresentationState.HIDDEN and presentation_state != PresentationState.WITHDRAWN

## The hand is physically at the paper and ink may appear. ENTER does not
## qualify: the arm is still on its way in.
func is_ready_to_write() -> bool:
	return presentation_state == PresentationState.WRITING or presentation_state == PresentationState.LETTER_PAUSE

## A glyph motion is under way (the nib is travelling to its contact).
func is_motion_pending() -> bool:
	return _motion_pending

func get_nib_position() -> Vector3:
	return _get_nib_position()

func get_last_glyph_index() -> int:
	return _last_glyph_index

func get_rest_position() -> Vector3:
	return _assembly_rest_position

func is_rest_captured() -> bool:
	return _assembly_rest_captured

func begin_writing(_text: String = "") -> void:
	# A fresh sheet: the arm starts off the paper and enters to its rest pose.
	_cancel_tween()
	_capture_rest_transforms()
	_restore_joint_rests()
	_last_glyph_index = -1
	_last_contact_row = -1
	_motion_pending = false
	_has_resume_position = false
	var assembly := _get_assembly()
	if assembly != null:
		assembly.position = _assembly_rest_position + Vector3(0.0, 0.0, 0.11)
	_begin_enter(_assembly_rest_position)

## The operator came back: the arm returns to the pose it left, with its glyph
## index and authoring history intact. Never resets the cursors.
func resume_writing() -> void:
	if is_ready_to_write() or presentation_state == PresentationState.ENTER:
		return
	# The withdrawal tween from finish_writing() must be dead before the
	# resume transforms are restored: a live tween keeps writing into
	# Sleeve.position and fights the re-entry.
	_cancel_tween()
	_motion_pending = false
	var hand := get_node_or_null(_get_hand_path()) as Node3D
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	var sleeve := _get_assembly()
	if hand != null:
		hand.transform = _hand_resume_transform
	if wrist != null:
		wrist.transform = _wrist_resume_transform
	if sleeve != null:
		sleeve.transform = _sleeve_resume_transform
	_begin_enter(_resume_position if _has_resume_position else _assembly_rest_position)

## The operator stood up: withdraw, but remember the pose for the return.
func suspend() -> void:
	if not is_active():
		return
	var assembly := _get_assembly()
	if assembly != null:
		_resume_position = assembly.position
		_has_resume_position = true
		_sleeve_resume_transform = assembly.transform
	var hand := get_node_or_null(_get_hand_path()) as Node3D
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	if hand != null:
		_hand_resume_transform = hand.transform
	if wrist != null:
		_wrist_resume_transform = wrist.transform
	_motion_pending = false
	finish_writing()

func _begin_enter(target: Vector3) -> void:
	presentation_state = PresentationState.ENTER
	_apply_visibility(true)
	_enter_elapsed = 0.0
	_enter_target = target
	var assembly := _get_assembly()
	if assembly == null or not is_inside_tree() or enter_duration <= 0.0:
		if assembly != null:
			assembly.position = target
		presentation_state = PresentationState.WRITING
		return
	_enter_start = assembly.position

## Deterministic clocks: entry and glyph motion both advance here, and one
## tick's time is spent ONCE. Production advances this from the paper's frame
## tick; tests advance it directly. Returns the time the tick did NOT consume:
## entry first, then any in-flight motion, sequentially — so a caller that
## starts a motion mid-tick may hand it only the honest remainder.
func advance_presentation(delta: float) -> float:
	var remaining := maxf(delta, 0.0)
	if presentation_state == PresentationState.ENTER:
		remaining -= _advance_entry(remaining)
	if _motion_pending and remaining > 0.0:
		remaining -= _advance_motion(remaining)
	return maxf(remaining, 0.0)

## Advances the entry clock by at most `delta`. Returns the time actually
## consumed, so an entry that completes mid-tick leaves the rest of the tick
## honestly unused.
func _advance_entry(delta: float) -> float:
	if presentation_state != PresentationState.ENTER or delta <= 0.0:
		return 0.0
	var before := _enter_elapsed
	_enter_elapsed += delta
	var t := clampf(_enter_elapsed / maxf(enter_duration, 0.0001), 0.0, 1.0)
	var assembly := _get_assembly()
	if assembly != null:
		var eased: float = sin(t * PI * 0.5)
		assembly.position = _enter_start.lerp(_enter_target, eased)
	if t >= 1.0:
		presentation_state = PresentationState.WRITING
		return clampf(enter_duration - before, 0.0, delta)
	return delta

## Request the motion that brings the nib onto glyph `glyph_index` of `text`.
## Returns false when the rig cannot accept it (not at the paper, or a motion
## is already under way). The nib travels; `glyph_contact` fires on arrival.
func request_glyph_motion(glyph_index: int, text: String) -> bool:
	var settled_states := [
		PresentationState.HIDDEN, PresentationState.WITHDRAWN,
		PresentationState.ENTER, PresentationState.FINISH
	]
	if presentation_state in settled_states:
		return false
	if _motion_pending:
		return false
	if text.is_empty():
		return false
	var glyph_count := _glyph_count(text)
	if glyph_index < 0 or glyph_index >= glyph_count:
		return false
	var paper := get_parent() as TranscriptPaper
	if paper == null or not is_inside_tree():
		return false

	_last_glyph_index = glyph_index

	# The whole solve happens in this rig's local space (B2). The world
	# contact enters through the rig's own inverse transform.
	var contact_rig := to_local(paper.to_global(paper.get_glyph_contact(glyph_index)))
	# A row change is decided by the paper's own layout contract — the same
	# fixed columns that place the ink — not by hoping a rig-space Y delta
	# survives this rig's orientation.
	var row := _layout_row_of_glyph(text, glyph_index)
	_motion_is_row_change = _last_contact_row >= 0 and row != _last_contact_row

	var sleeve := _get_assembly()
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if sleeve == null or wrist == null or nib == null:
		return false

	# --- solve the target pose, entirely in rig-local space ---
	# The solve is a two-pass reach, and every step is measured:
	#   1) wrist fine travel toward the contact, clamped to its physical limit;
	#   2) the sleeve swings around the explicit elbow pivot (rig-local);
	#   3) once more with whatever travel remains in the wrist;
	#   4) a final rigid translation of the whole assembly — bounded, and
	#      recomputed from the actual pose each glyph, so nothing accumulates
	#      and no joint ever separates (B2: no cumulative hiding, but an
	#      honest reach when the contact's radius around the elbow differs
	#      from the nib's).
	var sleeve_original := sleeve.transform
	var wrist_original := wrist.position
	var wrist_target := wrist.position
	var sleeve_target := sleeve.transform
	for pass_index in 2:
		var tip_pass := to_local(nib.to_global(Vector3(0, -0.011, 0)))
		var d_pass := contact_rig - tip_pass
		# Wrist fine travel in its own parent (sleeve) space.
		var d_sleeve := sleeve_target.basis.inverse() * d_pass
		var wrist_offset := wrist_target - _wrist_rest_position
		var desired := wrist_offset + d_sleeve
		if desired.length() > wrist_travel_limit:
			desired = desired.normalized() * wrist_travel_limit
		wrist_target = _wrist_rest_position + desired
		wrist.position = wrist_target
		var tip_after_wrist := to_local(nib.to_global(Vector3(0, -0.011, 0)))
		var residual := contact_rig - tip_after_wrist
		if residual.length() <= 0.00005:
			break
		var elbow := _assembly_rest_position + elbow_offset_rig
		var to_nib := tip_after_wrist - elbow
		var to_contact := contact_rig - elbow
		if to_nib.length() > 0.0001 and to_contact.length() > 0.0001:
			var axis := to_nib.cross(to_contact)
			if axis.length() > 0.000001:
				var angle := to_nib.angle_to(to_contact)
				var rot := Basis(axis.normalized(), angle)
				sleeve_target = Transform3D(
					rot * sleeve_target.basis,
					elbow + rot * (sleeve_target.origin - elbow))
		sleeve.transform = sleeve_target
	# Final bounded rigid translation: the arm reaches as a whole, joints
	# locked. Beyond the bound the residual stays visible as a solver defect.
	sleeve.transform = sleeve_target
	wrist.position = wrist_target
	var tip_final := to_local(nib.to_global(Vector3(0, -0.011, 0)))
	var correction := contact_rig - tip_final
	if correction.length() <= max_final_correction:
		sleeve_target.origin += correction
	# Restore the CURRENT pose: the motion below travels from where the hand
	# actually is to the solved target.
	sleeve.transform = sleeve_original
	wrist.position = wrist_original

	# --- record and start the motion (Q2) ---
	_motion_sleeve_start = sleeve.transform
	_motion_sleeve_target = sleeve_target
	_motion_wrist_start = wrist.position
	_motion_wrist_target = wrist_target
	_motion_glyph_index = glyph_index
	_motion_elapsed = 0.0
	_motion_duration = row_change_duration if _motion_is_row_change else glyph_motion_duration
	_motion_pending = true
	_last_contact_row = row
	presentation_state = PresentationState.WRITING
	return true

## Advances the in-flight motion by at most `delta`. Returns the time
## actually consumed; the contact fires only when the nib has truly arrived.
func _advance_motion(delta: float) -> float:
	if not _motion_pending or delta <= 0.0:
		return 0.0
	var before := _motion_elapsed
	_motion_elapsed += delta
	var t := clampf(_motion_elapsed / maxf(_motion_duration, 0.0001), 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	var sleeve := _get_assembly()
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	if sleeve != null:
		sleeve.transform = _motion_sleeve_start.interpolate_with(_motion_sleeve_target, eased)
	if wrist != null:
		var lerped := _motion_wrist_start.lerp(_motion_wrist_target, eased)
		if _motion_is_row_change:
			# A small lift over the finished line: the nib hops, it does not
			# scrape across the paper.
			lerped += Vector3(0.0, sin(PI * t) * pause_lift, 0.0)
		wrist.position = lerped
	if t >= 1.0:
		# Arrived: the exact target pose, then the contact event the paper
		# has been waiting for. Ink appears now, not on the cue.
		if sleeve != null:
			sleeve.transform = _motion_sleeve_target
		if wrist != null:
			wrist.position = _motion_wrist_target
		var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
		if nib != null:
			_last_nib_position = nib.global_position
		_motion_pending = false
		presentation_state = PresentationState.WRITING
		glyph_contact.emit(_motion_glyph_index)
		return clampf(_motion_duration - before, 0.0, delta)
	return delta

## Legacy entry point kept so older callers and the saved diagnostic probe
## still compile: it routes into the request/motion flow.
func set_writing_progress(_ratio: float, text: String = "", visible_characters: int = 0) -> void:
	if text.is_empty() or visible_characters < 0:
		return
	request_glyph_motion(clampi(visible_characters, 0, _glyph_count(text) - 1), text)

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
	_motion_pending = false
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
	_active_tween.tween_property(assembly, "position", target, withdraw_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.finished.connect(func():
		if presentation_state == PresentationState.FINISH:
			presentation_state = PresentationState.WITHDRAWN
			_apply_visibility(false)
	)

## B3: the full authored pose — assembly AND joints, position AND basis —
## returns. Nothing of the last sheet survives into the next one.
func reset() -> void:
	_cancel_tween()
	presentation_state = PresentationState.HIDDEN
	_last_glyph_index = -1
	_last_contact_row = -1
	_has_resume_position = false
	_motion_pending = false
	_enter_elapsed = 0.0
	_apply_visibility(false)
	_capture_rest_transforms()
	var assembly := _get_assembly()
	if assembly != null and _assembly_rest_captured:
		assembly.transform = _sleeve_rest_transform
	_restore_joint_rests()
	_last_nib_position = _get_nib_position()

func _restore_joint_rests() -> void:
	var wrist := get_node_or_null("Sleeve/Wrist") as Node3D
	var hand := get_node_or_null(_get_hand_path()) as Node3D
	var nib := get_node_or_null("%s/Pen/Nib" % _get_hand_path()) as Node3D
	if wrist != null:
		wrist.transform = _wrist_rest_transform
	if hand != null:
		hand.transform = _hand_rest_transform
	if nib != null:
		nib.position = _nib_rest_position

func _glyph_count(text: String) -> int:
	var count := 0
	for index in text.length():
		if not _is_layout_whitespace(text.substr(index, 1)):
			count += 1
	return count

## One whitespace contract, shared with the paper: these characters carry no
## glyph and never receive a contact.
func _is_layout_whitespace(character: String) -> bool:
	return character in [" ", "\t", "\n", "\r"]

## The layout row a glyph lives on, from the same fixed-column contract the
## paper's ink layout uses (TranscriptPaper.GLYPH_COLUMNS).
func _layout_row_of_glyph(text: String, glyph_index: int) -> int:
	var glyph := 0
	for index in text.length():
		if _is_layout_whitespace(text.substr(index, 1)):
			continue
		if glyph == glyph_index:
			return index / TranscriptPaper.GLYPH_COLUMNS
		glyph += 1
	return 0

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

func _get_assembly_path() -> String:
	return "Assembly" if get_node_or_null("Assembly") != null else "Sleeve"

func _get_hand_path() -> String:
	var assembly_path := _get_assembly_path()
	var wrist_hand := "%s/Wrist/Hand" % assembly_path
	if get_node_or_null(wrist_hand) != null:
		return wrist_hand
	return "%s/Hand" % assembly_path

func _cancel_tween() -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
