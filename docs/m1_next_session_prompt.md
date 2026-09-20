# DEAD WIRE M1 — промпт продолжения в новой сессии

> **Актуальный следующий проход после H1–H9 (2026-09-19):** [Quality Finish](m1_quality_finish_plan.md) и [implementation prompt](m1_quality_finish_prompt.md). Старые фазы/замечания ниже сохраняются как контекст; уже закрытые H1–H9 не начинать заново. Новые B1–B3 проверены отдельным diagnostic probe.

Дата handoff: 2026-09-19.
Рабочая папка: /Users/y.israfilov/Desktop/dead-wire.
Назначение: самодостаточная инструкция для новой модели с небольшим начальным контекстом.
Это задание на продолжение реализации, а не новый аудит ради ещё одного плана.

## 1. Задача и полномочия

Продолжи текущую M1 ночную смену автономно до законченного результата в пределах доступной реализации и проверки. Исправь оставшиеся дефекты, закончи незакрытые V0–V7 и F3–F6, подготовь build к раннему cold checkpoint и финальному F7.

Владелец уже разрешил:
- обычные обратимые изменения кода/сцен/тестов в этом scope;
- скачивание, адаптацию и реальное runtime-подключение бесплатных CC0/Public Domain assets;
- замену руки/предплечья, локальную переработку board/documents/layout;
- вызовы существующих vision-прокси для проверки игровых кадров.

Не запрашивай повторное подтверждение этих работ. Решай рутинные вопросы самостоятельно, фиксируй важные решения и проверяй результат. Не расширяй проект новыми ночами, combat, scare director, IK framework, полным персонажем, глобальным renderer rewrite или посторонним сайтом.

Главная цель: убедительная обжитая работа одного оператора, материальность действий, сохраняющиеся следы и психологическое давление через внимание/ответственность. Нельзя объявлять эту цель достигнутой по числу PASS.

## 2. Что прочитать и чему доверять

Сначала AGENTS.md / /Users/y.israfilov/.codex/RTK.md, затем:
1. Этот handoff целиком.
2. docs/m1_living_shift_plan.md.
3. docs/art/m1_asset_quality_pass.md.
4. docs/reports/m1_asset_quality_pass_report.md, включая последний addendum.
5. docs/reports/m1_asset_quality_visual_review.md.
6. docs/reports/m1_living_shift_f1_f2_review.md и correction updates F1/F2.
7. tools/vision_check.py, tools/production_evidence_capture.gd, tools/window_evidence_capture.gd.
8. Реальные файлы выбранного участка.

Ранние отчёты содержат уже устаревшие «не реализовано» и «нет vision». Не принимай их за текущее состояние. Старый issue закрывай фактической проверкой, а не переписывай уже исправленное.

Перед кодом: git status, HEAD, доступный Godot, реальный свежий baseline. Весь build сейчас состоит из многочисленных modified/untracked файлов поверх HEAD 70a8967. Это рабочая версия пользователя — не очищать и не сбрасывать. Не трогать sites/, посторонние configs и пользовательские файлы.

## 3. Vision: использовать именно Flash через существующий proxy

**В этой конфигурации базовый агент GLM-5.3 не является способом просмотра изображений.** Для screenshot review обращайся к **GLM-5.3-Flash** через существующий helper.

Точное имя provider в конфигурации: **bandelbanget** (не транслитерация «Bundle Bangit»).
- Приоритет 1: provider bandelbanget, request model glm-5.3-flash.
- Приоритет 2: provider modelhub, request model glm-5.3-flash.
- Приоритет 3: OpenRouter, request model z-ai/glm-5.3-flashx.

Вызов через bandelbanget/glm-5.3-flash повторно получен при подготовке этого handoff. Это подтверждение доступного здесь маршрута, не универсальное утверждение о возможностях всех моделей с похожими именами.

Helper:
- tools/vision_check.py.
- Сам читает существующие настройки ~/.config/opencode/opencode.json и ~/.local/share/opencode/auth.json.
- Отправляет PNG как image_url с base64 в chat/completions.
- Отдельный Z.AI-ключ не требуется для этих уже настроенных маршрутов.
- Не печатай ключи, Authorization, полные auth/config или base64 в отчёты/чат. Не копируй их в репозиторий.
- Отправляй только нужные игровые captures, без посторонних окон и секретов.

Команды из корня проекта:

