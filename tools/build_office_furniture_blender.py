"""Authored PSX furniture for the M1 office: telegraph desk, record bookcase,
and pigeonhole filing cabinet. Same pipeline as the potbelly stove.

Run with Blender 5.x Python:
    blender -b -P tools/build_office_furniture_blender.py

Writes, all in Godot metres:
    assets/models/office_furniture_v1/{desk,bookcase,cabinet}_static.glb
    assets/textures/office_furniture_v1/furniture_atlas_256.png
    assets/models/office_furniture_v1/build_manifest.json
    docs/art/state_2026-10-20/furniture/sources/*.blend (editable source)

Every piece is authored in its Godot prop-local space (origin on the floor,
+Y up), then converted for Blender with pos() and exported with export_yup,
so an instance of the prop scene places it exactly where the blockout was.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/office_furniture_v1"
OUT.mkdir(parents=True, exist_ok=True)
TEX = ROOT / "assets/textures/office_furniture_v1"
TEX.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "docs/art/state_2026-10-20/furniture/sources"
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("", encoding="utf-8")

COLLECTION = "DW_OfficeFurniture_v1"
old = bpy.data.collections.get(COLLECTION)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
coll = bpy.data.collections.new(COLLECTION)
bpy.context.scene.collection.children.link(coll)

# --- authored 256px atlas: 4x4 tiles of 64px -------------------------------
TILES = {
    "dark_wood": (0, 0),
    "mid_wood": (1, 0),
    "light_wood": (2, 0),
    "brass": (3, 0),
    "paper": (0, 1),
    "leather": (1, 1),
    "baize": (2, 1),
    "iron": (3, 1),
}
COLORS = {
    "dark_wood": (54, 40, 28),
    "mid_wood": (92, 66, 44),
    "light_wood": (124, 92, 60),
    "brass": (150, 118, 62),
    # Aged manila, not fresh white. The desk lamp sits 0.3 m from the pigeonhole
    # rack at 2.6 energy, so a 196-value paper clips to a flat white wedge with
    # no facet shading at all — the forms read as blank cutouts. 118 keeps them
    # inside the lamp's range so the flat-shaded facets still read as paper.
    "paper": (118, 102, 74),
    "leather": (74, 44, 34),
    "baize": (32, 58, 42),
    "iron": (46, 44, 42),
}

rng = random.Random(18941020)
image = bpy.data.images.new("DW_Furniture_Atlas_256", width=256, height=256)
pixels = [0.02, 0.02, 0.02, 1.0] * (256 * 256)

for kind, (tx, ty) in TILES.items():
    base = COLORS[kind]
    for y in range(64):
        for x in range(64):
            noise = rng.uniform(-3.0, 3.0)
            if kind in ("dark_wood", "mid_wood", "light_wood"):
                grain = 5.0 * math.sin(y * 0.62 + 2.4 * math.sin(x * 0.11))
                seam = -26.0 if (y % 32) in (0, 1) else 0.0
                detail = grain + seam
            elif kind == "brass":
                detail = 5.0 * math.sin(x * 0.22) * math.cos(y * 0.19)
                detail += -12.0 if ((x * 3 + y * 5) % 61) == 0 else 0.0
            elif kind == "paper":
                detail = 2.5 * math.sin(x * 0.9 + y * 0.4)
                detail += -8.0 if (y % 21) == 0 else 0.0
            elif kind == "leather":
                detail = 4.0 * math.sin(x * 0.7) * math.cos(y * 0.6)
                detail += -14.0 if ((x + y * 2) % 17) == 0 else 0.0
            elif kind == "baize":
                detail = 3.0 * math.sin(x * 1.3) * math.cos(y * 1.1)
            else:
                detail = 3.0 * math.sin(x * 0.41 + y * 0.37) + 2.0 * math.cos(y * 0.8)
            idx = ((ty * 64 + y) * 256 + tx * 64 + x) * 4
            for c in range(3):
                pixels[idx + c] = round(max(0, min(255, base[c] + detail + noise)) / 8) * 8 / 255
            pixels[idx + 3] = 1.0

image.pixels.foreach_set(pixels)
image.filepath_raw = str(TEX / "furniture_atlas_256.png")
image.file_format = "PNG"
image.save()
image.pack()

materials = {}
for kind in TILES:
    mat = bpy.data.materials.new("dw_furniture_" + kind)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.62 if kind == "brass" else 0.9
    bsdf.inputs["Metallic"].default_value = 0.6 if kind in ("brass", "iron") else 0.0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    materials[kind] = mat


def pos(v):
    """Godot prop-local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


