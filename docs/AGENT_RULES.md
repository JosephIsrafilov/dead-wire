# DEAD WIRE — rules for every AI agent (any model, any tool)

This file is the working contract for Claude, Codex, Gemini, Cursor, Copilot or any other
agent that touches this repository. `AGENTS.md` holds the commands and invariants; this file
holds **how to work here**. If they conflict, the invariants in `AGENTS.md` win, then this file,
then any plan document.

The owner (Yusif) reads Russian. Talk to him in Russian. Code and code comments stay in English.

---

## 1. The one question

Before starting any task, answer in one sentence:

> **What will the player see, hear, feel or decide differently after this change?**

- If the answer is concrete ("the cold moon patch on the floor makes the door readable",
  "the player now has to choose between the window and the key") — do it.
- If the answer is "nothing, but the code/docs/tests are tidier" — it is **not** the next task,
  unless it is one of: a bug that breaks a real playthrough, a violated invariant, or a broken
  test/build you cannot work without. Put the rest in the "Later" list of your report.

Previous agent runs burned days on work the player never notices: tests that pin dates in
documents, procedure audits, evidence logs, contract reworks with no visible effect. The
owner stopped those runs. Don't repeat it.

## 2. Work loop (one task at a time)

1. **Read** the task, the files it touches, and the relevant GDD section. Say in one line what
   the player-facing result will be.
2. **Before frames.** For anything visual or spatial, capture the same fixed cameras before you
   change anything (`tools/room_overview_capture.gd`, `tools/exterior_view_capture.gd`,
   `tools/window_evidence_capture.gd`, `tools/writing_evidence_capture.gd`; see
   `docs/HANDOVER.md` §4). Windowed tools run one at a time.
3. **Change** the smallest thing that produces the result. Prefer tuning existing nodes,
   materials and lights over new systems.
4. **After frames** from the same cameras, same settings. **Look at them yourself.** A headless
   run, a green test or `vision_check.py` is never visual acceptance. When the change moves,
   flickers or sounds (light, flame, cloth, particles, animation, audio), also record the fixed
   30-second clip with sound before and after: a still frame can't show any of that.
5. **Behaviour checks**: focused suite, then full regression, lint, boot smoke (commands in
   `AGENTS.md`). Only what the change can affect; the full run before every commit.
6. **Report and stop at the checkpoint** (§3).

## 3. Owner checkpoints: stop and show

The owner judges taste. The agent proposes, shows and waits.

- After every **phase** of a plan, and after any big visual change (palette, lighting rig,
  window/exterior, the figure, the hand, UI style), **stop**. Don't chain into the next phase
  without the owner's OK.
- For taste decisions, offer **2–3 variants** side by side (same camera), with your
  recommendation first. Don't pick one silently and build on it.
- Report format (in Russian, short):
  1. Что изменилось для игрока (1–3 lines).
  2. Before/after pairs: file paths of the frames.
  3. Checks: commands and real results (suites/assertions, exit codes, unexpected `SCRIPT ERROR`s).
  4. Where I'm unsure / what I need you to decide.
  5. Later: things I noticed but didn't do.
- Never claim "done", "green" or "looks good" for something you did not run or look at. Say
  what was not checked.

## 4. Art direction (from GDD §3.7 and §35; apply it, don't reinvent it)

- **Light:** one dominant warm light (the desk lamp) and one cold light (the moon through the
  window). Ambient near zero. Corners, door and board live in darkness until approached.
  Don't fix "too dark" by adding another lamp. Fix it with the cold light (moon patch, rim)
  and material values.
- A light that reaches furniture either casts shadows or is removed; unshadowed fills leak
  through objects and flatten the room.
- **The look must not depend on the player's monitor.** Check frames at 1080p and 1440p in the
  default presentation mode; pixel size and grade must match.
- **Color:** warmth is local, around the lamp; the rest of the room is cool and desaturated.
  If a whole frame reads orange-brown, the grade or the fill lights are wrong.
- **Texel density is consistent.** Never put a low-resolution, nearest-filtered texture on a
  surface the camera sees bigger than its native size (giant pixels next to fine ones look
  cheap). Depth outside the window comes from real simple geometry + fog, not from painted
  pixel billboards.
- **Paper is the most important material.** It is never brighter than the lamp that lights it,
  has thickness and a contact shadow, and text on it is always readable.
- **Interface:** the room shows state, overlays don't. No status strings ("Line Busy",
  "Still Copying"). Interaction hint = a dot plus one printed word on focus. Key hints only in
  the first minutes. No modern sans fonts. Documents are lifted toward the camera, not shown
  as flat modal panels. Choices are physical (lever, pen, stamp) with a sound and a short animation.
