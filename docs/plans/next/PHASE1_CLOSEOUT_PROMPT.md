# Промпт агенту: Фаза 1 — закрыть хвосты и закоммитить

> Продолжение `PHASE1_HOOK_LEGIBILITY_PROMPT.md`. Состояние проверено ревьюером 2026-10-16:
> - 97 suites / 2975 assertions / 0 FAIL;
> - `gdlint scripts/` чистый;
> - boot exit 0 с прежним фоном (10 ObjectDB / 2 resources, новых нет).
>
> Всё ниже — проверенные факты.

---

Ты продолжаешь работу над **DEAD WIRE** (Godot 4.7.1, GDScript) в `C:\Users\YUSIF\Documents\dead-wire`.

Фаза 1 «хук читаем» (T1–T6) реализована, прошла ревью и **не закоммичена**. Твоя задача:
- закрыть пять хвостов (A–E);
- проверить;
- сделать **два коммита** от имени владельца (код, затем доки);
- **не пушить**.

## 0. Перед началом

1. Прочитай `AGENTS.md`, `docs/HANDOVER.md` §5–§8 (генераторы, ловушки, шаблон теста, **конвенции коммитов**) и `docs/plans/next/PHASE1_HOOK_LEGIBILITY_PROMPT.md` (что делалось).
2. `git status --short` — сверь с ожидаемым списком (раздел 4). Если видишь файлы вне списка — **остановись и спроси владельца**, ничего не удаляй и не откатывай.
3. Базовая линия: `GODOT_BIN="$GODOT" bash tools/run_all_tests.sh` → должно быть **97 / 2975 / 0 FAIL**. Если нет — остановись и доложи.

```bash
GODOT="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --audio-driver Dummy --path . --script tests/<dir>/<name>_test.gd   # фокусный
"$GODOT" --headless --path . --import                                                  # после нового class_name
"$GODOT" --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn  # boot
.venv-tools/Scripts/gdlint.exe scripts/
```

**Правила:**
- TDD: тест → увидеть RED по нужной причине → реализация → GREEN.
- Числа suites/assertions не падают.
- Не ослабляй и не удаляй тесты.
- Не запускай `rewrite.py` и `tools/build_*`.

## 1. Хвосты

### A. Интеграционный тест: шёпот реально подключён в сцене офиса

**Факт:**
- `MurmurCaption` добавлен в `scenes/office/m1_office.tscn` (узел `MurmurCaption`, `session = NodePath("../TelegraphSessionController")`, `layer = 4`).
- `tests/ui/murmur_caption_test.gd` проверяет его только на голой сессии без сцены. Если путь в сцене сломается, шёпот молча исчезнет, и ни один тест не упадёт.

**Сделать:** новый `tests/integration/murmur_office_wiring_test.gd`. Образец загрузки офиса возьми из `tests/integration/m1_office_integration_test.gd` или `previous_copy_close_feed_test.gd` — те же автолоады и тот же порядок.

Assertions:
1. В инстансе `m1_office.tscn` есть узел `MurmurCaption` типа `MurmurCaption`.
2. `murmur.session == office.session_controller` (тот же объект).
3. `office.session_controller.perception_glyph.is_connected(murmur._on_perception_glyph)`.
4. Слой: `murmur.layer` < `DocumentViewer.layer` (сейчас 4 < 10), так что открытый документ перекрывает шёпот.

**Как получить RED:** код уже существует, поэтому тест будет зелёным сразу. Докажи, что он ловит поломку:
1. Временно испорти путь **на диске**: в `scenes/office/m1_office.tscn` замени `session = NodePath("../TelegraphSessionController")` у узла `MurmurCaption` на `NodePath("../NoSuchNode")`.
2. Запусти тест — он должен упасть на assertion 2 или 3. Сохрани вывод.
3. Верни путь, запусти тест — GREEN.
4. Проверь `git diff scenes/office/m1_office.tscn`: в diff должна остаться только исходная вставка узла MurmurCaption, без следов `NoSuchNode`.

В отчёте укажи, как именно получен RED.

### B. Согласовать «видел ли игрок фигуру» с frustum-тестом

