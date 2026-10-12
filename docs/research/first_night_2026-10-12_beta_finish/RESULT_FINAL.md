# Beta finish — итоговый отчёт (2026-10-12, сессия 2)

**Статус: НЕ ГОТОВО к отправке.** Блокер P4 (native crash 0xC0000005 / exit-time shutdown) открыт.

## Изменённые файлы (этой сессией)
- `assets/fonts/elias_working/glyph_*.svg` — горизонтальное сжатие x-координат на 0.90 вокруг центра; высоты не менялись. Регенерация `tools/build_elias_font.py`. Резерв: `font_before/`.
- `tools/package_windows_beta.py` — исключения `.git/.godot/.zip/.bak/.dmp`; SPOILER-бриф не пакуется; проверка EXE+PCK; вывод не внутри source и source не корень; build ID от хешей EXE/PCK; проверка class_name-скриптов в PCK.
- `tools/package_windows_beta_test.py` — 10 тестов (было 4), падающие RED до правок.
- `export_presets.cfg` — Windows Beta: `export_filter` scenes→all_resources; exclude + `sites/*,.dream-loop/*`. Резерв: `preserve/export_presets.cfg.before`. ВНИМАНИЕ: в рабочей копии уже был незакоммиченный `[preset.1]` (до моих правок) — сохранён.
- `docs/beta/SOUND_HANDOFF_SPOILERS.md` — удалено делегирование; помечено как не входящее в ZIP.
- `docs/beta/THIRD_PARTY_NOTICES.md` — добавлены Noto, Old Standard, Elias, временные звуки.
- `scripts/ui/document_viewer.gd` — (из сессии 1) header/константы.

## Фактические проверки
- Ширина ряда «TRAIN 17 CLEAR EAST»: 0.1909 м → 0.1761 м (лимит 0.18 м). `player_feedback_test` должен пройти (подтверждено probe run3).
- Вертикальные метрики (height/yoffset) не изменены — проверено скриптом.
- `verify_mechanics.py` полный (после правок шрифта и packager): **86/86 suites, 2747 assertions, 0 failed**; 18 suites с shutdown-сообщениями «resources still in use» (не assertion).
- `gdlint scripts/`: без замечаний.
- `unittest tools.package_windows_beta_test`: 10 OK.
- `tests/python/test_elias_font_builder.py` — см. `font_01/builder_test.log`.
- Экспорт p10 (`builds/windows-beta/export_2026-10-12_p10`): exit 0; PCK 618 путей, запрещённых нет; все class_name-скрипты в PCK.
- ZIP `builds/windows-beta/dead-wire-windows-beta-f82939d9995e-bbc2b028444d.zip`: 13 файлов, без спойлера.
- P6 standalone (распакованный ZIP, 40 с): 0 SCRIPT ERROR, 0 parse/load; exit 124 (таймаут, не падение).

## Найдено и исправлено в сборке
- Экспорт `export_filter=scenes` не включал 19 class_name-скриптов (например `GameSettings`) → standalone падал парсингом `main_menu.gd`. Исправлено (p10 проверен).

## Незакрытые ограничения
- **P4 crash (0xC0000005)**: не воспроизведён в одном прогоне, но причина не найдена. Dump 6456 без symbols/stack, привязка к probe не доказана. Для symbolized stack нужен cdb/procdump или PDB — требует отдельного разрешения (не ставил). Не объявлено исправленным.
- **Exit-time ошибки** (RID leak, Unreferenced StringName, PagedAllocator) — присутствуют в standalone и тестах; не разобраны по P4.
- **Шрифт**: горизонтальная проверка только по измерению движком; визуальная приёмка (скриншоты) не выполнялась.
- **P2 (визуальная проверка, формы, кадры)** и **P3 listening QA** не выполнены — требуют человека.
- **P5** (production/night-water прогоны, perf) не выполнены.
- Аудио: unregistered Foley (paper_turn, route_lever, door_latch) — требуется owner provenance review.
- Старые `builds/windows-beta/*.exe/.pck` (23:08) устарели, не отдавать.
