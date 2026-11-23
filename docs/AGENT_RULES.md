# DEAD WIRE — rules for every AI agent (any model, any tool)

This file is the working contract for Claude, Codex, Gemini, Cursor, Copilot or any other
agent that touches this repository. `AGENTS.md` holds the commands and invariants; this file
holds **how to work here**. If they conflict, the invariants in `AGENTS.md` win, then this file,
then `docs/plans/next/ACTIVE_ROADMAP.md`.

The owner (Yusif) reads Russian. Talk to him in Russian. Code and code comments stay in English.

---

## 1. The one question

Before starting any task, answer in one sentence:

> **What will the player see, hear, feel or decide differently after this change?**

- If the answer is concrete ("the cold moon patch on the floor makes the door readable",
  "turning from the signal lever to the doorway now feels natural at 360°") — do it.
- If the answer is "nothing, but the code/docs/tests are tidier" — it is **not** the next task,
  unless it is one of: a bug that breaks a real playthrough, a violated invariant, or a broken
  test/build you cannot work without. Put the rest in the "Later" list of your report.

Previous agent runs burned days on work the player never notices: tests that pin dates in
documents, procedure audits, evidence logs, contract reworks with no visible effect. The
owner stopped those runs. Don't repeat it.

## 2. Work loop (one task at a time)

1. **Read & research.** Read the task, the files it touches, and the relevant GDD/roadmap section.
   If building or rebuilding 1880s–1890s hardware, stationery, signals, or architecture, research
   real historical references first. Say in one line what the player-facing result will be.
2. **Before frames.** For anything visual or spatial, capture the same fixed cameras before you
   change anything (`tools/room_overview_capture.gd`, `tools/exterior_view_capture.gd`,
   `tools/window_evidence_capture.gd`, `tools/writing_evidence_capture.gd`; see
   `docs/HANDOVER.md` §4). Windowed tools run one at a time.
3. **Change** the smallest thing that produces the result. Prefer tuning existing nodes,
   materials and lights over new systems. Keep RU and EN localization in sync via `GameLocale.pick()`.
4. **After frames** from the same cameras, same settings. **Look at them yourself.** A headless
   run, a green test or `vision_check.py` is never visual acceptance. When the change moves,
   flickers or sounds (light, flame, cloth, particles, animation, audio), verify motion/sound as well.
5. **Behaviour checks**: `gdlint scripts/`, focused suite, boot smoke, and release/route smoke when
   input or flow changed (commands in `AGENTS.md`). Run the full regression before every commit.
6. **Report and stop at the checkpoint** (§3).

## 3. Owner checkpoints: stop and show

The owner judges taste. The agent proposes, shows and waits.

- After every **phase** of a plan, and after any big visual change (palette, lighting rig,
  window/exterior, town street/room, the figure, the hand, UI style), **stop**. Don't chain
  into the next phase without the owner's OK.
- For taste decisions, offer **2–3 variants** side by side (same camera), with your
  recommendation first. Don't pick one silently and build on it.
- Report format (in Russian, concise, with clickable `file:///` links):
  1. Что изменилось для игрока (1–3 lines).
  2. Before/after pairs: file paths of the frames.
  3. Checks: commands and real results (suites/assertions, exit codes, unexpected `SCRIPT ERROR`s).
  4. Where I'm unsure / what I need you to decide.
  5. Later: things I noticed but didn't do.
- Never claim "done", "green" or "looks good" for something you did not run or look at. Say
  what was not checked.

## 4. Art direction (1890 PSX authenticity + GDD §3.7 / §35)

- **Historical 1890s authenticity:** props, instruments, and town spaces must read as genuine late
  19th-century frontier depot hardware (cast iron, brass bezels, walnut clipboards, riveted enamel
  signal plates, notched semaphore quadrants, kerosene sconces, tallow/wax candles) — never
  generic placeholder blocks or modern UI widgets.
