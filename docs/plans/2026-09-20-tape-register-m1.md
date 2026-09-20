# Tape Register (M1) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Лентопишущий регистр — второй рендер того же MorseRuntimeScheduler: чернильные точки-тире на непрерывно ползущей бумажной ленте, читаемые игроком как несокрушимый якорь истины.

**Architecture:** `TapeRegisterController` подписывается на сигналы существующего `MorseRuntimeScheduler` (как `SounderController`), накапливает `MorseScheduledEvent` в собственный буфер записи и рендерит их как текстовую ленту (Лентопись: MARK → `·`/`—`, GAP → пробел). Чтение — через существующий `DocumentViewer`. Лента не имеет доступа к тексту передач вообще: только MARK/GAP/duration_units. Честность по построению.

**Tech Stack:** Godot 4.7 / GDScript. Тесты — SceneTree-скрипты, запускаются `godot --headless --audio-driver Dummy --path . --script <path>`; полный прогон `bash tools/run_all_tests.sh`.

**Дизайн-документ:** `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md`, секция 4 (Лентопишущий регистр). Защищённые правила: лента пишет ВСЁ (трафик, шум, служебные повторы, стук в закрытую линию); лента никогда не лжёт (у неё нет текста); автокомпаратора с листом НЕТ.

**Базовая линия на момент планирования:** 37 suites / 1847 assertions, все зелёные. Перед началом прогнать `bash tools/run_all_tests.sh` и убедиться в том же числе.

---

## Контракты существующего кода (читать перед задачами)

### MorseRuntimeScheduler (`scripts/telegraph/morse/morse_runtime_scheduler.gd`)

Сигналы:
```gdscript
signal timing_event_started(event: MorseScheduledEvent)
signal timing_event_finished(event: MorseScheduledEvent)
signal playback_time_advanced(previous_seconds: float, current_seconds: float)
signal playback_completed(schedule: MorsePlaybackScheduleData)
signal playback_cancelled(schedule: MorsePlaybackScheduleData, elapsed_seconds: float)
```

### MorseScheduledEvent (`scripts/telegraph/morse/morse_scheduled_event.gd`)

```gdscript
var event_index: int          # порядковый в расписании
var kind: MorseTimingEvent.Kind   # Kind.MARK или Kind.GAP
var duration_units: int       # длина в единицах тайминга: 1-2 = точка, длиннее = тире
var start_seconds: float
var duration_seconds: float
var end_seconds: float
```

### SounderController — паттерн подписки (`scripts/telegraph/hardware/sounder_controller.gd:78-104`)

`connect_scheduler(scheduler)` / `disconnect_scheduler()` с проверкой `is_connected` перед connect/disconnect. Копируем патрон целиком.

### DocumentViewer (`scripts/ui/document_viewer.gd`)

```gdscript
func open_document(doc_id: String, title: String, body: String, footer: String = "") -> void
func is_open() -> bool
signal document_opened(doc_id: String)
signal document_closed(doc_id: String)
```

### Интерполяция знака (как её делает лента)

Американское морзе на бумажной ленте: MARK → чернильная отметка, длина ∝ `duration_units`.
Текстовое представление для чтения (моноширинное):
- MARK с `duration_units <= 2` → `·`
- MARK с `duration_units >= 3` → `—`
- GAP → пробел (по одному символу на unit, минимум 1; межбуквенный/межсловный GAP различаются длиной и на ленте видны как длинный пустой пробел — этого достаточно)

---

### Task 1: TapeRegisterController — буфер записи + подписка (RED)

**Files:**
- Create: `scripts/telegraph/hardware/tape_register_controller.gd`
- Test: `tests/telegraph/tape_register_test.gd`

**Step 1: Write the failing test**

```gdscript
extends SceneTree

## Tape register contract (design doc §4): the tape is a second renderer of
## the SAME scheduler timeline the sounder plays. It records every MARK/GAP
## event verbatim and has no access to message text at all.

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Register Test Suite ---")
	# 1. Instantiates and starts empty.
	var tape := load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(tape)
	await process_frame
	if not _a(tape.get_record().is_empty(), "Tape starts empty"): return

	# 2. Records MARK/GAP verbatim from scheduler events.
	var ev_mark := MorseScheduledEvent.new()
	ev_mark.kind = MorseTimingEvent.Kind.MARK
	ev_mark.duration_units = 1
	var ev_gap := MorseScheduledEvent.new()
	ev_gap.kind = MorseTimingEvent.Kind.GAP
	ev_gap.duration_units = 3
	tape._on_timing_event_started(ev_mark)
	tape._on_timing_event_started(ev_gap)
	if not _a(tape.get_record().size() == 2, "Two events recorded verbatim"): return
	if not _a(tape.get_record()[0].kind == MorseTimingEvent.Kind.MARK
		and tape.get_record()[1].kind == MorseTimingEvent.Kind.GAP,
		"Kinds preserved in order"): return

	# 3. connect/disconnect follows the sounder pattern.
	var sched: MorseRuntimeScheduler = MorseRuntimeScheduler.new()
	root.add_child(sched)
	tape.connect_scheduler(sched)
	if not _a(sched.timing_event_started.is_connected(tape._on_timing_event_started),
		"connect_scheduler hooks timing_event_started"): return
	tape.disconnect_scheduler()
	if not _a(not sched.timing_event_started.is_connected(tape._on_timing_event_started),
		"disconnect_scheduler unhooks cleanly"): return

	# 4. reset clears the record but not the subscription lifecycle.
	tape.reset()
	if not _a(tape.get_record().is_empty(), "reset clears the tape"): return

	tape.queue_free()
	sched.queue_free()
	print("--- All Tape Register Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_register_test.gd`
