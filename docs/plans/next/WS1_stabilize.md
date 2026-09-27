# WS1 — Стабилизация: репозиторий, раннер, P0/P1 кода, честность звука

**Цель:** чистая база, на которой можно строить ночи 2–6: никаких висящих тестов, никаких латентных P0,
честность звука «по построению», лента без склеек в момент хука.

**Архитектура:** точечные исправления в существующих системах, каждое закреплено тестом. Новых систем нет.

**Tech stack:** Godot 4.7 / GDScript; тесты — `extends SceneTree` (шаблон `HANDOVER.md` §7);
полный прогон `bash tools/run_all_tests.sh`; линт `.venv-tools/bin/gdlint scripts/`.

**Базовая линия:** 38 suites / 1915 assertions; production route 57 PASS; playthrough 58 PASS.

---

## Контракты существующего кода (прочитать перед задачами)

### MorseRuntimeScheduler (`scripts/telegraph/morse/morse_runtime_scheduler.gd`)
```gdscript
signal timing_event_started(event: MorseScheduledEvent)
signal timing_event_finished(event: MorseScheduledEvent)
signal playback_time_advanced(previous_seconds: float, current_seconds: float)
signal playback_completed(schedule: MorsePlaybackScheduleData)
signal playback_cancelled(schedule: MorsePlaybackScheduleData, elapsed_seconds: float)
func start(schedule: MorsePlaybackScheduleData) -> bool
func cancel() -> void
func is_playing() -> bool
func get_current_event() -> MorseScheduledEvent      # kind: MorseTimingEvent.Kind.MARK / GAP, duration_units
func advance_time(delta: float) -> void               # тесты: scheduler.auto_process = false
```

### ShiftDirector (`scripts/office/shift_director.gd`)
- `_play_on_wire(text) -> float` — кодирует, компилирует, **безусловно** `scheduler.cancel()`, стартует.
- `_wire_idle() -> bool`; `advance(delta)` — детерминированный шаг для тестов; фазы `Phase.*`
  (enum только дописывается в конец — `ANSWERING` последний).
- `_advance_to_slot(...)` вызывается из обработчика `session_completed` (реэнтрантно).

### TelegraphSessionController (`scripts/telegraph/session/telegraph_session_controller.gd`)
- подписан на `playback_completed` и `playback_time_advanced` (строки ~107–111), **не** на `playback_cancelled`.
- `State.{READY, RECEIVING, COPYING, VERIFYING, AWAITING_ROUTE, AWAITING_COMMIT, ...}`, `get_state()`,
  `start_transmission()`, `get_current_scenario()`.

### TapeRegisterController (`scripts/telegraph/hardware/tape_register_controller.gd`)
- `_on_timing_event_started(event)` → `_record.append(event)`;
  `_on_playback_completed` добавляет синтетический GAP `BETWEEN_TRANSMISSIONS_GAP_UNITS` (12);
  `_on_playback_cancelled` — **ничего** (частичные чернила остаются, разделителя нет).
- `get_record()`, `get_tape_text()` (MARK ≤2 юнита → `·`, ≥3 → `—`, каждый юнит GAP → пробел).

### OfficeAmbience (`scripts/audio/office_ambience.gd`)
- `set_hush_db(value)` двигает room tone / wind / stove; **`clock_player` не трогает**.

### DoorAttentionSource (`scripts/events/door_attention_source.gd`)
- `scheduler` (ставит контроллер), `_wire_marking()` — проверка только в момент старта шага.

### MoonWeather (`scripts/office/moon_weather.gd`)
- `_rng.seed = 18941014` (фиксирован), `_cloud_left`, `_until_cloud`, `is_dimmed_now()`, `advance(delta)`;
  фигура приглушает свет **сама по себе**.

---

### Task 1.1 — Раннер: таймаут и честная детекция провалов

**Files:** Modify `tools/run_all_tests.sh`

**Проблема:** рантайм-ошибка внутри `_run` останавливает корутину до `quit()` → headless Godot висит вечно;
`grep '^FAIL:'` не матчит `  FAIL:` (отступ).

**Шаги:**
1. Воспроизвести: временный suite с `var x = null; x.foo()` в `_run` → раннер висит (не коммитить suite).
2. На macOS нет `timeout`. Обёртка без зависимостей:
   ```bash
   run_with_timeout() {  # $1 = seconds, rest = command
       local secs=$1; shift
       "$@" & local pid=$!
       ( sleep "$secs" && kill -9 "$pid" 2>/dev/null ) & local watcher=$!
       wait "$pid"; local rc=$?
       kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
       return $rc
   }
   ```
   Использовать для каждого suite с лимитом 180 с; убитый по таймауту suite = FAIL с пометкой `TIMEOUT`.
3. `grep -q 'FAIL:'` вместо `'^FAIL:'`.
4. Добавить в поиск Godot `/Applications/Godot.app/Contents/MacOS/Godot` и `/opt/homebrew/bin/godot`.

**Acceptance:** временный висящий suite завершается как `TIMEOUT` за ≤180 с; suite с `  FAIL:` и exit 0
считается провалом; обычный прогон — 38/1915.

