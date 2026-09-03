"""Reports readability metrics for DEAD WIRE evidence captures.

    python tools/measure_luminance.py docs/art/m1_visual_acceptance/final
    python tools/measure_luminance.py <dir_a> <dir_b>   # side-by-side delta

Automated brightness numbers never prove visual quality. They only catch frames
that are crushed so far into black that nothing in them can be judged at all.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

CRUSH_THRESHOLD = 32


def measure(path: Path) -> dict[str, float]:
	image = Image.open(path).convert("L")
	histogram = image.histogram()
	pixel_count = sum(histogram)
	weighted = sum(level * count for level, count in enumerate(histogram))
	crushed = sum(histogram[:CRUSH_THRESHOLD])
	blown = sum(histogram[250:])
	return {
		"mean": weighted / pixel_count,
		"crushed_pct": 100.0 * crushed / pixel_count,
		"blown_pct": 100.0 * blown / pixel_count,
	}


def collect(directory: Path) -> dict[str, dict[str, float]]:
	return {png.name: measure(png) for png in sorted(directory.glob("*.png"))}


def print_single(directory: Path) -> None:
	results = collect(directory)
	print(f"{directory}  ({len(results)} PNG)")
	print(f"{'file':<38}{'mean':>8}{'<32 %':>9}{'>250 %':>9}")
	for name, metrics in results.items():
		print(f"{name:<38}{metrics['mean']:>8.1f}{metrics['crushed_pct']:>9.1f}{metrics['blown_pct']:>9.1f}")
	if results:
		mean_of_means = sum(m["mean"] for m in results.values()) / len(results)
		worst = min(results.items(), key=lambda item: item[1]["mean"])
		print(f"\nmean of means: {mean_of_means:.1f}   darkest: {worst[0]} ({worst[1]['mean']:.1f})")


def print_delta(before_dir: Path, after_dir: Path) -> None:
	before = collect(before_dir)
	after = collect(after_dir)
	shared = [name for name in after if name in before]
	print(f"{before_dir}  ->  {after_dir}   ({len(shared)} shared PNG)")
	print(f"{'file':<38}{'mean':>16}{'<32 %':>16}")
	for name in shared:
		b, a = before[name], after[name]
		print(
			f"{name:<38}"
			f"{b['mean']:>7.1f}->{a['mean']:<7.1f}"
			f"{b['crushed_pct']:>7.1f}->{a['crushed_pct']:<7.1f}"
		)
	missing = [name for name in after if name not in before]
	if missing:
		print(f"\nonly in {after_dir.name}: {', '.join(missing)}")


def main(argv: list[str]) -> int:
	if len(argv) == 2:
		print_single(Path(argv[1]))
	elif len(argv) == 3:
		print_delta(Path(argv[1]), Path(argv[2]))
	else:
		print(__doc__)
		return 2
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv))
