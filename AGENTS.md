# AGENTS.md — DEAD WIRE

First-person psychological horror, Godot 4.7 / GDScript. You are a telegraph
operator in April 1890; the core hook: you hear one thing, your hand writes another.

**Start here, every agent, every model:** `docs/AGENT_RULES.md` (how to work here:
player-visible results first, stop at owner checkpoints with before/after frames,
art direction, what not to waste time on). Then `docs/HANDOVER.md` (state, traps,
conventions) and the active plan in `docs/plans/next/`.

Non-negotiable in short:
- Before any task, answer: what will the player see, hear or decide differently?
  If nothing, it isn't the next task (bugs and invariants excepted).
- Visual work: before/after frames from the same cameras, looked at by you. Stop
  after each phase and show the owner; don't chain phases unattended.
- Never revert or stage the owner's uncommitted work; explicit paths only.
- Talk to the owner in Russian; code and comments in English.

## Commands

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
# Whole night incl. hook + dawn (windowed; currently broken: synthetic E presses do not land). Other capture tools: docs/HANDOVER.md §4
godot --path . --script tools/first_night_playthrough.gd -- --capture

# After adding any class_name or asset: refresh the class cache
godot --headless --path . --import

# Lint production scripts (tests/tools are exempt — established style)
.venv-tools/bin/gdlint scripts/
# Windows: .venv-tools/Scripts/gdlint.exe scripts/

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
  separate stores.

## Layer map

- `scripts/telegraph/morse/` — data model, encoder, scheduler (timing = data)
- `scripts/telegraph/session/` — session state machine, scenarios (.tres in `data/scenarios/`)
- `scripts/telegraph/hardware/` — sounder, telegraph key, tape register
- `scripts/telegraph/ui/` — transcript paper + writer rig, routing board, ledger, duty sheet
- `scripts/office/` — office controller, shift director (pacing), seat
- `scripts/ui/` — document viewer (all reading happens through it), menus
- `tools/` — evidence capture, vision check, test runner, watch
- `docs/design/` — GDD (frozen direction) + horror layer design (approved)
- `docs/plans/` — implementation plans (TDD task breakdowns)

## Working rules

- Commit identity: `Yusif Israfilov(Kaiser) <113928967+JosephIsrafilov@users.noreply.github.com>`
  (git user is not configured globally — use `-c user.name=... -c user.email=...`).
- Content (scenarios, directives, night structure) lives in `.tres` resources, not code.
- Editor-generated `.uid` files are tracked alongside scripts.
- `gdlintrc` at repo root: 120 cols, `class-definitions-order`/`max-returns`/
  `max-public-methods` disabled (they fight the established file layout and
  state-machine accessors). Run gdlint on `scripts/` only.
- Python tools go in `.venv-tools` (PEP 668: no system pip).
- Don't build the town, final art, endings, or complex AI before M1 proves the
  core loop (GDD §28 guardrails).
