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
    else:
        points = [(cx, cy - h / 2, cz + w / 2), (cx, cy - h / 2, cz - w / 2),
                  (cx, cy + h / 2, cz - w / 2), (cx, cy + h / 2, cz + w / 2)]
        normal = (1, 0, 0)
    p.add_face(points, normal, [(0, 1), (1, 1), (1, 0), (0, 0)])


def add_pointed_window(asset: Asset, name: str, center: Vec3, width: float, height: float, face: str = "-z") -> None:
    add_box(asset, name + "_dark", center, (width, height, 0.045) if face in ("+z", "-z") else (0.045, height, width), "dark_glass")
    if face in ("+z", "-z"):
        z = center[2] + (0.05 if face == "+z" else -0.05)
        add_box(asset, name + "_sill", (center[0], center[1] - height / 2 - 0.07, z), (width + 0.18, 0.10, 0.12), "wood_light")
        add_box(asset, name + "_side_l", (center[0] - width / 2, center[1], z), (0.10, height + 0.16, 0.12), "wood_light")
        add_box(asset, name + "_side_r", (center[0] + width / 2, center[1], z), (0.10, height + 0.16, 0.12), "wood_light")
        add_box(asset, name + "_point", (center[0], center[1] + height / 2 + 0.05, z), (0.10, 0.15, 0.12), "wood_light")
    else:
        x = center[0] + 0.05
        add_box(asset, name + "_side_l", (x, center[1], center[2] - width / 2), (0.12, height + 0.16, 0.10), "wood_light")
        add_box(asset, name + "_side_r", (x, center[1], center[2] + width / 2), (0.12, height + 0.16, 0.10), "wood_light")


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
    for x in (-2.0, 2.0):
        for dx in (-1.63, 0, 1.63):
            add_box(a,'Door stile',(x+dx,1.85,4.39),(.105,3.34,.09),'wood_light')
        for dx in (-.82,.82):
            add_beam(a,'Door diagonal',(x+dx-.68,.47,4.405),(x+dx+.68,3.15,4.405),.15,'wood')
        for y in (.58,3.12):
            add_box(a,'Hinge strap',(x-1.37,y,4.48),(.48,.118,.064),'rust')
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
    add_box(a, "FrontWest", (-1.72, 1.95, 3.0), (1.72, 3.5, 0.45), "stone")
    add_box(a, "FrontEast", (1.72, 1.95, 3.0), (1.72, 3.5, 0.45), "stone")
    add_box(a, "Lintel", (0, 3.54, 3.0), (1.75, 0.42, 0.48), "stone_dark")
    add_box(a, "Roof", (0, 3.83, 0), (5.55, 0.30, 6.55), "roof")
    add_box(a, "OakDoor", (0, 1.50, 3.25), (1.45, 2.35, 0.12), "wood_dark")
    add_box(a, "DoorBar", (0, 1.58, 3.36), (1.65, 0.14, 0.14), "iron")
    for x in (-1.05, 1.05):
        add_pointed_window(a, "ArrowSlit" + str(x), (x, 2.12, 3.24), 0.34, 0.85, "+z")
        add_box(a, "SlitBar" + str(x), (x, 2.12, 3.38), (0.05, 0.72, 0.08), "iron")
    add_poster(a, "WantedPoster", (-2.64, 1.92, 0.20), (0.92, 1.42), "print_wanted", "+z")
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


