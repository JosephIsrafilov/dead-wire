# DEAD WIRE M1 — H1–H9 завершение: итоговый отчёт текущей сессии

> **⚠️ Исторический документ (сессия H1–H9).** Актуальный статус —
> [`docs/reports/m1_quality_finish_report.md`](m1_quality_finish_report.md)
> (P0–P5: B1–B3, Q1–Q7, локальная сборка). В частности, пункт 6.2 ниже
> («mid-write текст мелок, чтение через viewer») устарел: live-лист теперь
> читается во время письма (blind vision-подтверждено).

**Дата:** 2026-09-19 (вечер).
**База:** HEAD `70a8967` + рабочий tree пользователя (сохранён полностью; F1/F2 и corrections R1–R9 не откатывались).
**Задание:** `docs/m1_next_session_prompt.md` — закрыть H1–H9, закончить доступный объём V0–V7 / F3–F6.

---

## 1. Текущий статус (главное)

| Область | Статус | Ключевое доказательство |
|---|---|---|
| H1 часы | **закрыто** | director-owned station time; тесты WAITING→CALLING→RECEIVING монотонность, bounded speed, нет snap; маятник bob/rod, общая фаза с tick |
| H2 production-проверки | **закрыто** | `tools/production_evidence_capture.gd` — 0 failures, весь маршрут через реальный ввод (окно, не headless) |
| H3 подача листа | **закрыто** | два слоя бумаги, PREPARING-gate, отмена feed, стабильный anchor; 70+ assertions |
| H4 вставание | **закрыто** | stand-glide на детерминированном clock, свободная точка, отмена glide при ходьбе, отложенное включение collision кресла |
| H5 retained route | **закрыто** | per-slot reset ≠ физический результат; watch reset очищает; R01/R04 тесты |
| H6 атмосфера/звук | **инженерно закрыто** | creak anchors (6 Marker3D), pre-call hush once, buses Foley/Telegraph, flame проверен; **прослушивание — за человеком** |
| H7 ledger | **закрыто** | общий knowledge-backed словарь с DutySheet; unknown показывается как unknown; дата APRIL 1894 |
| H8 читаемость | **закрыто по vision** | нейтральная транскрипция full-frame: board читается после увеличения подписей; рука непрерывна; фигура читаема |
| H9 отчёты/манифест | **закрыто** | этот отчёт — верхний уровень; A07 честно reference-only; A05 — derived export; история вынесена |

**Regression:** 34 suites / **1637 assertions / 0 failed** (было 1546; +91 новых проверок).
**Production boot:** exit 0, 0 ошибок в логе. **Main-scene smoke:** PASSED.
**Полный ночной проход:** 73 PASS / 0 failures / 14 скриншотов + WAV.
**Production evidence (реальный ввод):** 46 PASS / **0 failures** / 6 скриншотов.
**Window evidence (logic fixture):** 15 PASS / **0 failures** / 4 скриншота.

## 2. Vision-проверки (provider/model и evidence)

Все проверки — **bandelbanget/glm-5.3-flash** через `tools/vision_check.py` (один ответ пришёл через fallback openrouter/z-ai/glm-5.3-flashx — зафиксировано в логе). Каждая запись: provider, model, время, SHA-256 кадра, вопрос, ответ — в `.dream-loop/vision_log.jsonl` (12 записей этой сессии). Секретов и reasoning в логе нет.

**Проверка самого helper перед использованием:** `--selftest` 8/8 (reasoning_content не вердикт, пустой контент не успех, finish_reason=length → inconclusive, все провайдеры упали → exit 1, пустая папка → exit 2). Обнаружено и исправлено в helper: `max_tokens` 600 → 2400 (модель тратила бюджет на рассуждения и возвращала пустой content — старый helper молча подставлял reasoning; теперь это честный inconclusive + retry).

| Проверка | Кадр | Вердикт |
|---|---|---|
| Board full-frame, ДО правки | playthrough 05_routing_0 (sha 9d94d2ae) | физические подписи **unreadable** — дефект H8 подтверждён нейтральной транскрипцией |
| Board full-frame, ПОСЛЕ правки | 05_routing_0 (sha 6906276b4c) | MAIN / CLEAR EAST / SIDING / HOLD читаются («faint but readable») |
| Header-карточка board | 05_routing_1 (sha 8716a251) | «EAST DIVISION» / «TRAIN ORDERS» читаются; текст не перекрыт рычагом/рамой |
| Рука, начало строки | 03_writing_0 | рука непрерывна, перо у бумаги, клиппинга нет (примечание: «длинная трубчатая» — стилистика PSX) |
| Рука, поздняя строка | 03_writing_2 | непрерывна, контакт пера есть |
| Архивный лист | 03_writing_0 | видны ДВА листа (архивный + активный) — новая подача H3 читается как бумага |
| Фигура в окне | window_evidence w2_seat_turn | силуэт с шляпой/плечами/торсом различим на лунном фоне; переплёты не режут |
| Viewer транскрипта | 04_transcript_2 | «TELEGRAM TRANSCRIPT (ELIAS CRANE)», «WATCHER», prompt читаются |
| Duty sheet | 02_orders | строки traffic/footer читаются полностью |

