# DEAD WIRE — точечное закрытие native crash и оставшихся beta-gates

Работай в C:/Users/YUSIF/Documents/dead-wire.
Задача: довести текущий кандидат до честного handoff звукарю/бета-тестеру, сначала проверить и исправить установленный crash path. НЕ переделывать завершённые механики.
**Один агент, БЕЗ САБАГЕНТОВ, экономно.** Без commit/stage/push/reset/restore. Сохрани всю чужую dirty-работу. Прочти AGENTS.md, RTK.md, docs/HANDOVER.md.
Все shell commands через rtk. Godot — только последовательно через tools/with_preserved_settings.py с raw child exit/result-json. При GUI/sandbox/network/system changes используй штатный approval; пользовательский запрос на задачу не даёт blanket permission на установки.

## Начни с этих документов, не повторяй сделанное расследование

1. docs/research/first_night_2026-10-12_crash_review/REVIEW.md
2. docs/research/first_night_2026-10-12_crash_review/offline_dump_analysis.json
3. docs/research/first_night_2026-10-12_crash_review/disassembly.txt
4. docs/research/first_night_2026-10-12_crash_review/upstream_117991_files.json
5. docs/plans/2026-10-12_BETA_REVIEW_REMAINDER.md

Новый независимый review уже проверил 21 packager test, ZIP CRC/hash/EXE/PCK и 546 PCK entries. Не переписывай packager заново и не гоняй full regression до конкретного исправления.

## A. Crash: теперь есть конкретная локализация, не начинай снова с «нужен cdb»

Все 3 старых дампа (08/09/11 октября) имеют:
- read access violation 0xC0000005 по Godot RVA +0x547AF6;
- instruction mov r12, qword ptr [r13+8]; fault address точно r13+8;
- одинаковую ограниченную AMD64-unwind цепочку +0x547AF6 ← +0x3E39378 ← +0x5FFB1;
- дизассемблирование + exact a13da4feb source с высокой уверенностью дают Main::cleanup → ScriptServer::finish_languages → GDScriptLanguage::finish, чтение s->self() из script_list.

Сильная рабочая гипотеза: engine-side use-after-free списка GDScript при разрыве зависимостей. Не говорить, что causal chain уже полностью доказан: heap/free provenance и конкретный скрипт отсутствуют. Дамп6456 не привязан к probe22:53. Export EXE — другой бинарник, соответствующий offset к нему НЕ применять.

Совпадающий upstream:
https://github.com/godotengine/godot/issues/117975
https://github.com/godotengine/godot/pull/117991
Merge commit 0dd6299f7146362d36b130ac1dc42406cfb3ede6.
В конец GDScript::clear() добавляются:

    #ifdef TOOLS_ENABLED
        base_cache = Ref<GDScript>();
    #endif
        base = Ref<GDScript>();

Это освобождает base-зависимость до s=s->next(); иначе разрушение текущего Ref может освободить уже выбранный следующий узел.
В сохранённых исходниках точного a13da4feb и тега4.7.1-stable этот фикс ОТСУТСТВУЕТ. Подтверди applicability, не обещай результат только по похожему issue. Production scripts в основном extends native types; конкретный base/base_cache trigger в наших crash suites пока не найден.

### План проверки/исправления

1. Сохрани inventory/hash текущих изменённых файлов и точные engine/template/test hashes. Проверь только относящиеся к crash path зависимости, self-list lifetime и compiled clear при необходимости; не сканируй весь проект без вопроса.
2. Выбери самый дешёвый контролируемый путь: минимальное scratch reproduction с тем же shutdown signature и frozen old-engine control; затем вариант с проверенным upstream fix. Не запускай прежний suite снова без нового наблюдения/инструмента.
3. Перед исполнением зафиксируй гипотезу, один изменяемый фактор, команды и лимит. Ориентир ≤5 запусков на arm, последовательных; если control не падает, это INCONCLUSIVE, а не fix. Не увеличивай число запусков самовольно и не повторяй до зелёного. Предпочти детерминированный repro/diagnostic evidence статистическому угадыванию.
4. Engine update/backport возможен ТОЛЬКО после проверки наличия нужного diff и совместимости. Если нужны новый engine, компиляция, symbols или templates — сначала один конкретный approval request: источник/размер/место/цель/системные изменения. Не собирать движок много часов и не скачивать гигабайты без разрешения. Не подменять установленный Godot; отдельный versioned engine path, rollback сохранён. Debug/release export templates должны соответствовать выбранному engine.
5. Если доказана project-side причина — surgical patch + regression. Не массово убирать type hints/preloads/cycles, не отключать звук, не добавлять arbitrary sleeps/awaits и не подавлять exit errors. Если подтверждён engine bug, честно отделить engine patch от project workaround.
6. Cdb сам не даёт Godot symbols; произвольный PDB той же версии не гарантирует соответствие. PE stripped, CodeView отсутствует. SDK/ProcDump/WER/registry нужны только под конкретный диагностический вопрос и approval, не как формальный обязательный первый шаг.
7. Если нельзя доказать и проверить fix в доступных рамках, заверши bounded diagnostic report с точным blocker; не объявляй engine UAF устранённым. Продолжи независимые задачи ниже.

