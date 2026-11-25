# AGENTS.md — FORM 19 (internal repo: dead-wire)

First-person psychological horror, Godot 4.7 / GDScript. You are a telegraph
operator in April 1890; the core hook: you hear one thing, your hand writes another.

**Start here, every agent, every model:** `docs/AGENT_RULES.md` (how to work here:
player-visible results first, stop at owner checkpoints with before/after frames,
art direction, what not to waste time on). Then `docs/HANDOVER.md` (state, traps,
conventions) and the single active plan in `docs/plans/next/ACTIVE_ROADMAP.md`.

Non-negotiable in short:
- Before any task, answer: what will the player see, hear or decide differently?
  If nothing, it isn't the next task (bugs and invariants excepted).
- Visual work: before/after frames from the same cameras, looked at by you. Stop
  after each phase and show the owner; don't chain phases unattended.
- Research real 1880s–1890s period references before building or rebuilding
  telegraph hardware, signal gear, furniture, stationery, or town buildings.
- Never revert or stage the owner's uncommitted work; explicit paths only.
- Talk to the owner in Russian; code and comments in English.

## Commands

PowerShell 5.1 note: `&&` is unsupported — chain dependent steps with `; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`.

```bash
# Full regression (MUST be green; suite/assertion counts never drop — current baseline in docs/HANDOVER.md §1)
bash tools/run_all_tests.sh
# Windows: GODOT_BIN="/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" bash tools/run_all_tests.sh

# Focused suite
godot --headless --audio-driver Dummy --path . --script tests/telegraph/<suite>_test.gd

# Production boot smoke (0 errors required)
godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn

# Production route (windowed ONLY — real mouse capture; headless refuses with exit 2; 63 PASS)
godot --path . --script tools/production_evidence_capture.gd
# Whole night incl. hook + dawn (windowed; 87 PASS). Other capture tools: docs/HANDOVER.md §4
godot --path . --script tools/first_night_playthrough.gd -- --capture

# After adding any class_name or asset: refresh the class cache
godot --headless --path . --import

# Windows Beta release build + validated .zip packaging
godot --headless --path . --export-release "Windows Beta x86_64" ".dream-loop/export_check/dead-wire-windows-beta-x86_64.exe"
.venv-tools/Scripts/python.exe tools/package_windows_beta.py .dream-loop/export_check --output builds/windows-beta

# Lint production scripts (tests/tools are exempt — established style; max 1000 lines/file)
.venv-tools/bin/gdlint scripts/
# Windows: .venv-tools/Scripts/gdlint.exe scripts/

# Measure the office mix: loudness, band balance, loop seams, bed-vs-sounder masking
.venv-tools/Scripts/python.exe tools/audio_measure.py measure audio/sfx/ambience
.venv-tools/Scripts/python.exe tools/audio_measure.py mask --bed audio/sfx/ambience/wind_window.wav \
    --target audio/sfx/telegraph/sounder_up.wav --bed-gain-db -33 --target-gain-db -3

# Vision check via glm-5.3-flash (never trust a headless result as visual acceptance)
python3 tools/vision_check.py <image.png> ["question"]
python3 tools/vision_check.py --all <dir> ["question"]

# Watch mode: lint + focused suite on save
tools/watch_tests.sh [filter]
```

## Test conventions

- Tests are `extends SceneTree` scripts: `_init` → `call_deferred("_run")`,
  print `  PASS: <desc>` / `  FAIL: <desc>`, `quit(0)` all-pass / `quit(1)` first fail.
- Runner greps `PASS:` lines and exit codes. Baseline grows with each feature;
  never let the suite count drop.
- TDD on contract work: write the failing test first, watch it fail, then implement.
- GDScript lambda gotcha: captured `int` is by-value — counters in signal lambdas
  must be arrays (`arr.append(1)`), not `x += 1`.
- Physics interpolation (`physics_interpolation = true`) with `camera.top_level = true`:
  tests that teleport the player must call `reset_physics_interpolation()` and await
  two `physics_frame`s + one `process_frame` before raycasting.

## Architecture invariants (violating these breaks the game's honesty)

- **Signal pipeline** (GDD §3.1): TRUE SIGNAL → ELIAS PERCEPTION → WRITTEN
  TRANSCRIPT → PLAYER. Layers never collapse. `TelegraphScenarioData` carries
  `true_message` / `elias_perception` / `written_transcript` separately.
- **Tape register** (`TapeRegisterController`) is the objective anchor: it subscribes
  to `MorseRuntimeScheduler.timing_event_started` like the sounder and records
  MARK/GAP events only. It has NO access to message text and can never lie by
  construction. Do not give it text, do not distort its record.
