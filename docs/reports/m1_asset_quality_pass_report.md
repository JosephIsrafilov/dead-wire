# DEAD WIRE M1 — Asset Quality Pass V0–V7 + F3 остатки: итоговый отчёт

> **⚠️ Исторический документ (сессия до H1–H9).** Актуальный статус —
> [`docs/reports/m1_h1_h9_completion_report.md`](m1_h1_h9_completion_report.md):
> часы, production-проверки, подача листа, посадка/вставание, retained route,
> атмосфера/buses, ledger, читаемость board (vision-подтверждена) закрыты;
> regression 34 suites / 1637 assertions / 0 failed. Всё ниже — состояние на
> момент этой сессии, включая уже исправенные впоследствии пункты (например,
> «подача листа отсутствует», «NIGHT ENTRIES не реализован» — устарело).

**Дата:** 2026-09-19 (финальная сессия).
**База:** HEAD `70a8967` + uncommitted working tree (F1/F2 + corrections R1–R9 + этот pass).
**Документы-задания:** `docs/art/m1_asset_quality_pass.md` (V0–V7), `docs/m1_living_shift_plan.md` (F3-остатки в рамках разрешения), `docs/reports/m1_living_shift_f1_f2_review.md`.
**Честная рамка:** визуальную оценку кадров и прослушивание WAV модель сделать не может (нет image/audio ввода); все такие пункты явно помечены `pending human`. Инженерные проверки — реальные прогоны этого build.

---

## 1. Что изменилось для игрока

### Рука (V1)
- Старая «метровая палка» (sleeve 0.39 м видимой длины, кисть 7.7 см) заменена авторской анатомией: предплечье 0.28 м с манжетой, полная кисть ~0.15 м в хвате пера (ладонь + сложенные пальцы + противопоставленный большой палец).
- Движение разбито: `wrist_carry_fraction` — запястье несёт 35% хода, кисть 65%; предплечье остаётся лежать. Рука больше не ездит единым вектором.
- Suspend/resume сохраняют индекс глифа и позу; reset возвращает суставы в authored-позиции.

### Окно (V2)
- Окно перенесено с «за спиной» (yaw 146°) на северо-запад: **yaw ≈ 88° от рабочего взгляда, 1.76 м от кресла** — боковое зрение, разделённое внимание по плану.
- Горизонтальный переплёт убран (2 высоких стекла вместо 4 секций) — голова/плечи фигуры не дробятся.
- Ночной фон за окном поднят до холодного лунного (×1.9) — тёмный силуэт читается на светлом фоне.

### Routing board (V3)
- Панель сужена с 1.56 м до 0.72 м; золотые 3D-рельсы заменены **плоской чернильной схемой пути** (главная линия, siding, стрелка, точки станций).
- Печатная карточка `EAST DIVISION — TRAIN ORDERS` в тонкой рамке, метки `◄ CLEAR EAST` / `HOLD ►` у физических упоров.
- Чугунный рычаг на оси с двумя упорами, деревянный grip; латунный **механический указатель** со стрелкой.
- Бросок рычага — только после подтверждения session (`routing_resolved`): accepted → поворот к упору + Kenney impact в момент контакта; **NO ORDER/lapse рычаг не трогает**.

### Документы (V4)
- Duty roster: 0.68×0.58 → **0.24×0.32 м** (реальный лист), заголовок NIGHT REGISTER.
- Dawn evidence: 0.74×0.64 → 0.25×0.33 лист на доске **на двух плоских штифтах**.
- Interaction-области сохранены (большой trigger ≠ большой mesh).
- Все `====`/`----` сепараторы во всех документах → тонкие типографские линии.

