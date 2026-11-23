class_name SeatedHudCopy
extends RefCounted

## Duty strip copy for the 4-view seated workstation, separated to keep
## SeatedStationController focused on view/cursor orchestration.

const NOTICE_LINE_OPENED: int = 1
const NOTICE_POST_LOCKED: int = 2

static func post_lock_notice_text(kind: int) -> String:
	match kind:
		NOTICE_LINE_OPENED:
			return GameLocale.pick(
				"Линия открыта — покидать пост до конца смены нельзя",
				"Line open — do not leave the desk until the watch ends"
			)
		NOTICE_POST_LOCKED:
			return GameLocale.pick(
				"Линия открыта — встать из-за стола нельзя до конца смены",
				"Line is open — you cannot leave the desk until dawn"
			)
	return ""

static func duty_texts(
	office: M1OfficeController, current_view: int, view_enum: Variant, post_lock_notice: String = ""
) -> Dictionary:
	var primary := GameLocale.pick("ДЕЖУРСТВО — Следите за линией и окном", "STAND BY — Watch the wire and the yard")
	var sub := ""
	if office == null:
		return {"primary": primary, "sub": sub}

	var pen := office.get_node_or_null("DeskAmendment") as DeskAmendment
	if pen != null and pen.writing:
		primary = GameLocale.pick(
			"ПРАВКА — Впишите слово (латиницей), [Enter] Принять, [Esc] Отмена",
			"WRITING CORRECTION — Type word, [Enter] Keep on sheet, [Esc] Cancel"
		)
		return {"primary": primary, "sub": sub}

	var director := office.shift_director
	var session := office.session_controller
	var lamp_life := office.get_node_or_null("LampLife") as LampLife
	if director != null and director.is_shift_over():
		if office.dawn_evidence != null and office.dawn_evidence.is_revealed() \
				and not office.dawn_evidence.is_inspected():
			primary = GameLocale.pick(
				"СМЕНА ОКОНЧЕНА — Встаньте [Tab], прочтите передачу у двери и выходите",
				"WATCH OVER — Stand up [Tab], read the handover by the door, and leave"
			)
		elif office.office_door != null and not office.office_door.is_open:
			primary = GameLocale.pick(
				"СМЕНА ОКОНЧЕНА — Встаньте [Tab] и откройте южную дверь",
				"WATCH OVER — Stand up [Tab] and open the south door to leave"
			)
		else:
			primary = GameLocale.pick(
				"РАССВЕТ — Встаньте [Tab] и выйдите за порог",
				"DAWN — Stand up [Tab] and step out the doorway"
			)
	elif director != null and director.get_phase() == ShiftDirector.Phase.PRE_SHIFT:
		if lamp_life != null and lamp_life.wick < 0.72:
			primary = GameLocale.pick(
				"НАЧАЛО СМЕНЫ — Поправьте лампу, проверьте книги, нажмите ключ",
				"SHIFT START — Click lamp, check books, click brass key"
			)
		else:
			primary = GameLocale.pick(
				"НАЧАЛО СМЕНЫ — Проверьте расписание и журнал, затем нажмите ключ",
				"SHIFT START — Check Timetable & Ledger, then brass key"
			)
		sub = GameLocale.pick(
			"• Пока линия закрыта можно встать [Tab] · После открытия линии вставать до конца смены нельзя",
			"• You may stand [Tab] now · Once you open the line, you cannot leave the desk until dawn"
		)
	elif director != null and director.get_phase() == ShiftDirector.Phase.CALLING:
		primary = GameLocale.pick(
			"ВЫЗОВ — Нажмите телеграфный ключ%s",
			"INCOMING CALL — Click the brass key%s to answer"
		) % ("" if current_view == view_enum.DESK else " [W]")
	elif director != null and director.get_phase() == ShiftDirector.Phase.ANSWERING:
		primary = GameLocale.pick("ОТВЕТ ПРИНЯТ — Ждите передачу...", "LINE ANSWERED — Sender coming in...")
	elif session != null:
		match session.get_state():
			TelegraphSessionController.State.RECEIVING:
				primary = GameLocale.pick(
					"ПРИЁМ — Слушайте саундер; рука записывает",
					"COPYING INCOMING — Listen to the sounder; wait for pen to finish"
				)
			TelegraphSessionController.State.COPYING:
				primary = GameLocale.pick(
					"ДОПИСЫВАЕТ — Подождите, пока перо поднимется",
					"FINISHING COPY — Wait for the pen to lift"
				)
			TelegraphSessionController.State.VERIFYING:
				primary = GameLocale.pick(
					"ЗАПИСЬ ГОТОВА — Нажмите на лист%s для проверки",
					"COPY COMPLETE — Click the clipboard sheet%s to read & verify"
				) % ("" if current_view == view_enum.DESK else " [W]")
			TelegraphSessionController.State.AWAITING_ROUTE:
				if current_view != view_enum.LEFT_SIGNAL:
					primary = GameLocale.pick(
						"ПРИКАЗ ЖДЁТ — Повернитесь налево [A] к рычагу сигнала",
						"ORDER PENDING — Look left [A] and pull CLEAR EAST or HOLD"
					)
				else:
					primary = GameLocale.pick(
						"ПРИКАЗ ЖДЁТ — Выберите ПРОПУСТИТЬ или ДЕРЖАТЬ на рычаге",
						"ORDER PENDING — Click CLEAR EAST or HOLD on the lever"
					)
			TelegraphSessionController.State.AWAITING_COMMIT:
				if office.get_pending_correction().is_empty() and _slot_allows_correction(session):
					if current_view != view_enum.RIGHT_FILING:
						primary = GameLocale.pick(
							"ПОДШИВКА — Поставьте печать справа [D]",
							"FILE COPY — Pen lower sheet or stamp ORIGINAL [D]"
						)
					else:
						primary = GameLocale.pick(
							"ПОДШИВКА — Нажмите печать на столе",
							"FILE COPY — Stamp the copy on the desk"
						)
					sub = GameLocale.pick(
						"• Нужна правка — возьмите перо внизу листа [W]",
						"• To amend the copy — click the pen on the lower sheet [W]"
					)
				else:
					if current_view != view_enum.RIGHT_FILING:
						primary = GameLocale.pick(
							"ПОДШИВКА — Повернитесь направо [D] и поставьте печать",
							"FILE COPY — Look right [D] and stamp the copy"
						)
					else:
						primary = GameLocale.pick(
							"ПОДШИВКА — Поставьте печать на копию",
							"FILE COPY — Stamp the copy"
						)
			TelegraphSessionController.State.CONSEQUENCE:
				primary = GameLocale.pick("ПОДШИТО — Следите за двором", "ORDER FILED — Watch the night outside")

	var warning := session.get_deadline_warning_text() if session != null else ""
	var shutter := office.get_node_or_null("ServiceShutterEvent")
	var reg := session.get_tape_register() if session != null else null
	if not warning.is_empty():
		sub = "• %s" % warning
	elif not post_lock_notice.is_empty():
		sub = "• %s" % post_lock_notice
	elif shutter != null and shutter.has_method("has_unread_slip") and shutter.has_unread_slip():
		sub = GameLocale.pick(
			"• Записка под южной дверью — обернитесь [S]",
			"• Clearance slip slid under the south door — look back [S] to read"
		)
	elif reg != null and reg.needs_winding():
		sub = GameLocale.pick(
			"• Регистр замедляется — заведите ручкой справа на столе",
			"• Tape register slowing — click its side crank on the desk to wind"
		)

	return {"primary": primary, "sub": sub}

