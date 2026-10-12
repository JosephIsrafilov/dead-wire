# DEAD WIRE — результат instrument-first

## Изменено

Три близких рабочих предмета получили7 Blender-authored static/moving assemblies:
key static/lever, sounder static/armature, register static/spool/stylus.3332 triangles,
256px six-tile shared authored atlas, nearest, ограниченная шероховатая латунь/wood/
iron/coil/ebonite/paper. Никаких downloaded museum photos/мешей/логотипов.

В production заменено отображение, не контент/логика: исходные colliders/pivots,
key controls, MARK/GAP armature, регистр и бумага остаются на прежних узлах.
Старые blockouts скрыты (reversible). Кисть, фон/свет, UI, звук, movement, сценарии,
тайминги и объективная лента не редактировались.

Источник: `sources/dead_wire_instruments_v1.blend` (7мешей, atlas packed, assembly layout).
Builder:`tools/build_instruments_blender.py`; importer:`tools/import_instruments.gd`.
Runtime:`assets/models/instruments_v1/*.res` и `assets/textures/instruments_v1/`.
Museum catalogue text/reference URLs в manifest/provenance; не точная историческая реплика.

## Проверено исполнением

- instrument_art_test: RED на отсутствующий mesh → GREEN71; затем RED на coil clearance
  → GREEN72 после уменьшения катушек/контактной стойки.3332 triangles внутри бюджета.
- Последний полный runner:46 suites/2094 assertions/0 assertion failures.
  Полные per-suite logs и `verification/regression.json` сохранены.
- `gdlint scripts/`: clean.
- Production windowed route:57PASS/0failures/6shots, WASD/input/physics,0teleports.
- Автоматическая полная ночь:0failures/14shots, запись Master; телепорты и сокращённый
  answer beat НЕ являются human playtest/доказательством pacing.
-13before+13after720p кадров, актуальный comparison.png;90frame фиксированный motion
  capture → silent MP4 encoded30fps. Это mechanism test, не realtime timing video.
- Проверен сохранённый .blend отдельным Blender process:7meshes и packed atlas.
- После финализации источника повторно Godot import/importer/instrument72green.

## Не решено / не заявлено

До прохода intro_music fadeFAIL воспроизвёлся; в первом regression после интеграции
shift_director crash139. Изоляция/repeat позднее прошли без правок. Причины **не установлены**.
Green означает assert/exit status, не error-free:14suites содержалиERROR-lines (shutdown
resources, detached OfficeFoley/global_transform), production boot10ObjectDB/2resources,
окна7TextureRID leaks. Это продолжение известных проблем, не новый стабилизационный pass.

Image review endpoint404, поэтому художественная/эмоциональная приёмка **открыта**.
Кадры/MP4 передаются владельцу без выдуманного visual score.1080p и human playtest не делали.
Повтор GLB source rebuild:5/8байт-хэшей совпали (atlas+4moving exports),3static GLB различались.
Нельзя выдавать pipeline за byte-identical. Геометрия/материалы/метры импортированы и
контрактно проверены; exporter metadata/naming может различаться, причины байт-разницы
не разобраны. Hash report сохранён.

## Gameplay brainstorm (план, не реализация)

`docs/plans/2026-10-10_INSTRUMENT_FIRST.md`:verify→commit, neutral filing/amendment input,
обучение независимой сверке обычной работой, контактные следы решений, тот же лист при
подъёме, tension от необходимости отвернуться и осмысленная тишина без chores. Следующий
полноценный patch:P0neutral choices+amendment input/outcome; простая замена captions с
оставленным automatic WATER не считается исправлением. Новые ночи/город/канон вне scope.

## Git

Прежнее существовавшее состояние:f82939d9995ec2761e730b1fe8dcaa033bf0be41, pushed и exact
remote ref проверен. Этот новый instrument/design pass **оставлен незакоммиченным**,
поскольку просьба пользователя commit/push относилась к существовавшему перед ним состоянию.