CURRENT = []


# A wood grain tile repeated once across a 1.2 m panel reads as flat paint on
# a desk top; repeating it every ~0.4 m keeps the plank grain visible at the
# scale the player actually sees. UVs never change the silhouette.
UV_PERIOD = 0.40


def finish(obj, kind, uv_repeat=None):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(materials[kind])
    bpy.context.view_layer.objects.active = obj
    if not obj.data.uv_layers:
        obj.data.uv_layers.new()
    tx, ty = TILES[kind]
    if uv_repeat is None:
        extent = max(obj.dimensions) if max(obj.dimensions) > 0.0 else UV_PERIOD
        uv_repeat = max(1.0, round(extent / UV_PERIOD))
    for uv in obj.data.uv_layers.active.data:
        u = (uv.uv.x * uv_repeat) % 1.000001
        v = (uv.uv.y * uv_repeat) % 1.000001
        uv.uv.x = (tx * 64 + 2 + u * 60) / 256
        uv.uv.y = (ty * 64 + 2 + v * 60) / 256
    for face in obj.data.polygons:
        face.use_smooth = False
    CURRENT.append(obj)
    return obj


def box(name, centre, size, kind, bevel=0.0, rot_deg=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos(centre))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0], size[2], size[1])
    if any(rot_deg):
        obj.rotation_euler = (
            math.radians(rot_deg[0]),
            math.radians(-rot_deg[2]),
            math.radians(rot_deg[1]),
        )
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, kind)


def cyl(name, centre, radius, depth, kind, axis=(0, 1, 0), sides=10, radius_top=None):
    loc = pos(centre)
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=sides, radius1=radius, radius2=radius_top, depth=depth, location=loc
        )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(pos(axis).normalized())
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, kind)


def begin():
    CURRENT.clear()


