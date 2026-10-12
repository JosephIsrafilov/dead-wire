# First Night beta finish — execution result (2026-10-12)

Status: **PARTIAL. Not ready to send.** Native crash disposition (P4) not done; P2/P3 not done; production, night-water, export-after-fixes and visual/resolution checks not run.

## Changed files (this pass)

- `scripts/ui/document_viewer.gd` — removed literal PowerShell `` `n `` escape fragments and duplicate `HAND_FONT_SIZE`/`HAND_PIXEL_SIZE` lines above `extends`; constants now sit after `HAND_DOC_ID` in the file's existing constant block. CRLF preserved.
- New files only under `docs/research/first_night_2026-10-12_beta_finish/` and `builds/windows-beta/export_2026-10-12_p6/`, `builds/windows-beta/dead-wire-windows-beta-f82939d9995e-584b04bcbefb.zip`.
- No git commit, staging, restore, checkout or reset. No other source edits.

## Protected work

- Inventory before: `preserve/inventory_before.txt` (193 entries, 135 untracked). After: `preserve/inventory_after.txt`, identical set.
- Tracked diff backup: `preserve/tracked_before.patch` (+ stat).

## Checks actually run

| Check | Command result | Evidence |
|---|---|---|
| Lint `scripts/` | `gdlint` — no problems | console |
| Import | Godot `--import`, exit 0, settings preserved | `import_01/result.json` |
| Foley lifecycle | 1 suite, 36 assertions, 0 runtime errors, exit 0 | `foley_01/` |
| Full mechanics regression | 86 suites: **85 passed, 1 failed**, 2732 assertions; child exit codes all 0 except one (exit 1); no native crash in this run | `full_01/summary.json`, `full_01/result.json` (wrapper 0x1) |
| Tools Python tests | 19 OK | `python_tools/out.log` |
| tests/python | 5 OK | `python_tests/out.log` |
| Packager unit tests | 4 OK | `python_tools/packager_test.log` |
| Standalone export (Windows Beta preset) | exit 0, settings preserved | `export_01/` |
| Packaging | 14 files ZIP, build ID `dead-wire-windows-beta-f82939d9995e-584b04bcbefb` | `export_01/package.log` |

Hashes (SHA-256):
- New export EXE `builds/windows-beta/export_2026-10-12_p6/dead-wire-windows-beta-x86_64.exe`: `6fb906a8a6797af980b82f77c9eecb3d097a74a49aa257b5fdff501b292698e9`
- New export PCK: `176bee6f8061625f83dcdea82112d1e843d6eec2bf90134615d6ed53943fc29e`
- ZIP `builds/windows-beta/dead-wire-windows-beta-f82939d9995e-584b04bcbefb.zip`: `abb3f0da76bb1fa77f6c416471614af884095cdc1c3c3d0ae96fdf56d3cfb03b`
- Old root `builds/windows-beta/dead-wire-windows-beta-x86_64.exe/.pck` (Oct 11 23:08) are **stale**; not to be shipped. The ZIP's EXE matches the new export.

ZIP contents check: EXE, PCK, hand-off docs, THIRD_PARTY_NOTICES, font OFL files (cedarville, courierprime, imfell, noto, oldstandard), audio ATTRIBUTION. No tools/tests/docs/research/.hermes/logs/SVG/.py entries.

## Failures and errors (not hidden)

1. **FAIL `tests/integration/player_feedback_test.gd`** — "Live ink rows fit the real sheet". Probe measured the widest row of `TRAIN 17 CLEAR EAST` at **0.1909 m** vs test limit **0.18 m**. Label is 18 px / pixel 0.00148 (plan's intended values); HEAD had 16 / 0.00135. The test is unchanged from HEAD. Not resolved: the threshold must not be lowered, and 10 columns is a design constraint. Options for owner: wider sheet/label, fewer columns, or smaller font (conflicts with legibility plan). Probe script deleted after use.
2. **21 suites with "resources still in use at exit" shutdown ERROR** (also logged in prior evidence). Not diagnosed (P4 scope).
3. **Native crash (0xC0000005)**: not reproduced in this full run (no native exits). This is **one run**, does not establish a fix. Per plan, the release blocker stays open.

## Not done (plan items remaining)

- P1 (partially): Foley RegisterWind fixture topology not reviewed (the test passes, but the fixture inspection was not done); route bounds test passes in full run; no focused runs for desk_geometry, route_explanation, route_reentrancy, routing_mouse, guidance, elias_handwriting_font, transcript_paper, writer_rig_space, readable_settings, settings_exit_paths, procedural_clarity, reference_reading_example (covered only by the full regression).
- P2: fonts/atlas metrics, forms regeneration, live/archive/viewer frames at 720p/1080p, guidance edge cases — **not done**. Visual acceptance: UNVERIFIED.
- P3: OfficeFoley stream/option persistence review, `SOUND_HANDOFF_SPOILERS.md` cleanup, provenance regeneration, listening QA — **not done**.
- P4: crash probe, stack/symbolication, shutdown analysis — **not done**. Older dump metadata only.
- P5: production_evidence_capture, night_water, serial route runs, menu→pause→exit flow, performance sampling — **not done**.
- P6: standalone launch from extracted package (menu/office), class-cache check — **not done**. Only export + packaging performed.

## Ready-to-send disposition

**Not ready.** Open blockers: failing layout assertion, unresolved native crash, shutdown resource errors, incomplete P2–P5 evidence, no standalone launch test. Human/listening/visual tests: NOT RUN. Owner decision needed on the 0.18 m ink-width vs 18 px font conflict.

## Next steps

1. Owner decision on ink-width constraint.
2. P4 diagnostics (requires owner permission for debugger/WER/procdump if needed).
3. Complete P2 forms/fonts, P3 sound docs, P5 capture runs, P6 standalone launch.
4. Independent review by the previous agent; no commit/push done.
