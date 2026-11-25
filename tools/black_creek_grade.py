"""Port of the Black Creek hillside grade for the landmark generator.

`scripts/town/black_creek_hillside.gd` owns the hill. Anything that has to sit
*on* the hill — the chapel's founded terrace, the wall that holds its lip, the
stair down to the meadow, the fence, the graves — needs the same heights, and the
Python generator cannot call GDScript. This module mirrors `_grade()` and
`mesh_grade()` exactly, and `tests/town/black_creek_chapel_test.gd` checks the
two implementations against the built geometry.

Change the numbers in BOTH files or the churchyard floats again.

Why a rectangular bench: the grade used to flatten the chapel radially
(`max(|x|/5.0, |z|/6.8)`, smoothed over 0.8..1.65). That left a flat pad barely
4 m x 6 m — the nave's own footprint — and let the scarp feather *through* the
building, so there was no level ground for graves, a fence or a stair head. A
walled bench is also what an 1880s Colorado hillside church actually sits on: you
cut a bench out of the slope, you hold its downhill lip in rubble masonry, and
the burying ground is the bench.
"""

from __future__ import annotations

import math

LOT_X = (-34.0, -12.0, 12.0, 34.0)
LOT_Z = (58.0, 61.0, 58.0, 60.0)
LOT_Y = (3.1, 4.2, 3.8, 4.6)

# Chapel origin in world space; every chapel-local value below is relative to it.
CX, CY, CZ = -46.0, 0.62, 39.0

# Churchyard bench. The nave is 7.33 x 9.82, so the bench leaves ~4.3 m of level
# ground on each flank (graves), 1.3 m at the front (entry steps), 1.5 m behind.
BENCH_X = 8.00        # half width   -> local x in [-8.0, 8.0]
BENCH_FRONT = 8.00    # north face   -> local z = -8.00
BENCH_BACK = 6.00     # south face   -> local z = +6.00
BENCH_BLEND = 1.55    # feather from bench to natural grade, in bench-radius units
BENCH_DROP = 0.065    # the whole grade sits this far under the floor datum

GRID = 2.0


def smoothstep(a: float, b: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def bench_radius(lx: float, lz: float) -> float:
    """1.0 exactly on the bench edge, > 1.0 outside it. Only an upper bound."""
    return max(abs(lx) / BENCH_X, -lz / BENCH_FRONT if lz < 0.0 else lz / BENCH_BACK)


def _base_grade(x: float, z: float) -> float:
    rise = max(0.0, z - 46.8)
    height = min(37.0, rise * (0.35 + math.sin(x * 0.080) * 0.075))
    height += smoothstep(0, 12, rise) * (math.sin(x * 0.21 + z * 0.17) * 1.4 + math.sin(x * 0.37) * 0.7)
    height += 5.2 * math.exp(-((x + 54) / 19.0) ** 2) * smoothstep(1, 14, rise)
    for i in range(len(LOT_X)):
        radius = max(abs(x - LOT_X[i]) / 7.0, abs(z - LOT_Z[i]) / 6.0)
        height = lerp(LOT_Y[i], height, smoothstep(0.76, 1.45, radius))
    return height


def grade(x: float, z: float) -> float:
    """World-space terrain height. Mirrored by black_creek_hillside.gd::_grade."""
    creek_fade = lerp(0.17, 1.0, smoothstep(2.0, 19.0, abs(x - 47.0)))
    return _base_grade(x, z) * creek_fade - BENCH_DROP


def mesh_grade(x: float, z: float) -> float:
    """Height of the rendered grid at (x, z): the terrain is flat-shaded, so the
    surface a prop must touch is the triangle, not the unsampled function."""
    gx = math.floor(x / GRID) * GRID
    gz = math.floor(z / GRID) * GRID
    u = (x - gx) / GRID
    v = (z - gz) / GRID
    b = grade(gx + GRID, gz)
    c = grade(gx, gz + GRID)
    if u + v <= 1.0:
        return grade(gx, gz) * (1.0 - u - v) + b * u + c * v
    return grade(gx + GRID, gz + GRID) * (u + v - 1.0) + b * (1.0 - v) + c * (1.0 - u)


def bench_top() -> float:
    """World y of the level churchyard bench. Every authored piece stands on it."""
    return CY - BENCH_DROP


def ground_local(lx: float, lz: float) -> float:
    """Rendered ground at a chapel-local x/z, expressed in chapel-local y."""
    return mesh_grade(CX + lx, CZ + lz) - CY


def local_to_world(lx: float, ly: float, lz: float) -> tuple:
    return CX + lx, CY + ly, CZ + lz


def scarp_profile(lx: float = 0.0, lz: float = -7.90, run: float = 9.0, step: float = 0.25) -> list:
    """Ground heights going north from the bench lip, to found the stair and wall."""
    out = []
    z = lz
    while z > lz - run:
        out.append((z, ground_local(lx, z)))
        z -= step
    return out


if __name__ == "__main__":
    print("bench top: world %.3f, chapel-local %.3f" % (bench_top(), bench_top() - CY))
    print("\nbench samples (all must read ~%.3f):" % (bench_top() - CY))
    for lx, lz in ((-7.4, -7.7), (7.4, -7.7), (-7.4, 6.0), (7.4, 6.0),
                   (0.0, 0.0), (0.0, -5.8), (0.0, 5.9)):
        print("  local(%5.1f,%6.1f) -> %7.3f" % (lx, lz, ground_local(lx, lz)))
    print("\nnorth scarp at local x = 0 (lip is z = -7.90):")
    for lz, h in scarp_profile():
        print("  local z %6.2f  world z %6.2f  ground %8.3f" % (lz, CZ + lz, h))