**Факт:** `scripts/events/attention_observation_target.gd`:
- `_is_being_watched()` (видимость: появление и исчезновение) теперь — AABB силуэта против frustum камеры;
- `check_camera(camera, ui_blocked)` → `evaluate_observation(cam_pos, cam_fwd, is_occluded)` всё ещё считает «увидел» по **конусу 45° от origin**;
- значит, силуэт может быть в кадре (и удерживаться от исчезновения), а `saw_window_event` не запишется — или наоборот.

Вызовы:
- production: `scripts/office/m1_office_controller.gd:830` `window_observation.check_camera(cam, is_world_view_blocked())`;
- тесты: `tests/events/window_observation_test.gd:44,50,55` (`evaluate_observation` напрямую), `:110,114` (`check_camera`), `tests/office/atmosphere_test.gd:150`.

**Сделать:**
1. Вынеси общий предикат `_silhouette_in_frustum(camera: Camera3D) -> bool` из `_is_being_watched()`: AABB + `watch_margin` + все плоскости + `max_distance`. `_is_being_watched()` вызывает его.
2. `check_camera()` засчитывает наблюдение, только если одновременно:
   - событие активно и ещё не наблюдено;
   - индикатор виден;
   - `not ui_blocked`;
   - `_silhouette_in_frustum(camera)`;
   - луч до `global_position` не перекрыт (существующий raycast по `collision_mask = 1` сохранить).
   При успехе — та же запись знания и `event_observed`, что сейчас. Вынеси запись в `_mark_observed()`, чтобы не дублировать.
3. `evaluate_observation(pos, fwd, occluded)` оставить **как есть** — это низкоуровневый API без камеры, его пинят тесты. В doc-комментарии написать, что production идёт через `check_camera`.
4. **Тест сначала:** добавь в `tests/events/window_watch_frustum_test.gd` (или новый suite):
   - камера FOV 65, силуэт под 50° по горизонтали, без стен → `check_camera` = **true** (сейчас false — RED);
   - силуэт за спиной → false;
   - `ui_blocked = true` → false;
   - стена (StaticBody3D на layer 1) между камерой и фигурой → false.
5. Прогони `window_observation_test`, `atmosphere_test`, `attention_timeline_test`, `door_attention_test`, `m1_office_integration_test` — должны остаться зелёными.

### C. Документация (это просил владелец)

1. **`AGENTS.md`**, блок Commands, первая строка комментария. Сейчас:
   `# Full regression (38 suites / 1915 assertions at 2026-09-27; MUST be green, counts never drop)`
   Заменить на фактические числа **после A+B** и сегодняшнюю дату. Ниже добавить строку для Windows:
   `# Windows: GODOT_BIN="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" bash tools/run_all_tests.sh`.
   Строку линтера дополнить Windows-путём `.venv-tools/Scripts/gdlint.exe scripts/`.
   Больше в AGENTS.md ничего не менять. Если запись в AGENTS.md заблокирована защитой файла — **попроси у владельца разрешение явно** и жди ответа; не обходи защиту.
2. **`docs/HANDOVER.md`** — новый чекпоинт **самым первым** после строки «Docs are written in Russian…». 6–10 строк, нормальный русский текст с пробелами (не сжатый, как старые чекпоинты):
   - заголовок `## Checkpoint 2026-10-16 — Фаза 1: хук читаем`;
   - что сделано (T1–T6 + A/B одной строкой каждое);
   - числа suites/assertions;
   - что не проверено: оконные прогоны, человеческий плейтест, аудио-шёпот отсутствует (только текст);
   - ссылки на `docs/reviews/2026-10-16_SENIOR_REVIEW.md` и оба PHASE1-промпта.
3. **`docs/reviews/2026-10-16_SENIOR_REVIEW.md`** — в конец добавить раздел `## Статус после Фазы 1 (2026-10-16)` с таблицей «пункт → статус → чем закрыт». Остальной текст ревью не переписывать.

   | Пункт | Статус | Чем закрыт |
   |---|---|---|
   | G1 | частично | шёпот (текст) + cues по концам букв; сегментации ленты нет; аудио-шёпота нет |
   | G2 | частично | дедлайн хука 55 с в `.tres`; RPT нет |
   | G3 | закрыт | часовой механизм с первого вызова, 360 с, обучение заводу |
   | G10 | закрыт | fictional / F3 telemetry / WIRE TAKE / NON-INK / prototype |
   | U1 | закрыт | каналы текста разнесены, тест непересечения |
   | U4 | частично | перенос ленты по гэпам ≥ 3; полосы-ленты и вида «лента под карточкой» нет |
   | P0.1 (frustum) | закрыт | видимость и наблюдение — frustum (после B) |
   | G5 | частично | тексты нейтральны; стол подшивки всё ещё только для хука — решение владельца |