static func cursor_label(office: M1OfficeController, target: Interactable) -> String:
	if target == null or not target.can_interact():
		return ""
	var raw := target.get_prompt()
	var n: String = String(target.name)
	var pname: String = String(target.get_parent().name) if target.get_parent() != null else ""
	if n == "AmendInteractable":
		return GameLocale.pick("Взять перо — Вписать правку", "Pick Up Pen — Correct Copy")
	if n == "WickInteractable":
		return GameLocale.pick("Керосиновая лампа — %s", "Oil Lamp — %s") % raw
	if n == "LeanAtWindow":
		if not target.is_actionable:
			return GameLocale.pick(
				"Окно — Удерживайте ПКМ, чтобы прильнуть",
				"Window Glass — Hold RMB to Lean"
			)
		return raw
	if pname == "TelegraphKey":
		if target.is_actionable and office != null and office.shift_director != null \
				and office.shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT:
			return GameLocale.pick(
				"Открыть линию — после этого вставать нельзя",
				"Open the Line — locks you at the desk until dawn"
			)
		if not target.is_actionable:
			return GameLocale.pick(
				"Телеграфный ключ — %s (Пробел / Удерж. ЛКМ)",
				"Brass Key — %s (Space / Hold LMB)"
			) % raw
	if pname == "RoutingBoard" and not target.is_actionable:
		return GameLocale.pick("Поездной сигнал (%s)", "Train-Order Signal (%s)") % raw
	return raw

static func _slot_allows_correction(session: TelegraphSessionController) -> bool:
	var scen := session.get_current_scenario() if session != null else null
	if scen == null:
		return false
	for opt in scen.commit_options:
		if opt != null and opt.requires_correction:
			return true
	return false