~~~bash
rtk proxy python3 tools/vision_check.py .dream-loop/playthrough_water/05_routing_0.png "Inspect the physical board, not the HUD. Transcribe only text actually readable at this full-frame resolution. Mark uncertain labels unreadable. Do not guess the expected text. List concrete visible defects."

rtk proxy python3 tools/vision_check.py .dream-loop/production_evidence/p1_seated_receiving.png "Describe the hand, cuff, forearm and pen. Identify visible gaps, intersections, floating parts and text occlusion. Say when the image is insufficient. Do not assume the rig is correct."

rtk proxy python3 tools/vision_check.py --all .dream-loop/production_evidence "Describe visible rendering or spatial defects. Separate directly visible evidence from uncertainty. Do not infer animation or audio quality from a still image."
~~~

Сначала сделай один контрольный вызов и проверь фактически выбранные provider/model и непустой результат. При DNS/network error в sandbox используй штатный путь разрешения сетевого доступа этой среды; не заключай, что у Flash отсутствует vision. Не переключайся молча на текстовую glm-5.3.

### 3.1. Ограничения текущего helper, которые нужно исправить

В проверенной версии:
- При ALL PROVIDERS FAILED script может завершиться с exit 0.
- --all на пустой папке также не означает выполненную проверку.
- При пустом content helper подставляет reasoning_content.
- Нет проверки finish_reason/усечения, structured verdict и сохранённого соответствия ответ↔hash кадра.

Исправь эти места небольшим отдельным изменением:
- явный success/error, ненулевой exit при полной неудаче;
- пустая папка — ошибка, не green;
- не использовать reasoning_content как финальный vision verdict и не публиковать reasoning;
- incomplete/truncated ответ — inconclusive с ограниченным retry;
- сохранять provider/model, время, SHA-256 изображения, вопрос и финальный короткий ответ, без секретов;
- не позволять бесконечные запросы: одна первичная и одна проверочная итерация после конкретного изменения; далее менять подход, если дефект повторяется.

Покрыть обработку ошибок локальными fixtures/mocks, не тратить live API на каждую проверку parser.

### 3.2. Как получать полезную приёмку

- Не задавай «подтверди, что стало хорошо». Проси назвать видимые дефекты и неопределённость.
- Для читаемости сначала проси дословную транскрипцию БЕЗ ожидаемых слов. Иначе модель может достроить известную надпись.
- Full-frame при рабочей дистанции — основной критерий. Увеличенный crop помогает диагностике, но не доказывает чтение игроком.
- Передавай actual свежий кадр, не только путь/описание. Храни новые evidence отдельно, чтобы не путать их с прежними.
- Один PNG не доказывает плавность, порядок контакта, слышимость и проходимость. Для motion — последовательность кадров + реальные события/время; для collision — runtime; для audio — отдельное прослушивание.
- Model verdict может ошибаться. Сопоставляй ответ с геометрией/телеметрией/изображением; при расхождении пункт остаётся открытым.
- Vision закрывает конкретные наблюдаемые проверки, но не заменяет F7 и эстетическое решение владельца.

При подготовке handoff независимый запрос на full-frame board дал неуверенное чтение физических подписей, несмотря на прежний PASS. Helper допускает fallback/усечение, поэтому это повод для повторной корректной проверки, а не авторитетный автоматический FAIL/PASS.

## 4. Текущий прогресс: сохранить, не начинать заново

По коду и свежим кадрам:
- F1/F2 two-cursor paper, signal/copy distinction, deadlines, lapse, UI gates и R1–R9 реализованы ранее; сохранить и регрессионно проверить.
- Северная стена визуально закрыта; новые window/board композиции присутствуют.
- Кисть/рукав исправлялись повторно; на последнем seated кадре видна более непрерывная форма.
- Бумажная карточка board теперь видна; её читаемость на обычной дистанции ещё нужно доказать.
- CC0 furniture/audio реально подключались. Проверить актуальный manifest/instances, не повторять скачивание автоматически.
- В коде уже есть sheet feed, approach-переход посадки и NIGHT ENTRIES. Старый отчёт «их нет» устарел. Но реализации не полностью соответствуют исходному контракту — см. ниже.
- Flame binding появился.
- Заявленный последний baseline: 34 suites / 1546 assertions / 0 failed; полный playthrough 0 failures, 14 кадров; production evidence 13/13; window evidence 10/10. Это числа отчёта, получить собственный fresh run.

