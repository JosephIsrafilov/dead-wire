# tdc_air

- source: https://archive.org/details/designers-choice-complete
- author: Nicholas A. Judy (The Designer's Choice)
- license: CC0 1.0
- note: Same library: a quiet-night recording with a faint fan somewhere in the building.
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
| `amb_quiet_nighttime.flac` | `amb_quiet_nighttime.wav` | 147 s | 177 s | 52651358 | `37ca2ae1a6ff5b05…` | `1d4108d707980805…` |

Cut times and filters live in `tools/town_audio_sources.py`; the build is
`tools/build_town_audio_recordings.py`.
