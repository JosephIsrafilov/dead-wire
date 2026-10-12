# DEAD WIRE — независимая проверка краша и остатка Q1–Q6

Дата: 2026-10-12. Статус: **NOT READY TO SEND**.
Без сабагентов, без запуска Godot, без изменения production/tests/export/settings, без commit/push/reset.

## 1. Что установлено по крашу

Проверены все три существующих Godot minidump: PID 16920 (08.10), 16504 (09.10), 6456 (11.10).
Все три дают read access violation 0xC0000005 в одном RVA **0x547AF6**.
Timestamp PE и SizeOfImage в дампах совпадают с локальным non-console EXE; это совместимость образа, НЕ криптографическое доказательство полного совпадения всех байтов дампа с нынешним EXE.
SHA256 нынешнего EXE и каждого дампа сохранены в offline_dump_analysis.json. Не путать этот EXE с 198 KB console-wrapper и экспортным runtime EXE.

Точная инструкция из локального EXE:

    00547af6  4d8b6508  mov r12, qword ptr [r13 + 8]

Во всех трёх exception records fault address = r13 + 8. r13 не NULL: это недействительный адрес узла, а не NULL-доступ к аудиоплееру.
В двух контекстах r9 = 0xFEEEFEEEFEEEFEEE (характерный Windows freed-memory marker). Это поддерживающий признак, НЕ самостоятельное доказательство, какой объект и где был освобождён.

По AMD64 .pdata/.xdata восстановлена ограниченная unsymbolized цепочка; return addresses проверены на call instructions. Во всех дампах одинаковые первые кадры:

    Godot +0x547AF6 (function starts +0x547AA0)
      ← Godot +0x3E39378 (function starts +0x3E39240; virtual finish call)
      ← Godot +0x5FFB1 (function starts +0x5FCC0; Main::cleanup strings)
      ← Godot +0x5255F ... Windows entry

Это НЕ raw stack scan, но и НЕ symbolized debugger stack. Самодельный bounded unwinder останавливается при выходе из поддержанных engine frames; сырой скан сохранён отдельно и не выдан за call stack.

Дизассемблирование и публичные исходники exact commit a13da4feb позволяют с высокой уверенностью идентифицировать:
**Main::cleanup → ScriptServer::finish_languages → GDScriptLanguage::finish**.
Функция +0x547AA0 совпадает структурно: finishing flag → GDScriptCache::clear → script_list → очистка argument/return/member script references → scr->clear → next → destructor Ref → list cleanup.
Инструкция падения соответствует получению s->self() из script_list (gdscript.cpp:2247 в сохранённом исходнике).

### Наиболее обоснованная причина

Недействительный элемент script_list во время очистки ссылок GDScript; **engine-side use-after-free при shutdown — сильная рабочая гипотеза**. Данные существенно сильнее прежнего предположения про sounder/tweens.
Однако дампы не содержат достаточной heap/provenance информации, чтобы назвать конкретный освобождающий destructor или скрипт проекта. Установлен site/subsystem, НЕ подтверждён весь causal chain.
Связь дампа 6456 с probe 22:53 не установлена (дамп 22:12). Не переносить этот диагноз автоматически на каждый исторический native exit или на экспортный runtime.

### Найден upstream-аналог

- https://github.com/godotengine/godot/issues/117975 — Rare heap-use-after-free when clearing dependencies between scripts during exit.
- https://github.com/godotengine/godot/pull/117991 — GDScript: Clear base script in GDScript::clear.
- API подтверждает merged=true, commit 0dd6299f7146362d36b130ac1dc42406cfb3ede6.
- Diff добавляет в конец GDScript::clear освобождение base_cache (TOOLS_ENABLED) и base ПЕРЕД переходом к следующему элементу списка.
- Исходники тега 4.7.1-stable и exact a13da4feb byte-identical; этих строк в clear НЕТ. Не делать вывод о составе binary только по номеру версии; compiled clear (+0x5474D0) также сохранён в disassembly.txt; исходниковый diff — основание выбора кандидата, но causal applicability всё ещё требует контрольной проверки.

Почему подходит: переход s = s->next() делается до разрушения локального Ref<GDScript>; destructor может освободить следующий скрипт, и следующая итерация читает уже мёртвый узел. Это описанный upstream механизм и совпадающее место ошибки.
Почему ещё не готовый fix: конкретный base/base_cache trigger в DEAD WIRE не доказан. В scripts/ увидены преимущественно native bases; inner QuietOffice extends M1OfficeController имеется в отдельном foley test, но его загрузка в crash probe не подтверждена. Иные оставшиеся зависимости могут дать тот же site. Нельзя обещать, что именно эти 5 строк устранят наши падения без контрольной проверки.

### Вывод про инструменты

Cdb отсутствует, PDB/CodeView records в текущем PE отсутствуют, COFF symbols stripped. Запрос «установить cdb ИЛИ скачать любой PDB 4.7.1» технически недостаточен: нужна проверенная совместимость symbols/build; cdb сам символов Godot не создаёт. ProcDump только снимает дамп.
Прежнее утверждение «без установки debugger невозможно сузить причину» опровергнуто этой офлайн-проверкой. Системная установка сейчас НЕ обязательный первый шаг. При необходимости нужен один конкретный запрос с размером/назначением/изменениями, не blanket permission.

## 2. Что проверено независимо из последнего отчёта

