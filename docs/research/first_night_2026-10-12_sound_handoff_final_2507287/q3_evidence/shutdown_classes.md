# Shutdown evidence split (sound_handoff_final_2507287)

Four distinct exit-time classes are catalogued. They are NOT one defect and must not be
declared harmless together.

## Class A — native AV 0xC0000005 (BLOCKER, engine-side)
- Historical: 3 dumps at RVA +0x547AF6, s->self() read in GDScriptLanguage::finish.
- final_regression_2 (4.7.1): rule44_content_test exit 3221225477 after 12/12 PASS. Preserved.
- 4.8-dev7 protocol (this session, q1_engine/runs/): R1/R3 rule44, R2 shift_director,
  R4 production boot — 4/4 exit 0x00000000. No reliable failing 4.7.1 control exists
  (MRP INCONCLUSIVE), so causal attribution stays INCONCLUSIVE. Stability gate for the
  candidate is judged in Phase 4 full regression on the frozen engine+inputs.

## Class B — AudioStreamWAV / AudioStreamPlaybackWAV / StringName "Ambience" (test teardown)
- One sampled suite (atmosphere_test) traced to test-owned ambience playback outliving
  teardown (office_ambience.gd has no _exit_tree; nodes die with the office tree in game).
- q4b/shutdown_b_verdict.md covers THAT suite only, not all suites or the game runtime.
- Present in some headless suite exits (error_bearing count varies run to run: 16→20).
- Disposition: non-blocking residual for the sound-designer evaluation; the packaged game
  graceful quit showed NO such errors. Not silenced anywhere; if a real game defect is ever
  proven, it needs a surgical fix + focused test.

## Class C — RenderingDevice texture RID leaks (windowed runs)
- Exact signature: `WARNING: 7 RIDs of type "Texture" were leaked.
  at: finalize (servers/rendering/rendering_device.cpp:8900)`.
- Present in windowed production capture exits with exit 0; also found in 45 historical
  evidence logs (windowed/headless capture tools). Test/capture-tool teardown ordering:
  textures created by capture tooling are finalized after RenderingServer shutdown check.
- Disposition: non-blocking residual; not observed in the packaged game graceful quit
  (q4b/graceful stderr had no RID warning; final packaged probe repeats in Phase 4).

## Class D — ObjectDB/PagedAllocator "resources still in use" lines
- Broad exit-ordering notice; correlates with capture tools holding scene refs at exit.
- Disposition: non-blocking residual; counted and reported, never suppressed.

## Tooling correction
q4b/graceful_probe.py defects (stdout not saved; FindWindowW(None,None) fallback; unverified
PostMessageW) fixed in this session's graceful_probe2.py (PID-filtered enumeration, both
streams saved, post results, exe/cwd/settings hashes, raw exit). One bounded graceful run is
scheduled against the NEW final package in Phase 4; WM_CLOSE exit 0 alone never proves the
in-menu Quit path.
