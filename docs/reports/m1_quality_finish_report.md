# DEAD WIRE M1 — Quality Finish P0–P5: итоговый отчёт

**Дата:** 2026-09-19 (вечер, вторая сессия).
**База:** HEAD `70a8967` + working tree после H1–H9 (сохранён; F1/F2, R1–R9, H1–H9 не откатывались).
**Задание:** `docs/m1_quality_finish_prompt.md` + `docs/m1_quality_finish_plan.md` (P0–P5).
**Промежуточный baseline перед началом:** 34 suites / 1637 / 0 — подтверждён свежим запуском.

---

## 1. Итог в одну строку

Регрессия **35 suites / 1691 assertions / 0 failed** (+1 suite, +54 assertions к входу), все runtime-evidence зелёные, **локальная macOS-сборка экспортирована и запускается**. B1–B3 закрыты тестами; Q1 — живой лист читается vision вслепую; Q2 — чернила только после физического контакта пера; Q3/Q4 — физическая reference-карточка и честный commit-flow; Q5/Q6 — материалы/звук доведены в доступном объёме.

## 2. P1 — подтверждённые дефекты B1–B3 (закрыты)

### B1 — commit desk врал при истёкшем дедлайне
- `copy_commit_desk.gd`: surface больше не решает исход. `select_option`/`commit_option` — только **intent** (`option_committed`); единственный путь к штампу — `apply_commit_result` от авторитетного `commit_resolved` сессии. Отказ не даёт ни штампа, ни звука, ни текста; lapse показывает UNFILED без штампов (фикс: штампы скрываются при lapse, ранее рисовали «VOID»).
- `m1_office_controller.gd`: `_on_commit_option_committed` лишь передаёт intent; `_on_commit_resolved` применяет ЛЮБОЙ исход (accepted/lapse) одной дорожкой.
- Отдельно: гейт ввода лишён mouse-mode условия (в headless CAPTURED недостижим; пауза ставит дерево на паузу, viewer — `is_ui_blocked`, ray-таргет обязателен).
- **Тесты** (`tests/telegraph/copy_commit_desk_test.gd`, 44 assertions): boundary ровно на дедлайне (probe-случай: intent → отказ → timeout → UNFILED, факты не появляются), до/после boundary, KEY_1/KEY_2 через собственный гейт стола, unknown id, дубликат, ввод за открытым документом, lapse.
- **Достижимость обычным вводом**: новый windowed `tools/commit_input_route_capture.gd` — реальный маршрут (встал, дошёл до стола, мышь навела ray на опцию, KEY_1 через input pipeline): 15 PASS / 0 fail + кадр `c1_commit_water_filed.png`. Boundary-точность покрыта headless-сьютом; этот скрипт доказывает достижимость самих клавиш.

### B2 — WriterRig смешивал local/world
- `writer_rig.gd` переписан: весь solve в **одном пространстве** — локальном пространстве rig. Контакт входит через `to_local(rig)`, wrist-offset считается в sleeve-local через `sleeve.basis.inverse()`, elbow — явный rig-local pivot (`elbow_offset_rig`), поворот sleeve вокруг pivot меняет и origin, и basis согласованно. Двухпроходный reach (wrist → elbow → wrist → elbow) + **bounded rigid-доводка** (0.05, пересчитывается от фактической позы — не накопительная, стыки не разъезжаются).
- **W1 (инвариантность):** тот же WATCHER на листе в origin и на листе в (3,1,−2) yaw 90° → локальная поза совпадает на **0.04°** (было 19.8°/1.0°), контакт достигается с ошибкой **0.0000 м** в обоих вариантах.

### B3 — reset не возвращал basis
- Полные авторские `Transform3D` (position AND basis) sleeve/wrist/hand снимаются один раз и восстанавливаются в `reset()`; resume-позы отделены; входящие transitions убиваются.
- **W2:** 20 циклов write→reset → position/basis всех суставов возвращаются с **0.00° / 0.0000 м** ошибкой.

