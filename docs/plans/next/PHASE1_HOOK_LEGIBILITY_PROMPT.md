# Промпт агенту: Фаза 1 — хук читаем (DEAD WIRE)

> Скопируй всё ниже линии в новую сессию агента. Источник: `docs/reviews/2026-10-16_SENIOR_REVIEW.md` (§3 G1–G3, G5, G10, §4 U1/U4/U8, §7 P0.1).
> Все факты о коде ниже проверены вручную 2026-10-16 на HEAD `c35c612` + незакоммиченный T1.

---

Ты работаешь над **DEAD WIRE**: Godot 4.7.1, GDScript, first-person психологический хоррор. Телеграфист в 1894: слышишь одно, рука пишет другое.

Репозиторий: `C:\Users\YUSIF\Documents\dead-wire` (Windows, Git Bash и PowerShell).

Задача: **сделать ключевой бит (WATER на проводе → рука пишет WATCHER) воспринимаемым и проверяемым новичком без знания Morse.** Не добавлять последствий (это Фаза 2), не трогать арт.

## 0. Прочитать перед работой (обязательно, целиком)

1. `AGENTS.md`: инварианты архитектуры, команды. Числа suites в нём устарели: факт **90 suites / 2889 assertions**.
2. `docs/HANDOVER.md`, только §3–§8: команды, генераторы, **ловушки 1–20**, шаблон теста, коммиты. Чекпоинты сверху читать не нужно.
3. `docs/reviews/2026-10-16_SENIOR_REVIEW.md`, §3, §4, §7, §11 (кодекс).
4. Код, который будешь менять (ниже по задачам), — **целиком, не выборочно**.

## 1. Окружение и команды

```bash
GODOT="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
# полный прогон (~4 мин), базовая линия 90/2889, после T1 = 91 suites
GODOT_BIN="$GODOT" bash tools/run_all_tests.sh
# фокусный suite
"$GODOT" --headless --audio-driver Dummy --path . --script tests/<dir>/<name>_test.gd
# после ЛЮБОГО нового class_name (ловушка 1)
"$GODOT" --headless --path . --import
# boot smoke: exit 0; известный фон — 10 ObjectDB leaks / 2 resources, не новые
"$GODOT" --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn
# lint (только scripts/)
.venv-tools/Scripts/gdlint.exe scripts/
```

`godot` нет в PATH. Строки `ERROR: Failed to read the root certificate store` и shutdown-leak предупреждения — известный фон, не регресс.

## 2. Нерушимые правила

- **Инварианты из AGENTS.md:**
  - слои `true_message → elias_perception → written_transcript` не схлопываются;
  - лента регистра **не получает текст** никогда;
  - writer rig: один tick = максимум один глиф, чернила только на `glyph_contact`;
  - критическая морзе всегда читаема, без стингеров;
  - Listener не трогает предметы;
  - WorldState ≠ KnowledgeState.
- **TDD:** сначала тест, запустить и **увидеть RED по нужной причине**, потом реализация. Шаблон — HANDOVER §7.
- **Числа suites/assertions не падают.** Удалять или ослаблять тест ради зелёного запрещено.
- **Ловушка 5:** тесты и `tools/production_evidence_capture.gd` / `tools/first_night_playthrough.gd` пинят UI-строки. Поменял строку → `grep -rn` по `tests/ tools/ scripts/ scenes/` и обнови все места.
- **Строки и тайминги, видимые игроку, — в `.tres` или константах**, не размазаны литералами. Ключи фактов не собирать заново.
- **Не коммитить и не пушить** без явного разрешения владельца. Если разрешит: только явные пути (ловушка 17), identity из AGENTS.md, без co-author трейлера (HANDOVER §8).
- **Оконные capture-тулы** (`tools/production_evidence_capture.gd`, `tools/first_night_playthrough.gd -- --capture`) захватывают мышь на минуты. **Спроси владельца перед запуском.** Headless-прогон не равен визуальной приёмке.
- **Не запускать** `rewrite.py` (ловушка 13) и `tools/build_*` (ловушка 7).
- После каждой задачи: фокусные suites + lint. В конце — полный прогон и boot.

## 3. Уже сделано (T1) — проверь, не переделывай

**T1. Дедлайн подшивки в данных сценария.** Не закоммичено, лежит в рабочем дереве.

