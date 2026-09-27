# WS3 — Презентация: убрать «дёшево» с кадра

**Цель:** кадр и звук соответствуют GDD §35 (мир в пиксельной сетке, без HUD-строк, свет — мотивированный,
вес в каждом действии). Проблемы `#27–#36` диагноза.

**Зависит от:** WS1 (частично). Задачи 3.1 и 3.2 — **до плейтеста WS2.12**, остальные — параллельно.

**Приёмка любой задачи WS3:** headless-тесты ≠ визуальная приёмка. Каждая задача заканчивается оконным захватом
(`tools/room_overview_capture.gd` o1–o9/c1–c4 или `tools/writing_evidence_capture.gd`) и сравнением с
`docs/art/state_2026-09-27/*.png` (до/после, одним кадром). `python3 tools/vision_check.py` — только если работает
на машине (HANDOVER §6, ловушка 11).

---

## Контракты существующего кода

- `InteractionController` (`scripts/interaction/interaction_controller.gd`): одна метка `prompt_label`, `STATUS_ALPHA = 0.55`
  для неактивных подсказок; строки задаются `Interactable.prompt_text`.
- Источники HUD-строк: `shift_director.gd` константы `PROMPT_*` (13 штук, `Answered — Sender Coming In`,
  `Line Busy — Copying`, `Sender Waiting — Set the Route`…), `m1_office_controller.gd:512/516`,
  `routing_board.gd:78`, `routing_board.tscn:280` (оверлей `[2] HOLD [1] CLEAR EAST`).
- PSX: `scaling_3d_scale` в `m1_office_controller.gd`, шейдер канваса (5 бит, Bayer 4×4, `pixel_size = 1/scale`).
- Слои: рука/рукав `layers = 2`; `WindowBounceLight.light_cull_mask` и `RoomReflection.reflection_mask = 4294967293`
  (исключают слой 2). Новые материалы руки обязаны сохранить это.
- Свет с тенями: `DeskLampLight`, `WindowBounceLight`, `RoutingBoardSconceLight`, `DoorLampLight`, `LandingDawnLight` (+ RevealLight).
- Звук: шины `Master / Ambience / Foley / Telegraph` (`default_bus_layout.tres`), эффектов нет.
  `OfficeAmbience` (`scripts/audio/office_ambience.gd`): room tone, ветер, печь, часы; `set_hush_db()`.
  `tools/generate_action_foley.py` — **общий RNG: новые звуки только дописывать в конец**, иначе меняются все старые.
- Аудио-честность (GDD §7): любой новый звук проходит через правило «не в MARK критической копии» (WS1.6).

---

### Task 3.1 — HUD без статус-строк (#27) — **до плейтеста**

**Правило:** на экране только глагол действия при наведении (`Sit`, `Read Tape`, `Trim Wick`). Состояние
показывает мир: перо движется = «ещё копирую», провод молчит = «нет копии», рычаг в положении = «маршрут записан».
**Files:** четыре источника выше; `interaction_controller.gd` — неактивный интерактив **не показывает текст вовсе**
(удалить ветку `STATUS_ALPHA`, если после задачи у неё нет пользователей — проверить `grep -rn STATUS_ALPHA`).
**RED:** новый `tests/ui/hud_vocabulary_test.gd`: загрузить офис, пройти все `Interactable` в дереве, для каждого
`prompt_text` проверить: ≤3 слова, нет `—`, нет `[`, не входит в стоп-лист
`["No Copy Yet","Still Copying","Line Busy","Route recorded"]`.
**GREEN:** неактивные — `prompt_text = ""`; `PROMPT_RECEIVING` удалить; оверлей доски удалить (метки HOLD/CLEAR EAST
на самой доске уже есть). Не забыть подсказку `Return to the Chair…` — заменить миром: перо замирает,
ручка брошена на лист (уже есть поза).
**Acceptance:** тест + route 57 PASS (тексты `production_evidence_capture.gd` обновить) + кадр o1 без строк.
**Commit:** `fix: the room says what state it is in; the HUD only names verbs`

### Task 3.2 — Физический рычаг маршрута (#27)

