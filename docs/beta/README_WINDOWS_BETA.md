# FORM 19 — Windows Playtest Build

## Русский (по умолчанию)

### Как запустить
1. Распакуйте весь ZIP-архив целиком в любую папку с правами на запись (не запускайте прямо из архива).
2. Запустите `dead-wire-windows-beta-x86_64.exe` (редактор Godot не требуется).
3. Если Windows SmartScreen покажет предупреждение о неизвестном издателе — это неподписанная бета-сборка без коммерческого сертификата; продолжайте запуск только если доверяете отправителю.

### Что в этой сборке
- Главное 3D-меню станции **FORM 19** (язык по умолчанию — русский, переключить `RU | EN` можно прямо на титульном экране или в настройках).
- Ночной подход к станции Блэк-Крик (апрель 1890).
- Полная первая ночная смена (Ночь 1) за телеграфным постом.
- Рассветная дорога домой в пансион Харгроув, переход ко сну и дневной Блэк-Крик (включая чтение местной газеты и посещение салуна «Медный Мул»).

### Управление
- **Ходьба (улица, станция, помещения):**
  - `W / A / S / D` — движение
  - Мышь — осмотр
  - `E` — взаимодействие (сесть за стол, открыть дверь, прочесть газету или записку)
  - `Esc` — пауза или закрыть открытый документ
  - `J` / `F1` — повторить текущее напоминание
- **За телеграфным столом (круговой обзор 360°):**
  - `A` / `D` (или стрелки на экране `‹` / `›`) — поворот по кабинету (`Стол ↔ Поездной сигнал ↔ Дверь ↔ Подшивка`)
  - `W` — вернуться лицом к столу; `S` — повернуться к двери
  - `ЛКМ` — взаимодействие с приборами, бумагами, рычагом и планшетами
  - `Пробел` или удержание `ЛКМ` на латунном ключе — ответить по линии
  - `ПКМ` / `Q` — прильнуть к окну (в настройках доступно переключение вместо удержания)
  - Колесо мыши — регулировать фитиль лампы
  - `Tab` — встать из-за стола (на рассвете)
- **Чтение документов:**
  - Колесо мыши / `Page Up` / `Page Down` / `↑` / `↓` (`Home` / `End` — в начало/конец) — прокрутка
  - `Esc` — закрыть документ

### Звук и обратная связь
- Звук в сборке рабочий, но часть фоли и фонов — временные бета-заглушки; телеграфные сигналы должны оставаться отчётливо слышимыми поверх комнаты. В настройках есть раздельные ползунки **Общая громкость**, **Шум комнаты**, **Телеграф**, **Звуки предметов** и **Музыка**, а также параметры читаемости и графики.
- **Локальный лог плейтеста:** по умолчанию при старте смены из главного меню пишется локальный лог таймингов в `%APPDATA%\Godot\app_userdata\dead-wire\playtest\` (когда и что открыто/выбрано — без введённого вами текста и без автоматической отправки куда-либо; отключается в настройках пунктом **Playtest log**).
- Если хотите поделиться багом или впечатлениями — в папке `hand-off/` лежит шаблон `BETA_REPORT_FORM.md`. Это бета-версия, возможны незавершённые элементы.

---

## English

### Start here
1. Extract the complete ZIP to a writable folder (do not launch directly from inside the archive).
2. Double-click `dead-wire-windows-beta-x86_64.exe` (no Godot editor required).
3. If Windows SmartScreen warns about an unknown publisher, this unsigned playtest build has no publisher certificate; continue only if you trust the sender.

### What is in this build
- Live 3D **FORM 19** station menu (Russian by default; switch `RU | EN` anytime on the title screen or in Options).
- Night approach to Black Creek Depot (April 1890).
- Full First Night watch (Night 1) at the telegraph workstation.
- Dawn walk home to Hargrove Boarding House, sleep transition, and daytime Black Creek exploration (including the local newspaper and *The Copper Mule* Saloon).

### Controls
- **Walking (street, depot, interiors):**
  - `W / A / S / D` — move; Mouse — look
  - `E` — interact (sit in chair, open doors, read newspaper/notes)
  - `Esc` — pause menu or close document; `J` / `F1` — repeat current reminder
- **Seated at the telegraph desk (360°):**
  - `A` / `D` (or on-screen `‹` / `›`) — turn around (`Desk ↔ Train-Order Signal ↔ Door ↔ Filing`)
  - `W` — snap back to desk; `S` — turn to door
  - `LMB` — interact with instruments, papers, signal lever, and clipboards
  - `Space` or hold `LMB` on the brass key — answer the wire
  - `RMB` / `Q` — lean closer / watch the window (hold by default; toggle available in Options)
  - `Mouse Wheel` — adjust lamp wick
  - `Tab` — stand up (at dawn)
- **Reading documents:**
  - `Mouse Wheel` / `Page Up` / `Page Down` / `Up` / `Down` (`Home` / `End` jump to ends) — scroll; `Esc` — close

### Sound, Privacy & Beta Notes
- Sound is functional with some provisional beta Foley/beds; telegraph signals must stay clearly audible. Options provide separate **Master**, **Room ambience**, **Telegraph**, **Foley**, and **Music** sliders plus display/readability presets.
- **Privacy:** No automatic upload exists. A watch started from the title screen writes local timing logs to `%APPDATA%\Godot\app_userdata\dead-wire\playtest\` (never raw typed words, never sent anywhere; can be turned off via **Playtest log** in Options).
- See `hand-off/BETA_REPORT_FORM.md` if you wish to share reproducible issues. This is an in-progress beta build, not a final release.
