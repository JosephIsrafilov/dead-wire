# DEAD WIRE - M1 Core Hook Production Spec

Дата: 2026-09-04  
Статус: approved for implementation  
Scope owner: orchestration / design review

## 1. Цель инкремента

Довести текущую смену до законченного психологического цикла:

```text
answer -> listen -> inspect -> verify -> commit -> visible result -> consequence beat
```

Игрок должен самостоятельно обнаружить, что объективный сигнал `WATER` и запись
Элиаса `WATCHER` расходятся, после чего осознанно зафиксировать одну из версий.

## 2. Подтвержденное текущее состояние

- `TelegraphSessionController` проигрывает `true_message`, а `TranscriptPaper`
  одновременно показывает `written_transcript`.
- Запись раскрывается по общему ratio длительности. Для `WATER -> WATCHER` это
  не соответствует буквенным границам.
- Scenario 3 завершает session сразу после передачи: commit отсутствует.
- Window figure запускается на `0.8 s`, примерно за `1.26 s` до первой видимой
  отличающейся буквы.
- Transcript является `Label3D`; руки, карандаша и физического письма нет.
- Routing board имеет семантику `CLEAR EAST / HOLD` и не подходит для выбора
  источника истины.

## 3. Assumptions и ограничения

- Godot 4.7, single-player, local state, Steam/PC target.
- Objective Morse и его scheduler остаются детерминированными.
- Первые два сценария сохраняют текущие routing outcomes.
- WorldState хранит результат в мире; KnowledgeState хранит осознание Элиаса.
- Критический текст остается читаемым при `1280x720` и текущем render scale.
- Нет network/privacy surface; telemetry не входит в этот инкремент.
- Нельзя вводить game over за ошибку или пропуск. История продолжает учитывать
  решение.

## 4. Рассмотренные подходы

### A. Strict binary verification gate - выбран

После передачи игрок осматривает transcript, затем отдельная diegetic commit
surface предлагает конкретные записи:

- `CORRECT COPY: WATER`
- `FILE COPY: WATCHER`

Плюсы: ясная ответственность, отсутствие семантического конфликта с routing
lever, ограниченный и тестируемый state machine.

### B. Трехсторонний выбор с повтором - отложен

`WATER / WATCHER / REQUEST REPEAT` сильнее как расследование, но требует replay
state, ограничения повторов и правила для уже написанного transcript. В P0 это
создает optimization loop и размывает первый выбор.

### C. Переиспользовать routing board - отклонен

Меньше сцен и кода, но железнодорожный lever отвечает на вопрос о маршруте, а не
о доверии записи. Это экономит реализацию ценой неверного mental model игрока.

## 5. Interaction design

### 5.1 Нормальная процедура обучения

Все три M1-сообщения требуют осмотра transcript после передачи.

Для Scenario 1 и 2:

```text
listen -> inspect transcript -> routing board unlocks -> route
```

Это учит игрока смотреть на бумагу до аномалии. Игра не добавляет новый prompt
только на Scenario 3 и не выдает mismatch интерфейсом.

Для Scenario 3:

```text
listen WATER while hand writes WATCHER
-> inspect transcript
-> commit one concrete record
-> selected line receives a physical stamp
-> short recovery pause
-> window figure becomes pending
-> shift can finish only after consequence hold
```

### 5.2 Commit surface

Используется отдельная world-space `CopyCommitDesk`, не routing board и не
fullscreen meta-menu.

- До transcript inspection она неактивна.
- После inspection доступны ровно две физические controls/lines.
- Labels называют конкретные записи, а не `TRUST HEARD / TRUST WRITTEN`.
- После выбора поверхность блокируется exactly once.
- Выбранная строка получает чернильный stamp; другая визуально гаснет.
- Double input и input после commit являются no-op.

### 5.3 Discovery rule

UI не показывает отдельное сообщение `MISMATCH DETECTED` и не декодирует Morse.
Нормальная процедура предоставляет доказательства, но вывод делает игрок.

## 6. State machine

Логические состояния session:

```text
IDLE
-> READY
-> RECEIVING
-> VERIFYING
-> AWAITING_ROUTE | AWAITING_COMMIT
-> CONSEQUENCE (Scenario 3 only)
-> COMPLETE
```

Инварианты:

1. `VERIFYING` начинается только после завершения signal и transcript writing.
2. Transcript inspection exactly once переводит session дальше.
3. Scenario 1/2 переходят в `AWAITING_ROUTE` только после inspection.
4. Scenario 3 переходит в `AWAITING_COMMIT` только после inspection.
5. Commit до inspection не меняет WorldState/KnowledgeState.
6. Valid commit записывается ровно один раз.
7. Timeout создает отдельный `lapsed` outcome и не выбирает версию автоматически.
8. `session_completed` не испускается до завершения consequence hold.
9. Reset/cancel уничтожает pending timers, cues, animation и figure request.

## 7. Data contracts

### 7.1 TelegraphScenarioData

Добавить data-driven поля с безопасными default, чтобы существующие сценарии не
получали скрытого поведения:

```text
requires_transcript_verification: bool
transcript_reveal_cues: PackedFloat32Array
commit_options: Array[TelegraphCommitOption]
commit_lapsed_world_fact: String
commit_lapsed_knowledge_fact: String
consequence_event_id: String
consequence_delay_seconds: float
consequence_hold_seconds: float
```

`transcript_reveal_cues` - монотонные normalized timestamps на каждый видимый
glyph. Это authored cue map, а не равномерное деление total ratio. Пробелы не
требуют отдельного cue. Пустой массив сохраняет legacy fallback для сценариев,
которые еще не мигрировали.

### 7.2 TelegraphCommitOption

Минимальный Resource:

```text
action_id: StringName
display_label: String
world_fact: String
knowledge_fact: String
result_text: String
```

