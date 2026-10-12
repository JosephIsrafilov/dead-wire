# DEAD WIRE — аудит первой ночи перед onboarding / typography / response pass

Дата: 2026-10-11, Asia/Baku. Статус: исследование и фиксация понимания запроса; **не реализация и не утверждённый финальный дизайн**.

## Запрос владельца

Готовая первая ночь для самостоятельного прохождения звукарём: правдоподобные шрифты,
отзывчивые действия, функциональный временный звук и обучение в ходе игры вместо
предварительного чтения длинных инструкций. Возможный канал обучения — короткие мысли
Элиаса снизу экрана. Остаток существующего M1-плана сохраняется, но эксперименты и
расширение кампании не становятся автоматически обязательными.

## Метод и границы

- Прочитаны HANDOVER, index WS1–WS7, remaining-work plan и релевантные части исходного full plan.
- Изучены реальные font wiring, interaction/input ownership, chair transitions,
  director/session clocks, document/filing/route UI, audio bindings, export presets.
- Повторно прочитаны локальные research artifacts: procedural developer sources,
  learning_research.json и brief по исторической манере письма.
- В browser прочитаны 3 страницы Game Accessibility Guidelines и описания 4 шрифтов Google Fonts.
- Шрифтовые cmap прочитаны локальным Python: латинский ASCII присутствует во всех трёх
  bundled fonts; кириллица А–я и ё отсутствуют. Это проверка исходных файлов, не runtime fallback.
- WAV durations прочитаны из локальных RIFF headers без проигрывания и изменения файлов.
- Новых Godot runs, игрового прослушивания, измерений FPS/latency или человеческих плейтестов нет.
- Производственные файлы, assets, settings и git index не изменялись; новых шрифтов не скачано.

## Подтверждённые факты

### 1. Неоконченная E02 остаётся блокером

m1_scenario_2_attention.tres содержит FREIGHT 71 EAST (13 non-space glyphs),
но 19 reveal cues. TelegraphScenarioData.get_validation_errors() отклоняет несовпадение;
TelegraphSessionController.can_load_scenario() отказывает в загрузке невалидного ресурса.
telegraph_scenario_data_test.gd всё ещё ожидает старую фразу и 19 cues.
Ledger ещё не объясняет request != clearance. Завершение R01 остаётся первым implementation task.

### 2. Типографика уже разделена только частично

- Theme default: IM FELL English; office назначает его всем Label3D без explicit font.
- DocumentViewer: IM FELL для обычных документов; Cedarville для handwriting;
  Courier Prime для tape/reference timing table.
- Transcript 3D и viewer используют Cedarville; glyph contact вычисляется по метрикам
  настоящего font, font_size и pixel_size. Замена handwriting влияет на pen positions,
  ширину строк и совпадение 3D/viewer/archive, а не только на внешность.
- IM FELL происходит из Oxford types XVII века. Это не доказанный комплект шрифтов
  железнодорожной конторы Colorado 1894. Старый комментарий  every ... is 1894 letterpress
  — художественная декларация, не историческая аутентификация.
- Cedarville создан по почерку современной preschool teacher, не по specimen делового
  письма XIX века. Он лицензирован и пригоден для чтения, но его происхождение не подтверждает
  образ рабочего почерка Элиаса.
- Old Standard TT воспроизводит classicist serif style late XIX / early XX века:
  полезный кандидат для сравнения, НЕ доказанный railway font. Его локального файла ещё нет.
- Libre Caslon Text не принимать как прямой исторический источник: описание прямо говорит
  о hand-lettered Caslon interpretations в рекламе 1950-х, хотя название кажется подходящим.
- Кириллица потребует отдельного bundled face / явной fallback policy. Нельзя просто вставить
  русский текст в существующую тему и считать получившийся системный fallback правдоподобным.
- Spencerian 1874 — референс формы и техники, не доказательство почерка каждого телеграфиста.
  Palmer edition 1915 не использовать как прямое доказательство 1894.