## 5. Приоритетный backlog, проверенный при handoff

### H1. Часы идут назад при начале call — воспроизведено

scripts/office/station_clock.gd:
- WAITING добавляет wait_fraction к номеру slot.
- В CALLING wait_fraction становится 0.
- advance присваивает новое значение без монотонного сглаживания.
- _on_shift_closed по-прежнему мгновенно ставит финальное время.

Runtime probe /tmp/dead_wire_handoff_clock.gd:
- open_line → director.advance(13) → clock.advance(0.1): hours = 25.1666667.
- director.advance(2) → clock.advance(0.1): hours = 23.0.
Лог: /tmp/dead-wire-handoff-clock.log. Это независимая воспроизведённая ошибка, не вкус.

Сделай по §8 основного плана: директор владеет station time/target; display монотонен, скорость ограничена, нет snap на call/slot/closing. Не просто зажимай неверную формулу max(previous,current) без решения темпа. Test WAITING→CALLING→RECEIVING→resolution на fast/slow/missed путях.

Маятник пока вращает ClockPendulumGlass, сохраняет отдельную фазу; проверить настоящий bob/rod pivot и общий phase с tick, не качать стекло корпуса.

### H2. Production evidence всё ещё обходит настоящее управление

tools/production_evidence_capture.gd:
- _walk_to напрямую ставит player.global_position.
- _press_look_at напрямую меняет rotation.y, обходя реальный look input/yaw clamp.
- _emit_interaction напрямую emit_signal("interacted"), обходя ray + E.

tools/window_evidence_capture.gd также содержит staging, отключённые processing/timers и неверно названный seated shot. Не считать эти scripts полноценной проверкой естественного ввода только из-за комментариев.

Оставь fixtures для локальных случаев, но добавь отдельный production route:
movement actions → настоящее движение/collision → mouse motion через player handler → ray target → E → pause/document/stand/return.
Перед seated shot assert is_seated && is_settled. Проверить высоту камеры и clamp. Не разрешать teleport «между shots» в доказательстве целостного маршрута.

### H3. Подача листа пока двигает весь TranscriptPaper root

scripts/telegraph/ui/transcript_paper.gd:
- begin_writing сразу стирает visible prefix и заменяет text;
- _play_sheet_feed tween'ит self.position, вместе с WriterRig и Interactable;
- отдельного сохранённого старого visual sheet нет;
- PREPARING фактически не используется как gate подачи;
- close_incomplete не отменяет feed tween.

Доведи до исходного поведения: старые чернила/лист физически уходят, новый чистый лист подаётся; стабильный interaction anchor; рука входит после готовности листа; cues буферизуются, Morse не задерживается. Максимум два простых слоя бумаги, без инвентаря/физической стопки.

Проверить normal, ранние cues, pause, terminal/cancel/restart во время подачи. Не дублировать phase/grace timers.

### H4. Посадка улучшена, вставание ещё телепортирует

OperatorSeat.sit уже имеет approach interpolation. Stand всё ещё присваивает _standing_transform мгновенно. Approach напрямую двигает transform без видимого collision sweep.

Проверить подход с разных сторон стула, траекторию около стола, свободную точку вставания, repeated/direct sit/stand, отмену tween, управление взглядом. Сделать короткое согласованное перемещение тела без прохода сквозь мебель и без борьбы tween с мышью. Не удлинять действия ради «веса».

### H5. Retained route сбрасывается при следующем slot

RoutingBoard.reset_for_new_transmission очищает _last_route_action и возвращает lever/needle к rest. Это противоречит сохранению физического результата до следующего принятого действия.

Разделить per-slot input reset и retained presentation. Поздний tween предыдущего результата не должен перезаписать новую запись; watch reset очищает всё. Проверить correct/wrong/lapse, быстрый следующий slot и два одинаковых route подряд.

### H6. Atmosphere/audio части F4–F6 ещё не закончены

По текущему коду:
- UneaseDirector всё ещё выбирает случайную polar position вокруг игрока, а не anchors.
- Hush всё ещё запускается из call_started для первых calls, а не один раз ДО первого call slot 0.
- critical-window guard добавлен, сохранить его.
- default_bus_layout содержит только Ambience помимо Master; Foley/Telegraph не разведены.
- Flame path появился: сначала проверить, а не переписывать заново.