Изменения:
- `scripts/telegraph/session/telegraph_scenario_data.gd`: `@export var commit_deadline_seconds: float = -1.0` (отрицательное = фолбэк сессии) + валидация `is_finite`.
- `scripts/telegraph/session/telegraph_session_controller.gd`:
  - `get_commit_deadline_seconds()`: авторское значение сценария, иначе export 30.0;
  - все внутренние чтения (`advance_post_signal`, `get_deadline_warning_text`, `_is_commit_deadline_expired`) идут через этот getter.
- `data/scenarios/m1_scenario_3_core_hook.tres`: `commit_deadline_seconds = 55.0`.
- Новый `tests/telegraph/scenario_deadline_test.gd`: был RED, стал GREEN.
- Тесты и tool переведены на getter: `amendment_office_test`, `night_recovery_test`, `amendment_contract_test`, `copy_commit_desk_test`, `telegraph_session_controller_test` (секция 5 использует `scen3.duplicate()` с 0.5 s), `tools/first_night_playthrough.gd:134,136`.

Проверено: эти 7 suites зелёные. **Полный прогон после T1 ещё не делался — сделай первым шагом** (`git diff` для просмотра).

## 4. Задачи

### T2. Рука пишет в ритме услышанного; на хуке — спешит

**Проблема** (проверено):
- `transcript_reveal_cues` в `data/scenarios/m1_scenario_{1,2,3}*.tres` расставлены «на глаз»: равномерно в сценарии 2 (`0.076923…`), примерно в 1 и 3.
- Игрок не может выучить, что рука идёт за буквами, поэтому спешка руки на WATCHER не читается.
- Cue = момент, когда глиф *разрешён*; движение руки начинается тогда, чернила — на контакте. См. `transcript_paper.gd:381-411` `set_writing_progress`.

**Сделать:**
1. Новый `scripts/telegraph/morse/morse_letter_timing.gd`:
   - `class_name MorseLetterTiming extends RefCounted`;
   - `static func letter_end_fractions(message: String, alphabet: AmericanMorseAlphabetData) -> PackedFloat32Array` — по одному значению на каждый непробельный глиф: нормированное время конца его последнего MARK;
   - правила гэпов **те же, что в энкодере**: `AmericanMorseEncoder.INTER_LETTER_GAP_UNITS` (3) и `INTER_WORD_GAP_UNITS` (6), длина буквы = `alphabet.get_sequence(c).total_duration_units()`;
   - если сообщение не кодируется — пустой массив;
   - лента этот helper **не использует**;
   - после создания класса — `--import`.

   Эталон реализации:
   ```gdscript
   static func letter_end_fractions(message: String, alphabet: AmericanMorseAlphabetData) -> PackedFloat32Array:
       var ends := PackedFloat32Array()
       if alphabet == null or message.is_empty():
           return ends
       var units := 0
       var words := message.split(" ")
       for w_idx in range(words.size()):
           var word := words[w_idx]
           for c_idx in range(word.length()):
               var sequence := alphabet.get_sequence(word[c_idx])
               if sequence == null:
                   return PackedFloat32Array()
               units += sequence.total_duration_units()
               ends.append(float(units))
               if c_idx < word.length() - 1:
                   units += AmericanMorseEncoder.INTER_LETTER_GAP_UNITS
           if w_idx < words.size() - 1:
               units += AmericanMorseEncoder.INTER_WORD_GAP_UNITS
       if units <= 0:
           return PackedFloat32Array()
       for i in range(ends.size()):
           ends[i] = ends[i] / float(units)
       return ends
   ```
   Проверь, что сумма юнитов совпадает с `MorseScheduleCompiler` (`total_duration_seconds / seconds_per_unit`) для всех трёх сообщений. Это обязательная assertion.

2. **Тест сначала:** `tests/telegraph/transcript_cue_alignment_test.gd`.
   - Helper: «E» → `[1.0]`; последний элемент всегда 1.0; монотонность; число = числу глифов; сумма юнитов = schedule.
   - Честные сценарии 1 и 2 (`written == true`): каждый cue = letter end ± 0.005.
   - Хук:
     - cues[0..2] (W, A, T) = концы W, A, T в **WATER** ± 0.005;
     - cues[3..6] (C, H, E, R) строго > конца T, ≤ 1.0, равномерно, последний = 1.0;
     - средний интервал C–H–E–R меньше среднего интервала честного сценария 1 — «рука спешит».
   - Сгенерируй значения helper'ом (временный скрипт, не коммитить) и впиши в три `.tres`. Не руками.
3. **Физическая выполнимость:** убедись, что writer rig успевает писать хвост хука без потери чернил. Прогони существующие `writer_rig_*`, `writer_hand_test`, `transcript_paper_test`, `previous_copy_close_feed_test`, `telegraph_scenario_data_test`. Если какой-то тест пинит старые числа cues (`grep -rn "0.076923\|0.08, 0.20" tests tools`), обнови осознанно и отметь в отчёте.

