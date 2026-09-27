> **SUPERSEDED (2026-09-27).** Исторический документ. Актуальное состояние и планы: `docs/HANDOVER.md`, `docs/plans/next/00_INDEX.md`.

# PROMPT — довести DEAD WIRE M1 после H1–H9

Работай в /Users/y.israfilov/Desktop/dead-wire.
Это задание на реализацию и проверку, а не на составление ещё одного плана.

## Обязательное чтение

1. AGENTS.md и /Users/y.israfilov/.codex/RTK.md.
2. docs/m1_quality_finish_plan.md — актуальный план следующего прохода.
3. docs/reports/m1_h1_h9_completion_report.md — уже выполненное.
4. docs/m1_living_shift_plan.md — сохраняемые общие контракты.
5. docs/art/m1_asset_quality_pass.md — art scope, CC0 sources, asset pipeline.
6. docs/reports/evidence/m1_quality_2026_09_19/probe.gd, probe.log и source_hashes.json.
7. Реальные файлы текущего этапа.

Старый docs/m1_next_session_prompt.md описывает предыдущий H1–H9 pass. Не начинай уже закрытые работы заново. Новая задача определяется этим prompt и m1_quality_finish_plan.md.

## Цель

Сделать рабочую смену убедительной и читаемой: игрок видит, как Элиас пишет, может самостоятельно заметить расхождение с сигналом, понимает своё решение и видит честный сохранённый результат. PSX-стиль сохраняется. Программистская корректность и визуальное качество проверяются отдельно.

Разрешён весь объём P0–P5 нового плана. Начни с короткого baseline, затем выполняй этапы последовательно до завершения доступной работы. P6/F7 требует реальных людей; подготовь его и не выдумывай результаты.

## Сначала подтверждённые проблемы

1. B1: CopyCommitDesk ставит WATER FILED до подтверждения session. В boundary fixture session отвергает действие, затем пишет lapse, но поверхность остаётся WATER FILED. Исправь request/accepted-result flow. Отказ не даёт штампа/звука. Проверяй authoritative outcome и поверхность вместе. Отдельно проверь достижимость boundary обычным InputMap: fixture не заменяет production доказательство.
2. B2: WriterRig складывает local wrist offset с world delta и использует локальный elbow как мировую точку. Исправь пространства и pivot; не скрывай ошибку дополнительным накопительным translation.
3. B3: reset руки восстанавливает position, но оставляет изменённую basis. Восстанавливай полный authored transform и проверяй повторные циклы.

Существующий diagnostic script намеренно печатает дефекты, а не падает assertion. Перенеси случаи в настоящие suites. После изменения кода исторические hash/observed values не переписывай как будто это результат новой версии.

## Затем качество главного момента

- Физический лист должен читаться во время записи. Наличие viewer не является оправданием микроскопических live букв.
- Сначала улучшить расположение бумаги, рабочий взгляд, world-size lettering, контраст и путь руки; optional desk focus только по условиям Q1, одинаково для всех сценариев.
- Прямые pose jumps заменить малым контролируемым движением к contact. Glyph появляется после контакта; authored Morse не задерживается.
- Сделать существующую reference table полезной физической опорой; не вводить автоматический перевод, replay, MISMATCH DETECTED и подсказку ожидаемого ответа.
- Commit — короткое физическое действие после authoritative acceptance, с контактным SFX и сохраняющимся результатом.
- Затем привести комнату, документы, props и звук к единой композиции по Q5/Q6. Используй существующие assets и выбранные CC0 candidates, не начинай массовый asset shopping.
- Проверить локальную playtest-сборку и содержимое export по Q7 без публикации.

Не увеличивай число scares ради напряжения. Понятная работа, ответственность и неоднозначность важнее декоративного шума.

## Vision — обязательно использовать доступный маршрут

tools/vision_check.py уже существует и использует настроенные credentials:
- основной provider bandelbanget, model glm-5.3-flash;
- fallback modelhub / glm-5.3-flash;
- затем OpenRouter / z-ai/glm-5.3-flashx.

В этом workflow plain glm-5.3 не заменяет Flash для изображений. Отдельный Z.AI-ключ не нужен. Не объявляй «нет vision», не проверив helper/маршрут.

Из корня проекта:
~~~bash
rtk proxy python3 tools/vision_check.py --selftest
rtk proxy python3 tools/vision_check.py .dream-loop/playthrough_water/03_writing_2.png "Transcribe only ink actually visible on the physical sheet, not the HUD. Do not infer missing letters. Describe hand occlusion or disconnected geometry. Mark uncertainty."
~~~

Для нового результата сначала создай СВЕЖИЙ capture. Не подставляй expected WATER/WATCHER в blind transcription вопрос. Full-frame первым, crop только для диагностики. Для motion используй последовательность кадров и timing; один PNG не доказывает плавность.

Проверяй непустой финальный content, truncation/error и фактический provider/model. Failure не PASS. Не использовать reasoning_content как verdict. Логи связывай с SHA-256 конкретного кадра, без секретов и reasoning. При сетевой sandbox-ошибке используй штатный доступ/approval механизм среды; не подменяй модель текстовой.

Vision — дополнительный критик, а не судья абсолютной истины. Ответы сверять с runtime, кодом и изображением. Не повторять вопрос до желаемого YES.

## Инварианты

Сохранить:
- deterministic American Morse и true/written separation;
- доступность cues независимо от посадки;
- body readiness, actual contact, two cursors, terminal partial;
- deadlines по t0 и once-only warnings/outcomes;
- neutral WATER/WATCHER/UNFILED;
- WorldState ≠ KnowledgeState;
- UI occlusion, pending figure и bounded completion;
- честные archived paper/route/ledger и watch reset.

Не добавлять combat, новую ночь, менеджеры, IK framework, полный body или глобальный shader rewrite. Не трогать sites/ и чужие изменения. Working tree после H1–H9 — база, а не мусор для очистки.

## Порядок и проверка

- Сначала прочитай HEAD/status и получи fresh baseline.
- P1: B1–B3 + адресные тесты.
- P2: live readability и движение руки.
- P3: доступность процедуры и физический commit.
- P4: материалы, документы, звук, ритм.
- P5: fresh full regression, production input route, все outcomes, runtime evidence и local playtest build.
- Подготовить P6/F7.

На каждом этапе: дефект → минимальное связное изменение → focused checks → реальный кадр/движение → нейтральная vision-проверка → исправление конкретного остатка.

Не ослабляй assertions ради green. Не считай прямую установку transform/emit_signal доказательством input route. Не переписывай objective signal ради красивой анимации. Тесты, captions и отчёт должны описывать то, что действительно происходило.

Обычные обратимые решения в этом scope выполняй автономно. Конкретный внешний blocker фиксируй, но продолжай независимые задачи. Не останавливай реализацию из-за отсутствия blind игроков или аудиовхода. Слуховую приёмку при отсутствии возможности слушать честно оставить pending.

## Завершение

Один актуальный отчёт:
- изменения для игрока;
- состояние B1–B3 и Q1–Q7;
- commands/results свежих focused/full/boot/input checks;
- matched before/after и motion evidence;
- vision provider/model/questions/ответы с hashes;
- использованные assets и локальная build;
- открытые audio/human acceptance пункты.

Не закрывать задачу фразой «ещё можно отполировать», если обязательная доступная работа осталась. Не заявлять эстетическое/человеческое качество по одной модели или числу assertions.
