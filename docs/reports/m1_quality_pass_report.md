# M1 Quality Pass — Current Evidence

Updated: 2026-09-06  
Scope: first night office loop and core hook presentation

## Defects found and fixed

- `CopyCommitDesk` labels used the opposite world-space basis from the readable
  `TranscriptPaper` label. In the previous `02_commit_ready.png`, the labels
  were inverted relative to the player camera and read as bright debug text over
  the wood grain.
- Copy labels were too small and their origin sat at the edge of the physical
  plates. The desk now uses the same upright paper basis as the transcript,
  centered label bounds, dark ink, warm edge contrast, and a larger authored
  glyph size. Meaning remains in the words and `VOID` stamp; color is only an
  accent.
- The explicit `lapse_commit()` terminal path recorded state but did not update
  the physical desk. The office now mirrors a lapse as `UNFILED` / `NO COPY
  FILED`, without selecting or stamping either authored copy.
- The capture harness previously covered only the WATER branch. It now covers
  WATER, WATCHER, lapsed, delayed consequence, and reset from the production
  scene at 1280x720.

## Changed files

- `scenes/telegraph/copy_commit_desk.tscn`
- `scripts/telegraph/ui/copy_commit_desk.gd`
- `scripts/office/m1_office_controller.gd`
- `tests/telegraph/copy_commit_desk_test.gd`
- `capture_m1_luna_completion.gd`
- `docs/reports/m1_quality_pass_report.md`

## Runtime evidence

The production capture harness completed successfully with Godot 4.7.1
Forward+ and Dummy audio. Every PNG below is 1280x720 and was written from the
current tree:

| Capture | Evidence |
| --- | --- |
| `01_writer_mid.png` | Writer remains active during `RECEIVING`. |
| `02_commit_ready.png` | Both copy choices are upright and readable after transcript inspection. |
| `03_commit_water_stamped.png` | WATER selection locks the desk and stamps one line. |
| `04_consequence_figure.png` | Figure begins only after the neutral recovery delay. |
| `05_commit_watcher_stamped.png` | WATCHER selection is independently covered. |
| `06_commit_lapsed.png` | Lapse displays `UNFILED` without selecting a copy. |
| `07_reset_idle.png` | Reset clears the figure and commit presentation. |

Latest capture hashes are printed by `capture_m1_luna_completion.gd`; the
latest run produced seven unique SHA-256 values.

## Automated verification

Passed after the changes:

- `tests/telegraph/copy_commit_desk_test.gd` — 21 assertions
- `tests/telegraph/transcript_paper_test.gd` — 22 assertions
- `tests/telegraph/telegraph_session_controller_test.gd` — 47 assertions
- `tests/integration/m1_office_integration_test.gd` — full production flow,
  including both core-hook commit semantics and delayed figure observation
- `tests/events/window_observation_test.gd` — pending, visible, observed and
  expiry paths
- `capture_m1_luna_completion.gd` — seven production captures and branch checks

Godot still prints the host certificate-store warning and may print ObjectDB
teardown warnings; these runs exited successfully and had no assertion
failures. The full `tools/run_all_tests.ps1` run remains the final regression
check for this tree.

## Remaining acceptance

Automated verification is complete for the changed paths. Human acceptance is
still required: a blind first-time player should complete intro → duty sheet →
open line → call → receive → inspect → commit or lapse → visible consequence →
dawn without being told the words `WATER`, `WATCHER`, or the expected next
interaction. Test 1280x720 first, then 1920x1080 and 1280x800. Record whether
the player notices the mismatch, understands the next action, sees the stamp or
UNFILED result, and connects the delayed window event to the preceding desk
decision.
