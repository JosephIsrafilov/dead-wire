# DEAD WIRE: First Night Vertical Slice

Completed first-night loop: title entry, office inspection, seated telegraph watch, deterministic Morse playback, transcript inspection, routing, physical copy filing, investigation clues, attention event, dawn handover, exit ending, and restart.

Key fixes include stable scenario completion signals, routing deadlines beginning after transmission, explicit unread/lapsed handling, cancellation of pending attention figures, independent WorldState/KnowledgeState evidence, physical filing targets, document typography, contextual procedure guidance, pause/restart correctness, local atmosphere hush, and authored foley for paper, stamp, lever, and latch actions. Visual pass adds textured wood/paper materials, operator hand and sleeve meshes, lamp chimney, table legs, readable filing labels, and warmer controlled lighting.

## Verification

- `tools/run_all_tests.ps1`: **34 suites, 1,359 assertions, 0 failures**.
- Real-time WATER playthrough: **0 failures, 14 screenshots**, ending and restart passed.
- Real-time WATCHER playthrough: **0 failures, 14 screenshots**, ending and restart passed.
- Real-time LAPSED playthrough: **0 failures, 14 screenshots**, unfiled deadline, ending, and restart passed.
- Captured master audio WAV from WATER run: `.dream-loop/playthrough_water/watch_audio.wav` (17.2 MB, non-empty recording).
- Captures and logs are retained under `.dream-loop/` for visual review; the directory is ignored by git.

Run commands:

```powershell
rtk proxy powershell -NoProfile -File tools/run_all_tests.ps1
rtk proxy powershell -NoProfile -Command "& 'C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path . --script res://tools/first_night_playthrough.gd -- --capture"
```

The automated playthrough drives production raycasts and InputMap actions. It verifies mechanics, timing, rendered captures, actual audio recording, ending, and clean state reset. Subjective human fear/readability and long-session hardware coverage remain outside this automated evidence.
