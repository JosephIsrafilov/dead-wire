# Onboarding, legibility and the notice board — pass report

Date: 2026-10-21, Asia/Baku. Owner feedback driving this pass:

> «непонятно, что происходит вообще... рандомный набор непонятных звуков...
> как-то играться скучно, непонятно»
> «окно будто немного странное... доска не предписывается»
> «как он подвинул, и приказ работал — как-то странно»
> «Classic — чуть-чуть убавить и в этом стиле продолжать»

Every item below was measured or seen in a captured frame before and after.
Nothing here is a new system: the guidance controller, the shift director and
the board already existed. What was missing was **content and one honest hook**.

---

## 1. "Непонятно, что происходит" — the room now answers its own sounds

### What was actually wrong

The entry thought said `Lamp first. Then the chair and the key.` — a procedure
and nothing else. Every sound in the room arrived unnamed. The probe
(`tools/ambience_probe.gd`) showed four simultaneous beds plus two event
sources the player had no way to identify:

| source | bus | dB | where | note |
|---|---|---|---|---|
| RoomTonePlayer | Ambience | −30.0 | 2D | continuous |
| WindPlayer | Ambience | −27.0 | (−1.5, 1.55, −2.36) | at the window |
| StovePlayer | Ambience | −31.0 | (2.1, 0.75, 1.55) | at the stove |
| ClockPlayer | Ambience | −35.0 | (−2.8, 2.16, 0.62) | 0.13 s tick |
| **foreign traffic** | wire | — | — | **full Morse, slot 1, 4 s in, not addressed to the player** |
| **creaks** | Ambience | −14.0 | 8 anchors | **unexplained settling** |

The foreign bulletin is the worst offender: `SLOW DANCER LEADS DIEGO SECOND`
plays on the sounder four seconds into slot 1 and *nothing anywhere says it is
not the player's telegram*. That single event explains most of "рандомный
набор непонятных звуков".

### What changed

`NightGuidanceController` already existed and was already wired; it only spoke
about procedures. It now also speaks about **events**, from authored data, never
from `WorldState`:

- `data/night_guidance/m1_guidance.tres` gained a `reactions` array
  (`call`, `answered`, `missed`, `signal_end`, `copy_done`, `routed`,
  `route_lapsed`, `foreign`, `creak`).
- `night_guidance_data.gd` gained `reaction_for(kind)`.
- `night_guidance_controller.gd` gained `react(kind, delay)`, a queued reaction
  that speaks at the next free moment, plus hooks on
  `ShiftDirector.call_started / call_answered / traffic_missed /
  foreign_traffic_heard` and `UneaseDirector.creaked`.
- `shift_director.gd` gained `signal foreign_traffic_heard(text)` so the night
  can say "that was not for this office" without the controller reaching into
  the director's internals.

Rules the controller enforces, each pinned by a test:

| rule | why |
|---|---|
| A reaction outranks a pending procedure | the player is asking "what was that" |
| Never while blocked (wire, document, board, pause) | it must not talk over Morse or a page |
| Goes stale after 8 s and is dropped | a thought describing a finished moment is a lie |
| Silenced by `contextual_thoughts_enabled` | the options switch means what it says |
| Never quotes `WATER`, `WATCHER`, correctness or a verdict | it may not solve the game |

The entry thought now names the room's own sounds:

> `Lamp first. Then the chair and the key. The wind is the window, the tick is
> the clock, the fire is the stove — nothing here is unexplained.`

**Files:** `data/night_guidance/m1_guidance.tres`,
`scripts/office/night_guidance_data.gd`,
`scripts/office/night_guidance_controller.gd`,
`scripts/office/shift_director.gd`
**Test:** `tests/guidance/reaction_thought_test.gd` (80 assertions)

---

## 2. "Как он подвинул, и приказ работал — как-то странно" — the lever now explains itself

The confusion is real and the design is deliberate: the routing board is a
**physical order instrument**, not a truth-check. `M1_CORE_HOOK_PRODUCTION_SPEC.md`
§4C rejects reusing it as the trust decision for exactly this reason — "lever
отвечает на вопрос о маршруте, а не о доверии записи". But nothing on the object
said so, so it read as a menu that ought to match the telegram.

Two additions, both diegetic, no tutorial box and no new UI:

1. A painted line on the slate under the header card:
   `THROW = SEND. IT DOES NOT READ THE COPY.`
2. The `route` thought rewritten from
   `Orders are in the ledger. Routes go through the wall board.`
   to
   `The order is on the sheet. The lever does not agree with the paper — it
   sends what I decide to send.`

The line was placed by measurement, not by eye: it sits at y 0.958, below the
header card's bottom strip (ends 0.982) and above the `MAIN` label (0.90), and
it clears the slate width at `pixel_size 0.0024`. The first two attempts were
clipped behind the header card and then too dim to read; both were caught in
captures, not assumed.

