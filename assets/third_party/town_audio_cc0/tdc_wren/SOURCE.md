# tdc_wren

- source: https://archive.org/details/designers-choice-complete
- author: Nicholas A. Judy (The Designer's Choice)
- license: CC0 1.0
- note: Same library: a Carolina wren, recorded outdoors with other birds behind it.
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
| `carolina_wren_chirping.flac` | `carolina_wren_chirping.wav` | 3.4 s | 11.7 s | 7474468 | `4df45fc91ff5b643…` | `34cc6d92f648a99d…` |

Cut times and filters live in `tools/town_audio_sources.py`; the build is
`tools/build_town_audio_recordings.py`.
