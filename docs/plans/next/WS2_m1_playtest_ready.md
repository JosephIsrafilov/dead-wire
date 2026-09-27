# WS2 — M1 готова к внешнему плейтесту: честный хук, решения с весом, подготовленное окно

**Цель:** первая ночь, в которой игрок **сам** замечает расхождение WATER/WATCHER, принимает хотя бы одно
настоящее решение, видит последствия и испытывает дискомфорт, отворачиваясь от окна. Затем — слепой
плейтест на 5 людях (GDD §22, §24 шаг 20).

**Зависит от:** WS1 (разделители ленты, флаг `critical_copy`, честность звука).

**Базовая линия:** как в `00_INDEX.md`. **Ограничение контента:** алфавит M1 — 18 знаков
`A C D E F G H I L N O R S T U W 1 7` (`data/morse/m1_american_morse_alphabet.tres`). Любой новый текст на
проводе — только из них (или сначала задача WS4.6 «полный алфавит»).

---

## Контракты существующего кода

- `TelegraphScenarioData` (`scripts/telegraph/session/telegraph_scenario_data.gd`): `scenario_id`,
  `transmission_data` (`true_message`, `elias_perception`, `written_transcript`), `expected_routing_action`,
  `commit_options: Array[TelegraphCommitOption]`, `commit_deadline_seconds` (в сессии).
- `TelegraphCommitOption` (`telegraph_commit_option.gd`): `action_id`, `display_label`, `knowledge_fact`, `world_fact`.
- `CopyCommitDesk` (`scripts/telegraph/ui/copy_commit_desk.gd`): `select_option(index)`, `stamp_contact` сигнал,
  `get_result_text()`.
- `DispatchLedger` (`scripts/telegraph/ui/dispatch_ledger.gd`): только чтение (правила + строки из KnowledgeState).
- `DutySheet` (`scripts/telegraph/ui/duty_sheet.gd`): `HEADER` со STANDING ORDERS, `get_watch_record()`.
- `ShiftDirector`: `wait_seconds_before_call`, `foreign_traffic_text/_slot/_after_seconds`, `_play_on_wire`.
- `MoonWeather`, `AttentionObservationTarget` (фигура), `LampLife` (фитиль), `TapeRegisterController.spring_tension`.

---

### Task 2.1 — Стол подшивки больше не выдаёт правду (#1) — **P0**

**Files:** `data/scenarios/m1_scenario_3_core_hook.tres`, `scripts/telegraph/ui/copy_commit_desk.gd`,
`scripts/telegraph/session/telegraph_commit_option.gd`, тест `tests/telegraph/copy_commit_desk_test.gd`.

**Дизайн:** две кнопки: **FILE AS COPIED** / **AMEND — WRITE CORRECTION**. «Исправить» открывает выбор из трёх
слов (данные сценария: `amend_candidates = ["WATCHER", "WATER", "WAITER"]` — все собираются из алфавита M1),
перемешанных детерминированно по seed смены. Правильный выбор = то, что на ленте. Неверное исправление —
тоже решение (факт `amended_wrong_core_hook`), не game over (GDD §3.3).

**Step 1 — RED:**
```gdscript
# (#1) The desk never names the true word before the operator commits.
var scen := load("res://data/scenarios/m1_scenario_3_core_hook.tres") as TelegraphScenarioData
for opt in scen.commit_options:
	if not assert_condition(not opt.display_label.contains(scen.transmission_data.true_message), "Commit label never names the true word: %s" % opt.display_label): return
```
**Step 3 — GREEN:** новые поля `amend_candidates: PackedStringArray`, `amend_correct: String` в сценарии;
`CopyCommitDesk.select_option(AMEND)` → показать три Label3D-плашки на столе (три дополнительных
Interactable, как `Option1Interactable`), выбор → факт. Existing facts `committed_water_core_hook` /
`committed_watcher_core_hook` сохраняют смысл (сводка `dawn_evidence.gd` их читает).

**Acceptance:** тест выше + прохождение: FILE AS COPIED → сводка «WATCHER»; AMEND→WATER → «WATER»;
AMEND→WAITER → новая ветка сводки «исправление не совпало с регистром». Обновить `first_night_playthrough.gd`.

**Commit:** `fix: the filing desk no longer names the true word; amending means reading the tape`