**Files:** `scenes/telegraph/routing_board.tscn`, `scripts/telegraph/ui/routing_board.gd`.
Рычаг — два интерактива на ручке (верх = HOLD, низ = CLEAR EAST) вместо клавиш `[1]/[2]`; анимация 0.25 с,
звук `lever_throw` (дописать в конец `generate_action_foley.py`). Клавиши 1/2 оставить как ускоритель, но
без подписи. Положение рычага остаётся до следующего вызова = видимое состояние.
**RED:** `routing_board_test.gd` — `interact(upper)` → маршрут HOLD, `lever_angle > 0`; повтор не меняет факт.
**Commit:** `feat: route with the lever itself`

### Task 3.3 — Рука перестаёт быть пластилином (#28)

**Files:** `tools/build_writer_hand.gd` (генератор, переписывает `transcript_paper.tscn` — HANDOVER §5),
новая текстура `assets/textures/psx_hand_atlas_64.png`.
- UV в генераторе (цилиндрическая развёртка пальцев, планарная ладони) → атлас 64×64: кожа, ногти, складки
  суставов, тень под манжетой. Альбедо кожи ≤ 0.55 (бумага ~0.8 — рука не ярче листа).
- Рукав: ткань в ёлочку 32×32, светлее на 15% на сгибе, `SPECULAR_DISABLED` сохранить; сократить видимую массу
  рукава: плечевой сегмент ниже на 2 см (генератор, `elbow_offset_rig` пересчитывается сам).
**RED (headless):** `writer_hand_test.gd` (или существующий тест руки) — средняя яркость альбедо кожи < яркости
`form_night_copy.png`; меш руки имеет UV (`ARRAY_TEX_UV` не пуст); слой 2 сохранён.
**Acceptance:** `tools/hand_turntable_capture.gd` + `writing_evidence_capture.gd`; рука не отделяется от манжеты
на 8 ракурсах (запястье ≤ 6 мм — существующий тест риг держит).
**Commit:** `feat: the hand gets skin, knuckles and a cuff shadow`

### Task 3.4 — Пятно у нижнего края кадра (#29)

Найти меш: оконный кадр сидя → `javascript`-подобно нельзя; сделать `tools/debug_near_plane_probe.gd`
не нужно — достаточно временно выключать `layers` по группам в `room_overview_capture.gd` c1. Кандидаты: левая рука
оператора (если есть), колено из `operator_seat`. Решение — поднять `near` камеры сидя с 0.05 до 0.08 **или**
убрать меш из слоя камеры сидя. Проверка: кадр c1 без телесного пятна; рука-писарь не срезается ближней плоскостью.

### Task 3.5 — Вьюер документов в пиксельной сетке (#30)

**Files:** `scripts/ui/document_viewer.gd`.
Документ рендерится в `SubViewport` 320×240 (шрифты IM Fell / Cedarville, `texture_filter = nearest`), затем
масштабируется целым множителем; фон — затемнённый кадр комнаты (не модальная кремовая панель), бумага
подсвечена лампой (`modulate` от `LampLife.wick`, связка с WS2.7).
**RED:** viewer test — `get_viewport_texture_size() == Vector2i(320, 240)`; масштаб — целое число.
**Commit:** `feat: documents are read in the same pixel grid as the room`

### Task 3.6 — Окно перестаёт быть телевизором (#31)

**Files:** `scenes/office/m1_office.tscn` (экстерьер), текстура `m1_night_exterior`.
- Альбедо фона ≤ 0.6 (сейчас >1 — светится); 3 слоя параллакса (холмы 12 м, столбы 25 м, небо) вместо плоскости.
- Отражение лампы в стекле: roughness стекла 0.35, отражение ≤ 30% размера — перестаёт читаться как НЛО.
- Луна — не диск: гало в текстуре неба, яркий источник — только `MoonSpot`.
**Acceptance:** кадры o2/o5 до/после; фигура (WS1.7) всё ещё различима в зазоре.

### Task 3.7 — Бювар, органайзер, подпись доски (#32)

- `DeskBlotter`: `roughness = 1.0`, `specular = 0.1` → перестаёт быть серо-шалфейным.
- Бланки в органайзере: альбедо 0.62 (не ярче листа на столе).
- `routing_board.tscn`: подпись CLEAR EAST — `font_size` −10% или ширина доски +2 см; проверить кадром c3.
**RED:** `desk_geometry_test.gd` — метки доски в пределах рамки (AABB текста ⊂ AABB доски).