def build_chapel() -> Asset:
    a = Asset("chapel_steeple")
    # Carpenter Gothic: clapboards, steep roof and lancets (Grace Church, Georgetown, CO).
    add_box(a, 'Masonry footing', (0,-.28,0), (7.4,1.24,10.1), 'stone_dark')
    for i in range(23):
        add_box(a, 'Lapped clapboard', (0,.45+i*.21,0), (7.33,.211,9.82), 'white')
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
    chapel_lancet(a, (0,.58,-4.96), 1.48, 2.88, '-z', 'wood_dark')
    add_box(a, 'Porch landing', (0,.32,-5.52), (2.82,.24,1.37), 'wood_light')
    for x in (-1.13,1.13):
        add_box(a, 'Landing pier', (x,-.58,-5.94), (.29,1.60,.29), 'stone_dark')
        add_beam(a, 'Stair stringer', (x,.17,-6.05), (x,-.47,-7.27), .17, 'wood_dark')
    for i in range(4):
        add_box(a,'Porch stair',(0,.25-i*.17,-6.30-i*.29),(2.65,.23,.35),'wood_light')
    for x in (-1.22,1.22):
        add_box(a,'Porch post',(x,1.84,-5.98),(.16,2.85,.17),'white')
        add_beam(a,'Porch knee brace',(x,2.49,-5.98),(x*.65,3.24,-5.98),.10,'white')
    add_gable_prism(a,'Entry canopy',(0,3.36,-5.56),3.05,1.78,.15,.88,'roof')
    add_box(a,'Bell tower',(0,7.35,-2.5),(2.55,4.25,2.65),'white')
    chapel_lancet(a,(0,7.46,-3.84),1.19,1.64,'-z','wood_dark')
    for y in (7.7,7.96,8.22,8.48,8.74):
        add_box(a,'Bell louver',(0,y,-3.88),(.93 if y<8.55 else .64,.09,.08),'wood_light')
    add_box(a,'Belfry cornice',(0,9.53,-2.5),(2.85,.24,2.95),'white')
    add_cylinder(a,'Shingled steeple',(0,11.13,-2.5),1.93,3.16,'roof',4,.045,math.pi/4)
    add_box(a,'Cross upright',(0,13.08,-2.5),(.11,.81,.11),'iron')
    add_box(a,'Cross arm',(0,13.16,-2.5),(.68,.12,.10),'iron')
    a.empty("COL_Chapel_Nave", {"shape": "boxes", "boxes": [[-2.02, 2.65, 0, 3.25, 5.0, 9.8], [2.02, 2.65, 0, 3.25, 5.0, 9.8], [0, 4.55, 4.78, 7.4, 1.2, 0.36]]})
    a.empty("COL_Chapel_Belfry", {"shape": "box", "center": [0, 7.35, -2.5], "size": [2.55, 4.25, 2.65]})
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
    for i, x in enumerate((-42.0, -24.0, -8.0, 8.0, 24.0)):
        add_poster(a, "PolePoster" + str(i), (x + 0.15, 3.75, 12.40), (0.62, 0.92), "print_wanted" if i % 2 == 0 else "print_quarantine", "+z")
    # Keep the full radius of each bank stone beyond the bridge deck edge (z=25.30).
    for i, pos in enumerate(((43.0, 0.20, 20.0), (44.0, 0.23, 26.25), (50.0, 0.18, 28.5), (42.6, 0.16, 30.0))):
        add_cylinder(a, "CreekStone" + str(i), pos, 0.52 + i * 0.08, 0.35 + i * 0.03, "stone", 8)
    a.empty("COL_Wagon", {"shape": "box", "center": [-9.0, 1.15, 27.0], "size": [4.8, 1.8, 2.2]})
    a.empty("COL_Woodpile", {"shape": "box", "center": [-39.0, 0.8, 20.0], "size": [3.2, 1.8, 1.1]})
    a.empty("COL_HitchRail", {"shape": "box", "center": [-28.0, 0.72, 29.3], "size": [5.0, 1.45, 0.30]})
    return a


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
            {"name": "stone_calaboose", "path": "res://assets/models/town/stone_calaboose.glb", "world_transform": ["26", "0", "6"], "collisions": ["COL_Calaboose_Walls"], "prints": ["wanted.png"]},
            {"name": "mj_spur_gate", "path": "res://assets/models/town/mj_spur_gate.glb", "world_transform": ["20", "0", "-16"], "collisions": ["COL_MJ_Gate_Posts", "COL_MJ_Gate_Leaves"], "interaction": {"id": "mj_gate", "world_point": [20, 1.2, -15.4], "reserved_clearance": [3.4, 2.0, 1.6]}, "prints": ["quarantine.png"]},
            {"name": "creek_bridge_trough", "path": "res://assets/models/town/creek_bridge_trough.glb", "world_transform": ["46", "0", "24"], "collisions": ["COL_Bridge_Deck", "COL_Trough"], "interaction": {"id": "horse_trough", "world_point": [23.5, 0.55, 29.4], "reserved_clearance": [2.3, 1.0, 1.1]}},
            {"name": "chapel_steeple", "path": "res://assets/models/town/chapel_steeple.glb", "world_transform": ["-54", "9", "62"], "collisions": ["COL_Chapel_Nave", "COL_Chapel_Belfry"]},
            {"name": "roadside_props", "path": "res://assets/models/town/roadside_props.glb", "world_transform": ["0", "0", "0"], "collisions": ["COL_Wagon", "COL_Woodpile", "COL_HitchRail"], "interaction_policy": "Decorative props stay outside depot, boarding, MJ and horse-trough interaction clearance."},
        ],
        "print_assets": [
            "res://assets/textures/town_v2/print/wanted.png",
            "res://assets/textures/town_v2/print/quarantine.png",
            "res://assets/textures/town_v2/print/blacksmith.png",
            "res://assets/textures/town_v2/print/shoeing.png",
        ],
        "existing_layout_notes": {
            "builder_positions_read": {"depot": [0, 0, -2.5], "main_track_z": -18, "creek_x": 47, "bridge_z": 23, "existing_trough": [23.5, 0, 29.4], "existing_mj_gate": [22, 0, -14], "existing_chapel": [-46, 8.5, 58]},
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
