# DEAD WIRE M1 — Quality Finish: исследование, аудит и план исполнения

Дата: 2026-09-19.
База: HEAD 70a8967 + текущий working tree после H1–H9.
Задание владельца: изучить источники, проверить код и подготовить следующий план реального повышения качества.
Статус: исследование завершено; изменения игры по этому документу ещё не выполнены.

**Главное:** не начинать очередную полную переделку M1. Сохранить выполненные F1/F2/H1–H9, исправить подтверждённые новые дефекты и сделать главный момент игры читаемым и физически убедительным.

Исполняющий prompt: [m1_quality_finish_prompt.md](m1_quality_finish_prompt.md).
Общая спецификация: [m1_living_shift_plan.md](m1_living_shift_plan.md).
Разрешённые CC0 assets и art scope: [m1_asset_quality_pass.md](art/m1_asset_quality_pass.md).
Предыдущее состояние: [m1_h1_h9_completion_report.md](reports/m1_h1_h9_completion_report.md).

## 1. Какая именно версия игры должна получиться

Игрок без объяснений извне:
1. понимает свою обычную работу;
2. видит, что перо действительно оставляет запись;
3. может заметить расхождение во время работы, а не только прочитать готовую подсказку;
4. добровольно решает, когда отвлечься;
5. узнаёт свой выбор по физическому результату;
6. уходит с понятной записью ночи и неопределённостью о смысле событий.

Улучшение измеряется по этим шести действиям. «Модель сказала красиво», количество ассетов, строк и assertions не заменяют их.

Не менять: American Morse, true/written separation, три основных сценария, нейтральность WATER/WATCHER/UNFILED, запрет physical intervention Listener, PSX language, отсутствие combat/повтора передачи/новых менеджеров.

## 2. Что изучено и какие выводы применены

Использованы профильные skills game-design, game-art, game-audio, code-reviewer, godot-gdscript-patterns. Их общие шаблоны адаптированы под DEAD WIRE: reward здесь — понятный завершённый поступок, аудиоприоритет — Morse; loot, combat и адаптивную музыку не добавлять.

Источники проверены 2026-09-19. Следующие решения — наша адаптация источников, не обещание научно доказанного «страха».

