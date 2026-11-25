"""Generate a 1890s dark railroad boot splash image (assets/branding/boot_splash.png)."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_PATH = ROOT / "assets" / "branding" / "boot_splash.png"
ICON_MASTER = ROOT / "assets" / "branding" / "form19_icon_master.png"
FONT_BOLD = ROOT / "assets" / "fonts" / "oldstandard" / "OldStandardTT-Bold.ttf"
FONT_REG = ROOT / "assets" / "fonts" / "oldstandard" / "OldStandardTT-Regular.ttf"


def _draw_centered(
    draw: ImageDraw.ImageDraw, cx: float, y: float, text: str, font: ImageFont.FreeTypeFont, color: tuple[int, int, int, int]
) -> None:
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw * 0.5, y), text, font=font, fill=color)


def main() -> None:
    w, h = 1280, 720
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - w * 0.5) / (w * 0.5)
    ny = (yy - h * 0.45) / (h * 0.5)
    dist = np.sqrt(nx * nx * 0.72 + ny * ny)
    glow = np.exp(-dist * dist * 2.1)

    # Warm soot-black to dark walnut glow
    r = 9.0 + glow * 26.0
    g = 7.0 + glow * 19.0
    b = 6.0 + glow * 12.0

    # Subtle film grain so dark vignette never bands
    rng = np.random.default_rng(1890)
    grain = (rng.random((h, w), dtype=np.float32) - 0.5) * 3.0
    arr = np.stack(
        [np.clip(r + grain, 0, 255), np.clip(g + grain, 0, 255), np.clip(b + grain, 0, 255)],
        axis=-1,
    ).astype(np.uint8)
    canvas = Image.fromarray(arr, mode="RGB").convert("RGBA")
    draw = ImageDraw.Draw(canvas, "RGBA")

    brass = (186, 148, 88, 175)
    brass_dim = (132, 104, 62, 120)
    cream = (238, 224, 194, 245)
    muted = (176, 158, 126, 210)

    # Outer double frame + corner rosettes
    draw.rectangle((28, 28, w - 29, h - 29), outline=brass_dim, width=2)
    draw.rectangle((38, 38, w - 39, h - 39), outline=brass, width=1)
    for rx, ry in [(38, 38), (w - 46, 38), (38, h - 46), (w - 46, h - 46)]:
        draw.rectangle((rx, ry, rx + 8, ry + 8), fill=brass)

    cx = w * 0.5
    if ICON_MASTER.is_file():
        seal = Image.open(ICON_MASTER).convert("RGBA").resize((124, 124), Image.Resampling.LANCZOS)
        # Subtle warm integration into dark splash
        canvas.alpha_composite(seal, (int(cx - 62), 188))

    f_title = ImageFont.truetype(str(FONT_BOLD), 56)
    f_sub = ImageFont.truetype(str(FONT_REG), 19)
    f_micro = ImageFont.truetype(str(FONT_BOLD), 14)

    _draw_centered(draw, cx, 338, "F O R M   1 9", f_title, cream)
    draw.line((cx - 190, 416, cx + 190, 416), fill=brass, width=2)
    # Morse ornament: · — ·
    draw.ellipse((cx - 28, 427, cx - 22, 433), fill=brass)
    draw.rectangle((cx - 12, 428, cx + 12, 432), fill=brass)
    draw.ellipse((cx + 22, 427, cx + 28, 433), fill=brass)

    _draw_centered(draw, cx, 452, "BLACK CREEK & WESTERN RY.  ·  TELEGRAPH DEPT.", f_sub, muted)
    _draw_centered(draw, cx, h - 82, "APRIL 1890  ·  8,850 FT.", f_micro, brass_dim)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT_PATH)
    print("Generated boot splash:", OUT_PATH)


if __name__ == "__main__":
    main()
