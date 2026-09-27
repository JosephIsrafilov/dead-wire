# DEAD WIRE — HANDOVER (read this first)

Last updated: 2026-09-27. Audience: any model or person picking up the project cold.
Docs are written in Russian, code and code comments in English. Keep that split.

## 1. State now

- HEAD `74f0443` on `main`, in sync with `origin/main`.
- Regression: **38 suites / 1915 assertions green**. Production route: **57 PASS**. First-night playthrough: **58 PASS**.
- Boot smoke: 0 errors. Playable macOS build: `builds/dead-wire-m1-macos.zip` (tracked, export preset "Playtest").
- What plays today: one M1 night in a single telegraph office. There are three telegrams (baseline, attention,
  and the core hook, where WATER on the wire is written as WATCHER by the hand). Around them: routing on the board,
  filing at the stove table, reading the tape register, moonlight and weather at the window, wick trimming,
  register winding, and a dawn ritual. The contact sheets are in §11.
- Diagnosis of every known problem (#1–39, P0/P1/P2): `docs/plans/2026-09-27_STATE_OF_THE_GAME.md`.
- Implementation plans: `docs/plans/next/00_INDEX.md` (workstreams WS1–WS7).

## 2. Read order

1. This file.
2. `AGENTS.md`: commands, architecture invariants, layer map.
3. `docs/plans/2026-09-27_STATE_OF_THE_GAME.md`: what is broken and why.
4. `docs/plans/next/00_INDEX.md`, then the workstream you are executing (start with `WS1_stabilize.md`).
5. `docs/design/DEAD_WIRE_GDD_v1.0.md` (v1.1, frozen direction). The relevant sections are §3 (pillars),
   §7 (audio fairness), §10 (Listener), §28 (guardrails) and §35 (presentation bar).
6. `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md`: the nights 2–6, citations and trial design (approved).
7. `docs/plans/2026-09-26-production-value-pass.md`: the last big pass, the room/shift design, and the genre research with URLs.

## 3. Headless commands (fast, safe, run anytime)

```bash
bash tools/run_all_tests.sh                                   # full regression, ~3–4 min
godot --headless --audio-driver Dummy --path . --script tests/<dir>/<suite>_test.gd
godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn   # boot smoke
godot --headless --path . --import                            # after adding any class_name / asset
.venv-tools/bin/gdlint scripts/                               # lint production scripts only
tools/watch_tests.sh [filter]                                 # lint + focused suite on save
```

Suites live under `tests/{audio,debug,events,integration,office,player,state,telegraph,ui}/`.

## 4. Windowed tools (real window, mouse captured, 5–10 min each; headless refuses with exit 2)

These are not part of the regression. Run them when the player route, interactables or visuals change.
Output goes to `.dream-loop/…`, which is gitignored. Copy the frames you want to keep into `docs/art/state_<date>/`.

| Tool | Proves | Output |
|---|---|---|
| `godot --path . --script tools/production_evidence_capture.gd` | full production route, **57 PASS** | `.dream-loop/production_evidence/` |
| `godot --path . --script tools/first_night_playthrough.gd -- --capture` | whole night incl. hook + dawn, **58 PASS** | `.dream-loop/playthrough_water/` |
| `tools/room_overview_capture.gd` | room frames o1–o9 standing, c1–c4 seated | `.dream-loop/overview/` |
| `tools/writing_evidence_capture.gd` | hand + pen writing on the sheet | `.dream-loop/writing_evidence/` |
| `tools/hand_turntable_capture.gd` | hand/cuff/sleeve from 8 angles | `.dream-loop/hand_turntable/` |
| `tools/window_evidence_capture.gd` | window, moon, figure | `.dream-loop/window_evidence/` |
| `tools/commit_input_route_capture.gd` | filing desk input route | `.dream-loop/commit_route/` |

Visual acceptance means looking at the frames yourself. `python3 tools/vision_check.py <png> ["question"]` gives a
second opinion only where it works (trap 11).

## 5. Generated artifacts: who owns what

Some files are **written by generators**. If you edit the output by hand, the next generator run overwrites your change.

| Generator | Writes | Rule |
|---|---|---|
| `tools/build_writer_hand.gd` | `hand_v3/cuff_v3/forearm_v3` `.res`; **edits `scenes/telegraph/transcript_paper.tscn`** (Pen `rotation`, `WriterRig.elbow_offset_rig`) | loads the office to seat the operator; rerun after moving desk/paper/seat |
| `tools/build_paper_forms.gd` | `form_night_copy.png`, `card_morse_stock.png`, `map_division.png` | form constants **must match** the transcript `Label3D` in `transcript_paper.tscn` |
| `tools/build_wallpaper.gd` | `psx_wallpaper_stripe_128.png` | — |
| `tools/generate_action_foley.py` | foley WAVs | **shared RNG: append new sounds at the end only**, or every old sound changes |
| `tools/generate_sounder.py`, `generate_office_ambience.py` | sounder / ambience WAVs | run from `.venv-tools` |
| `tools/build_lamp_chimney.py` | chimney mesh | — |

Export: preset "Playtest" produces `builds/dead-wire-m1-macos.zip`. A release template cannot run a specific scene.
Verify an export with `godot --headless --main-pack <pck> --quit-after 120 res://scenes/office/m1_office.tscn`.

## 6. Traps (each one has cost a session before)

1. **New `class_name` is invisible** until `godot --headless --path . --import` refreshes the class cache.
2. **`.tscn` comments** (`;`) go only before a `[node …]` header, never between property lines.
3. **`Transform3D` literals**: the basis order is easy to get wrong. Set the `rotation` property instead.
4. **Counts never drop.** The suite and assertion counts are the baseline. Deleting a test to go green is a regression.
5. **Tests and capture tools pin UI strings.** Changing a prompt or label also means updating
   `tests/**` and `tools/production_evidence_capture.gd` / `first_night_playthrough.gd`.
6. **`ShiftDirector.Phase` is append-only.** Tests and saved logic use the enum values.
7. **Generators rewrite scenes** (§5). Check `git diff` after running any `tools/build_*`.
8. **Foley RNG order** (§5): append only.
9. **Windowed tools** capture the mouse and take minutes. They cannot run headless (exit 2).
10. **`.dream-loop/` is not in git.** Evidence frames vanish unless copied to `docs/art/`.
11. **`vision_check.py` is machine-specific.** It reads provider keys from the owner's `~/.config/opencode/`
    and `~/.local/share/opencode/`. Elsewhere it has no targets; skip it and review the frames yourself.
12. **System Python has no PIL/numpy** (PEP 668). Use `.venv-tools/bin/python`, and never `pip install` system-wide.
13. **`rewrite.py` at the repo root is dangerous.** It overwrites the wall nodes of `m1_office.tscn` with stale values.
    Never run it. Its deletion is WS1.8, pending the owner's OK.
14. **GDScript lambdas capture `int` by value.** Use arrays for counters in signal lambdas.
15. **Multiline lambdas inside call arguments** fail to parse. Use named functions.
16. **Arm rendering**:
    - Vertex colours need `vertex_color_is_srgb`.
    - The arm meshes are on `layers = 2`. `WindowBounceLight.light_cull_mask` and `RoomReflection.reflection_mask`
      (`4294967293`) exclude that layer.
    - Cloth uses `SPECULAR_DISABLED`, otherwise the probe's grazing Fresnel turns the sleeve pale grey.
17. **The index may hold files staged by the owner** (`builds/dead-wire.app`, `.DS_Store`, `docs/plans/site_redesign_brief.md`).
    Never `git add -A` / `git commit -a`. Commit explicit paths only.
18. **Seat yaw centring is intentional.** A "fix" once broke the route (stand/sit loop).
19. **macOS has no `timeout`.** The runner needs its own watchdog (WS1.1).
20. **The writer rig spends a tick's time once.** Never call `advance_presentation` twice per frame, and never place ink on the cue.

## 7. Test template

```gdscript
extends SceneTree
## <What contract this suite guards, in one or two sentences.>
##   godot --headless --audio-driver Dummy --path . --script tests/<dir>/<name>_test.gd

func _init() -> void:
	call_deferred("_run")

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok

func _run() -> void:
	if not assert_condition(1 + 1 == 2, "Describe the behaviour, not the code"): return
	quit(0)
```

The runner greps the `PASS:`/`FAIL:` lines and the exit code. TDD: RED first (watch it fail for the right reason), then GREEN.

## 8. Conventions

- **Commits** use the owner's identity and have no co-author trailer:
  `git -c user.name="Yusif Israfilov(Kaiser)" -c user.email="113928967+JosephIsrafilov@users.noreply.github.com" commit -m "…" -- <paths>`.
  - The subject is `feat:`/`fix:`/`refactor:`/`test:`/`docs:` plus a sentence in the game's voice
    (e.g. `fix: hand stays in the sleeve; SW corner and north wall read`).
  - The body ends with `38 suites / N assertions green; production route 57 PASS.`
- **Script headers**: `class_name` first, then a `##` block saying what the node is *in the fiction* and what
  contract it keeps. Test headers carry their run command.
- **Comments** are sparse and explain *why* (a contract or a fiction reason), never *what*.
- **Named contracts**: the writer rig timing, the tape honesty and audio fairness each have a named test. New
  contracts get a named test too.
- **Content in `.tres`**, not code (scenarios, directives, nights). The owner does not want CI; don't propose it.
- **Pushing** is done by the owner (the shell has no GitHub credentials).

## 9. Next steps (ranked)

1. **WS1** (stabilize):
   - runner watchdog;
   - `_play_on_wire` refuses during a live telegram, and the session handles `playback_cancelled`;
   - tape segment gaps;
   - null guards and deferred slot advance;
   - the `critical_copy` flag;
   - clock ducking and a footstep gap check;
   - figure/cloud honesty.
2. **WS2.1** (P0): the filing desk must stop naming the true word.
3. **WS3.1 + 3.2**: remove the HUD status strings; make the route lever physical. Both are needed before the playtest.
4. **WS2.2–2.10**, then the **blind 5-player playtest (WS2.12)**. Its verdict gates everything after it.
5. **WS4**: NightData, WireService, and splitting the god objects. This is behaviour-neutral.
6. **WS5**: nights 2–3 and the sending prototype. WS6 (town) and WS7 (trial and endings) are milestone-level.

## 10. Doc map

| CURRENT | HISTORICAL (bannered SUPERSEDED or dated reports) |
|---|---|
| `AGENTS.md`, `docs/HANDOVER.md` | `docs/plans/2026-09-21_SESSION_HANDOVER.md` |
| `docs/plans/2026-09-27_STATE_OF_THE_GAME.md` | `docs/m1_living_shift_plan.md`, `docs/m1_next_session_prompt.md` |
| `docs/plans/next/*` | `docs/m1_quality_finish_plan.md`, `docs/m1_quality_finish_prompt.md` |
| `docs/design/DEAD_WIRE_GDD_v1.0.md` (v1.1) | `docs/reports/*` (dated pass reports) |
| `docs/design/DEAD_WIRE_HORROR_LAYER_DESIGN.md` | `docs/plans/2026-09-20-tape-register-m1.md` (done) |
| `docs/plans/2026-09-26-production-value-pass.md` | `docs/architecture/*` (lags the rig, tape and director; code is truth) |
| `docs/third_party_assets.md` (licences) | |

## 11. How the game looks and plays now (2026-09-27)

- `docs/art/state_2026-09-27/play_1_start_to_writing.png`: from the shift opening to the hand copying the first telegram.
- `docs/art/state_2026-09-27/play_2_hook_to_dawn.png`: from the core hook (WATER→WATCHER) through filing and the tape to dawn.
- `docs/art/state_2026-09-27/room_views.png`: room overview frames, standing and seated.