### D. Побочные файлы — включить в коммит осознанно

- `default_bus_layout.tres`: Godot при `--import` добавил `uid="uid://c4tigndd50lqq"` и убрал `load_steps`. Это нормальная нормализация формата 4.x. **Включить** в коммит кода; Godot всё равно вернёт её при следующем импорте.
- `tools/targeted_fix_frames_capture.gd.uid`: сопутствующий uid для уже отслеживаемого `tools/targeted_fix_frames_capture.gd`. По конвенции проекта `.uid` трекаются — **включить**.
- Все новые `*.gd.uid` рядом с новыми скриптами и тестами — **включить**.
- Предупреждение `CRLF will be replaced by LF` на `scenes/ui/pause_menu.tscn` — не трогать, это git.

### E. Финальная проверка (перед коммитом)

1. Полный прогон: suites ≥ 98, assertions > 2975, **0 FAIL**. Запиши точные числа.
2. `gdlint scripts/` чистый.
3. Boot smoke exit 0; ObjectDB/resources не больше 10/2.
4. `git diff --check` без ошибок пробелов.
5. Grep: `grep -rn "fictional\|NON-INK\|DISPUTED\|Ready to file exactly\|WIRE TAKE\|F3  telemetry" scripts scenes data tests tools`. Остатков быть не должно; внутренние `telemetry`-идентификаторы в `office_ambience.gd`/`sounder_controller.gd` — не игровой текст, их не трогать.
6. **Оконные прогоны** (`tools/production_evidence_capture.gd`, `tools/first_night_playthrough.gd -- --capture`) захватывают мышь на минуты. **Спроси владельца**. Если разрешит — запускай строго последовательно и посмотри кадры: шёпот над мыслью, мысль над prompt, без пересечений; лента читается. Если не разрешит или не ответит — **не блокируй коммит**, а честно впиши в тело коммита «windowed routes not rerun».

## 2. Коммиты

Конвенция владельца (`docs/HANDOVER.md` §8): identity владельца, **без co-author трейлера**, только явные пути (ловушка 17: `git add -A` / `git commit -a` запрещены), тема `feat:/fix:/docs:` + фраза голосом игры. В теле — числа тестов последней строкой. **Не пушить** — пушит владелец.

Перед каждым коммитом: `git add <явные пути>` → `git diff --cached --stat` → сверить список → коммит.

### Коммит 1 — код, данные, тесты

Пути (сверь с `git status`; добавь новые файлы из A/B):

```
data/night_guidance/m1_guidance.tres
data/scenarios/m1_scenario_1_baseline.tres
data/scenarios/m1_scenario_2_attention.tres
data/scenarios/m1_scenario_3_core_hook.tres
default_bus_layout.tres
scenes/office/m1_office.tscn
scenes/ui/pause_menu.tscn
scripts/events/attention_observation_target.gd
scripts/office/m1_office_controller.gd
scripts/office/night_guidance_controller.gd
scripts/telegraph/hardware/tape_register_controller.gd
scripts/telegraph/morse/morse_letter_timing.gd
scripts/telegraph/morse/morse_letter_timing.gd.uid
scripts/telegraph/session/telegraph_scenario_data.gd
scripts/telegraph/session/telegraph_session_controller.gd
scripts/telegraph/ui/dispatch_ledger.gd
scripts/telegraph/ui/duty_sheet.gd
scripts/ui/amendment_editor.gd
scripts/ui/main_menu.gd
scripts/ui/murmur_caption.gd
scripts/ui/murmur_caption.gd.uid
tests/events/window_watch_frustum_test.gd
tests/events/window_watch_frustum_test.gd.uid
tests/guidance/wind_guidance_test.gd
tests/guidance/wind_guidance_test.gd.uid
tests/integration/amendment_office_test.gd
tests/integration/night_recovery_test.gd
tests/integration/murmur_office_wiring_test.gd        (+ .uid, из A)
tests/office/atmosphere_test.gd
tests/office/shift_director_test.gd
tests/telegraph/amendment_contract_test.gd
tests/telegraph/copy_commit_desk_test.gd
tests/telegraph/rule44_content_test.gd
tests/telegraph/scenario_deadline_test.gd
tests/telegraph/scenario_deadline_test.gd.uid
tests/telegraph/tape_clockwork_test.gd
tests/telegraph/tape_clockwork_test.gd.uid
tests/telegraph/tape_evidence_test.gd
tests/telegraph/tape_feed_monotonicity_test.gd
tests/telegraph/tape_register_test.gd
tests/telegraph/telegraph_session_controller_test.gd
tests/telegraph/transcript_cue_alignment_test.gd
tests/telegraph/transcript_cue_alignment_test.gd.uid
tests/ui/document_text_scale_test.gd
tests/ui/murmur_caption_test.gd
tests/ui/murmur_caption_test.gd.uid
tests/ui/tape_layout_test.gd
tests/ui/text_channel_layout_test.gd
tests/ui/text_channel_layout_test.gd.uid
tools/first_night_playthrough.gd
tools/targeted_fix_frames_capture.gd.uid
```