Замечание честности: транскрипция mid-write листа на физической бумаге (03_writing_*) остаётся «слишком мелкой для чтения» — это расстояние письма, чтение сделано viewer'ом по дизайну (§5.1 плана); карточка board — главный читаемый мировой текст — теперь читается.

## 3. Что изменилось по пунктам H1–H9

### H1 — часы
- `scripts/office/shift_director.gd`: директор владеет station time. Stage-события (open line 23:00; слот разрешён — 26:00/27:0; closing 29:18; shift over 06:00) задают **target**, а не значение. Display монотонно догоняет target: скорость = clamp(gap*0.25, 7ч/300с, 0.04ч/с). Внутри этапа target дрейфует к потолку этапа; 06:00 не пересекается до closing; на shift_closed нет финального snap — стрелки дожимаются на той же скорости и останавливаются на 06:00 сами.
- `scripts/office/station_clock.gd`: теперь presentation директора (`get_station_hours()`), никаких присваиваний на call/slot/closing, нет обратного хода. Маятник: настоящий `ClockPendulumPivot` + rod + bob (новые узлы в `office_storytelling_props.tscn`), качание rotation.x; стекло корпуса неподвижно. Фаза маятника читается из OfficeAmbience (`get_mechanical_elapsed()`) — один механический хрономиметр на комнату, tick на каждом полупериоде.
- Воспроизведённый дефект (25.17→23.0) закрыт тестами: h_wait→h_call→h_receive монотонны, bounded catch-up, «hands reach 6 A.M. at their bounded speed», «never crossed 06:00 before the shift ended».

### H2 — production-проверки
- `tools/production_evidence_capture.gd` переписан: движение — только Input-акции через реальный `move_and_slide` (max_step проверяется с учётом длительности кадра — hitch не телепорт); взгляд — синтетический `InputEventMouseMotion` через `Input.parse_input_event`, обрабатывается `_input` игрока (yaw clamp задействован и проверен: 115° из ±115°); каждое E — ray держит цель + действие `interact` через реальный pipeline (`InputEventAction` через `parse_input_event`); seated-кадры ассертят `is_seated && is_settled` и высоту камеры; Esc-pause замораживает симуляцию (тики не идут); между кадрами нет телепортов; director/session/scheduler/paper работают live. Требует окна (headless честно отказывается, exit 2).
- `tools/window_evidence_capture.gd`: заголовок честно называет его logic/visibility-фикстурой (production-доказательство — отдельный скрипт); w2 теперь реально снимается сидя (assert is_seated && is_settled).

### H3 — подача листа
- `transcript_paper.tscn`: `Sheet` (PaperMesh+Label3D+StationHeading) и `PreviousSheet` (архивный слой) — root, Interactable и WriterRig неподвижны: **interaction anchor стабилен**.
- `transcript_paper.gd`: `begin_writing` архивирует видимую копию на PreviousSheet (снимок текста), старый лист скользит к краю пачки; чистый лист подаётся (PREPARING, 0.3 c, детерминированный clock в `advance_paper`); рука входит только после укладки листа (`_finish_sheet_feed` → `rig.begin_writing`); cues буферизуются во время подачи (available cursor не теряется); `close_incomplete` отменяет feed; suspend во время PREPARING ставит feed на паузу, resume продолжает. Morse не задерживается ничем.

### H4 — вставание
- `operator_seat.gd`: body-glide переведён с tween на детерминированный clock в `_process` (как paper/rig). Sit: подход с клипом по коллизии (`_transform_clear` на каждом шаге — сквозь мебель не пройти), поворот к столу отменяется пользовательским взглядом. Stand: цель — сохранённая точка стояния, если она чиста, иначе ближайшая свободная у кресла; glide отменяется ходьбой (тело уже под управлением игрока), collision кресла пере-включается только когда тело ушло ≥0.8 м (нет depenetration-телепорта). Pitch-settle не воюет с мышью.
- Тесты: подход с трёх сторон, no-teleport кадры, свободная точка, повторные sit/stand, чистая посадка после glide.

### H5 — retained route
- `routing_board.gd`: `reset_for_new_transmission` сбрасывает только возможность ввода; lever/needle/`_last_route_action` живут до конца watch. `reset_for_new_watch` (вызывается из `load_scenario_by_index(0)`) очищает физический результат. `play_route_accept` ходит к абсолютным упорам от однократно снятого rest (без drift) и убивает предыдущий tween результата. Промпт: до решения — статус линии/действие, после — «Route recorded: …» до конца watch.