Expected: FAIL — скрипт не найден / class not defined.

**Step 3: Write minimal implementation**

```gdscript
class_name TapeRegisterController
extends Node

## The paper-tape register (design doc §4): a mechanical recorder that inks
## every MARK/GAP of the objective scheduler timeline onto a continuously
## fed paper strip. It is the sounder's silent twin — same signals, no sound,
## and NO access to message text whatsoever: it cannot lie by construction.

var _record: Array[MorseScheduledEvent] = []
var _connected_scheduler: MorseRuntimeScheduler = null

func get_record() -> Array[MorseScheduledEvent]:
	return _record

func connect_scheduler(scheduler: MorseRuntimeScheduler) -> void:
	if scheduler == null:
		return
	disconnect_scheduler()
	_connected_scheduler = scheduler
	if not scheduler.timing_event_started.is_connected(_on_timing_event_started):
		scheduler.timing_event_started.connect(_on_timing_event_started)

func disconnect_scheduler() -> void:
	if _connected_scheduler == null:
		return
	if _connected_scheduler.timing_event_started.is_connected(_on_timing_event_started):
		_connected_scheduler.timing_event_started.disconnect(_on_timing_event_started)
	_connected_scheduler = null

func reset() -> void:
	_record.clear()

func _on_timing_event_started(event: MorseScheduledEvent) -> void:
	_record.append(event)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_register_test.gd`
Expected: PASS, 5 assertions.

**Step 5: Commit**

```bash
git add scripts/telegraph/hardware/tape_register_controller.gd tests/telegraph/tape_register_test.gd
git commit -m "feat: tape register records scheduler marks/gaps verbatim"
```

---

### Task 2: Рендер ленты в текст (DOT/DASH/SPACE)

**Files:**
- Modify: `scripts/telegraph/hardware/tape_register_controller.gd`
- Test: `tests/telegraph/tape_register_test.gd` (расширить)

**Step 1: Write the failing tests** (добавить в `_run` перед cleanup)

```gdscript
	# 5. Tape rendering: MARK units -> dot/dash, GAP -> space per unit.
	var t2 := load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t2)
	await process_frame
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 1))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 3))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 3))
	if not _a(t2.get_tape_text() == "· —   ", "Mark/GAP render to dot/dash/spaces verbatim, got '%s'" % t2.get_tape_text()): return
	# Word gap: long GAP renders as more spaces.
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 2))
	if not _a(t2.get_tape_text() == "· —   · ", "A 2-unit MARK is still a dot; gaps scale"): return
	t2.queue_free()
```

и хелпер в конец файла:

```gdscript
func _ev(kind: MorseTimingEvent.Kind, units: int) -> MorseScheduledEvent:
	var e := MorseScheduledEvent.new()
	e.kind = kind
	e.duration_units = units
	return e
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_register_test.gd`
Expected: FAIL — `get_tape_text` not defined.

**Step 3: Implement**

Добавить в `TapeRegisterController`:

```gdscript
## Ink rendering. MARK <= 2 units is a dot, >= 3 units is a dash; every GAP
## unit is one blank column — exactly how paper strips looked, and exactly
## as readable with the Morse reference card.
func get_tape_text() -> String:
	var out := ""
	for event in _record:
		if event.kind == MorseTimingEvent.Kind.MARK:
			out += "·" if event.duration_units <= 2 else "—"
		else:
			out += " ".repeat(maxi(event.duration_units, 1))
	return out
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_register_test.gd`
Expected: PASS, 7 assertions.

**Step 5: Commit**

```bash
git add scripts/telegraph/hardware/tape_register_controller.gd tests/telegraph/tape_register_test.gd
git commit -m "feat: tape register renders marks to ink dot/dash text"
```

---

### Task 3: Подписка на реальный scheduler в сцене