- **Light (Night vs. Day Contrast):**
  - *Night station (`M1Office`):* one dominant warm light (the kerosene desk lamp) and one cold exterior
    light (moonlight / dawn haze through window and yard) plus sparse, spatially motivated secondary
    practicals (stove ember glow, brass corner candle, warm sconce). Ambient stays low (~0.095) so
    corners live in shadow without crushing walls to flat black. Never blast the night room with
    unshadowed fills.
  - *Daytime Black Creek & Saloon (`M2`):* warm golden April Colorado mountain sunlight, crisp blue sky,
    readable shadows (`ambient ~0.35–0.40`), and cozy amber kerosene/mahogany interior in *The Copper Mule*
    Saloon via dual day/night presets in `psx_grade.gdshader` (see `docs/design/BLACK_CREEK_TOWN_AND_DAYTIME_DESIGN.md`
    §7) — so the bright human daytime sharpens the dread of returning to the night office.
- **The look must not depend on the player's monitor.** Check frames in windowed presentation mode;
  the 5-bit Bayer PSX grade (`psx_grade.gdshader`) and lighting must remain legible without
  black-crush.
- **Color:** warmth stays local around practical lights; cool desaturated blue-slate dominates the
  window, yard, and far shadows.
- **Texel density is consistent.** Never put a low-resolution, nearest-filtered texture on a
  surface seen huge by the camera. Depth outside comes from real simple geometry + fog, not flat
  billboards.
- **Paper is the most important material.** It looks like warm aged 1890s stock — framed by
  walnut boards/clips, ruled telegraph form markings, subtle ink/rubber stamps, crisp `OldStandardTT`
  letterpress text, never brighter than its practical light, and never ruined by default grey OS/Godot
  scrollbars or floating edges hanging off desks.
- **Interface & seated ergonomics:** the room shows state; overlays stay minimal. Full 360° seated
  rotation (`A/D` ring, `W` desk, `S` door) never traps the player in a dead-end view; edge buttons
  never overlap the top-left duty strip or physical instruments. Choices remain tactile (lever,
  pen, clipboard, brass key, wick) with sound and short animation.
- **No** CRT frames, VHS noise or chromatic aberration. Grain and vignette stay subtle.
- **The 30-second clip test:** would a stranger watching 30 seconds guess this game cost more
  than it did? If not, add darkness, material fidelity, or silence — not filler clutter.

## 5. Horror design rules

- **Sparse.** Long normal stretches; the strange becomes strange because it breaks a learned routine.
- **Clear actions, ambiguous meaning.** The player always knows what they can do; nobody tells
  them what an event means.
- **Don't explain in text what the player can notice.** Elias's thoughts (including his uneasy
  dawn thought walking home in M2) name the lingering detail or next action. They never explain
  the plot, never reassure ("nothing here is unexplained"), and never interpret the anomaly.
- **Divided attention is the core** (GDD §3.2): "Is it uncomfortable to turn away from the window
  when the sounder starts?" New horror work should make that answer "yes" without breaking
  audio fairness.
- **Consequences must be noticeable** to someone who doesn't know the script (including daytime
  Black Creek reactions in M2), without a right/wrong verdict screen.
- Invariants in `AGENTS.md` are absolute: separate signal layers, register = MARK/GAP only,
  critical Morse always readable, no stingers over critical copy, the Listener never touches
  objects, the figure changes only between observations, WorldState ≠ KnowledgeState.

## 6. Tests: protect behaviour, not taste

- Write tests (TDD: RED, then GREEN) for **behaviour, contracts, invariants and bugs you fixed**
  (e.g., focus/Alt-Tab capture recovery, 360° view transitions, state persistence into M2).
- **Don't** write tests that pin arbitrary visual numbers, dates in docs, or fragile copy unless a
  contract or capture tool depends on it.
- Suite and assertion counts never drop unnecessarily; update stale assertions only when a
  deliberate contract or default locale changes, and document any known branch deltas honestly.
