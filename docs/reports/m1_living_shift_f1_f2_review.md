# M1 Living Shift — review F1/F2 и correction prompt

Дата: 2026-09-19.
База: HEAD 70a8967 + текущие незакоммиченные F1/F2.
Область: сверка implementation с living shift plan, отчётами и адресные runtime probes.
Код игры в этом review не изменялся.

## Вывод

Основные исправления idle board, Escape, active transcript read gate и UI-aware observation работают в проверенных условиях. F1 требует нескольких уточнений; F2 требует correction pass до заявления о полном выполнении контракта. После исправлений нужны production runtime и ранний плейтест; затем F3.

Не переписывать работающий Escape arbitration. Не относить проблемы lifecycle пера и can_write к будущей декоративной полировке.

## Что проверено заново

Godot 4.7.2, headless, Dummy audio, реальная production office scene.

| Проверка | Результат |
|---|---|
| tests/telegraph/routing_board_test.gd | 22 PASS, exit 0 |
| tests/events/window_observation_test.gd | 31 PASS, exit 0 |
| tests/ui/document_viewer_test.gd | 15 PASS, exit 0 |
| Escape через Viewport.push_input(InputEventKey), обычный порядок scene nodes | Board закрылся; pause не открылся; второе нажатие открыло pause |
| То же с изменённым порядком PauseMenu в дереве | Такой же правильный результат |
| Escape через очередь событий при открытом document | Document закрылся; pause не открылся |
| Осмотр EMPTY paper | Воспроизведён дефект: viewer открыт с текстом длины 0 |
| Третий сценарий после реального течения scheduler/paper | В VERIFYING и AWAITING_COMMIT ключ показывает Line Busy (Receiving) |
| is_world_view_blocked при pause | Возвращает false; дерево действительно paused |
| Изолированная проверка lambda capture | Внешний int остаётся 0 после сигнала; array counter становится 1 |

Итого существующие профильные suites: 3 / 68 assertions / 0 FAIL. Полный regression в этом review не запускался; 34/1470 — число из F2-отчёта, а не новый независимый прогон.

Ограничения: headless event dispatch не доказывает визуальный контакт пера, качество звука или ощущения управления. Реальное GUI/audio не проверено. Во время запусков движок выдавал системную ошибку get_system_ca_certificates на macOS; в временном scene probe при выходе также были cleanup warnings об оставшихся объектах/resources. Эти сообщения не скрыты и сами по себе не установлены как дефекты F1.

Временные evidence:
- /tmp/dead_wire_f1_review.gd — production-scene probe с push_input; read-only к исходникам, сохранение настроек отключено в probe.
- /tmp/dead-wire-f1-runtime-review.log
- /tmp/dead_wire_capture_review.gd и /tmp/dead-wire-capture-review.log
- /tmp/dead-wire-f1-routing-test.log
- /tmp/dead-wire-f1-observation-test.log
- /tmp/dead-wire-f1-document-test.log

Скрипты в /tmp временные: нужные regression cases перенести в существующие tests, не зависеть от их сохранности.

## F1 — исправления

### R1 [P2] Ключ продолжает сообщать о приёме после конца сигнала

Место: scripts/office/shift_director.gd, _apply_key_state, около строки 460.
Связанный участок: scripts/office/m1_office_controller.gd, _update_key_feedback (при directed shift выходит сразу).

Воспроизведение: закончить третью передачу, дождаться VERIFYING; осмотреть transcript и перейти в AWAITING_COMMIT. В обоих состояниях ключ показывает Line Busy (Receiving). Директор остаётся в Phase.RECEIVING и не учитывает состояние session. Для routing-сценария аналогично следует различать COPYING/VERIFYING и действительно доступный route.

Исправление: вычислять prompt по комбинации director phase и session state. Refresh должен вызываться при session_state_changed, а не только смене фазы или посадки.