- **No** CRT frames, VHS noise or chromatic aberration. Grain and vignette stay subtle.
- **The 30-second clip test:** would a stranger watching 30 seconds guess this game cost more
  than it did? If not, add darkness, material or silence, not content.

## 5. Horror design rules

- **Sparse.** Long normal stretches; the strange becomes strange because it breaks a learned routine.
- **Clear actions, ambiguous meaning.** The player always knows what they can do; nobody tells
  them what an event means.
- **Don't explain in text what the player can notice.** Elias's thoughts name the next action
  or react to something. They never list the room, never reassure ("nothing here is
  unexplained"), and never interpret the anomaly.
- **Divided attention is the core** (GDD §3.2): "Is it uncomfortable to turn away from the window
  when the sounder starts?" New horror work should make that answer "yes" without breaking
  audio fairness.
- **Consequences must be noticeable** to someone who doesn't know the script, without a
  right/wrong verdict.
- Invariants in `AGENTS.md` are absolute: separate signal layers, register = MARK/GAP only,
  critical Morse always readable, no stingers over critical copy, the Listener never touches
  objects, the figure changes only between observations, WorldState ≠ KnowledgeState.

## 6. Tests: protect behaviour, not taste

- Write tests (TDD: RED, then GREEN) for **behaviour, contracts, invariants and bugs you fixed**.
- **Don't** write tests that pin art values, colors, light energies, UI copy, dates in docs or
  file contents just to raise the assertion count. If a string matters to a test, it's because
  a capture tool or a contract depends on it.
- Suite and assertion counts never drop. Changing a contract means updating its test with an
  equal or stronger check, never deleting the red assert.
- Count unexpected `SCRIPT ERROR`s as failures even when the exit code is 0. Report known
  shutdown noise (ObjectDB leaks, godot#117991 teardown crash) separately and honestly.

## 7. Scope

- Do what the active plan says, in its order. If a task turns out to need a new system, a new
  generator or more than about a day, stop and propose it first.
- GDD §28 guardrails hold until the M1 playtest verdict: no town, no new nights, no endings,
  no complex AI, no free physics on every object, no renderer or engine change.
- Content (scenarios, thoughts, night structure) lives in `.tres`, not code.

## 8. Docs: less is more

- **Don't create new review, audit, report or "evidence" documents** unless the owner asks. Your
  report goes in the chat.
- Per task: tick the checkbox in the active plan and add **one** journal line.
- Update `docs/HANDOVER.md` / GDD / `AGENTS.md` numbers only when a fact actually changed, in the
  same commit.
- Frames, logs and audio go to `.dream-loop/` or `test_logs/` (outside git). Copy only frames
  the owner approved into `docs/art/`.

## 9. Git

- The working tree often holds the owner's uncommitted work. **Never** revert, stash, reset or
  "clean" it. Never `git add -A` / `commit -a`. Stage explicit paths only.
- Commit as the owner:
  `git -c user.name="Yusif Israfilov(Kaiser)" -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" commit …`
- Small commits, one task each. Subject: `feat:`/`fix:`/`refactor:`/`test:`/`docs:`/`chore:`,
  in the game's voice. Body ends with the real numbers (`N suites / M assertions green; lint
  clean; boot exit 0.`).
- The owner pushes. Don't push, don't rewrite history.

## 10. Environment (Windows machine)

- Godot 4.7.1: `C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.
  Don't switch engine versions.
- If a sandbox blocks writes outside the repo, Godot fails on its log in `%APPDATA%`: point
  `APPDATA` at a folder inside the repo for that run (don't commit it).
- Lint: `pwsh -File tools/lint.ps1` (Windows) or `bash tools/lint.sh`; they move the gdtoolkit
  cache into the project. "Cannot open file … already exists" is a cache problem, not style errors.
- After any new `class_name` or asset: `godot --headless --path . --import`.
- Normalize edited `.gd`/`.tscn` to LF. Python tools run from `.venv-tools`.
- Generators overwrite files (`docs/HANDOVER.md` §5). Read what a generator writes before
  running it; never regenerate everything for one asset.

## 11. Anti-patterns we have already paid for

| Don't | Do instead |
|---|---|
| Add a lamp because a corner is dark | Moonlight patch, rim light, material value |
| Pixel-art billboard for distant scenery | Simple geometry + fog + one motivated light |
| A long thought that explains the room | Let the sound and the object explain themselves |
| A modal dialog for an in-world action | The hand, the pen, the paper, the lever |
| A test that a document contains "1890" | Fix the text; test only contracts |
| A new report `.md` for every session | One journal line + chat report |
| Chaining five plan phases unattended | Stop at each checkpoint with before/after frames |
| "Looks fine" from a headless run | Windowed frames, looked at by you, then by the owner |
