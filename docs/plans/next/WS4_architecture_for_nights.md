# WS4 — Архитектура под ночи 2–6

**Цель:** новая ночь = новый `.tres`, без правок `.gd`. God-объекты разбиты так, чтобы каждая часть
тестировалась отдельно. Проблемы `#19–#22`, `#34`, `#37`.

**Зависит от:** WS1. **Делать до WS5.** Весь поток — **рефакторинг без изменения поведения**: route 57 PASS и
playthrough 58 PASS до и после каждой задачи, кадры не меняются. Если тест меняется — только с литерала на
константу/поле данных, не по смыслу.

---

## Контракты существующего кода

- `ShiftDirector` (`scripts/office/shift_director.gd`, 753 строки): `enum Phase` (**только дописывать в конец** —
  `ANSWERING` уже последний), сигналы `phase_changed / shift_opened / call_started / call_answered /
  traffic_missed / route_deadline_started / route_defaulted / shift_closed`, `advance(delta)` (тесты крутят
  директора вручную), экспорты `wait_seconds_before_call`, `foreign_traffic_*`, `call_sign`, `route_deadline_seconds`,
  `closing_sign(_trouble)`, часовые константы `STATION_*`, строки `PROMPT_*`; стадии часов через `if count == 3` (стр. 372).
- `M1OfficeController` (`scripts/office/m1_office_controller.gd`, 740 строк): PSX-настройки, шрифт, фейды,
  связка сигналов (`_bind_signals` ~130 строк), список сценариев (`_get_scenario_list`), обработчики документов
  (`_on_*_inspected`), подсказки (`_update_transcript_prompt`, `_refresh_guidance`, `_update_key_feedback`),
  выход со смены (`_try_end_shift`), `scenario_id == "core_hook_water_watcher"` (стр. 400).
- `WorldStateStore` / `KnowledgeStateStore` (`scripts/state/`) — раздельные, не сливать.
- `DawnEvidence`, `DutySheet`, `DispatchLedger` читают факты из сторов.
- `TranscriptPaper` (654) и `WriterRig` (523) — таблица глифов продублирована (форма буквы на бумаге и путь пера).

---

### Task 4.1 — `NightData.tres` (#19)

**Files:** Create `scripts/night/night_data.gd` (`class_name NightData extends Resource`),
`data/nights/night_m1.tres`. После создания — `godot --headless --path . --import` (кэш `class_name`, HANDOVER §6).
**Поля (только то, что сейчас захардкожено — YAGNI):**
```gdscript
@export var night_index: int = 1
@export var scenarios: Array[TelegraphScenarioData] = []
@export var wait_seconds_before_call: PackedFloat32Array = PackedFloat32Array([20.0, 38.0, 50.0])
@export var call_sign: String = "CR CR"
@export var foreign_traffic_text: String = ""
@export var foreign_traffic_slot: int = -1
@export var closing_sign: String = "GN"
@export var closing_sign_trouble: String = "OS 17"
@export var clock_stage_at_scenario: PackedInt32Array = PackedInt32Array()  # replaces `count == 3`
@export var duty_sheet_header: String = ""
@export var hook_scenario_id: StringName = &""  # replaces the literal on m1_office_controller.gd:400
@export var audio_profile: Resource = null      # WS3.13
```
**RED:** `tests/night/night_data_test.gd` — `night_m1.tres` загружается; `scenarios.size() == 3`; значения совпадают с
текущими экспортами директора (сравнивать **с константами/полями**, не с литералами).
**GREEN:** `ShiftDirector.night: NightData` и `M1OfficeController.night: NightData`; при `night != null` значения
берутся из данных, экспорты остаются как запасной путь до конца WS4, затем удаляются (Task 4.8).
**Commit:** `refactor: the night is data — NightData resource for M1`

### Task 4.2 — Директор переходит к слоту отложенно (#21)

Если не сделано в WS1.4: `_advance_to_slot.call_deferred()` вместо прямого вызова из `session_completed`.
**RED:** тест подключает свой обработчик `session_completed` **до** директора и проверяет, что сессия ещё в
состоянии завершения, когда обработчик срабатывает (порядок подключения больше не важен).

### Task 4.3 — `WireService`: кто сейчас на проводе

**Проблема:** `_play_on_wire` вызывают вызов, чужой трафик, служебные сигналы, `GN`, ответы маршрута (WS2.6) —
каждый сам проверяет занятость. **Files:** Create `scripts/telegraph/session/wire_service.gd` (узел под сессией).
```gdscript
enum Priority { SERVICE, FOREIGN, CALL, TELEGRAM }
func request(text: String, priority: Priority) -> bool   # false = refused, nothing keyed
func is_busy() -> bool
signal finished(text: String)
```
Правило: `TELEGRAM` никогда не прерывается; более высокий приоритет ждёт следующей паузы ≥7 юнитов (не режет);
низший при занятости — отклоняется, вызывающий решает, повторять ли.
**RED:** `wire_service_test.gd` — FOREIGN во время TELEGRAM → false, лента не меняется; SERVICE после TELEGRAM → true.
**GREEN:** директор вызывает только `wire.request(...)`; `_play_on_wire` удалить.
**Commit:** `refactor: one wire service decides who keys the line`