### 3. Обучение сейчас вынесено главным образом в документ

DutySheet содержит 7 инструкций: lamp/chair/key, seated copy, ledger/board,
tape/card, amendment/filing, clocks и dawn. Реальные локальные E hints уже есть;
общего контекстного onboarding / inner-thought controller нет.
GDD §35.4 предпочитает state в комнате, а §36.3 оставляет внутренний голос открытым.
Текущий запрос владельца задаёт новое направление, но точный формат и границы реплик
нужно зафиксировать перед изменением поведения.

Отдельно важен конфликт: если реплика на третьей телеграмме объявляет я написал не то,
она обнаруживает расхождение за игрока. Процедуру независимой проверки можно объяснить
раньше, на обычной передаче, без авторского знания WATER/WATCHER.

### 4. Отзывчивость нельзя свести к ускорению персонажа

Факты из current production:
- movement 1.35 m/s, acceleration 4.5, deceleration 8.0;
- approach 0.34 s, sit head settle 0.8 s, stand 0.6 s; key требует settled seat;
- viewer open animation 0.24 s;
- answer beat 0.8 s;
- route logical acceptance до animation; throw 0.42 s; stop audio после throw;
- stamp logical acceptance до physical contact 0.16 s; return 0.4 s;
- key down 0.05 s, return 0.16 s;
- мышь не сглаживается, seat settle уступает ручному look;
- board/document/editor имеют явное владение вводом и transition guards.

Эти числа — исходные значения, **не измеренная input-to-photon latency**.
Ритуал, ощущение принятого ввода и блокировка управления — разные вопросы.
Сохранять immediate accepted-state feedback и physical-contact sound; не играть ложное
подтверждение для rejected/late input и не покупать время скрытым reset дедлайна.

### 5. Временный звук уже функционирует, но есть роли для разведения

- Buses: Telegraph, Foley, Ambience; полноценная middleware не требуется для M1.
- Sounder down/up идут из objective scheduler, не из handwriting.
- Pen привязан к glyph_contact; stamp к stamp_contact; lever throw к route_accepted.
- Door attention использует цельную длительность семпла / pitch + safety margin,
  ждёт подходящий GAP и прекращает optional sample при MARK.
- Pen scratch 0.055 s; sounder down 0.075 s / up 0.055 s; key click 0.09 s.
- Route lever sample 0.42 s сам содержит несколько impacts; отдельный stop вызывается
  через 0.42 s animation. Возможный double-impact — гипотеза для прослушивания, не доказанный дефект.
- WICK sample 0.62 s используется и для lamp wheel, и register winding.
- PAPER используется и для viewer pickup, и для sheet feed.
- Footsteps: один sample с pitch variation, не настоящая библиотека разных шагов.
- Отдельного voice bus сейчас нет; voice recording не запрошено как обязательная часть.

До звукаря нужен понятный sound-event inventory и замена временных assets без переписывания
session authority. Не требуется считать нынешние placeholders финальным звуковым дизайном.

### 6. Передача звукарю — это также экспорт

В export_presets.cfg только macOS Playtest; единственный top-level build — прежний macOS zip.
Текущего Windows export preset нет. Платформу получателя ещё нужно подтвердить;
Windows является рабочим предположением, а не фактом о его компьютере.
Для handoff важна свежая standalone build, испытанная без редактора, а не команда запуска Godot.

### 7. Стабильность и экспериментальные границы

Сохранённые 78 suites / 2584 assertions относятся к состоянию до частичной E02.
18 suites имели shutdown resource ERROR. Crash 0xC0000005 после 132 assertions в isolated
shift_director подтверждён; root cause неизвестен. Control и diagnostic 0/10 не доказывают fix.
SHA256 живого shift_director_test.gd совпадает с frozen control snapshot:
93102bcca9189bc55df33596377a52c5c7642dcbc185e5cd7a32a872d357042b.
Это teardown/test-process evidence, не доказательство crash в живой игровой смене.

## Понимание задачи для подтверждения владельцем