def bake(name):
    """Join the current part list into one mesh and return it."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in CURRENT:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = CURRENT[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tri = obj.modifiers.new("Export triangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    return obj


def export(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / filename),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    return {
        "triangles": len(obj.data.polygons),
        "vertices": len(obj.data.vertices),
        "materials": [m.name for m in obj.data.materials],
        "aabb_godot": [
            round(min(v.co.x for v in obj.data.vertices), 4),
            round(min(v.co.z for v in obj.data.vertices), 4),
            round(-max(v.co.y for v in obj.data.vertices), 4),
            round(max(v.co.x for v in obj.data.vertices), 4),
            round(max(v.co.z for v in obj.data.vertices), 4),
            round(-min(v.co.y for v in obj.data.vertices), 4),
        ],
    }


# =========================================================================
# 1. Telegraph operator's desk (prop-local, DeskSetup origin on the floor)
#    Top surface stays at y = 0.75; the pigeonhole rack, pen tray and
#    inkwell keep their blockout footprints so the desk tests still measure
#    the same furniture.
# =========================================================================
begin()

# Top slab with a moulded lip that catches the lamp light.
box("DeskTop", (0.0, 0.72, 0.0), (1.5, 0.06, 0.75), "mid_wood", 0.004)
box("DeskTopLip", (0.0, 0.683, 0.0), (1.54, 0.024, 0.79), "dark_wood", 0.003)
box("DeskTopBead", (0.0, 0.664, 0.0), (1.5, 0.014, 0.75), "mid_wood", 0.002)

# Aprons between the legs, with a recessed panel line.
for side_z in (-0.335, 0.335):
    box("DeskApron" + ("Back" if side_z > 0 else "Front"), (0.0, 0.635, side_z), (1.38, 0.10, 0.035), "dark_wood", 0.003)
    box("DeskApronPanel" + ("Back" if side_z > 0 else "Front"), (0.0, 0.632, side_z - 0.02), (1.22, 0.06, 0.012), "mid_wood")
for side_x in (-0.715, 0.715):
    box("DeskApronSide", (side_x, 0.635, 0.0), (0.035, 0.10, 0.62), "dark_wood", 0.003)

# Turned legs: tapered octagonal shaft with two collars and a brass shoe.
for sx in (-0.68, 0.68):
    for sz in (-0.31, 0.31):
        cyl("DeskLeg", (sx, 0.345, sz), 0.046, 0.69, "dark_wood", axis=(0, 1, 0), sides=8, radius_top=0.034)
        cyl("DeskLegCollarTop", (sx, 0.60, sz), 0.048, 0.035, "dark_wood", axis=(0, 1, 0), sides=8)
        cyl("DeskLegCollarMid", (sx, 0.24, sz), 0.050, 0.030, "dark_wood", axis=(0, 1, 0), sides=8)
        cyl("DeskLegShoe", (sx, 0.02, sz), 0.042, 0.04, "brass", axis=(0, 1, 0), sides=8, radius_top=0.036)

# Drawer pedestal on the operator's right, three drawers with bail pulls.
box("DrawerCarcass", (0.48, 0.45, 0.0), (0.38, 0.48, 0.65), "dark_wood", 0.004)
box("DrawerCarcassTop", (0.48, 0.70, 0.0), (0.40, 0.02, 0.67), "mid_wood", 0.003)
for index, cy in enumerate((0.30, 0.475, 0.62)):
    box("DrawerFront%d" % index, (0.48, cy, -0.318), (0.34, 0.135, 0.022), "mid_wood", 0.004)
    box("DrawerBead%d" % index, (0.48, cy, -0.330), (0.30, 0.10, 0.008), "dark_wood")
    for bx in (0.40, 0.56):
        box("DrawerPullPost%d" % index, (bx, cy + 0.005, -0.336), (0.012, 0.012, 0.018), "brass")
    box("DrawerPullBar%d" % index, (0.48, cy + 0.005, -0.346), (0.15, 0.010, 0.010), "brass", 0.002)

# Back rail against the wall.
box("DeskBackRail", (0.0, 0.63, -0.345), (1.46, 0.08, 0.05), "dark_wood", 0.003)

# Pigeonhole rack: back, sides, top, bottom, dividers, mid shelf.
box("OrganizerBack", (-0.15, 0.87, 0.395), (0.95, 0.24, 0.012), "dark_wood", 0.002)
box("OrganizerTop", (-0.15, 0.9825, 0.34), (0.95, 0.015, 0.12), "dark_wood", 0.002)
box("OrganizerBottom", (-0.15, 0.7575, 0.34), (0.95, 0.015, 0.12), "dark_wood", 0.002)
box("OrganizerSideLeft", (-0.6175, 0.87, 0.34), (0.015, 0.24, 0.12), "dark_wood", 0.002)
box("OrganizerSideRight", (0.3175, 0.87, 0.34), (0.015, 0.24, 0.12), "dark_wood", 0.002)
for dx in (-0.45, -0.15, 0.15):
    box("OrganizerDivider", (dx, 0.87, 0.34), (0.012, 0.21, 0.12), "mid_wood")
box("OrganizerShelfMid", (-0.30, 0.87, 0.34), (0.30, 0.010, 0.118), "dark_wood")
box("OrganizerRail", (-0.15, 0.752, 0.283), (0.94, 0.012, 0.012), "dark_wood")

# Filed blanks standing in the cubbies, each at its blockout angle.
for index, (cx, cy, tilt) in enumerate(
    (
        (-0.54, 0.82, 6.9),
        (-0.30, 0.79, -6.9),
        (-0.30, 0.92, 6.9),
        (0.0, 0.83, -6.9),
        (0.23, 0.82, 6.9),
    )
):
    box("OrganizerForms%d" % index, (cx, cy, 0.35), (0.16, 0.10 if index != 1 else 0.05, 0.006), "paper", 0.001, rot_deg=(0, 0, tilt))

# Pen tray with two steel pens, inkwell with a brass cap, wire lead block.
box("PenTray", (0.52, 0.758, -0.18), (0.18, 0.016, 0.06), "dark_wood", 0.003)
box("PenTrayInset", (0.52, 0.766, -0.18), (0.15, 0.006, 0.038), "baize")
cyl("PenShaft1", (0.48, 0.772, -0.18), 0.006, 0.15, "iron", axis=(1, 0.12, 0.0), sides=6)
cyl("PenShaft2", (0.56, 0.772, -0.19), 0.006, 0.14, "iron", axis=(1, -0.18, 0.05), sides=6)
# The inkwell stands right of the copy board, within the writing hand's reach
# (plan 5.8; tools/move_desk_inkwell.gd moved the baked copy to the same place).
cyl("Inkwell", (-0.32, 0.775, -0.20), 0.026, 0.045, "iron", sides=10, radius_top=0.022)
cyl("InkwellCap", (-0.32, 0.800, -0.20), 0.017, 0.012, "brass", sides=8)
cyl("InkwellCollar", (-0.32, 0.792, -0.20), 0.027, 0.008, "brass", sides=10)
box("WireLeadBlock", (-0.62, 0.765, 0.30), (0.08, 0.03, 0.06), "dark_wood", 0.002)
cyl("WireLeadBush", (-0.62, 0.782, 0.30), 0.012, 0.02, "brass", sides=8)

desk = bake("desk_static")
desk_stats = export(desk, "desk_static.glb")

# =========================================================================
# 2. Record bookcase (prop-local; sides x = +-0.4, back at z = -0.15)
# =========================================================================
begin()

box("BookcasePlinth", (0.0, 0.04, 0.0), (0.84, 0.08, 0.32), "dark_wood", 0.003)
box("BookcasePlinthBead", (0.0, 0.085, 0.0), (0.86, 0.02, 0.34), "mid_wood", 0.002)
for sx in (-0.4, 0.4):
    box("BookcaseSide", (sx, 0.79, 0.0), (0.04, 1.5, 0.32), "dark_wood", 0.003)
    box("BookcasePilaster", (sx * 1.03, 0.79, 0.10), (0.018, 1.34, 0.10), "mid_wood", 0.002)
    for py in (0.20, 0.58, 0.96, 1.34):
        box("BookcasePilasterBead", (sx * 1.03, py, 0.10), (0.026, 0.03, 0.11), "dark_wood")
box("BookcaseTopBoard", (0.0, 1.53, 0.0), (0.88, 0.04, 0.34), "mid_wood", 0.003)
box("BookcaseCornice", (0.0, 1.57, 0.0), (0.92, 0.04, 0.36), "dark_wood", 0.003)
box("BookcaseCorniceCap", (0.0, 1.598, 0.0), (0.86, 0.02, 0.33), "mid_wood", 0.002)
box("BookcaseBack", (0.0, 0.79, -0.15), (0.8, 1.45, 0.02), "dark_wood", 0.001)
for bx in (-0.2, 0.0, 0.2):
    box("BookcaseBackSeam", (bx, 0.79, -0.162), (0.006, 1.43, 0.004), "mid_wood")
for sy in (0.45, 0.85, 1.20):
    box("BookcaseShelf", (0.0, sy, 0.0), (0.76, 0.03, 0.30), "mid_wood", 0.002)
    box("BookcaseShelfFace", (0.0, sy - 0.018, 0.148), (0.76, 0.012, 0.012), "dark_wood")

# Contents: deterministic rows of spines with a spine label band, paper
# folios and one record box. Books stand on the shelf boards, not through them.
rng_case = random.Random(1894)


def spine(name, x, shelf_y, width, height, kind, lean):
    """A standing book: body plus a recessed label band on its spine."""
    box(name, (x + width / 2.0, shelf_y + height / 2.0, 0.02), (width, height, 0.19), kind, 0.0015, rot_deg=(0, 0, lean))
    band_y = shelf_y + height * 0.68
    box(name + "Band", (x + width / 2.0, band_y, 0.117), (width * 0.72, 0.028, 0.004), "paper", 0.0, rot_deg=(0, 0, lean))
    box(name + "BandLow", (x + width / 2.0, band_y - 0.045, 0.117), (width * 0.72, 0.012, 0.004), "brass", 0.0, rot_deg=(0, 0, lean))


# Compartment base -> (x to fill to, book height range). Four compartments,
# every book top clears the shelf board above it (top board underside 1.51).
shelf_specs = ((0.080, 0.06, 0.20, 0.30), (0.465, 0.30, 0.19, 0.245), (0.865, 0.30, 0.17, 0.225), (1.215, 0.30, 0.18, 0.245))
for shelf_y, fill_to, height_lo, height_hi in shelf_specs:
    x = 0.02 if shelf_y < 0.1 else -0.34
    while x < fill_to:
        width = round(rng_case.uniform(0.030, 0.056), 3)
        height = round(rng_case.uniform(height_lo, height_hi), 3)
        lean = rng_case.choice((0.0, 0.0, 0.0, 0.0, 2.5, -3.0))
        kind = rng_case.choice(("leather", "leather", "dark_wood", "mid_wood"))
        spine("BookVolume", x, shelf_y, width, height, kind, lean)
        x += width + rng_case.uniform(0.001, 0.004)

# Record box on the bottom shelf, and a flat stack of ledgers on shelf two.
box("RecordBox", (-0.16, 0.215, 0.02), (0.35, 0.20, 0.25), "dark_wood", 0.002)
box("RecordBoxLabel", (-0.16, 0.215, 0.147), (0.10, 0.05, 0.004), "paper")
box("RecordBoxBead", (-0.16, 0.215, 0.1455), (0.30, 0.16, 0.002), "mid_wood")
for index, (cx, cy) in enumerate(((0.20, 0.492), (0.19, 0.530), (0.21, 0.568))):
    box("LedgerFlat%d" % index, (cx, cy, 0.02), (0.24, 0.036, 0.20), "paper" if index % 2 else "leather", 0.001, rot_deg=(0, 0, 3 if index == 1 else -2))

bookcase = bake("bookcase_static")
bookcase_stats = export(bookcase, "bookcase_static.glb")

# =========================================================================
# 3. Pigeonhole filing cabinet (prop-local; body 0.9 x 1.7 x 0.4)
# =========================================================================
begin()

box("CabinetBody", (0.0, 0.85, 0.0), (0.9, 1.7, 0.4), "dark_wood", 0.004)
box("CabinetPlinth", (0.0, 0.05, 0.02), (0.94, 0.10, 0.44), "dark_wood", 0.003)
box("CabinetPlinthBead", (0.0, 0.105, 0.02), (0.96, 0.02, 0.46), "mid_wood", 0.002)
box("CabinetCrown", (0.0, 1.73, 0.0), (0.98, 0.08, 0.46), "dark_wood", 0.003)
box("CabinetCrownCap", (0.0, 1.775, 0.0), (0.94, 0.03, 0.42), "mid_wood", 0.002)
for dx in (-0.42, 0.42):
    box("CabinetStile", (dx, 0.90, 0.205), (0.06, 1.56, 0.02), "mid_wood", 0.002)
box("CabinetRailTop", (0.0, 1.62, 0.205), (0.84, 0.06, 0.02), "mid_wood", 0.002)
box("CabinetRailMid", (0.0, 1.08, 0.205), (0.84, 0.05, 0.02), "mid_wood", 0.002)

# Two framed doors with raised panels and brass knobs.
for side in (-1, 1):
    door_x = 0.21 * side
    box("CabinetDoor", (door_x, 0.52, 0.215), (0.40, 0.84, 0.03), "mid_wood", 0.003)
    box("CabinetDoorPanel", (door_x, 0.52, 0.232), (0.30, 0.66, 0.012), "dark_wood", 0.003)
    box("CabinetDoorBead", (door_x, 0.52, 0.239), (0.24, 0.58, 0.006), "mid_wood")
    box("CabinetDoorStileL", (door_x - 0.185 * side, 0.52, 0.222), (0.04, 0.84, 0.024), "dark_wood")
    box("CabinetDoorStileR", (door_x + 0.185 * side, 0.52, 0.222), (0.04, 0.84, 0.024), "dark_wood")
    cyl("CabinetKnob", (0.04 * side, 0.54, 0.245), 0.020, 0.030, "brass", axis=(0, 0, 1), sides=8, radius_top=0.014)
    box("CabinetEscutcheon", (0.04 * side, 0.47, 0.238), (0.02, 0.05, 0.008), "brass")

# Record shelf and the pigeonhole grid above it.
box("RecordShelf", (0.0, 1.05, 0.23), (0.84, 0.04, 0.06), "mid_wood", 0.002)
box("RecordShelfLip", (0.0, 1.075, 0.26), (0.84, 0.012, 0.012), "dark_wood")
box("UpperRecordsBack", (0.0, 1.35, 0.21), (0.80, 0.52, 0.03), "dark_wood", 0.002)
box("PigeonholeTop", (0.0, 1.605, 0.235), (0.82, 0.03, 0.10), "mid_wood", 0.002)
box("PigeonholeBottom", (0.0, 1.095, 0.235), (0.82, 0.03, 0.10), "mid_wood", 0.002)
box("PigeonholeShelf", (0.0, 1.35, 0.235), (0.80, 0.02, 0.10), "mid_wood", 0.002)
for dx in (-0.27, 0.0, 0.27):
    box("PigeonholeDivider", (dx, 1.35, 0.235), (0.02, 0.52, 0.10), "dark_wood", 0.002)
for dx in (-0.27, 0.0, 0.27):
    box("PigeonholeLabel", (dx + 0.135 if dx < 0.26 else dx, 1.10, 0.289), (0.10, 0.035, 0.004), "paper")
box("PaperFolio1", (-0.135, 1.25, 0.23), (0.20, 0.15, 0.04), "paper", 0.001, rot_deg=(0, 0, 4))
box("PaperFolio2", (0.135, 1.40, 0.23), (0.20, 0.18, 0.04), "paper", 0.001, rot_deg=(0, 0, -6))
box("PaperFolio3", (-0.135, 1.44, 0.23), (0.18, 0.10, 0.03), "paper", 0.001, rot_deg=(0, 0, -3))
box("PaperFolio4", (0.135, 1.22, 0.23), (0.16, 0.08, 0.03), "paper", 0.001, rot_deg=(0, 0, 7))

cabinet = bake("cabinet_static")
cabinet_stats = export(cabinet, "cabinet_static.glb")

# --- save the editable source and the manifest -----------------------------
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "dead_wire_office_furniture_v1.blend"), copy=True)

report = {
    "desk_static": desk_stats,
    "bookcase_static": bookcase_stats,
    "cabinet_static": cabinet_stats,
}
(OUT / "build_manifest.json").write_text(
    json.dumps(
        {
            "authoring": "Blender 5.2 bpy; deterministic 1894 office furniture (desk, record bookcase, pigeonhole cabinet)",
            "units": "metres",
            "atlas": "res://assets/textures/office_furniture_v1/furniture_atlas_256.png",
            "assemblies": report,
            "total_triangles": sum(item["triangles"] for item in report.values()),
        },
        indent=2,
    ),
    encoding="utf-8",
)
print(json.dumps(report, indent=2))
