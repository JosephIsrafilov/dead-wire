"""Generate 1890s period railway stationery textures for TimetableCard and OperatorCard."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "materials" / "style_tests" / "textures" / "psx"
FONT_REG = ROOT / "assets" / "fonts" / "oldstandard" / "OldStandardTT-Regular.ttf"
FONT_BOLD = ROOT / "assets" / "fonts" / "oldstandard" / "OldStandardTT-Bold.ttf"


def _value_noise(h: int, w: int, scale_x: float, scale_y: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    gh = max(2, int(np.ceil(h / scale_y)) + 2)
    gw = max(2, int(np.ceil(w / scale_x)) + 2)
    grid = rng.random((gh, gw), dtype=np.float32)
    ys = np.linspace(0, gh - 2, h, dtype=np.float32)
    xs = np.linspace(0, gw - 2, w, dtype=np.float32)
    yi = ys.astype(np.int32)
    xi = xs.astype(np.int32)
    yf = (ys - yi)[:, None]
    xf = (xs - xi)[None, :]
    # Smoothstep interpolation
    sy = yf * yf * (3.0 - 2.0 * yf)
    sx = xf * xf * (3.0 - 2.0 * xf)
    n00 = grid[yi[:, None], xi[None, :]]
    n10 = grid[yi[:, None] + 1, xi[None, :]]
    n01 = grid[yi[:, None], xi[None, :] + 1]
    n11 = grid[yi[:, None] + 1, xi[None, :] + 1]
    return (n00 * (1.0 - sx) + n01 * sx) * (1.0 - sy) + (n10 * (1.0 - sx) + n11 * sx) * sy


def make_parchment(w: int, h: int, seed: int, tint: tuple[float, float, float]) -> Image.Image:
    """Aged parchment matching build_paper_forms.gd (fibres, blotches, foxing, handled edges)."""
    fib = (
        _value_noise(h, w, 4.5, 22.0, seed) * 0.65
        + _value_noise(h, w, 2.2, 9.0, seed + 1) * 0.35
        - 0.5
    ) * 0.095
    blot = np.maximum(_value_noise(h, w, 48.0, 48.0, seed + 7) - 0.54, 0.0) * 0.24

    xs = np.arange(w, dtype=np.float32)[None, :]
    ys = np.arange(h, dtype=np.float32)[:, None]
    ex = np.minimum(xs, (w - 1) - xs) / (w * 0.065)
    ey = np.minimum(ys, (h - 1) - ys) / (h * 0.065)
    edge = (1.0 - np.clip(np.minimum(ex, ey), 0.0, 1.0)) * 0.13

    k = 1.0 + fib - blot - edge
    rgb = np.empty((h, w, 3), dtype=np.float32)
    rgb[:, :, 0] = tint[0] * k
    rgb[:, :, 1] = tint[1] * k * (1.0 - blot * 0.28)
    rgb[:, :, 2] = tint[2] * k * (1.0 - blot * 0.55)

    # Deterministic foxing spots
    rng = np.random.default_rng(seed + 19)
    yy, xx = np.ogrid[:h, :w]
    for _ in range(9):
        cx = int(rng.integers(18, w - 18))
        cy = int(rng.integers(18, h - 18))
        rad = int(rng.integers(2, 6))
        mask = (xx - cx) ** 2 + (yy - cy) ** 2 <= rad * rad
        rgb[mask, 0] = rgb[mask, 0] * 0.68 + 0.55 * 0.32
        rgb[mask, 1] = rgb[mask, 1] * 0.68 + 0.40 * 0.32
        rgb[mask, 2] = rgb[mask, 2] * 0.68 + 0.25 * 0.32

    arr = np.clip(rgb * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, mode="RGB")


def draw_double_border(draw: ImageDraw.ImageDraw, w: int, h: int, ink: tuple[int, int, int]) -> None:
    o0, o1 = 14, 24
    draw.rectangle((o0, o0, w - 1 - o0, h - 1 - o0), outline=ink, width=3)
    draw.rectangle((o1, o1, w - 1 - o1, h - 1 - o1), outline=ink, width=1)
    box = 7
    for cx, cy in [
        (o1 + 1, o1 + 1),
        (w - 1 - o1 - box, o1 + 1),
        (o1 + 1, h - 1 - o1 - box),
        (w - 1 - o1 - box, h - 1 - o1 - box),
    ]:
        draw.rectangle((cx, cy, cx + box, cy + box), fill=ink)


def center_text(
    draw: ImageDraw.ImageDraw, w: int, y: int, text: str, font: ImageFont.FreeTypeFont, color: tuple[int, int, int]
) -> None:
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((w - tw) * 0.5, y), text, font=font, fill=color)


def build_timetable_stock() -> None:
    w, h = 512, 412
    img = make_parchment(w, h, seed=44, tint=(0.79, 0.71, 0.53))
    draw = ImageDraw.Draw(img)
    ink = (56, 44, 32)
    faint_ink = (96, 78, 58)
    red_ink = (122, 58, 46)
    f_micro = ImageFont.truetype(str(FONT_BOLD), 11)

    draw_double_border(draw, w, h, ink)
    center_text(draw, w, 30, "B. C. & W. RY.   ·   FORM 44   ·   SPECIAL ORDERS", f_micro, faint_ink)

    # Double divider cleanly above title, single rule cleanly below column header (No./TIME/DIR -> py ~174)
    draw.line((42, 108, w - 42, 108), fill=ink, width=2)
    draw.line((42, 113, w - 42, 113), fill=faint_ink, width=1)
    draw.line((54, 158, w - 54, 158), fill=(134, 114, 88), width=1)
    draw.line((54, 190, w - 54, 190), fill=(116, 96, 72), width=1)

    # Warning divider cleanly in the blank line above bottom spur closure notice
    draw.line((42, 255, w - 42, 255), fill=red_ink, width=2)
    draw.line((42, 260, w - 42, 260), fill=faint_ink, width=1)
    draw.line((42, 304, w - 42, 304), fill=ink, width=1)

    center_text(draw, w, h - 42, "EAST DIVISION  ·  SUPT. OFFICE  ·  APRIL 1890", f_micro, faint_ink)
    img.save(OUT_DIR / "card_timetable_stock.png")


def build_operator_stock() -> None:
    w, h = 400, 340
    img = make_parchment(w, h, seed=71, tint=(0.81, 0.73, 0.56))
    draw = ImageDraw.Draw(img)
    ink = (56, 44, 32)
    faint_ink = (96, 78, 58)
    f_micro = ImageFont.truetype(str(FONT_BOLD), 10)

    draw_double_border(draw, w, h, ink)
    center_text(draw, w, 29, "STATION STANDING POST  ·  NIGHT WATCH", f_micro, faint_ink)

    # Top title rule above heading (~y=92), double divider in blank line (~y=115), footer double below item 5 (~y=248)
    draw.line((44, 74, w - 44, 74), fill=faint_ink, width=1)
    draw.line((36, 113, w - 36, 113), fill=ink, width=2)
    draw.line((36, 117, w - 36, 117), fill=faint_ink, width=1)
    draw.line((36, 264, w - 36, 264), fill=faint_ink, width=1)
    draw.line((36, 268, w - 36, 268), fill=ink, width=2)

    center_text(draw, w, h - 38, "RULE 221  ·  B. C. & W. TELEGRAPH DEPT.", f_micro, faint_ink)
    img.save(OUT_DIR / "card_operator_stock.png")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_timetable_stock()
    build_operator_stock()
    print("Generated stationery cards in", OUT_DIR)


if __name__ == "__main__":
    main()
