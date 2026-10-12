# DEAD WIRE — завершение Windows beta для звукаря

> **Review-дополнение 2026-10-12:** layout failure устранён; актуальный проверенный остаток — [BETA_REVIEW_REMAINDER](2026-10-12_BETA_REVIEW_REMAINDER.md). Сверка результатов и замечания — [REVIEW](../research/first_night_2026-10-12_beta_finish/REVIEW_2026-10-12.md). Ниже сохранён исходный handoff, не текущий статус исполнения.

Дата: 2026-10-12. Исполнитель: один агент, **без сабагентов**.
Основная спецификация: [FIRST_NIGHT_FINISH](2026-10-11_FIRST_NIGHT_FINISH.md).
Этот документ уточняет остаток и фактическое состояние после остановленного исполнения; не заменяет художественные и архитектурные требования основной спецификации.

## 0. Задача и граница передачи

Подготовить проверенный Windows x64 beta-кандидат первой ночи. Звукарь сначала проходит игру без спойлеров как внешний beta-тестер, затем читает отдельный технический звуковой brief. Оценка им багов/играбельности — будущий результат, не уже полученная приёмка.

Не реализовывать новые ночи, город, IK, stroke animation, новую передачу, compact pacing, telemetry или дополнительные scares. Не менять walking/Morse speed, answer beat, deadlines 30/20/45. Не создавать агентов. Не делать staging/commit/push, WER/registry изменения или внешние uploads без отдельного разрешения. Не переписывать существующий dirty tree ради удобства.

**Два разных итога:**
1. Engineering candidate: воспроизводимая сборка, проверенные контракты/маршруты, отчёт о фактических ограничениях.
2. Готовность к отправке: отсутствие нерешённого release blocker либо явное решение владельца передавать конкретный ограниченный диагностический build. Не считать молчание владельца согласием отправить сборку с необъяснённым native crash.

## 1. Прочитать до изменения файлов

- AGENTS.md, C:/Users/YUSIF/.codex/RTK.md.
- docs/HANDOVER.md: верхний checkpoint относится только к этапу A и **устарел относительно новых изменений**.
- Основную спецификацию, затем этот документ.
- docs/research/first_night_2026-10-11/implementation_a/RESULT.md.
- implementation_b/full_01/summary.json, guidance_integrated_imported/, production_01/, night_water_01/, export_02/ в том же research-каталоге.
- docs/research/first_night_2026-10-11/crash_probe/20261011_225329_814822_9ef949d4/result.json.

Все shell commands — через rtk. Python: .venv-tools/Scripts/python.exe. В sandbox launcher может сообщить Unable to create process; запросить штатное разрешение, не переустанавливать Python и не обходить ограничения другим runtime. Все engine runs — последовательно и через tools/with_preserved_settings.py. Оконные runs требуют разрешения, реального окна и могут захватывать мышь.

## 2. Достоверное исходное состояние

### Уже реализовано, не начинать с нуля

