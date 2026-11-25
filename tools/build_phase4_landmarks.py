"""Build tangible phase-4 Black Creek landmarks without Blender.

This generator writes only new phase-4 files:
- assets/models/town/{water_tower,kowalski_blacksmith,stone_calaboose,
  mj_spur_gate,creek_bridge_trough,chapel_steeple,roadside_props}.glb
- assets/textures/town_v2/print/{wanted,quarantine,blacksmith,shoeing}.png
- assets/models/town/phase4_asset_catalog.json

Coordinate convention matches the Godot town builder: Y is up, X is east,
Z is south. Each landmark GLB has its origin at its art-bible grade position;
roadside_props is a world-space prop packet with root origin at (0,0,0).
The GLBs contain visual geometry only. Collision boxes and interaction anchors
are emitted in the catalog for explicit Godot-side integration.
"""
from __future__ import annotations

import io
import json
import math
import struct
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

import black_creek_grade as G

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "assets" / "models" / "town"
PRINT_DIR = ROOT / "assets" / "textures" / "town_v2" / "print"
FONT_PATH = ROOT / "assets" / "fonts" / "oldstandard" / "OldStandardTT-Regular.ttf"

Vec3 = Tuple[float, float, float]
Color = Tuple[float, float, float, float]

MATERIALS: Dict[str, Tuple[str, Color, float, float]] = {
    "wood": ("Weathered pine", (0.30, 0.22, 0.15, 1), 0.90, 0.0),
    "wood_light": ("Sun bleached pine", (0.48, 0.36, 0.23, 1), 0.88, 0.0),
    "wood_dark": ("Tarred timber", (0.14, 0.10, 0.075, 1), 0.95, 0.0),
    "wood_red": ("Oxide red timber", (0.34, 0.13, 0.095, 1), 0.91, 0.0),
    "roof": ("Weathered shingles", (0.16, 0.17, 0.16, 1), 0.96, 0.0),
    "stone": ("Frontier granite", (0.39, 0.38, 0.34, 1), 0.96, 0.0),
    "stone_dark": ("Granite shadow", (0.25, 0.25, 0.23, 1), 0.98, 0.0),
    "mortar": ("Old mortar", (0.48, 0.45, 0.39, 1), 1.0, 0.0),
    "iron": ("Cast iron", (0.09, 0.095, 0.095, 1), 0.72, 0.72),
    "steel": ("New chain steel", (0.43, 0.46, 0.44, 1), 0.34, 0.82),
    "rust": ("Rusted rail", (0.33, 0.16, 0.095, 1), 0.82, 0.30),
    "ochre": ("Yellow boy water", (0.60, 0.29, 0.075, 1), 0.42, 0.0),
    "water": ("Black Creek water", (0.18, 0.31, 0.33, 1), 0.18, 0.05),
    "glass": ("Bottle glass", (0.18, 0.30, 0.27, 0.82), 0.20, 0.05),
    "paper": ("Aged paper", (0.66, 0.57, 0.40, 1), 0.90, 0.0),
    "ink": ("Letterpress ink", (0.09, 0.065, 0.045, 1), 0.94, 0.0),
    "white": ("Chapel limewash", (0.67, 0.64, 0.55, 1), 0.93, 0.0),
    "dark_glass": ("Window dark", (0.08, 0.12, 0.13, 1), 0.24, 0.05),
    "paint_blue": ("Clinic blue", (0.20, 0.28, 0.31, 1), 0.86, 0.0),
    "brick": ("Kiln brick", (0.50, 0.38, 0.28, 1), 0.92, 0.0),
    # Cast bell metal, dark with a century of verdigris; the tone is a warm
    # bronze instead of brass so it reads as 1885 rather than a ship's fitting.
    "bell_bronze": ("Cast bell bronze", (0.247, 0.180, 0.098, 1), 0.44, 0.55),
}


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def rgba_to_srgb(c: Color) -> Color:
    return c


class MeshPart:
    def __init__(self, name: str, material: str):
        self.name = name
        self.material = material
        self.vertices: List[Vec3] = []
        self.normals: List[Vec3] = []
        self.uvs: List[Tuple[float, float]] = []
        self.indices: List[int] = []

    def add_face(self, points: Sequence[Vec3], normal: Vec3, uv: Sequence[Tuple[float, float]] = ()) -> None:
        base = len(self.vertices)
        self.vertices.extend(points)
        u, v = (tuple(b - a for a, b in zip(points[0], p)) for p in points[1:3])
        cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
        length = math.sqrt(sum(q*q for q in cross))
        reverse = sum(a*b for a, b in zip(normal, cross)) < 0
        geometric = tuple(q / length * (-1 if reverse else 1) for q in cross) if length else normal
        self.normals.extend([geometric] * len(points))
        dominant = max(range(3), key=lambda i: abs(geometric[i]))
        axes = [(2, 1), (0, 2), (0, 1)][dominant]
        self.uvs.extend(uv or [(p[axes[0]] * .54, -p[axes[1]] * .54) for p in points])
        for i in range(1, len(points) - 1):
            self.indices.extend([base, base + i + 1, base + i] if reverse else [base, base + i, base + i + 1])


class Asset:
    def __init__(self, name: str):
        self.name = name
        self.parts: List[MeshPart] = []
        self.nodes: List[dict] = []
        self.images: Dict[str, bytes] = {}

    def part(self, name: str, material: str) -> MeshPart:
        p = MeshPart(name, material)
        self.parts.append(p)
        self.nodes.append({"name": name, "part": p})
        return p

    def empty(self, name: str, extras: dict) -> None:
        self.nodes.append({"name": name, "extras": extras})


def rotate_y(p: Vec3, angle: float) -> Vec3:
    x, y, z = p
    c, s = math.cos(angle), math.sin(angle)
    return (x * c - z * s, y, x * s + z * c)