- 21 packager tests: OK (0.074 s; запуск без Godot).
- p12 PCK: 546 entries; payload MD5, exclusions и class remap targets проходят текущий проверяющий код.
- ZIP: 13 файлов, CRC clean, EXE/PCK byte-identical p12; spoiler brief отсутствует.
- ZIP SHA256 ff1eda2fe816aff1d5e66baa625610eceaba2eea8c017fc5fa02c1890a76efa9.
- Build candidate dead-wire-windows-beta-f82939d9995e-2ed1b969852f.
- Сохранённый final_regression/summary.json: 86/86, 2747 assertions, 16 suites resources-still-in-use. Это проверка сохранённых артефактов, не новый engine run.

## 3. Найденные пробелы / ошибки отчёта

### Q4 — открыт
Native crash не исправлен. Exit-time resources/StringName/PagedAllocator/RID не root-caused и НЕ доказанно имеют одну причину.
В q4/shutdown_disposition.txt категоризация «cleanup ordering issue» сильнее имеющихся доказательств.
7 Texture RID warnings есть и в оконных capture runs с exit0, не только после принудительного завершения standalone. Не списывать всё на timeout.

### Q5 — заявленный wrong-word не подтверждён
q5/wrong_result.json запускает commit_input_route_capture.gd БЕЗ branch args.
Сам скрипт tools/commit_input_route_capture.gd:91 вводит WATER, log пишет WATER world fact recorded.
**17 PASS относятся к NORMAL WATER input route, НЕ к wrong valid word.**
first_night_playthrough.gd поддерживает --wrong (WAITER), --lapsed и --watcher; q5/night_result.json имеет только --capture, то есть default normal.
UI screenshot generator вводил WAITER, но это не полный оконный wrong-night run до dawn.
Нужно проверить актуальные wrong/lapse/FILE AS COPIED ветки имеющимися путями; не считать прошлые прогоны другой версии свежими.

### Q2 — частично
Сохранённые captures/commands относятся к 1280x720; 1080p, вся нужная матрица presentation modes/text scales и дополнительные чтения не подтверждены.
q2/captures пуст; UI images лежат в shared docs/research/mechanics_2026-10-10/ui_captures, writing/production — .dream-loop. Нужен индекс точных файлов/hashes/dimensions или копии в уникальный evidence dir, чтобы следующий capture не перезаписал доказательства.
Новый художественный/визуальный verdict в этой проверке НЕ выполнялся. Не объявлять все glyph/mode combinations accepted.

### Q3 — документы ещё нуждаются в уборке
q3/provenance_table.txt содержит взаимоисключающие beta rows: generate_beta_footstep.py и UNKNOWN legacy, дубли legacy; lever_stop сначала path not found, затем corrected path.
Нужна одна актуальная строка на реально используемый asset с точным путём/хешем/binding/license. Listening на headphones/speakers открыт и не заменяется lint/tests.

### Q5 perf — только ограниченный smoke
120 frames warmup +300 measured frames, seated office, live director DISABLED. Значения 5.2/5.9/6.3 ms не доказывают performance всей ночи при writing/viewer/pause/scene transitions и не доказывают 1080p. Нужен короткий реальный gameplay sample с длительностью/сценарием, если этот gate остаётся обязательным.

### Q6 — не завершён
45 s alive, затем terminate с raw exit 1. Это не graceful quit и не пакетный gameplay route.
Полный маршрут clean extract → menu → Begin Watch → office → pause/resume → restart/menu → Quit остаётся открыт. При отсутствии native UI automation в этой сессии — конкретный ручной checklist, не заявление о принципиальной невозможности автоматизации без патча пакета.

### Документация
В beta_review_finish/ отсутствует RESULT.md, хотя HANDOVER ссылается на него. Не восстанавливать выдуманный успех; записать отчёт с указанными ограничениями.

## 4. Минимальный следующий порядок

1. Подтвердить engine cleanup UAF trigger минимальным scratch reproduction или совместимым diagnostic build; frozen control, один фактор, ограниченный бюджет запусков. Не повторять прежний probe без новой информации.
2. Если применимость #117991 доказана — отдельный patched engine + согласованные debug/release export templates либо проверенная официальная версия с нужным fix. Не подменять системный/пользовательский Godot и не пересобирать всё без разрешения.
3. Если это project-side lifecycle/dependency issue — только доказанный minimal patch+regression. Не убирать type hints/preloads/audio пачкой и не добавлять arbitrary waits как «fix».
4. Разобрать graceful shutdown отдельно; закрыть пакетный UI/quit маршрут.
5. Wrong/lapse/file-as-copied оконные branches, недостающая visual matrix, реалистичный perf sample.
6. Устранить противоречия provenance/RESULT, один final full+lint после стабилизации, один новый экспорт/ZIP после всех production/engine changes. Не рассылать старый p12 как исправленный.
7. Owner art approval + human listening; sound designer beta feedback не выдумывать. Можно отправить диагностическую beta только по явному решению владельца, не переименовывая её в ready.

## 5. Артефакты и затраты этой проверки

Все новые файлы находятся только в docs/research/first_night_2026-10-12_crash_review/.
Исходные дампы не копировались и никуда не загружались.
Скачаны два публичных исходника Godot, exact-commit копия, upstream API evidence и Capstone 5.0.6 wheel 1.3 MB в local_deps; глобальные Python/system packages не менялись. local_deps исключён локальным .gitignore.
inspect_offline.py — ограниченный одноразовый read-only анализатор для этих дампов, не универсальный debugger; disassemble_site.py и audit_package.py сохраняют детали проверки.
Полный движковый regression, новые crash probes, установка SDK/WER/registry и изменения игры не выполнялись.
