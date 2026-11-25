"""Build the room's PSX surface maps from the local CC0 scans and worn boards."""

import ast
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets/textures"
TOWN = TEX / "town_v2"
ROOM = TEX / "office_surfaces"
ROOM.mkdir(exist_ok=True)
RESAMPLE = Image.Resampling.LANCZOS


def sized(image, size):
    return image.resize((size, size), RESAMPLE)


def scan(name, size, channel="albedo"):
    return sized(Image.open(TOWN / f"{name}_{channel}.png").convert("RGB"), size)


def tint(image, color, span):
    grey = ImageOps.autocontrast(ImageOps.grayscale(image), cutoff=1)
    dark = tuple(max(0, c - span) for c in color)
    light = tuple(min(255, c + span) for c in color)
    return ImageOps.colorize(grey, dark, light)


def from_height(height, strength):
    pixels = height.convert("L").load()
    w, h = height.size
    normal = Image.new("RGB", (w, h))
    values = []
    for y in range(h):
        for x in range(w):
            dx = (pixels[(x - 1) % w, y] - pixels[(x + 1) % w, y]) * strength
            dy = (pixels[x, (y + 1) % h] - pixels[x, (y - 1) % h]) * strength
            length = math.sqrt(1.0 + dx * dx + dy * dy)
            values.append(tuple(round(127.5 * (1.0 + n / length)) for n in (dx, dy, 1)))
    normal.putdata(values)
    return normal


def save_maps(folder, name, albedo, normal, roughness):
    albedo.save(folder / f"{name}_albedo.png", optimize=True)
    normal.save(folder / f"{name}_normal.png", optimize=True)
    roughness.save(folder / f"{name}_roughness.png", optimize=True)


def rough(image, low, high):
    return ImageOps.colorize(
        ImageOps.autocontrast(ImageOps.grayscale(image)), (low,) * 3, (high,) * 3
    ).convert("L")


