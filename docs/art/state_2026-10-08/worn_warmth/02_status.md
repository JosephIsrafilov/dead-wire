> Исторический статус до разрешённого перехода на локальные бесплатные ассеты.
> Актуальное продолжение: [03_local_asset_integration.md](03_local_asset_integration.md).

# Статус pass — 2026-10-08

## Выполнено

- 01_emotional_brief.md: русский бриф, исследовательские выводы с источниками,
  три существующие передачи и вопросы для короткого слепого просмотра.
- Четыре точных независимых generation prompts и JSONL jobs сохранены рядом.
- tools/psx_texture.py: supplied image → 128×128 BOX reduction → optional matching
  существующей mean RGB → четырёхтексельная seam blend → 32 levels/channel.
  Это обработка предоставленного изображения, НЕ процедурная подмена изображения.
- tools/psx_texture_test.py: размер/палитра/idempotency, границы повторения, mean RGB.
- В настоящей office scene убран grazing specular у существующего BlotterFelt:
  specular_mode=SPECULAR_DISABLED, без изменения tint, roughness, geometry/light.
  desk_geometry_test: три новых контракта; RED на старом sheen, GREEN после исправления.

## Что НЕ получилось

**Ни одной новой текстуры не получено и не подключено.** Built-in image_gen отсутствует.
После разрешения владельца вызван неизменённый bundled CLI imagegen с gpt-image-2,
1024×1024, quality high, отдельно по каждому prompt. Для всех четырёх запросов API
вернул data item без b64_json; CLI упал в base64 decoding на NoneType:

| Материал | Время API ответа | Результат |
|---|---:|---|
| wallpaper | 166.7 s | b64_json absent; exit 1, no PNG |
| wood | 33.3 s | b64_json absent; exit 1, no PNG |
| baize | 26.3 s | b64_json absent; exit 1, no PNG |
| paper | 40.9 s | b64_json absent; exit 1, no PNG |

Не установлено, содержал ли ответ URL, пустую generation или другой несовместимый формат:
CLI не сохранил полный response. Не заявлять, что изображения были успешно сгенерированы.
Не изменён skill CLI и не создан custom SDK runner. Повторные платные запросы на том же
неподдерживаемом формате не отправлялись. Billing провайдера не проверялся.
Запрошено API имя gpt-image-2; фактический routing на reli/gpt-image-2 / версия 2.5
не подтверждены. Старые источники, бумажные формы, лента и карты сохранены.

**Оконная приёмка не выполнена:** запрос запуска room_overview_capture отклонён
политикой approvals Never. Не запускался headless framebuffer вместо неё. Полный
арт-пакет не существует, поэтому статус — неполная реализация, не accepted candidate.

## Как продолжить с настоящими исходниками

После восстановления совместимого image-generation пути сохранить 1024×1024 PNG
в output/imagegen/worn_warmth/ под именами *_source_v1.png, посмотреть originals;
далее игровые версии писать под отдельными именами в assets/textures/worn_warmth/:

- wallpaper: --tileable --match materials/style_tests/textures/psx/psx_wallpaper_stripe_128.png
- wood: --tileable --match materials/style_tests/textures/weathered_brown_planks_diff.png
- baize: --tileable; сохранить tint BlotterFelt, не делать highlight/normal map
- paper: --match materials/style_tests/textures/paper_worn_diff.png; только blank surfaces

Команда: .venv-tools/Scripts/python.exe tools/psx_texture.py SOURCE OUTPUT <flags>.
Обработка seam не доказывает отсутствие заметного grid в 3×3; обязательно посмотреть.
Проверить четыре stripe-периода исходника и отсутствие global illumination gradient.
Сукно должно оставаться тихим/матовым. Если mean-matching даёт clipping или теряет цвет,
исправить исходник/выбор изображения, не поднимать свет всего офиса.

Подключать только m1_wall_plaster, m1_wainscot_wood, paper_log и BlotterFelt.
Все прежние источники и material tint/uv scales сохранить. Не заменять генератор обоев,
не редактировать shared desk wood всех моделей и printed form textures.
Потом import → same-camera windowed 720p/1080p before/after → regression/lint/boot.
Не путать texture tests с эмоциональной или визуальной приёмкой.

Финальная проверка и наблюдения boot дописаны ниже по фактическим результатам.

## Фактическая финальная проверка

- Full regression: **39 suites / 1952 assertions / 0 FAIL**. desk_geometry_test 26/26.
- Python pipeline: 3 unittest cases прошли под .venv-tools с Pillow 12.3.0 / numpy 2.5.3.
- gdlint scripts/ чистый; git diff --check чистый.
- Headless boot exit 0, НО shutdown: 8 ObjectDB leaks / 1 resource still in use (ERROR).
  Повтор с исходным BlotterFelt (без нового specular_mode) дал тот же shutdown error,
  затем изменение восстановлено. Значит это воспроизводимо и без текущей правки;
  требование «boot 0 errors» НЕ выполнено, причина не устранена в этом material pass.
- Из production изменена ровно одна строка office scene; lights/geometry/content/audio
  неизменны. Существующие hand changes сохранены. Коммита/push нет.
