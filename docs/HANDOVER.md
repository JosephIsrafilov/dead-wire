# FORM 19 (dead-wire) — HANDOVER (read this first)

Обновлён **2026-11-23** (ребрендинг **`FORM 19`** с восковой иконкой и живым 3D-меню + финализация M1 + принятый этап **M2-A / Фаза 6 города** + полная библия сюжета, режиссуры и аудио-PDF, ветка `experiment/seated-bay-m1`): актуальная точка входа
для любой модели. Снимок решений текущей сессии: `docs/plans/SESSION_HANDOVER_2026-11-23.md`. История прошлых циклов — `docs/plans/HANDOVER_HISTORY.md` и `git log`.
Документы на русском (кроме `AGENTS.md` и `docs/AGENT_RULES.md`), код и комментарии на английском.

## 1. Текущее состояние (M1 Final + FORM 19 + принятый M2-A)

- **Движок:** Godot 4.7.1 stable (`C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`).
- **Рабочая ветка:** `experiment/seated-bay-m1` (M1 Первая ночь отполирована и готова к внешнему плейтесту).
- **Игровой поток M1 (гибридный):**
  1. **Вход и свободная ходьба (`WASD` + мышь `[CAPTURED]`):** Элиас заходит в станцию Блэк-Крик ночью;
     может осмотреть комнату (печь, полки, книги, дверь, окно) и сесть за телеграфный стол (`[E]` на стул).
  2. **Посадка за рабочий пост (`SeatedStationController`, вид 360°):** курсор `[VISIBLE]`, полный
     круговой обзор по клавишам/кнопкам:
     - `A` / `‹`: `Стол → Поездной сигнал → Дверь → Подшивка → Стол`
     - `D` / `›`: обратное кольцо
     - `W` / `⌃`: прямо к `Стол` из любой позиции; `S` / `⌄`: прямо к `Дверь` из любой позиции
     - Взаимодействие кликом ЛКМ по приборам/папкам/рычагу, ПКМ прильнуть к окну, колесо мыши — фитиль лампы, `Пробел`/удерж. ЛКМ — телеграфный ключ.
  3. **Рассветный уход:** после завершения смены появляется `[Tab]` / `Встать`, Элиас встаёт и
     выходит через входную дверь. (В M2-A этот выход перейдёт в рассветную дорогу домой и сон.)
- **Визуал и предметная среда (доведено в финализации M1):**
  - **Восточная стена:** `Bookcase` с томами `PhLedgerVolumes` (`(2.62, 0, -0.45)`), рядом тумбочка
    `CornerSideTable` (`(2.55, 0, -1.62)`) с горящей латунной свечой `CornerCandle` (`CandleLife`,
    теплое мерцание с тенями); `StoveEmberLight` вынесен наружу решётки печи; без-теневой black-crush
    смягчён в `psx_grade.gdshader` (`ambient_light_energy = 0.095`, `tonemap_exposure = 1.36`).
  - **Левый простенок (`RoutingBoard`, 1890s Train-Order Signal Stand):** перестроен по историческим
    референсам 1890-х (чугунная A-рама `CastIronWorn`, зубчатый квадрант, тяга и шкив вверх,
    латунный репитер-диск с двумя аспектами, эмалевые таблички на заклёпках, тёплый керосиновый
    бра `RoutingBoardSconceLight`, RU/EN подписи).
  - **Стол и бумаги:** `PreviousSheet` лежит на свободном зелёном сукне слева от основного листа
    (`(-0.27, -0.0115, 0.03)`), а не свисает с края; `CopyCommitDesk` пересобран в ореховые
    планшеты-клипборды с латунными зажимами, штемпельной подушечкой и угловыми штампами;
    `DocumentViewer` стилизован под состаренный пергамент 1890-х со шрифтом `OldStandardTT` и
    тонким сепия-скроллом (горизонтальный скролл ленты отключён, когда полоса помещается в окно).
- **Бренд, иконка и главное меню (`FORM 19`):**
  - Витринное название игры — **`FORM 19`** (`MainMenu.WINDOW_TITLE`); внутренний `config/name="dead-wire"` в `project.godot` сохранён для совместимости путей настроек и сейвов.
  - Иконка — сургучно-латунная печать 1890-х с рельефным `19` и `· — ·` (`icon.ico` на 7 размеров `16..256 px`, `icon.png`, обновлённый `icon.svg`, мастер `assets/branding/form19_icon_master.png`, генератор `tools/build_form19_icon.py`).
  - Главное меню (`scenes/ui/main_menu.tscn`, `TitleMood`, `TitleBackdrop3D`) рендерит в реальном времени 3D-диораму ночного депо через 5-битный Bayer PSX-шейдер с живым мерцанием лампы, параллаксом от мыши, редким импульсом `· — ·` и силуэтом за забором; настройки оформлены через `PeriodUIStyle` в 3-вкладочную книгу (`Игра / Звук / Экран`) с быстрым переключателем `RU | EN` и живым звуком по аудиошинам.