### Task 4.4 — Разбить `ShiftDirector` (#20)

Цель ≤ 350 строк. Вынести:
- `StationClock` (`scripts/office/station_clock.gd`): `STATION_*`, скорость, догон, стадии из `NightData`;
  сигнал `stage_changed(stage)`.
- `KeyPrompt` (`scripts/office/key_prompt.gd`): все `PROMPT_*` + `refresh_key_state()`; после WS3.1 там остаются
  только глаголы.
- Директор оставляет фазы, таймеры, слоты.
**RED:** существующий `shift_director_test.gd` без изменений смысла; новые `station_clock_test.gd` (стадии по данным).
Порядок: сначала `StationClock` (чистые функции), потом `KeyPrompt`, коммит после каждого.

### Task 4.5 — Разбить `M1OfficeController` (#20)

Цель ≤ 350 строк. Вынести:
- `DocumentRouter` (`scripts/office/document_router.gd`): все `_on_*_inspected`, `_on_document_opened/closed`,
  `is_world_view_blocked`, обёртки текста ленты.
- `GuidanceHints` (`scripts/office/guidance_hints.gd`): `_update_transcript_prompt`, `_update_deadline_warning_footer`,
  `_update_key_feedback`, `_refresh_guidance`.
- `PsxPresentation` — **не выносить**: 30 строк, один пользователь (YAGNI).
Узлы добавляются в `m1_office.tscn` как дети офиса; контроллер находит их `get_node_or_null` (образец — `DawnRitual._ready`).
**Acceptance:** route 57 PASS, playthrough 58 PASS, `m1_office_integration_test` без правок смысла.

### Task 4.6 — Общая таблица глифов бумаги и пера

**Files:** Create `data/morse/glyph_map.tres` (или `scripts/telegraph/ui/glyph_map.gd` c `const`), источник для
`TranscriptPaper` и `WriterRig`. Заодно — расширение алфавита: какие буквы реально нужны ночам 2–6 (WS5) и
есть ли у них форма пера. Без формы пера буква на провод не идёт (тест).
**RED:** `glyph_map_test.gd` — каждый знак алфавита M1 имеет запись; запись одна на обоих потребителей.

### Task 4.7 — Тесты сравнивают с данными, а не литералами

`grep -rn '"HOLD FREIGHT UNTIL TEN"\|"CR CR"\|core_hook_water_watcher\|20.0, 38.0' tests/` → заменить на поля
сценария/`NightData`. Отдельный коммит: `test: suites read the night's data instead of pinning literals`.

### Task 4.8 — Уборка (#34, #37)

- Реквизит из `scenes/style_tests/props/` переехать в `scenes/props/` (обновить `ExtResource` пути; UID сохранить —
  перемещать через редактор или сохранить `.uid` рядом).
- Дубликат `StorageCabinet` (в `m1_office.tscn` и `style_tests/props/storage_cabinet.tscn`) — оставить один инстанс.
- `scenes/style_tests/m1_office_visual_spike.tscn` — удалить, если на него нет ссылок (`grep -rn visual_spike`).
- Удалить экспорты-дубликаты `NightData` из директора/контроллера (после 4.1).
- Мёртвый код: для каждой `func` без вызовов (`grep -rn "name(" scripts tests tools`) — удалить.
- `rewrite.py` в корне — удалить (подтвердить с владельцем, WS1.8).

### Task 4.9 — Хранилища состояния: одна точка доступа

Нужно только если в WS5 ≥3 новых потребителя ищут сторы по путям. Иначе пропустить.
Если нужно: `scripts/state/state_stores.gd` — `static func of(node: Node) -> Dictionary` возвращает
`{world, knowledge}` по дереву. Сторы не сливать.

---

## Критерии готовности WS4
- [ ] 4.1 NightData  - [ ] 4.2 deferred  - [ ] 4.3 WireService  - [ ] 4.4 директор ≤350  - [ ] 4.5 контроллер ≤350
- [ ] 4.6 глифы  - [ ] 4.7 тесты от данных  - [ ] 4.8 уборка  - [ ] 4.9 (по необходимости)
- `grep -rn 'core_hook_water_watcher' scripts/` → 0. Новая ночь добавляется без правок `.gd` (проверяется в WS5.3).
