# DEAD WIRE — HANDOVER (read this first)

Last updated: 2026-09-27. Audience: any model or person picking up the project cold.
Docs are written in Russian, code and code comments in English. Keep that split.

## Checkpoint 2026-10-09 — цельная кисть, новый подключённый кандидат

Последний полный повтор: **45 suites /2022 assertions /0 FAIL**, writer_hand37,
rig-space44, paper134, lint clean. Активная сцена теперь ссылается на
`hand_authored_v1.res`: одна связная закрытая skin-оболочка,276 общих вершин/548 треугольников,
шесть именованных частей,0 пересечений с Shaft, прежние matte/layers/contact контракты.
Исходник авторски построен кодом (`author_writer_hand.py` → JSON → Godot importer),
не Blender-скульпт/mocap. Две сборки byte-identical, frame совпадает с активным пером.
Runtime WriterRig/cloth/pen/gameplay/audio в этом проходе не менялись.

Просмотр: `docs/art/state_2026-10-09/hand_authored/review.html`; план/итог01_plan/02_result.
Clay6 ракурсов, office before/after720p,2MP4 с игровым звуком (15,8/5,8с).
Запрошенный1080p снова OS-limited1920×1061 — точного1080p нет.
**Художественная приёмка владельца и5 игроков отсутствует.** Макро всё ещё стилизован;
whole-glyph pop остался, штриховую анимацию/новый звук не реализовали. G2 лишь compatibility,
G0 без живого adult motion-reference. Следующий отдельный шаг — TACTILE_M1 §P1/P3.

Первые прогоны были нестабильны: shift_director exit5 (изоляция132 и полный повтор green);
production route1 FAIL из-за одного необъяснённого смещения после кресла, повтор57 PASS.
Код/порог не ослабляли; первопричины открыты, не называть гарантированно ложным flake.
Автоматическая полная ночь0 FAIL/14shots, но teleports и сокращённый answer beat инструмента
не позволяют выдавать её за human pacing playtest. Clean boot всё ещё **не достигнут**:
10ObjectDB/2resources; окна7Texture RID leaks. Старые ассеты/незакоммиченные правки
сохранены. Commit/push не было. Это supersedes прежнюю hand_grip форму, не её runtime.

## Checkpoint 2026-10-09 — supersedes the older counts / visual status below

Current uncommitted Windows work: **45 suites / 2020 assertions / 0 FAIL**, lint clean.
Fixed-length two-link arm from the preceding pass is retained. The hand now has a flatter
palm, lower/slimmer writing index and separated relaxed fingers; exact pen contact and
no-penetration contracts retained. New silhouette assertion was RED then GREEN. Hand35,
rig-space44, paper134. Generator hand/cuff/forearm/upper-arm/scene is byte-identical on rerun.
**This is a viewed stylized candidate, NOT owner-approved final anatomy.** Macro still shows
separate-shell joint transitions; no external vision verdict (empty proxy answers).

Real windowed evidence and 15.8 s writing MP4 with actual audio:
`docs/art/state_2026-10-09/hand_grip/review.html`, details in `02_result.md`.
Production input/physics route:0 failures; full automated first night:0 failures after fixing
its old speed-dependent0.7 s exit wait (now waits for physical ending, bounded3 s). The latter
teleports between interaction points and shortens answer beat; it is NOT a human playtest.
720p/1080p office and neutral before/after exist. Gameplay follow-up plan (not implemented):
`docs/plans/2026-10-09_TACTILE_M1.md` — copy agency, writing, object continuity, foley, body/pacing.

Prior pass changes retained: archive copy readable, viewer/transcript layout matched, slower
distance-driven gait, licensed temporary intro-only Kevin MacLeod Long Note One (CC BY4),
four local worn-warmth albedos. No new scenario/canon/audio/movement changes in the hand pass.
No commit/push. **Boot exits0 but is NOT clean:** current shutdown10 ObjectDB leaks /2 resources;
windowed captures7 texture RID leaks. Causes remain open; do not repeat old zero-error claims.

### Anatomy / penmanship research (2026-10-09, documentation only)

`docs/art/state_2026-10-09/hand_anatomy/01_anatomy_and_writing_brief.md` and `sources.json`:
hand masses/joint chains, adult coordination studies (abstract/full-text access distinguished),
modern grasp variation, and visually checked1874 penmanship scans. Important correction:
static digits alone are NOT proof of bad writing (forearm/muscular movement traditions).
The next candidate should have coherent thenar/web/joint transitions and one reference-led
writing style, not endless tube radius tweaks or random tremor. No mesh/rig/gameplay edits
in this research; prior45/2020 baseline was not rerun. External figures only in ignored cache.

## Checkpoint 2026-10-08 — overrides stale status below

Current continuation: `docs/reports/2026-10-08_DEVICE_HANDOFF.md` on branch `codex/hand-rebuild-handoff`.
Hand anatomy work is saved but **visually rejected by the owner**; interrupted rebuild has before frames only.
Latest verified regression baseline: **39 suites / 1934 assertions**. Do not treat historical acceptance reports as current visual approval.

### Rebuild attempt (2026-10-08, later) — v5 generator, NOT accepted