**Files:**
- Modify: `scripts/telegraph/session/telegraph_session_controller.gd` (в `_ready`, рядом с `sounder.connect_scheduler(scheduler)`, ~строка 112)
- Test: `tests/telegraph/tape_register_test.gd` (расширить)

**Step 1: Write the failing test** (добавить перед cleanup; сценарная сцена та же, что в телеметрии — реальный путь сессии)

```gdscript
	# 6. Real path: a session playing a real schedule inks the tape verbatim;
	# the tape never sees text, only the timeline the sounder plays.
	var paper_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/transcript_paper.tscn")
	var session := load("res://scenes/telegraph/telegraph_session.tscn")
	# (если сцена сессии названа иначе — найти через grep "session_controller.tscn" scenes/)
	```

Перед написанием этого теста инженеру: найти актуальную сцену сессии —
`ls scenes/telegraph/` — и собрать её так, как это делает
`tests/telegraph/telegraph_session_controller_test.gd` (первые ~60 строк: как
инстанцируется сессия, как подаётся `TelegraphScenarioData`). Не изобретать
свою сборку. Тест:

- инстанцировать сессию с базовым сценарием (как в существующем тесте);
- получить `tape` (дочерний узел сессии или отдельный узел, см. Task 4);
- прогнать `scheduler.advance_time()` до `playback_completed`;
- assertions:
  - `tape.get_record().size() > 0` — лента записала реальную передачу;
  - сумма `duration_units` на ленте равна сумме units расписания (сравнить с `scheduler.get_active_schedule().events`);
  - в ленте есть и MARK, и GAP;
  - `tape.get_tape_text()` содержит `·` и не содержит букв латиницы.

**Step 2: Run test to verify it fails** (лента ещё не в сцене сессии)

**Step 3: Implement**

В `telegraph_session_controller.gd` `_ready()`, после подключения sounder:

```gdscript
	if tape_register != null and scheduler != null:
		tape_register.connect_scheduler(scheduler)
```

с `@export var tape_register: TapeRegisterController = null` и fallback-поиском
узла по имени `TapeRegister` (как `document_viewer` в `m1_office_controller.gd:82-83`).

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add scripts/telegraph/session/telegraph_session_controller.gd tests/telegraph/tape_register_test.gd
git commit -m "feat: session wires the tape register to the live scheduler"
```

---

### Task 4: Узел в сцене сессии + физический лоток

**Files:**
- Create: `scenes/telegraph/tape_register.tscn` (Node3D-узел со скриптом `TapeRegisterController` + простой меш: деревянная колодка, латунный барабан — можно из примитивов CSG/BoxMesh как временная арта; позиция у ключа, НЕ в зоне окна/двери)
- Modify: сцена сессии (добавить экземпляр `tape_register.tscn`)
- Modify: `scripts/telegraph/hardware/tape_register_controller.gd` — если нужны @export для позиций

**Step 1:** Собрать сцену в редакторе Godot (или текстом .tscn по образцу существующих пропов — `scenes/props/m1/`). Визуальный минимум: колодка + барабан + полоска бумаги (белый PlaneMesh) уходящая в короб.
**Step 2:** Добавить в сцену сессии рядом с ключом.
**Step 3:** Проверить production-boot: `godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn` — 0 ошибок.
**Step 4:** Run full suite: `bash tools/run_all_tests.sh` — 37 suites зелёные.
**Step 5: Commit**

```bash
git add scenes/telegraph/tape_register.tscn scenes/telegraph/
git commit -m "feat: tape register prop in the session scene"
```

---

### Task 5: Чтение ленты — Interactable + DocumentViewer

**Files:**
- Modify: `scripts/telegraph/hardware/tape_register_controller.gd` (interactable + `inspect_tape()`)
- Create/Modify: сцена ленты — добавить `Interactable` (по образцу `transcript_paper.tscn`: узел Interactable + CollisionShape3D, `prompt_text`)
- Modify: `scripts/office/m1_office_controller.gd` — открыть ленту в существующем `document_viewer` (см. `_on_document_opened` / как открывается transcript)
- Test: `tests/telegraph/tape_register_test.gd` (расширить)

**Step 1: Write the failing tests**

- `inspect_tape()` эмитит сигнал `tape_inspected(text: String)`;
- текст = `get_tape_text()` с обёрткой заголовка «STATION REGISTER — BLACK CREEK»;
- пустая лента: сигнал всё равно эмитится с пустой лентой (машина честна даже когда пуста);
- viewer: `open_document` вызывается с doc_id `"tape_register"`.

**Step 2: Run to verify fail.**

**Step 3: Implement**

```gdscript
signal tape_inspected(text: String)

const TAPE_DOC_ID := "tape_register"
const TAPE_TITLE := "STATION REGISTER"

## The operator lifts the strip to the lamp. No auto-comparison with the
## transcript sheet ever happens: checking is the player's own work (GDD §5).
func inspect_tape() -> void:
	tape_inspected.emit(get_tape_text())
