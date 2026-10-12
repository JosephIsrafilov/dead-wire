# RESULT — beta review finish (2026-10-12, crash-review fix session)

**Статус: NOT READY TO SEND.** Открыт native crash 0xC0000005 (см. ниже).

Автор: fix-сессия по `docs/research/first_night_2026-10-12_crash_review/AGENT_FIX_PROMPT.md`.
Этот файл — отчёт текущей сессии. Он исправляет два недостоверных утверждения прежнего отчёта
(beta_review_finish, сессия до review): wrong-word ветка тогда НЕ была пройдена (q5/wrong_result.json
гонял commit_input_route_capture.gd с WATER — это normal-ветка), и standalone 45-секундный boot
не был игровым маршрутом. Оба пункта ниже закрыты заново честно.

## A. Crash: подтверждено, исправлено — нет, блокер остаётся

- **Подтверждена применимость upstream #117991 на уровне кода и бинарника** (высокая уверенность):
  PR merged (0dd6299f7146362d36b130ac1dc42406cfb3ede6, milestone 4.8); в исходниках нашего
  4.7.1.stable.official.a13da4feb (`gdscript_exact_commit.cpp`) строк base/base_cache в
  `GDScript::clear()` НЕТ; в бинарнике 323f9c4cc5db674e цикл `GDScriptLanguage::finish` виден
  (r13 = script_list, crash на `mov r12,[r13+8]` = s->self(), next = `[r13+0x10]`) — тот же site,
  что во всех трёх дампов. Details: `crash_review/fix_attempt/applicability_verdict.md`.
- **Контрольный repro**: официальный MRP из issue #117975 на нашем движке НЕ падает (exit 0,
  run2, frozen control). Это делает вопрос INCONCLUSIVE, а не «не воспроизводится вообще»:
  upstream сам называет триггер редким/heap-зависимым. По этому же правилу чистый MRP-прогон
  НЕ является доказательством, что #117991 исправит наш краш.
- **Проектный фикс НЕ применялся**: конкретный `base`-триггер в наших suites не идентифицирован;
  запрещено массово убирать type hints/preloads или добавлять waits. Engine-side фикс требует
  patched engine — см. `crash_review/fix_attempt/approval_request.md` (Option A: official 4.8
  preview engine + matching templates ~1.4 GB, Option B: local build 4.7.1 + 5-line patch).
  НИЧЕГО не скачивалось и не устанавливалось без разрешения.
- **Живое подтверждение краша в этой сессии**: final regression 85/86 —
  `tests/telegraph/rule44_content_test.gd` вышел с raw exit 3221225477 (0xC0000005) после
  12/12 PASS («Scenario identity is preserved»). Лог сохранён
  (`beta_review_finish/final_regression_2/`), повтор не делался. Signature совпадает с
  историческим probe: green assertions, потом teardown-краш. Crash остаётся ОТКРЫТЫМ.

## B. Shutdown (отдельно от краша)

- Verbose-прогон error-bearing suite (atmosphere_test, 86 PASS, exit 0) показал состав:
  AudioStreamWAV ×3 + AudioStreamPlaybackWAV ×3 (Refcount 1) + orphan StringName «Ambience» —
  test-teardown ownership аудио, не дефект игры. Detail: `beta_review_finish/q4b/shutdown_b_verdict.md`.
- **Graceful quit пакета p12 подтверждён**: WM_CLOSE окну игры → raw exit 0x00000000,
  0 SCRIPT/parse/load ошибок (`q4b/graceful/`). Классификатор не ослаблялся, raw errors сохранены.
- 7 Texture RID warnings присутствуют и в windowed exit-0 прогонах — отдельный класс,
  к аудио-лизам не привязан, не «доказанно один дефект».

## C. Исправленные claims и закрытые остатки

1. **Q5 wrong-word — теперь реально пройден**: `first_night_playthrough.gd -- --capture --wrong`
   (WAITER): 78 PASS / 0 FAIL, exit 0, скриншоты в `.dream-loop/playthrough_wrong/`, копии+
   индекс в `q2/captures_index/`. Прежний 17-PASS run признан normal-веткой и помечен как таковой.
2. **Q2 captures**: 29 текущих изображений скопированы в уникальный evidence dir
   `beta_review_finish/q2/captures_index/` с INDEX.txt (размер+sha16). Дополнительно снята
   1080p матрица UI (4 кадра, 1920x1061, `q2/captures_1080/` с INDEX).
3. **Q3 provenance**: таблица переписана — одна строка на asset, без противоречивых дублей
   (старая сохранена как `provenance_table.superseded_2026-10-12.txt`). Human listening — OPEN.
4. **Perf**: real-time sample с live director + WATER transmission + viewer transition:
   p50 5.13 / p95 5.99 / p99 8.41 мс @720p (300 frames), viewer p95 5.48
   (`q5/perf_live/`). Не full-night benchmark — отмечено.
5. **Q6 standalone**: graceful quit доказан (exit 0). Полный игровой UI-маршрут в пакете —
   честный 5-минутный checklist владельцу (`q6/standalone_manual_checklist.txt`); автоматизация
   потребовала бы патча shipping-пакета — не делалось.
6. **beta_review_finish/RESULT.md — этот файл** (создан; раньше отсутствовал при ссылке из HANDOVER).

## D. Финальная приёмка

- Full regression (final_regression_2): **86 suites, 85 PASS, 2747 assertions, 0 FAIL lines,
  0 SCRIPT ERROR, lint clean**. Suite count не снижался (86=86). One suite = native 0xC0000005
  (см. A). error_bearing 20 (было 16) — вариативность teardown-класса, raw logs сохранены.
- Новый export НЕ делался: production-кода игра не менялась (изменения — только tools/docs),
  шаблоны 4.7.1 совместимы, p12 остаётся последним валидным артефактом, но **не называется
  исправленным от краша**.

## Build artifact (unchanged from review)

- Build ID `dead-wire-windows-beta-f82939d9995e-2ed1b969852f`
- ZIP `ff1eda2fe816aff1d5e66baa625610eceaba2eea8c017fc5fa02c1890a76efa9`
- EXE `6fb906a8a6797af9…`, PCK `c7e398705cbf3569…`; 13 files; CRC clean; no spoiler brief;
  PCK 546 entries verified; legacy footstep absent.

## Открытые пункты (не закрыты этой сессией)

1. Native crash — блокер; ждать решения владельца по approval_request.md (Option A/B).
2. Owner artistic approval + human listening + human playtest — не выполнялись агентом.
3. 1080p/720p художественная приёмка владельцем; manual 5-min package route.
4. Full-night performance на «реальной» сессии (эталонный benchmark) — по необходимости.