A follow-up pass rewrote `tools/build_writer_hand.gd` to authored planar-joint topology
(per-finger MCP/PIP/DIP chains, widened palm shell, thenar-rooted thumb, per-part guard
diagnostics). Contracts all hold; regression still **39/1934 green**; generator idempotent.
**But the visual result is not meaningfully better than the rejected v4** (independent reads
score both ~2–3/10 at macro: fused digits, pen-through-flesh). See
`docs/art/state_2026-10-08/hand_rebuild/03_rebuild_status.md` and `before/after` frames.
The root cause is structural: the pen passes through the thumb–index web, so the index/middle
knuckles sit on the pen's axis and cannot wrap it within real phalanx lengths. This needs an
owner decision (stylized-accept / fully-authored mesh / re-pose), not more generator tuning.
Movement feel, tape/commit honesty and sound remain untouched, pending an accepted hand.

### Independent review (2026-10-08) — integrity correction, NOT visual acceptance

The v5 root-cause diagnosis above is **not established**: review found **260/260 palm triangles
had zero area**. Missing ring directions became Vector3.ZERO in resampling and overrode the
computed loft frame. All five finger tips were also left uncapped. A minimal correction now
reconstructs missing directions and closes the tips; writer_hand_test grew from 19 to 30
assertions (RED on the original palm, GREEN after regeneration). Full regression: **39/1945**;
lint clean; production headless boot 0 errors. Hand and scene re-generation is byte-identical,
but forearm bytes differed on repeat, so the original cuff/sleeve outputs were restored.
**No new visual acceptance**: windowed capture approval was denied by this session's policy.
The before/after frames above still show the agent's uncorrected v5, not this correction.
See `docs/art/state_2026-10-08/hand_rebuild/04_independent_review.md` for findings and next step.

### Authored pose fix (2026-10-08) — current mesh, visual acceptance still pending

The generator now uses explicit pose sections with local joint bevels, without spline fitting
or collision clamps; the fingers have closed tips and real surface names. Re-generation of
hand/cuff/forearm/scene is byte-identical. Full regression **39/1949**, hand test **34**;
lint clean and production headless boot 0 errors. Runtime rig, movement and audio unchanged.
A production-session motion probe recorded 16 accurate glyph contacts and withdrawal (not
real-input route acceptance). Neutral CPU-rendered geometry comparisons are saved in
`docs/art/state_2026-10-08/hand_rebuild/fix/`; they are NOT Godot screenshots. Windowed
capture was denied by session policy, so office lighting, motion video and final anatomy
acceptance remain unverified. Details: `05_authored_pose_fix.md` in that directory's parent.

### Worn warmth pass (2026-10-08) — partial implementation, images unavailable

Current regression **39/1952**. The real desk blotter now has SPECULAR_DISABLED (three
new desk geometry assertions); no light/geometry/scenario/audio changes. Added a Russian
emotional brief and reproducible 128px texture processing with 3 Python tests.
All four gpt-image-2 CLI requests failed decoding absent b64_json; **no new texture was
saved or integrated**. Windowed capture approval was denied. Headless boot exits 0 but
reports 8 ObjectDB leaks / 1 resource in use at shutdown, reproduced with the original
blotter material too; do NOT claim zero errors. Details and exact prompts:
`docs/art/state_2026-10-08/worn_warmth/02_status.md` and `01_emotional_brief.md`.

### Worn warmth continuation (2026-10-08) — four wired local derivatives, NOT visually accepted

This supersedes the preceding partial-pass status: after owner permission to use free assets,
four 128px / 32-level-channel albedos are wired under assets/textures/worn_warmth/.
Wood/paper reuse documented local CC0 sources (Poly Haven / ambientCG); wallpaper derives from
project-authored stripes, baize is authored deterministic weave. No AI images were obtained.
Originals, printed forms, UV scales/tints, lighting, geometry, gameplay and audio are preserved.
Nearest filtering and matte felt are guarded by a new 25-assertion material suite.
Latest full regression rerun: **40 suites / 1977 assertions / 0 FAIL**, lint and Python tests green.
The first run failed shift_director_test (exit 5); isolation and full rerun passed (132).
Cause remains unresolved; isolation also emitted detached-node OfficeFoley binding errors.
Known boot shutdown resource leaks remain, so **zero-error boot is NOT achieved**.
No new windowed 720p/1080p captures or human emotional acceptance; 2D repeat sheets are not
Godot screenshots. Current status: integrated candidate pending visual acceptance.
Details/provenance: docs/art/state_2026-10-08/worn_warmth/03_local_asset_integration.md.
No commit/push. The unaccepted authored hand remains unchanged in this texture continuation.

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
| `tools/author_writer_hand.py` → `tools/build_authored_writer_hand.gd` | `hand_authored_v1.json` → `hand_authored_v1.res` (**активная кисть**) | сохранённый `hand_authored_frame.json`; не меняет scene/pen/cloth; frame tool только после изменения пера |
| `tools/build_writer_hand.gd` (**старый hand; cloth/scene**) | `hand_v3/cuff_v3/forearm_v3` `.res`; **edits `scenes/telegraph/transcript_paper.tscn`** (Pen `rotation`, `WriterRig.elbow_offset_rig`) | loads the office to seat the operator; rerun after moving desk/paper/seat |
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


## Screenshot follow-up 2026-10-08

Windowed Godot after captures now exist in worn_warmth/windowed_720p (1280×720)
and windowed_1080p (actual 1920×1061, OS-limited, NOT exact 1080p). 13 viewpoints each.
See docs/art/state_2026-10-08/worn_warmth/04_windowed_screenshots.md for art-fixture
conditions. No same-camera before, gameplay route acceptance, or hand acceptance.
This supersedes the earlier claim that no new windowed captures were available.
