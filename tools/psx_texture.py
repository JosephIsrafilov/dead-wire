"""Prepare authored albedo images for the office's 128px material grid.

python tools/psx_texture.py SOURCE OUTPUT [--tileable] [--match EXISTING]
Only transforms supplied pixels; never generates substitute art.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image


LEVELS = np.rint(np.linspace(0, 255, 32)).astype(np.uint8)


def prepare(image, tileable=False, reference=None):
    pixels = np.asarray(image.convert("RGB").resize((128, 128), Image.Resampling.BOX), dtype=np.float64)
    if reference is not None:
        target = np.asarray(reference.convert("RGB"), dtype=np.float64).mean(axis=(0, 1))
        pixels += target - pixels.mean(axis=(0, 1))
    if tileable:
        # Blend only four texels at each seam. Never mirror the whole grain/pattern.
        for axis in (0, 1):
            for i in range(4):
                near = [slice(None), slice(None)]
                far = [slice(None), slice(None)]
                near[axis], far[axis] = i, -i - 1
                a, b = pixels[tuple(near)].copy(), pixels[tuple(far)].copy()
                weight = (1.0 - i / 4.0) * 0.5
                pixels[tuple(near)] = a * (1.0 - weight) + b * weight
                pixels[tuple(far)] = b * (1.0 - weight) + a * weight
    indices = np.rint(np.clip(pixels, 0, 255) * 31 / 255).astype(np.uint8)
    return Image.fromarray(LEVELS[indices])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--tileable", action="store_true")
    parser.add_argument("--match", type=Path, help="Match existing texture mean RGB, preserving material brightness")
    args = parser.parse_args()
    with Image.open(args.source) as source:
        if min(source.size) < 128:
            parser.error("Source must be at least 128px on each axis; keep the unmodified original")
        if args.match:
            with Image.open(args.match) as reference:
                result = prepare(source, args.tileable, reference)
        else:
            result = prepare(source, args.tileable)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    print(f"Prepared {args.output} (128x128, 32 levels/channel)")


if __name__ == "__main__":
    main()
