# DEAD WIRE — HANDOVER (read this first)

Обновлён 2026-10-23 (M1_FINISH_PLAN, фаза 1): одна страница текущего состояния. Полная история —
`docs/plans/HANDOVER_HISTORY.md` (прежний HANDOVER без правок) и git log.
Документы на русском, код и комментарии к коду на английском.

## 1. Состояние

- Движок: Godot 4.7.1 stable (baseline), `C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.
  Один движок для тестов/захватов/беты — 4.7.1 (ROADMAP 0.8). Flake `shift_director_test` (exit 139 в teardown) принят: повторный прогон, логи в `test_logs/`. Новые evidence-артефакты в git не кладутся, история не переписывается (0.9).
- Базовая линия: **141 suites / 3979 assertions / 0 FAIL**, gdlint чистый, boot exit 0. Числа не должны падать.
- Передача работы 31.10.2026 (состояние, ловушки, остаток M1): `docs/plans/next/HANDOFF_2026-10-31.md`.
- Известный фон (не регресс): на shutdown — ObjectDB leaks / resources in use (boot ≈10/2); в оконных
  прогонах — 7 texture RID. **`shift_director_test` примерно в 1/3 полных прогонов падает на teardown
  движка (exit 139) ПОСЛЕ всех 132 PASS** — godot#117991, открыт, не «чинится повтором»:
  процедура и анализ в `docs/research/roadmap_loop_2026-10-16/shift_director_flake_analysis.md`.
- Триаж 2026-10-23: финальный полный прогон — exit 0, 116/3442, без SCRIPT ERROR и без
  повторов внутри этого прохода. Предыдущие прогоны дали exit 139 после всех PASS у
  `misroute_wire_test` (18) и `wind_guidance_test` (9); это не исправлено, логи сохранены в
  `.dream-loop/phase0/` и `test_logs/phase0_teardown/`. На shutdown также встречается
  PagedAllocator (`Pages in use exist at exit`) вместе с утечками ресурсов. База относится
  к текущему смешанному рабочему дереву, не к чистому HEAD: мебель/физика владельца и зависимые
  части A2 остаются незакоммиченными. Сверка 242 исходных файлов — SHA-256, без потерь.
  Кадры READABLE 1080p/1440p и три точки замера — `.dream-loop/phase0/`; статус —
  `docs/plans/next/M1_FINISH_PLAN.md`. Следующая фаза требует OK владельца.
- M1_FINISH_PLAN, фаза 1: READABLE/CLASSIC — весь кадр 960×540, целочисленный fit,
  CLEAN — native. На 1080p — 2× без полей, на 1440p — 2× с полями 320/180 px.
  Пол 229 texels/m; потолок и панель 192; nearest+mipmaps на материалах комнаты.
  Physics interpolation включена; pose кресла остаётся покадровым, поворот стоя — по physics tick.
  Финальный прогон 117/3498 exit 0 без SCRIPT ERROR/повторов; production route 58 PASS exit 0;
  lint/boot exit 0. Кадры и видео — `.dream-loop/phase1/`; база всё ещё смешанное дерево.
- Фаза 1 (читаемость хука) закрыта. Живой трекер задач, журнал цикла и вопросы владельцу —
  `docs/plans/ROADMAP.md`. Кодекс разработки — `docs/reviews/2026-10-16_SENIOR_REVIEW.md` §11.
  Push делает только владелец; ветка `main` впереди `origin/main` на коммиты цикла.

## 2. Порядок чтения

1. Этот файл. 2. `AGENTS.md` (инварианты, команды). 3. `docs/plans/ROADMAP.md`. 4. `docs/plans/2026-09-27_STATE_OF_THE_GAME.md`.
5. `docs/plans/next/00_INDEX.md` (WS1–WS7). 6. GDD `docs/design/DEAD_WIRE_GDD_v1.0.md` (§3, §7, §10, §28, §35) + `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md`.

## 3. Headless-команды (быстрые, безопасные)

```bash
GODOT="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
GODOT_BIN="$GODOT" bash tools/run_all_tests.sh    # полная регрессия ~4–5 мин; SUITE_TIMEOUT=180 (env)
bash tools/run_all_tests_selftest.sh              # selftest раннера (sandbox, движок не нужен)
"$GODOT" --headless --audio-driver Dummy --path . --script tests/<dir>/<suite>_test.gd
"$GODOT" --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn  # boot smoke
"$GODOT" --headless --path . --import             # после нового class_name/ассета/переноса скрипта
.venv-tools/Scripts/gdlint.exe scripts/           # lint (tests/tools освобождены — устоявшийся стиль)
tools/watch_tests.sh [filter]                     # lint + фокусный suite по сохранению
```

Suites: `tests/{audio,debug,events,integration,office,player,state,telegraph,ui}/`.

## 4. Оконные инструменты (реальное окно, захват мыши, headless отказывает exit 2; запускать по одному)

| Инструмент | Доказывает | Ожидание | Вывод |
|---|---|---|---|
| `"$GODOT" --path . --script tools/production_evidence_capture.gd` | полный production-маршрут (с подшивкой копии 1) | **63 PASS** | `.dream-loop/production_evidence/` |
| `"$GODOT" --path . --script tools/first_night_playthrough.gd -- --capture` | вся ночь с первого запуска: калибровка, подшивка 1–2, хук, рассвет | **87 PASS** | `.dream-loop/playthrough_water/` |
| `tools/room_overview_capture.gd` | комната o1–o9 стоя, c1–c4 сидя | — | `.dream-loop/overview/` |
| `tools/writing_evidence_capture.gd` | рука и перо на листе | — | `.dream-loop/writing_evidence/` |
| `tools/hand_turntable_capture.gd` | кисть/манжет/рукав, 8 углов | — | `.dream-loop/hand_turntable/` |
| `tools/window_evidence_capture.gd` | окно, луна, фигура | — | `.dream-loop/window_evidence/` |
| `tools/commit_input_route_capture.gd` | маршрут стола подшивки | — | `.dream-loop/commit_route/` |

Визуальная приёмка = смотреть кадры глазами; `tools/vision_check.py` — только второе мнение (ловушка 11).
`first_night_playthrough.gd` без `--capture` — быстрая проверка логики/raycast ночи без реальных смен.

## 5. Генераторы (перезаписывают вывод; после запуска — `git diff`)

| Генератор | Пишет | Правило |
|---|---|---|
| `tools/author_writer_hand.py` → `tools/build_authored_writer_hand.gd` | `hand_authored_v1.json/.res` (активная кисть) | frame tool только после изменения пера |
| `tools/build_writer_hand.gd` (старая кисть; cloth/scene) | `hand_v3/cuff_v3/forearm_v3`; **правит `scenes/telegraph/transcript_paper.tscn`** | перезапускать после переноса стола/бумаги/кресла |
| `tools/build_paper_forms.gd` | формы PNG | константы должны совпадать с `Label3D` в `transcript_paper.tscn` |
| `tools/build_wallpaper.gd` | `psx_wallpaper_stripe_128.png` | — |
| `tools/generate_action_foley.py` | foley WAV | **общий RNG: новые звуки только в конец** |
| `tools/generate_sounder.py`, `generate_office_ambience.py` | sounder/ambience WAV | запускать из `.venv-tools` |
| `tools/build_lamp_chimney.py` | mesh дымохода | — |

Экспорт: пресеты «Playtest» (macOS zip) и «Windows Beta x86_64» + `tools/package_windows_beta.py`.

## 6. Ловушки (каждая стоила сессии)

1. Новый `class_name` невидим до `--import`. 2. Комментарии `;` в `.tscn` — только перед `[node …]`.
3. `Transform3D`-литералы: задавайте `rotation`, не basis. 4. Числа suites/assertions не падают никогда.
5. Тесты и capture-тулы пинят UI-строки: меняя строку, `grep -rn` по `scripts scenes data tests tools`,
   включая `tools/production_evidence_capture.gd` и `first_night_playthrough.gd`.
6. `ShiftDirector.Phase` только дописывать в конец. 7. Генераторы (§5) переписывают сцены; `rewrite.py`
   удалён (ROADMAP 0.2). 8. Foley RNG: только append. 9. Оконные тулы: мышь, минуты, по одному.
10. `.dream-loop/` вне git — ценные кадры копировать в `docs/art/`. 11. `vision_check.py` машинно-специфичен.
12. Системный Python без PIL/numpy — только `.venv-tools`. 13. (снято) `rewrite.py` удалён 2026-10-16.
14. GDScript-лямбды захватывают `int` по значению — счётчики в массивах. 15. Многострочные лямбды в аргументах не парсятся — именованные функции.
16. Рука: `vertex_color_is_srgb`; меши на `layers = 2` (маски `WindowBounceLight`/`RoomReflection` их исключают); cloth `SPECULAR_DISABLED`.
17. В индексе могут лежать файлы владельца: только явные пути, никогда `git add -A` / `commit -a`.
18. Центрирование yaw кресла намеренное. 19. macOS без `timeout` — раннер имеет собственный watchdog (SUITE_TIMEOUT, ROADMAP 0.6).
20. Writer rig тратит время тика один раз: не вызывать `advance_presentation` дважды за кадр, чернила только на `glyph_contact`.
21. `*.import` теперь в git (ROADMAP 0.4): коммитить вместе с ассетами; loop амбиенса закреплён `edit/loop_mode=1` (`as_looping()` — страховка).
22. Windows: после правок нормализуйте `.tscn`/`.gd` в LF — CRLF внутри многострочных строк `.tscn` парсится в `Label.text` буквально и ломает проверки равенства.

## 7. Шаблон теста

```gdscript
extends SceneTree
## <Какой контракт охраняет suite, 1–2 предложения.>
##   godot --headless --audio-driver Dummy --path . --script tests/<dir>/<name>_test.gd

func _init() -> void:
	call_deferred("_run")

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok

func _run() -> void:
	if not assert_condition(1 + 1 == 2, "Описывайте поведение, не код"): return
	quit(0)
```

Раннер grep'ает `PASS:`/`FAIL:` (отступ терпим) и exit code. TDD: сначала RED по нужной причине, потом GREEN.

## 8. Конвенции

- Коммиты: идентичность владельца, без co-author, только явные пути:
  `git -c user.name="Yusif Israfilov(Kaiser)" -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" commit …`.
  Тема: `feat:`/`fix:`/`refactor:`/`test:`/`docs:`/`chore:` + фраза голосом игры. Тело заканчивается
  строкой чисел: `N suites / M assertions green; lint clean; boot exit 0.` (+ оконные результаты).
- Заголовки скриптов: `class_name`, затем `##` — что узел значит в фикции и какой контракт держит.
  Комментарии редкие и объясняют «почему». Именованные контракты получают именованные тесты.
- Контент (сценарии, директивы, ночи) — в `.tres`, не в коде. CI не нужен — не предлагать.
- Числа в `AGENTS.md` обновляются в том же коммите, где меняются (кодекс §11 D25).
- Пушит владелец (в shell нет GitHub-учётки).