- **Writer rig timing contract**: `advance_presentation(delta) -> float` spends a
  tick's time ONCE (entry, then motion, remainder returned). One presentation tick
  writes at most one glyph; ink lands on `glyph_contact`, never on the cue.
- **Audio fairness** (GDD §7): critical Morse is always readable. Noise may eat
  non-critical characters only. No stingers over critical copy.
- **The Listener never touches objects** (GDD §10). Physical changes need another
  explanation. The window figure exists only between observations.
- `WorldState` (objective) vs `KnowledgeState` (what Elias/player knows) stay
  separate stores across night shifts and town scenes.
- **SubViewport reparent & Windows focus**: `M1OfficeController` reparents `M1Office`
  into `OfficePresentation/OfficeFrame` (`SubViewport`), firing `_exit_tree()` then
  `_enter_tree()`. Any `get_tree().root` focus signal subscription (such as
  `PauseMenu`) MUST bind in `_enter_tree()` and unbind in `_exit_tree()`, and Windows
  focus recovery must cycle `VISIBLE → CAPTURED` when returning from Alt-Tab so
  Windows `DisplayServer` re-acquires OS `ClipCursor`.
- **`InteractionController.cursor_mode` standing invariant**: `cursor_mode` may ONLY
  be `true` while `player.seated_station_mode == true`. Inactive
  `SeatedStationController` focus/mouse-exit notifications must never trigger
  `set_cursor_target(null)` or flip `cursor_mode = true`.
- **RU + EN localization parity**: Russian is default (`GameLocale.pick(ru, en)` in
  `scripts/ui/game_locale.gd`); every player-facing string supports both RU and EN.

## Layer map

- `scripts/telegraph/morse/` — data model, encoder, scheduler (timing = data)
- `scripts/telegraph/session/` — session state machine, scenarios (.tres in `data/scenarios/`)
- `scripts/telegraph/hardware/` — sounder, telegraph key, tape register
- `scripts/telegraph/ui/` — transcript paper + writer rig, routing board (1890s Train-Order Signal), ledger, duty sheet
- `scripts/player/` — `PlayerController` (standing walk/lean), `SeatedStationController` (360° seated bay-window HUD & pointer raycast), `SeatedHudCopy`, `OperatorSeat`
- `scripts/interaction/` — `Interactable`, `InteractionController` (raycast + cursor-mode gate)
- `scripts/office/` — `M1OfficeController`, `ShiftDirector`, `ShiftArrival`, `RoomPropsInteract`, `YardFog`, `CandleLife`, `LampLife`, `NightGuidanceController`, door & exterior
- `scripts/ui/` — `MainMenu` (`FORM 19` live 3D title), `TitleMood`, `TitleBackdrop3D`, `PeriodUIStyle`, `DocumentViewer` (parchment/tape reader), `PauseMenu`, `GameLocale`
- `tools/` — evidence capture, vision check, test runner, Windows Beta packager (`package_windows_beta.py`)
- `docs/design/` — GDD (frozen direction) + horror layer design (approved)
- `docs/plans/next/ACTIVE_ROADMAP.md` — single active multi-milestone plan (M1 Final → M2 Dawn/Home/Town → Night 2+ → M3)

## Working rules

- Commit identity: `Yusif Israfilov(Kaiser) <113928967+JosephIsrafilov@users.noreply.github.com>`
  (git user is not configured globally — use `-c user.name=... -c user.email=...`).
- Content (scenarios, directives, night structure, town notices) lives in `.tres` resources, not code.
- Editor-generated `.uid` files are tracked alongside scripts.
- `gdlintrc` at repo root: 120 cols, 1000 max lines/file, `class-definitions-order`/`max-returns`/
  `max-public-methods` disabled. Run gdlint on `scripts/` only. Keep `m1_office_controller.gd` under 1000 lines by extracting helpers.
- Python tools go in `.venv-tools` (PEP 668: no system pip).
- **Milestone transition rule**: M1 Night 1 (`FORM 19`) and M2-A (Dawn walk, Boarding House & Black Creek Phases 1–3) are accepted by the owner; next development proceeds strictly along `docs/plans/next/ACTIVE_ROADMAP.md` v3.0 (**Stage 0: screenshot/calendar bugfixes & baseline commit → Stage 1: redesigned 3D Window Figure & M1 opening polish → Stage 2: PSX NPC pipeline, Living Cinema dialogue, Copper Mule Wave 1 & town well/Flint → Stage 3: Nights 2–3 & Days 2–3 → Stage 4: Faro-Duel 1890, Day 4 Protest & Nights 4–5 → Stage 5: Saloon Wave 3, Night 6, Quiet Saturday & Sunday Trial → Stage 6: Audio/balance/release**), still respecting GDD §28 guardrails against empty open-world bloat or free physics on every prop.