- Rule 44: FREIGHT 71 EAST, 13 cues, fiction/company wording, IDs/facts/HOLD сохранены.
- NightGuidanceController/Data + .tres + production overlay; F1, cooldown, once-only auto thoughts, блокировки. Полнота edge cases ещё не принята.
- Карточка American Morse с примером AL из encoder, объяснение пауз и wire take numbers; duty sheet разбит на тематические разделы.
- Interaction ray refresh на E; seat settle/stand .45, approach .34; viewer open .16; explicit intro skip .35 при normal fade2.2.
- Routing buttons через select_action и прежнюю acceptance authority; mouse capture восстановляется при закрытии.
- Bundled Noto Sans Regular/Old Standard Regular/Bold; Elias SVG/atlas/BMFont pipeline, подключение live/archive/viewer. Это **художественно не принятый кандидат**, не доказанный убедительный почерк.
- Export stream fields в OfficeFoley; Telegraph/Foley/thought options; register_wind.wav и project-authored footstep_wood_beta.wav.
- Sounder generator регенерирует существующие WAV byte-identically. Старый unknown footstep сохранён, runtime ссылки переведены на beta replacement.
- Windows preset, packager, docs/beta/*.md; matching official templates скачаны и извлечены локально.

### Что проверено — и что эти числа НЕ означают

| Evidence | Фактический результат |
|---|---|
| implementation_a/full_01 | 79 suites /2596 assertions /0 failed;17 suites с shutdown ERROR |
| implementation_b/full_01 | **85 suites /81 passed /4 failed**,2730 PASS lines;20 error-bearing suites |
| guidance_integrated_imported | 2 suites /22 PASS;production suite сохраняет shutdown resource ERROR |
| implementation_b/production_01/result.json | engine exit0,0 failures,6 screenshots;7 Texture RID warning;сам harness сначала упал при печати Unicode после сохранения child result |
| implementation_b/night_water_01 | engine exit0,0 failures,normal amendment/dawn/exit/restart;7 Texture RID warning |
| implementation_b/export_02 | export exit0;EXE+PCK созданы,но **устарели относительно последних правок** |
| Python tools discovery | 19 tests прошли;это не включает автоматически tests/python/ и tools/repro/ |

Full_01 failures: Foley node lookup/timeout; desk projected lettering18.2px при threshold20; routing label bounds; **Rule44 native0xC0000005 после12PASS**. После этого некоторые исправления внесены, но последний полный GREEN отсутствует.

При read-only inventory 2026-10-12 найдено **86** файлов *_test.gd. Это discovery count, не число прошедших suites. Проверить актуальный count заново перед execution.

### Срочный найденный дефект текущего дерева

scripts/ui/document_viewer.gd сейчас содержит строку с буквальными PowerShell escape-фрагментами:

    const HAND_DOC_ID := "transcript_paper"`nconst HAND_FONT_SIZE := 18.0`nconst HAND_PIXEL_SIZE := 0.00148

Там же HAND_FONT_SIZE/HAND_PIXEL_SIZE уже объявлены над extends. Исправить literal escape и дубли **до engine verification**; привести header к существующему class_name/extends/constant стилю. Не цитировать прежний lint как доказательство текущей parse readiness.

## 3. Защита чужой работы и порядок проверки

- Сохранить новый inventory, tracked diff и копии только редактируемых untracked файлов. Старый исходный diff: implementation_a/tracked_before.patch; он нужен для сравнения, НЕ для blanket rollback.
- Во время прошлого прохода routing_board.gd был ошибочно восстановлен агентом из HEAD; parent восстановил прежние dirty authority hunks из checkpoint. Не повторять git restore/checkout/reset. Route reentrancy после восстановления дал8PASS.
- Responsiveness-файлы восстановлены parent из HEAD **плюс прежний dirty patch**, затем хирургически изменены. Не переносить повреждённые BOM/mojibake версии обратно.
- Для каждого пакета: конкретный failing assertion → минимальное исправление → focused regression. Parse failure не считать RED контрактом. Старые FAIL logs сохранять.
- Не гонять полный regression после каждой мелочи. Один раз после интеграции пакетов; повторять только после конкретного исправления, не ради случайного зелёного native exit.
- Новый отчёт: docs/research/first_night_2026-10-12_beta_finish/. Уникальные каталоги, отдельно child exit, PASS/FAIL, SCRIPT/parse/runtime ERROR, shutdown ERROR/warnings.

## 4. Исполнение по пакетам

### P1 — восстановить coherence и закрыть обычные failures

**Файлы:** document_viewer.gd, foley_lifecycle_test.gd, office_foley.gd только по установленной причине; font/layout files; route_explanation_test.gd; соответствующие тесты.

1. Исправить описанный viewer header, проверить оставшиеся literal escape/BOM/дубли в изменённых файлах без глобальной переформатировки.
2. Foley: production _bind ищет TelegraphSessionController/TapeRegister. Новый _test_stream_injection создаёт session с другим name и вызывает get_node("RegisterWind") без guard; это вероятная конкретная причина. Сопоставить fixture с production topology либо обоснованно использовать уже имеющийся authority accessor, не добавлять фиктивный RegisterWind ради теста. Тест должен падать assertion, не зависать90с на null. Сохранить lifecycle/idempotency/accepted-only проверки.
3. Desk: не снижать20px threshold. Сцена/формы после interrupted worker уже используют font_size18 и pixel_size.00148; проверить реальный результат, границы и contact, а не ещё раз автоматически увеличивать.
4. Route bounds test был изменён с bottom112 на68 под кнопки, но финальный GREEN не получен. Проверить fit/no overlap и обе клавиатурные/мышиные команды; rejected/late route не анимировать.
5. Import, focused suites, lint. Проверить соответствующие Python tests; не засчитывать отсутствие discovery как pass.

**Выход:** parse/runtime failures пакета устранены; focused assertions не уменьшились; маршрут принятия не изменён.

### P2 — закрыть font/layout/forms и guidance edge cases

**Fonts:** tools/build_elias_font.py, assets/fonts/elias_working/*, transcript_paper.tscn/.gd, document_viewer.gd, build_paper_forms.gd, tests/python/test_elias_font_builder.py, elias_handwriting_font_test.gd.

- SVG теперь реально читаются builder; уже существующие источники не удаляются/не заменяются stroke table. Проверить, что HAND_LEAN изменения не остались только в коде создания отсутствующих SVG: существующие SVG могли сохранить прежнюю форму.
- Atlas белая alpha mask; проверить stroke bounds с толщиной, comma descender, cropped right strokes C/G/R/Q, Godot metrics и stable prefix. Test наличия char в .fnt НЕ доказывает реальное coverage/layout.
- SVG parser понимает ограниченные M/L paths; честно документировать формат, не обещать произвольное SVG editing. Не вводить универсальный SVG renderer ради этого этапа.
- Builder twice → byte-identical atlas/metrics, источники unchanged. Все A–Z/0–9/нужная punctuation читаемы, I/L,C/G,R/A и digits различимы.
- Единые реальные metrics для live/archive/viewer/forms;10columns сохранены; contact вычисляется по активному font, не random offsets.
- Перегенерировать печатные формы **в окне** через build_paper_forms.gd; проверить diff только ожидаемых PNG, import. Не запускать старые hand/scene generators.
- Сохранить реальные кадры live writing, archive, viewer в720p/1080p. Если image tools не показывают изображение, явно отметить visual acceptance UNVERIFIED, не подписывать кадры accepted.
- Документировать художественный статус и будущее ухудшение руки без реализации других ночей; owner approval отдельно.

**Guidance:** проверить пропуски шагов, повторные signals, expiry/cooldown, pause/resume, disabled auto+manualF1, teardown, быстрые modal переходы, предупреждения; immediate clear при transmission start. Никаких hidden message/expected route/correctness входов. Текущий anti-spoiler test меняет disconnected WorldState — дополнить проверкой реального production состояния, а не считать его исчерпывающим.

Проверить нижний overlay в screen space: максимум2строки, text scale, footer overlap, отсутствие двойной persistent hint; освоенный read/route не повторяется автоматически. F1 должен объяснять актуальную процедуру без выбора ответа. Критерий «ключ только после фактической посадки» сопоставить с current director is_seated vs is_settled и тестами; не отменять свободный manual look.

### P3 — звук и options без ложной готовности

- OfficeFoley stream injection: actual defaults, correct signal once, teardown, pen=glyph_contact, stamp=stamp_contact, accepted lever start и отдельный stop. Прослушать route_lever целиком: семпл сам содержит impacts, поэтому отдельный stop может удваивать удар. Исправлять только подтверждённый дефект.
- Wick/register и pickup/feed действительно разные stream/звуки. Telegraph/Foley/options persistence и live apply, main/pause menu Tab cycle/fit720p при всех text scales; после modal Enter/E/Esc нет click-through.
- Установить provenance paper_turn/route_lever/door_latch по generator, при необходимости regeneration с before/after hashes. Shared RNG generate_action_foley append-only; не менять прежние файлы случайной вставкой RNG calls.
- docs/beta/SOUND_HANDOFF_SPOILERS.md содержит устаревающие/противоречивые значения и предложение «assign worker» — убрать делегирование, привести к актуальному коду. THIRD_PARTY_NOTICES должен отражать Noto/OldStandard/Elias и временные beta sounds.
- Необязательный Foley не маскирует critical Morse; no correctness sounds. Waveform/auto tests не заменяют реальное listening QA. Наушники/динамики — отметить фактически выполненное или оставить honest gate.

### P4 — native crash отдельно, не случайный teardown patch

**Подтверждение:** latest one-run probe result3221225477/0xC0000005 после132PASS, original test SHA25693102bcca9189bc55df33596377a52c5c7642dcbc185e5cd7a32a872d357042b. После12PASS Rule44 тоже был native crash: проблема не доказана специфичной для ShiftDirector.

Доступный dump .6456.dmp (22:12 прошлого дня) read-only metadata: access violation в Godot exe+0x547AF6. Evidence older_dump_6456_metadata.json. **Не доказано**, что dump принадлежит последнему probe; module offset не символизированный stack и не root cause.

- Старые control/teardown experiments inconclusive. Не менять production по их догадкам.
- Exact wrapper --result-json уже сохраняет raw exit; run_crash_probe создаёт уникальный каталог. Проверить timeout handling: убийство wrapper не должно оставить child/settings незавершёнными; не утверждать гарантированное восстановление при hard kill.
- Следующий диагностический шаг должен дать stack или явно документированное ограничение доступных symbols/debugger. Не повторять тот же probe без новой информации. WER/registry/procdump/debugger setup требует отдельного разрешения.
- Если есть обоснованная гипотеза: frozen control, один фактор на эксперимент, одинаковые engine/build/backend/input и ограниченный заранее batch. Ноль crashes не установленная причина.
- Shutdown resource errors разобрать отдельно; осторожно с resource reference cycles и surviving Nodes, но это гипотезы до evidence. Не обнулять warnings подавлением логов.

**Выход:** доказанный минимальный fix с regression или точный blocker-report. Во втором случае остановить статус ready-to-send; владелец решает про отдельный diagnostic build. Не называть crash resolved из-за green assertion banner.

### P5 — integrated evidence

После coherence fixes, generation/import и стабильного дерева:
- Full regression: discovery count не падает (сейчас86), assertions не ниже прежнего clean2596; новый итог вывести из raw logs. Не суммировать разные версии.
- Lint scripts/ only; boot0 parse/runtime errors; shutdown status отдельно.
- Serial windowed production route; normal/wrong valid amendment/FILE AS COPIED/lapse. Wrong route/missed call/incomplete copy также через существующие test/capture paths. Не ослаблять deadline и accepted-only tests.
- Menu → watch → pause/options → resume → dawn/handover → exit → restart/menu/quit. Settings restored after every run.
- Реальные720p/1080p,3 presentation modes и existing text scales; если OS ограничивает1080p, записать actual dimensions.
- Реальный performance: hardware/resolution/mode/warmup/sample duration,p95/p99. MovieMaker/teleports/compressed timers не human pacing или real-time benchmark. Input processing timestamps не input-to-photon.
- Human results NOT RUN. Звукарь — первый будущий внешний beta-тест; пяти-player gate основной спецификации остаётся открытым, не выдумывать и не блокировать подготовку пакета ожиданием моделей-«игроков».

### P6 — свежая standalone beta и безопасный пакет

- Windows preset уже изменён на scene dependency closure после успешного export_02; **эта новая конфигурация не экспортировалась**. Проверить runtime load() dependencies/menu/office/guidance/fonts и class cache. macOS preset не менять.
- Templates локальные .dream-loop/export_templates/templates/windows_*_x86_64.exe. Archive SHA25686409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72. Не скачивать1.28GB повторно.
- Новый export в отдельный versioned каталог; существующий EXE/PCK не выдавать за current. Лицензии runtime/models/fonts/music/Godot включить, tools/tests/research/.hermes/credentials/logs/SVG authoring sources и неизвестный legacy footstep исключить. Проверить PCK manifest, не только внешнюю ZIP структуру. icon.svg runtime оставить.
- Packager сейчас пишет ZIP внутрь потенциального source export directory. Исправить/проверить: старые ZIP и output ZIP не входят в build hash/archive; разрешать только нужные standalone файлы, требовать matching EXE+PCK, source не repository root. Добавить unit tests, не «архивировать всё кроме denylist».
- Build ID должен связывать **фактические EXE/PCK hashes**, dirty source snapshot/manifest и дату. Git HEAD один не идентифицирует незакоммиченный build.
- Проверить standalone без редактора/проектного cwd (из extracted package), main menu и реальный office launch; headless quit-after недостаточен. Не открывать неподтверждённый artifact пользователю автоматически как готовый.
- English README spoiler-free; F1/options/unsigned publisher/temporary audio/known limitations. Spoiler brief в отдельном явно помеченном файле. Report form: bugs,steps,expected/actual,buildID,playability/questions,без raw typed words/names/автосбора. Никаких uploads.

## 5. Команды (пример; каталоги evidence всегда новые)

PowerShell из C:/Users/YUSIF/Documents/dead-wire. Любой запуск engine сохраняет настройки; не запускать параллельно.

    rtk proxy .venv-tools/Scripts/python.exe tools/with_preserved_settings.py -- C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe --headless --audio-driver Dummy --path . --import
    rtk proxy .venv-tools/Scripts/python.exe tools/with_preserved_settings.py -- .venv-tools/Scripts/python.exe tools/verify_mechanics.py --filter foley_lifecycle --out docs/research/first_night_2026-10-12_beta_finish/foley_01
    rtk proxy .venv-tools/Scripts/gdlint.exe scripts/
    rtk proxy .venv-tools/Scripts/python.exe -m unittest discover -s tools -p '*_test.py'
    rtk proxy .venv-tools/Scripts/python.exe -m unittest discover -s tests/python -p 'test_*.py'
    rtk proxy .venv-tools/Scripts/python.exe tools/with_preserved_settings.py -- .venv-tools/Scripts/python.exe tools/verify_mechanics.py --out docs/research/first_night_2026-10-12_beta_finish/full_01
    rtk proxy .venv-tools/Scripts/python.exe tools/with_preserved_settings.py -- .venv-tools/Scripts/python.exe tools/capture_engine_run.py --out docs/research/first_night_2026-10-12_beta_finish/production_01 --timeout 180 -- --path . --script tools/production_evidence_capture.gd

Для остальных focused tests заменить filter: desk_geometry, route_explanation, route_reentrancy, routing_mouse, guidance, elias_handwriting_font, transcript_paper, writer_rig_space, readable_settings, settings_exit_paths, procedural_clarity, reference_reading_example.

Проверь фактические supported flags инструмента перед использованием. capture_engine_run сохраняет child code в result.json; wrapper exit может отличаться. При abnormal/native exit не повторять до зелёного.

## 6. Что вернуть владельцу и ревьюеру

Один короткий итог + docs/research/first_night_2026-10-12_beta_finish/RESULT.md:
- Реально изменённые файлы/пакеты, rationale → intended effect → actual check.
- Исходный inventory, protected changes, diff/rollback references без reset.
- RED/focused/full/lint/raw child exits, отдельно errors/shutdown/crashes; точные evidence paths.
- Идентификатор сборки, hashes, ZIP path, список содержимого и standalone checks **только если реально выполнены**.
- Выполнено / candidate / unverified / blocked. Visual/listening/human tests не подменять автоматикой.
- Native crash disposition и причины shutdown; любые неопределённости явно.
- Никакого commit/push/staging без разрешения. Передать результат на review прежнему агенту, не заявлять его review заранее.

## 7. Checklist

- [ ] P1: coherent tree + ordinary failures green.
- [ ] P2: font/forms/contact/guidance проверены; visual status честно обозначен.
- [ ] P3: sound streams/options/provenance и актуальный brief.
- [ ] P4: crash/shutdown disposition, release blocker снят либо явно остаётся.
- [ ] P5: новый full/lint/boot/production/branch evidence.
- [ ] P6: current standalone build/clean package/hashes, runtime launch.
- [ ] Передано на независимый review; owner artistic approval и beta feedback отдельно.

В этой planning-only правке engine/tests/export не запускались; состояние выше — read-only inventory и сохранённые ранее результаты.