def add_box(asset: Asset, name: str, center: Vec3, size: Vec3, material: str, rot_y: float = 0.0) -> None:
    p = asset.part(name, material)
    cx, cy, cz = center
    sx, sy, sz = (v / 2.0 for v in size)
    corners = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
               (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    corners = [rotate_y((cx + x, cy + y, cz + z), rot_y) for x, y, z in corners]
    faces = [
        ((0, 1, 2, 3), (0, 0, -1)), ((4, 7, 6, 5), (0, 0, 1)),
        ((0, 4, 5, 1), (0, -1, 0)), ((3, 2, 6, 7), (0, 1, 0)),
        ((1, 5, 6, 2), (1, 0, 0)), ((0, 3, 7, 4), (-1, 0, 0)),
    ]
    for ids, normal in faces:
        p.add_face([corners[i] for i in ids], normal)


def add_yaw_box(asset: Asset, name: str, center: Vec3, size: Vec3, material: str, yaw: float = 0.0) -> None:
    """A box spun about its own centre.

    `add_box`'s `rot_y` argument rotates the *world* position around the origin,
    which is only harmless for pieces that already sit on the axis. Anything
    off-centre — a crate at x 12.7, a brush at x 24.9 — must yaw about itself or it
    lands metres away from where it was authored.
    """
    p = asset.part(name, material)
    cx, cy, cz = center
    sx, sy, sz = (v / 2.0 for v in size)
    corners = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
               (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    c, s = math.cos(yaw), math.sin(yaw)
    corners = [(cx + x * c - z * s, cy + y, cz + x * s + z * c) for x, y, z in corners]
    faces = [
        ((0, 1, 2, 3), (-s, 0, -c)), ((4, 7, 6, 5), (s, 0, c)),
        ((0, 4, 5, 1), (0, -1, 0)), ((3, 2, 6, 7), (0, 1, 0)),
        ((1, 5, 6, 2), (c, 0, s)), ((0, 3, 7, 4), (-c, 0, -s)),
    ]
    for ids, normal in faces:
        p.add_face([corners[i] for i in ids], normal)


def add_beam(asset: Asset, name: str, a: Vec3, b: Vec3, width: float, material: str, depth: float | None = None) -> None:
    p = asset.part(name, material)
    ax, ay, az = a
    bx, by, bz = b
    d = (bx - ax, by - ay, bz - az)
    length = math.sqrt(sum(q * q for q in d))
    if length < 1e-5:
        return
    d = tuple(q / length for q in d)
    reference = (0.0, 1.0, 0.0) if abs(d[1]) < 0.92 else (1.0, 0.0, 0.0)
    u = (d[1] * reference[2] - d[2] * reference[1], d[2] * reference[0] - d[0] * reference[2], d[0] * reference[1] - d[1] * reference[0])
    un = math.sqrt(sum(q * q for q in u))
    u = tuple(q / un for q in u)
    v = (d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0])
    hw, hd = width / 2.0, (depth or width) / 2.0
    c = ((ax + bx) / 2.0, (ay + by) / 2.0, (az + bz) / 2.0)

    def point(su: float, sv: float, sd: float) -> Vec3:
        return (c[0] + u[0] * su + v[0] * sv + d[0] * sd,
                c[1] + u[1] * su + v[1] * sv + d[1] * sd,
                c[2] + u[2] * su + v[2] * sv + d[2] * sd)

    faces = [
        ([point(-hw, -hd, -length / 2), point(hw, -hd, -length / 2), point(hw, hd, -length / 2), point(-hw, hd, -length / 2)], tuple(-q for q in d)),
        ([point(-hw, -hd, length / 2), point(-hw, hd, length / 2), point(hw, hd, length / 2), point(hw, -hd, length / 2)], d),
        ([point(-hw, -hd, -length / 2), point(-hw, -hd, length / 2), point(hw, -hd, length / 2), point(hw, -hd, -length / 2)], tuple(-q for q in v)),
        ([point(-hw, hd, -length / 2), point(hw, hd, -length / 2), point(hw, hd, length / 2), point(-hw, hd, length / 2)], v),
        ([point(hw, -hd, -length / 2), point(hw, -hd, length / 2), point(hw, hd, length / 2), point(hw, hd, -length / 2)], u),
        ([point(-hw, -hd, -length / 2), point(-hw, hd, -length / 2), point(-hw, hd, length / 2), point(-hw, -hd, length / 2)], tuple(-q for q in u)),
    ]
    for points, normal in faces:
        p.add_face(points, normal)


def add_cylinder(asset: Asset, name: str, center: Vec3, radius: float, height: float, material: str, sides: int = 12, top_radius: float | None = None, rot_y: float = 0.0) -> None:
    p = asset.part(name, material)
    top_radius = radius if top_radius is None else top_radius
    cx, cy, cz = center
    for i in range(sides):
        a0 = math.tau * i / sides + rot_y
        a1 = math.tau * (i + 1) / sides + rot_y
        x0, z0 = math.cos(a0) * radius, math.sin(a0) * radius
        x1, z1 = math.cos(a1) * radius, math.sin(a1) * radius
        xt0, zt0 = math.cos(a0) * top_radius, math.sin(a0) * top_radius
        xt1, zt1 = math.cos(a1) * top_radius, math.sin(a1) * top_radius
        p.add_face([(cx + x0, cy - height / 2, cz + z0), (cx + x1, cy - height / 2, cz + z1),
                    (cx + xt1, cy + height / 2, cz + zt1), (cx + xt0, cy + height / 2, cz + zt0)],
                   (math.cos((a0 + a1) / 2), 0, math.sin((a0 + a1) / 2)))
    bottom = [(cx + math.cos(math.tau * i / sides + rot_y) * radius, cy - height / 2,
               cz + math.sin(math.tau * i / sides + rot_y) * radius) for i in range(sides)]
    top = [(cx + math.cos(math.tau * i / sides + rot_y) * top_radius, cy + height / 2,
            cz + math.sin(math.tau * i / sides + rot_y) * top_radius) for i in range(sides)]
    p.add_face(list(reversed(bottom)), (0, -1, 0))
    p.add_face(top, (0, 1, 0))


def add_gable_prism(asset: Asset, name: str, center: Vec3, width: float, depth: float, wall_h: float, roof_h: float, material: str) -> None:
    p = asset.part(name, material)
    cx, cy, cz = center
    e = width / 2.0
    y0, y1 = cy + wall_h / 2.0, cy + wall_h / 2.0 + roof_h
    front = [(cx - e, cy - wall_h / 2.0, cz + depth / 2), (cx + e, cy - wall_h / 2.0, cz + depth / 2),
             (cx + e, y0, cz + depth / 2), (cx, y1, cz + depth / 2), (cx - e, y0, cz + depth / 2)]
    back = [(x, y, cz - depth / 2) for x, y, _ in front]
    p.add_face([front[0], front[1], front[2], front[3], front[4]], (0, 0, 1))
    p.add_face(list(reversed(back)), (0, 0, -1))
    p.add_face([front[0], back[0], back[1], front[1]], (0, -1, 0))
    p.add_face([front[1], back[1], back[2], front[2]], (1, 0, 0))
    p.add_face([front[2], back[2], back[3], front[3]], (0.55, 0.55, 0.62))
    p.add_face([front[3], back[3], back[4], front[4]], (-0.55, 0.55, 0.62))
    p.add_face([front[4], back[4], back[0], front[0]], (-1, 0, 0))


def add_poster(asset: Asset, name: str, center: Vec3, size: Tuple[float, float], material: str, face: str = "+z", rot_y: float = 0.0) -> None:
    """A single printed sheet pressed against a flat face.

    The face names the outward normal, so a bill on the calaboose's west wall uses
    `-x` and lies in the wall's own plane instead of standing out of it. Winding is
    fixed up downstream by `MeshPart.add_face`, which flips triangles that disagree
    with the declared normal.
    """
    w, h = size
    cx, cy, cz = center
    p = asset.part(name, material)
    if face == "+z":
        points = [(cx - w / 2, cy - h / 2, cz), (cx + w / 2, cy - h / 2, cz),
                  (cx + w / 2, cy + h / 2, cz), (cx - w / 2, cy + h / 2, cz)]
        normal = (0, 0, 1)
    elif face == "-z":
        points = [(cx + w / 2, cy - h / 2, cz), (cx - w / 2, cy - h / 2, cz),
                  (cx - w / 2, cy + h / 2, cz), (cx + w / 2, cy + h / 2, cz)]
        normal = (0, 0, -1)
    elif face == "-x":
        points = [(cx, cy - h / 2, cz + w / 2), (cx, cy - h / 2, cz - w / 2),
                  (cx, cy + h / 2, cz - w / 2), (cx, cy + h / 2, cz + w / 2)]
        normal = (-1, 0, 0)
    elif face == "+x":
        points = [(cx, cy - h / 2, cz - w / 2), (cx, cy - h / 2, cz + w / 2),
                  (cx, cy + h / 2, cz + w / 2), (cx, cy + h / 2, cz - w / 2)]
        normal = (1, 0, 0)
    else:
        raise ValueError("add_poster face must be one of +z -z +x -x, got %r" % face)
    p.add_face(points, normal, [(0, 1), (1, 1), (1, 0), (0, 0)])


def make_print(path: Path, title: str, lines: Sequence[str], accent: Tuple[int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    w, h = 256, 384
    im = Image.new("RGB", (w, h), (193, 167, 116))
    px = im.load()
    seed = sum(ord(ch) for ch in title + "".join(lines))
    for y in range(h):
        for x in range(w):
            n = (x * 17 + y * 31 + seed * 13) % 19 - 9
            edge = min(x, y, w - 1 - x, h - 1 - y)
            fade = max(0, 8 - edge) * 2
            px[x, y] = tuple(clamp(v + n - fade, 0, 255) for v in (193, 167, 116))
    draw = ImageDraw.Draw(im)
    try:
        title_font = ImageFont.truetype(str(FONT_PATH), 31)
        body_font = ImageFont.truetype(str(FONT_PATH), 15)
        small_font = ImageFont.truetype(str(FONT_PATH), 11)
    except OSError:
        title_font = body_font = small_font = ImageFont.load_default()
    draw.rectangle((12, 12, w - 13, h - 13), outline=(62, 42, 28), width=3)
    draw.rectangle((20, 20, w - 21, h - 21), outline=accent, width=1)
    draw.line((29, 72, w - 29, 72), fill=accent, width=2)
    bbox = draw.textbbox((0, 0), title, font=title_font)
    draw.text(((w - (bbox[2] - bbox[0])) / 2, 31), title, fill=(56, 38, 28), font=title_font)
    y = 105
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=body_font)
        draw.text(((w - (bbox[2] - bbox[0])) / 2, y), line, fill=(55, 42, 31), font=body_font)
        y += 27
    draw.line((39, y + 13, w - 39, y + 13), fill=(84, 59, 37), width=1)
    draw.text((35, h - 56), "BLACK CREEK COUNTY · APRIL 1890", fill=(63, 44, 30), font=small_font)
    im = im.filter(ImageFilter.GaussianBlur(radius=0.16))
    im.save(path)


def build_water_tower() -> Asset:
    a = Asset("water_tower")
    for x in (-2.1, 2.1):
        for z in (-1.8, 1.8):
            add_box(a, f"Leg_{x}_{z}", (x, 2.7, z), (0.38, 5.4, 0.38), "wood_dark")
    for z in (-1.8, 1.8):
        add_beam(a, "BraceFront" + str(z), (-2.1, 0.8, z), (2.1, 4.6, z), 0.18, "wood_light")
        add_beam(a, "BraceBack" + str(z), (2.1, 0.8, z), (-2.1, 4.6, z), 0.18, "wood_light")
    for x in (-2.1, 2.1):
        add_beam(a, "BraceSide" + str(x), (x, 0.8, -1.8), (x, 4.6, 1.8), 0.18, "wood_light")
        add_beam(a, "BraceSideR" + str(x), (x, 0.8, 1.8), (x, 4.6, -1.8), 0.18, "wood_light")
    add_box(a, "Platform", (0, 5.35, 0), (5.4, 0.30, 5.0), "wood")
    add_cylinder(a, "Tank", (0, 7.25, 0), 2.35, 3.6, "wood_light", 16)
    for y in (5.75, 7.25, 8.75):
        add_cylinder(a, "SteelBand" + str(y), (0, y, 0), 2.43, 0.11, "steel", 16)
    add_cylinder(a, "TankRoof", (0, 9.75, 0), 2.72, 1.35, "roof", 16, top_radius=0.08)
    add_cylinder(a, "RoofCap", (0, 10.50, 0), 0.16, 0.25, "steel", 10)
    add_beam(a, "RailSpout", (0, 5.48, -2.15), (0, 4.72, -4.35), 0.24, "steel")
    add_box(a, "SpoutCounterweight", (0, 4.55, -4.45), (0.42, 0.60, 0.42), "iron")
    a.empty("COL_WaterTower_Legs", {"shape": "boxes", "boxes": [[-2.1, 2.7, -1.8, 0.38, 5.4, 0.38], [2.1, 2.7, -1.8, 0.38, 5.4, 0.38], [-2.1, 2.7, 1.8, 0.38, 5.4, 0.38], [2.1, 2.7, 1.8, 0.38, 5.4, 0.38]]})
    a.empty("COL_WaterTower_Tank", {"shape": "cylinder", "center": [0, 7.25, 0], "radius": 2.35, "height": 3.6})
    return a


def add_wheel(a: Asset, name: str, center: Vec3, r: float, yaw: float = 0) -> None:
    # Open felloe and tyre in XY; the axle lies along local Z.
    start = len(a.parts)
    for suffix, outer, inner, half, material in (
            ('Felloe', r - .035, r - .145, .060, 'wood_light'), ('Tyre', r, r - .039, .068, 'rust')):
        part = a.part(name + suffix, material)
        for i in range(24):
            t, q = (math.tau * k / 24 for k in (i, i + 1))
            def point(angle, radius, z):
                return (radius * math.sin(angle), radius * math.cos(angle), z)
            radial = (math.sin((t+q)/2), math.cos((t+q)/2), 0)
            for z in (-half, half):
                part.add_face([point(t, outer, z), point(q, outer, z), point(q, inner, z),
                               point(t, inner, z)], (0, 0, math.copysign(1, z)))
            for radius, n in ((outer, radial), (inner, tuple(-v for v in radial))):
                part.add_face([point(t, radius, -half), point(q, radius, -half),
                               point(q, radius, half), point(t, radius, half)], n)
    for i in range(12):
        t = i * math.tau / 12
        add_beam(a, name + 'Spoke', (0, 0, 0), (math.sin(t)*(r-.10), math.cos(t)*(r-.10), 0),
                 .061, 'wood_light', .092)
    add_cylinder(a, name + 'Hub', (0, 0, 0), .14, .28, 'wood_dark')
    hub = a.parts[-1]
    hub.vertices = [(x, -z, y) for x, y, z in hub.vertices]
    hub.normals = [(x, -z, y) for x, y, z in hub.normals]
    transform_parts(a.parts[start:], center, yaw)


def transform_parts(parts: Sequence[MeshPart], offset: Vec3, yaw: float) -> None:
    for part in parts:
        part.vertices = [tuple(x + b for x, b in zip(rotate_y(p, yaw), offset)) for p in part.vertices]
        part.normals = [rotate_y(p, yaw) for p in part.normals]


def build_blacksmith() -> Asset:
    a = Asset("kowalski_blacksmith")
    add_box(a, "Foundation", (0, 0.22, 0), (10.8, 0.44, 8.8), "stone_dark")
    add_box(a, "MainBay", (0, 2.75, 0), (10.4, 5.05, 8.45), "wood")
    add_gable_prism(a, "GabledRoof", (0, 5.28, 0), 11.0, 9.0, 0.18, 2.25, "roof")
    add_box(a, "DoorL", (-2.0, 1.85, 4.28), (3.25, 3.30, 0.16), "wood_dark")
    add_box(a, "DoorR", (2.0, 1.85, 4.28), (3.25, 3.30, 0.16), "wood_dark")
    add_box(a, 'Shop threshold', (0, .16, 4.47), (7.52, .32, .45), 'stone_dark')
    for x in (-2.0, 2.0):
        for dx in (-1.63, 0, 1.63):
            add_box(a,'Door stile',(x+dx,1.85,4.39),(.105,3.34,.09),'wood_light')
        for dx in (-.82,.82):
            add_beam(a,'Door diagonal',(x+dx-.68,.47,4.405),(x+dx+.68,3.15,4.405),.15,'wood')
        for y in (.58,3.12):
            add_box(a,'Hinge strap',(x-1.37,y,4.48),(.48,.118,.064),'rust')
        add_box(a, 'Lock plate', (x+.15, 1.32, 4.50), (.17, .28, .06), 'iron')
        add_box(a, 'Shop pull', (x+.15, 1.32, 4.56), (.09, .21, .09), 'rust')
    add_box(a, "Canopy", (5.1, 3.0, 1.85), (3.4, 0.22, 5.2), "wood_light")
    for x in (4.0, 6.2):
        add_box(a, "CanopyPost" + str(x), (x, 1.55, 0.0), (0.22, 3.1, 0.22), "wood_dark")
    add_box(a, "ForgeBase", (-3.25, 0.75, -2.25), (2.5, 1.5, 1.75), "stone")
    add_box(a, "ForgeMouth", (-3.25, 1.20, -3.16), (0.78, 0.82, 0.08), "iron")
    add_box(a, "ForgeChimney", (-3.25, 5.0, -2.25), (1.15, 5.0, 1.15), "stone_dark")
    add_box(a, "ForgeCap", (-3.25, 7.62, -2.25), (1.45, 0.22, 1.45), "iron")
    add_box(a, "AnvilBase", (3.55, 0.58, 1.25), (0.58, 1.16, 0.58), "wood_dark")
    add_box(a, "Anvil", (3.55, 1.27, 1.25), (1.18, 0.28, 0.48), "iron")
    add_box(a, "AnvilHorn", (4.20, 1.30, 1.25), (0.72, 0.22, 0.22), "iron")
    add_wheel(a, 'RepairWheel', (5.67, .91, 3.22), .91, -.24)
    add_box(a, 'SignBackboard', (0, 4.32, 4.32), (5.69, 1.53, .20), 'wood_dark')
    add_poster(a, 'KowalskiLivery', (0, 4.32, 4.425), (5.52, 1.43), 'print_blacksmith', '+z')
    a.empty("COL_Blacksmith_Body", {"shape": "box", "center": [0, 2.75, 0], "size": [10.4, 5.05, 8.45]})
    a.empty("COL_Blacksmith_Forge", {"shape": "box", "center": [-3.25, 0.75, -2.25], "size": [2.5, 1.5, 1.75]})
    return a


def build_calaboose() -> Asset:
    a = Asset("stone_calaboose")
    add_box(a, "Foundation", (0, 0.20, 0), (5.5, 0.40, 6.5), "stone_dark")
    add_box(a, "BackWall", (0, 1.95, -3.0), (5.2, 3.5, 0.45), "stone")
    add_box(a, "WestWall", (-2.38, 1.95, 0), (0.45, 3.5, 5.6), "stone")
    add_box(a, "EastWall", (2.38, 1.95, 0), (0.45, 3.5, 5.6), "stone")
    # The front wall is built *around* the door and the two lights. The door bay
    # keeps the 1.72 m opening the old wall had (the oak door and its lintel fill
    # it), and each slit is a true 0.30 x 0.80 aperture cut through the 0.45 stone
    # at |x| 1.44 — 0.445 m clear of the oak jambs at |x| .715-.845, so nothing
    # clips the door reveal and the light reads through the wall from an angle.
    add_wall_with_openings(a, "FrontWest", -2.58, -0.86, 0.20, 3.70, 3.0, 0.45, "stone",
                           [(-1.44, 2.15, 0.30, 0.80)])
    add_wall_with_openings(a, "FrontEast", 0.86, 2.58, 0.20, 3.70, 3.0, 0.45, "stone",
                           [(1.44, 2.15, 0.30, 0.80)])
    add_box(a, "Lintel", (0, 3.54, 3.0), (1.75, 0.42, 0.48), "stone_dark")
    add_box(a, "Roof", (0, 3.83, 0), (5.55, 0.30, 6.55), "roof")
    add_box(a, "OakDoor", (0, 1.50, 3.25), (1.45, 2.35, 0.12), "wood_dark")
    # The cut faces of the wall pieces are the reveals. Set a dark lining 0.20 back
    # from the outer face so the aperture reads as depth through 0.45 m of stone
    # rather than a black sticker on the surface, and drop one iron bar in it.
    for x in (-1.44, 1.44):
        add_box(a, "SlitLining" + str(x), (x, 2.15, 3.02), (0.30, 0.80, 0.02), "dark_glass")
        add_box(a, "SlitBar" + str(x), (x, 2.15, 3.16), (0.045, 0.74, 0.045), "iron")
    for x in (-.78, .78):
        add_box(a, 'Jail door jamb', (x, 1.58, 3.31), (.13, 2.43, .17), 'wood')
    add_box(a, 'Jail door threshold', (0, .33, 3.46), (1.7, .15, .44), 'stone_dark')
    for y in (.64, 2.32):
        add_box(a, 'Jail strap hinge', (-.46, y, 3.34), (.49, .12, .055), 'rust')
    add_box(a, 'Jail lock plate', (.56, 1.48, 3.40), (.18, .24, .07), 'rust')
    add_box(a, "DoorBar", (0, 1.58, 3.36), (1.65, 0.14, 0.14), "iron")
    # The bill is pasted to the west wall, in the wall plane, on a thin board so it
    # casts and shades like paper on stone rather than a card standing in the yard.
    add_box(a, "WantedBackingBoard", (-2.612, 1.92, 0.10), (0.045, 1.50, 1.00), "wood_dark")
    add_poster(a, "WantedPoster", (-2.638, 1.92, 0.10), (0.92, 1.42), "print_wanted", "-x")
    a.empty("COL_Calaboose_Walls", {"shape": "boxes", "boxes": [[0, 1.95, -3, 5.2, 3.5, 0.45], [-2.38, 1.95, 0, 0.45, 3.5, 5.6], [2.38, 1.95, 0, 0.45, 3.5, 5.6], [-1.72, 1.95, 3, 1.72, 3.5, 0.45], [1.72, 1.95, 3, 1.72, 3.5, 0.45]]})
    return a


def build_mj_gate() -> Asset:
    a = Asset("mj_spur_gate")
    for x in (-2.25, 2.25):
        add_box(a, "GatePost" + str(x), (x, 1.25, 0), (0.36, 2.5, 0.36), "wood_dark")
        add_box(a, "PostCap" + str(x), (x, 2.58, 0), (0.50, 0.16, 0.50), "iron")
    for side in (-1,1):
        for i in range(7):
            add_box(a, 'Gate plank', (side*(.125 + i*.292),1.13,.02),(.282,2.10,.15),
                    'wood_light' if i % 4 == 2 else 'wood')
        for y in (.31,1.99):
            add_box(a, 'Strapped cross rail', (side*1.0,y,.124),(2.05,.16,.09),'wood_dark')
        for y in (.47,1.77):
            add_box(a, 'Rusted strap hinge', (side*1.94,y,.18),(.52,.135,.072),'rust')
    add_beam(a, "GateBraceL", (-2.05, 0.35, 0.15), (-0.32, 2.02, 0.15), 0.12, "iron")
    add_beam(a, "GateBraceR", (2.05, 0.35, 0.15), (0.32, 2.02, 0.15), 0.12, "iron")
    add_box(a, "RailL", (-0.78, 0.08, -8.0), (0.10, 0.16, 20.0), "rust")
    add_box(a, "RailR", (0.78, 0.08, -8.0), (0.10, 0.16, 20.0), "rust")
    for z in range(-17, 2, 2):
        add_box(a, "Tie" + str(z), (0, 0.035, float(z)), (2.3, 0.08, 0.20), "wood_dark")
    add_box(a, 'Notice backing', (0,1.86,.235),(3.60,1.31,.14),'wood_dark')
    add_poster(a, 'QuarantineBoard', (0,1.86,.309),(3.48,1.22),'print_quarantine','+z')
    add_beam(a, "FreshChainUpper", (-0.48, 1.40, 0.42), (0.48, 1.40, 0.42), 0.075, "steel")
    add_beam(a, "FreshChainLower", (-0.48, 1.05, 0.42), (0.48, 1.05, 0.42), 0.075, "steel")
    add_box(a, "FreshLock", (0.0, 1.22, 0.48), (0.28, 0.42, 0.12), "steel")
    add_box(a, "DrainBed", (13.9, 0.025, 4.0), (27.2, 0.05, 0.72), "stone_dark", rot_y=math.radians(3))
    add_box(a, "YellowBoyDrain", (13.9, 0.058, 4.0), (26.5, 0.045, 0.30), "ochre", rot_y=math.radians(3))
    add_box(a, "DrainBankL", (13.9, 0.10, 3.56), (27.2, 0.18, 0.18), "stone")
    add_box(a, "DrainBankR", (13.9, 0.10, 4.44), (27.2, 0.18, 0.18), "stone")
    a.empty("COL_MJ_Gate_Posts", {"shape": "boxes", "boxes": [[-2.25, 1.25, 0, 0.36, 2.5, 0.36], [2.25, 1.25, 0, 0.36, 2.5, 0.36]]})
    a.empty("COL_MJ_Gate_Leaves", {"shape": "boxes", "boxes": [[-1.18, 1.15, 0.02, 1.82, 2.12, 0.16], [1.18, 1.15, 0.02, 1.82, 2.12, 0.16]]})
    a.empty("ANCHOR_MJ_GATE_INTERACT", {"id": "mj_gate", "local_position": [0, 1.2, 0.6], "reserved_clearance": [3.4, 2.0, 1.6]})
    return a


def build_bridge_trough() -> Asset:
    a = Asset("creek_bridge_trough")
    pitch = 9.7 / 24
    for i in range(24):
        x = -4.85 + (i + 0.5) * pitch
        add_box(a, "DeckPlank" + str(i), (x, 0.28, 0), (pitch - 0.009, 0.22, 4.6), "wood_light")
    for side in (-1, 1):
        for i in range(5):
            t0, t1 = i / 5, (i + 1) / 5
            x0, x1 = (side * (6.37 - 1.52*t) for t in (t0 + .003, t1 - .003))
            y0, y1 = ((6.37 - abs(x)) * .39 / 1.52 for x in (x0, x1))
            top = [(x0,y0,-2.30),(x1,y1,-2.30),(x1,y1,2.30),(x0,y0,2.30)]
            toe = [(x,y-.12,z) for x,y,z in top]
            plank = a.part('ApproachPlank', 'wood_light')
            plank.add_face(top, (0,1,0))
            for j, n in enumerate(((0,0,-1),(-side,0,0),(0,0,1),(side,0,0))):
                k = (j+1)%4
                plank.add_face([top[j],top[k],toe[k],toe[j]], n)
    for z in (-1.75, 0, 1.75):
        add_box(a, "LongitudinalJoist" + str(z), (0, 0.10, z), (9.7, 0.20, 0.22), "wood_dark")
    for x in (-4.3, 4.3):
        add_box(a, "Stringer" + str(x), (x, 0.10, 0), (0.28, 0.32, 4.8), "wood_dark")
        for z in (-1.65, 0, 1.65):
            add_box(a, "Pile" + str(x) + str(z), (x, -0.35, z), (0.36, 1.5, 0.36), "wood_dark")
    for side in (-1, 1):
        add_box(a, "BridgeRail" + str(side), (0, 1.12, side * 2.16), (9.7, 0.14, 0.14), "wood_light")
        for x in (-4.4, 0, 4.4):
            add_box(a, "RailPost" + str(side) + str(x), (x, 0.68, side * 2.16), (0.17, 0.90, 0.17), "wood_dark")
    # Keep the approach lane clear of the former centerline bank stones.
    # Bridge origin (46.5, 0, 23) keeps the trough interaction at (23.5, 0, 29.4).
    tx, tz = -23.0, 6.4
    add_box(a, "TroughBody", (tx, 0.42, tz), (2.45, 0.84, 0.92), "wood_light")
    add_box(a, "TroughWater", (tx, 0.85, tz), (2.15, 0.06, 0.66), "water")
    add_box(a, "PumpStand", (tx + 1.35, 1.05, tz), (0.30, 1.65, 0.30), "iron")
    add_beam(a, "PumpHandle", (tx + 1.35, 1.72, tz), (tx + 0.55, 1.72, tz + 0.25), 0.10, "iron")
    add_cylinder(a, "PumpSpout", (tx + 1.35, 1.45, tz - 0.32), 0.10, 0.72, "iron", 8, rot_y=math.pi / 2)
    add_box(a, "TroughFootL", (tx - 0.82, 0.18, tz), (0.18, 0.36, 0.96), "wood_dark")
    add_box(a, "TroughFootR", (tx + 0.82, 0.18, tz), (0.18, 0.36, 0.96), "wood_dark")
    a.empty("COL_Bridge_Deck", {"shape": "tread_profile", "width": 4.6,
                               "profile_x_y": [[-6.37, 0], [-4.85, 0.39], [4.85, 0.39], [6.37, 0]]})
    a.empty("COL_Trough", {"shape": "box", "center": [tx, 0.42, tz], "size": [2.45, 0.84, 0.92]})
    a.empty("ANCHOR_HORSE_TROUGH_INTERACT", {"id": "horse_trough", "local_position": [tx, 0.55, tz], "world_position_when_placed_at_bible_origin": [23.5, 0.55, 29.4], "reserved_clearance": [2.3, 1.0, 1.1]})
    return a


def chapel_lancet(a: Asset, origin: Vec3, w: float, h: float, face: str, fill='dark_glass') -> None:
    x, y, z = origin
    n = {'-z': (0,0,-1), '+x': (1,0,0), '-x': (-1,0,0)}[face]
    def at(u, v, depth=0):
        if face == '-z':
            return x+u, y+v, z-depth
        return x+n[0]*depth, y+v, z-u*n[0]
    profile = [(-.5,0),(.5,0),(.5,.64),(.43,.78),(.24,.90),(0,1),(-.24,.90),(-.43,.78),(-.5,.64)]
    points = [at(u*w,v*h) for u,v in profile]
    a.part('Lancet glazing' if fill == 'dark_glass' else 'Recessed lancet panel', fill).add_face(points,n)
    trim = 'wood_dark' if fill == 'dark_glass' else 'white'
    for p,q in zip(points, points[1:]+points[:1]):
        add_beam(a,'Milled lancet casing',p,q,.093,trim)
    if fill == 'dark_glass':
        add_beam(a,'Lancet muntin',at(0,0,.035),at(0,h*.97,.035),.037,'wood_light')
        add_beam(a,'Lancet cross rail',at(-w*.49,h*.53,.035),at(w*.49,h*.53,.035),.047,'wood_light')
    elif h > 2:
        for u in (-.31,0,.31):
            add_beam(a,'Raised door stile',at(u*w,.12,.038),at(u*w,h*.68,.038),.065,'wood')
        add_beam(a,'Door lock plate',at(w*.27,.82,.05),at(w*.27,1.02,.05),.09,'iron')


def build_chapel_terrace(a: Asset) -> None:
    """Dress the low, playable churchyard shelf at the foot of the slope."""
    top = G.bench_top() - G.CY
    pave_top = top + 0.058

    # --- Paving is NOT the whole churchyard. A camp burying ground is earth with a
    # paved forecourt at the door and a walk down each flank of the nave; paving the
    # burial ground would make the plots read as decals on a courtyard, which is
    # exactly how the first build looked. The grave rows therefore sit on the graded
    # bench itself (BENCH top), and only the entry and the walks are stone.
    add_box(a, 'Churchyard forecourt', (0, top + .029, -6.30), (5.60, .058, 3.10), 'stone')
    add_box(a, 'Churchyard walk west', (-4.72, top + .029, -0.60), (1.55, .058, 11.2), 'stone')
    add_box(a, 'Churchyard walk east', (4.72, top + .029, -0.60), (1.55, .058, 11.2), 'stone')
    add_box(a, 'Churchyard walk south', (0.0, top + .029, 5.10), (11.0, .058, 1.30), 'stone')
    # Short dry-stone fronts flank the opening. No wall or fence crosses the approach.
    for side in (-1, 1):
        for i in range(3):
            y = top - .085 - i * .183
            for k in range(9):
                x = side * (1.32 + k * .755)
                add_box(a, 'Revetment face stone', (x, y, -8.12 - i * .055),
                        (.74, .18, .65), 'stone' if (i + k) % 3 else 'stone_dark')
        add_box(a, 'Revetment capstone', (side * 4.35, top + .011, -8.03),
                (6.77, .12, .66), 'stone')
    _chapel_stair(a, pave_top)

    # --- Fence: leaning pickets along the three cut edges of the bench.
    _chapel_fence(a, pave_top)

    # --- Graves: five plots on the level ground each side of the nave.
    _chapel_graves(a, pave_top)


def _chapel_stair(a: Asset, deck_top: float) -> None:
    """Four stone risers on the lane axis; full-depth steps support the player."""
    for i in range(4):
        z = -10.50 + i * .72
        y = -G.CY + (G.CY + deck_top) * (i + 1) / 4
        foot = -G.CY - .07
        add_box(a, 'Path tread', (0, (foot + y) / 2, z), (2.12, y - foot, .74),
                'stone' if i % 2 else 'stone_dark')
    add_box(a, 'Path apron', (0, -G.CY + .005, -13.24), (2.25, .02, 4.56), 'stone_dark')


def _chapel_fence(a: Asset, top: float) -> None:
    """Weathered picket fence on the three cut edges; leaning, not plumb.

    A hillside burying ground is fenced against stock, and an 1885 fence in a
    freezing camp leans. Posts are bedded into the bench (bottom below paving) and
    the pickets follow a slow deterministic tilt, so the line reads as settled
    rather than as a modelled picket run.
    """
    edges = [
        # North edge, broken directly in line with the porch.
        ((-7.70, -8.02), (-1.05, -8.02)),
        ((1.05, -8.02), (7.70, -8.02)),
        # West and east edges run south to the cut slope.
        ((-7.70, -8.02), (-7.70, 5.90)),
        ((7.70, -8.02), (7.70, 5.90)),
        # South edge.
        ((-7.70, 5.90), (7.70, 5.90)),
    ]

    seed = 1885
    for ei, (p0, p1) in enumerate(edges):
        ax, az = p0
        bx, bz = p1
        run = math.hypot(bx - ax, bz - az)
        count = max(2, int(run / 2.05) + 1)
        along_z = abs(bz - az) > abs(bx - ax)
        for k in range(count):
            t = k / (count - 1)
            lx = ax + (bx - ax) * t
            lz = az + (bz - az) * t
            # Posts lean a little and the caps sit off-centre: an 1885 camp fence
            # is not plumb. No rotation is applied because add_box rotates about
            # the asset origin, which would swing an edge post metres off its line.
            lean = 0.045 + 0.030 * math.sin(seed * 0.37 + ei * 1.7 + k * 0.9)
            add_box(a, 'Fence post', (lx, top + .52, lz), (.115, 1.14, .115), 'wood_dark')
            add_box(a, 'Post cap', (lx + lean * (0.0 if along_z else 0.3),
                                    top + 1.10, lz + lean * (0.3 if along_z else 0.0)),
                    (.165, .07, .165), 'wood_dark')
            if k == count - 1:
                continue
            nx = ax + (bx - ax) * ((k + 1) / (count - 1))
            nz = az + (bz - az) * ((k + 1) / (count - 1))
            for s in range(5):
                f = (s + 1) / 6.0
                px = lx + (nx - lx) * f
                pz = lz + (nz - lz) * f
                skew = 0.055 * math.sin(seed * 0.91 + ei * 2.3 + k * 1.7 + s * 1.31)
                # Pickets are driven into the paving: bottom below the top surface
                # so the fence reads as planted, not placed on the slabs.
                add_box(a, 'Picket', (px + (0.0 if along_z else skew), top + .43,
                                      pz + (skew if along_z else 0.0)),
                        (.072, 1.00, .052), 'wood_light' if (k + s) % 5 else 'wood')
            # Rails must span the diagonal the posts actually sit on, so the box is
            # sized on the dominant axis and pulled in to the segment length on the
            # other: a rail longer than its bay would poke through the next post.
            for rail_y in (.34, .78):
                add_box(a, 'Fence rail', ((lx + nx) / 2, top + rail_y, (lz + nz) / 2),
                        (.05, .07, math.hypot(nx - lx, nz - lz)) if along_z
                        else (math.hypot(nx - lx, nz - lz), .07, .05), 'wood_dark')

    # --- Gate: the opening is 2.10 m wide, with heavier hinge and latch posts and
    # one leaf hung open against the fence. A churchyard gate stands open in daylight
    # and an 1880s one is a braced plank leaf, not pickets, so it reads as a gate
    # from the street even at 100 m.
    gate_z = -8.02
    for gx in (-1.05, 1.05):
        add_box(a, 'Gate post', (gx, top + .62, gate_z), (.17, 1.36, .17), 'wood_dark')
        add_box(a, 'Gate post cap', (gx, top + 1.34, gate_z), (.23, .08, .23), 'wood_dark')
    # Leaf, swung back flat against the inside of the fence at the west jamb.
    for i in range(5):
        add_box(a, 'Gate leaf plank', (-1.02, top + .60, gate_z + .22 + i * .26),
                (.09, 1.02, .24), 'wood_light' if i % 2 else 'wood')
    for rail_y in (.28, .96):
        add_box(a, 'Gate leaf rail', (-1.02, top + rail_y, gate_z + .74), (.11, .10, 1.24), 'wood_dark')
    add_box(a, 'Gate leaf brace', (-1.02, top + .62, gate_z + .74), (.09, 1.14, .09), 'wood_dark')
    # Gate threshold: one slab so the opening reads as a way through, not a hole.
    add_box(a, 'Gate threshold', (0, top + .028, gate_z - .02), (2.07, .06, 1.05), 'stone')


def _chapel_graves(a: Asset, top: float) -> None:
    """Five 1885 graves on the level ground each side of the nave.

    Three headstones and two timber crosses, which is the mix you find in a camp
    cemetery of that year: carved stone for the families who could pay, a nailed
    cross for the miner who could not. The inscription is two thin dark bars
    because the mesh has no text; at the 100 m distance the street camera sees
    them they read as lettering, and close up as weathered cutting.
    """
    plots = [
        (-5.62, -2.20, 0.00, 'stone'),
        (-5.62, 0.30, 0.05, 'cross'),
        (-5.62, 2.70, -0.04, 'stone'),
        (5.62, -2.10, 0.03, 'stone'),
        (5.62, 1.05, -0.05, 'cross'),
    ]
    for lx, lz, tilt, kind in plots:
        # The plot is a sunken rectangle of earth kerbed in stone, cut into the
        # graded bench. Earth sits 0.05 BELOW the bench so a plot reads as a grave
        # and not as a raised slab: that is the whole visual difference between a
        # burying ground and a paved yard.
        add_box(a, 'Grave plot', (lx, top - .045, lz), (1.30, .09, 2.22), 'stone_dark')
        add_box(a, 'Grave earth', (lx, top - .020, lz), (1.10, .055, 2.02), 'wood')
        for kx, kz, kw, kd in ((-.61, 0, .06, 2.22), (.61, 0, .06, 2.22),
                               (0, -1.08, 1.30, .06), (0, 1.08, 1.30, .06)):
            add_box(a, 'Plot border', (lx + kx, top + .028, lz + kz), (kw, .085, kd), 'stone')
        # The head of the plot is at -z; the grave runs away from it. The small
        # tilt is applied by offsetting the stone's base, not by rotating about
        # the asset origin (add_box rotates about the origin, which at x = -5.6
        # would swing the stone off its plot).
        hz = lz - 1.16
        if kind == 'stone':
            add_box(a, 'Headstone plinth', (lx, top + .055, hz), (.72, .13, .30), 'stone_dark')
            add_box(a, 'Headstone', (lx + tilt * .3, top + .50, hz), (.62, .78, .135), 'stone')
            add_box(a, 'Headstone shoulder', (lx + tilt * .55, top + .90, hz), (.46, .10, .125), 'stone')
            add_box(a, 'Incised name', (lx + tilt * .55, top + .60, hz - .075), (.50, .045, .012), 'stone_dark')
            add_box(a, 'Incised date', (lx + tilt * .55, top + .47, hz - .075), (.30, .035, .012), 'stone_dark')
            add_box(a, 'Headstone cap', (lx + tilt * .6, top + .955, hz), (.34, .05, .14), 'mortar')
        else:
            add_box(a, 'GraveCross foot', (lx, top + .05, hz), (.36, .20, .56), 'stone_dark')
            add_box(a, 'GraveCross upright', (lx + tilt * .2, top + .58, hz), (.095, 1.06, .085), 'wood_dark')
            add_box(a, 'GraveCross arm', (lx + tilt * .5, top + .86, hz), (.66, .085, .075), 'wood_dark')


def build_chapel() -> Asset:
    a = Asset("chapel_steeple")
    # Carpenter Gothic: clapboards, steep roof and lancets (Grace Church, Georgetown, CO).
    add_box(a, 'Masonry footing', (0,-.445,0), (7.4,.91,10.1), 'stone_dark')
    for i in range(23):
        add_box(a, 'Lapped clapboard', (0,.45+i*.21,0), (7.33,.211,9.82), 'white')
    add_box(a, 'Weatherboard apron', (0,.184,0), (7.33,.33,9.82), 'white')
    add_gable_prism(a, 'Weatherboard gables', (0,5.16,0), 7.27,9.80,.08,2.95,'white')
    for sign in (-1,1):
        roof = a.part('Overhanging shingle roof', 'roof')
        for y, normal in ((0, (sign*.64,.77,0)), (-.15, (-sign*.64,-.77,0))):
            roof.add_face([(sign*4.12,5.0+y,-5.36),(0,8.37+y,-5.36),
                           (0,8.37+y,5.36),(sign*4.12,5.0+y,5.36)], normal)
        add_beam(a, 'Eave fascia', (sign*4.12,4.94,-5.36), (sign*4.12,4.94,5.36), .14, 'roof')
        for z in (-5.36,5.36):
            add_beam(a, 'Gable bargeboard', (sign*4.11,5.01,z), (0,8.38,z), .14, 'white')
        for z in (-4.94,4.94):
            add_box(a,'Corner casing',(sign*3.66,2.74,z),(.19,4.88,.18),'white')
        chapel_lancet(a, (sign*2.13, 1.72, -4.93), 1, 2.38, '-z')
        for z in (-3.10,0,3.10):
            chapel_lancet(a, (sign*3.69,1.68,z), .98, 2.50, '+x' if sign > 0 else '-x')
    chapel_lancet(a, (0, 1.30, -4.96), 1.42, 2.58, '-z', 'wood_dark')
    # The churchyard is dressed first so the building's entry can stand on the
    # paving surface the dressing establishes, not on the raw bench.
    build_chapel_terrace(a)
    pave = G.bench_top() - G.CY + 0.058                # -0.007 local
    # The four steps at the gate do the climbing; the walk stays level from
    # there all the way under the porch to the sill.
    add_box(a, 'Entry plinth', (0, pave - .085, -6.01), (3.10, .17, 2.06), 'stone')
    for i in range(5):
        add_box(a, 'Plinth joint', (-1.28 + i * .64, pave + .005, -5.52), (.05, .01, .92), 'mortar')
    for side in (-1, 1):
        add_box(a, 'Plinth cheek', (side * 1.63, pave, -5.52), (.24, .20, .98), 'stone_dark')
    # Porch posts stand on the lowest landing, not on air, and the footings are
    # sunk into it so the joint reads as a bedded stone rather than a hover.
    for x in (-1.52, 1.52):
        add_box(a, 'Porch post', (x, pave + 1.61, -6.80), (.17, 3.20, .17), 'white')
        add_beam(a, 'Porch knee brace', (x, pave + 2.54, -6.80), (x * .62, pave + 3.32, -6.80), .10, 'white')
        add_box(a, 'Post footing', (x, pave + .05, -6.80), (.36, .30, .36), 'stone')
    add_gable_prism(a, 'Entry canopy', (0, pave + 3.44, -6.28), 3.24, 1.92, .16, .86, 'roof')

    # --- Belfry: an open timber lantern, so the bell is actually visible from
    # the street. The old box was a closed clapboard drum with louvres painted on
    # its south face — there was no bell in it and no way to see one.
    add_box(a,'Belfry sill',(0,5.98,-2.5),(2.85,.26,2.95),'white')
    for sx in (-1,1):
        for sz in (-1,1):
            add_box(a,'Belfry corner post',(sx*1.12,7.72,-2.5+sz*1.16),(.24,3.24,.24),'white')
    for y in (6.42, 8.98):
        for sx in (-1,1):
            add_beam(a,'Belfry girt',(sx*1.12,y,-3.66),(sx*1.12,y,-1.34),.17,'white')
        for sz in (-1,1):
            add_beam(a,'Belfry girt',(-1.12,y,-2.5+sz*1.16),(1.12,y,-2.5+sz*1.16),.17,'white')
    # Braced corner knees keep the lantern from reading as a bare cage.
    for sx in (-1,1):
        for sz in (-1,1):
            add_beam(a,'Belfry brace',(sx*1.12,6.42,-2.5+sz*1.16),(sx*.30,8.98,-2.5+sz*.30),.10,'white')
    # Lapped weatherboard panels on three faces, the south face left open.
    for sy in (1,-1):
        for i in range(7):
            add_box(a,'Belfry weatherboard',(0,6.62+i*.34,-2.5+sy*1.16),(2.10,.33,.10),'white')
    for sx in (-1,1):
        for i in range(7):
            add_box(a,'Belfry weatherboard',(sx*1.12,6.62+i*.34,-2.5),(.10,.33,2.10),'white')
    # Open south bay: the bell hangs in this gap, framed by the corner posts.
    add_box(a,'Belfry south head',(0,9.12,-3.66),(2.24,.24,.14),'white')

    # --- The bell itself: cast bronze, waist-widened, on a through-bolted headstock.
    add_cylinder(a,'Bell headstock',(0,8.78,-3.10),.13,.96,'wood_dark',8)
    add_cylinder(a,'Bell headstock iron',(0,8.80,-3.10),.075,1.10,'iron',8)
    for y, r, h, top in ((8.34, .13, .30, .15), (8.17, .21, .22, .13), (7.98, .30, .22, .21),
                         (7.78, .36, .26, .30), (7.58, .39, .22, .36), (7.44, .38, .10, .39)):
        add_cylinder(a,'Bell bronze',(0,y,-3.10),r,h,'bell_bronze',14,top)
    # Sound bow and lip: the thick rim that gives a bell its strike tone.
    add_cylinder(a,'Bell lip',(0,7.38,-3.10),.40,.15,'bell_bronze',14,.45)
    add_cylinder(a,'Bell crown',(0,8.47,-3.10),.15,.10,'bell_bronze',10,.09)
    # Clapper hanging inside, just visible under the lip.
    add_cylinder(a,'Bell clapper',(0,7.34,-3.10),.045,.44,'iron',8)
    add_cylinder(a,'Clapper ball',(0,7.12,-3.10),.10,.16,'iron',8)
    add_beam(a,'Bell wheel stay',(-.34,8.60,-3.10),(.34,8.60,-3.10),.07,'iron')
    add_box(a,'Bell rope fall',(0,6.24,-3.34),(.05,2.10,.05),'wood_light')
    add_box(a,'Belfry cornice',(0,9.42,-2.5),(2.95,.26,3.05),'white')
    add_cylinder(a,'Shingled steeple',(0,11.03,-2.5),2.05,3.32,'roof',4,.05,math.pi/4)
    add_box(a,'Cross upright',(0,13.06,-2.5),(.11,.81,.11),'iron')
    add_box(a,'Cross arm',(0,13.14,-2.5),(.68,.12,.10),'iron')
    # Collision is expressed in the same chapel-local frame the builder uses, so
    # the Godot side can copy these numbers without a second coordinate system.
    # The nave box is split into two wall slabs plus the end wall (the building is
    # hollow: the player never enters, but the raycast for the entry must not read
    # a solid block); the churchyard gets a shelf the graves and stair stand on.
    a.empty("COL_Chapel_Nave", {"shape": "boxes", "boxes": [[-2.02, 2.65, 0, 3.25, 5.0, 9.8], [2.02, 2.65, 0, 3.25, 5.0, 9.8], [0, 4.55, 4.78, 7.4, 1.2, 0.36]]})
    a.empty("COL_Chapel_Bench", {"shape": "box", "center": [0, -0.30, -1.00], "size": [15.9, 0.60, 13.6]})
    a.empty("COL_Chapel_Revetment", {"shape": "box", "center": [0, -0.86, -8.55], "size": [15.9, 1.70, 0.90]})
    a.empty("COL_Chapel_Belfry", {"shape": "box", "center": [0, 7.72, -2.5], "size": [2.55, 3.40, 2.65]})
    a.empty("ANCHOR_CHAPEL_BELL", {"id": "chapel_bell", "local_position": [0, 8.10, -3.10],
                                   "world_position_when_placed_at_bible_origin": [-46, 8.72, 35.90],
                                   "reserved_clearance": [2.6, 3.4, 2.7]})
    return a


def build_mine_headframe() -> Asset:
    a = Asset('mine_headframe')
    # Leadville timber hoists: battered posts, accessible sheave deck and a separate engine shed.
    for x in (-1, 1):
        for z in (-1, 1):
            add_box(a, 'Granite pier', (x*2.7,.17,z*2.05), (.89,.43,.89), 'stone_dark')
            add_beam(a, 'Battered timber leg', (x*2.7,.31,z*2.05), (x*1.29,12,z*1.30), .42, 'wood')
    for lo, hi in ((.64,4.0),(4.0,7.8),(7.8,11.65)):
        def corner(x, y, z):
            return (x*(2.7-y*.1175), y, z*(2.05-y*.0625))
        for i in (-1,1):
            for fixed_axis in (0,2):
                def pt(j, y):
                    return corner(i,y,j) if fixed_axis == 0 else corner(j,y,i)
                add_beam(a, 'Horizontal girt', pt(-1,hi),pt(1,hi),.27,'wood')
                for j in (-1,1):
                    add_beam(a, 'Diagonal brace', pt(j,lo),pt(-j,hi),.20,'wood_dark')
    add_box(a,'Sheave deck',(0,11.78,0),(3.9,.26,3.4),'wood_light')
    add_wheel(a,'Hoisting sheave',(0,13.32,0),1.29,0)
    add_beam(a,'Flanged shaft collar',(-1,12.05,0),(1,12.05,0),.32,'iron')
    for z in (-1.17,1.17):
        add_beam(a,'Sheave bearing support',(0,11.75,z),(0,13.32,z),.34,'wood')
    add_beam(a,'Sheave shaft',(0,13.32,-1.31),(0,13.32,1.31),.25,'iron')
    add_box(a,'Engine shed rubble base',(8,.24,-3),(8.9,.48,6.2),'stone_dark')
    add_box(a,'Engine shed siding',(8,2.22,-3),(8.7,3.85,6),'wood')
    add_gable_prism(a,'Engine shed roof',(8,4.15,-3),9.15,6.53,.20,1.58,'roof')
    add_box(a,'Sliding freight door',(7,1.64,.036),(2.41,2.8,.12),'wood_dark')
    add_beam(a,'Sliding door strap',(5.9,.52,.12),(8.12,2.76,.12),.16,'wood_light')
    for x in (9.12,11.05):
        add_box(a,'Hoist shop sash',(x,2.35,.09),(1.11,1.25,.17),'wood_light')
        add_box(a,'Hoist shop glazing',(x,2.35,.19),(.88,1.04,.04),'dark_glass')
        add_box(a,'Sash meeting rail',(x,2.35,.22),(.9,.085,.08),'wood_light')
    add_beam(a,'Haul cable',(0,13.38,0),(5.08,3.53,-1.4),.043,'iron')
    add_cylinder(a,'Brick boiler chimney',(13,5.68,-5.9),.91,11.36,'brick',12,.56)
    add_cylinder(a,'Corbelled chimney crown',(13,11.36,-5.9),.73,.34,'brick',12)
    add_cylinder(a,'Chimney mouth',(13,11.55,-5.9),.52,.035,'iron',12)
    return a


def add_boulder(asset: Asset, name: str, center: Vec3, radius: float, height: float,
                material: str = "stone", seed: int = 0, sides: int = 9) -> None:
    """A faceted, angular river boulder bedded into the bank.

    Built from three vertex rings with per-vertex radial and vertical jitter, so the
    silhouette is a chipped block rather than a smooth drum: the footprint is drawn
    in and the base is pushed `BED` under `center.y` so no face can hover over the
    gravel. Creeks in the Colorado mineral belt are full of these — plucked granite
    that has been tumbled but not rounded.
    """
    BED = 0.14
    cx, cy, cz = center
    p = asset.part(name, material)
    rnd = (lambda n: ((seed * 1103515245 + n * 12345) % 997) / 997.0)
    top_ring: List[Vec3] = []
    shoulder: List[Vec3] = []
    base_ring: List[Vec3] = []
    for i in range(sides):
        a = math.tau * i / sides
        # Two unequal phases keep the top and shoulder from echoing each other.
        r_top = radius * (0.62 + 0.30 * rnd(i + 3))
        r_mid = radius * (0.86 + 0.16 * rnd(i * 5 + 1))
        r_bot = radius * (0.74 + 0.14 * rnd(i * 7 + 9))
        y_top = cy - BED + height * (0.86 + 0.14 * rnd(i * 3 + 2))
        y_mid = cy - BED + height * (0.44 + 0.16 * rnd(i * 11 + 4))
        top_ring.append((cx + math.cos(a) * r_top, y_top, cz + math.sin(a) * r_top))
        shoulder.append((cx + math.cos(a) * r_mid, y_mid, cz + math.sin(a) * r_mid))
        base_ring.append((cx + math.cos(a) * r_bot, cy - BED, cz + math.sin(a) * r_bot))
    cap = (cx + radius * 0.10, cy - BED + height * 1.02, cz - radius * 0.14)
    for i in range(sides):
        j = (i + 1) % sides
        an = math.tau * (i + 0.5) / sides
        out = (math.cos(an), 0.0, math.sin(an))
        p.add_face([shoulder[i], shoulder[j], top_ring[j], top_ring[i]],
                   (out[0] * 0.8, 0.62, out[2] * 0.8))
        p.add_face([base_ring[i], base_ring[j], shoulder[j], shoulder[i]], out)
        p.add_face([top_ring[i], top_ring[j], cap], (out[0] * 0.7, 1.0, out[2] * 0.7))
    p.add_face(list(reversed(base_ring)), (0, -1, 0))


def add_wall_with_openings(asset: Asset, name: str, x0: float, x1: float, y0: float, y1: float,
                           z: float, depth: float, material: str,
                           holes: Sequence[Tuple[float, float, float, float]]) -> None:
    """A wall slab with genuine rectangular apertures cut through it.

    `holes` are (x centre, y centre, width, height) in the wall's own plane. Splitting
    the slab into the pieces around each hole is what makes a jail light an actual
    opening in 0.45 m of stone: a dark card standing in front of the wall reads as a
    painted rectangle from every angle but head-on, and a two-face shell reads worse.
    """
    cuts = sorted(holes, key=lambda h: h[0] - h[2] / 2.0)
    cursor = x0
    for cx, cy, w, h in cuts:
        left, right = cx - w / 2.0, cx + w / 2.0
        bottom, top = cy - h / 2.0, cy + h / 2.0
        if left > cursor:
            add_box(asset, name, ((cursor + left) / 2.0, (y0 + y1) / 2.0, z),
                    (left - cursor, y1 - y0, depth), material)
        if bottom > y0:
            add_box(asset, name + " sill", (cx, (y0 + bottom) / 2.0, z),
                    (w, bottom - y0, depth), material)
        if top < y1:
            add_box(asset, name + " head", (cx, (top + y1) / 2.0, z),
                    (w, y1 - top, depth), material)
        cursor = right
    if cursor < x1:
        add_box(asset, name, ((cursor + x1) / 2.0, (y0 + y1) / 2.0, z),
                (x1 - cursor, y1 - y0, depth), material)


def build_roadside_props() -> Asset:
    a = Asset("roadside_props")
    # World-space placement, deliberately outside the core walk lines and existing interaction boxes.
    add_box(a, 'WagonBed', (0, 1.16, 0), (4.65, .23, 2.06), 'wood_dark')
    for z in (-.99, .99):
        for y in (1.37, 1.64):
            add_box(a, 'WagonSideboard', (0, y, z), (4.55, .25, .10), 'wood_red')
        for x in (-2.19, -.78, .78, 2.19):
            add_box(a, 'WagonStake', (x, 1.47, z*1.06), (.10, .65, .13), 'wood_light')
    for x in (-2.25, 2.25):
        add_box(a, 'WagonEndboard', (x, 1.48, 0), (.12, .47, 1.94), 'wood_red')
    for x in (-1.67, 1.67):
        add_beam(a, 'WagonAxle', (x, .90, -1.28), (x, .90, 1.28), .15, 'iron')
        add_box(a, 'WagonBunk', (x, 1.01, 0), (.22, .21, 2.18), 'wood_dark')
        for z in (-1.23, 1.23):
            add_wheel(a, 'WagonWheel', (x, .90, z), .90)
    add_beam(a, 'WagonTongue', (1.74, .94, 0), (4.24, .082, 0), .16, 'wood')
    transform_parts(a.parts, (-9, 0, 27), -.105)
    for i, (z, y) in enumerate(((19.62,.24), (20.16,.24), (20.70,.24), (19.9,.65), (20.43,.65))):
        add_beam(a, 'SplitFirewood' + str(i), (-40.5 + .07*i, y, z), (-38 + .05*i, y, z), .45, 'wood_light')
    for i, (x, z) in enumerate(((-14, 26.5), (-13, 26.9), (7, 27.8))):
        for y, r, h, top in ((.14,.40,.28,.47), (.56,.47,.56,.47), (.97,.47,.26,.40)):
            add_cylinder(a, 'BarrelStaves' + str(i), (x,y,z), r, h, 'wood', 14, top)
        for y, r in ((.16,.447), (.40,.482), (.73,.482), (.99,.447)):
            add_cylinder(a, 'BarrelHoop' + str(i), (x,y,z), r, .045, 'iron', 14)
    add_box(a, "HitchRail", (-28.0, 0.72, 29.3), (5.0, 0.12, 0.12), "wood_dark")
    for x in (-30.3, -28.0, -25.7):
        add_box(a, "HitchPost" + str(x), (x, 0.72, 29.3), (0.16, 1.45, 0.16), "wood_dark")

    # No posters on the poles. `black_creek_telegraph_lines.gd` already nails a
    # double-sided WeatheredBroadside to every second pole at eye height, wrapped
    # to the timber; the five 0.62 x 0.92 one-sided cards that used to sit here at
    # 3.75 m with no support are gone, not moved.

    # Four angular boulders in the reach below the bridge. The old pieces were
    # eight-sided drums whose flat undersides floated 0.28 m over the gravel; these
    # are faceted, irregular, and bedded 0.14 m into the surface they stand on, so
    # the creek bed (y -0.425) and the east bank (y 0.265) both meet stone.
    BED_TOP, BANK_TOP = -0.425, 0.265
    for i, (x, z, r, h, base) in enumerate((
            (44.35, 26.55, 0.62, 0.58, BED_TOP),
            (49.85, 27.20, 0.78, 0.74, BED_TOP),
            (46.10, 30.30, 0.66, 0.52, BED_TOP),
            (51.05, 28.55, 0.58, 0.50, BANK_TOP))):
        add_boulder(a, "CreekBoulder" + str(i), (x, base + 0.14, z), r, h, "stone", seed=i * 37 + 11)

    # Work left out where the day crew would leave it: nothing here takes a walk
    # line, a doorway or an interaction clearance, and none of it carries collision.
    _depot_freight(a)
    _smithy_work_bench(a)
    _store_deliveries(a)
    _trough_kit(a)

    a.empty("COL_Wagon", {"shape": "box", "center": [-9.0, 1.15, 27.0], "size": [4.8, 1.8, 2.2]})
    a.empty("COL_Woodpile", {"shape": "box", "center": [-39.0, 0.8, 20.0], "size": [3.2, 1.8, 1.1]})
    a.empty("COL_HitchRail", {"shape": "box", "center": [-28.0, 0.72, 29.3], "size": [5.0, 1.45, 0.30]})
    return a


def _crate(asset: Asset, name: str, center: Vec3, size: Vec3, yaw: float = 0.0) -> None:
    """A nailed shipping crate: body plus the corner battens that read at 3 m."""
    cx, cy, cz = center
    add_yaw_box(asset, name, center, size, "wood_light", yaw)
    band = 0.055
    for edge in (-1.0, 1.0):
        add_yaw_box(asset, name + " batten", (cx, cy + edge * (size[1] / 2 - band), cz),
                    (size[0] + 0.02, band, 0.045), "wood_dark", yaw)
    # Corner straps run face-to-face, so they rotate about the crate's own centre.
    half = (size[0] / 2, size[1] / 2, size[2] / 2)
    c, s = math.cos(yaw), math.sin(yaw)
    for side in (-1.0, 1.0):
        lo_local = (-half[0], -half[1], side * half[2])
        hi_local = (half[0], half[1], side * half[2])
        lo = (cx + lo_local[0] * c - lo_local[2] * s, cy + lo_local[1], cz + lo_local[0] * s + lo_local[2] * c)
        hi = (cx + hi_local[0] * c - hi_local[2] * s, cy + hi_local[1], cz + hi_local[0] * s + hi_local[2] * c)
        add_beam(asset, name + " strap", lo, hi, 0.07, "wood", 0.035)


def _depot_freight(a: Asset) -> None:
    """Two crates and a sack stacked on the platform against the depot's east wall.

    The platform deck is at y 0.30, so each piece is stacked up from that plane
    rather than sunk into it. The stack hugs the shell's east wall (which ends at
    x 12.0) and leaves 0.25 m to the platform rim at x 13.2, clear of the freight
    ramp at z -13.8..-12.0 and of the south apron walk.
    """
    _crate(a, "DepotCrateA", (12.50, 0.60, -8.30), (0.86, 0.60, 0.74), 0.03)
    _crate(a, "DepotCrateB", (12.53, 1.06, -8.36), (0.60, 0.32, 0.56), -0.09)
    add_yaw_box(a, "DepotSack", (12.45, 0.45, -9.16), (0.46, 0.30, 0.42), "wood_light", 0.22)
    add_yaw_box(a, "DepotSackTie", (12.45, 0.60, -9.16), (0.12, 0.05, 0.12), "wood_dark", 0.22)


def _smithy_work_bench(a: Asset) -> None:
    """A quench tub and a tongs trestle under the smithy's open east canopy.

    The shop shell ends at x -40.80 and the canopy roof reaches x -39.20, so this
    strip is the only covered ground a player can actually see into; the pieces sit
    in it rather than behind the wall, 1.6 m north of the door line so nobody walking
    up to Kowalski's threshold has to steer around them.
    """
    tx, tz = -40.22, 15.55
    add_cylinder(a, "QuenchTub", (tx, 0.30, tz), 0.44, 0.60, "wood", 14)
    for y, r in ((0.10, 0.462), (0.50, 0.462)):
        add_cylinder(a, "QuenchTubHoop", (tx, y, tz), r, 0.05, "iron", 14)
    add_cylinder(a, "QuenchWater", (tx, 0.585, tz), 0.395, 0.03, "water", 14)
    # A low trestle with tongs and a hammer leaning off it, handles on the dirt.
    add_yaw_box(a, "TrestleTop", (-40.15, 0.52, 16.62), (1.16, 0.10, 0.24), "wood_dark", 0.06)
    for dx in (-0.46, 0.46):
        add_yaw_box(a, "TrestleLeg", (-40.15 + dx, 0.26, 16.62), (0.11, 0.52, 0.20), "wood", 0.06)
    for i, (dx, tilt) in enumerate(((-0.30, 0.15), (-0.09, 0.09), (0.14, 0.19))):
        add_beam(a, "Tongs" + str(i), (-40.44 + dx, 0.02, 16.60),
                 (-40.44 + dx + tilt, 0.86, 16.54), 0.045, "iron")
    add_yaw_box(a, "HammerHead", (-39.72, 0.80, 16.58), (0.20, 0.09, 0.09), "iron", 0.28)
    add_beam(a, "HammerHaft", (-39.72, 0.78, 16.58), (-39.57, 0.10, 16.69), 0.055, "wood_light")


def _store_deliveries(a: Asset) -> None:
    """A hogshead and a crate left on the mercantile's west flank, off the porch."""
    hx, hz = -23.62, 35.90
    add_cylinder(a, "StoreHogshead", (hx, 0.44, hz), 0.40, 0.88, "wood", 14)
    for y in (0.10, 0.44, 0.78):
        add_cylinder(a, "StoreHogsheadHoop", (hx, y, hz), 0.418, 0.05, "iron", 14)
    add_cylinder(a, "StoreHogsheadLid", (hx, 0.885, hz), 0.40, 0.03, "wood_dark", 14)
    _crate(a, "StoreCrate", (-23.70, 0.26, 34.78), (0.60, 0.52, 0.54), -0.12)


def _trough_kit(a: Asset) -> None:
    """A tin bucket and a curry brush left at the trough's east end.

    Both rest on the dirt beside the trough rather than on its water, so nothing
    floats: the bucket's base is at y 0 and the brush lies on the gravel.
    """
    add_cylinder(a, "TroughBucket", (25.05, 0.13, 29.30), 0.155, 0.26, "iron", 10, 0.17)
    add_cylinder(a, "TroughBucketHandle", (25.05, 0.28, 29.30), 0.17, 0.02, "iron", 10)
    # Bristles down into the gravel, sawn back on top: the block's base is at y 0,
    # not 1 cm proud of it.
    add_yaw_box(a, "CurryBrush", (24.92, 0.025, 28.98), (0.26, 0.05, 0.10), "wood_dark", 0.34)
    add_yaw_box(a, "CurryBrushBack", (24.92, 0.065, 28.98), (0.25, 0.03, 0.095), "wood", 0.34)


def _align4(data: bytes, fill: bytes = b"\x00") -> bytes:
    return data + fill * ((4 - len(data) % 4) % 4)


def pack_f32(values: Iterable[float]) -> bytes:
    return struct.pack("<" + "f" * len(list(values)), *values)


def make_glb(asset: Asset, out_path: Path) -> None:
    buffer = bytearray()
    buffer_views: List[dict] = []
    accessors: List[dict] = []
    meshes: List[dict] = []
    nodes: List[dict] = []
    material_names = sorted({part.material for part in asset.parts})
    materials = []
    textures = []
    images = []
    samplers = [{"magFilter": 9728, "minFilter": 9728, "wrapS": 10497, "wrapT": 10497}]
    texture_ids: Dict[str, int] = {}

    def append_bytes(data: bytes, target: int | None = None) -> int:
        nonlocal buffer
        start = len(buffer)
        buffer.extend(data)
        if len(buffer) % 4:
            buffer.extend(b"\x00" * (4 - len(buffer) % 4))
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(data)}
        if target is not None:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    def texture(path: Path, roughness: bool = False, limewash: bool = False) -> dict:
        name = 'limewashed_plank' if limewash else path.stem
        if name not in texture_ids:
            if roughness:
                g = Image.open(path).convert('L')
                white = Image.new('L', g.size, 255)
                encoded = io.BytesIO()
                Image.merge('RGB', (white, g, white)).save(encoded, format='PNG')
                data = encoded.getvalue()
            elif limewash:
                grain = Image.open(path).convert('L')
                encoded = io.BytesIO()
                ImageOps.colorize(grain, '#a49d8e', '#f1eee4').save(encoded, format='PNG')
                data = encoded.getvalue()
            else:
                data = path.read_bytes()
            texture_ids[name] = len(textures)
            images.append({'name': name, 'bufferView': append_bytes(data), 'mimeType': 'image/png'})
            textures.append({'sampler': 0, 'source': len(images) - 1})
        return {'index': texture_ids[name]}

    for name in material_names:
        if name.startswith('print_'):
            pbr = {'metallicFactor': 0.0, 'roughnessFactor': 0.95,
                   'baseColorTexture': texture(PRINT_DIR / (name[6:] + '.png'))}
            materials.append({'name': name, 'pbrMetallicRoughness': pbr})
            continue
        _, col, rough, metal = MATERIALS[name]
        pbr = {'baseColorFactor': list(col), 'metallicFactor': metal, 'roughnessFactor': rough}
        mat = {'name': name, 'pbrMetallicRoughness': pbr}
        family = ('plank' if name.startswith('wood') or name == 'white' else
                  'iron' if name in ('iron', 'rust') else 'stone' if name.startswith('stone') else
                  'brick' if name == 'brick' else 'roof' if name == 'roof' else None)
        if family:
            maps = PRINT_DIR.parent
            pbr['baseColorTexture'] = texture(maps / f'{family}_albedo.png', limewash=name == 'white')
            pbr['metallicRoughnessTexture'] = texture(maps / f'{family}_roughness.png', True)
            pbr['roughnessFactor'] = 1.0
            mat['normalTexture'] = {**texture(maps / f'{family}_normal.png'), 'scale': .62}
            # Tints modulate the photographed color instead of replacing it.
            pbr['baseColorFactor'] = ([.96, .93, .84, 1] if name == 'white' else
                                     [min(1, .35 + v * 1.25) for v in col[:3]] + [1])
        materials.append(mat)
    mat_index = {name: i for i, name in enumerate(material_names)}

    for node_info in asset.nodes:
        if "part" not in node_info:
            nodes.append({"name": node_info["name"], "extras": node_info.get("extras", {})})
            continue
        part: MeshPart = node_info["part"]
        if not part.vertices or not part.indices:
            nodes.append({"name": part.name})
            continue
        pos_flat = [q for p in part.vertices for q in p]
        norm_flat = [q for p in part.normals for q in p]
        uv_flat = [q for p in part.uvs for q in p]
        pos_view = append_bytes(struct.pack("<" + "f" * len(pos_flat), *pos_flat), 34962)
        norm_view = append_bytes(struct.pack("<" + "f" * len(norm_flat), *norm_flat), 34962)
        uv_view = append_bytes(struct.pack("<" + "f" * len(uv_flat), *uv_flat), 34962)
        idx_view = append_bytes(struct.pack("<" + "H" * len(part.indices), *part.indices), 34963)
        min_v = [min(p[i] for p in part.vertices) for i in range(3)]
        max_v = [max(p[i] for p in part.vertices) for i in range(3)]
        pos_acc = len(accessors)
        accessors.append({"bufferView": pos_view, "componentType": 5126, "count": len(part.vertices), "type": "VEC3", "min": min_v, "max": max_v})
        norm_acc = len(accessors)
        accessors.append({"bufferView": norm_view, "componentType": 5126, "count": len(part.normals), "type": "VEC3"})
        uv_acc = len(accessors)
        accessors.append({"bufferView": uv_view, "componentType": 5126, "count": len(part.uvs), "type": "VEC2"})
        idx_acc = len(accessors)
        accessors.append({"bufferView": idx_view, "componentType": 5123, "count": len(part.indices), "type": "SCALAR", "min": [min(part.indices)], "max": [max(part.indices)]})
        mesh_index = len(meshes)
        meshes.append({"name": part.name, "primitives": [{"attributes": {"POSITION": pos_acc, "NORMAL": norm_acc, "TEXCOORD_0": uv_acc}, "indices": idx_acc, "material": mat_index[part.material]}]})
        nodes.append({"name": part.name, "mesh": mesh_index})

    root_children = list(range(len(nodes)))
    gltf = {
        "asset": {"version": "2.0", "generator": "dead-wire phase4 landmark generator"},
        "scene": 0,
        "scenes": [{"name": asset.name, "nodes": root_children}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "textures": textures,
        "images": images,
        "samplers": samplers,
        "bufferViews": buffer_views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(buffer)}],
    }
    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes = _align4(json_bytes, b" ")
    binary = _align4(bytes(buffer))
    total_len = 12 + 8 + len(json_bytes) + 8 + len(binary)
    out = bytearray()
    out.extend(struct.pack("<III", 0x46546C67, 2, total_len))
    out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    out.extend(json_bytes)
    out.extend(struct.pack("<II", len(binary), 0x004E4942))
    out.extend(binary)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(out)