Нельзя моделировать эти варианты как `correct/incorrect`: objective signal
известен системе, но сюжетный смысл выбора должен оставаться неоднозначным.

### 7.3 M1 facts

```text
WorldState:
  core_hook_filed_water
  core_hook_filed_watcher
  core_hook_commit_lapsed

KnowledgeState:
  verified_core_hook
  committed_water_core_hook
  committed_watcher_core_hook
  core_hook_commit_lapsed
```

## 8. Transcript authorship animation

Выбран world-space rig, закрепленный на transcript pad:

```text
TranscriptPaper
  PaperMesh
  Label3D
  WriterRig
    Sleeve
    Wrist
    Hand
      Pen
        Shaft
        Nib
```

Presentation states:

```text
HIDDEN -> ENTER -> CONTACT -> WRITING <-> LETTER_PAUSE -> FINISH -> WITHDRAWN
```

Правила:

- Sleeve уходит за ближний край кадра и сообщает связь с телом Элиаса.
- Pen всегда остается child руки и не может выглядеть самостоятельным объектом.
- Один writer state machine; не создавать Tween на каждый Morse mark.
- Nib достигает позиции glyph до появления glyph.
- На inter-letter gap pen слегка приподнимается.
- После writing рука отходит, transcript остается.
- Clear/load/cancel полностью сбрасывает rig и active tween.
- Нет collision, IK, imported character rig и procedural stroke simulation.

## 9. Consequence design

Branch-visible result состоит из выбранного физического stamp и сохраненного
fact. Это честно показывает, что решение принято и будет иметь продолжение.

Window figure не является правильным/неправильным payoff:

- Она запускается после одинаковой recovery pause для обоих вариантов.
- Она не ветвится по commit, иначе визуально подтверждает `WATCHER`.
- Если окно находится в поле зрения, событие остается pending; lifetime начинается
  только после фактического появления, а не пока figure скрыта.
- Session завершает consequence только после минимального observable hold.

Полноценные разные внешние последствия facts появятся в следующем day scene. В
этом инкременте нельзя симулировать их текстовой фразой как уже реализованный мир.

## 10. Timeout и recovery

- Общий deadline продолжает контролировать `ShiftDirector`.
- Timeout во время `VERIFYING` или `AWAITING_COMMIT` записывает lapsed facts.
- Commit desk показывает `UNFILED`, затем идет тот же нейтральный consequence beat.
- Нет silent fallback к `WATER` или `WATCHER`.
- Каждый terminal path обязан разблокировать progression смены.

## 11. Accessibility

- Ни одно решение не кодируется только цветом.
- Commit controls имеют focus/navigation и используют InputMap actions.
- Morse rhythm не заменяется готовым текстом.
- Visual pulse/armature movement остается синхронным источником timing.
- Writer rig не перекрывает более 15% transcript.
- Hand/pen animation не использует flicker и не зависит от head bob.

## 12. Verification plan

### Automated

- Cue validation: length, monotonicity, bounds, spaces policy.
- Transcript glyph count на каждом authored cue.
- Writer position и lifecycle на 25/50/75/100% progress.
- Out-of-order, double commit и commit-before-inspection являются no-op.
- Оба commit facts и lapsed fact mutually exclusive.
- Scenario 1/2 не могут route до inspection и сохраняют прежние outcomes.
- Figure отсутствует во время `RECEIVING` и запускается после commit/timeout.
- Figure lifetime начинается после visible resolution.
- Reset/cancel не оставляет hand, stamp, timer или pending event.
- Startup-to-end smoke проходит через real main scene и InputMap.
- Полный regression suite остается green.

### Runtime evidence

- Capture live writing на 25/50/75%.
- Capture обе stamped branches.
- Capture mismatch window без figure.
- Capture delayed figure после recovery pause.
- Проверить `1280x720`, `1920x1080`, `1280x800`.

### Blind playtest gate

- >=70% замечают mismatch без подсказки.
- >=80% понимают следующее действие.
- >=70% приписывают запись руке Элиаса, не UI или магической бумаге.
- >=70% связывают stamp/result со своим commit.
- Unfair miss критического сигнала <=10%.

## 13. Не входит в P0

- Repeat/replay mechanic.
- Полный daytime town и Nights 2-6.
- Generic quest/evidence framework.
- Save-slot/versioning migration.
- Combat, chase, monster AI и random scare director.
- Broad PSX shader rewrite.
- Full character body, IK или mocap handwriting.
- Marketing content production.

## 14. Decision log

| Решение | Альтернативы | Причина |
|---|---|---|
| Strict binary gate | repeat; no commit | Заканчивает ответственность без optimization loop |
| Universal transcript inspection | только Scenario 3 | Не выдает аномалию новым правилом |
| Dedicated CopyCommitDesk | routing board | Сохраняет корректную семантику предмета |
| Concrete labels | HEARD/WRITTEN | Не объясняет психологическую механику мета-языком |
| Authored cue map | uniform ratio | Поддерживает unequal strings и letter timing |
| Anchored world rig | ghost pen; camera viewmodel | Стабильный physical contact и меньше clipping |
| Stamp as immediate branch result | figure branch | Не превращает фигуру в ответ на mystery |
| Figure after neutral pause | `0.8 s` during signal | Сначала discovery, затем отдельный dread beat |
| No repeat in P0 | replay state | Сохраняет scope и силу первого commit |

## 15. Implementation ownership

- Logic worker: scenario resources, state machine, commit contracts, facts, unit and
  integration tests.
- Presentation worker: transcript cue consumer, WriterRig, CopyCommitDesk visuals,
  animation lifecycle and presentation tests.
- Orchestrator: integration, main-scene wiring, consequence timing, runtime capture,
  full regression and adversarial review.