### T3. Пружина регистра перестаёт прятать хук; заводу учат

**Проблема** (проверено, `scripts/telegraph/hardware/tape_register_controller.gd`):
- `spring_run_down_seconds = 240`, `SLACK_TENSION = 0.55`, `wind_prompt_below = 0.75`.
- Run-down идёт в `_process` (197-202) **с момента `connect_scheduler`**, то есть с загрузки сцены, включая PRE_SHIFT.
- Slack наступает примерно через 108 с, хук приходит примерно через 4 минуты, поэтому его марки остаются «под роликами».
- Про завод не говорят ни duty sheet (`duty_sheet.gd:26-60`), ни мысли (`data/night_guidance/m1_guidance.tres`).

**Сделать:**
1. Часовой механизм стартует **с первого `_on_playback_started`** (первый вызов на линии), а не с загрузки. Флаг вроде `_clockwork_running`, сбрасывается в `reset()`.
2. `spring_run_down_seconds` 240 → **360**: prompt примерно через 90 с после первого вызова, slack примерно через 162 с. Значение — export в сцене/скрипте, причину напиши в комментарии.
3. **Учить:**
   - в `duty_sheet.gd` HEADER, раздел READING THE WIRE, добавить строку про завод сбоку регистра, например «Wind the register at its side key when the strip slows.»;
   - в `m1_guidance.tres` — запись `{"id": &"wind", "text": "The register is slowing. I should wind it before the next call.", "delay": 1.0, "duration": 6.0, "once": true}`;
   - в `night_guidance_controller.gd` `_refresh_visible_context()` — контекст `&"wind"`, когда фаза `ShiftDirector.Phase.WAITING`, wind-интерактивный включён (`session.get_tape_register()._wind_interactable.enabled`, лучше добавить публичный `needs_winding() -> bool`) и не заблокировано. Приоритет выше `&"compare"`.
4. Не трогать: монотонность feed-курсора, «запись никогда не меняется», `wind()` выталкивает всё.

**Тесты сначала:**
- В `tests/telegraph/tape_feed_monotonicity_test.gd` или новом suite: пружина не садится до первого playback; садится после; `needs_winding()`.
- В тесте гайданса: контекст `wind` появляется в WAITING при `needs_winding()`.
- `tests/office/atmosphere_test.gd` и `tape_feed_monotonicity_test.gd` пинят «SPRING SLACK» — см. T5.

### T4. Шёпот Элиаса: слой восприятия становится видимым

**Проблема:** `elias_perception` нигде не потребляется, кроме `debug_inspector.gd:212`. Средний слой пайплайна мёртв, игрок не может узнать, что *услышал* Элиас.

**Решение владельца в этой фазе:** только **текстовый шёпот** — диегетичные субтитры внутреннего голоса.
- Голосовых ассетов нет. TTS не использовать (лицензии системных голосов, качество).
- Аудио-шёпот — отдельная будущая задача с актёром. Хук под аудио **не строить заранее**: никаких абстракций «на будущее».

**Сделать:**
1. **Сессия** (`telegraph_session_controller.gd`):
   - новый сигнал `perception_glyph(scenario_id: String, index: int, glyph: String)`;
   - в `start_transmission()` посчитать `MorseLetterTiming.letter_end_fractions(perception_text_без_пробелов…)` от `transmission_data.elias_perception`;
   - в `_on_playback_time_advanced` (только `State.RECEIVING`, только активный schedule) эмитить глифы, чьё время пересечено (`curr_time / total`);
   - в `_on_scheduler_completed` до t0 добить оставшиеся;
   - сброс в `load_scenario`/`reset_session`;
   - каждый глиф ровно один раз; при `playback_cancelled` не добивать.
2. **Новый UI-узел** `scripts/ui/murmur_caption.gd` (`class_name MurmurCaption extends CanvasLayer`), добавить в `m1_office.tscn` рядом с NightGuidance:
   - подписывается на `perception_glyph`;
   - показывает накопленные буквы строчными через разрядку: «w · a · t · e · r»; пробел слова = двойной интервал;
   - стиль тише, чем мысль: альфа примерно 0.55, тот же шрифт Noto, 20 px, тень;
   - после `transmission_finished` держит текст 4 с, затем fade 1.5 с;
   - очищается на новом сценарии;
   - пауза останавливает (process_mode по умолчанию);
   - **не читает** `true_message` и `written_transcript`, **не ссылается** на `M1OfficeController` по типу (ацикличность — кодекс §11 п.15); связь через `@export var session: TelegraphSessionController`.
