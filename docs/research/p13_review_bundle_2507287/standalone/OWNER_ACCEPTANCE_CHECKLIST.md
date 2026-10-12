# Owner acceptance checklist — M1 Sound Designer Evaluation Build (p13, 2026-10-12)

Package: `builds/windows-beta_final/p13-dead-wire-windows-beta-25072877efe9-6dc8868431dd.zip`
SHA-256: `1d411edc9dd411102ab2c1e40a02b6bbc769fe8974ce6f44e3dd7df3440d8c96`
Engine: Godot 4.8-dev7 official (`4.8.dev7.official.c971f93e7`), PR #117991 present in source.

## Automated status (do not re-verify, read RESULT.md instead)
Regressions 86/85 with 1 documented engine-registration delta, 2746 assertions, 0 SCRIPT
ERROR; gdlint clean; export clean; packaged PCK 518 entries verified; standalone UI route
(menu → options → office → pause → resume → leave post → menu → quit) recorded and exited 0.

## What the owner must sign off (cannot be automated)
1. [ ] Extract ZIP to a writable folder, run `dead-wire-windows-beta-x86_64.exe`.
2. [ ] SmartScreen / publisher warning appears (unsigned beta) — expected.
3. [ ] Main menu → Begin the Watch → office renders; East Division board legible.
4. [ ] Esc pause opens "LINE HELD"; settings sliders respond (Telegraph/Foley distinct).
5. [ ] Resume works; Leave the Post returns to menu; Quit exits cleanly (no crash dialog).
6. [ ] ART APPROVAL on the framing, board, forms, letterforms (never validated by the agent).
7. [ ] Optional manual step: play ~2 minutes for pacing judgement (human playtest gate).

## Known residuals the owner should see (non-blocking)
- Books in the ledger render without cover textures in the export (preset excludes polyhaven
  textures but ships the referencing .tscn) — pre-existing, cosmetic.
- 7 Texture RID leak warning and some test-teardown audio notices at exit — catalogued.
- One test assertion differs on 4.8 (ClassDB registration of a global script class); game
  behavior unaffected. Owner decision recorded in RESULT.md.

## Distribution rules
- This package may go to the sound designer as an EVALUATION build.
- Do NOT label it public beta, do NOT upload diagnostics/dumps.
- The spoiler sound brief (SOUND_HANDOFF_SPOILERS.md) is delivered separately AFTER the first
  playthrough, not inside the ZIP (verified absent).

## Sound designer handoff (post-send task)
Deliver: the ZIP + the listening checklist in
`docs/research/first_night_2026-10-12_sound_handoff_final_2507287/q3_evidence/audio_provenance_manifest.md`
(MARK/GAP intelligibility, lever throw+stop, pickup vs feed, pen/stamp contacts, wick/wind,
ambience balance, intro/pause/quit transitions) + BETA_REPORT_FORM.md from the package.
Their listening verdict is the expected downstream deliverable, not a precondition for sending.