---

### Task 2.2 — Лента читается новичком (без компаратора) (#17)

**Files:** `scripts/telegraph/hardware/tape_register_controller.gd` (`get_tape_text`), `scripts/office/m1_office_controller.gd` (`_wrap_tape_text`).

**Правило:** вьюер разбивает ленту на **строки по паузам ≥ `BETWEEN_TRANSMISSIONS_GAP_UNITS`** (это правило рендера
GAP, не знание текста) и показывает последние сверху, с номером отрезка («— 3 —»). Буквенного декода нет.

**RED:** `tape_register_test.gd` — две передачи → `get_tape_text()` содержит ровно одну границу отрезков;
ни один символ, кроме `·`, `—`, пробела, перевода строки и номеров отрезков.
**Acceptance:** в плейтест-кадре отрезок WATER — отдельная последняя строка.

**Commit:** `feat: the register reads in segments split at long silences`

---

### Task 2.3 — Дедлайн подшивки под реальную работу проверки (#17)

**Files:** `data/scenarios/m1_scenario_3_core_hook.tres` (поле `commit_deadline_seconds`, перенести из кода
сессии в данные), сессия читает из сценария.
**Значение:** 50 с по умолчанию; финальное — по телеметрии плейтеста (Task 2.10). **Acceptance:** значение в `.tres`,
тесты используют поле, а не число.

---

### Task 2.4 — Подшивать каждую копию (приказ 5 честен) (#12)

**Files:** `data/scenarios/m1_scenario_1_baseline.tres`, `m1_scenario_2_attention.tres` (одна опция `FILE COPY`),
`copy_commit_desk.gd` (однокнопочный режим), `m1_office_controller.gd` (подсказка), duty sheet без изменений.
**RED:** `m1_office_integration_test.gd` — после маршрута сценария 1 сессия в `AWAITING_COMMIT`, стол активен.
**Acceptance:** все три копии подшиваются; штамп/звук на каждой; прохождение обновлено.

**Commit:** `feat: every copy is filed at the stove table, as the standing orders say`

---

### Task 2.5 — Маршрут, который требует ledger (#13)

**Files:** `data/scenarios/m1_scenario_2_attention.tres`, `scripts/telegraph/ui/dispatch_ledger.gd` (правило),
`telegraph_session_controller.gd` (проверка маршрута уже по `expected_routing_action`).
**Контент (из алфавита M1):** передача `FREIGHT 71 EAST` (вместо HOLD FREIGHT UNTIL TEN); правило ledger:
«Rule 44 — Freight east of Black Creek HOLDS while No. 17 is on the line.» → верно **HOLD**, хотя в тексте EAST.
Правило в ledger — печатный текст, игрок читает его во вьюере.
**Acceptance:** в 1 из 2 маршрутов верный ответ ≠ слово из телеграммы; тесты обновлены (строки вида
`"HOLD FREIGHT UNTIL TEN"` в тестах заменить на поле сценария).

**Commit:** `feat: the second order needs the ledger's Rule 44 to route`

---

### Task 2.6 — Видимые последствия маршрута (#14)

**Files:** `scripts/office/shift_director.gd` (служебная реплика в следующей паузе), `dispatch_ledger.gd`
(строка ночи), данные — в сценарии (`route_reply_right`, `route_reply_wrong` из алфавита M1:
`"17 OS"` / `"WHERE IS 17"` → только из разрешённых знаков: `"WHERE IS 17"` содержит W H E R E I S 1 7 ✓).
**Правило:** каждый записанный факт маршрута имеет потребителя в течение той же ночи: ответ по проводу
(лента его чернит) + строка в ledger «17 — reported past Hollis 00:14» / «17 — unreported».
**RED:** director test — после неверного маршрута в следующей паузе звучит `route_reply_wrong`, а не верный.
**Commit:** `feat: a route answers back on the wire and in the ledger`

---

### Task 2.7 — Дела со ставками (#11)