### Мебель (V5) — реальные CC0-модели в runtime
- Стул: Poly Haven painted_wooden_chair_01 (724 tris), farmhouse-white приглушён; **OperatorSeat anchors, ChairSolid, sit_completed — нетронуты** (CSG-визуал скрыт).
- Шкаф: painted_wooden_cabinet_02 (966 tris), равномерно 0.72 (2.57→1.85 м), заменяет визуал StorageCabinet, collision прежний.
- Книги: 4 тома из encyclopedia_set_01 (67k tris набора — в сцене только выбранные, остальное освобождается скриптом).
- Столик wooden_table_02 (196 tris) — служебная поверхность у двери.

### Звук (V6)
- Рычаг: Kenney impactWood_heavy в момент упора (не при нажатии клавиши).
- Штамповка: Kenney impactPlate_heavy; посадка/вставание: Kenney impactWood_medium.
- Бумага (viewer open/close): Luckius paper_sound (OGA CC0).
- Wind-bed переанкерен на новое окно.

### F3-остатки в рамках pass
- Accepted-lever + механический указатель (см. V3) — выполнено.
- Retained sheets / journal / ledger статусы — уже были (F2), подтверждены regression.
- **Не сделано и не заявлено:** анимация подачи нового листа (лист лежит, вход — только рука), новая body-анимация посадки (плавный tween прежний), ledger NIGHT ENTRIES полировка — осознанно оставлено: это отдельный F3+ объём, не прикрытый зелёными тестами.

## 2. Закрытые стадии и критерии (§11)

| Этап | Статус | Доказательство |
|---|---|---|
| V0 baseline + acquisition | ✅ | baseline 34/1536/0; скачано A02–A06, A08, S01, S03 (+A07 уже был); SHA-256 manifest'ы |
| V1 рука | ✅ инженерно / ⏳ визуально | paper tests 45, night_recovery (nib-миллиметр, топология) зелёные; зрительная оценка — человеку |
| V2 комната/окно | ✅ инженерно / ⏳ визуально | spatial_metrics (LoS через проём), window_evidence 10/10 (появление при отведённом взгляде, поворот с геймплейных позиций, defers при watched, bounded fallback) |
| V3 board | ✅ | routing_board tests, integration (accepted/echo/deadline), рычаг по `routing_resolved` |
| V4 документы | ✅ инженерно / ⏳ визуально | пропорции в tscn; сепараторы; presentation_structure |
| V5 мебель | ✅ | spatial_metrics (все пропы в границах, пути), smoke; PH-модели реально инстанцированы |
| V6 звук | ✅ инженерно / ⏳ на слух | foley-привязки, ambience_test 50; **прослушивание — человеку** |
| V7 regression+evidence | ✅ | см. §4 |

## 3. Реально используемые ассеты (полный manifest — `docs/third_party_assets.md`)

Runtime-instanced: A02 (table), A03 (cabinet), A04 (chair), A05 (4 тома), A07 (lamp, ранее), S01 (lever/stamp/chair), S03 (paper).
Downloaded-not-wired: A08 Paper001 (текстура бумаги — бумага пока на прежнем paper_log.tres), S02 не качался (142 MB, не понадобился), S04–S06/M01 — Freesound login, fallback по плану.
Blocked: A01 (itch.io требует payment method даже для $0) → рука сделана авторски, что прямо разрешено планом V1 п.11.

## 4. Результаты проверок последнего build (не скопированные)

- **Fresh full regression:** `tools/run_all_tests.sh` — **34 suites / 1536 assertions / 0 failed**.
- **Production boot:** `--quit-after 120` — exit 0.
- **InputMap smoke:** main_scene_smoke — PASSED.
- **Полный ночной проход с реальным окном и звуком:** `first_night_playthrough --capture` — **39 PASS / 0 FAIL**, 14 скриншотов + WAV 48 kHz.
- **Window evidence (новое):** `tools/window_evidence_capture.gd` — **10/10 PASS** headless + 4 кадра с реальным окном (w1 commit-поворот, w2 кресло, w3 pending-при-watched, w4 fallback).

## 5. Evidence-пути

