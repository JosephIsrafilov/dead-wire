# Repository baseline

Branch: `codex/hand-rebuild-handoff`
HEAD: `f82939d9995ec2761e730b1fe8dcaa033bf0be41`

## Worktree snapshot

99 status entries: 33 modified paths, 66 untracked paths. No staged changes reported. Existing uncommitted work is preserved; do not reset, clean, checkout, stash, or otherwise discard it.

Modified paths (33):

- `data/scenarios/m1_scenario_3_core_hook.tres`
- `docs/HANDOVER.md`
- `docs/third_party_assets.md`
- `scenes/office/m1_office.tscn`
- `scenes/telegraph/sounder.tscn`
- `scenes/telegraph/tape_register.tscn`
- `scenes/telegraph/telegraph_key.tscn`
- `scripts/audio/office_foley.gd`
- `scripts/office/dawn_evidence.gd`
- `scripts/office/m1_office_controller.gd`
- `scripts/state/knowledge_state.gd`
- `scripts/telegraph/hardware/tape_register_controller.gd`
- `scripts/telegraph/session/telegraph_commit_option.gd`
- `scripts/telegraph/session/telegraph_scenario_data.gd`
- `scripts/telegraph/session/telegraph_session_controller.gd`
- `scripts/telegraph/ui/copy_commit_desk.gd`
- `scripts/telegraph/ui/dispatch_ledger.gd`
- `scripts/telegraph/ui/duty_sheet.gd`
- `scripts/telegraph/ui/routing_board.gd`
- `scripts/ui/document_viewer.gd`
- `scripts/ui/pause_menu.gd`
- `tests/audio/intro_music_test.gd`
- `tests/integration/night_recovery_test.gd`
- `tests/office/shift_director_test.gd`
- `tests/telegraph/copy_commit_desk_test.gd`
- `tests/telegraph/duty_sheet_test.gd`
- `tests/telegraph/routing_board_test.gd`
- `tests/telegraph/tape_register_test.gd`
- `tests/telegraph/telegraph_scenario_data_test.gd`
- `tests/telegraph/telegraph_session_controller_test.gd`
- `tools/commit_input_route_capture.gd`
- `tools/first_night_playthrough.gd`
- `tools/window_evidence_capture.gd`

Untracked paths (66; directories shown as reported by git):

- `.hermes/`
- `assets/fonts/courierprime/`
- `assets/models/instruments_v1/`
- `assets/textures/instruments_v1/`
- `docs/art/state_2026-10-10/`
- `docs/plans/2026-10-10_INSTRUMENT_FIRST.md`
- `docs/plans/2026-10-10_MECHANICS_EVIDENCE_CHOICE.md`
- `docs/research/mechanics_2026-10-10/`
- `findings.md`
- `progress.md`
- `scenes/ui/amendment_editor.tscn`
- `scripts/telegraph/hardware/tape_ink_event.gd`
- `scripts/telegraph/hardware/tape_ink_event.gd.uid`
- `scripts/telegraph/session/amendment_text.gd`
- `scripts/telegraph/session/amendment_text.gd.uid`
- `scripts/telegraph/session/route_action.gd`
- `scripts/telegraph/session/route_action.gd.uid`
- `scripts/ui/amendment_editor.gd`
- `scripts/ui/amendment_editor.gd.uid`
- `task_plan.md`
- `tests/audio/foley_lifecycle_test.gd`
- `tests/audio/foley_lifecycle_test.gd.uid`
- `tests/integration/amendment_input_test.gd`
- `tests/integration/amendment_input_test.gd.uid`
- `tests/integration/amendment_office_test.gd`
- `tests/integration/amendment_office_test.gd.uid`
- `tests/integration/amendment_pointer_test.gd`
- `tests/integration/amendment_pointer_test.gd.uid`
- `tests/integration/office_load_atomicity_test.gd`
- `tests/integration/office_load_atomicity_test.gd.uid`
- `tests/integration/route_deadline_test.gd`
- `tests/integration/route_deadline_test.gd.uid`
- `tests/telegraph/amendment_contract_test.gd`
- `tests/telegraph/amendment_contract_test.gd.uid`
- `tests/telegraph/amendment_record_test.gd`
- `tests/telegraph/amendment_record_test.gd.uid`
- `tests/telegraph/instrument_art_test.gd`
- `tests/telegraph/instrument_art_test.gd.uid`
- `tests/telegraph/route_acceptance_test.gd`
- `tests/telegraph/route_acceptance_test.gd.uid`
- `tests/telegraph/route_authority_test.gd`
- `tests/telegraph/route_authority_test.gd.uid`
- `tests/telegraph/route_reentrancy_test.gd`
- `tests/telegraph/route_reentrancy_test.gd.uid`
- `tests/telegraph/tape_evidence_test.gd`
- `tests/telegraph/tape_evidence_test.gd.uid`
- `tests/ui/amendment_editor_test.gd`
- `tests/ui/amendment_editor_test.gd.uid`
- `tests/ui/amendment_lifetime_test.gd`
- `tests/ui/amendment_lifetime_test.gd.uid`
- `tests/ui/tape_layout_test.gd`
- `tests/ui/tape_layout_test.gd.uid`
- `tools/build_instruments_blender.py`
- `tools/import_instruments.gd`
- `tools/import_instruments.gd.uid`
- `tools/instrument_motion_capture.gd`
- `tools/instrument_motion_capture.gd.uid`
- `tools/mechanics_demo.gd`
- `tools/mechanics_demo.gd.uid`
- `tools/mechanics_ui_capture.gd`
- `tools/mechanics_ui_capture.gd.uid`
- `tools/verify_instruments.py`
- `tools/verify_mechanics.py`
- `tools/verify_mechanics_test.py`
- `tools/with_preserved_settings.py`
- `tools/with_preserved_settings_test.py`

## Prior recorded test baseline and open issues

Previously recorded baseline: 61 suites / 2396 assertions / 0 assertion failures. 18 suites report shutdown `resources still in use` errors. Native access violation `3221225477` remains open; 7 Texture RID leaks remain open. Baseline not re-run in this pass.

## This pass

A03 wrapper test ran RED then GREEN. No engine run was performed. No Godot command was run. Real APPDATA `settings.cfg` not touched; preservation tests used temporary files under TMPDIR. No commit or push.

## A02 stability follow-up (2026-10-11)

Isolated `tests/office/shift_director_test.gd` x10 via `tools/repeat_engine_exit.py` (settings preserved): 9/10 harness-passed; run 04 exited `0xC0000005` (3221225477) after printing all 132 PASS lines and the PASSED banner. Native access violation recurred in a fresh isolated process, so it does not depend on a predecessor suite. Stop condition applied: 0 of 3 serial full regressions run. No root cause, no fix. Evidence: `docs/research/readable_pass/stability_followup/REPORT.md` and `repeats/shift_isolated_a02/20261011_192904_b85134ac/`.
