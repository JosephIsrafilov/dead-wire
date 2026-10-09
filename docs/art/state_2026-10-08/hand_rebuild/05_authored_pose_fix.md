# Исправление кисти — 2026-10-08

## Статус

Реализован новый авторский low-poly вариант фиксированной пишущей позы на существующем
WriterRig. Технические проверки пройдены; геометрия просмотрена в явно помеченном software
preview. **Финальная визуальная приёмка в оконном Godot и видео НЕ выполнены:** политика
текущей сессии отклонила необходимое разрешение. Не считать это полностью закрытой art-задачей.

## Что изменено

- tools/build_writer_hand.gd сокращён: убраны прежний решатель фаланг, Catmull–Rom и
  collision-driven clamp. Вместо них явные точки частей кисти и короткие локальные
  quadratic bevels суставов. Поверхности по-прежнему собираются loft, это НЕ внешний
  Blender-меш и НЕ единая сшитая manifold-сетка.
- Полноценная ладонь, широкий dorsal bridge, отделённое основание большого пальца,
  дуга указательного над пером, опора среднего, отдельный мягкий поджим ring/little.
- Закрыты fingertip caps. Ногти — отдельные ограниченные плоскости; убрано окрашивание
  целого наконечника цветом ногтя. Кожа не затемнялась для маскировки формы.
- Реальные surface names: palm/index/middle/ring/little/thumb.
- Меш кисти 920 triangles (v5: 1150, промежуточное исправление: 1200).
- Перо и elbow_offset_rig не перемещены относительно прежней сцены. Pen child of Hand,
  wrist_travel_limit=0.006, layers=2 и SPECULAR_DISABLED сохранены.
- Источник рукава теперь читает authored settled seat без запуска office simulation:
  устранена зависимость плеча от физического tick и утечки генератора при выходе.
  Все три meshes + scene byte-identical при повторном запуске. Scene diff отсутствует.

## Проверки

- writer_hand_test вырос 19 → 34. Новые контракты: невырожденная геометрия, закрытые
  кончики, surface names, пересечение целых треугольников с convex shaft. Тест clip
  откалиброван на пересекающем треугольнике с тремя внешними вершинами и отдельном
  треугольнике. Допуски старых контактов/clearance не увеличивались.
- RED: names на исходном меше; triangle test нашёл 8 пересечений в первом новом варианте.
  GREEN после изменения самой позы, без clamp: 0 triangle crossings, 0 vertex penetrations;
  upper clearance 4.92 mm; index/middle/thumb имеют 12/11/5 контактных вершин.
- Full regression: **39 suites / 1949 assertions, 0 FAIL**.
- gdlint scripts/ clean; production headless boot 0 errors; git diff --check clean.
- tools/writer_hand_motion_probe.gd запускает настоящую baseline передачу office/session/paper:
  16 glyph contacts, max contact error <0.000001 m, ENTER/WRITING/FINISH/WITHDRAWN.
  Проверка поведения, НЕ визуальная приёмка и НЕ real-input production route.
  При shutdown probe: 37 ObjectDB instances / 7 resources still in use; exit 0 не скрывает
  эти сообщения. Генератор и обычный boot завершаются без них.
- writer_rig_space_test 44/44, transcript_paper_test 134/134 внутри общей регрессии.

## Изображения и воспроизводимость

fix/before и fix/after — одинаковые software камеры/свет, 1000×750, НЕ Godot lighting.
Before — исправленный в предыдущем review v5 с восстановленной ладонью; исходный сломанный
v5 сохранён в старом after/ этого каталога. Превью экспортируют реальный Godot ArrayMesh,
затем рисуют его CPU z-buffer растеризатором (двустороннее плоское освещение, без production
теней/постобработки). Рукав не показан в этих статичных preview; это важное ограничение.

Исходники: fix/sources/export_hand.gd, render_hand.py. Скопировать во временную .dream-loop,
запустить экспорт headless, затем python render_hand.py <output-directory>. Mesh JSON и
motion JSON сохранены рядом. Motion samples содержат frame numbers при fixed-fps 60,
а НЕ wall-clock timestamps или gameplay video.

## Осталось проверить в реальном renderer

1. tools/hand_turntable_capture.gd — 6 ракурсов, сравнить силуэт и обратные стороны.
2. tools/writing_evidence_capture.gd — офисный свет и весь диапазон текста, манжета/рукав.
3. Оконное видео entry/строки/переход/withdrawal и динамическая связь плеча с телом.
4. Production route/playthrough, если визуальный просмотр потребует изменения scene/rig.

Не обещана реалистичная анатомия или отсутствие всех самопересечений между частями кисти.
На software preview новый вариант читается более ясно, но остаётся грубой стилизованной
low-poly кистью. Существующие корни пальцев входят в ладонь отдельными оболочками.

Movement controller, audio, Morse, content и runtime WriterRig не менялись. Ничего не
закоммичено, внешние ассеты/Blender/плагины не скачивались.