```

В офис-контроллере — подключение к viewer по образцу transcript_inspected.

**Step 4: Run test + full suite.**

**Step 5: Commit**

```bash
git add scripts/telegraph/hardware/tape_register_controller.gd scripts/office/m1_office_controller.gd scenes/telegraph/tape_register.tscn tests/telegraph/tape_register_test.gd
git commit -m "feat: reading the tape through the document viewer"
```

---

### Task 6: Непрерывность — лента ползёт всю смену (feed через playback_time_advanced)

**Files:**
- Modify: `scripts/telegraph/hardware/tape_register_controller.gd`
- Test: `tests/telegraph/tape_register_test.gd` (расширить)

Дизайн §4: лента пишет непрерывно, пока линия открыта. Между передачами — пустая лента.
Реализация: длина пустых прогонов должна отличать «пауза внутри передачи» от «пауза между передачами».

**Step 1: Write the failing tests**

- После `connect_scheduler` и двух завершённых передач с паузой между ними (два `playback_completed`), `get_tape_text()` содержит пустой прогон между ними длиннее любого межсимвольного GAP (т.е. пауза между передачами визуально отличима: `>= N` пробелов, N подобрать из реального межсловного GAP сценария, обычно 6-7 units).
- playback_cancelled: лента сохраняет то, что успела записать (обрыв честен).

**Step 2: Run to verify fail.**

**Step 3: Implement**

Подписка на `playback_completed` / `playback_cancelled` в `connect_scheduler` (по паттерну sounder).
Метод `_on_playback_completed`: дописать в буфер GAP-событие «межпередачная пауза» (синтетический `MorseScheduledEvent` c kind=GAP и `duration_units`, вычисленным из паузы реального времени смены — на M1 достаточно константы-заглушки `BETWEEN_TRANSMISSIONS_GAP_UNITS := 12`, подобранной визуально; тайминг-модель не трогаем).
`get_tape_text()` уже рендерит GAP → пробелы, отдельный код не нужен.

**Step 4: Run test + full suite.**

**Step 5: Commit**

```bash
git add scripts/telegraph/hardware/tape_register_controller.gd tests/telegraph/tape_register_test.gd
git commit -m "feat: tape runs continuously across the shift with between-transmission gaps"
```

---

### Task 7: Телеметрия + финальная регрессия

**Files:**
- Modify: `tools/production_evidence_capture.gd` (добавить в paper-телеметрию: `tape_event_count`, снапшот `tape.get_record().size()` при каждом glyph_contact — для vision-less проверки «лента пишет всегда»)
- Test: полный прогон

**Step 1:** Добавить в `_paper_snapshot()`: `"tape_event_count": paper.get_writer_rig()... ` — нет, правильнее: `_telemetry_tape` (ссылка на ленту сессии), в снапшот `"tape_event_count": _telemetry_tape.get_record().size()`.
**Step 2:** Инвариант в `_check_paper_invariants()`: tape_event_count монотонно не убывает по всем сэмплам.
**Step 3:** `godot --path . --script tools/production_evidence_capture.gd` — 0 failures.
**Step 4:** `bash tools/run_all_tests.sh` — все suites зелёные, число не меньше базовой линии + новые.
**Step 5:** Production boot: `godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn` — 0 ошибок.
**Step 6:** Vision-чек скриншота у ключа (лента видна в кадре): `python3 tools/vision_check.py .dream-loop/production_evidence/p1_seated_receiving.png "..."` — вопрос про видимость ленты у ключа.
**Step 7: Commit**

```bash
git add tools/production_evidence_capture.gd
git commit -m "feat: tape register telemetry in production evidence"
```

---

## Definition of Done (соответствие дизайну §4)

- [ ] Лента пишет всё, что проиграл scheduler: трафик, служебное, шум (когда появится)
- [ ] Лента не имеет доступа к тексту передач (нет поля текста в классе — проверяется ревью)
- [ ] MARK→`·`/`—` по duration_units; GAP→пробелы по units
- [ ] Лента ползёт непрерывно: пауза между передачами визуально отличима
- [ ] Чтение через существующий DocumentViewer, без нового UI
- [ ] Никакого автокомпаратора с TranscriptPaper
- [ ] Focused suite зелёная; full regression не ниже базовой линии
- [ ] Production boot и production route зелёные; телеметрия пишет tape_event_count

## Запреты

- Не трогать MorseRuntimeScheduler, MorseTimingEvent, тайминг-модель — лента только подписчик
- Не добавлять ленте знание о true_message/elias_perception/written_transcript
- Не трогать TranscriptPaper и WriterRig (вчерашний timing-контракт неприкосновенен)
- Не строить UI сверх DocumentViewer