Закончить anchors/selection/skip при отсутствии кандидата, pre-call timing/once flag, buses и корректные user settings. Сохранить audible Morse, предупреждения за UI и нейтральность выбора. SFX audition не заменять фактом подключения файлов.

### H7. Ledger появился, но содержит семантические упрощения

DispatchLedger теперь имеет NIGHT ENTRIES, однако:
- filed + отсутствие clear-east fact автоматически трактуется как HOLD;
- incomplete_copy отдельно не отражается;
- statuses/labels продублированы относительно DutySheet;
- дата "23 APRIL" зашита независимо от остальных документов.

Проверить реальные факты и показать неизвестное как неизвестное; не придумывать HOLD из отсутствия знания. Использовать общую knowledge-backed логику статусов, учесть incomplete+lapsed, missed и commit variants. Дату согласовать с существующим setting, не придумывать новую историю.

### H8. Читаемость и визуальная связность — повторная независимая проверка

Карточка board теперь видима, но на full-frame 05_routing_0.png физические надписи малы; HUD не считается заменой. Проверять нейтральной транскрипцией и обычной дистанцией, не только debug/board_crop.

Проверить руку на всех glyphs/строках и в движении, а не только один удачный PNG. Сохранять contact и стыки. Окно — отдельный добровольный отворот, не screenshot, искусственно наведённый прямо на цель.

Оценить комнату по задачам владельца: рабочие группы, функциональные props, масштаб и читаемость документов. Не делать ещё один случайный полный art rewrite.

### H9. Отчёты и доказательства требуют консолидации

Текущий итоговый отчёт одновременно содержит ранние «F3 не сделан/нет vision» и новый addendum. Обнови верхний текущий статус и таблицу, старое вынеси в историю.

Проверь manifest, A07 actual runtime path, derived book export и удаление source-only assets из export по фактическим ссылкам. Не переноси старые claims автоматически.

## 6. Порядок автономной работы

1. Контрольный vision call, корректность helper error handling, свежий baseline.
2. H1 и H2: исправить часы и достоверность production проверки.
3. H3–H5: физическая непрерывность бумаги/тела/результатов.
4. H6–H7: комната, звук, записи ночи.
5. H8: визуальные итерации по свежим кадрам через Flash.
6. H9 и полный acceptance pass.

На каждом участке:
наблюдаемый дефект → минимальное связное исправление → адресный тест → runtime capture → neutral vision review → исправление подтверждённого остатка.

Не останавливайся после одного нового отчёта или списка рекомендаций. Выполни всё доступное в разрешённом объёме. Если конкретная внешняя зависимость блокирует часть работы, зафиксируй её и продолжай независимые части. Не используй отсутствие blind игроков как причину остановки кода.

## 7. Проверки и завершение

Обязательные ветки:
- normal/wrong route, missed call;
- WATER/WATCHER/UNFILED;
- stand/return до и после t0, return after grace;
- pause во время enter/feed/receive;
- deadline warning за открытым document;
- input на deadline boundary, повторные actions;
- retained paper/route/ledger через несколько slots;
- pending figure при заранее направленном взгляде;
- естественный маршрут key→board→commit→door;
- restart в незавершённом состоянии;
- монотонные часы и чистый scene boot.

Использовать existing tests. Fresh full regression после стабильного прохода, не многократное повторение без новых изменений. Логи проверять на ошибки, не только exit code. Нельзя удалить assertions ради green.

Visual evidence: gameplay camera, 1280×720 и дополнительные поддерживаемые разрешения, одинаковые settings для before/after. Для motion — несколько кадров и timing/logs, лучше видео. Ссылки/вопросы/ответы vision сохранять вместе с hashes снимков. Не публиковать reasoning.

Аудио требует отдельной оценки доступным аудиоинструментом/человеком. Vision не слышит WAV через PNG. F7 — настоящие новые игроки; model review не blind playtest.

Итоговый отчёт:
- что изменилось для игрока;
- какие H/V/F критерии реально закрыты;
- новые команды и результаты проверок;
- provider/model и пути проверенных vision evidence;
- реально используемые assets;
- конкретные остающиеся human/audio/playtest пункты.

Не заявляй «всё готово», если остаётся доступная обязательная реализация. Отдели engineering complete, visual checks, audio acceptance и human acceptance.
