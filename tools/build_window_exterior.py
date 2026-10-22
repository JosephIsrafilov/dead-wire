#!/usr/bin/env python3
"""The view out of the north window: sky, ridge, and the mine's own silhouette.

Why this is generated rather than painted
-----------------------------------------
The old backdrop was one 128x128 tile with a moon, a pole and a ridge already
baked into it. That is why the view read as a postcard: the whole world was one
flat picture at one depth, 0.84 m behind the glass, and the pole and wires in
front of it were the only parallax in the scene.

This pass splits the view into the layers a real one has, each at its own
distance, so moving the head actually shifts them against each other:

  * sky        - a vertical gradient with no moon in it. The moon is a real
                 light and a real disc in the scene; baking a second one into
                 the sky is how the window grew a duplicate moon.
  * ridge      - the far slope, a band of hills along the horizon.
  * mineworks  - the closed mine: headframe, shed, spoil bank and fence line.

THE HORIZON CONTRACT
--------------------
Every layer below the sky draws its ground line at exactly HORIZON_V of the
tile. The scene places each quad so that this line lands on the horizon the
camera actually sees, which is what keeps the layers agreeing about where the
ground is: a quad whose ground sits at an arbitrary fraction of its own height
renders its content below the window and looks like nothing is out there.

Everything is deterministic and nearest-sampled like the rest of the PSX set.

    .venv-tools/Scripts/python.exe tools/build_window_exterior.py
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image

OUT_DIR = os.path.join("materials", "style_tests", "textures", "psx")
SEED = 1885

# Fraction of the tile's height where the ground line sits. tools/exterior_view_capture.gd
# and the scene transforms in m1_office.tscn are placed against this number.
HORIZON_V = 0.68


def _lerp(a: tuple[float, float, float], b: tuple[float, float, float], t: float):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _grain(value: float, rng: random.Random, amount: float) -> float:
    """Quantised noise, the same 8-step look the other PSX tiles have."""
    noisy = value + rng.uniform(-amount, amount)
    return round(max(0.0, min(1.0, noisy)) * 8.0) / 8.0


def build_sky(width: int = 128, height: int = 128) -> Image.Image:
    """Night sky: cold at the top, faintly warmer at the horizon, no moon."""
    rng = random.Random(SEED)
    # Top, mid, horizon. The horizon is lighter because the town's own light
    # and the snow on the far ridge lift it; the top is almost black.
    # Values chosen so the yard's fence and the mine read as SILHOUETTES
    # against it. The first pass had the sky at the same value as the buildings,
    # and the whole view collapsed into one dark rectangle: at night the near
    # things are dark because the sky behind them is not.
    top = (0.080, 0.100, 0.155)
    mid = (0.150, 0.180, 0.245)
    horizon = (0.255, 0.270, 0.300)
    img = Image.new("RGB", (width, height))
    pixels = img.load()
    for y in range(height):
        t = y / float(height - 1)
        if t < HORIZON_V:
            base = _lerp(top, mid, t / HORIZON_V)
        else:
            base = _lerp(mid, horizon, (t - HORIZON_V) / (1.0 - HORIZON_V))
        for x in range(width):
            # A slow horizontal variation so the sky is not a perfect gradient;
            # the eye reads a flat gradient as a painted backdrop.
            drift = 0.014 * math.sin((x / width) * math.pi * 2.0 + 0.7)
            v = _grain(base[0] + drift, rng, 0.008)
            g = _grain(base[1] + drift, rng, 0.008)
            b = _grain(base[2] + drift * 1.4, rng, 0.010)
            pixels[x, y] = (int(v * 255), int(g * 255), int(b * 255))
    return img


def build_ridge(width: int = 128, height: int = 128) -> Image.Image:
    """The far slope: two overlapping hill lines, darker as they come closer.

    Everything below the nearer crest is filled, down past the horizon, so the
    layer is a solid band rather than a floating cut-out.
    """
    rng = random.Random(SEED + 1)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()

    horizon_px = HORIZON_V * (height - 1)

    def crest(amp: float, phase: float, freq: float, x: int) -> float:
        u = x / float(width)
        return (horizon_px
                - amp * (1.0 + math.sin(u * math.pi * 2.0 * freq + phase))
                - amp * 0.5 * (1.0 + math.sin(u * math.pi * 2.0 * freq * 2.3 + phase * 1.7)))

    far = (0.150, 0.170, 0.210)
    near = (0.088, 0.100, 0.128)
    for x in range(width):
        far_top = crest(9.0, 0.9, 1.6, x)
        near_top = crest(5.5, 2.4, 2.1, x)
        for y in range(height):
            if y >= near_top:
                colour = near
            elif y >= far_top:
                colour = far
            else:
                continue
            pixels[x, y] = (
                int(_grain(colour[0], rng, 0.006) * 255),
                int(_grain(colour[1], rng, 0.006) * 255),
                int(_grain(colour[2], rng, 0.008) * 255),
                255,
            )
    return img


def build_mineworks(width: int = 128, height: int = 128) -> Image.Image:
    """The closed mine across the yard, as a silhouette against the sky.

    A silhouette is not a black rectangle. What makes one read at night is the
    few surfaces that still catch the sky — a ridge line, the sky-facing face of
    a roof, the windward edge of a timber — set against everything that does
    not. The first version of this layer was one flat block, and at 9 m it read
    exactly like one.

    Forms, in the order they carry the read: the shed's pitched roof, its
    boarded wall, the headframe over the shaft with its sheave wheel, the spoil
    bank, and the fence running out to the left.
    """
    rng = random.Random(SEED + 2)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()

    # Four values only. Night silhouettes are read by value steps, not by detail.
    skyward = (0.105, 0.115, 0.140)   # faces turned up at the sky
    wall = (0.070, 0.078, 0.094)      # walls in ambient only
    deep = (0.044, 0.049, 0.060)      # openings, shadowed sides
    ground = (0.038, 0.042, 0.050)    # the yard's own ground

    horizon_px = int(round(HORIZON_V * (height - 1)))

    def put(x: int, y: int, colour, jitter: float = 0.004) -> None:
        if 0 <= x < width and 0 <= y < height:
            pixels[x, y] = (
                int(_grain(colour[0], rng, jitter) * 255),
                int(_grain(colour[1], rng, jitter) * 255),
                int(_grain(colour[2], rng, jitter) * 255),
                255,
            )

    # Ground and spoil bank from the horizon down, so the layer never floats.
    for x in range(width):
        top = horizon_px - int(2 * math.sin(x * 0.09) + 1.5 * math.sin(x * 0.23))
        for y in range(top, height):
            put(x, y, ground)

    # --- the shed ---------------------------------------------------------
    # A pitched roof, not a box: the two roof planes catch different amounts of
    # sky, which is the only thing that explains a building's shape at night.
    shed_left, shed_right = 2, 56
    ridge_y = horizon_px - 17
    eave_left = horizon_px - 10
    eave_right = horizon_px - 12
    ridge_x = (shed_left + shed_right) // 2
    for x in range(shed_left, shed_right):
        if x <= ridge_x:
            t = (x - shed_left) / float(max(ridge_x - shed_left, 1))
            roof_y = int(round(eave_left + (ridge_y - eave_left) * t))
            # The near roof plane faces the sky.
            shade = skyward
        else:
            t = (x - ridge_x) / float(max(shed_right - ridge_x, 1))
            roof_y = int(round(ridge_y + (eave_right - ridge_y) * t))
            # The far plane is turned away from us: darker.
            shade = wall
        for y in range(roof_y, horizon_px + 1):
            put(x, y, shade if y < roof_y + 2 else wall)
        put(x, roof_y, skyward)

    # Boarded wall below the eaves, with the plank lines that stop it reading
    # as one flat face.
    for x in range(shed_left, shed_right):
        for y in range(horizon_px - 8, horizon_px + 1):
            tone = wall if (x // 4) % 2 == 0 else deep
            put(x, y, tone, 0.003)

    # A broken section of roof: the mine has not been maintained.
    for x in range(30, 38):
        for y in range(ridge_y - 2, ridge_y + 4):
            pixels[x, y] = (0, 0, 0, 0)

    # Boarded window openings. Nothing inside is lit.
    for wx in (10, 22, 44):
        for x in range(wx, wx + 6):
            for y in range(horizon_px - 6, horizon_px):
                put(x, y, deep, 0.002)
        for x in range(wx, wx + 6, 2):
            for y in range(horizon_px - 6, horizon_px):
                put(x, y, wall, 0.002)

    # A chimney stack, and the only thing on the site with a warm edge: the
    # mine is shut, so this is not a working fire — it is the office lamp of a
    # caretaker, and it stays a single point of warmth.
    for x in range(14, 19):
        for y in range(ridge_y - 9, ridge_y):
            put(x, y, wall, 0.003)
    put(16, ridge_y - 9, skyward)

    # --- the headframe ----------------------------------------------------
    # Four legs seen as two, meeting over the shaft. Each leg is a square
    # timber two texels wide: the outer edge catches the sky continuously and
    # the inner face does not. Marking the highlight every few steps instead —
    # the first attempt — drew a ladder, because a broken edge reads as rungs.
    apex_x, apex_y = 74, horizon_px - 32
    foot_y = horizon_px
    for foot_x in (64, 85):
        outer_left = foot_x < apex_x
        steps = 60
        for i in range(steps + 1):
            t = i / float(steps)
            x = int(round(foot_x + (apex_x - foot_x) * t))
            y = int(round(foot_y + (apex_y - foot_y) * t))
            put(x, y, wall, 0.003)
            put(x + 1, y, deep, 0.003)
            # The sky-facing edge, always on the outside of the frame.
            if outer_left:
                put(x - 1, y, skyward, 0.002)
            else:
                put(x + 2, y, skyward, 0.002)
    # Cross-bracing: what makes a headframe read as a headframe.
    for level in (0.28, 0.52, 0.74):
        y = int(round(foot_y + (apex_y - foot_y) * level))
        half = int(round(abs(85 - 64) * 0.5 * (1.0 - level)))
        for x in range(apex_x - half, apex_x + half):
            put(x, y, wall, 0.003)
    # The sheave wheel at the top: small, and only its rim, because a filled
    # disc at this size reads as a balloon.
    for angle_step in range(30):
        angle = math.tau * angle_step / 30.0
        x = int(round(apex_x + math.cos(angle) * 4))
        y = int(round(apex_y - 2 + math.sin(angle) * 4))
        put(x, y, wall, 0.002)

    # --- the fence --------------------------------------------------------
    # Running left from the shed: the boundary of the station's ground.
    for x in range(0, shed_left):
        y = horizon_px - 3 - int(1.5 * math.sin(x * 0.12))
        put(x, y, wall, 0.003)
        if x % 8 == 0:
            for post in range(0, 4):
                put(x, y + post, wall, 0.003)

    return img


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    targets = {
        "psx_window_sky_128.png": build_sky(),
        "psx_window_ridge_128.png": build_ridge(),
        "psx_window_mineworks_128.png": build_mineworks(),
    }
    for name, image in targets.items():
        path = os.path.join(OUT_DIR, name)
        image.save(path)
        print(f"wrote {path} ({image.width}x{image.height}, {image.mode}, horizon v={HORIZON_V})")


if __name__ == "__main__":
    main()