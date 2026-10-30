"""Worn floorboards for the M1 office.

    .venv-tools/Scripts/python.exe tools/build_worn_floor.py

Writes materials/style_tests/textures/psx/psx_floor_boards_256.png: a 256px
tile of four floorboards across and two courses down, staggered like real
boarding, with the wear an 1894 depot floor actually has — uneven board tones,
dark seams instead of clean ones, iron nails with rust runs, a knot, a split
board, scuffs along the traffic line and grime that collects at the edges.

Deterministic: same seed, same image. This is a texture pass only; the floor's
collision and the `Floor` node stay exactly as they are.
"""
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "materials/style_tests/textures/psx/psx_floor_boards_256.png"

SIZE = 256
BOARDS = 4                 # boards across the tile
TILE_M = 0.56              # metres one tile covers at the material's uv scale
BOARD_M = TILE_M / BOARDS  # 0.14 m — a real floorboard width

# One tone per board; the variation is what stops a floor reading as a print of
# four boards repeated fifty times.
TONES = [(96, 70, 46), (82, 58, 38), (110, 82, 54), (74, 52, 34)]

rng = random.Random(1894)
img = Image.new("RGB", (SIZE, SIZE), (24, 18, 12))
px = img.load()

board_px = SIZE // BOARDS  # 64 px
# Course boundaries are staggered per board, so joints never line up in a cross.
joint_rows = []
for b in range(BOARDS):
    count = 2
    rows = sorted(rng.sample(range(48, SIZE - 48), count - 1))
    joint_rows.append([0] + rows + [SIZE])

for b in range(BOARDS):
    base = TONES[b % len(TONES)]
    # A per-board tint shift, so neighbours differ even where the tone repeats.
    shift = rng.randint(-7, 7)
    for x in range(b * board_px, (b + 1) * board_px):
        along = (x - b * board_px) / board_px
        # Grain: long slow waves down the board plus a fine cross ripple.
        for y in range(SIZE):
            grain = (
                5.5 * math.sin(y * 0.13 + b * 2.1)
                + 3.0 * math.sin(y * 0.41 + math.sin(x * 0.35) * 1.4)
                + 1.6 * math.sin(y * 1.7 + x * 0.2)
            )
            # Wear: the middle of a board is walked on, its edges are not.
            walk = -6.0 * math.sin(math.pi * along)
            n = rng.uniform(-3.0, 3.0)
            r, g, bl = (
                max(0, min(255, base[0] + shift + grain + walk + n)),
                max(0, min(255, base[1] + shift + grain * 0.9 + walk + n)),
                max(0, min(255, base[2] + shift + grain * 0.75 + walk + n)),
            )
            px[x, y] = (int(r), int(g), int(bl))

    # Seams: a dark gap between boards, not a bright line. The old texture drew
    # its seams light and the whole floor read as dashed white lines.
    for edge in (b * board_px, (b + 1) * board_px - 1):
        for y in range(SIZE):
            r, g, bl = px[edge, y]
            px[edge, y] = (int(r * 0.30), int(g * 0.30), int(bl * 0.30))

    # Butt joints across the board: a dark end-grain line, two pixels wide.
    for row in joint_rows[b][1:-1]:
        for x in range(b * board_px, (b + 1) * board_px):
            for dy in (0, 1):
                r, g, bl = px[x, (row + dy) % SIZE]
                px[x, (row + dy) % SIZE] = (int(r * 0.45), int(g * 0.45), int(bl * 0.45))

# Nails: two per board end, set in from the seam, each with a rust run under it.
def nail(x, y, radius=1):
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            if dx * dx + dy * dy <= radius * radius + 1:
                px[(x + dx) % SIZE, (y + dy) % SIZE] = (18, 16, 15)
    for run in range(1, 7):
        yy = (y + run) % SIZE
        r, g, bl = px[x, yy]
        px[x, yy] = (int(r * 0.72 + 18), int(g * 0.62 + 6), int(bl * 0.5))

for b in range(BOARDS):
    inset = 7
    for row in joint_rows[b]:
        for x in (b * board_px + inset, (b + 1) * board_px - inset):
            nail(x, (row + 5) % SIZE)
            nail(x, (row - 5) % SIZE)

# Scuffs: short bright-dark drags where boots and crates have caught the boards.
for _ in range(26):
    x = rng.randrange(SIZE)
    y = rng.randrange(SIZE)
    length = rng.randint(6, 22)
    dark = rng.random() < 0.65
    for step in range(length):
        xx, yy = (x + step) % SIZE, (y + step // 3) % SIZE
        r, g, bl = px[xx, yy]
        f = 0.86 if dark else 1.12
        px[xx, yy] = (int(min(255, r * f)), int(min(255, g * f)), int(min(255, bl * f)))

# A knot in one board, and a split running out of it.
kx, ky = 3 * board_px + 34, 150
for dx in range(-5, 6):
    for dy in range(-4, 5):
        if dx * dx / 25.0 + dy * dy / 16.0 <= 1.0:
            px[(kx + dx) % SIZE, (ky + dy) % SIZE] = (38, 26, 17)
for step in range(40):
    xx, yy = (kx + step // 2) % SIZE, (ky + 6 + step) % SIZE
    r, g, bl = px[xx, yy]
    px[xx, yy] = (int(r * 0.55), int(g * 0.55), int(bl * 0.55))

# Grime: soot settles into the seams and corners, never in a straight band.
for _ in range(1400):
    x = rng.randrange(SIZE)
    y = rng.randrange(SIZE)
    r, g, bl = px[x, y]
    f = 0.80 + rng.random() * 0.15
    px[x, y] = (int(r * f), int(g * f), int(bl * f))

img.save(OUT)
print("WROTE", OUT, "tile covers %.2f m, board %.3f m" % (TILE_M, BOARD_M))
