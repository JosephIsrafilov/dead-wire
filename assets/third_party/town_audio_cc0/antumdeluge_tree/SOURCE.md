# antumdeluge_tree

- source: https://opengameart.org/content/tree-creaking
- author: AntumDeluge (recording by Department64)
- license: CC0 1.0
- note: A tree creaking, cleaned and peak-normalised to -6 dBFS by the uploader; 44.1 kHz mono FLAC.
- status: source-only. `assets/third_party/` is excluded from both
  export presets and refused by `tools/package_windows_beta.py`; only
  the cut runtime files under `audio/sfx/` ship.

Each file below is a **lossless FLAC excerpt** of the original download, not
a re-encode: the excerpt starts at `origin` seconds of the original and ends
at `end`, so every sample the build cuts is bit-identical to the download.
The original's size, duration and SHA-256 are recorded so the excerpt can be
re-derived from the same upload.

| excerpt | original | origin | end | original bytes | original sha256 | excerpt sha256 |
|---|---|---|---|---|---|---|
| `tree_creak.flac` | `tree_creak.flac` | 0 s | 6.58 s | 231924 | `9bab7c7f68850136…` | `32417a7edc0f469f…` |

Cut times and filters live in `tools/town_audio_sources.py`; the build is
`tools/build_town_audio_recordings.py`.