Проверки: COPYING → finish copy; VERIFYING → read copy; AWAITING_ROUTE → set route; AWAITING_COMMIT → file copy; CONSEQUENCE → нейтральный статус ожидания, без ложного receiving. Не включать ключ как доступное действие там, где оно отсутствует.

### R2 [P2] Пустая бумага открывается как готовый документ

Место: scripts/office/m1_office_controller.gd, _on_transcript_inspected / _update_transcript_prompt, около строк 330–385.

Воспроизведение: новый watch до первого сообщения, осмотр TranscriptPaper. PaperState.EMPTY получает read prompt; viewer открывает пустую TELEGRAM TRANSCRIPT.

Исправление: явно обработать EMPTY и PREPARING. Для EMPTY — статус No copy yet, без действия чтения и без document_opened. READY_TO_INSPECT и terminal partial сохраняют свои корректные пути; старый готовый лист между слотами остаётся читаемым.

Проверки: EMPTY/PREPARING не открывают viewer, активная partial не открывает viewer, terminal partial открывает только написанный prefix, старый готовый лист не верифицирует новый scenario.

### R3 [P2, тест] Проверка отсутствия board_opened ложноположительна

Место: tests/ui/framing_test.gd, около строк 108–112:

~~~gdscript
var opened_count: int = 0
board.board_opened.connect(func(): opened_count += 1)
~~~

Проверено отдельным запуском: изменение захваченного scalar внутри lambda не меняет исходный локальный int. Поэтому opened_count == 0 проходит даже после сигнала.

Исправление: mutable array/dictionary либо поле test object для счётчика. Обязательно положительный контроль: idle interaction даёт 0, валидное открытие awaiting board даёт ровно 1. Просмотреть аналогичные новые lambda counters на ту же ошибку.

Существующий framing test также не доказывал оба порядка Escape, несмотря на формулировку отчёта: там прямые вызовы pause-first. В этом review оба порядка прошли через engine event dispatch. Закрепить именно такую проверку в regression; это пробел тестов, а не найденная ошибка Escape.

### R4 [P3, полнота контракта] Маска UI не включает pause

Место: scripts/office/m1_office_controller.gd, is_world_view_blocked, около строки 389.

Во время pause функция возвращает false. В текущем production обычный _process остановлен SceneTree.pause, поэтому утечка saw_window_event через pause не продемонстрирована. Не записывать это как подтверждённый gameplay leak.

Исправление: включить состояние pause/tree.paused в общий query, как требует план, и добавить проверку. Event lifecycle не отменять. Это устранение неполного контракта, ниже по приоритету R1–R3.

## F2 — замечания предыдущего review, включённые в общий pass

### R5 [P2] Resume бумаги заново инициализирует WriterRig

scripts/telegraph/ui/transcript_paper.gd: resume_writing, около строки 280, вызывает rig.begin_writing.
scripts/telegraph/ui/writer_rig.gd: begin_writing сбрасывает _last_glyph_index = -1 и ставит assembly в стартовую позу.

Бумажный written cursor сохраняется, но авторство rig прерывается сбросом. Реализовать отдельный rig suspend/resume с сохранённым индексом и нужной позой. Gate появления глифа должен опираться на реальную готовность rig, а не только независимые 0.18 s.

Проверить индекс/позу rig до паузы и после resume, input во время enter/withdraw, отсутствие чернил до контакта, отмену callbacks на terminal/reset. Подтвердить видео.

### R6 [P2] Frame hitch раскрывает несколько глифов за один кадр

scripts/telegraph/ui/transcript_paper.gd: advance_paper, около строк 86–90.

Цикл while расходует сразу весь накопленный budget. При delta = 1 s он может написать 3 и более glyphs до следующего rendered frame. Последовательные вызовы set_writing_progress в одном кадре не являются видимой последовательностью движения пера.

Исправление: presentation queue с ограниченным раскрытием на кадр/контакт; signal availability может уйти вперёд. Не менять Morse timing. Проверить не только конечный count, но число новых видимых глифов между rendered ticks и контакт каждого из них.