def write_catalog() -> None:
    catalog = {
        "coordinate_convention": "Godot world axes: X east, Y up, Z south; landmark origins are at art-bible grade positions.",
        "assets": [
            {"name": "water_tower", "path": "res://assets/models/town/water_tower.glb", "world_transform": ["-24", "0", "-14"], "collisions": ["COL_WaterTower_Legs", "COL_WaterTower_Tank"]},
            {"name": "kowalski_blacksmith", "path": "res://assets/models/town/kowalski_blacksmith.glb", "world_transform": ["-46", "0", "13"], "collisions": ["COL_Blacksmith_Body", "COL_Blacksmith_Forge"], "prints": ["blacksmith.png", "shoeing.png"]},
            {"name": "stone_calaboose", "path": "res://assets/models/town/stone_calaboose.glb", "world_transform": ["26", "0", "6"], "collisions": ["COL_Calaboose_Walls"], "prints": ["wanted.png"],
             "dressing_notes": "WantedPoster lies in the -X wall plane on a sawn backing board at local (-2.638, 1.92, 0.10); the two ArrowSlit lights are true 0.30 x 0.80 apertures cut through the 0.45 front wall at |x| 1.44, outboard of the oak jambs, with a dark lining 0.20 back and one iron bar."},
            {"name": "mj_spur_gate", "path": "res://assets/models/town/mj_spur_gate.glb", "world_transform": ["20", "0", "-16"], "collisions": ["COL_MJ_Gate_Posts", "COL_MJ_Gate_Leaves"], "interaction": {"id": "mj_gate", "world_point": [20, 1.2, -15.4], "reserved_clearance": [3.4, 2.0, 1.6]}, "prints": ["quarantine.png"]},
            {"name": "creek_bridge_trough", "path": "res://assets/models/town/creek_bridge_trough.glb", "world_transform": ["46", "0", "24"], "collisions": ["COL_Bridge_Deck", "COL_Trough"], "interaction": {"id": "horse_trough", "world_point": [23.5, 0.55, 29.4], "reserved_clearance": [2.3, 1.0, 1.1]}},
            {"name": "chapel_steeple", "path": "res://assets/models/town/chapel_steeple.glb", "world_transform": ["-46", "0.62", "39"], "collisions": ["COL_Chapel_Nave", "COL_Chapel_Bench", "COL_Chapel_Revetment", "COL_Chapel_Belfry"],
             "interaction": {"id": "chapel_bell", "world_point": [-46, 8.72, 35.90], "reserved_clearance": [2.6, 3.4, 2.7]}},
            {"name": "roadside_props", "path": "res://assets/models/town/roadside_props.glb", "world_transform": ["0", "0", "0"], "collisions": ["COL_Wagon", "COL_Woodpile", "COL_HitchRail"],
             "interaction_policy": "Decorative props stay outside depot, boarding, MJ and horse-trough interaction clearance. The depot crates, smithy quench tub and trestle, mercantile hogshead and trough bucket/brush are dressing only: they carry no collider and sit off every walk line.",
             "removed": "PolePoster0..4 (five 0.62 x 0.92 one-sided bills floating at y 3.75 with no support) are gone; black_creek_telegraph_lines.gd keeps the wrapped, double-sided WeatheredBroadside at eye height on every second pole.",
             "creek_boulders": "Four faceted, irregular boulders bedded 0.14 m into the ground at (44.35,26.55), (49.85,27.20), (46.10,30.30) on the creek bed reach below the bridge and (51.05,28.55) on the east bank, replacing four eight-sided drums whose flat undersides floated over the gravel."},
        ],
        "print_assets": [
            "res://assets/textures/town_v2/print/wanted.png",
            "res://assets/textures/town_v2/print/quarantine.png",
            "res://assets/textures/town_v2/print/blacksmith.png",
            "res://assets/textures/town_v2/print/shoeing.png",
        ],
        "existing_layout_notes": {
            "builder_positions_read": {"depot": [0, 0, -2.5], "main_track_z": -18, "creek_x": 47, "bridge_z": 23, "existing_trough": [23.5, 0, 29.4], "existing_mj_gate": [22, 0, -14], "existing_chapel": [-46, 0.62, 39]},
            "integration_note": "Art Bible §6.2 positions are authoritative for this packet; existing builder currently contains placeholder/prototype positions and must be integrated deliberately rather than overwritten by this generator.",
        },
    }
    (MODEL_DIR / "phase4_asset_catalog.json").write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    import argparse
    builders = {
        'water_tower': build_water_tower, 'kowalski_blacksmith': build_blacksmith,
        'stone_calaboose': build_calaboose, 'mj_spur_gate': build_mj_gate,
        'creek_bridge_trough': build_bridge_trough, 'chapel_steeple': build_chapel,
        'roadside_props': build_roadside_props, 'mine_headframe': build_mine_headframe,
    }
    parser = argparse.ArgumentParser(description='Rebuild selected GLBs using the authored print textures.')
    parser.add_argument('models', nargs='+', choices=builders)
    for name in parser.parse_args().models:
        make_glb(builders[name](), MODEL_DIR / (name + '.glb'))
        print(f'Wrote {name}.glb')


if __name__ == "__main__":
    main()
