"""Stage lossless FLAC excerpts of the CC0 recordings the town audio is cut from.

We will not ship 375 MB of full ambience originals, and we will not ship a
re-encoded lossy copy of them either. Each source becomes a FLAC excerpt (FLAC
is lossless, so every sample the build uses is bit-identical to the download)
covering its cut window plus a margin. `excerpts.json` records, per excerpt, the
original's filename, byte size, duration and SHA-256 plus where the excerpt
starts — so the provenance chain survives without the original bytes.

    python tools/stage_cc0_town_audio.py --input <dir of downloads>

`--input` holds the originals named exactly as `tools/town_audio_sources.py`
declares them. Windows come from that same module, so an excerpt can never be
too short for the cut it exists to serve. Nothing here touches `audio/`.

Re-runnable: excerpts are only rewritten when their bytes would change, so a
second run is quiet and the manifest stays stable.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from town_audio_sources import SOURCES, check  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "third_party" / "town_audio_cc0"
MANIFEST = OUT / "excerpts.json"
SAMPLE_FMT = "s32"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def duration(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=False,
    )
    return float(result.stdout.strip())


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True,
                        help="directory holding the original downloads")
    args = parser.parse_args(argv)
    source_dir = Path(args.input)

    problems = check()
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1

    records = []
    for key, source in SOURCES.items():
        original = source_dir / source.original_name
        if not original.is_file():
            print(f"missing original: {original}", file=sys.stderr)
            return 1
        total = duration(original)
        if source.excerpt_end > total + 1e-3:
            print(f"{key}: excerpt ends at {source.excerpt_end}s but the "
                  f"original is {total:.2f}s", file=sys.stderr)
            return 1
        excerpt = OUT / source.pack / (Path(source.original_name).stem + ".flac")
        excerpt.parent.mkdir(parents=True, exist_ok=True)
        previous = sha256(excerpt) if excerpt.is_file() else None
        result = subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-ss", f"{source.excerpt_origin:.3f}",
             "-to", f"{source.excerpt_end:.3f}", "-i", str(original),
             "-c:a", "flac", "-sample_fmt", SAMPLE_FMT, str(excerpt)],
            capture_output=True, check=False,
        )
        if result.returncode != 0:
            print(f"{key}: ffmpeg failed: "
                  f"{result.stderr.decode('utf-8', 'replace')[:200]}",
                  file=sys.stderr)
            return 1
        digest = sha256(excerpt)
        records.append({
            "key": key,
            "pack": source.pack,
            "original_name": source.original_name,
            "original_bytes": original.stat().st_size,
            "original_seconds": round(total, 3),
            "original_sha256": sha256(original),
            "excerpt": excerpt.relative_to(OUT).as_posix(),
            "excerpt_origin": source.excerpt_origin,
            "excerpt_end": source.excerpt_end,
            "excerpt_sha256": digest,
        })
        state = "same" if previous == digest else "wrote"
        print(f"{key:16} {source.pack:16} "
              f"{source.excerpt_origin:8.2f}-{source.excerpt_end:8.2f}s  "
              f"{excerpt.stat().st_size // 1024:>6}K  {state}")

    text = json.dumps(records, indent=1) + "\n"
    if MANIFEST.is_file() and MANIFEST.read_text(encoding="utf-8") == text:
        print(f"\n{MANIFEST.name} unchanged")
    else:
        MANIFEST.write_text(text, encoding="utf-8")
        print(f"\nwrote {MANIFEST.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