1. Целевой результат — одна самодостаточная первая ночь, а не вся кампания.
2. Человек начинает работать через простые действия и контекстную помощь; длинная duty sheet
   остаётся справочником, не вступительным экзаменом.
3. Короткие текстовые мысли Элиаса помогают процедуре, но не находят улику и не выбирают за игрока.
4. Шрифты оцениваем по роли и референсу: печать, handwriting и non-diegetic help не обязаны быть одинаковыми.
5. Отзывчивость — ясное принятие ввода и отсутствие ненужного ожидания, без ускорения Morse,
   движения или переписывания deadline semantics ради ощущения динамики.
6. Временный звук должен давать причинный отклик и оставлять канал Morse читаемым;
   звукарь получает runnable build и event/asset map, не обязан сначала чинить gameplay.
7. Проверка — контракты + live input/frames/audio + настоящий новый игрок; не имитация людей моделью.

## Предположения / ограничения (пока не финальные решения)

- Keyboard/mouse; локальная Windows candidate для handoff, если у получателя другая ОС — export отдельно.
- Без обязательной озвучки мыслей; текст пока на нынешнем английском языке игры,
  русские примеры в обсуждении не равны утверждённой локализации. Возможен отдельный русский UI слой.
- Никакой новой paid generation, uploads, analytics, middleware или campaign framework.
- Content для hints при реализации хранить в resources, не пачке hardcoded narrative strings.
- Owner changes сохраняются, commits только после review explicit paths, push не выполняется.
- Performance/latency target — предложить и измерить; тестовые числа не выдавать за результаты.
- Contextual hints нельзя спамить, перекрывать чтение/ввод, оставлять устаревшими после действия,
  показывать поверх critical copy или брать сведения из WorldState/true_message/expected action.
- Общая completion не должна требовать все art/pacing/telemetry эксперименты до первого новичка.

## Источники, прочитанные в этом ходе

### UI/обучение/звук — практические рекомендации, не доказанный эффект в DEAD WIRE

- https://gameaccessibilityguidelines.com/include-contextual-in-game-helpguidancetips/
  Постепенное введение понятий в контексте действия уменьшает upfront instruction burden.
- https://gameaccessibilityguidelines.com/use-simple-clear-text-formatting/
  Разборчивые формы букв, спокойный фон; mixed case для больших блоков; декоративность не цель сама по себе.
- https://gameaccessibilityguidelines.com/ensure-sound-music-choices-for-each-key-objects-events-are-distinct-from-each-other/
  Различимые звуковые события помогают распознаванию действий. Это не требует звучания каждого hint.

### Описания шрифтов — происхождение дизайна, не историческая сертификация props

- https://fonts.google.com/specimen/IM+Fell+English/about
  Fell types, Oxford XVII век; современная цифровая версия Igino Marini.
- https://fonts.google.com/specimen/Cedarville+Cursive/about
  Основа — handwriting preschool teacher; не реконструкция рабочего почерка 1894.
- https://fonts.google.com/specimen/Libre+Caslon+Text/about
  Оптимизация для body text; источник рисунка — интерпретации Caslon в рекламе 1950-х.
- https://fonts.google.com/specimen/Old+Standard+TT/about
  Реконструкция classicist serif styles late XIX / early XX; regional suitability ещё не проверена.

### Локальные источники предыдущего исследования (не повторный live retrieval)

- docs/research/mechanics_2026-10-10/deadwire_procedural_research.json
- docs/research/mechanics_2026-10-10/learning_research.json
- docs/art/state_2026-10-09/hand_anatomy/01_anatomy_and_writing_brief.md
- docs/art/state_2026-10-09/hand_anatomy/sources.json

## Следующий шаг

Подтвердить понимание цели и предположения. Затем выбрать компактный дизайн onboarding,
типографики и feedback; написать точный implementation plan с RED/GREEN и оконным handoff gate.
Не заявлять ни implementation, ни готовность первой ночи на основании этого аудита.