**Files:** `scenes/telegraph/routing_board.tscn`,
`data/night_guidance/m1_guidance.tres`
**Frames:** `frames/board.png`

---

## 3. The notice board — "не предписывается"

### What the frame showed

`frames/` from the first capture: five small papers scattered across a large
empty baize, with the two lower notices sitting at the very bottom edge. Measured
geometry:

- baize: 0.700 × 0.600 m, centred (1.620, 1.550)
- papers: ~0.12 × 0.10–0.15 m each, all clustered in one horizontal band
- result: roughly 60% of the board bare, papers reading as flecks

### Fixes

1. **Scale and layout.** The four notices are roughly twice the area and now
   occupy the four quadrants around the register card, so the papers reach
   toward the baize edges the way pinned paper actually does
   (`PINNED` in `tools/build_office_props_blender.py`).
2. **Ink legibility.** The four notices had `outline_size = 0`, so 12–13 px dark
   letterpress on dark paper lost its thin strokes in this dim room. The one
   label that read clearly, `DutyRosterText`, had `outline_size = 1`. The
   notices now match it, with a warm paper-toned outline rather than white.

### A real bug found on the way

After rebuilding the mesh, the ink and the papers disagreed on screen. The
probes disagreed with the screen, which is the useful signal:

- `tools/notice_fit_probe.gd` compared sizes → all "OK"
- `tools/notice_align_probe.gd` compared positions → delta 0.000 m
- `tools/wall_props_paper_probe.gd` read the baked mesh directly → **vertices
  still at the old positions**

The `.res` had been rebuilt but Godot was still serving a stale imported cache
of the `.glb`. `--import` followed by `import_office_props.gd` fixed it, and the
paper vertices then matched `PINNED`. Without the third probe this would have
been "fixed" by moving the labels to match a stale mesh.

**Files:** `tools/build_office_props_blender.py`,
`scenes/style_tests/props/office_storytelling_props.tscn`
**Frames:** `frames/notice_board.png`, `frames/notice_board_close.png`,
`frames/notice_board_wide.png`

---

## 4. "Classic — чуть-чуть убавить"

`CLASSIC_LINES` 480 → **540**. At the project's 720p window that is scale
0.667 → 0.750, a 12.5% finer pixel — "чуть-чуть", not a style change. The grade
still samples every screen line (`pixel_size = 1`), so the character is still
nearest-filtered, unshaded-per-vertex PSX; only the render resolution moved.

`readability_policy.gd`, `tests/presentation/readability_policy_test.gd` and
`tests/presentation/production_readability_test.gd` updated together.

**Files:** `scripts/presentation/readability_policy.gd`
**Tests:** 33 assertions (policy) + 7 (production)

---

## 5. Tooling: why lint appeared to fail

`.venv-tools/Scripts/gdlint.exe scripts/` reported **63 problems**, all of the
form `Cannot open file '...': Cannot create a file when that file already exists`.
None of them were code. Two defects in `gdtoolkit` itself:

1. `parser.py` used `if not os.path.exists(d); os.makedirs(d)` — a TOCTOU race,
   so two concurrent linters both pass the check and one raises
   `FileExistsError`. Now `os.makedirs(d, exist_ok=True)`.
2. `get_cache_directory()` used `os.path.expandvars("%LOCALAPPDATA%")`, which
   leaves an unset variable verbatim on Windows, producing a relative path that
   resolved to a directory the process did not own. It now honours
   `GDTOOLKIT_CACHE_DIR`, then `%LOCALAPPDATA%` only if it actually expanded,
   then `~/.cache`.

With those two fixed, `scripts/` lints **0 problems**.

---

## Verification

- `tests/guidance/reaction_thought_test.gd` — 80 assertions, all pass
- `tests/guidance/night_guidance_test.gd` — updated for the new entry thought
- `tests/presentation/readability_policy_test.gd` — 33 assertions
- `tests/presentation/production_readability_test.gd` — 7 assertions
- `scripts/` — `gdlint`: **0 problems**
- `routing_board.tscn` — loads headless with no errors

Known non-regressions, both reproduced on the untouched baseline:

- `tests/guidance/wind_guidance_test.gd` passes every assertion but
  intermittently exits `0xC0000005` at teardown (reproduced 1-in-4 on the
  stashed baseline).
- `tests/telegraph/amendment_contract_test.gd` fails from an uncommitted
  pre-existing edit in `scripts/telegraph/session/telegraph_session_controller.gd`.

## What this pass did NOT do

- No voice acting, no subtitle system, no forced tutorial, no quest marker.
- No change to Morse timing, the tape register, or any deadline.
- The night backdrop behind the window is still a flat painted quad — depth
  layers are a separate pass.
- The onboarding content is English, matching the rest of the game.