**Commit:** `chore: test runner times out hung suites and catches indented FAIL lines`

---

### Task 1.2 — Сессия переживает отмену; провод не рвёт телеграмму (#4)

**Files:** Modify `scripts/office/shift_director.gd`, `scripts/telegraph/session/telegraph_session_controller.gd`;
Test: `tests/office/shift_director_test.gd` (новый раздел)

**Step 1 — RED:**
```gdscript
# --- the wire never cuts a message that is being received --------------------
# (#4) A nag, warning or line noise must not cancel a live telegram.
director.advance(director.wait_seconds_before_call[0] + 0.1)
key.press()
director.advance(director.answer_beat_seconds + 0.05)
if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Receiving the first order"): return
var played := director._play_on_wire(director.call_sign)
if not assert_condition(played == 0.0, "The director refuses to key over a live telegram"): return
if not assert_condition(session.scheduler.is_playing(), "The telegram is still on the wire"): return
```
**Step 2:** запустить `tests/office/shift_director_test.gd` → FAIL («refuses to key»).

**Step 3 — GREEN:**
- в `_play_on_wire`: `if session.get_state() in [State.RECEIVING, State.COPYING] and session.scheduler.is_playing(): return 0.0`
  (COPYING — если расписание ещё идёт);
- в сессии подписаться на `playback_cancelled`: если отменено расписание **текущей** телеграммы в RECEIVING →
  перейти в согласованное состояние (сейчас — вернуть `READY` и записать факт `telegram_cut_<id>` в WorldState).
  Это задел под BK-перебивки WS5; поведение закрепить отдельной проверкой.

**Acceptance:** новые проверки зелёные; полная регрессия; маршрут 57 PASS.

**Commit:** `fix: the director never keys over a live telegram; session handles a cancelled schedule`

---

### Task 1.3 — Разделитель на ленте при отмене и после каждой передачи (#2, #3)

**Files:** Modify `scripts/telegraph/hardware/tape_register_controller.gd`; Test: `tests/telegraph/tape_register_test.gd`

**Контракт ленты не меняется:** она пишет только MARK/GAP и не знает текста. Разделитель — это GAP, то есть
**правда**: линия действительно замолчала.

**Step 1 — RED:** в `tape_register_test.gd`:
```gdscript
# (#2) A call cut short by the operator's answer leaves a visible gap before
# the message: the partial CR never runs into the first letter.
register.reset()
scheduler.start(_compile("CR"))
scheduler.advance_time(0.25)          # mid-call
scheduler.cancel()
scheduler.start(_compile("W"))
scheduler.advance_time(5.0)
var text := register.get_tape_text()
var boundary := text.find("  ")     # GAP columns between the cut call and W
if not assert_condition(_longest_blank_run(text) >= TapeRegisterController.CANCEL_GAP_UNITS, "A cut call is separated from the next message on the tape"): return
```
(`_compile` и `_longest_blank_run` — хелперы теста; `_longest_blank_run` считает самую длинную серию пробелов.)

**Step 3 — GREEN:** в `_on_playback_cancelled` добавить синтетический GAP `CANCEL_GAP_UNITS := 6`.
Для #3: оставить warning/nag на саундере и ленте (лента пишет всё), но гарантировать ≥12-юнитный GAP до
служебного сигнала — директор ждёт `_wire_idle()` + `WARNING_CLEARANCE_SECONDS` после конца телеграммы.

**Acceptance:** сегмент WATER на ленте окружён паузами ≥12 юнитов в сценарии 3 (проверка в
`tests/integration/m1_office_integration_test.gd`: найти последовательность MARK/GAP WATER в `get_record()`
по индексу событий телеграммы, проверить соседние GAP).

**Commit:** `fix: the tape separates a cut call and service signals from the message`

---

### Task 1.4 — Null-guards и отложенный переход слота (#21, #22)

**Files:** `scripts/office/m1_office_controller.gd` (`_refresh_guidance`, строки ~728–736),
`scripts/office/shift_director.gd` (`_on_session_completed` → `_advance_to_slot.call_deferred(...)`)

**Test:** в `tests/integration/m1_office_integration_test.gd` — после завершения сценария 1 проверить, что
`office.get_current_scenario_index()` меняется только после `await process_frame` (фиксирует новый контракт);
в тесте без `DawnEvidence` (удалить узел перед `_ready`) `_process` не падает.

**Commit:** `fix: guidance survives missing nodes; slot advance deferred out of session_completed`

---

### Task 1.5 — Флаг критической копии вместо литерала ID (#8)

**Files:** `scripts/telegraph/session/telegraph_scenario_data.gd` (+ `@export var critical_copy: bool = false`),
`data/scenarios/m1_scenario_3_core_hook.tres` (`critical_copy = true`), `m1_scenario_2_attention.tres`
(распоряжение маршрута — тоже `true`), `scripts/office/unease_director.gd`, `scripts/office/m1_office_controller.gd`.