def room_maps():
    board = scan("plank", 256).transpose(Image.Transpose.ROTATE_90)
    board = tint(board, (123, 87, 54), 46)
    height = ImageOps.grayscale(board).point(lambda value: 65 + value // 3)
    seams = ImageDraw.Draw(board)
    beads = ImageDraw.Draw(height)
    for x in range(0, 256, 32):
        seams.line((x, 0, x, 255), fill=(52, 35, 24), width=2)
        seams.line((x + 3, 0, x + 3, 255), fill=(104, 70, 43), width=2)
        seams.line((x + 6, 0, x + 6, 255), fill=(147, 108, 69))
        beads.line((x, 0, x, 255), fill=38, width=2)
        beads.line((x + 4, 0, x + 4, 255), fill=123, width=3)
    save_maps(ROOM, "beadboard", board, from_height(height.filter(ImageFilter.GaussianBlur(.65)), .024),
              rough(height, 143, 237))

    floor = Image.open(ROOT / "materials/style_tests/textures/psx/psx_floor_worn_128.png")
    floor = sized(floor.convert("RGB"), 256)
    wood_grain = scan("plank", 256)
    floor = Image.blend(floor, tint(wood_grain, (119, 113, 100), 49), .27)
    floor = ImageEnhance.Color(floor).enhance(.64)
    save_maps(ROOM, "floor", floor, from_height(floor, .019), rough(ImageOps.invert(floor), 129, 230))

    cloth = Image.open(TEX / "worn_warmth/baize_128_v1.png").convert("RGB")
    cloth = sized(cloth, 256)
    felt = tint(cloth, (22, 49, 33), 11)
    stains = Image.new("L", felt.size, 0)
    stain_draw = ImageDraw.Draw(stains)
    for x, y, rx, ry in [(104, 146, 43, 32), (165, 112, 4, 5), (173, 103, 2, 3), (87, 179, 5, 2)]:
        stain_draw.ellipse((x-rx, y-ry, x+rx, y+ry), fill=45 if rx > 8 else 152)
    felt.paste((26, 29, 19), mask=stains.filter(ImageFilter.GaussianBlur(2.0)))
    edge = ImageDraw.Draw(felt)
    edge.rectangle((8, 8, 247, 247), outline=(88, 65, 29), width=2)
    edge.rectangle((13, 13, 242, 242), outline=(56, 48, 27))
    save_maps(ROOM, "blotter", felt, from_height(cloth, .024), rough(cloth, 205, 250))

    weave = ImageOps.grayscale(cloth)
    draw = ImageDraw.Draw(weave)
    for y in range(0, 256, 5):
        draw.line((0, y, 255, y), fill=81, width=1)
    for x in range(0, 256, 5):
        draw.line((x, 0, x, 255), fill=104, width=1)
    save_maps(ROOM, "wool", tint(weave, (172, 160, 143), 21), from_height(weave, .022),
              rough(weave, 214, 252))

    rng = random.Random(1890)
    ember = Image.new("RGB", (128, 128), (27, 10, 5))
    draw = ImageDraw.Draw(ember)
    for _ in range(260):
        x, y = rng.randrange(128), rng.randrange(128)
        r = rng.randint(1, 7)
        color = rng.choice(((51, 19, 8), (102, 39, 9), (188, 73, 12), (226, 146, 42), (249, 191, 64)))
        draw.polygon(((x-r, y), (x, y-r), (x+r, y), (x, y+r)), fill=color)
    ember.filter(ImageFilter.GaussianBlur(.7)).save(ROOM / "ember_coals.png", optimize=True)

    enamel = tint(scan("plaster", 128), (126, 144, 136), 31)
    chips = ImageDraw.Draw(enamel)
    for x, y in ((8, 35), (39, 37), (50, 41), (65, 34), (89, 36), (105, 42), (119, 38), (86, 64)):
        chips.ellipse((x-2, y-1, x+3, y+2), fill=(55, 43, 33))
    enamel.save(ROOM / "cup_enamel.png", optimize=True)


COLORWAYS = {
    "book_wine": (104, 35, 34),
    "book_ocher": (131, 96, 47),
    "book_blue": (37, 61, 79),
    "book_olive": (61, 77, 47),
    "soot_glass": (101, 84, 59),
    "register_glass": (157, 166, 156),
}


def texture_source(kind, kit):
    if "wood" in kind:
        return "plank" if kind == "worn_wood" else "mahogany"
    if kind in {"brass", "iron", "sheet_iron", "rust", "coil", "coal", "wall_brass"}:
        return "iron"
    if kind == "brick":
        return "brick"
    if kind in {"paper", "enamel", "glass", "soot_glass", "register_glass", "dust"}:
        return "plaster"
    if kind in {"slate", "ebonite"}:
        return "stone"
    if kind in {"baize", "wool", "leather"} or kind.startswith("book_"):
        return "cloth"
    raise ValueError((kind, kit))


def kit_maps(script, kit, stem):
    path = ROOT / "tools" / script
    assignments = {}
    for statement in ast.parse(path.read_text(encoding="utf-8")).body:
        if isinstance(statement, ast.Assign) and getattr(statement.targets[0], "id", None) in {"TILES", "COLORS"}:
            assignments[statement.targets[0].id] = ast.literal_eval(statement.value)
    tiles = assignments["TILES"]
    colors = assignments["COLORS"] | COLORWAYS
    albedo = Image.new("RGB", (256, 256), (34, 28, 24))
    normal = Image.new("RGB", (256, 256), (128, 128, 255))
    roughness = Image.new("L", (256, 256), 235)
    for kind, (tx, ty) in tiles.items():
        if kind == "soot_glass":
            continue  # Shares the clear-glass UV tile, with a different Godot tint.
        source = texture_source(kind, kit)
        if source == "cloth":
            texture = sized(Image.open(TEX / "worn_warmth/baize_128_v1.png").convert("RGB"), 64)
            relief = from_height(texture, .02)
        else:
            texture = scan(source, 64)
            relief = scan(source, 64, "normal")
        color = colors[kind]
        if kind == "brass":
            color = (181, 141, 77)
        elif kind in {"iron", "sheet_iron"}:
            color = (71, 67, 61) if kind == "iron" else (88, 80, 72)
        span = 38 if source in {"mahogany", "iron", "plank", "brick"} else 17
        tile = tint(texture, color, span)
        if kind == "coil":
            rib = ImageDraw.Draw(tile)
            for y in range(0, 64, 4):
                rib.line((0, y, 63, y), fill=(97, 51, 29))
                rib.line((0, y + 1, 63, y + 1), fill=(154, 86, 46))
            relief = from_height(tile, .018)
        finish = (61, 140) if kind in {"brass", "wall_brass"} else (124, 218)
        if kind in {"paper", "baize", "wool"} or kind.startswith("book_"):
            finish = (190, 253)
        box = (tx * 64, (3 - ty) * 64)
        albedo.paste(tile, box)
        normal.paste(relief, box)
        roughness.paste(rough(texture, *finish), box)
    folder = TEX / kit
    albedo.save(folder / f"{stem}.png", optimize=True)
    normal.save(folder / f"{stem}_normal.png", optimize=True)
    roughness.save(folder / f"{stem}_roughness.png", optimize=True)


if __name__ == "__main__":
    room_maps()
    for source, folder, name in (
        ("build_instruments_blender.py", "instruments_v1", "instrument_atlas_256"),
        ("build_office_furniture_blender.py", "office_furniture_v1", "furniture_atlas_256"),
        ("build_office_props_blender.py", "office_props_v1", "props_atlas_256"),
        ("build_stove_blender.py", "stove_v1", "stove_atlas_256"),
    ):
        kit_maps(source, folder, name)
