"""Render handwriting sample sheets for the owner's choice (plan 5.1).

Reads the shipped Elias Working glyph SVGs and draws the same lines of copy in
three hands on a paper-coloured sheet. Writes PNGs only to
.dream-loop/frames/handwriting/ and never touches the shipped font.

    .venv-tools/Scripts/python.exe tools/handwriting_samples.py
"""
import math
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_elias_font as font  # noqa: E402

OUT = font.ROOT / ".dream-loop" / "frames" / "handwriting"
SCALE = 2
W, H = 1000, 520
PAPER = (222, 210, 182)
INK = (38, 29, 21)
LINES = ["WATCHER AT MINE NO. 3", "TRAIN 17 HELD AT GRADE", "NO ONE ON THE LINE 4:10"]

VARIANTS = {
    "a_current": {"lean": 0.0, "width": 2.7, "pressure": 0.0, "jitter": 0.0, "squeeze": 1.0},
    "b_pressure": {"lean": 0.0, "width": 2.4, "pressure": 1.3, "jitter": 1.2, "squeeze": 1.0},
    "c_hurried": {"lean": 0.12, "width": 2.1, "pressure": 0.8, "jitter": 2.0, "squeeze": 0.86},
}


def glyph_strokes(ch):
    name = "glyph_space.svg" if ch == " " else f"glyph_u{ord(ch):04X}.svg"
    path = font.OUT / name
    return font.read_svg_strokes(path) if path.exists() else []


def wobble(seed, amount):
    # Deterministic per-letter noise in [-amount, amount].
    return (math.sin(seed * 12.9898) * 43758.5453 % 1.0 * 2.0 - 1.0) * amount


def render(variant):
    w, h = W * SCALE, H * SCALE
    buf = bytearray(PAPER * (w * h))

    def disc(x, y, r):
        rr = r * r
        for yy in range(max(0, int(y - r - 1)), min(h, int(y + r + 2))):
            row = yy * w
            for xx in range(max(0, int(x - r - 1)), min(w, int(x + r + 2))):
                if (xx - x) ** 2 + (yy - y) ** 2 <= rr:
                    i = (row + xx) * 3
                    buf[i:i + 3] = bytes(INK)

    size = 0.62 * SCALE
    seed = 0
    for line_no, text in enumerate(LINES):
        pen_x = 60.0 * SCALE
        base_y = (110 + line_no * 140) * SCALE
        for ch in text:
            seed += 1
            strokes = glyph_strokes(ch)
            if not strokes:
                pen_x += 14 * size * 1.6
                continue
            min_x, _min_y, max_x, _max_y = font.stroke_bounds(strokes)
            dy = wobble(seed, variant["jitter"]) * SCALE
            tilt = wobble(seed + 0.5, variant["jitter"] * 0.02)
            for stroke in strokes:
                pts = []
                for x, y in stroke:
                    lx = (x - min_x) * variant["squeeze"] + variant["lean"] * (54.0 - y) + tilt * (54.0 - y)
                    pts.append((pen_x + lx * size * 1.6, base_y + (y - 54.0) * size * 1.6 + dy))
                for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                    seg = math.hypot(x1 - x0, y1 - y0)
                    # Downstrokes press harder: width follows the stroke's direction.
                    down = (y1 - y0) / seg if seg > 0 else 0.0
                    r = variant["width"] * 0.5 * SCALE * 1.6 * size * (1.0 + variant["pressure"] * 0.35 * down)
                    steps = max(1, int(seg))
                    for n in range(steps + 1):
                        t = n / steps
                        disc(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, max(r, 0.6))
            pen_x += (max(18, max_x - min_x + 8) * variant["squeeze"]) * size * 1.6
    return downsample(buf, w, h)


def downsample(buf, w, h):
    out = bytearray(W * H * 3)
    for y in range(H):
        for x in range(W):
            for c in range(3):
                total = 0
                for sy in range(SCALE):
                    row = (y * SCALE + sy) * w
                    for sx in range(SCALE):
                        total += buf[(row + x * SCALE + sx) * 3 + c]
                out[(y * W + x) * 3 + c] = total // (SCALE * SCALE)
    return out


def png(buf):
    raw = b"".join(b"\x00" + bytes(buf[y * W * 3:(y + 1) * W * 3]) for y in range(H))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, variant in VARIANTS.items():
        path = OUT / f"hand_{name}.png"
        path.write_bytes(png(render(variant)))
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
