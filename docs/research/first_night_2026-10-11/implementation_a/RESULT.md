# Первая ночь — этап A / R01, 2026-10-11

## Область выполненного

Полная спецификация сохранена в docs/plans/2026-10-11_FIRST_NIGHT_FINISH.md. Этот checkpoint закрывает восстановление Rule 44, а не весь план первой ночи.

- Исходный dirty inventory: dirty_before.txt; tracked_before.patch сохраняет существовавший diff. Не откатывались авторские изменения, staging/commit/push не выполнялись.
- Второй сценарий: FREIGHT 71 EAST сохранён в трёх отдельных слоях; 13 reveal cues. Идентификаторы, факты, expected HOLD, внимание и deadlines сохранены.
- Ledger: вымышленный Black Creek company order; HOLD до division clearance; EAST request не является разрешением; для Freight 71 clearance нет.
- Обновлены только scenario-pinned assertions и комментарий integration. Независимые encoder/compiler golden fixtures не менялись.
- Rule44 test вырос с 5 до 12 проверок; UID создан Godot import.

Основание → ожидаемый эффект → проверка: правило должно требовать профессионального сопоставления request с ledger, а не буквального исполнения HOLD в телеграмме. Проверены resource validation, полномочия и последствия. Понимание новичками ещё не проверено.

## Фактическая проверка

| Проверка | Результат |
|---|---|
| RED / red/ | 3 PASS, 2 FAIL, exit 1: ledger и validation; без parse/runtime errors |
| Initial GREEN / green/ | 5 PASS, exit 0 |
| Full / full_01/summary.json | 79 suites, 2596 assertions, 0 failed; включает итоговые 12 Rule44 assertions |
| Production lint / lint.log | exit 0, no problems |
| Godot import | exit 0 |
| Boot / boot.log | exit 0; 10 ObjectDB leaks, ERROR 2 resources still in use |
| Windowed production / production_route.log | exit 0, 58 PASS, 0 failures, 6 screenshots; 7 Texture RID warning |
| Windowed wrong amendment / night_wrong.log | exit 0, 61 PASS, 0 failures; 7 Texture RID warning |

Все engine runs последовательны и через with_preserved_settings.py. Полные тестовые логи сохранены. Full regression: все ERROR в 17 suites — resources still in use at exit; SCRIPT/parse errors отсутствуют. Это не error-free acceptance.

Production route использует настоящий ввод/ходьбу; night_wrong использует teleports и ускоренные таймеры, не проверяет человеческий темп. Два production кадра сохранены в production_frames/. Просмотр p4_board_standing через image tool не дал отображаемого изображения в этой сессии; визуальная приёмка не заявляется.

## Crash-контроль — отдельно от gameplay

Прочитаны предшествующие stability_followup REPORT/TEARDOWN_AUDIT/controlled_teardown. Исторический native 0xC0000005 остаётся подтверждённым, причина не установлена.

Один свежий исходный shift_director с --verbose / headless / Dummy напечатал 132 PASS и PASSED banner, после чего wrapper вернул -1 (shift_control_verbose_exit.txt). Wrapper возвращает subprocess returncode через SystemExit; точный высокий Windows child exit не сохранён отдельным JSON, поэтому новый -1 НЕ объявляется доказанным 0xC0000005. Стек в verbose логе отсутствует. SHA256 исходного теста: 93102bcca9189bc55df33596377a52c5c7642dcbc185e5cd7a32a872d357042b. Тест не изменён.

Никаких повторов до зелёного, teardown patch, driver switch или WER/registry изменений. Read-only просмотр CrashDumps запрещён sandbox; наличие нового dump не установлено. Следующая диагностика: harness должен записать raw child returncode/hex до SystemExit; затем один контролируемый verbose/dump эксперимент, без изменения теста. Настройка WER — только отдельное разрешение.

## Осталось

- Этап A: точный crash exit/stack и причины shutdown ошибок; normal/as-copied/lapse production ветки на новом дереве.
- Этап B: guidance resources/controller/overlay + options/F1/anti-spoiler; reference AL; ограниченный responsiveness baseline/patch.
- Ранний тест двух людей — НЕ ПРОВЕДЁН.
- Этап C: авторские векторные глифы/offline bitmap builder, font role separation, contact/layout checks, sound replacement fields/mix.
- Этап D: Windows export/package hygiene, реальное performance измерение и слепой тест пяти новых людей — НЕ ПРОВЕДЕНЫ.
- Этап E: подтверждённая итерация, sound handoff, owner review. Compact pacing не включён.

Первую ночь не считать законченной, build для звукаря не создан. Никаких человеческих/художественных результатов не выдумано.