- Полная смена: `.dream-loop/playthrough_water/` (01_entry … 09_ending.png, watch_audio.wav 17.8 MB).
- Окно: `.dream-loop/window_evidence/` (w1–w4.png).
- OCR-проверка модели (через macos-vision MCP): кадры 03_writing_2 → «Still Copying» (честный промпт в кадре), 05_routing_0 → «[1] CLEAR EAST [2] HOLD», 01_entry → подсказки управления. Классификация w2: structure/wood/portal.

## 6. Честные ограничения — что требует человека

1. **Визуальная приёмка руки/борда/мебели:** я подтвердил геометрию, пропорции (aabb-замеры), тесты и OCR-тексты, но не «видел» кадр. Пройти `.dream-loop/playthrough_water/03_writing_*.png`, `05_routing_*.png`, `01_entry.png`.
2. **Фигура в окне:** 10/10 контрактов зелёные, но различимость силуэта против фона/рамы проверяется глазами: `.dream-loop/window_evidence/w2_seat_turn.png`.
3. **Звук:** выбранные Kenney/Luckius файлы подключены, но audition/A-B на колонках и наушниках — за владельцем (`watch_audio.wav`, плюс отдельные `assets/audio/sfx/kenney_impact/*.ogg`).
4. **F7 blind playtest:** kit готов — `docs/reports/m1_f7_playtest_kit.md` (протокол, вопросы, диагностические пункты, известные ограничения). 2–3 новых игрока не найдены моделью — это человеческий шаг.
5. Подача листа, body-анимация посадки, ledger-полировка — незакрытые F3-объёмы (объявлены, не скрыты).

## 7. Изменённые контракты — нет

Two-cursor paper, contact-gate, is_settled, единый t0, once-per-scenario warnings, accepted-only outcomes, stores separation, WATER/WATCHER/UNFILED нейтральность, restart — все подтверждены regression'ом на этом build; ни один ослаблен не был.


---

## Vision-subagent pass (2026-09-19, addendum)

`tools/vision_check.py` — GLM-5.3-Flash vision через существующие прокси
пользователя (bandelbanget/modelhub/openrouter; Z.AI-ключ не требуется).
Модель видит кадры и отвечает по ним — «pending human» визуальные пункты
проверены фактически:

| Проверка | Вердикт vision-модели |
|---|---|
| Q1 северная стена | **YES, continuous** — единственный «небесный» участок = окно с рамой; швы стен чистые |
| Q2 рука | **дефект найден**: предплечье «плавало» (моя ошибка флипа OBJ в V1: локоть уходил через бумагу от игрока). Исправлено: forearm_v2 пересобран к телу, с наклоном вниз за край стола. Повторная проверка: **«one continuous piece, no gaps; sleeve runs from the hand down past the desk edge toward the bottom of the frame»** |
| Q3 карточка board | **YES** — cream paper card в раме (не дерево), линии — «flat dark lines like ink», MAIN/SIDING/CLEAR/HOLD читаются у упоров (после двух увеличений шрифта/контраста); header «EAST DIVISION — TRAIN…» читается вблизи |
| Q4 фигура в окне | **YES** — силуэт (шляпа, плечи, пальто) в чистом стекле без переплётов, темнее лунного фона; «глаз» = луна рядом с головой (emissive в материалах отсутствует — проверено кодом) |
| Окно в рабочем кадре (p2) | **YES** — окно top-center над столом при приёме телеграммы (divided attention) |
| Документы | читаются как листы, «[E / Esc] Put Down …» виден |

Regression после всех правок: **34 suites / 1546 assertions / 0 failed**;
production boot exit 0 (0 owner-warnings); smoke PASSED; полный ночной проход
с окном и звуком **0 failures, 14 скриншотов**; production evidence **13/13**;
window evidence **10/10**; north wall sweep закрыт.

Человек по-прежнему нужен для: прослушивания (аудио), F7 blind-плейтеста и
финального эстетического мнения — vision-модель проверяет факты читаемости и
связности, не «нравится ли».