### Task 3.8 — Печь и стол подшивки (#33)

- Печь: заменить CSG-кучу на low-poly меш (`tools/build_stove.gd`, по образцу `build_writer_hand.gd`: генератор
  → `.res`), дверца с решёткой; свет печи — `OmniLight3D` range 1.8, энергия с мерцанием 0.9–1.1, **без теней**.
- Стол подшивки: лампа-«пятно» над ним или светлая скатерть; штамп и корзина копий читаются силуэтом с порога.
**Acceptance:** кадр с порога (o4) — стол подшивки узнаётся за 2 с (спросить на плейтесте).

### Task 3.9 — CSG → меши, тени (#34)

- `tools/bake_csg.gd`: для каждого `CSGCombiner3D` в `m1_office.tscn` — `bake_static_mesh()` → `.res` в
  `assets/meshes/office/`, заменить узел `MeshInstance3D` с тем же transform и материалом. Сначала один узел,
  кадр, потом остальные. **Не использовать `rewrite.py`** (HANDOVER §6).
- Тени: оставить `DeskLampLight` + `WindowBounceLight`; `RoutingBoardSconceLight`, `DoorLampLight` — без теней;
  `LandingDawnLight`/`RevealLight` — `shadow_enabled` включать только в `DawnRitual.begin()`.
**RED:** `atmosphere_test.gd` — до рассвета ровно 2 света с тенями; после `begin()` — 3.
**Acceptance:** `grep -c 'type="CSG' scenes/office/m1_office.tscn` → 0 (сейчас 62); кадры o1–o9 совпадают.

### Task 3.10 — Текстуры в одной системе (#35)

Все фото-текстуры Poly Haven: даунскейл до 128 px (`nearest`), без normal map, квантование палитры 32 уровня —
скрипт `tools/psx_texture.py` (`.venv-tools`, PIL). Обои: контраст полос −30%. Дымоход — глазурь темнее.
Список исходников — `docs/third_party_assets.md` (обновить размеры).

### Task 3.11 — Шины и пространство (#36)

**Files:** `default_bus_layout.tres`.
- `Master`: `AudioEffectLimiter` (ceiling −1 dB).
- `Ambience` и `Foley`: send в новую шину `Room` (`AudioEffectReverb` room 0.25, damping 0.7, wet 0.12 — маленькая
  деревянная комната).
- `Telegraph`: **сухая** (читаемость, GDD §7) — только ранние отражения, wet ≤ 0.05.
**RED:** `audio_bus_test.gd` — шина Telegraph не имеет реверба с wet > 0.05; Master имеет лимитер.

### Task 3.12 — Фоли: вариации (#36)

Дописать в конец `generate_action_foley.py` (порядок RNG!): шаги ×4 (доска/половик), скрип стула ×2, перо — петля
штриха 400 мс с отрывами вместо 55-мс тика (ведёт `WriterRig` по `glyph_contact`, не по таймеру). Гейт
транзиентов: у каждого клипа атака ≤ 5 мс, хвост ≤ −60 dB в конце (проверка в самом генераторе assert-ом).

### Task 3.13 — Поющий провод, room tone, погода, рассвет (#36)

- «Поющий провод»: тонкий гул 180–240 Гц с медленной модуляцией, громче при ветре; стихает во время хуша
  (`UneaseDirector`) — это тот же канал, что WS2.8.
- Room tone: два варианта, кроссфейд раз в 90–150 с (seed смены).
- Погода: облака `MoonWeather` → +2 dB ветра; рассвет → птица одна, далеко, после `DawnRitual.begin()` + 20 с.
- Профиль ночи `data/audio/night_1_audio.tres` (громкости, seed, включённые слои) — подготовка к WS4 NightData.

---

## Критерии готовности WS3
- [ ] 3.1 HUD  - [ ] 3.2 рычаг  - [ ] 3.3 рука  - [ ] 3.4 пятно  - [ ] 3.5 вьюер  - [ ] 3.6 окно  - [ ] 3.7 стол
- [ ] 3.8 печь  - [ ] 3.9 CSG/тени  - [ ] 3.10 текстуры  - [ ] 3.11 шины  - [ ] 3.12 фоли  - [ ] 3.13 слои звука
- Контакт-лист «после» в `docs/art/state_<дата>/` рядом со «до».