- **M2-A и Блэк-Крик (Фаза 6 принята):**
  - Проходимость моста в обе стороны (`tests/town/m2a_street_traversal_test.gd` — 8/8 PASS), связка рассвета/пансиона/сна/дня (`tests/town/m2a_dawn_lodging_flow_test.gd` — 27/27 PASS).
  - Визуал Фазы 6 (27 кадров в `.dream-loop/town_overhaul/phase6/`): выправлены рампа моста, телега со спицованными колёсами на грунте, вывески кузницы/врачебницы/ворот `MJ`, копёр и заснеженные хребты, белёная часовня с посаженными на склон елями, дневное освещение салуна «Медный Мул» в 11:30 и вид из окон Комнаты № 4. Готово к переходу в **M2-B1**.
- **Локализация и фокус:** русский язык стоит по умолчанию (`GameLocale`, переключается на EN);
  исправлена потеря интеракции после Alt-Tab в оконном режиме (`PauseMenu` биндит `get_tree().root`
  в `_enter_tree()`, перещёлкивает `VISIBLE → CAPTURED` для Windows `ClipCursor`, а неактивный
  `SeatedStationController` не трогает `InteractionController.cursor_mode`).
- **Состояние тестов на ветке:**
  - Активные ключевые сьюты гибридного M1 + рендер/бумага/подшивка/сигнал стабильно **PASS** (0 FAIL),
    `gdlint scripts/` — 0 ошибок, headless boot smoke — exit 0, Windows Beta release export + PCK — exit 0.
  - Известные легаси-расхождения ветки (остались от старой EN/standing-only базы до гибрида):
    `bookshelf_inspect_test.gd` и `tape_layout_test.gd` (ждут старые EN-строки/шрифт),
    `m1_spatial_metrics_test.gd` (8 ассертов ждут старую геометрию шкафа/стола подшивки).
  - Известный шум движка на teardown: редкий ObjectDB leak при выходе и `shift_director_test`
    teardown crash в ~1/3 полных прогонов после всех 132 PASS ([Godot #117991](https://github.com/godotengine/godot/pull/117991)).

## 2. Порядок чтения для нового агента

1. `docs/AGENT_RULES.md` — правила работы, чекпоинты, арт-дирекшн, антипаттерны.
2. `AGENTS.md` — команды и **нерушимые архитектурные инварианты**.
3. Этот файл (`docs/HANDOVER.md`) — текущее состояние и ловушки + **свежий снимок последней сессии:** `docs/plans/SESSION_HANDOVER_2026-11-23.md` (обязательно прочесть перед продолжением!).
4. **`docs/plans/next/ACTIVE_ROADMAP.md`** — **единственный активный план развития** (M1 Final →
   M2 Рассвет/пансион/солнечный Блэк-Крик/салун → Ночь 2+ → M3 Концовки).
5. **Дизайн-библия города и дня:** `docs/design/BLACK_CREEK_TOWN_AND_DAYTIME_DESIGN.md` (генеральный план Блэк-Крика 140×75 м, 14 объектов, салун «Медный Мул», экономика 1890 г., выпивка, спины/казино, персонажи в духе RDR2 + Steel Ball Run, дуальный шейдер День/Ночь).
6. **Мастер-библия визуального продакшна города 1890 г.:** `docs/art/BLACK_CREEK_1890_VISUAL_PRODUCTION_BIBLE.md` (историческая архитектура Колорадо 1890, CC0-библиотека текстур Poly Haven/AmbientCG, полиграфия и вывески вместо белых квадратиков, экстерьер и интерьер Салуна «Медный Мул», 5-фазный автономный арт-план и 15-пунктовый чек-лист).
7. **Глобальная библия сюжета, хоррора и дедукции:** `docs/design/DEAD_WIRE_STORY_AND_HORROR_BIBLE.md` (единая отполированная кампания Ночи 1–6 + Дни 1–6, тайна 14 окт. 1885 г., сквозная линия отца-палача *Long Drop*, кульминация Дж. Коула в суде и 6 финалов).
8. **Канонические досье персонажей (12 фигур):** `docs/design/DEAD_WIRE_CHARACTER_DOSSIERS.md` (точные даты рождения, знаки зодиака, восточные года, включая Дж. Коула 1 июня 1837 г. / Огненный Петух, отец — «врач-палач» 1880-х, тики для *Liar's Bar*-блефа, реакции на курение и звуковые сигнатуры речи).
9. **Режиссёрская и продюсерская библия:** `docs/design/DIRECTOR_AND_PRODUCER_BIBLE.md` (синтез 7 референсов, пейсинг первых 60–90 минут, силуэт в Ночь 1, курение 1890 г., азарт + «Аванс Стерлинга», «Живое кино» в диалогах и 3-уровневая библия PSX-анимаций).
10. **Режиссёрский бриф по звуку и музыке:** `docs/audio/DEAD_WIRE_Sound_Brief_Mobile.pdf` (короткая 6-страничная выжимка для чтения с телефона — пересылать другу) + `docs/audio/SOUND_AND_MUSIC_DIRECTOR_BRIEF.md` (полная тех. карта для движка: 4–6-нотный лейтмотив, церковный хор/фисгармония, секретный стук `· — ·`, *Audio Fairness* `1.2–4 kHz`, 12 сигнатур и полезные плагины/базы SFX).
11. GDD: `docs/design/DEAD_WIRE_GDD_v1.0.md` (§3, §7, §10, §28, §35) + `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md`.

## 3. Headless-команды (Windows PowerShell 5.1 и bash)

В PowerShell 5.1 нет `&&` — связывайте шаги через `; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`.

```powershell
$GODOT = "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"

# Линт production-скриптов (tests/ и tools/ освобождены; лимит 1000 строк/файл)
.venv-tools\Scripts\gdlint.exe scripts/

# Boot smoke (должен вернуть exit 0 без SCRIPT ERROR)
& $GODOT --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn

# Фокусный тест
& $GODOT --headless --audio-driver Dummy --path . --script tests\office\phase2_hybrid_flow_test.gd

# Обновление кэша классов/ассетов после нового class_name или .png/.ogg/.tres
& $GODOT --headless --path . --import

# Сборка и упаковка Windows Beta релиза в .zip для плейтеста
& $GODOT --headless --path . --export-release "Windows Beta x86_64" ".dream-loop/export_check/dead-wire-windows-beta-x86_64.exe"
.venv-tools\Scripts\python.exe tools/package_windows_beta.py .dream-loop/export_check --output builds/windows-beta
```

Полная bash-регрессия:
```bash
GODOT_BIN="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" bash tools/run_all_tests.sh
```

Сьюты: `tests/{audio,debug,events,integration,office,player,state,telegraph,ui}/`.

## 4. Оконные инструменты (только реальное окно, не headless; запускать по одному)

| Инструмент | Что проверяет | Ожидание | Вывод |
|---|---|---|---|
| `tools/production_evidence_capture.gd` | полный production-маршрут с подшивкой | **63 PASS** | `.dream-loop/production_evidence/` |
| `tools/first_night_playthrough.gd -- --capture` | вся ночь: калибровка, подшивки, хук, рассвет | **87 PASS** | `.dream-loop/playthrough_water/` |
| `tools/first_night_playthrough.gd -- --walk` | живые часы, ходьба, фитиль, выход | **113 PASS** | `.dream-loop/playthrough_water_walk/` |
| `tools/room_overview_capture.gd` | обзор комнаты стоя и сидя | — | `.dream-loop/overview/` |
| `tools/writing_evidence_capture.gd` | рука и перо на листе | — | `.dream-loop/writing_evidence/` |
| `tools/hand_turntable_capture.gd` | кисть/манжет/рукав | — | `.dream-loop/hand_turntable/` |
| `tools/window_evidence_capture.gd` | окно, луна, фигура | — | `.dream-loop/window_evidence/` |
| `tools/commit_input_route_capture.gd` | стол подшивки | — | `.dream-loop/commit_route/` |

Визуальная приёмка = всегда открывать и смотреть реальные PNG глазами; `tools/vision_check.py` — только второе мнение.

## 5. Генераторы (перезаписывают вывод; после запуска смотреть `git diff`)

| Генератор | Пишет | Правило |
|---|---|---|
| `tools/author_writer_hand.py` → `tools/build_authored_writer_hand.gd` | `hand_authored_v1.json/.res` | frame tool после правки |
| `tools/build_paper_forms.gd` | формы PNG | константы = `Label3D` |
| `tools/build_wallpaper.gd` | `psx_wallpaper_stripe_128.png` | — |
| `tools/generate_action_foley.py` | foley WAV | **общий RNG: новые звуки только в конец** |
| `tools/generate_sounder.py`, `generate_office_ambience.py` | sounder/ambience WAV | запускать из `.venv-tools` |
| `tools/package_windows_beta.py` | `.zip` архив релиза + манифесты | проверяет PCK v4, MD5, `class_name` |

## 6. Ловушки (каждая стоила часов отладки)

1. Новый `class_name` невидим до `--import`.
2. Комментарии `;` в `.tscn` — только перед `[node …]`.
3. `Transform3D`-литералы: задавайте `rotation`, не basis.
4. Числа проверок/инвариантов не опускать молча.
5. UI-строки могут пиниться тестами — меняя строку, проверяйте `rg` по `scripts scenes data tests tools`.
6. `ShiftDirector.Phase` только дописывать в конец.
7. Генераторы (§5) перезаписывают сцены — проверяйте перед запуском.
8. Foley RNG: новые звуки добавлять только в конец.
9. Оконные тулы требуют фокус, мышь и запускаются строго по одному.
10. `.dream-loop/` вне git — ценные референсные кадры при необходимости копировать в `docs/art/`.
11. `vision_check.py` может ошибаться в деталях — смотреть кадры глазами.
12. Системный Python без PIL/numpy — использовать `.venv-tools\Scripts\python.exe`.
13. (снято) `rewrite.py` удалён.
14. GDScript-лямбды захватывают `int` по значению — счётчики делать массивами (`[0]`).
15. Многострочные лямбды в аргументах не парсятся — выносить в именованные методы.
16. Рука: `vertex_color_is_srgb`; меши на `layers = 2`; cloth `SPECULAR_DISABLED`.
17. В рабочем дереве могут быть незакоммиченные файлы владельца — никогда `git add -A` или `git checkout --`.
18. Центрирование yaw кресла намеренное.
19. У раннера `run_all_tests.sh` свой `SUITE_TIMEOUT`.
20. Writer rig тратит `delta` один раз (`advance_presentation`), чернила ложатся только на `glyph_contact`.
21. `*.import` в git: коммитить вместе с ассетами.
22. Windows CRLF: нормализуйте `.tscn`/`.gd`/`.md` к LF (`\n`), иначе CRLF ломает `Label.text` в `.tscn`.
23. **`SubViewport` reparent & фокус окна:** `M1OfficeController` переносит `M1Office` в `OfficePresentation/OfficeFrame`, вызывая `_exit_tree()` → `_enter_tree()`. Любые подписки на `get_tree().root` (как в `PauseMenu`) вешать в `_enter_tree()` и снимать в `_exit_tree()`. При возврате из Alt-Tab на Windows обязательно циклить `VISIBLE → CAPTURED`, чтобы `DisplayServer` перезахватил OS `ClipCursor`.
24. **`SeatedStationController` vs `InteractionController.cursor_mode`:** системные `NOTIFICATION_WM_MOUSE_EXIT` / `FOCUS_OUT` приходят и пока Элиас ещё стоит. Неактивный `SeatedStationController` (`not enabled or not _activated`) не имеет права вызывать `_clear_cursor_target()` и переводить `InteractionController.cursor_mode` в `true`.
25. **`physics_interpolation` в тестах:** при телепортации игрока в тесте вызывать `player.reset_physics_interpolation()` и ждать **два** `physics_frame` + `process_frame`, чтобы `camera.top_level = true` и луч успели синхронизироваться.
26. **PowerShell 5.1 и лимит 1000 строк:** в PowerShell 5.1 нет `&&`; `gdlint` ограничивает файл 1000 строками (`m1_office_controller.gd` сейчас 997 строк — не раздувать, выносить новые механики и будущие сцены M2 в отдельные скрипты/узлы).

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

## 8. Конвенции коммитов

- Идентичность владельца, без co-author, только явные пути:
  `git -c user.name="Yusif Israfilov(Kaiser)" -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" commit ...`
- Тема: `feat:`/`fix:`/`refactor:`/`test:`/`docs:`/`chore:` + коротко и по сути.
- Пушит только владелец; не переписывать историю и не пушить без прямой просьбы.
