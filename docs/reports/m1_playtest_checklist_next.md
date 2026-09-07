# M1 Manual Playtest Checklist — Next Gate

Цель: ручная проверка core hook и внимания. Это не автоматический тест и не human acceptance до сбора результатов.

## Setup

- Свежий state, production main scene, Forward+, debug inspector выключен.
- Записать разрешение, graphics backend, head bob и устройство вывода звука.
- Не подсказывать слова WATER/WATCHER, commit desk, ожидаемую ветку или момент фигуры.
- Для каждого прогона записать экран или хотя бы timestamp ключевых действий.

## Основной прогон

1. Дать игроку самому найти кресло, ключ и transcript; не объяснять процедуру.
2. Для baseline и attention call отметить: возвращается ли игрок к sounder, смотрит ли на transcript после остановки и не пропускает ли критический сигнал из-за presentation.
3. На третьем сообщении не подсказывать mismatch. Зафиксировать, что игрок делает после окончания письма: transcript, routing board, commit desk или ничего.
4. Если открылась commit-поверхность, проверить, различает ли игрок две записи как физические документы, выбирает ли ровно одну и замечает ли stamp/VOID.
5. После выбора не подсказывать окно. Зафиксировать, видит ли игрок фигуру и связывает ли её с предыдущим commit только по последовательности событий.

## Обязательные ветви

### WATER

- Довести до `file_water`; убедиться, что выбор принимается один раз.
- Проверить `FILED`/`VOID`, блокировку повторного ввода и последующий neutral recovery beat.

### WATCHER

- Повторить с другой физической копией.
- Проверить, что presentation не называет ветку правильной/неправильной, stamp виден, а figure не подтверждает один вариант визуально.

### Lapsed

- На `VERIFYING` или `AWAITING_COMMIT` дождаться deadline без выбора.
- Проверить явный `UNFILED`, отсутствие silent fallback к WATER/WATCHER, продолжение смены и нейтральный consequence path.

### Missed call

- Намеренно смотреть в окно/на routing board во время критического Morse.
- Повторить, слушая из рабочего положения.
- Отметить: слышен ли весь критический сигнал, понятен ли момент возврата к sounder, не маскируют ли его музыка/стингер/визуальный эффект.

## Readability and comfort

- С близкого и обычного рабочего расстояния прочитать labels обеих копий и результат stamp.
- Проверить, что transcript не закрывается WriterRig более чем кратко и рука/перо не flicker.
- Проверить, что дверь и окно остаются отдельными зонами внимания, а routing board требует поворота.
- Проверить 1280x720 минимум; отдельно повторить 1920x1080 и 1280x800.
- Зафиксировать motion discomfort, head-bob complaint, текст слишком мелкий/яркий, усталость от поворотов и проблемы с пространственным звуком.

## Per-player record

```text
player / run / resolution / backend:
mismatch noticed without prompt: yes/no/unclear
next action understood without prompt: yes/no/unclear
transcript inspected before commit: yes/no
WATER branch completed: yes/no
WATCHER branch completed: yes/no
lapsed branch observed: yes/no
critical call unfairly missed: yes/no
stamp and VOID noticed: yes/no
consequence linked to commit: yes/no/unclear
motion/readability/audio issue:
free observation:
```

## Gate interpretation

Собрать минимум два независимых прогона и не подменять их автоматическими assertions. Ориентиры из production spec: не менее 70% замечают mismatch, 80% понимают следующее действие, 70% связывают result со своим commit, unfair critical-call miss менее 10%. До появления WATCHER и lapsed captures эти ветви считаются непокрытыми evidence.