**Files:** `scripts/office/lamp_life.gd`, `scripts/ui/document_viewer.gd`, `scripts/telegraph/hardware/tape_register_controller.gd`.
- **Фитиль:** при `wick < 0.75` вьюер документов затемняет бумагу (`modulate` панели ∝ wick) — читать труднее.
- **Пружина:** при `spring_tension < 0.5` вьюер ленты показывает только «подтянутую» часть: последние N
  событий ещё «под пером» (не выведены). Запись не меняется (тест «Winding never touches the record» остаётся);
  меняется **показ** — «правда запаздывает» (research #3).
**RED:** atmosphere test — при низкой пружине `get_tape_text_for_viewer()` короче `get_tape_text()`;
после `wind()` — равны. Viewer-тест — затемнение при низком фитиле.
**Acceptance:** игнорирование дела заметно ≤60 с. **Commit:** `feat: a low wick darkens the page; a slack spring holds back the tape`

---

### Task 2.8 — Подготовить окно до хука (#15)

**Files:** `scripts/office/moon_weather.gd` (детерминированное событие), `scripts/office/shift_director.gd`
(триггер в паузе слота 1), `scripts/audio/office_ambience.gd` (провал «поющего провода»/ветра).
**Дизайн:** в паузе слота 1 один раз: облако гасит луну, одновременно ветер в проводах стихает на 3 с и
возвращается. Фигуры нет (§3.5 — одно событие). Игрок учится: «свет со стороны окна что-то значит».
**RED:** director test — в паузе слота 1 `moon.is_dimmed_now()` становится true ровно один раз; фигура невидима.
**Commit:** `feat: the window teaches itself once before the hook`

---

### Task 2.9 — Чужой трафик читается как жизнь провода (#16)

**Files:** `scripts/office/shift_director.gd`. Перед текстом — чужой позывной `DN DN` (станция Denver, из алфавита)
и пауза; вдобавок саундер тише на 4 дБ (дальняя станция).
**Acceptance:** прохождение — лента содержит отрезок позывного перед чужим трафиком; плейтест: ≤1/5 путают с поломкой.

---

### Task 2.10 — Телеметрия плейтеста

**Files:** Create `scripts/debug/playtest_telemetry.gd` (узел в офисе), пишет `user://playtest/<unix>.json`.
**События:** время ответа на каждый вызов, открытия ленты/карточки/ledger (с временем), выбор подшивки,
попадания в дедлайны, взгляды на окно (из `AttentionObservationTarget`), подрезки фитиля/заводы, итог сводки.
**RED:** тест — симулированная смена пишет JSON с ключами `calls`, `documents`, `commit`, `window_looks`.
**Commit:** `feat: local playtest telemetry per run`

---

### Task 2.11 — Решение по «ночь 1 vs хук» (#18) — документ, не код

**Files:** `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md` (исправить строку 5 «ничего не реализовано»),
`docs/design/DEAD_WIRE_GDD_v1.0.md` §21/§26.
**Решение для записи:** текущая ночь M1 — **вертикальный срез** («сжатая ночь 3»), чтобы плейтест проверил хук.
Кампанийная ночь 1 (WS5) будет чистой, без аномалий. Добавить одну таблицу соответствия.

---

### Task 2.12 — Слепой плейтест, 5 человек

**Files:** Create `docs/reports/2026-XX-XX_m1_blind_playtest.md` по шаблону:
- сборка (`builds/…zip`), наушники, без объяснений кроме «вы ночной телеграфист»;
- наблюдение молча; после — 6 вопросов: заметили расхождение? когда? как проверяли? неуютно ли
  отворачиваться от окна (1–5)? что было непонятно? что хотелось сделать и нельзя было?
- телеметрия JSON к каждому участнику.
**Гейты (из спецификации M1):** ≥70% замечают расхождение без подсказки; средний дискомфорт окна ≥3.5/5;
≤1/5 застревает дольше 60 с. Итог — список исправлений в WS2.

---

## Критерии готовности WS2
- [ ] 2.1 хук не выдан  - [ ] 2.2 лента по отрезкам  - [ ] 2.3 дедлайн в данных  - [ ] 2.4 каждая копия подшивается
- [ ] 2.5 маршрут через ledger  - [ ] 2.6 последствия  - [ ] 2.7 дела со ставками  - [ ] 2.8 окно подготовлено
- [ ] 2.9 чужой позывной  - [ ] 2.10 телеметрия  - [ ] 2.11 решение по ночи 1  - [ ] 2.12 плейтест 5 человек
- Плюс из WS3: 3.1 (HUD) и 3.2 (рычаг) обязательны до плейтеста.
