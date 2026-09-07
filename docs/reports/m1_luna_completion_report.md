# M1 Luna Completion Report

Date: 2026-09-05
Status: implementation verified; human acceptance pending

## Scope

This pass audited the existing M1 core hook, read the production capture
harness before relying on its PNGs, ran a Forward+ runtime capture, and made
the smallest presentation fix that the live state exposed.

The existing `capture_12_evidence_shots.gd` covers 16 canonical room frames.
It does not cover the live WriterRig, CopyCommitDesk unlock, stamped commit, or
reset state. Those states are captured separately by
`capture_m1_luna_completion.gd` into `docs/art/m1_visual_acceptance/luna_completion`.

## Confirmed defect and fix

`CopyCommitDesk` was wired to search for `Option1Label`/`Option2Label` and
`Option1Stamp`/`Option2Stamp`, while the production scene contains
`OptionOneLabel`/`OptionTwoLabel` and `OptionOneStamp`/`OptionTwoStamp`. The desk
state changed to enabled, but its physical labels and stamps never updated.

The fix uses the authored scene node names, hides copy labels until transcript
verification, keeps both labels visible after filing, and preserves a visible
`STAMPED`/`VOID` result. Desk labels were rotated toward the operator and
authored as two lines to fit the physical plates at 1280x720.

## State and reset verification

The new runtime harness asserts:

- WriterRig is active while scenario 3 is in `RECEIVING`.
- The desk labels remain hidden in `VERIFYING`, before inspection.
- Inspection enters `AWAITING_COMMIT` and reveals exactly two copy choices.
- `file_water` commits once and disables the desk.
- Reset clears the desk presentation and pending window figure.

The state machine document now reflects the implemented path:

`IDLE -> READY -> RECEIVING -> VERIFYING -> AWAITING_ROUTE/AWAITING_COMMIT -> CONSEQUENCE -> COMPLETE`

## Evidence

All five files are new runtime captures from Godot 4.7.1 Forward+ at 1280x720,
not historical evidence:

- `01_writer_mid.png` - hand/pen rig active during live writing.
- `02_commit_ready.png` - both physical options visible after inspection.
- `03_commit_water_stamped.png` - selected line stamped and desk locked.
- `04_consequence_figure.png` - figure appears only after the neutral delay.
- `05_reset_idle.png` - reset returns to a clean office presentation.

The directory also contains a superseded `04_reset_idle.png` from an earlier
four-frame harness run; it is not part of the current five-frame evidence set.

The harness printed unique SHA256 values for every capture. It was run with the
writable project-local `.godot_user` APPDATA and the supplied console binary.

## Verification run

Passed:

- `tools/run_all_tests.ps1` - 33/33 suites, 1299 assertions, 0 failures.
- `tests/telegraph/copy_commit_desk_test.gd` - 16 assertions.
- `capture_m1_luna_completion.gd` - 5 PNGs and 14 runtime assertions.

The capture run also completed the writer, verification, commit, and reset
paths without a Godot access violation. The engine printed its known Windows
certificate-store warning; it did not affect the run. Both regression runners
now ignore that warning when deciding whether a suite emitted an assertion
failure.

## Remaining limits

No human playtest or human visual acceptance is claimed. The new evidence is
1280x720 only; 1920x1080 and 1280x800 still need review. The capture harness
does not yet render the watcher branch or lapsed branch. Those are suitable
next captures before calling M1 accepted.
