# DEAD WIRE — продолжение на другом устройстве

Дата: 2026-10-08 (Asia/Baku). Ветка: `codex/hand-rebuild-handoff`.
Это checkpoint незавершённой работы, НЕ визуально принятая рука.

## Что обнаружено после прерывания

- Активные генератор, тест, сцена, hand/cuff meshes идентичны recovery-копиям предыдущего hand anatomy pass; forearm идентичен `.recover_hand_2026-10-08_redo`.
- Новый полноценный rebuild НЕ завершён: в `docs/art/state_2026-10-08/hand_rebuild/` только `before/`, нет итогового after/video.
- Последний anatomy pass: уменьшены пропорции, добавлены 6 поверхностей и ногтевые плоскости, centripetal interpolation и clearance/clamp. Владелец отверг визуальное качество. Отчёт anatomy pass сохраняется как история, не как разрешение считать задачу закрытой.
- Movement feel, лента/commit и звук в этой рабочей копии не исправлены.

## Проверки checkpoint

Повторно выполнены перед переносом: полная регрессия 39 suites / 1934 assertions; gdlint scripts/; headless boot. Результаты: regression exit 0 (39/1934, 0 FAIL), lint exit 0, boot exit 0 / 0 errors / warning о 6 ObjectDB instances при выходе. Оконные route/playthrough в этом checkpoint не перезапускались; исторические 57/73 PASS не выдавать за свежую проверку.

## С чего начать

1. `AGENTS.md`, `docs/HANDOVER.md`, `docs/plans/next/00_INDEX.md`.
2. `docs/reports/2026-10-08_NATURALNESS_DREAD_AUDIT.md`.
3. `docs/plans/next/2026-10-08_HAND_ANATOMY_BRIEF.md` — контекст, не продолжать старую подгонку вслепую.
4. Просмотреть `docs/art/state_2026-10-08/hand_anatomy/after/` и `hand_rebuild/before/`.
5. `tools/build_writer_hand.gd`, `tests/telegraph/writer_hand_test.gd`, `scenes/telegraph/transcript_paper.tscn`, существующий WriterRig и тесты.
6. Godot import на свежем checkout, затем регрессия. `.venv-tools` и машинные MCP не переносятся Git: использовать среду нового устройства, не копировать абсолютные пути macOS. Если RTK отсутствует — установить/согласовать альтернативу; не предполагать наличие всех инструментов.

## Новое требование владельца

Переделать руку до убедительного игрового качества, а не косметически поправить тесты. Сначала силуэт/ладонь/фаланги/хват в нейтральном и production свете. Затем материал. Допустима контролируемая authored topology вместо трубок. Никаких случайных сторонних ассетов, установки Blender/MCP без согласования, full-body/IK.

- Ладонь не блок; естественное основание большого пальца и web spaces.
- Пять пальцев, осмысленные фаланги; ring/little без петель, бугристого комка и открытых торцов.
- Естественный tripod grip, не формовать анатомию клином вокруг пера ради GREEN.
- Манжета связная, плечо стабильно, рукав не чёрная масса в кадре.
- Оконные BEFORE/AFTER в одинаковых условиях, 720p/1080p, плюс видео entry/письмо/переход строки/withdrawal.
- Предыдущий отчёт не означает принятие: итог только «вариант готов к проверке владельцем».

## Конкретные технические долги нового генератора

- `_finger_chain`: centre=midpoint+bow*sagitta и radius=s/2+L²/(8s) несогласованы; концы не лежат на указанной окружности. Две конечные точки затем переставляются. Доли 45/30/25 не гарантируют реальные длины фаланг.
- У пальцев `cap_end=false`: обещанные закрытые подушечки могут не создаваться.
- `_clamp_vertex` скрывает плохую позу: нужна диагностика количества и max displacement по части. Коррекция не является доказательством хорошей анатомии.
- Генератор читает прежний Shaft frame, а Pen transform пишет в конце: проверить отсутствие зависимости от прошлого запуска.
- `WRIST_OFF` в тесте продублирован; это не общий источник.
- Тест отсутствие вершин внутри пера не исключает triangle intersections; half-space distance не точная внешняя mesh distance. Не ослаблять допуски ради зелёного результата.
- Centripetal spline не гарантирует отсутствие любых пересечений всей объёмной руки; arc/chord>1 сам по себе не доказывает петлю.

## Сохранить контракты

Pen child of Hand; wrist_travel_limit=0.006; layers=2/masks; cloth SPECULAR_DISABLED; time-once advance_presentation; один glyph/tick; ink только glyph_contact; reset/suspend/resume без дрейфа. Источник генерации и Pen/elbow_offset_rig согласованы; повторная генерация всех hand/cuff/forearm без накопительного изменения позы.

Scope: рука/рукав/источник меша, сцена бумаги, релевантные tests/capture. Без player movement, окна, HUD, сценариев, морзе, DSP/WAV. Звук позже со звукарём. Не запускать rewrite.py.

## Восстановимые материалы

`docs/reports/evidence/hand_handoff_2026-10-08.tar.gz` содержит recovery-копии и локальные debug probes, ранее скрытые `.git/info/exclude`. Это архив для диагностики, не production код. Распаковывать в отдельную временную папку, не поверх checkout. Пробы не считаются авторитетной проверкой; некоторые используют приблизительную геометрию.

Не перенесены: `.godot/`, `.venv-tools/`, машинные ключи/конфиг, `.DS_Store`, распакованный `builds/dead-wire.app`. Site-redesign brief и исходный staged index владельца не включались в этот hand checkpoint.