### H6 — атмосфера/звук
- `unease_director.gd`: creaks из 6 Marker3D-anchors сцены (пол/балка/углы/стена/дверь/печь); выбор исключает предыдущий anchor, <0.8 м от игрока, min separation; нет кандидатов — тишина, без ошибок и циклов. Pre-call hush: один раз за watch, в WAITING slot 0 при остатке ≤ pre_call_hush_seconds (не из call_started); короткий wait — доступная часть envelope; повторов нет (flag).
- `default_bus_layout.tres`: Master → **Ambience / Foley / Telegraph**. Sounder (messages+calls+nags+closing) — Telegraph; foley (paper/stamp/latch/chair/lever/door steps) — Foley. Настройки master/ambience пользователя работают как раньше; hush — локальный микс, не пользовательская громкость (тест сохранён).
- Flame: probe подтвердил привязку `flame_mesh` в production (Path `DeskSetup/OilLamp/Flame`), rest scale не дрейфует; добавлены flame-ассерты в atmosphere_test.

### H7 — ledger
- `duty_sheet.gd`: общий статический словарь статусов `knowledge_status()` + `core_hook_outcome()` — единая knowledge-backed логика для листа и журнала.
- `dispatch_ledger.gd`: NIGHT ENTRIES из общего словаря; filed без route-факта → «FILED» без выдуманного направления; incomplete+lapsed → «COPY INCOMPLETE / NO ORDER SENT»; commit-исходы — HEARD/WRITTEN COPY SEALED / UNFILED (+ COPY INCOMPLETE / UNFILED); missed → «NO COPY»; unscheduled-строка только при наличии записи; дата «NIGHT ENTRIES — APRIL 1894» согласована с остальными документами (никакого «23 APRIL»).

### H8 — читаемость
- Board: буквы физических подписей 2.6 см → ~4.5–5 см (pixel_size 0.0024→0.0035, font 11→13, темнее чернила, header в две строки «EAST DIVISION / TRAIN ORDERS»). Нейтральная full-frame транскрипция подтверждает чтение (см. §2). Без подсказок ожидаемого текста, обычная дистанция.
- Рука: непрерывность подтверждена на двух кадрах письма (начало/поздняя строка) + archived sheet виден.
- Окно: силуэт читаем, переплёты не режут (w2 — реально сидя).

### H9 — отчёты/манифест
- Этот отчёт — актуальный верхний статус; прежний итоговый отчёт `m1_asset_quality_pass_report.md` получил шапку с указанием на этот документ и помечен историей.
- `docs/third_party_assets.md`: A07 честно переведён в **reference-only** (в runtime — авторский CSG proxy `oil_lamp_lowpoly.tscn`, а не Poly Haven лампа; прежняя строка «runtime-instanced (pre-existing)» была неверна). A05: описан реальный derived export `m1_ledger_volumes.tscn` (4 тома, свои материалы/owners) — source-пак 67k tris не инстанцируется, owner-warning'и из boot-лога исчезли.

## 4. Команды и свежие результаты

~~~bash
# regression (34/1637/0)
rtk proxy env GODOT_BIN="/opt/homebrew/bin/godot" bash tools/run_all_tests.sh
# boot (exit 0, 0 errors)
godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn
# smoke
godot --headless --audio-driver Dummy --path . --script res://tests/integration/main_scene_smoke_test.gd
# полный ночной проход (окно): 73 PASS / 0 fail / 14 кадров + WAV
godot --path . --script res://tools/first_night_playthrough.gd -- --capture
# production route, реальный ввод (окно): 46 PASS / 0 fail / 6 кадров
godot --path . --script res://tools/production_evidence_capture.gd
# window logic fixture: 15 PASS / 0 fail / 4 кадра (окно) — headless даёт 10/10 логику без кадров
godot --path . --script res://tools/window_evidence_capture.gd
# vision: selftest + проверки кадров
python3 tools/vision_check.py --selftest
python3 tools/vision_check.py <png> "<нейтральный вопрос>"
~~~

## 5. Реально используемые assets (runtime)

PH стол/шкаф/кресло/derived-книги (CC0), Kenney impact (lever/stamp/chair, CC0), Luckius paper (viewer open/close, CC0). Синтезированные ambience-беды — прежние. A07 лампа — авторский proxy (reference-only, см. §3 H9). A08 — скачан, не подключён.

## 6. Честные оставшиеся ограничения

1. **Аудио-прослушивание (F4/F6 gate)** — audition/A-B выбранных SFX на наушниках/колонках за владельцем; `watch_audio.wav` (48 kHz) и `assets/audio/sfx/kenney_impact/*.ogg` готовы. Vision не слышит WAV.
2. **F7 blind playtest** — kit готов (`docs/reports/m1_f7_playtest_kit.md`); нужны 2–5 новых игроков. Model review ≠ playtest.
3. **Эстетическое решение владельца** — vision подтвердил факты читаемости/связности, не «нравится ли».
4. Мелочь: mid-write физический лист на расстоянии письма мелок для чтения (чтение — через viewer по дизайну); транскрипция требует внимательного взгляда.
5. Экспорт-пресет проекта не настроен — вопрос исключения source-only ассетов из дистрибутива встанет при сборке; в runtime-сцене они не инстанцируются.

**Status: engineering complete (H1–H9 в доступном объёме); audio acceptance и human acceptance (F7) — pending, как и требует план.**
