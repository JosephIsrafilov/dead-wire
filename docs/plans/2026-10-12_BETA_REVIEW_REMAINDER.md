# DEAD WIRE — остаток после независимого review

Дата: 2026-10-12. **Один исполнитель, без сабагентов.**

- Основная спецификация: [FIRST_NIGHT_FINISH](2026-10-11_FIRST_NIGHT_FINISH.md).
- Предыдущий handoff: [BETA_HANDOFF_EXECUTION](2026-10-12_BETA_HANDOFF_EXECUTION.md).
- Независимое ревью: [REVIEW](../research/first_night_2026-10-12_beta_finish/REVIEW_2026-10-12.md).
- Машинная сверка: [REVIEW_EVIDENCE](../research/first_night_2026-10-12_beta_finish/REVIEW_EVIDENCE_2026-10-12.json).

## 1. Цель и ограничения

Завершить проверенный Windows beta-кандидат первой ночи для звукаря. Сначала он играет без спойлеров как внешний beta-тестер, затем получает отдельный технический sound brief. Не объявлять пять человеческих плейтестов проведёнными. Художественная/слуховая приёмка владельца и будущий внешний feedback — отдельные gates.

**Сейчас NOT READY TO SEND.** Новое решение владельца о размере листа не нужно: layout failure уже устранён. Отсутствие разрешения на установку debugger не блокирует формы, captures, packaging и code audit.

Не делать staging/commit/push, blanket rollback, новые ночи/город/IK, extra scares, telemetry, compact pacing. Walking/Morse speed, answer beat и deadlines 30/20/45 не менять. Сохранять truth/perception/transcript, объективную ленту, WorldState–KnowledgeState и прежние полномочия контроллеров. WER/registry/debugger installation — только отдельное разрешение. Не создавать сабагентов.

Перед изменениями прочитать AGENTS/RTK/HANDOVER и review; сохранить inventory, diff и копии затрагиваемых untracked файлов. HANDOVER устарел относительно этого review. Все engine runs — последовательно, через with_preserved_settings.py; shell commands — с rtk. Сохранять полные логи в уникальные каталоги.

## 2. Уже проверенное — не начинать заново

- Viewer parse/header исправлен.
- 48 SVG сопоставлены с font_before/: 47 изменены, space не менялся. Y-координаты и вертикальные char metrics height/yoffset не менялись.
- Widest row 0.17612 м < 0.18 м; projected height в desk test 28.6 px ≥20 px. Старые thresholds не ослаблены.
- Сохранённый full_02: **86/86 suites, 2747 PASS, 0 FAIL, 0 SCRIPT ERROR**, exit 0 у всех. Review пересчитал raw logs. **18 suites сохраняют shutdown resource ERROR**; один прогон не доказывает crash fix.
- На review повторно прошли 10 packager +5 font-builder Python tests. Godot повторно не запускался.
- P10 export: все 60 текущих class-cache scripts имеют .gd либо .gd.remap + .gdc entries. Предыдущий class_name omission в текущем build исправлен.
- ZIP: 13 файлов, CRC clean, без spoiler brief; PCK совпадает с p10. SHA256 ZIP: 87a7775b0c766a636cad46d4b148b7e50b378cfaf86454e99702c651fd166794.
- **Настоящая directory PCK содержит 548 entries**, не 618. Не считать raw strings за manifest.
- Unknown legacy footstep bytes всё ещё внутри PCK. Нынешний artifact не готов.
- p6_run2 — только renderer startup log без SCRIPT ERROR в наблюдённом интервале, exit 124. Это не подтверждение Begin Watch/office/restart/normal quit.

## 3. Пакеты исполнения

### Q1 — упаковка и документация