Команда (подставь числа и итоговый список путей):

```bash
git -c user.name="Yusif Israfilov(Kaiser)" \
    -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" \
    commit -F /tmp/phase1_msg.txt -- <все пути выше>
```

Текст `/tmp/phase1_msg.txt`:

```
feat: Elias murmurs what he hears; the hand keeps its rhythm, and rushes on WATCHER

- hook deadline authored in scenario data (55 s); session falls back to 30 s
- transcript cues land on real letter ends (MorseLetterTiming); the hook's
  C-H-E-R crowd the last two letters of WATER
- perception layer made visible: MurmurCaption spells elias_perception
  letter by letter; it never reads the true message or the written copy
- register clockwork starts with the first call, runs 360 s; winding is
  taught in the duty sheet and a thought
- player-facing text purged of production language; text channels no
  longer overlap; tape wraps on letter gaps only
- window figure: watched and seen both use the silhouette's frustum test

N suites / M assertions green; lint clean; boot exit 0 (10/2 known leaks).
<windowed routes: rerun X PASS / not rerun>
```

### Коммит 2 — документация

```
AGENTS.md
docs/HANDOVER.md
docs/reviews/2026-10-16_SENIOR_REVIEW.md
docs/plans/next/PHASE1_HOOK_LEGIBILITY_PROMPT.md
docs/plans/next/PHASE1_CLOSEOUT_PROMPT.md
```

Тема: `docs: senior review, phase 1 prompts and checkpoint; counts brought to date`. Последняя строка тела — те же числа.

После коммитов: `git log --oneline -3` и `git status --short`. Рабочее дерево должно быть чистым, кроме того, что было до тебя. **Не пушить.**

## 3. Отчёт владельцу (по-русски, коротко)

- A и B: RED → GREEN, имя assertion и причина RED; как именно получен RED в A.
- C и D: что изменено в каждом доке.
- Числа: до (97/2975) → после.
- Хэши двух коммитов и `git log --oneline -3`.
- Оконные прогоны: запускались или нет; если да — что видно на кадрах.
- Что осталось открытым:
  - аудио-шёпот;
  - перенос по словам на листе (`GLYPH_COLUMNS = 10`);
  - стол подшивки только для хука (G5);
  - RPT;
  - последствия (Фаза 2);
  - человеческий плейтест.

## 4. Ожидаемый `git status` на старте

Изменённые (M): 3 сценария + `m1_guidance.tres`, `default_bus_layout.tres`, `m1_office.tscn`, `pause_menu.tscn`, 10 скриптов из списка коммита 1, 13 тестов, `tools/first_night_playthrough.gd`.

Новые (??):
- `docs/reviews/`, `docs/plans/next/PHASE1_*_PROMPT.md`;
- `morse_letter_timing.gd`, `murmur_caption.gd` (+ .uid);
- 7 новых тестов (+ .uid);
- `tools/targeted_fix_frames_capture.gd.uid`.

Всё, что сверх этого, — стоп и вопрос владельцу.