**RED:** `tests/office/atmosphere_test.gd` — во время RECEIVING сценария 2 `unease._creak_at_anchor(...)`
не проигрывает скрип (`creaks_played` не растёт).
**GREEN:** `_critical_writing_window()` проверяет `session.get_current_scenario().critical_copy`;
все три литерала `"core_hook_water_watcher"` удалить (оставить ID только в `.tres`).

**Commit:** `fix: critical copy is a scenario flag; creaks and hushes respect every critical order`

---

### Task 1.6 — Часы глохнут под морзе; шаги только в достаточных паузах (#6, #7)

**Files:** `scripts/audio/office_ambience.gd`, `scripts/events/door_attention_source.gd`

**RED (часы):** `tests/audio/office_ambience_test.gd` — `ambience.set_hush_db(-20)` → `clock_player.volume_db`
ниже `clock_volume_db - 10`. И: во время RECEIVING (передать `session`) тик приглушён на ≥12 дБ.
**GREEN:** включить `clock_player` в `set_hush_db`; метод `duck_for_copy(on: bool)` вызывается директором/
контроллером на RECEIVING/COPYING. Фаза маятника не трогается (только громкость).

**RED (шаги):** `tests/events/door_attention_test.gd` — живой scheduler (`auto_process=false`) с «E I» (точки и
короткие паузы): шаг не стартует, пока текущий GAP < 3 юнитов или остаток GAP < длины сэмпла.
**GREEN:** `_wire_marking()` → `_gap_can_hold_step()`:
```gdscript
var ev := scheduler.get_current_event()
if ev == null or not scheduler.is_playing(): return true
if ev.kind == MorseTimingEvent.Kind.MARK: return false
var left := ev.end_seconds - scheduler.get_elapsed_seconds()
return ev.duration_units >= 3 and left >= footstep_sound.get_length()
```
**Acceptance:** интеграционная проверка «No footstep landed on a Morse mark» усилена до «no footstep sample
overlaps any MARK» (проверять интервал [start, start+length]).

**Commit:** `fix: the clock ducks under copy; footsteps only fill gaps long enough to hold them`

---

### Task 1.7 — Луна: фигура начинает облако; seed на смену (#9) и контракт «посмотрел — пусто» (#10)

**Files:** `scripts/office/moon_weather.gd`, `scripts/events/attention_observation_target.gd`, тест — `atmosphere_test.gd`

**Решение по #10 (зафиксировать в GDD §10 одной строкой):** фигура исчезает, **как только** на неё смотрят
(`is_observed` → `VisualIndicator.visible = false` немедленно). Удержание 6 с работает только пока не смотрят.

**RED:** (a) при появлении фигуры `moon._cloud_left > 0` (облако стартовало); (b) два экземпляра офиса с разными
seed смены дают разные расписания облаков; (c) фигура под взглядом → невидима в тот же кадр.
**GREEN:** MoonWeather подписывается на сигнал появления у `window_event` и ставит
`_cloud_left = max(_cloud_left, rng.randf_range(hold_min, hold_max))`; seed = `hash(Time.get_unix_time_from_system())`
при старте смены (в тестах задавать явно); в `attention_observation_target.gd` при `is_observed` прятать немедленно.

**Commit:** `fix: every moon dim is a cloud by construction; the figure is gone the moment it is watched`

---

### Task 1.8 — Гигиена репозитория (#23–26)

Каждый пункт — **только с подтверждением владельца** (удаление файлов, изменение `.gitignore`).
1. Убрать `*.import` из `.gitignore`, закоммитить все `.import` (настройки импорта и UID — часть проекта).
2. `assets/third_party/.gdignore` (пустой файл) — убирает 15 дублей UID; проверить, что офис грузится
   (`godot --headless --path . --quit-after 120 res://scenes/office/m1_office.tscn`, 0 ошибок).
3. Решение по билдам: либо `builds/` в `.gitignore` + `git rm --cached builds/dead-wire-m1-macos.zip`
   (релизы — через GitHub Releases), либо оставить zip, но **никогда** не коммитить `builds/*.app`.
4. `.DS_Store` в `.gitignore`, `git rm --cached` существующие.
5. Удалить опасный `rewrite.py` (переписывает стены офиса устаревшими значениями), `test_run_latest.log`,
   сиротские `tools/*.gd.uid` без скриптов, корневые `capture_*.gd`, если не используются (grep перед удалением).

**Acceptance:** `git status` чистый после свежего клона + `godot --headless --path . --import`; регрессия 38/1915.

**Commit:** `chore: track import settings; ignore third-party sources, builds and Finder files`

---

## Сводные критерии готовности WS1
- [ ] 1.1 раннер  - [ ] 1.2 отмена/провод  - [ ] 1.3 лента-разделители  - [ ] 1.4 guards/defer
- [ ] 1.5 critical_copy  - [ ] 1.6 часы/шаги  - [ ] 1.7 луна/фигура  - [ ] 1.8 гигиена
- регрессия не меньше базовой линии + новые проверки; маршрут 57 PASS; прохождение 58 PASS.