- Count unexpected `SCRIPT ERROR`s as failures even when the exit code is 0. Report known
  shutdown noise (ObjectDB leaks, godot#117991 teardown crash) separately and honestly.

## 7. Scope

- Follow `docs/plans/next/ACTIVE_ROADMAP.md` in order. If a sub-task needs a major unexpected
  system, propose it to the owner first.
- M1 Night 1 is complete and ready for playtest. Development now moves into **M2** following
  `docs/design/BLACK_CREEK_TOWN_AND_DAYTIME_DESIGN.md`:
  - **M2-A:** dawn walk home + Elias's boarding-house sleep transition;
  - **M2-B1–B3:** sunlit daytime Black Creek (`140 × 75 m`, phased up to 7 enterable interiors + 7 exterior
    landmarks), led by *The Copper Mule* Saloon (drinking, bartender Silas Vance intel in the spirit of
    RDR2/SBR, 1890 mechanical spinner *The Silver Spur* spins, Chuck-a-Luck, Faro with Casekeeper),
    Mercantile/Post, Company/Assay Office, Dr. Crane's Clinic, and *Chronicle* Print Shop;
  - **M2-C:** multi-night return shifts (Nights 2–6), then **M3** Sunday Wire Trial & endings.
- Guardrails remain: keep Black Creek dense, grounded in 1890 realism, and atmospheric (not an empty
  multi-kilometer open world, no combat/superpowers, no free physics on every object, no renderer/engine
  switch). Every phase must reach §35 quality before starting the next.
- Content (scenarios, thoughts, night/day schedules, town rumors, saloon prices/odds) lives in `.tres`, not code.

## 8. Docs: less is more

- **Don't create new review, audit, report or "evidence" documents** unless the owner asks. Your
  report goes in the chat.
- Keep only the living docs current (`AGENTS.md`, `docs/AGENT_RULES.md`, `docs/HANDOVER.md`,
  `docs/plans/next/ACTIVE_ROADMAP.md`): tick completed steps and update facts when they change.
- Frames, logs and builds scratch artifacts go to `.dream-loop/` or `test_logs/` (outside git).
  Release `.zip` archives go to `builds/windows-beta/`.

## 9. Git

- The working tree often holds the owner's uncommitted work. **Never** revert, stash, reset or
  "clean" it. Never `git add -A` / `commit -a`. Stage explicit paths only.
- Commit as the owner (only when requested or at approved milestones):
  `git -c user.name="Yusif Israfilov(Kaiser)" -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" commit …`
- Small commits, one task each. Subject: `feat:`/`fix:`/`refactor:`/`test:`/`docs:`/`chore:`,
  in the game's voice. Body ends with real verified check numbers.
- The owner pushes. Don't push, don't rewrite history.

## 10. Environment (Windows machine)

- Godot 4.7.1: `C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.
  Don't switch engine versions.
- **PowerShell 5.1**: `&&` fails — chain dependent commands with `; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`.
- Lint: `.venv-tools/Scripts/gdlint.exe scripts/` (max 1000 lines/file; `m1_office_controller.gd`
  is near the ceiling — extract helpers instead of growing it).
- After any new `class_name` or asset: `godot --headless --path . --import`.
- Windows Beta build & packager:
  `godot --headless --path . --export-release "Windows Beta x86_64" ".dream-loop/export_check/dead-wire-windows-beta-x86_64.exe"`
  followed by `.venv-tools/Scripts/python.exe tools/package_windows_beta.py .dream-loop/export_check --output builds/windows-beta`,
  then windowed `.exe --quit-after 180` smoke check.
- Normalize edited `.gd`/`.tscn`/`.md` to LF. Python tools run from `.venv-tools`.
- Generators overwrite files (`docs/HANDOVER.md` §5). Read what a generator writes before
  running it; never regenerate everything for one asset.

## 11. Anti-patterns we have already paid for

| Don't | Do instead |
|---|---|
| Flood-fill room with unshadowed lights | Motivated practicals (lamp, candle, sconce, stove ember) + moonlight |
| Grey Godot UI panels & oversized scrollbars | Aged 1890s paper, walnut clipboards, brass clips, slim sepia scroll |
| Dead-end seated camera where `A`/`D` stops working | Full 360° seated swivel (`DESK ↔ LEFT ↔ DOOR ↔ RIGHT ↔ DESK`) |
| Bind `get_tree().root` focus only in `_ready()` | Bind in `_enter_tree()` (survives `SubViewport` reparenting) + Windows `VISIBLE→CAPTURED` toggle |
| Flip `cursor_mode = true` from inactive `SeatedStation` | Guard every notification and `set_cursor_target()` on `_activated` & `seated_station_mode` |
| Chain five plan phases unattended | Stop at each checkpoint with before/after windowed frames |
| "Looks fine" from a headless run | Windowed frames, looked at by you, then by the owner |