3. **Работает для всех трёх сообщений.** Иначе шёпот сам выдаёт аномалию (кодекс §11 п.3).
4. **Fairness:** только текст, никакого звука; не перекрывает prompt и мысль (см. T5.1).

**Тесты сначала:** `tests/ui/murmur_caption_test.gd` и/или секция в `telegraph_session_controller_test`:
- на хуке эмитятся ровно W, A, T, E, R (5 глифов, а не 7), монотонно по времени, каждый не раньше конца своей буквы;
- на сценарии 1 эмитятся 16 глифов;
- cancel не добивает;
- `MurmurCaption` после хука показывает `w · a · t · e · r`, а лист в это время содержит WATCHER;
- **контрактная assertion:** source `murmur_caption.gd` не содержит `true_message`/`written_transcript` (прочитать файл как текст и проверить).

### T5. Нейтральные тексты, утечки иммершна, наложение текста

Все пункты проверены. Каждую строку перед заменой ищи `grep -rn` по `scripts scenes tests tools data`.

| # | Где | Сейчас | Сделать |
|---|---|---|---|
| 5.1 | `night_guidance_controller.gd:28-29` (мысль -124..-72) и `scenes/player/player.tscn:72-74` (prompt -112..-60) | **накладываются** | Мысль выше prompt'а без пересечения (например -176..-124); шёпот T4 выше мысли. Тест на непересечение rect'ов трёх лейблов |
| 5.2 | `scripts/telegraph/ui/dispatch_ledger.gd:23` | `Rule 44 (fictional Black Creek company order):` | `Rule 44 (Black Creek division order):`; обновить `tests/telegraph/rule44_content_test.gd` |
| 5.3 | `scenes/ui/pause_menu.tscn:208` | `… F3  telemetry` | Убрать F3 (работает только в debug); добавить `F1  recall thought` |
| 5.4 | `scenes/ui/main_menu.tscn:208` | `M1 office prototype` | Показывать только при `OS.is_debug_build()` или удалить; проверь `tests/ui/*menu*` |
| 5.5 | `tape_register_controller.gd` `get_tape_display_text`/`get_tape_text_for_viewer` | `[WIRE TAKE %d \| %s \| NON-INK BOUNDARY]`, статусы `INTERRUPTED/COMPLETE/ACTIVE`, `[SPRING SLACK — WIND REGISTER TO ADVANCE STRIP]` | Вынести формат в константы класса; язык эпохи, например `— STRIP %d · ENDED —` / `BROKEN OFF` / `RUNNING`, и `(strip held under the rollers — wind the register)`. Заголовок узнаётся константой, а не литералом: `m1_office_controller.gd:567` `begins_with("[WIRE TAKE")` перевести на константу/префикс. Тесты: `tape_evidence_test`, `tape_register_test`, `tape_layout_test`, `tape_feed_monotonicity_test`, `document_text_scale_test`, `atmosphere_test` (14 пинов) |
| 5.6 | `m1_office_controller.gd:560` footer ленты | `? unfinished mark; take labels are not timed ink` | `[E / Esc] Put Down Tape — ? marks a broken-off signal` |
| 5.7 | `m1_office_controller.gd:819` hint | `At the filing table: AMEND COPY to type a word, or FILE AS COPIED to seal the handwriting` | `File the copy at the table by the stove` |
| 5.8 | `duty_sheet.gd:46-51` | Раздел `DISPUTED COPY` + `ROUTING … not filing a disputed copy` (строка 41) | Раздел `FILING`: «Unscheduled copy is filed at the table: as copied, or amended in your own hand. Enter files; Esc keeps the draft.» Убрать слово *disputed* везде |
| 5.9 | `scripts/ui/amendment_editor.gd:75` | `Ready to file exactly: ` | `To be filed: ` |
| 5.10 | `m1_office_controller.gd:562-574` `_wrap_tape_text` | Режет строку ленты каждые 40 колонок, **разрывая букву** | Переносить только на гэпах ≥ 3 юнитов (≥ 3 пробелов); если группа длиннее ширины — резать как сейчас. **Лосслесс-контракт** (`tape_layout_test`: ни одна колонка пробелов не теряется) сохраняется; добавить assertion «буква не разрывается» |