### R7 [P2] Начало передачи не ждёт завершения посадки

scripts/office/m1_office_controller.gd: _on_transmission_started проверяет только is_seated.
scripts/player/operator_seat.gd: sit выставляет is_seated до завершения sit tween.

Сразу после начала посадки ключ доступен; если ответить в этот промежуток, бумага не приостановится до sit_completed.

Исправление: can_write / готовность рабочей позы, ложная во время перехода. Проверять как на старте, так и при resume; вход пера остаётся отдельным gate. Физическую плавность перемещения тела оставить F3, корректность готовности — F2.

### R8 [P2] Lifetime и однократность warnings неполные

scripts/telegraph/session/telegraph_session_controller.gd: advance_post_signal, около строк 139–155.
scripts/office/shift_director.gd: _pending_warning, _advance_step, _advance_to_slot.

- После grace warning игрок может закончить копию до grace. Позднее commit warning сработает снова: условие не проверяет уже прозвучавший grace warning.
- Deferred warning не привязан к scenario/generation и не очищается на смене slot/closing. Старое напоминание может прозвучать в новой ситуации.
- Grace warning и route nag приходятся примерно на один момент (15 s): проверить объединение, отсутствие перезапуска текущего service call или второго call подряд.

Исправление: общий once-per-scenario контракт, проверка актуальности deferred warning, очистка на resolution/load/restart, согласование с nag. Новый менеджер не нужен.

Проверки: grace warning → copy completed → порог commit warning; warning queued → outcome → следующий slot; queued warning → closing; nag + warning в один tick; warning не прерывает телеграмму.

### R9 [P2] Текст deadline warning скрыт за документом

scripts/office/m1_office_controller.gd: _refresh_guidance, около строки 548, меняет только persistent_hint.
scripts/interaction/interaction_controller.gd скрывает prompt при is_ui_blocked.

Звук предупреждения предусмотрен, но плановый читаемый footer документа не обновляется.

Исправление: обновлять существующий footer активного viewer без переоткрытия документа, повторного verification, сброса scroll и изменения snapshot текста. При завершении/закрытии ситуации убрать stale warning.

## Correction prompt для передачи исполнителю

Исправь замечания R1–R9 в docs/reports/m1_living_shift_f1_f2_review.md на текущем F1/F2 build, соблюдая docs/m1_living_shift_plan.md.

1. Начни с проверки HEAD/status и перечитай реальные участки: номера строк ориентировочные.
2. Не реализуй F3 целиком. В этом pass нужны корректность F1/F2, честные prompts и доказательства поведения. Подача листа, плавная траектория тела, ledger polish остаются F3.
3. Не ломай уже проверенные idle-board/Escape/observation пути. Используй существующие компоненты и tests.
4. Исправь ложноположительный счётчик теста с положительным контролем.
5. Добавь regression cases каждого исправления, отдельно текущий partial, terminal partial, retained sheet, посадку до sit_completed, frame hitch и warnings на границе resolution.
6. Выполни focused suites, затем fresh full regression, production boot и smoke. Называй реальные результаты этого запуска, не копируй 34/1470.
7. Проверь event dispatch через InputMap/Viewport, не только прямые _input/notify. Добавь production case, где директор/session/scheduler/paper/deadlines работают вместе.
8. Запиши реальное окно со звуком: seated receive WATER/WATCHER, stand/return, late return/grace, warning за документом. Headless не доказывает визуальный контакт или качество слухового предупреждения.
9. Обнови F1/F2 reports: implemented / tested / untested отдельно. При недоступном GUI оставь runtime acceptance pending, не объявляй её перенесённой в F3.
10. После correction и runtime — checkpoint 2–3 новых игроков; затем F3. Не подменяй плейтест зелёными тестами.

Порядок приоритетов: R5–R8 (lifecycle и время), R1/R2/R9 (понятное действие), R3 (достоверность теста), R4 (полнота query). Regression cases писать рядом с каждым исправлением, а не откладывать весь тестовый слой до конца.