| Первичный источник | Полезный принцип | Применение в DEAD WIRE |
|---|---|---|
| [Frictional: 9 Years, 9 Lessons on Horror](https://frictionalgames.com/2019-10-9-years-9-lessons-on-horror/) | Роль игрока, агентность, убедительный мир и редкость scares важнее их количества | Укрепить профессию оператора и ответственность; не добавлять scare, чтобы спрятать сырой interaction |
| [Frictional: Gaps of the Imagination](https://frictionalgames.com/2017-06-gaps-of-the-imagination/) | Воображение достраивает причины, если обратная связь последовательна | Скрывать объяснение аномалии, но сохранять ясность «что сделал я» и «что произошло с предметом» |
| [Xbox Accessibility Guideline 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101) | Проверять фактический размер букв в capture, а не номинальный font_size | Измерять буквы на физическом листе при реальном FOV/render scale; ориентир PC в источнике — 18 px при 1080p |
| [Game Accessibility Guidelines: размер текста](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/) и [контраст](https://gameaccessibilityguidelines.com/provide-high-contrast-between-text-ui-and-background/) | Размер/контраст должны работать на обычном дисплее; guideline предлагает 4.5:1 для текста/UI | Чёткие чернила на спокойной бумаге, варианты текста viewer; не затемнять critical lettering ради horror |
| [Godot: Label3D](https://docs.godotengine.org/en/stable/classes/class_label3d.html) | font_size и pixel_size влияют по-разному; увеличение детализации шрифта при сохранении world-size не увеличивает его экранный размер | Сначала композиция и размер, затем качество rasterization; no_depth_test не лечит перекрытие рукой |
| [Godot: Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html) | Локальные и мировые координаты различаются, есть to_local/to_global | Все точки/векторы authoring движения пера должны находиться в явно выбранном пространстве |
| [Godot: audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) | Mix маршрутизируется по bus, master должен иметь headroom | Проверить Telegraph/Foley/Ambience в сумме, сохранить темп Morse, не менять всё одной громкостью |
| [Xbox Accessibility Guideline 117](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117) | Управляемая камерой информация и непроизвольное движение требуют осторожности | Рабочую читаемость не покупать постоянным shake, принудительным поворотом или резким zoom |

При изменении цифр в источниках актуальная документация имеет приоритет. Проектные pixel/tempo targets ниже — настройки этого pass, не цитаты универсального стандарта.

## 3. Проверенная база и границы доказательств

Прочитаны реальные session/paper/rig/seat/commit/office/clock/ambience/reference/hand-over paths, сцены и тестовый runner. Просмотрены свежие кадры письма, board, комнаты, окна и commit.

Сохранён воспроизводимый диагностический script:
[probe.gd](reports/evidence/m1_quality_2026_09_19/probe.gd),
[probe.log](reports/evidence/m1_quality_2026_09_19/probe.log),
[source hashes](reports/evidence/m1_quality_2026_09_19/source_hashes.json).

Запуск:
~~~bash
rtk proxy godot --headless --audio-driver Dummy --path . --log-file /tmp/dead-wire-quality-audit.log --script res://docs/reports/evidence/m1_quality_2026_09_19/probe.gd
~~~

Это diagnostic probe, не green regression test: он печатает наблюдения и может завершиться exit 0 при найденном дефекте. Перенести нужные случаи в настоящие assert-based suites.

Последний полный regression из отчёта: 34 / 1637 / 0. В этом исследовании полный набор не запускался: игровой код не менялся. В probe были системный macOS certificate error и cleanup warning 6 ObjectDB instances; их нельзя автоматически приписывать найденным gameplay defects.

Master capture: 95.35 s, stereo, 48 kHz, 16-bit; sample peak около −13.34 dBFS, RMS около −44.74 dBFS, near-fullscale samples = 0. Это не true-peak/LUFS analysis и не audition; эти числа не доказывают различимость Morse или приятный timbre.

## 4. Подтверждённые дефекты — сначала их

### B1 [P1] Commit desk врёт при истёкшем дедлайне

Файлы:
- `scripts/telegraph/ui/copy_commit_desk.gd`, select_option / show_lapsed.
- `scripts/office/m1_office_controller.gd`, _on_commit_option_committed / _on_commit_resolved.
- `scripts/telegraph/session/telegraph_session_controller.gd`, submit_commit.
- `scripts/audio/office_foley.gd`, stamp callback.

Surface сначала ставит _committed/result/stamp, затем сообщает намерение session. Session может вернуть false. Office игнорирует return; последующий show_lapsed отказывается обновить уже «committed» surface.

Воспроизведение boundary между input и process:
~~~text
post_signal_elapsed = commit_deadline
desk.commit_option(file_water)
→ surface returns true, shows WATER FILED
→ world_water=false
advance_post_signal(0)
→ world_lapsed=true
→ surface STILL shows WATER FILED
~~~

Это подтверждённое нарушение контракта surface/session. Boundary-состояние в probe выставлено вручную перед следующим process tick; достижимость обычным InputMap в текущем loop отдельно не проверена. Не выдавать этот fixture за запись естественного прохождения. Если session отвергает намерение, визуальная поверхность всё равно обязана оставаться согласованной с результатом.

**Решение:** surface отправляет запрос, authoritative session решает, accepted result вызывает apply_commit_result на surface. Звук и stamp следуют принятому событию. Lapse показывает UNFILED; reject не создаёт ни печати, ни file SFX. Не исправлять простым увеличением deadline.

**Тесты:** точный boundary, до/после boundary, unknown action, duplicate, stale control, commit за document, нормальные WATER/WATCHER и lapse. Проверять одновременно facts, surface, сигнал, звук и ровно один outcome.

### B2 [P1] WriterRig смешивает local/world space

В set_writing_progress:
- `delta = contact - tip` — world-space;
- `wrist_offset = wrist.position - rest` — local-space;
- они складываются без преобразования.
- `elbow = _assembly_rest_position + ...` — локальная точка, но вычитается из world-space tip/contact.
- Basis поворачивается с сохранением origin, а не вокруг реального elbow; correction затем переводит сборку.

Одна и та же последовательность глифов:
- paper в origin: rotation change около 19.80°;
- paper при (3,1,−2), yaw 90°: около 1.00°.
Локальная поза должна быть эквивалентной после жёсткого переноса всей системы. Сейчас это не так.

**Решение:** один rig-local solve space. Переводить world point через inverse transform; вектор преобразовывать basis, без добавления translation. Задать явный elbow pivot. Сначала получать целевую pose, затем выполнять motion; не смешивать несколько накопительных поправок разных пространств.

### B3 [P1] Reset руки не восстанавливает basis

WriterRig.reset восстанавливает assembly.position, но не assembly.basis, хотя письмо его изменяет.

Probe после reset сохранил те же угловые ошибки 19.80° / 1.00°. Это позволяет позе меняться между телеграммами.

**Решение:** сохранять/восстанавливать полный authored Transform3D assembly и joints, отдельно resume pose. Убивать действующие presentation transitions. Rest capture один раз. Не запоминать уже изменённую pose как новый rest.

**Общие тесты B2/B3:** origin/translated/rotated scene, несколько строк, 20 циклов write/reset, pause/resume, cancel во время entry/withdraw, точка пера и стыки одновременно. В финале position/basis/scale совпадают с исходными в установленной epsilon.

## 5. Q1 — главный момент должен быть видим во время письма

### Почему это первая продуктовая задача

Физический текст слишком мелок/закрыт рукой на просмотренных кадрах. Последний отчёт называет это допустимым, потому что есть viewer. Это ослабляет утверждённую цель: увидеть WATCHER, пока звучит WATER.

В диагностике при 1280×720 проекция полной font-height составила около 14.05 выходных px, то есть примерно 7 px внутреннего 3D buffer при scale 0.5. Высота реальных букв меньше font-height; это расчёт проекции, не OCR и не pixel-perfect измерение raster.

### Реализация: три итерации с ограничением scope

**A. Сначала исправить рабочую композицию.**
- Лист ближе к естественной рабочей позиции, не за sounder.
- Pitch/положение камеры дают меньше foreshortening бумаги; не менять все FOV ради одного кадра.
- Увеличить world-size lettering, пересчитать layout/contact вместе, сохранить поля листа.
- 7 букв WATCHER целиком в одной читаемой строке. Те же правила и стиль для нормальных сообщений, без подсветки anomaly.
- Рука держит перо сбоку от уже написанного prefix; критические буквы не накрывает sleeve.
- Начальный target actual cap-height 18–22 выходных px при 720p в выбранной рабочей позе; после half-res остаётся различимая форма C/H/E. Это проектный ориентир, подтвердить независимым чтением.
- У Label3D nominal font-size и pixel-size менять согласованно. Повышение font_size при пропорциональном снижении pixel_size улучшает source raster, но не заменяет больший projected size.

**B. Только если A не даёт читаемость при удобной позе — добровольный desk focus.**
- Один hold InputMap action для небольшого наклона/приближения рабочего взгляда.
- Доступен одинаково на нормальной и аномальной записи; не включается автоматически в третьем сценарии.
- Не открывает viewer, не останавливает signal/deadline и не делает auto-look.
- Выход мгновенно по отпусканию/stand; новая механика не мешает обычной мыши.
- Малое движение, комфортный режим без sway. Не заставлять игрока держать focus весь watch.
- Не вводить HUD magnifier и готовую расшифровку сигнала.
Эта ветка необязательна, если A прошла gates.

**C. Затем поверхностная полировка.**
- Выбрать один контрастный ink/paper комплект.
- Умерить grain/dither на critical text, не переписывая global renderer.
- Не ставить no_depth_test: буквы не должны светиться сквозь руку.
- Viewer оставить для полного чтения и verification; он не заменяет live evidence.

### Приёмка Q1

1. Запись сценария 3 с точным временем сигнала и каждого glyph.
2. Кадры после WAT, после появления C/H, перед signal_finished и с полной копией.
3. Свежая vision-сессия без ожидаемого слова: «транскрибируй только реально написанный текст на листе; неизвестное пометь».
4. Full-frame 720p обязателен; crop — только диагностика. Сравнить также 1080p.
5. Просмотр normal scenario с тем же оформлением: никакой уникальной подсказки «сейчас аномалия».
6. Человек может смотреть на руку и различать запись в обычном темпе; ни один человек не обязан заметить её, когда сознательно смотрит в окно.

## 6. Q2 — письмо как движение, не серия телепортов

В коде contact достигается прямым присваиванием transform на cue. CONTACT/LETTER_PAUSE объявлены, но mark_letter_pause не вызывается потребителем. State names сами не создают физического движения.

После B2/B3:
- Оставить низкополигональную кисть, но оформить согнутый объём/манжету и правильный pen grip.
- Ввести малое перемещение к следующей точке, короткий contact, локальный lift на переносе строки.
- Никаких индивидуальных Tween на Morse mark. Один presentation controller на существующем WriterRig.
- Доступность glyph создаёт request; только фактический контакт подтверждает появление ink.
- Начальные transition durations порядка 40–90 ms, но измерять живой темп. Не менять objective Morse, не задерживать весь mismatch до конца передачи.
- При backlog ограниченный drain, уже написанные буквы неподвижны.
- Сохранить новую подачу старого/нового листа и stable interaction anchor.
- Никаких свободно летающих pen tips и удлиняющегося предплечья.
- Материальная вариация sleeve/cuff/skin важнее большого числа polygons; существующий CC0 shortlist можно использовать, но новый download не заменяет исправление motion solver.

Gate: 3 нормальных скорости кадра (30/60/120), hitch, stand/return, reset. Рассматривать не только конец pose, а 8–12 последовательных кадров движения. Любое изменение тени/перекрытия слова проверяется с настоящей лампой.

## 7. Q3 — игрок должен иметь возможность разобраться в сигнале

Это проверяемый дизайн-риск, не утверждение, что все игроки уже провалили hook.

Текущая reference-card в мире показывает только заголовок; таблица 18 символов появляется в modal viewer. Она скрывает руку. Третья передача короткая; просмотр готовых WATER/WATCHER options может стать первым источником подозрения, а не выводом из сигналов.

### Что сделать в этом scope

- Напечатать существующую таблицу на физической reference-card, упорядочить/увеличить её для рабочего взгляда. Не выделять только буквы финального ответа.
- Сохранить полный удобный viewer той же карточки и доступность до открытия линии.
- Проверить, что новичок заранее узнаёт: щелчки содержат сообщение, бумага — запись Элиаса, справочник — независимая опора.
- Коротко отредактировать existing standing orders для процедуры, без спойлера mismatch.
- Не добавлять автоматический перевод Morse, субтитр WATER, replay или forced tutorial.
- Сохранить текущие objective messages и сроки для baseline. Новые training transmissions не вводить в этот проход.

### Как диагностировать на раннем checkpoint

Отдельно записывать: умеет ли игрок Morse, услышал ли сообщение, видел ли живые буквы, пользовался ли справочником, заметил ли расхождение ДО просмотра вариантов commit.

Если после исправления доступа новичкам объективно недостаточно обучения, зафиксировать отдельное продуктовое решение об обучении. Не скрывать этот результат добавлением MISMATCH DETECTED и не объявлять общий 80% успех по знающим код игрокам.

Проверить формулировку `CORRECT COPY`: она может читаться как «правильный ответ», хотя подразумевает исправление. В этом pass допустима нейтральная редактура `AMEND COPY — WATER` / `RETAIN COPY — WATCHER` с сохранением action IDs/facts и понятностью действий. Это предложение дизайна, его эффект проверяется, а не считается установленным.

## 8. Q4 — физический commit и завершённая процедура

После B1:
1. Input сообщает намерение.
2. Session принимает исход.
3. Короткое движение stamp/press к бумаге.
4. Контакт даёт звук и видимый отпечаток.
5. Stamp уходит, выбранная запись остаётся.
6. Consequence запускается по прежним нейтральным правилам.

Не задерживать accepted facts до tween.finished: отмена анимации не должна отменять совершённое действие. Presentation отделена от уже принятой записи. State cleanup не создаёт второй звук.

UNFILED не рисует штамп за игрока. Если neutral consequence начался до завершения короткой stamp-анимации, согласовать timing через существующий recovery, не ставить новый бесконечный gate.

Визуально карточки выбора должны быть размещёнными на рабочем столе документами, а не двумя маленькими floating panels. Подписи читаемы из штатной standing pose, не только при auto-aim.

## 9. Q5 — более убедительная обстановка без массового нового контента

Сохранить новый window placement, исправленную wall/collision и реальные CC0 props.

### Проход 1: согласованность материалов/освещения

- Три семейства: тёмное дерево, светлая бумага/кожа, матовый металл/латунь.
- Проверить white farmhouse chair: выделяется ли как несвязанный asset на фоне остальных.
- Не делать каждый prop одинаково грязным; износ у контактов и мест работы.
- Paper и надписи реагируют на сцену согласованно; выбрать физически убедимую читаемость, не fullbright labels в чёрном помещении.
- Проверить imported furniture against collision: proxy повторяет занимаемый объём достаточно, чтобы руки/камера не проходили через визуальные ножки и не упирались в пустоту.
- Удалить визуально лишние/нефункциональные акценты, а не только добавлять.

### Проход 2: три рабочих группы

Desk = текущая работа; archive/board = правила и принятые приказы; door/stove = жизнь и смена оператора. Использовать имеющиеся книги, листы, lamp, coat, shelf и небольшой рабочий реквизит из разрешённого списка.

Каждому добавлению нужна причина. Отрицательное пространство остаётся. После двух итераций matched captures остановиться, если остаток — только вкус; не перерабатывать комнату бесконечно.

### Проход 3: документы и выход

- Печатные поля, хороший letterhead и ограниченный износ.
- Убрать зависимость game-critical font от случайного OS fallback, если можно корректно встроить уже лицензированный шрифт. Новый font проверять отдельно: бесплатный ≠ CC0, не копировать Georgia с машины.
- Сопоставить handover `6 A.M.` с actual station clock: теперь быстрый watch может закрыться раньше отображаемого 06:00. Не возвращать snap; подписать документ как end-of-watch/next-watch schedule либо использовать честное поле времени.
- Уход не должен превращаться в цепь внезапных «сначала прочитай ещё одну бумагу». Существующий mandatory handover сделать заранее понятным, без нового quest UI.

## 10. Q6 — звук и давление

Сохраняются H6 buses, anchor creaks, one pre-call hush. Не делать заново уже выполненное.

### Mixing pass

- Зафиксировать master capture и отдельные Telegraph/Foley/Ambience stems для диагностики.
- Сравнивать candidates на одинаковой воспринимаемой громкости; громче не означает качественнее.
- Проверить call со всех рабочих зон, distinctions down/up у стола, последний знак под paper/stamp/footsteps.
- Sample headroom есть; это не повод автоматически поднять master на 13 dB.
- Timbre текущего `impactPlate_heavy` для stamp нужно прослушать: подходящий файл определяется материалом/контактом, а не словом heavy.
- Синхронизировать foley с контактами, а не просто с любым UI event.
- У текущего OfficeFoley paper звук привязан к viewer open/close; реальная подача нового листа тоже должна иметь свой короткий согласованный звук, без дубля при inspect.
- Pin/cloth/wood не должны заглушать Telegraph. Audio warnings понятны за документом.
- UI pause должен замораживать clocks/loops по принятому контракту, resume не создаёт burst.

### Psychological pacing pass

Нормальная первая работа → небольшое отвлечение второй → защищённое письмо третьей → короткая пауза результата → нейтральное окно → запись ночи.

Не добавлять scare, чтобы заполнить паузу. Менять за итерацию одну группу waits/recovery/mix. Проверить, не возник ли повторяющийся cue, выдающий каждое событие заранее.

Для давления нужны понятные доступные действия с ограниченным временем. Если игрок теряется из-за interface/нечитаемости — это usability defect, а не достигнутый horror.

Музыка optional, преимущественно title/end. Human audition остаётся необходимым, если у агента нет аудиовхода. Он может выполнить acquisition/editing/technical checks, но не придумывать слуховой verdict.

## 11. Q7 — законченная проверяемая сборка

- Один snapshot working tree, свежие tests и logs; сохранённые captures соответствуют этому snapshot (hashes).
- Full regression проверяет не только exit/счётчик PASS, но GDScript parse/runtime errors; сохранять полные логи. Не превращать любой известный host diagnostic в gameplay bug без разбора.
- Реальный input route и edge cases, а не staged-only screenshots.
- Долги export: настроить локальную playtest-сборку для подтверждённой платформы этого проекта, без публикации. Если platform target не задан — локальный macOS smoke build/launch на текущей машине, платформу явно назвать.
- Source-only packs, тесты, debug tools и credentials не нужны в игровом export; проверить фактическое содержимое/размер, а не только visibility nodes.
- Реально отсутствующие export templates или signing requirements фиксировать как конкретный blocker; остальные проверки продолжать. Не скачивать другой engine вместо установленного ради удобства.
- Оценить game-thread frame time/редкие shader/font stutters на рабочих действиях; не строить большой benchmark framework.
- Сохранить provenance всех действительно использованных assets.

## 12. Порядок реализации

| Фаза | Содержание | Gate |
|---|---|---|
| P0 — baseline/evidence | Fresh HEAD/status, B1–B3 repro, реальные кадры, подходящий vision маршрут | Наблюдения отделены от предположений |
| P1 — достоверность | B1 commit acknowledgment, B2 coordinates, B3 rest reset | Surface/facts/sound согласованы, pose transform-invariant, reset полный |
| P2 — рабочее письмо | Q1 композиция/читабельность + Q2 короткая motion | Live prefix различим, контакт/стыки корректны во времени |
| P3 — понимание процедуры | Q3 reference/standing orders, Q4 физический commit | Игрок имеет опоры для сравнения, выбор остаётся его |
| P4 — цельность комнаты | Q5 материалы/документы/props/выход, Q6 foley/mix/pacing | Нормальная работа убедительна; редкие отклонения не тонут в шуме |
| P5 — release candidate | Q7, все ветки, fresh full regression, локальная test build | Проверяемый конкретный build и честные acceptance statuses |
| P6 — human checkpoint | Новые игроки, наблюдение core hook и agency | Реальные наблюдения, не модельные проценты |

Первый bounded pass P0–P2; при поручении всего документа выполнить P0–P5 последовательно, затем подготовить P6. Ограничение контекста решается отчётом/checklist, а не объявлением доступных задач «следующим проектом».

## 13. Matrix дополнительных проверок

| ID | Вход | Результат |
|---|---|---|
| C1 | Surface input на/после deadline | Нет file stamp/SFX; UNFILED после resolution |
| C2 | Valid WATER/WATCHER, duplicate | Один факт/один принятый result/один контактный звук |
| W1 | Paper origin и rigid moved/rotated | Эквивалентные local joint poses и contact |
| W2 | 20 write→reset циклов | Position/basis/scale возвращаются к rest |
| W3 | Mid-enter suspend/resume, terminal | Нет конкурирующего tween, detached hand, позднего glyph |
| W4 | 30/60/120 fps + hitch | Signal одинаковый, glyphs только после контакта, no bulk reveal |
| V1 | Seated full-frame mid-write | Нейтрально транскрибируемый prefix без ожидаемого ответа |
| V2 | Same style scenario 1/2/3 | Ничто UI-специфичное не выдаёт anomaly |
| V3 | Hand-shadow/motion over paper | Critical letters не закрыты рукавом/пером/тенью |
| U1 | Reference до watch и во время работы | Информация доступна без скрытой автоматической расшифровки |
| U2 | Stand/return/route/deadline | Улучшение композиции не ломает reach/collision/fairness |
| A1 | Call + footstep/paper/stamp | Сигнал различим; отдельный audition, не только peak |
| A2 | Pause/resume / repeated bind | Нет double players, duplicate foley или audio burst |
| R1 | Все outcomes и restart в середине motion | Старые facts/tween/ink/результаты не протекают |
| R2 | Exported build | Работает без dev tools/source packs/auth config |

Не заменять существующую матрицу F1/F2 этим сокращённым списком; это новые проверки сверх неё.

## 14. Vision и человеческая приёмка

Использовать исправленный `tools/vision_check.py`:
- bandelbanget / glm-5.3-flash;
- fallback modelhub / glm-5.3-flash;
- затем OpenRouter / z-ai/glm-5.3-flashx.
Отдельный Z.AI key для уже настроенных proxies не требуется. Не использовать plain glm-5.3 как замену vision в этом workflow.

~~~bash
rtk proxy python3 tools/vision_check.py --selftest
rtk proxy python3 tools/vision_check.py <fresh_png> "Transcribe only the ink currently visible on the physical sheet, not the HUD. Do not infer missing letters. Describe any hand occlusion or disconnected geometry. Mark uncertainty."
~~~

Никаких expected words в вопросе для blind transcription. Full-frame первым, crop вторым. Answers/logs привязаны к hashes кадров. Empty/truncated/failed response — inconclusive. Не сохранять секреты/reasoning. Не повторять запросы до желаемого YES.

**Не смешивать три разных gates:**
1. текст различим;
2. игрок понял процедуру;
3. игрок сам заметил mismatch и почувствовал ответственность.

Vision помогает первому, частично геометрии. Только реальные игроки проверяют второе и третье.

Checkpoint: сначала 2–3 диагностических новых игрока, затем минимум 5 для общей оценки; не объяснять mismatch. Отдельно учитывать Morse experience. Наблюдать момент замеченного расхождения до commit, а не только ответ после наводящего вопроса.

Если источник ошибки — обучение, зафиксировать это как отдельный design decision. Если источник — буквы/звук/поза, исправить слой. Не повышать число аномалий.

## 15. Definition of Done

**Engineering:** B1–B3 исправлены с regression cases; P2–P5 реализованы; все затронутые contracts зелёные; runtime/evidence относятся к текущему build; local playtest build проверен либо указан конкретный export blocker.

**Visual:** есть matched gameplay-camera before/after; live writing читается; рука непрерывна на последовательности кадров; board/commit/documents соответствуют значениям фактов. Vision response не единственное доказательство.

**Audio:** прослушан реальный mix на согласованном выводе; если это недоступно, статус audio acceptance pending, техническая работа закончена отдельно.

**Human:** реальный checkpoint/F7 проведён либо подготовлен; не выдумывать игроков или проценты.

**Не закрывать:** «выглядит лучше по названию mesh», «слово можно прочитать потом во viewer», «штамп уже появился, значит commit принят», «1637 asserts значит новых багов нет».
