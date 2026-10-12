# Shutdown disposition (B) — evidence-based

## Method
1. Representative error-bearing suite re-run with --verbose (tests/office/atmosphere_test.gd,
   86 assertions PASS, exit 0).
2. Graceful-quit probe on the shipped p12 package (WM_CLOSE to the game's own window;
   settings wrapper untouched; raw child exit recorded).

## Findings (representative suite, verbose)
- "resources still in use at exit" decomposes into:
  - Leaked AudioStreamWAV x3 + AudioStreamPlaybackWAV x3 (Reference count 1 each) —
    test-created ambience playback (room_tone_player / OfficeAmbience bus "Ambience") still
    alive at teardown; Godot prints the standard orphan hint.
  - Orphan StringName "Ambience" (static 0, total 6) + BAYER — bus names created at runtime.
- This is suite-teardown ownership, NOT a game defect: OfficeAmbience creates the player in
  _ready and it dies with the office tree; the test harness holds the last Ref at exit.
- The 7 Texture RID warnings seen in windowed capture runs with exit 0 are a separate
  exit-ordering warning class, also present on graceful exits; not the same defect as the
  audio leaks and not proven to be one defect.

## Graceful quit of the packaged game (p12 ZIP)
- WM_CLOSE after 25 s: game exited with raw code 0x00000000 (graceful).
- 0 SCRIPT ERROR, 0 Parse/Failed-to-load/Cannot-open-file in stderr.
- Same exit-time classes (RID/StringName) appear, consistent with the suite finding.

## Conclusion
"resources still in use" in test suites = test-teardown audio ownership; graceful packaged
exit is clean (exit 0). No game-code change is justified by this evidence. The classes stay
catalogued; no blind teardown patch applied. Native crash remains the only open blocker (A).