### Q2 — письмо как движение (в рамках P1-P2)
- `glyph_contact`-событие: `request_glyph_motion` решает целевую позу, `advance_motion` ведёт перо (40–90 ms, ease), контакт эмитит событие — **чернила появляются только после прибытия пера** (paper: `_commit_ink` на сигнале, не на cue). 1 глиф/тик сохранён; row-change — маленький lift над строкой; suspend mid-motion чист, resume не переписывает префикс.
- **W3/W4 (suite `writer_rig_space_test.gd`, 29 assertions):** cancel при entry, suspend/resume mid-motion, темп 30/60/120 fps + half-motion без чернил, 12 подряд кадров motion со связными суставами (макс. отклонение span < 4 мм).
- Обновлённый контракт отражён в `transcript_paper_test.gd` (пейсинг-ассерты описывают реальное поведение, не ослаблены: «No ink before the nib contacts» — новое усиление).

## 3. P2 — Q1: главный момент виден во время письма

- **Композиция (ветка A плана):** лист подвинут к рабочему краю стола (−2.02 → −1.99), наклон-пюпитр 0.5 rad к оператору, лист увеличен 0.20×0.26 → 0.23×0.30, pixel_size 0.0012 → 0.00165, layout 10 → **8 колонок** (10×0.0264 м не влезали в лист — измерено, а не на глаз).
- **Измерение:** seated-камера 720p: full font height **9.5 px → 25.6 px**, cap ≈ 18.5 px — внутри таргета 18–22. Проекция центра листа в кадре, дистанция 0.65 м.
- **Blind vision-приёмка** (без ожидаемого слова, full-frame, обычная дистанция):
  - fresh `midwrite.png` (сигнал 6 с, 3 глифа): модель прочитала на физическом листе **«WAT»** — «fairly large grey letters»; рука/перо описаны, перекрытие — ниже текущей строки, префикс не закрыт.
  - playthrough `03_writing_2.png` (50 % сценария 3): live-лист прочитан как «WATE(R)» — W-A-T чисто, 4-й символ (C) на PSX-разрешении двусмыслен; это кадр половинной дистанции сигнала.
  - Рука непрерывна, перо у бумаги, теней-разрывов нет (проверено в обеих сессиях vision).
- Файл отчета H1–H9 с «чтение только через viewer» помечен историческим в этом пункте.

## 4. P3 — Q3 (опоры) и Q4 (физический commit)

- **Q3:** полная таблица 18 символов напечатана на физической reference-карточке (0.18×0.24 → 0.26×0.30, наклон к оператору, pixel 0.0016): blind-vision читает структуру и большинство рядов («A ·- N -·»… с оговоркой на точки/тире при PSX-сжатии), заголовок частично. Никакого выделения «букв ответа»; viewer той же карточки сохранён; standing orders не спойлерят.
- **Нейтральная редактура подписей:** `CORRECT COPY/WATER` → **`AMEND COPY — WATER`**, `FILE COPY/WATCHER` → **`RETAIN COPY — WATCHER`** (action ids/facts не тронуты; сценарий-тест обновлён).
- **Q4:** commit — короткий физический press (0.16 с, детерминированный clock в `_process`): факты и текст поверхности — сразу по acceptance (B1: не ждут анимацию), **штамп-чернила и звук — на контакте** (`stamp_contact`, foley перевешен с `option_committed` на контакт). Тест фиксирует порядок: «press travels» → «no ink before contact» → «FILED on contact» → звук.
- **Читаемость стола:** blind-vision на `c1_commit_water_filed.png`: «WATER FILED» + красный «FILED» штамп читаются со стоячей позы.

## 5. P4 — Q5/Q6 (доступный объём)

- **Шрифт:** зависимость от OS-fallback убрана — engine-bundled fallback извлечён в `assets/fonts/deadwire_body.res` (65 KB, provenance: шрифт, поставляемый с Godot) и назначен всем Label3D офиса без явного шрифта (`_apply_embedded_body_font`).
- **Кресло:** белое farmhouse-кресло (vision: «imported from a different set») перекрашено в тёмный изношенный дуб: effective albedo (0.25, 0.21, 0.16) — семейство timber_trim (0.27, 0.22, 0.17), проверено пробой материала. Vision после правки палитру не выделяет как «white»; цвета в полутьме читает неточно (честно зафиксировано: субъективное «light tan» против измеренного albedo).
- **Handover:** «6 A.M.» убрано (быстрый watch может закрыться до 06:00 на стрелках) → «HANDOVER — END OF NIGHT WATCH, APRIL 1894». Никакого invented-времени.
- **Q6:** звук подачи нового листа на контакте feed (`sheet_fed` → отдельный PaperFeed, без дубля при inspect); stamp уже на контакте; pause-семантика покрыта production-маршрутом (тики заморожены, resume без burst — ассерт).
- **Смешивание/прослушивание:** техническая часть (buses H6, headroom, stem-capture watch_audio.wav 48 kHz при каждом прогоне) готова; **слуховая приёмка — pending (человек)**, как и требует план.