**Scope:** package_windows_beta.py, его tests, Windows section export_presets.cfg, docs/beta/*.md; небольшой PCK reader только по необходимости.

1. **RED:** private-notes.txt, extra.exe или неподтверждённый extra.dll внутри export source не должны молча входить в ZIP. Реализовать явный manifest: matching EXE/PCK и только реально необходимые approved runtime DLL. Не строить универсальный installer.
2. **RED:** pathname, оставшийся в class cache/remap, не должен считаться существующим bytecode. Сейчас check_pck_has_class_scripts ищет substring во всём PCK; тест с одной строкой не проверяет pack.
3. Читать настоящую directory текущего PCK v4: magic/version/flags, bounds, count, entry path/offset/size. Поддерживать только требуемый формат; для остальных — ясный unsupported. Для scripts проверять .gd payload либо .gd.remap → существующий .gdc target. Метаданные не являются исполняемым ресурсом. Не создавать generic pack explorer.
4. Windows-only exclusion для audio/sfx/foley/footstep_wood.wav. Исходник сохранить для rollback. В новом PCK не должно быть ни .import, ни соответствующего imported .sample. Beta footstep оставить. Проверять directory, а не raw substring.
5. Сохранить output-outside-source/source-not-repository guards. Build ID считать по final runtime manifest; неизвестные файлы не влияют на hash. Записать EXE/PCK hashes, source inventory/diff manifest, engine version и export command.
6. Исправить notices: runtime Noto Sans **static Regular**, не variable; убрать устаревшее утверждение unresolved sounder/legacy runtime footstep. Согласовать asset → source/generator → license. Проверить необходимые Godot MIT/model/audio credits, не заявлять blanket legal clearance.
7. Sound brief выдаётся отдельно после прохождения, но должен быть готов. Обновить stream names, lever runtime assignment, export status и открытый listening gate.

**Выход:** новые meaningful RED/GREEN tests, explicit file manifest, PCK payload validation, legacy asset отсутствует, notices однозначны. Старых 10 зелёных tests недостаточно для закрытия новых требований.

### Q2 — формы, почерк и guidance evidence

- Builder дважды → byte-identical atlas/metrics; source SVG не меняются. Не применять 0.90 повторно. Документировать ограниченный M/L SVG format, не обещать поддержку любого SVG.
- Проверить используемые строки, blank/partial sheet, длинное исправление, stable prefix, 10 columns, actual glyph contact и совпадение live/archive/viewer. Width и projected height проверять вместе. Ink остаётся на contact, не cue; никаких случайных offsets.
- **Оконно** выполнить tools/build_paper_forms.gd с текущими Old Standard/hand metrics. Перед этим сохранить outputs; после проверить только ожидаемые PNG diff и import. Генерация форм автоматизируема и сама по себе не требует человека. Старые hand/scene generators не запускать.
- Снять реальные кадры live writing, archive, viewer, card, route buttons, guidance и options при 720p/1080p, существующих presentation modes/text scales. Достаточно конкретных проверочных ракурсов, не сотни однотипных frames. Записать actual dimensions; MovieMaker не performance evidence.
- Посмотреть изображения: clipping, footer overlap, I/L, C/G, R/A, цифры, stamp/lever readability. Если image tool не показывает картинку, visual verdict UNVERIFIED, не accepted.
- Guidance: modal/pause/wire/deadline immediate clear; auto disabled + manual F1; once/cooldown/context transitions; stale queue, teardown. Hidden expected route/true message не поступают в помощь. Disconnected WorldState unit test не считать полной production anti-spoiler проверкой.

**Выход:** обновлённые формы, реальные кадры и технические проверки. Owner artistic approval остаётся отдельно от автоматических PASS.

### Q3 — функциональный звук и provenance

- paper_turn/route_lever/door_latch описаны существующим generate_action_foley.py. Сопоставить реально используемые bytes с generator в temporary workspace; сохранить before/after hashes. Не перезаписывать все WAV вслепую; shared RNG append-only.
- Проверить экспортируемые OfficeFoley streams/defaults, различие wick/wind и pickup/feed, single bind, teardown, accepted/rejected/late contracts. Pen → glyph_contact; stamp → stamp_contact; no correctness oracle.
- RoutingBoard._throw_lever назначает lever_impact_stream во время исполнения. Пустой stream в scene не доказывает отсутствие отдельного stop. Проверить throw sample + stop целиком; исправлять только подтверждённый двойной удар.
- Telegraph/Foley/thoughts options: live apply/persistence, Tab cycle, 720p fit/text scales, отсутствие modal click-through.
- Если агент не способен реально слушать, human headphones/speakers pass оставить открытым и предоставить короткий checklist/recording. Не перекладывать на человека механический code/provenance audit.

**Выход:** актуальная таблица source/trigger/bus/stream/level/provenance; protected Morse contracts green; listening status честный.

### Q4 — crash и shutdown отдельно

- Прежний probe подтвердил 0xC0000005 после 132 PASS; Rule44 тоже падал native после 12 PASS. Нынешний 0/1 не fix; test-harness-specific причина не доказана.
- Older dump 6456: Godot module +0x547AF6 без symbols; связь с последним probe не установлена. Offset не symbolized stack.
- Сначала read-only inventory доступных debugger/PDB, exact engine/test/source hashes, audio/backend, normal quit против forced timeout.
- При необходимости сделать **один конкретный запрос разрешения**: официальный инструмент/symbols, размер, цель, куда устанавливается/скачивается, какие system changes нужны. Не просить blanket WER разрешение. Cdb без matching symbols не гарантирует Godot function names; ProcDump снимает dump, а не символизирует его.
- Пока разрешения нет, сохранить точный blocker и продолжить независимые Q1–Q3/Q5. Не повторять один probe без новой информации.
- После evidence: одна гипотеза, один фактор, frozen control, заранее ограниченные runs. Не менять одновременно audio/tweens/free/wait.
- 18 test resource errors разобрать отдельно. StringName/PagedAllocator errors standalone с exit124 сравнить с graceful quit; не приписывать их игре, timeout или engine без evidence. Логи не подавлять.

**Выход:** обоснованный minimal fix с regression либо точный blocker report. При blocker не повышать статус ready-to-send без явного решения владельца о диагностической передаче.

### Q5 — актуальные игровые прогоны и измерения

- Оконный real-input production route; normal amendment, wrong valid word, FILE AS COPIED, lapse. Wrong route, missed call, incomplete copy — существующие test/capture paths.
- Restart/state clear, pause/options/menu, normal quit; authority/tape/write contracts не ослаблять.
- Real-time performance: hardware/resolution/mode, warmup/sample duration, p95/p99. Targets 20/33.3 мс — проектные, не научная гарантия. Teleports/compressed timers проверяют ветки, не human pacing.
- Один final full regression +lint после стабилизации, не после каждой мелочи. Baseline не ниже 86 suites/2747 assertions; новые контракты добавляют проверки. Native failed run сохранять, не повторять до зелёного.

**Выход:** current-tree production/branches/UI/performance evidence; human playtest NOT RUN до участия людей.

### Q6 — свежий пакет и standalone route

- Один fresh versioned export после всех changes. Проверить actual PCK directory/payloads, private paths и legacy exclusion через Q1.
- Новый ZIP CRC/hash/runtime manifest; основной ZIP без spoiler brief, отдельный brief готов.
- Extract в новый каталог; запуск без editor/project cwd. Сохранить executable/args/cwd/settings hashes before/after, EXE/PCK hashes, действия маршрута, raw child exit.
- Menu → Begin Watch → office → pause/resume → restart/menu → Quit. Whole-night branches сопоставить с Q5. Renderer boot 40 секунд и timeout124 не заменяют маршрут и graceful exit.
- Обновить HANDOVER/RESULT/checklist с exact version/evidence. Не объединять статистику разных builds. Git HEAD один не идентифицирует dirty build.

## 4. Экономный режим и передача

Один main agent, без delegation. Focused tests после конкретных fixes, один full в конце. Не читать огромные логи целиком в чат. Matching templates уже есть в .dream-loop/export_templates/templates/; 1.28 ГБ повторно не скачивать.

Новый evidence каталог: docs/research/first_night_2026-10-12_beta_review_finish/. Каждый run с уникальным out; старые failures сохранить.

- [ ] Q1: allowlist/PCK tests/legacy exclusion/consistent notices.
- [ ] Q2: forms/font/contact/layout/captures/guidance.
- [ ] Q3: streams/mix/provenance/options; честный listening gate.
- [ ] Q4: crash/shutdown disposition, blocker не выдан за fix.
- [ ] Q5: current production/branches/perf/full/lint.
- [ ] Q6: current ZIP/manifest/hashes/standalone route/graceful exit.
- [ ] HANDOVER +RESULT обновлены, передано на review; commit/push не было.

Вернуть коротко: выполнено / не проверено / blocked, изменённые файлы, exact logs/build ID/hashes, конкретно что нужно решить владельцу. Художественное одобрение и beta feedback не выдумывать.
