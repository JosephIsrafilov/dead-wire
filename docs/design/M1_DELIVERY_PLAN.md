# M1 Delivery Plan

Date: 2026-09-05
Owner: root orchestrator
Status: first implementation wave delegated; acceptance pending

## Scope and evidence

Finish one coherent office shift before expanding the campaign. M1 is a
compressed hook prototype, not automatically the final campaign Night 1.
Read GDD for narrative direction, production spec for current M1 contracts,
and source/runtime for implementation truth. Old reports are historical evidence.

Core verification, commit and consequence states already exist. Do not rebuild
them. Luna's previous report records 33 suites / 1299 assertions; this is a
reported baseline, not a fresh run by the orchestrator.

The orchestrator inspected `luna_completion/02_commit_ready.png`: text is
upside down from its capture camera and white labels compete with printed paper.
`01_writer_mid.png` is too wide to establish nib contact, glyph timing or
authorship; the block-like rig obscures part of the writing area. These frames
do not establish visual acceptance.

Godot successfully ran for the previous agent with project-local APPDATA.
The earlier claim that the executable was damaged was not established. Do not
replace the engine, delete profiles or launch repeated crashing processes on
that assumption.

## Delegation and ownership

- Luna 5.6, low: lightweight evidence/documentation audit. Own only
  `docs/reports/m1_visual_review_next.md` and
  `docs/reports/m1_playtest_checklist_next.md`. Inspect existing PNGs, check report
  contradictions and create a concrete manual acceptance checklist. No runtime
  changes, engine launches or edits to other reports in this wave.
- Terra 5.6, medium: bounded runtime correctness audit and fixes. Own session,
  attention event and office integration logic plus corresponding behavioral
  tests and `docs/reports/m1_terra_runtime_audit.md`. Confirm observable
  consequence timing, reset/cancel and terminal progression. No visual redesign.
- Root: owns this plan, visual review, integration acceptance and subsequent
  assignments. Preserve unrelated working-tree changes. Review each agent diff
  before broad testing. Runtime launch/capture has one owner at a time.

## Ordered backlog

| ID | Priority | Task and owner | Acceptance |
| --- | --- | --- | --- |
| R1 | P0 | Terra: inspect consequence hold versus actual figure appearance | Completion cannot incorrectly claim observable hold while figure was only pending; explicit bounded fallback prevents softlock if player never looks away |
| R2 | P0 | Terra: reset/cancel and terminal paths | No stale figure, callback, writer or stamp after reset; WATER, WATCHER, lapsed and missed call each progress; completion emitted exactly once |
| R3 | P0 | Root: validate repeatable launch | Document working executable and scoped writable APPDATA; one bounded process, logs and exit code; stop batch on native crash rather than spawning more dialogs |
| V1 | P0 | Next Luna task: local commit label orientation/material fix after root review | Both choices and stamps read upright from reachable player positions; text on a quiet ink/paper region; no answer encoded solely by color |
| V2 | P1 | Next Terra task: physical choice interaction if runtime audit confirms mismatch | Each visible choice has a predictable target, keyboard operation and locked feedback; no accidental commit behind document/pause UI |
| V3 | P1 | Terra: writer presentation only after closeup diagnosis | Capture real seated view at 25/50/75 percent; pen attached to hand, nib contact precedes glyph, withdrawal and reset clean; no major paper occlusion |
| V4 | P1 | Root art direction, Luna bounded scene edits | Consistent desk/window/stove light hierarchy, readable routing and documents, reduced competing paper texture; compare matched before/after views, avoid global shader rewrite |
| G1 | P1 | Root design, Terra implementation | A short reliable practice beat teaches listening and checking before mismatch; no UI reveal of WATER/WATCHER; do not silently turn the fixed 3-slot director into a campaign framework |
| G2 | P1 | Root feel review | Measure complete shift duration and idle time before changing 14/9/7 waits or 45-second deadline; tune one variable at a time with recorded reason |
| A1 | P1 | Terra audio/comfort diagnosis; Luna simple tuning | Sounder remains intelligible, sources localize correctly, hush preserves user volume, bob toggle and seat transition behave through pause/document states |
| E1 | P1 | Root narrative review, Terra only confirmed integration fixes | Dawn evidence distinguishes authored result from knowledge; both commits and lapsed produce an honest ending without claiming an unimplemented external world |
| Q1 | P1 | Terra capture owner, Luna evidence index | Both commits, lapsed, figure pending/visible, writer, reset, pause and exit evidence at 720p, 1080p and 1280x800; actual camera poses and hashes recorded |
| D1 | P2 | Luna documentation | One current status points to exact run evidence; separate automated pass, image review and human acceptance; old reports remain historical |
| H1 | Release gate | Owner/new players, root analysis | Blind first-shift test; record confusion, mismatch discovery, choice understanding, unfair misses and motion discomfort; fix repeated problems before M2 |

Dependencies: R1/R2 before final Q1; V1/V2 before choice playtest;
V3/G1 before judging authorship/mismatch; E1 before ending acceptance.
Do not dispatch the whole backlog in one prompt to a low-cost model.

## Verification and exit criteria

For behavior changes reproduce the defect with a targeted test, implement the
smallest fix, then run related suites. After integrated changes run the full
suite once and inspect logs for parser/script/native errors. Certificate-store
warnings must not hide real failures. Screenshot existence is not readability.

Manually inspect actual gameplay cameras, not only authored capture poses.
Test first-time start, both commits, no answer, no inspection, timeout, pause
during receiving, reset during pending consequence, repeated input and exit.
Keep objective Morse and WorldState/KnowledgeState separation intact.

Use 5 fresh players as an initial qualitative pass, then 8-12 for another
round if repeated issues justify it. Suggested internal targets: 70 percent
notice mismatch, 80 percent know the next action, 70 percent attribute writing
to Elias and understand their choice. These are provisional decision aids,
not statistical proof. Do not tell testers the hook beforehand.

M1 is accepted only when runtime paths work, actual views are readable and a
human can explain the procedure and choice. No claim of fear from unit tests.
Future M2 planning adds a compact external consequence and one new information
problem, not combat, open world, random scares or six unvalidated nights.

## Current progress

- Complete: source/report baseline read and two current images inspected.
- Delivered for root review: Luna lightweight audit and playtest checklist.
- Running: Terra runtime audit/fixes.
- Pending: root diff review, remaining visual inspection and integrated gates.
- Not started: later backlog waves and human playtest.