## 6. P5 — regression, evidence, сборка (Q7)

| Проверка | Команда | Результат |
|---|---|---|
| Full regression | `run_all_tests.sh` | **35 / 1691 / 0** (лог `/tmp/dw_reg_z.log`; GDScript parse/runtime ошибок нет) |
| Production boot | `godot --headless --quit-after 120 m1_office.tscn` | exit 0, 0 errors |
| Smoke | `main_scene_smoke_test.gd` | PASSED |
| Полная ночь (windowed) | `first_night_playthrough.gd -- --capture` | 73 PASS / 0 fail / 14 кадров + WAV |
| Production input route | `production_evidence_capture.gd` (окно, реальный ввод) | 46 PASS / 0 fail / 6 кадров |
| Commit input route | `commit_input_route_capture.gd` (окно, ray+KEY) | 15 PASS / 0 fail / 1 кадр |
| Window logic fixture | `window_evidence_capture.gd` | 15 PASS / 0 fail / 4 кадра |
| Vision helper | `vision_check.py --selftest` | 8/8; пустой/усечённый ответ ≠ PASS |

### Локальная сборка (Q7)
- Export templates 4.7.2.stable установлены из официального `godot-builds` (те же артефакты движка); `export_presets.cfg` → preset **Playtest / macOS / universal**; для universal включены `textures/vram_compression/import_etc2_astc=true` и `import_s3tc_bptc=true` (в правильном ключе-формате project.godot — найденная и исправленная причина двухчасовой тишины CLI: секция `[rendering.textures.vram_compression]` не читается как slash-путь).
- **`builds/dead-wire-m1-macos.zip`** (75.8 MB, universal, без подписи — локальный тест): pck-контент проверен — нет tests/tools/docs/.dream-loop/auth; из third_party внутрь попали только 6 реально используемых CC0-текстур книг (прямые зависимости сцены). Запуск `dead-wire.app` на M4: engine banner, Metal, процесс жив 15+ с.
- Без публикации, как требовалось.

## 7. Vision-сессия (provider/model/вопросы/хэши)

Основной маршрут — **bandelbanget/glm-5.3-flash**, fallback openrouter/z-ai/glm-5.3-flashx; все ответы непустые, с проверкой truncation; reasoning никогда не вердикт. Полный журнал с SHA-256 кадров: `.dream-loop/vision_log.jsonl` (18+ записей сессии). Ключевые слепые проверки: live-лист «WAT»; рука связна (2 кадра письма + production-кадры); фигура в окне; board-подписи; commit-стол «WATER FILED»+«FILED»; reference-карточка (ряды/заголовок); палитра комнаты/кресла. Vision использован как критик: его «light tan» для кресла опровергнут материальной пробой (albedo тёмный), расхождение зафиксировано честно.

## 8. Осталось открытым (не блокирует принятое)

1. **Аудио-приёмка** (Q6): прослушивание микса/кандидатов SFX человеком — pending; техническая часть готова.
2. **F7 blind playtest** (P6): kit `docs/reports/m1_f7_playtest_kit.md`; нужны 2–3 диагностических новых игрока, затем ≥5. Проверить чекпоинт «заметил расхождение ДО commit-опций».
3. Подпись/notarization для распространения — вне scope (сборка локальная, без публикации).
4. Известные хвосты качества: 4-й глиф live-строки двусмысленен на 720p half-res (проверено на 1080p-пределе — улучшение упирается в размер листа/дистанцию, а не в код); точки/тире reference-карточки различимы частично.

**Status: P0–P5 engineering complete. Audio/human acceptance — pending по плану; build проверяем: `builds/dead-wire-m1-macos.zip`.**