**Вне scope** (запиши в отчёт, не делай):
- **Перенос по словам на листе копии.** `TRANSCRIPT GLYPH_COLUMNS` = 10, жёсткий перенос → «TRAIN 17 C / LEAR EAST» (`transcript_paper.gd:755`). Контракт раскладки дублируется в `transcript_paper.gd` (`_layout_prefix`, `get_glyph_contact:779`), `writer_rig.gd` и `document_viewer.gd` `_present_copy`. Затрагивает геометрию контакта пера и `writer_rig_space_test`. Нужен отдельный проход с единым `GlyphLayout`.
- **«Подшивать каждую копию»** (стол активен только для хука → UI сам выдаёт аномалию). Это решение владельца (WS2.4 ранее отклонён в FIRST_NIGHT_FINISH §3.1).

### T6. Фигура в окне: frustum-тест вместо конуса 45°

**Проблема** (проверено, `scripts/events/attention_observation_target.gd:171-185`):
- `_is_being_watched()` меряет угол между forward камеры и **origin** узла, порог `max_view_angle_degrees = 45`.
- Горизонтальный half-FOV при FOV 65 и 16:9 ≈ 48.6°, при FOV 85 или 21:9 ≈ 58°. Голова и шляпа выше origin.
- Итог: фигура появляется и исчезает **в кадре**. Это нарушает правило «существует только между наблюдениями» (GDD §10).

**Сделать:**
1. `_is_being_watched()` считает watched, если **глобальный AABB `VisualIndicator`** (объединение `get_aabb()` всех `GeometryInstance3D`-потомков, включая CSG: `Shoulders/LeftArm/RightArm` — CSGBox3D, остальное MeshInstance3D; см. `scenes/office/window_observation_event.tscn:48-90`), расширенный на `@export var watch_margin: float = 0.15`, **пересекает frustum камеры** (`camera.get_frustum()`).
   - Консервативно: AABB вне frustum, только если все 8 углов снаружи одной плоскости (`plane.is_point_over`).
   - `max_distance` сохранить.
   - Окклюзию для watched **не** учитывать (консервативно = честно).
   - Фолбэк без геометрии: сфера радиуса 0.6 м вокруг `global_position`.
2. `evaluate_observation()` (знание «saw_window_event») не трогать в этой фазе, но отметь в отчёте несогласованность конуса и frustum.

**Тест сначала:** `tests/events/window_watch_frustum_test.gd`.
- Camera3D (FOV 65), фигура с BoxMesh-ребёнком под 50° по горизонтали: **старый код = не watched (RED)**, новый = watched.
- То же при FOV 85.
- Фигура за спиной = не watched.
- Голова выше края кадра частично в кадре = watched.
- Проверь, что `tests/events/window_observation_test.gd` (24), `attention_*`, `door_attention_test` остаются зелёными. Внимание: headless viewport size берётся из project settings, учти aspect в тесте.

## 5. Финальная проверка и отчёт

1. Полный прогон: **≥ 91 suites + новые, assertions > 2889, 0 FAIL.**
2. `gdlint scripts/` чистый.
3. Boot smoke exit 0, без **новых** ошибок.
4. `--import` выполнен.
5. Grep-проверка: `grep -rn "fictional\|NON-INK\|DISPUTED\|telemetry\|Ready to file exactly\|WIRE TAKE" scripts scenes data tests tools` — остатков нет. Исключение: внутренние идентификаторы телеметрии `office_ambience.gd`/`sounder_controller.gd` — это не игровой текст, проверь контекст.
6. **Спросить владельца** про оконные прогоны: `production_evidence_capture.gd` (57 PASS) и `first_night_playthrough.gd -- --capture` (58 PASS). Если разрешит — запустить последовательно (не параллельно, см. HANDOVER: параллельный захват ломает mouse capture) и **посмотреть кадры глазами**: шёпот, мысль и prompt не пересекаются; лента читается.
7. Обновить в том же наборе изменений:
   - `AGENTS.md`: числа suites/assertions;
   - короткий чекпоинт сверху `docs/HANDOVER.md` (5–8 строк, нормальный текст с пробелами);
   - в `docs/reviews/2026-10-16_SENIOR_REVIEW.md` пометить G1–G3/G10/U1/U4/P0.1 как частично или полностью закрытые.
8. **Отчёт владельцу** (по-русски):
   - что сделано по T1–T6;
   - RED → GREEN для каждого нового теста (имя assertion, причина RED);
   - какие пины строк обновлены;
   - числа до и после;
   - что НЕ сделано и почему (вне scope: перенос по словам на листе, file-every-copy, аудио-шёпот, последствия Фазы 2);
   - что не проверено человеком.
   - **Не коммитить** без разрешения.
