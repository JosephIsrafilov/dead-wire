# DEAD WIRE — краткие выводы исследования

Research evidence:docs/research/mechanics_2026-10-10/. Parent mechanically verified all38 quoted
excerpts from12distinct developer URLs against saved public source text; not12independent studies.
Also read Kelsey Beachum GDC2021 slides, learning/accessibility guidance and inkle interviews.

## Основная связь
Процедура ясна → обычная работа даёт компетентность → редкое нарушение вызывает собственный
вопрос → надёжные физические доказательства → решение игрока → сохранённый, честно показанный итог.
Mystery не равно путаница управления. Physical attention cost не равно input lag. Больше задач
не автоматически лучше хоррор: внимание нужно и работе, и интерпретации угрозы.

## Findings before implementation (historical baseline)
The defects below were observed before the accepted mechanics patch; refer to result/current tests for resolution.
- P0filing выдаёт WATER; AMEND выбирает готовый file_water, нет correction input/wrong amendment.
- P0tape wrap выбрасывает GAP column; MARK3/6 одинаковые. Internal American Morse pauses significant.
  Не утверждать, что обычные encoded M1 telegrams обязательно теряют MARK:обычный loss whitespace.
- Cancelled calls не получают real silent-boundary; stored in-flight event имеет planned duration.
  Blind synthetic12-unit gap не решает temporal truth, нужен agreed model.
- RoutingBoard записывает intent до acceptance; rejected late route может оставить false status/foley.
- First2messages говорят CLEAR EAST/HOLD напрямую:ledger не нужен для правильного решения.
- Standing order file every copy не соответствует route-as-file текущим сообщениям1/2.
- Commit budget30s от signal end; copy backlog+inspection+decode+travel внутри него. Adequacy untested.
- OfficeFoley deferred bind может выполниться на detachedoffice; current focused тест это показал.

## Чего не добавлять пока
Full town/nights, combat, sanity bar, постоянные скримеры, новые chores, fake tape/автоответ,
универсальная каллиграфия, mandatory full Morse learning, лишние slow interactions.

## Не забыть рабочее
Archive accessible, viewer/key gates, tick-once/ink-contact, separate state stores, physical route
lever and ledger records already implemented. Не "чинить" заново. Instrument pass сохранить.
