# Final M1 Redesign Evidence

The canonical visual-acceptance set is
`res://docs/art/m1_visual_acceptance/final/`, not this legacy directory.
It contains 12 production-scene captures at 1280x720, written by
`res://capture_12_evidence_shots.gd`, reloaded, size-checked, and checked for
unique SHA256 digests by the runner. The runner also writes four matched
before/final side-by-side pairs to `res://docs/art/m1_visual_acceptance/comparison/`.

This directory is retained as prior review evidence only.

## Regeneration

Run the script with the graphical D3D12 Godot executable:

```powershell
& "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\YUSIF\Documents\dead-wire" --script "res://capture_12_evidence_shots.gd" -- --stage=final
```

The script exits nonzero when it cannot instantiate the production scene,
cannot find the player camera, produces a non-1280x720 PNG, cannot reload a
written PNG, produces duplicate image hashes, or cannot compose a matched
comparison pair.