## B. Shutdown отдельно

16 suites resources-still-in-use, StringName/PagedAllocator и 7 Texture RID warnings не считать одним доказанным дефектом. Texture RID warnings были и при windowed exit0, не только timeout.
Сравни graceful quit и forced termination на одинаковом artifact. По одному representative verbose error-bearing suite и normal packaged exit выясни resource types/ownership; исправляй лишь подтверждённый дефект. Сохрани raw errors, не ослабляй классификатор и не подменяй process exit.

## C. Исправить недостоверные claims и закрыть конкретный остаток Q2–Q6

1. **Q5 wrong-word НЕ пройден указанным логом.** q5/wrong_result.json запускает commit_input_route_capture.gd, который вводит WATER. Его17PASS — normal WATER route. Исправь runs_summary/HANDOVER/RESULT. Для actual wrong full-night используй существующий first_night_playthrough.gd -- --capture --wrong (WAITER), затем проверь неправильный текст/facts/dawn без correctness oracle. --lapsed и watcher/FILE AS COPIED — по действительному назначению существующих script branches, не угадывай их mapping. Missing call/wrong route/incomplete copy сопоставь с актуальными tests. Один нужный run на непокрытую ветку, не дублировать уже актуальное evidence.
2. **Q2:** закрыть недостающие1080p и нужные presentation modes/text scales конкретными ракурсами live/archive/viewer/card/route/options/guidance; no clipping/footer overlaps, I/L C/G R/A/digits. Существующие кадры только720p. q2/captures пуст, UI images в shared mechanics_2026-10-10/ui_captures, writing/production в .dream-loop: скопируй нужные текущие изображения в уникальный evidence dir или запиши точный path/hash/dimensions/index. Не выдавай автоматические PASS за просмотр. Не перегенерировать формы/SVG и не применять0.90 повторно без дефекта.
3. **Q3:** приведи q3/provenance_table.txt к одной актуальной строке на asset. Сейчас там beta=generator и beta=UNKNOWN legacy, дубли legacy, lever_stop path-not-found рядом с corrected-path. Проверить реальные paths/bindings/SHA/license; это документальный audit, не повод регенерировать все WAV. Human headphones/speakers listening остаётся OPEN с коротким checklist.
4. **Perf:** старые300frames с disabled director и seated camera — synthetic smoke, не full-night performance. Короткий real-time sample при live writing/document/transition с hardware/resolution/mode/warmup/duration/p95/p99; не MovieMaker и не только пустая сцена. Без превращения в масштабный benchmark.
5. **Q6:** clean extract финального ZIP в новый каталог, вне repo cwd. Menu → Begin Watch → office → pause/resume → restart/menu → normal Quit. Сохрани actions, exe/pck/settings hashes и raw child exit. Предыдущий45s boot закончился terminate exit1, не graceful exit. Если native UI tools недоступны — точный5-minute checklist владельцу; не говорить, что любые внешние inputs требуют изменений пакета. Не патчить shipping PCK для удобства проверки.
6. beta_review_finish/RESULT.md отсутствует, хотя HANDOVER ссылается на него. Запиши честный сводный RESULT с old claims corrected и ссылкой на новый crash review. Не выдавай собственную реконструкцию за исходный отчёт прежнего агента. Owner художественная приёмка/human listening/playtest не выполнены агентом и не закрываются фиктивно.

## D. Финальная приёмка

После стабилизации один full mechanics regression +lint: baseline не ниже86suites/2747assertions,0FAIL,0SCRIPT ERROR. Shutdown/native failures сохранять отдельно; suite count не снижать. Python focused tests только затронутых tools.
Если production/engine/template inputs изменились — один свежий versioned export+ZIP после всех изменений, actual PCK payload/class/exclusion audit, CRC/runtime manifest/BUILD_ID/hashes, standalone route именно этой версии. Старый p12 не называть исправленным. Templates1.28GB уже есть — не скачивать их повторно без смены версии и необходимости.

Не нарушать truth→perception→transcript, objective MARK/GAP tape, contact-driven ink/audio, one glyph/tick, route authority, WorldState/KnowledgeState, Morse fairness. Не менять pacing/deadlines30/20/45, ten-column sheet, walking/Morse speed, сюжет/ночи/страхи/арт сверх подтверждённого дефекта.

Выход: короткий отчёт «подтверждено / исправлено / не проверено / blocker», причины с evidence и уровнем уверенности, exact changed paths, test commands/results, build ID/hashes. Никакого ready-to-send при открытом native blocker без отдельного явного решения владельца о диагностической beta-передаче.
