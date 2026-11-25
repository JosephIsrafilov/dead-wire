"""Authored PSX props for the M1 office: the operator's oil lamp, his chair,
and the regulator clock on the wall.

Same pipeline as the desk/bookcase/cabinet and the potbelly stove:

    blender -b -P tools/build_office_props_blender.py

Writes, all in Godot metres:
    assets/models/office_props_v1/{oil_lamp,chair,clock,lamp_glass}_static.glb
    assets/textures/office_props_v1/props_atlas_256.png
    assets/models/office_props_v1/build_manifest.json
    docs/art/state_2026-10-20/props/sources/*.blend

Style rules held here on purpose:
  * every surface is flat-shaded facets, no subdivision, no smooth normals;
  * the palette is the room's own muted 1894 palette, quantised to 8 steps so
    the nearest-filtered atlas never shows a gradient;
  * round things are 8..14 sided, never 32: a lamp shade in this room is a
    polygon, not a cylinder.

Prop-local space matches Godot (+Y up, origin on the prop's own floor) and the
GLB is exported with export_yup, so an instance of the prop scene lands exactly
where the blockout was.
"""
import json
import math
import random
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from office_blender_look import bake_vertex_ao, scanned_materials
OUT = ROOT / "assets/models/office_props_v1"
ONLY_MESHES = set(sys.argv[sys.argv.index("--only") + 1:]) if "--only" in sys.argv else set()
OUT.mkdir(parents=True, exist_ok=True)
TEX = ROOT / "assets/textures/office_props_v1"
TEX.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "docs/art/state_2026-10-20/props/sources"
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("", encoding="utf-8")

COLLECTION = "DW_OfficeProps_v1"
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
    "brass": (2, 0),
    "iron": (3, 0),
    "paper": (0, 1),
    "enamel": (1, 1),
    "leather": (2, 1),
    "glass": (3, 1),
    "slate": (0, 2),
    "baize": (1, 2),
    "worn_wood": (2, 2),
    "stained_wood": (3, 2),
    "rust": (0, 3),
    "knot_wood": (1, 3),
    "wool": (2, 3),
    "dust": (3, 3),
    "soot_glass": (3, 1),
}
COLORS = {
    "dark_wood": (54, 40, 28),
    "mid_wood": (96, 68, 46),
    # Brass and paper sit within 20 cm of the desk lamp's 2.6-energy source, so
    # a mid-tone brass clips to flat white and the fount stops reading as metal
    # at all. These values are pre-darkened for that light, not for a neutral
    # studio: the lamp then brings them back up to brass instead of past it.
    "brass": (104, 78, 40),
    "iron": (46, 44, 42),
    "paper": (118, 102, 74),
    "enamel": (150, 142, 122),
    "leather": (72, 44, 34),
    "glass": (150, 146, 132),
    "slate": (34, 52, 44),
    "baize": (32, 58, 42),
    # Wear palette. Not a different style: the same wood and iron, only older.
    # worn_wood is the grey-brown bare wood that shows where paint and finish
    # have gone; stained_wood is what soaks in at the bottom of a wall and the
    # foot of a door; rust is the streak iron leaves when it gets wet.
    "worn_wood": (112, 96, 74),
    "stained_wood": (36, 28, 20),
    "rust": (86, 48, 26),
    "knot_wood": (70, 50, 34),
    # Cloth and dust. A depot coat is dark greasy wool; dust is what the years
    # leave on the top edge of anything that stands still. The wool is not
    # near-black: at 46 the coat was a silhouette and none of its own wear
    # could be seen, so the form carries at 64 and the shadow does the rest.
    "wool": (64, 60, 54),
    "dust": (104, 96, 80),
}

materials = scanned_materials(TEX / "props_atlas_256.png", TILES, "dw_props_")


def pos(v):
    """Godot prop-local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


CURRENT = []


# One atlas tile repeated every ~0.35 m: below that the grain smears into flat
# paint on a 0.45 m chair seat, above it the tiling reads as wallpaper.
UV_PERIOD = 0.35


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


def tube(name, centre, radius, depth, kind, axis=(0, 1, 0), sides=10, radius_top=None):
    """Open-ended cone segment: a lamp chimney is glass, so it has no caps."""
    loc = pos(centre)
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=sides, radius=radius, depth=depth, location=loc, end_fill_type="NOTHING"
        )
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=sides,
            radius1=radius,
            radius2=radius_top,
            depth=depth,
            location=loc,
            end_fill_type="NOTHING",
        )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(pos(axis).normalized())
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, kind)


def ring(name, centre, radius, segment, depth, kind, segments=12):
    """A faceted ring in the YZ plane (the clock's round bezel)."""
    for i in range(segments):
        theta = math.tau * (i + 0.5) / segments
        cy = centre[1] + math.cos(theta) * radius
        cz = centre[2] + math.sin(theta) * radius
        length = math.tau * radius / segments * 1.12
        box(
            "%s%d" % (name, i),
            (centre[0], cy, cz),
            (depth, length, segment),
            kind,
            0.0,
            rot_deg=(math.degrees(theta) + 90.0, 0.0, 0.0),
        )


def loft(name, centre_x, sections, kind, uv_repeat=None, jitter=0.0):
    """A stack of flat-shaded quads closed into one solid: a body that is NOT a
    surface of revolution.

    Each section is (y, half_width_x, half_depth_z, centre_z, offsets).
    Vertices are placed on a rounded-rectangle outline rather than a circle, so
    a coat can be wide and thin — 0.37 across and 0.17 deep — which a cylinder
    cannot express. Every ring has the same vertex count, so the quads stitch
    without a triangulated mess, and the caps close the top and bottom.

    jitter pushes alternate vertices in and out by that fraction of the section
    radius, which is what gives cloth its broken silhouette instead of the
    lathe-turned smoothness that made the old coat read as a totem.
    """
    segments = len(sections[0][4])
    rings = []
    for index, (y, hw, hd, cz, offsets) in enumerate(sections):
        ring_verts = []
        for i in range(segments):
            nx, nz = offsets[i]
            wobble = 1.0
            if jitter > 0.0 and index not in (0, len(sections) - 1):
                wobble += jitter * (1.0 if (i + index) % 2 == 0 else -1.0)
            ring_verts.append((centre_x + nx * hw * wobble, y, cz + nz * hd * wobble))
        rings.append(ring_verts)

    verts = []
    faces = []
    for ring_verts in rings:
        for v in ring_verts:
            verts.append(v)
    for r in range(len(rings) - 1):
        base = r * segments
        nxt = (r + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base + i, base + j, nxt + j, nxt + i))
    # Caps: a fan around the whole bottom ring and the whole top ring.
    faces.append(tuple(range(segments - 1, -1, -1)))
    last = (len(rings) - 1) * segments
    faces.append(tuple(last + i for i in range(segments)))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([pos(v) for v in verts], [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj = finish(obj, kind, uv_repeat)
    # finish() only has the atlas offset for a UV layer it found empty, so the
    # loft's own projection is written here: front-facing surfaces read the
    # wool tile across the chest, and the tiling period matches every other
    # prop in the room.
    period = float(uv_repeat if uv_repeat else 3.0) / max(UV_PERIOD, 0.01)
    tx, ty = TILES[kind]
    for poly in obj.data.polygons:
        for loop_index in poly.loop_indices:
            v = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            u = (abs(v.x) * period) % 1.000001
            w = (abs(v.z) * period) % 1.000001
            obj.data.uv_layers.active.data[loop_index].uv = (
                (tx * 64 + 2 + u * 60) / 256,
                (ty * 64 + 2 + w * 60) / 256,
            )
    return obj


def cloth_outline(segments=12):
    """Unit rounded-rectangle outline: (nx, nz) pairs where |nx|,|nz| <= 1.

    A superellipse with exponent 3 keeps the corners of a folded coat and the
    flat of its chest, instead of the constant curvature of a circle.
    """
    points = []
    for i in range(segments):
        theta = math.tau * (i + 0.5) / segments
        c = math.cos(theta)
        s = math.sin(theta)
        nx = math.copysign(abs(c) ** (2.0 / 3.0), c)
        nz = math.copysign(abs(s) ** (2.0 / 3.0), s)
        points.append((nx, nz))
    return points


def round_outline(segments=12):
    """Unit circle outline, for the things in this room that really are round.

    A hat brim is a circle; a coat is not. The loft takes whichever outline its
    object needs, so the coat gets corners and the hat does not. Using the cloth
    outline for the hat is what made it read as a box with a lid on it.
    """
    points = []
    for i in range(segments):
        theta = math.tau * (i + 0.5) / segments
        points.append((math.cos(theta), math.sin(theta)))
    return points


def begin():
    CURRENT.clear()


def bake(name):
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
    bake_vertex_ao(obj)
    return obj


def export(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if not ONLY_MESHES or obj.name in ONLY_MESHES:
        bpy.ops.export_scene.gltf(
            filepath=str(OUT / filename),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_texcoords=True,
            export_normals=True, export_vertex_color="ACTIVE",
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
# 1. Operator's oil lamp (prop-local, base on the desk top).
#    The wick sits at y = 0.185 because the scene's Flame node and its light
#    are pinned there; everything below it is the fount, everything above is
#    glass. Total height stays at the old 0.40 m so the desk composition and
#    the WickInteractable box keep measuring the same object.
# =========================================================================
begin()

# Profile, bottom to top. One widening taper (foot), a clear stem, then the
# fount as the widest point of the whole lamp. The first pass had the foot
# wider than the belly, which rendered as a gourd with two lobes; a lamp reads
# as a lamp only when the reservoir is the silhouette's widest mass.
cyl("LampFootPad", (0.0, 0.006, 0.0), 0.052, 0.012, "brass", sides=12)
cyl("LampFootStep", (0.0, 0.018, 0.0), 0.048, 0.012, "brass", sides=12, radius_top=0.040)
cyl("LampStem", (0.0, 0.038, 0.0), 0.016, 0.028, "iron", sides=10)
cyl("LampStemCollar", (0.0, 0.056, 0.0), 0.022, 0.008, "brass", sides=10)

# Fount: the reservoir, widest at the belly, tapering up to the burner gallery.
cyl("LampFountLower", (0.0, 0.074, 0.0), 0.030, 0.028, "brass", sides=12, radius_top=0.058)
cyl("LampFountBelly", (0.0, 0.099, 0.0), 0.058, 0.022, "brass", sides=12)
cyl("LampFountUpper", (0.0, 0.121, 0.0), 0.058, 0.022, "brass", sides=12, radius_top=0.040)
cyl("LampFountNeck", (0.0, 0.137, 0.0), 0.040, 0.010, "brass", sides=12, radius_top=0.030)

# Burner gallery: the crown ring the chimney seats on. The whole assembly tops
# out at 0.168 m, below the flame at 0.185 m, so the wick is visible inside the
# glass instead of hidden behind a collar.
cyl("LampGalleryCrown", (0.0, 0.147, 0.0), 0.032, 0.010, "brass", sides=12, radius_top=0.028)
cyl("LampBurnerCollar", (0.0, 0.156, 0.0), 0.027, 0.008, "iron", sides=10)
cyl("LampWickRing", (0.0, 0.164, 0.0), 0.022, 0.008, "brass", sides=10)

# Wick adjuster on the operator's side (+X): a small knurled wheel tucked into
# the fount's waist, where a thumb would actually reach.
cyl("LampWickShaft", (0.050, 0.099, 0.0), 0.005, 0.018, "iron", axis=(1, 0, 0), sides=6)
cyl("LampWickWheel", (0.060, 0.099, 0.0), 0.010, 0.006, "brass", axis=(1, 0, 0), sides=8)
ring("LampCarryRing", (-0.054, 0.083, 0.0), .034, .006, .008, "brass", segments=14)
box("LampRingAnchor", (-0.049, 0.110, 0.0), (.024, .014, .018), "iron", .001)
for i in range(12):
    angle = math.tau * i / 12
    box("BurnerCrownTooth", (.028 * math.cos(angle), .153, .028 * math.sin(angle)),
        (.008, .010, .008), "brass", .001)

# A small brass plate riveted to the fount: the maker's mark, as a raised facet.
box("LampMakerPlate", (0.0, 0.099, -0.058), (0.028, 0.014, 0.004), "brass", 0.001)

lamp = bake("oil_lamp_static")
lamp_stats = export(lamp, "oil_lamp_static.glb")

# --- the glass chimney, exported apart so Godot can give it a real alpha ---
# A hurricaine chimney is a vase: it flares over the burner, swells, then
# narrows to the draught lip. Five faceted bands keep the silhouette polygonal.
begin()
tube("ChimneyFlare", (0.0, 0.192, 0.0), 0.022, 0.018, "glass", sides=10, radius_top=0.034)
tube("ChimneyBellyLow", (0.0, 0.222, 0.0), 0.034, 0.042, "glass", sides=10)
tube("ChimneyBelly", (0.0, 0.264, 0.0), 0.035, 0.042, "glass", sides=10)
tube("ChimneyShoulder", (0.0, 0.305, 0.0), 0.035, 0.040, "glass", sides=10, radius_top=0.026)
tube("ChimneyUpper", (0.0, 0.338, 0.0), 0.026, 0.026, "glass", sides=10)
tube("ChimneySootLip", (0.0, 0.359, 0.0), 0.026, 0.016, "soot_glass", sides=10)
lamp_glass = bake("lamp_glass_static")
glass_stats = export(lamp_glass, "lamp_glass_static.glb")

# =========================================================================
# 2. Operator's chair (prop-local, feet on the floor).
#    Seat top stays at 0.455 m and the back tops out at 0.90 m, so the
#    OperatorSeat anchors and the ChairSolid collision keep their contract.
# =========================================================================
begin()

# Turned legs: tapered octagonal shafts with a foot bead and a seat collar.
for sx in (-0.185, 0.185):
    for sz in (-0.175, 0.175):
        cyl("ChairLeg", (sx, 0.215, sz), 0.021, 0.43, "dark_wood", sides=8, radius_top=0.016)
        cyl("ChairFootBead", (sx, 0.022, sz), 0.024, 0.030, "dark_wood", sides=8)
        cyl("ChairSeatCollar", (sx, 0.408, sz), 0.026, 0.024, "dark_wood", sides=8)

# Stretchers between the legs, low enough to be kicked by a boot.
box("ChairStretcherFront", (0.0, 0.145, 0.175), (0.35, 0.018, 0.018), "dark_wood")
box("ChairStretcherBack", (0.0, 0.175, -0.175), (0.35, 0.018, 0.018), "dark_wood")
for sx in (-0.185, 0.185):
    box("ChairStretcherSide", (sx, 0.16, 0.0), (0.018, 0.018, 0.35), "dark_wood")

# Saddle seat: the rim tops out at the unchanged 0.455 m seat datum.
seat_vertices, seat_faces = [], []
seat_steps = 16
for radius, height in ((1.0, .414), (1.0, .455), (.78, .453), (.33, .438)):
    for i in range(seat_steps):
        a = math.tau * i / seat_steps
        seat_vertices.append(pos((.226 * radius * math.cos(a), height, .215 * radius * math.sin(a))))
for row in range(3):
    for i in range(seat_steps):
        j = (i + 1) % seat_steps
        seat_faces.append((row * seat_steps + i, row * seat_steps + j,
                           (row + 1) * seat_steps + j, (row + 1) * seat_steps + i))
seat_faces.append(tuple(range(3 * seat_steps, 4 * seat_steps)))
seat_mesh = bpy.data.meshes.new("SaddleSeat")
seat_mesh.from_pydata(seat_vertices, [], [tuple(reversed(face)) for face in seat_faces])
seat_mesh.update()
seat_uv = seat_mesh.uv_layers.new()
for loop in seat_mesh.loops:
    vertex = seat_vertices[loop.vertex_index]
    seat_uv.data[loop.index].uv = (.5 + vertex.y / .46, .5 + vertex.x / .49)
seat = bpy.data.objects.new("SaddleSeat", seat_mesh)
coll.objects.link(seat)
finish(seat, "mid_wood", 1.0)

box("ChairFrontApron", (0.0, 0.395, 0.174), (0.38, 0.05, 0.016), "dark_wood", 0.003)
box("ChairBackApron", (0.0, 0.395, -0.174), (0.38, 0.05, 0.016), "dark_wood", 0.003)
for sx in (-0.174, 0.174):
    box("ChairSideApron", (sx, 0.395, 0), (0.016, 0.05, 0.34), "dark_wood", 0.003)

# Continuous horseshoe arm rail, rising to the crest at the back.
rail_steps = 18
section_steps = 8
rail_vertices, rail_faces = [], []
for i in range(rail_steps + 1):
    u = i / rail_steps
    a = math.pi * (1.22 * u - .11)
    y = .673 + .205 * math.sin(math.pi * u) ** 2
    x, z = .207 * math.cos(a), .045 - .229 * math.sin(a)
    for j in range(section_steps):
        b = math.tau * j / section_steps
        rail_vertices.append(pos((x + .023 * math.cos(a) * math.cos(b), y + .022 * math.sin(b),
                                  z - .023 * math.sin(a) * math.cos(b))))
    if 0 < i < rail_steps and i % 2:
        h = y - .448
        cyl("TurnedArmSpindle", (x, .448 + h / 2, z), .012, h, "dark_wood", sides=8, radius_top=.010)
        cyl("SpindleCollar", (x, .481, z), .017, .021, "mid_wood", sides=8, radius_top=.013)
        cyl("SpindleBead", (x, y - .059, z), .015, .020, "mid_wood", sides=8, radius_top=.012)
for i in range(rail_steps):
    for j in range(section_steps):
        k = (j + 1) % section_steps
        rail_faces.append((i * section_steps + j, (i + 1) * section_steps + j,
                           (i + 1) * section_steps + k, i * section_steps + k))
rail_faces.extend((tuple(reversed(range(section_steps))),
                   tuple(range(rail_steps * section_steps, (rail_steps + 1) * section_steps))))
rail_mesh = bpy.data.meshes.new("ContinuousArm")
rail_mesh.from_pydata(rail_vertices, [], rail_faces)
rail_mesh.update()
rail_uv = rail_mesh.uv_layers.new()
for loop in rail_mesh.loops:
    rail_uv.data[loop.index].uv = ((loop.vertex_index % section_steps) / section_steps,
                                   (loop.vertex_index // section_steps) / rail_steps)
rail = bpy.data.objects.new("ContinuousArm", rail_mesh)
coll.objects.link(rail)
finish(rail, "mid_wood", 1.0)

chair = bake("chair_static")
chair_stats = export(chair, "chair_static.glb")

# =========================================================================
# 3. Regulator clock (prop-local around the dial centre; +X faces the room).
#    The dial plate, its twelve markers, the hands and the pendulum stay as
#    scene nodes: they are driven by StationClock. This mesh is the case.
#    The trunk is open at the back — a wall clock hangs against the wall, and
#    the wall is what closes it — so the bob swings in a real opening instead
#    of behind a board.
# =========================================================================
begin()

# Case: a back panel flush to the wall, deep stiles and rails that the dial
# recesses into. A wall regulator case is about 11 cm deep; the dial plate sits
# inside the bezel with the hands just proud of it. The origin sits on the wall
# plane (local x = 0) so the instance hangs at the wall's inner face and the
# dial lands at local x = 0.10 — exactly where the scene's dial plate is.
box("ClockBackPanel", (0.007, 0.0, 0.0), (0.014, 0.40, 0.40), "dark_wood")
for sz in (-0.203, 0.203):
    box("ClockCaseStile", (0.056, 0.0, sz), (0.098, 0.44, 0.034), "dark_wood", 0.002)
for sy in (-0.203, 0.203):
    box("ClockCaseRail", (0.056, sy, 0.0), (0.098, 0.034, 0.44), "dark_wood", 0.002)

# Dial recess: a shallow cone behind the dial plate, so the paper sits in a well.
cyl("ClockDialWell", (0.034, 0.0, 0.0), 0.176, 0.046, "dark_wood", axis=(1, 0, 0), sides=14, radius_top=0.168)
# Faceted brass bezel around the dial, proud of the paper by 1 cm so the hands
# (which the scene keeps at x = -2.786) clear its front face.
ring("ClockBezelFacet", (0.100, 0.0, 0.0), 0.176, 0.026, 0.022, "brass", segments=14)
# Inner lip the glass would sit on.
ring("ClockBezelLip", (0.093, 0.0, 0.0), 0.163, 0.008, 0.016, "brass", segments=14)

# Cornice: two stepped boards, the top one wider than the case.
box("ClockCornice", (0.057, 0.228, 0.0), (0.110, 0.030, 0.470), "dark_wood", 0.003)
box("ClockCorniceCap", (0.055, 0.252, 0.0), (0.100, 0.020, 0.440), "mid_wood", 0.002)
box("ClockBaseMould", (0.057, -0.228, 0.0), (0.110, 0.030, 0.462), "dark_wood", 0.003)
box("ClockBaseCap", (0.055, -0.250, 0.0), (0.098, 0.018, 0.430), "mid_wood", 0.002)

# Pendulum trunk: an open frame deep enough to hold the bob and its glass, so
# both read through a real opening instead of in front of a board. Local
# x 0.010..0.110 puts the frame between the wall plane and the bezel's depth.
for sz in (-0.094, 0.094):
    box("ClockTrunkStile", (0.060, -0.345, sz), (0.100, 0.240, 0.022), "dark_wood", 0.002)
box("ClockTrunkRailTop", (0.060, -0.228, 0.0), (0.100, 0.020, 0.210), "dark_wood", 0.002)
box("ClockTrunkRailBottom", (0.060, -0.462, 0.0), (0.100, 0.022, 0.224), "dark_wood", 0.002)
ring("ClockCaseMoulding", (0.074, 0.0, 0.0), .222, .025, .040, "mid_wood", segments=16)
ring("ClockTrunkSightBead", (0.105, -.345, 0), .085, .009, .012, "mid_wood", segments=14)

# A small brass finial on the cornice and the winding plate on the dial well.
cyl("ClockFinial", (0.055, 0.274, 0.0), 0.018, 0.026, "brass", sides=8, radius_top=0.012)
box("ClockWindingPlate", (0.051, -0.150, 0.0), (0.006, 0.030, 0.030), "brass", 0.001)

clock = bake("clock_static")
clock_stats = export(clock, "clock_static.glb")

# =========================================================================
# 4. Train-order board (prop-local, origin at the board's centre; the scene's
#    RoutingBoard node owns it, and the lever, needle, dial and labels stay
#    live scene nodes driven by routing_board.gd). This mesh is the slate, its
#    wooden frame and the mounting hardware.
# =========================================================================
begin()

# Slate: the same footprint the CSG board used (0.72 x 1.12 x 0.075), so the
# BoardSolid collision and both interaction boxes keep their sizes.
box("BoardSlate", (0.0, 0.72, 0.0), (0.72, 1.12, 0.075), "slate", 0.002)

# Frame: four boards with a chamfered outer edge and a moulded inner lip.
box("BoardFrameTop", (0.0, 1.34, 0.0), (0.86, 0.12, 0.14), "dark_wood", 0.004)
box("BoardFrameBottom", (0.0, 0.10, 0.0), (0.86, 0.12, 0.14), "dark_wood", 0.004)
for sx in (-0.42, 0.42):
    box("BoardFrameSide", (sx, 0.72, 0.0), (0.12, 1.32, 0.14), "dark_wood", 0.004)
    # Corner blocks: a real frame is pinned, not butted.
    for sy in (1.34, 0.10):
        box("BoardCornerBlock", (sx, sy, -0.036), (0.10, 0.10, 0.016), "mid_wood", 0.002)
# Inner lip, proud of the slate so the writing surface sits in a well.
box("BoardFrameLipTop", (0.0, 1.268, -0.020), (0.74, 0.024, 0.040), "mid_wood", 0.002)
box("BoardFrameLipBottom", (0.0, 0.172, -0.020), (0.74, 0.024, 0.040), "mid_wood", 0.002)
for sx in (-0.348, 0.348):
    box("BoardFrameLipSide", (sx, 0.72, -0.020), (0.024, 1.12, 0.040), "mid_wood", 0.002)

# Header board: the printed card sits in a shallow rebate under four strips.
box("BoardHeaderRebate", (0.0, 1.12, -0.040), (0.58, 0.27, 0.014), "dark_wood", 0.002)
box("BoardHeaderStripTop", (0.0, 1.245, -0.050), (0.58, 0.025, 0.014), "mid_wood", 0.001)
box("BoardHeaderStripBottom", (0.0, 0.995, -0.050), (0.58, 0.025, 0.014), "mid_wood", 0.001)
for sx in (-0.285, 0.285):
    box("BoardHeaderStripSide", (sx, 1.12, -0.050), (0.025, 0.27, 0.014), "mid_wood", 0.001)

# The track diagram is painted on the slate, so its lines are shallow grooves
# in the board rather than raised rails: three inked strips, 2 mm proud.
box("BoardInkMain", (-0.02, 0.86, -0.042), (0.50, 0.014, 0.004), "enamel")
box("BoardInkSiding", (-0.02, 0.62, -0.042), (0.50, 0.014, 0.004), "enamel")
box("BoardInkSwitch", (0.12, 0.74, -0.042), (0.012, 0.29, 0.004), "enamel", 0.0, rot_deg=(0, 0, 30))
cyl("BoardInkStation", (-0.24, 0.74, -0.042), 0.020, 0.004, "enamel", axis=(0, 0, 1), sides=8)
cyl("BoardInkSidingDot", (0.18, 0.62, -0.042), 0.020, 0.004, "enamel", axis=(0, 0, 1), sides=8)

# Lever hardware: the brass base the pivot stands in, and the two iron stops
# the throw lands against. The pivot, lever, grip and needle are scene nodes.
# The board's depth is local Z (local -Z faces the room), so every round fitting
# here is bored along Z, not along the board's width.
cyl("BoardLeverBase", (0.0, 0.33, -0.075), 0.045, 0.060, "brass", axis=(0, 0, 1), sides=8)
for sx in (-0.145, 0.145):
    cyl("BoardLeverStop", (sx, 0.545, -0.070), 0.012, 0.030, "iron", axis=(0, 0, 1), sides=8)
# Route indicator: the brass dial face the needle sweeps over.
cyl("BoardIndicatorDial", (0.0, 0.215, -0.045), 0.050, 0.014, "brass", axis=(0, 0, 1), sides=12)
cyl("BoardIndicatorHub", (0.0, 0.215, -0.052), 0.010, 0.010, "iron", axis=(0, 0, 1), sides=8)

# Mounting: two iron screws into the wall, with the shadow washer under each.
for sy in (1.24, 0.18):
    cyl("BoardFastener", (0.0, sy, -0.075), 0.020, 0.030, "iron", axis=(0, 0, 1), sides=8)
    cyl("BoardFastenerWasher", (0.0, sy, -0.058), 0.028, 0.008, "iron", axis=(0, 0, 1), sides=8)

board = bake("board_static")
board_stats = export(board, "board_static.glb")

# =========================================================================
# 5. North window (prop-local at the window node, +Z into the room).
#    The opening in the wall is 1.60 x 1.22 (world x -2.30..-0.70,
#    y 0.92..2.14). This mesh is casing, reveals, sash and sill; the glass
#    pane stays a scene node because the night backdrop is what it shows.
#
#    The middle of the aperture stays EMPTY on purpose: the figure stands
#    behind this glass at x = -1.5, and the observation contract needs a clear
#    column of sight. Only a bottom rail (under the coat), a top rail (over the
#    hat) and the two stiles exist — no meeting rail, no muntins.
# =========================================================================
begin()

# Jamb lining through the 12 cm wall. The sash sits INSIDE this lining, close to
# the room face: the first pass pushed the sash out to z = 0.12, which made the
# whole window read as a box bolted onto the wall instead of a hole cut in it.
#
# The lining is 40 mm thick, not 24. The wall opening is 1.60 x 1.22
# (x -2.30..-0.70, y 0.92..2.14); at 24 mm the lining's outer edge stopped at
# x -2.292 and left an 8 mm slit of open wall on each side, which showed up as a
# bright vertical line beside the window at night.
box("WindowRevealLeft", (-0.788, -0.020, 0.000), (0.040, 1.220, 0.120), "mid_wood", 0.002)
box("WindowRevealRight", (0.788, -0.020, 0.000), (0.040, 1.220, 0.120), "mid_wood", 0.002)
box("WindowRevealTop", (0.000, 0.586, 0.000), (1.616, 0.040, 0.120), "mid_wood", 0.002)
box("WindowRevealBottom", (0.000, -0.626, 0.000), (1.616, 0.040, 0.120), "mid_wood", 0.002)

# Interior casing (architrave) against the room face, with a bead line.
box("WindowCasingTop", (0.000, 0.690, 0.076), (1.880, 0.100, 0.030), "dark_wood", 0.003)
for sx in (-0.890, 0.890):
    box("WindowCasingSide", (sx, -0.020, 0.076), (0.100, 1.470, 0.030), "dark_wood", 0.003)
box("WindowCasingBeadTop", (0.000, 0.633, 0.093), (1.700, 0.016, 0.012), "mid_wood")
for sx in (-0.806, 0.806):
    box("WindowCasingBeadSide", (sx, -0.020, 0.093), (0.016, 1.300, 0.012), "mid_wood")

# Sash inside the reveal, flush with the room face: two rails and two stiles.
# The middle stays empty — the figure stands behind this glass.
box("WindowSashBottom", (0.000, -0.570, 0.038), (1.470, 0.064, 0.036), "mid_wood", 0.002)
box("WindowSashTop", (0.000, 0.542, 0.038), (1.470, 0.050, 0.036), "mid_wood", 0.002)
for sx in (-0.730, 0.730):
    box("WindowSashStile", (sx, -0.014, 0.038), (0.050, 1.180, 0.036), "mid_wood", 0.002)
box("WindowSashPull", (0.000, -0.596, 0.020), (0.070, 0.030, 0.014), "brass", 0.002)

# Sill: projects into the room far enough to read as a shelf, with a nose bead.
box("WindowSill", (0.000, -0.668, 0.140), (1.800, 0.050, 0.250), "mid_wood", 0.004)
box("WindowSillNose", (0.000, -0.688, 0.258), (1.840, 0.026, 0.022), "dark_wood", 0.002)
box("WindowApron", (0.000, -0.752, 0.076), (1.700, 0.088, 0.022), "dark_wood", 0.002)

# --- wear: this window has been painted, shrunk and repainted since the 80s ---
# A chipped bite out of the sill nose: the paint has gone and bare wood shows.
box("WindowSillChipA", (0.360, -0.690, 0.258), (0.150, 0.030, 0.024), "worn_wood", 0.0)
box("WindowSillChipB", (-0.520, -0.692, 0.256), (0.080, 0.026, 0.020), "worn_wood", 0.0)
# A worn strip along the sill where hands and forms have been laid for years.
box("WindowSillWear", (-0.180, -0.641, 0.150), (0.560, 0.006, 0.150), "worn_wood")
# Grime in the corners, where a wet cloth never reaches.
box("WindowGrimeLeft", (-0.730, -0.600, 0.058), (0.070, 0.060, 0.010), "stained_wood")
box("WindowGrimeRight", (0.690, -0.604, 0.058), (0.060, 0.050, 0.010), "stained_wood")
# Cracked reveal board: a dark split running up the jamb.
box("WindowRevealCrack", (0.778, -0.140, 0.000), (0.006, 0.300, 0.014), "stained_wood")
# Nail heads in the casing, and one that has rusted and run.
for sy in (0.560, -0.330, -0.560):
    cyl("WindowCasingNail", (0.890, sy, 0.092), 0.008, 0.010, "iron", axis=(0, 0, 1), sides=6)
cyl("WindowCasingNailRust", (0.890, -0.560, 0.090), 0.010, 0.004, "rust", axis=(0, 0, 1), sides=6)
box("WindowCasingNailRun", (0.890, -0.596, 0.094), (0.010, 0.060, 0.004), "rust")

# Exterior: a drip head over the opening and a ledge under it, so the outside
# of the window has a silhouette instead of being a hole in a wall.
box("WindowDripHead", (0.000, 0.612, -0.078), (1.760, 0.040, 0.048), "stained_wood", 0.002)
box("WindowExteriorLedge", (0.000, -0.668, -0.098), (1.720, 0.046, 0.130), "stained_wood", 0.002)

window = bake("window_static")
window_stats = export(window, "window_static.glb")

# =========================================================================
# 6. South door. Casing and jamb are static; the leaf is its own assembly
#    because it swings, and the knob is its own assembly because office_door.gd
#    rattles it. Leaf-local origin is the hinge line: x 0..0.90, y -1.05..1.05.
# =========================================================================
begin()

box("DoorJambLeft", (-0.445, 0.000, 0.000), (0.030, 2.150, 0.120), "mid_wood", 0.002)
box("DoorJambRight", (0.445, 0.000, 0.000), (0.030, 2.150, 0.120), "mid_wood", 0.002)
box("DoorJambTop", (0.000, 1.050, 0.000), (0.920, 0.030, 0.120), "mid_wood", 0.002)

# Architrave on the room side (local -Z faces the office). It stops at the
# threshold, not below the floor.
box("DoorCasingLeft", (-0.535, 0.055, -0.078), (0.090, 2.190, 0.028), "dark_wood", 0.003)
box("DoorCasingRight", (0.535, 0.055, -0.078), (0.090, 2.190, 0.028), "dark_wood", 0.003)
box("DoorCasingTop", (0.000, 1.150, -0.078), (1.160, 0.100, 0.028), "dark_wood", 0.003)
box("DoorCasingBeadLeft", (-0.452, 0.020, -0.092), (0.016, 2.120, 0.014), "mid_wood")
box("DoorCasingBeadRight", (0.452, 0.020, -0.092), (0.016, 2.120, 0.014), "mid_wood")
box("DoorCasingBeadTop", (0.000, 1.062, -0.092), (0.930, 0.016, 0.014), "mid_wood")

box("DoorThreshold", (0.000, -1.040, 0.000), (0.980, 0.022, 0.140), "dark_wood", 0.002)
# Hinge straps on the jamb side, and the strike plate on the latch side.
for sy in (0.700, -0.700):
    box("DoorHingeStrap", (-0.430, sy, -0.062), (0.070, 0.110, 0.014), "iron", 0.002)
box("DoorStrikePlate", (0.445, -0.020, -0.062), (0.026, 0.130, 0.014), "iron", 0.001)

door_casing = bake("door_casing_static")
door_casing_stats = export(door_casing, "door_casing_static.glb")

begin()

# A ledged and braced plank door, not cabinetmaking: six vertical boards with
# visible joints, two horizontal ledges and a diagonal brace on the room face,
# iron nails, a kick plate at the bottom. This is what a depot office door
# actually was — the four-panel door it replaced read as a town-house door, and
# too new for a room lit by one oil lamp.
PLANK_W = 0.148
for i in range(6):
    cx = PLANK_W * (i + 0.5)
    # Boards sit a hair proud of each other so the joints catch the lamplight.
    proud = 0.002 if i % 2 else 0.0
    box("LeafPlank", (cx, -0.004, -0.004 - proud), (PLANK_W - 0.004, 2.072, 0.046), "mid_wood", 0.002)
    box("LeafPlankJoint", (cx + PLANK_W * 0.5, -0.004, -0.030), (0.004, 2.060, 0.006), "stained_wood")

# Ledges and brace on the room face (local -Z).
for sy in (0.620, -0.620):
    box("LeafLedge", (0.450, sy, -0.038), (0.840, 0.150, 0.030), "dark_wood", 0.002)
    for nx in (0.170, 0.450, 0.730):
        cyl("LeafLedgeNail", (nx, sy, -0.056), 0.008, 0.008, "iron", axis=(0, 0, 1), sides=6)
box("LeafBrace", (0.450, 0.000, -0.038), (0.150, 1.240, 0.028), "dark_wood", 0.002, rot_deg=(0, 0, 27))
for nx, ny in ((0.240, 0.330), (0.660, -0.330)):
    cyl("LeafBraceNail", (nx, ny, -0.056), 0.008, 0.008, "iron", axis=(0, 0, 1), sides=6)

# --- wear: this door has been kicked, shouldered and slammed since 1894 -----
# Kick plate: a sheet-iron scuff guard at the bottom, dented, with rust running
# from its nails.
box("LeafKickPlate", (0.450, -0.930, -0.050), (0.760, 0.150, 0.010), "iron", 0.002)
box("LeafKickDentA", (0.300, -0.905, -0.056), (0.070, 0.030, 0.004), "stained_wood")
box("LeafKickDentB", (0.590, -0.952, -0.056), (0.050, 0.024, 0.004), "rust")
for nx in (0.140, 0.450, 0.760):
    cyl("LeafKickRivet", (nx, -0.930, -0.058), 0.010, 0.008, "brass", axis=(0, 0, 1), sides=6)
box("LeafKickRust", (0.760, -0.930, -0.057), (0.012, 0.110, 0.004), "rust")
# Grime band where boots and wet coats have darkened the boards for a century.
box("LeafGrimeLow", (0.450, -0.880, -0.029), (0.880, 0.180, 0.004), "stained_wood")
box("LeafGrimeEdgeA", (0.030, -0.520, -0.029), (0.040, 0.900, 0.004), "stained_wood")
box("LeafGrimeEdgeB", (0.870, 0.140, -0.029), (0.036, 0.700, 0.004), "stained_wood")
# A knot has fallen out of one plank near the bottom: a real hole through the
# board, with the wall's darkness behind it instead of a painted spot.
box("LeafKnotHole", (0.640, -0.470, -0.027), (0.030, 0.038, 0.006), "stained_wood")
box("LeafKnotHoleCore", (0.640, -0.470, -0.030), (0.018, 0.024, 0.004), "iron")
cyl("LeafKnotRim", (0.640, -0.470, -0.029), 0.026, 0.004, "knot_wood", axis=(0, 0, 1), sides=8, radius_top=0.030)
# A splintered bite out of the latch stile, where the door has caught on the
# strike for years, and a hairline split running up from it.
box("LeafStileChipA", (0.880, -0.640, -0.026), (0.050, 0.070, 0.010), "worn_wood")
box("LeafStileChipB", (0.884, -0.590, -0.026), (0.030, 0.040, 0.008), "worn_wood")
box("LeafSplit", (0.700, 0.860, -0.027), (0.005, 0.180, 0.005), "stained_wood")
# Wear where a hand has pushed this door open for years: the paint is gone in a
# palm-sized patch beside the latch.
box("LeafLockBacking", (0.787, -0.070, -0.033), (0.083, 0.161, 0.010), "iron", .002)

# Escutcheon and keyhole on the room face by the latch stile.
box("LeafEscutcheon", (0.800, -0.045, -0.042), (0.060, 0.150, 0.008), "iron", 0.001)
box("LeafKeyhole", (0.800, -0.070, -0.055), (0.012, 0.026, 0.006), "iron")
box("BoltBackplate", (.765, .216, -.039), (.171, .047, .021), "iron", .004)
for x in (.71, .82):
    box("BoltGuide", (x, .216, -.053), (.029, .042, .012), "iron", .003)
cyl("SlidingBolt", (.781, .221, -.065), .012, .152, "iron", axis=(1, 0, 0), sides=8)
box("BoltTurn", (.771, .244, -.073), (.014, .052, .018), "iron", .003)
for y in (-.625, .625):
    cyl("StrapHingePin", (.016, y, -.052), .015, .101, "iron", sides=8)
    box("LeafForgedStrap", (.077, y, -.057), (.145, .033, .012), "iron", .005)
    for x in (.038, .115):
        cyl("StrapRivet", (x, y, -.066), .008, .009, "iron", axis=(0, 0, 1), sides=7)

door_leaf = bake("door_leaf_static")
door_leaf_stats = export(door_leaf, "door_leaf_static.glb")

begin()
# Knob assembly, centred on its own origin so the rattle rotates it in place:
# a faceted brass ball on a short shank and a back plate.
cyl("KnobShank", (0.000, 0.000, 0.022), 0.011, 0.028, "brass", axis=(0, 0, 1), sides=8)
cyl("KnobBall", (0.000, 0.000, -0.008), 0.031, 0.040, "brass", axis=(0, 0, 1), sides=10, radius_top=0.022)
cyl("KnobPlate", (0.000, 0.000, 0.042), 0.026, 0.006, "brass", axis=(0, 0, 1), sides=10)
door_knob = bake("door_knob_static")
door_knob_stats = export(door_knob, "door_knob_static.glb")

# =========================================================================
# 7. Filing service table (prop-local, floor origin). Footprint and position
#    match what the Poly Haven table occupied (0.65 x 1.04), but the top is at
#    0.80 m instead of 0.768: CopyCommitDesk's own collision top is 0.80, so
#    the table was 3 cm short and the option plates floated above it.
# =========================================================================
begin()

# The table stands rotated 90 degrees in the room (local -X ends up facing
# north, into the office), so the drawer goes on local -X — the side a clerk
# actually walks up to — not on -Z.
box("TableTop", (0.000, 0.780, 0.000), (0.650, 0.040, 1.040), "mid_wood", 0.004)
box("TableTopMould", (0.000, 0.752, 0.000), (0.664, 0.018, 1.054), "dark_wood", 0.003)
box("TableTopSeamA", (0.000, 0.8005, -0.170), (0.640, 0.001, 0.004), "dark_wood")
box("TableTopSeamB", (0.000, 0.8005, 0.190), (0.640, 0.001, 0.004), "dark_wood")

# Rails on all four sides (a proper apron, not a skirt of separate boards),
# with the working drawer on the approach side.
box("TableApronApproach", (-0.286, 0.700, 0.000), (0.020, 0.100, 0.980), "dark_wood", 0.002)
box("TableApronFar", (0.286, 0.700, 0.000), (0.020, 0.100, 0.980), "dark_wood", 0.002)
box("TableApronSideA", (0.000, 0.700, -0.478), (0.600, 0.100, 0.020), "dark_wood", 0.002)
box("TableApronSideB", (0.000, 0.700, 0.478), (0.600, 0.100, 0.020), "dark_wood", 0.002)
box("TableDrawerFace", (-0.300, 0.700, 0.000), (0.014, 0.072, 0.360), "mid_wood", 0.002)
box("TableDrawerBead", (-0.309, 0.700, 0.000), (0.004, 0.052, 0.320), "dark_wood")
box("TableDrawerPull", (-0.316, 0.700, 0.000), (0.012, 0.012, 0.090), "brass", 0.001)
box("TableDrawerLock", (-0.309, 0.662, 0.000), (0.006, 0.018, 0.012), "brass", 0.001)

# Legs: square oak legs tapered on the two inside faces, with a foot bead and a
# shoulder block where they joint into the apron. Square, not turned — a
# working table in a depot is joinery, not cabinetmaking.
for sx in (-0.276, 0.276):
    for sz in (-0.462, 0.462):
        box("TableLeg", (sx, 0.355, sz), (0.048, 0.690, 0.048), "dark_wood", 0.002)
        box("TableLegTaperX", (sx - 0.014 if sx > 0 else sx + 0.014, 0.245, sz), (0.020, 0.470, 0.048), "dark_wood")
        box("TableLegShoulder", (sx, 0.716, sz), (0.060, 0.040, 0.060), "dark_wood", 0.002)
        box("TableFootBead", (sx, 0.016, sz), (0.058, 0.032, 0.058), "dark_wood", 0.002)

# One low H-stretcher: enough to stiffen the frame without reading as a shelf.
box("TableStretcherLong", (0.000, 0.180, 0.000), (0.520, 0.024, 0.030), "dark_wood", 0.002)
for sz in (-0.360, 0.360):
    box("TableStretcherCross", (0.000, 0.180, sz), (0.500, 0.020, 0.024), "dark_wood", 0.002)

table = bake("table_static")
table_stats = export(table, "table_static.glb")

# =========================================================================
# 8. Worn floor patch (world-space, origin at the room origin).
#    The floor itself stays the CSG box it always was — its top face is what
#    the player and the physics stand on. This sits a few millimetres above it,
#    on the traffic line between the door and the desk, and gives that line the
#    one thing a tiling texture cannot: individual boards that have lifted,
#    shrunk and split, with the nail heads standing proud of them.
#    Creak anchors are placed at the same boards in m1_office.tscn, so the
#    sound comes from where the wear is.
# =========================================================================
begin()

WORN_BOARDS = [
    # (x, z, length, lift, tilt_deg, tone)
    # Only 2 mm of lift and no tilt: these are boards of the same floor that
    # have shrunk and stood slightly proud, not timber laid on top of it. The
    # read comes from the gaps and the nails, not from a raised plank.
    (-1.02, 0.92, 1.30, 0.002, 0.0, "mid_wood"),
    (-0.88, 0.92, 1.30, 0.003, 0.0, "dark_wood"),
    (-0.74, 0.90, 1.34, 0.002, 0.0, "knot_wood"),
    (-0.40, 0.32, 1.16, 0.003, 0.0, "dark_wood"),
]
for index, (bx, bz, length, lift, tilt, tone) in enumerate(WORN_BOARDS):
    box(
        "WornBoard%d" % index,
        (bx, lift * 0.5, bz),
        (0.138, lift, length),
        tone,
        0.0,
        rot_deg=(tilt, 0, 0),
    )
    # The shrunk gap lives on one side only: a board that has pulled away from
    # its neighbour, not a board with a frame drawn round it.
    box("WornSeam%d" % index, (bx + 0.072, 0.0025, bz), (0.007, 0.005, length), "stained_wood")
    # Nails standing proud, each with the little dark bruise around it.
    for nz in (bz - length * 0.38, bz + length * 0.38):
        cyl("WornNail%d" % index, (bx, lift + 0.001, nz), 0.006, 0.003, "iron", axis=(0, 1, 0), sides=6)
        cyl("WornNailRust%d" % index, (bx, lift - 0.001, nz), 0.011, 0.002, "rust", axis=(0, 1, 0), sides=8)

# One board has lost its end: a splintered break, with the tongue of wood still
# hanging on. Laid at an angle so it reads as broken rather than cut, and in the
# floor's own tone so it does not look like a fresh offcut.
box("WornSplitTongue", (0.10, 0.004, -0.28), (0.110, 0.008, 0.150), "knot_wood", 0.0, rot_deg=(0, 0, 7))
box("WornSplitShadow", (0.10, 0.001, -0.28), (0.012, 0.003, 0.120), "stained_wood", rot_deg=(0, 0, 7))
# A knot hole worn right through the face veneer, with a grey worn rim round it.
cyl("WornKnotHole", (-0.88, 0.011, 0.55), 0.018, 0.005, "stained_wood", axis=(0, 1, 0), sides=8)
cyl("WornKnotRim", (-0.88, 0.010, 0.55), 0.025, 0.003, "worn_wood", axis=(0, 1, 0), sides=8, radius_top=0.023)

floor_wear = bake("floor_wear_static")
floor_wear_stats = export(floor_wear, "floor_wear_static.glb")

# =========================================================================
# 9. South-wall fittings (world space; OfficeStorytellingProps sits at the
#    origin, so local == world). Coat rack with the operator's coat and hat,
#    the night register frame, the service hatch, and the message tray.
#    The south wall's room face is z = 2.30; everything hangs a few mm proud.
# =========================================================================
begin()

# --- coat rack: a board, two iron hooks, and the coat actually hanging ------
# The board is narrow on purpose: at 0.50 wide it stuck out either side of the
# coat and the whole fitting read as a cross. A rack board only has to be wide
# enough to carry its hooks.
box("RackBoard", (-0.35, 2.05, 2.283), (0.300, 0.110, 0.024), "dark_wood", 0.003)
box("RackBoardBead", (-0.35, 1.992, 2.290), (0.320, 0.014, 0.014), "mid_wood")
for nx in (-0.480, -0.220):
    cyl("RackNail", (nx, 2.050, 2.296), 0.007, 0.008, "iron", axis=(0, 0, 1), sides=6)
# The hook: a shank out of the board and a curl the coat hangs from.
cyl("RackHookShank", (-0.35, 2.050, 2.240), 0.011, 0.075, "iron", axis=(0, 0, 1), sides=8)
cyl("RackHookCurl", (-0.35, 2.022, 2.212), 0.013, 0.040, "iron", axis=(0, 1, 0), sides=8, radius_top=0.008)
# A second, empty hook: a rack with one hook looks staged.
cyl("RackHookEmptyShank", (-0.180, 2.050, 2.250), 0.010, 0.060, "iron", axis=(0, 0, 1), sides=8)
cyl("RackHookEmptyCurl", (-0.180, 2.026, 2.226), 0.012, 0.032, "iron", axis=(0, 1, 0), sides=8, radius_top=0.007)

# --- THE COAT IS NOT BUILT HERE ANY MORE ------------------------------------
# The coat hangs from this hook, but it is a SIMULATED CLOTH GRID, not authored
# geometry: scripts/office/hanging_coat.gd builds the mesh, runs a Verlet
# simulation on it and drapes it from the collar. Authoring it as a static loft
# meant it could only ever be a sculpture of a coat — it could not sway when the
# operator walked past it, could not settle, and could not hang differently from
# the way it was modelled. Those are the things that make cloth read as cloth.
#
# What stays here is everything the coat hangs ON: the rack board, both hooks,
# and the hat. The coat's own dimensions (the profile table, the section outline,
# the atlas UVs) moved into hanging_coat.gd, which is now the single source of
# truth for where the coat begins and ends.
COAT_X = -0.350
COAT_Z = 2.198

# A worn felt hat, hung on the hook above the collar and slightly forward so it
# overlaps the coat instead of floating over it like a separate object.
#
# 2026-10-21: this was a flat brim disc plus a straight crown cone, and the
# crown's shadow turned the brim into a black plate — the hat read as a
# mushroom. It is now ONE loft: the brim edge sits low, the surface rises to
# the crown base, the crown runs up, and the top section is inset on one side so
# the crown is dented rather than a cone. One continuous surface means there is
# no shadow gap between brim and crown, which is what made the old version read
# as two stacked objects.
HAT_Z = 2.196
HAT_OUTLINE = round_outline(12)
# Proportions matter more than polygons here. At a 0.134 brim over an 8 cm
# crown the hat read as a bowl: a bowler's brim projects about 6 cm and its
# crown stands about 10, so the brim is pulled in to 0.116 and the crown raised
# to 9.4 cm. That ratio is what separates "hat" from "dish".
loft("Hat", COAT_X, [
    # y, half-width, half-depth, centre z, outline
    (1.990, 0.116, 0.113, HAT_Z - 0.012, HAT_OUTLINE),   # brim edge, dropped
    (2.002, 0.098, 0.096, HAT_Z - 0.005, HAT_OUTLINE),   # brim rises inward
    (2.018, 0.096, 0.094, HAT_Z, HAT_OUTLINE),           # crown base
    (2.070, 0.094, 0.092, HAT_Z - 0.002, HAT_OUTLINE),
    (2.104, 0.088, 0.087, HAT_Z - 0.004, HAT_OUTLINE),   # crown shoulder
    (2.112, 0.070, 0.072, HAT_Z - 0.009, HAT_OUTLINE),   # dented top
], "wool", uv_repeat=2.0)
# The band is a dark ribbon round the crown. It was 'leather', whose 72,44,34
# tile comes up bright orange-red in this light and read as a scarlet hatband;
# stained_wood is the same near-black brown the hems and grime use, so the band
# reads as ribbon rather than as a second material.
loft("HatBand", COAT_X, [
    (2.020, 0.097, 0.095, HAT_Z, HAT_OUTLINE),
    (2.040, 0.096, 0.094, HAT_Z, HAT_OUTLINE),
], "stained_wood", uv_repeat=1.0)

# --- night register frame (the Label3D stays the scene's own node) ----------
# A blank baize-covered notice board with one postcard on it is a placeholder.
# This is a working depot board: the register card in the middle, and the
# notices that accumulate on a board nobody clears — a timetable slip, a
# circular, a hand-written memo — each pinned with an iron tack.
box("RosterFrame", (1.620, 1.550, 2.288), (0.820, 0.720, 0.028), "dark_wood", 0.004)
box("RosterBaize", (1.620, 1.550, 2.274), (0.700, 0.600, 0.010), "baize")
box("RosterFrameBeadTop", (1.620, 1.888, 2.270), (0.760, 0.016, 0.012), "mid_wood")
box("RosterFrameBeadBottom", (1.620, 1.212, 2.270), (0.760, 0.016, 0.012), "mid_wood")
for sx in (1.232, 2.008):
    box("RosterFrameBeadSide", (sx, 1.550, 2.270), (0.016, 0.660, 0.012), "mid_wood")
for nx in (1.250, 1.990):
    cyl("RosterNail", (nx, 1.868, 2.264), 0.008, 0.008, "iron", axis=(0, 0, 1), sides=6)

# Pinned notices around the register card. They live INSIDE the baize
# (y 1.25..1.85, x 1.27..1.97). The lower pair used to sit at y ~1.37, only
# 12 cm above the bottom bead; from the desk the camera looks up at the board,
# so they read as orange patches hanging under the frame. Raised to 1.45 so
# they sit clearly inside the baize from every angle the player meets it at.
#
# 2026-10-21: the four slips were 12 x 10 cm postage stamps clustered in one
# horizontal band across the middle, which left the lower third and both side
# margins of a 70 x 60 cm baize bare. On screen the board read as a display
# case with scraps floating in it rather than a depot board nobody clears.
# They are now roughly twice the area and occupy the four quadrants around
# the register card, so the papers reach the baize edges the way pinned paper
# actually does. Every slip still clears the card and the baize border.
PINNED = [
    ("RosterNoticeTimetable", 1.420, 1.700, 0.200, 0.220, -3.0, "paper"),
    ("RosterNoticeCircular", 1.830, 1.710, 0.210, 0.190, 2.5, "paper"),
    ("RosterNoticeMemo", 1.400, 1.400, 0.190, 0.170, 4.0, "worn_wood"),
    ("RosterNoticeRule", 1.840, 1.410, 0.180, 0.200, -2.0, "paper"),
]
for name, nx, ny, w, h, tilt, kind in PINNED:
    box(name, (nx, ny, 2.258), (w, h, 0.004), kind, 0.0, rot_deg=(0, 0, tilt))
    # A tack at the top corner, and the little shadow bruise under it.
    cyl(name + "Tack", (nx - w * 0.32, ny + h * 0.38, 2.254), 0.006, 0.004, "iron", axis=(0, 0, 1), sides=6)
    box(name + "Bruise", (nx - w * 0.32, ny + h * 0.38, 2.260), (0.020, 0.020, 0.002), "stained_wood")
# An old notice torn down to a corner, still pinned: the board is never cleared.
box("RosterNoticeTorn", (1.586, 1.742, 2.259), (0.052, 0.030, 0.004), "paper", rot_deg=(0, 0, 7))
cyl("RosterNoticeTornTack", (1.566, 1.752, 2.255), 0.006, 0.004, "iron", axis=(0, 0, 1), sides=6)
# The frame is not square on the wall any more: it has been knocked.
box("RosterChip", (2.010, 1.190, 2.276), (0.040, 0.030, 0.010), "worn_wood")

# --- service hatch: a small counter window through the wall ----------------
box("HatchFrame", (2.420, 1.350, 2.288), (0.560, 0.480, 0.030), "dark_wood", 0.004)
box("HatchFrameInner", (2.420, 1.350, 2.272), (0.440, 0.360, 0.014), "stained_wood", 0.002)
box("HatchSill", (2.420, 1.120, 2.100), (0.620, 0.048, 0.380), "mid_wood", 0.003)
box("HatchSillNose", (2.420, 1.096, 2.290), (0.640, 0.026, 0.024), "dark_wood", 0.002)
box("HatchSillWear", (2.380, 1.096, 2.160), (0.320, 0.006, 0.130), "worn_wood")
# The counter has taken elbows for a century: a worn hollow in the sill.
box("HatchSillHollow", (2.330, 1.093, 2.190), (0.200, 0.004, 0.090), "stained_wood")
for nx in (2.180, 2.660):
    cyl("HatchNail", (nx, 1.560, 2.264), 0.008, 0.008, "iron", axis=(0, 0, 1), sides=6)
cyl("HatchNailRust", (2.660, 1.560, 2.262), 0.010, 0.004, "rust", axis=(0, 0, 1), sides=6)
box("HatchNailRun", (2.660, 1.500, 2.266), (0.010, 0.080, 0.004), "rust")

# --- message tray: a wall rack with two pigeonholes ------------------------
box("TrayBack", (-2.660, 0.950, -1.560), (0.020, 0.180, 0.480), "dark_wood", 0.002)
box("TrayShelf", (-2.680, 0.868, -1.560), (0.150, 0.032, 0.480), "mid_wood", 0.003)
box("TrayDivider", (-2.680, 0.950, -1.560), (0.140, 0.150, 0.012), "dark_wood", 0.002)
for sz in (-1.796, -1.324):
    box("TrayEnd", (-2.680, 0.950, sz), (0.140, 0.150, 0.012), "dark_wood", 0.002)
box("TrayLip", (-2.744, 0.960, -1.560), (0.010, 0.026, 0.470), "mid_wood")
# Two slips waiting, one cocked out of the pigeonhole the way they sit.
box("TraySlipReceived", (-2.712, 0.928, -1.680), (0.070, 0.100, 0.004), "paper", 0.001, rot_deg=(0, 0, -4))
box("TraySlipSent", (-2.706, 0.916, -1.470), (0.066, 0.084, 0.004), "paper", 0.001, rot_deg=(0, 0, 6))
box("TraySlipEdge", (-2.700, 0.880, -1.452), (0.030, 0.012, 0.070), "worn_wood")

# The hoop hangs where the operator can pick it up on the way out to the train.
box("OrderHoopHookPlate", (-.87, 1.76, 2.258), (.043, .085, .015), "iron", .004)
box("OrderHoopHook", (-.87, 1.730, 2.225), (.020, .020, .060), "iron", .005)
hoop_x, hoop_y, hoop_z, hoop_r = -.87, 1.572, 2.213, .135
for i in range(16):
    angle = math.tau * (i + .5) / 16
    box("HandBentAshHoop", (hoop_x + hoop_r * math.cos(angle),
        hoop_y + hoop_r * math.sin(angle), hoop_z), (.016, .057, .017), "worn_wood",
        .002, rot_deg=(0, 0, math.degrees(angle)))
box("OrderHoopHandle", (-.87, 1.21, 2.213), (.024, .48, .021), "mid_wood", .003)
for y in (1.432, 1.450):
    box("HoopBinding", (-.87, y, 2.213), (.027, .012, .025), "leather", .001)
box("OrderSlipInCord", (-.818, 1.51, 2.189), (.086, .102, .006), "paper",
    rot_deg=(0, 0, -13))
box("OrderSlipFold", (-.824, 1.478, 2.184), (.075, .024, .004), "enamel",
    rot_deg=(0, 0, -13))
box("OrderSlipSpringClip", (-.796, 1.546, 2.181), (.023, .025, .010), "brass",
    .001, rot_deg=(0, 0, -13))

cyl("SpittoonFoot", (2.55, .012, .93), .087, .020, "brass", sides=13)
cyl("SpittoonBowl", (2.55, .070, .93), .095, .095, "brass", sides=13, radius_top=.066)
tube("SpittoonMouth", (2.55, .137, .93), .064, .043, "brass", sides=13, radius_top=.10)
cyl("SpittoonDarkInterior", (2.55, .11, .93), .060, .004, "iron", sides=13)

box("DenverCrate", (2.62, .142, -.992), (.35, .278, .42), "worn_wood", .004)
for z in (-1.166, -.818):
    box("CrateEndCleat", (2.438, .142, z), (.024, .284, .030), "dark_wood", .002)
for y in (.102, .182):
    box("CratePlankJoint", (2.441, y, -.992), (.004, .004, .40), "dark_wood")

wall_props = bake("wall_props_static")
wall_props_stats = export(wall_props, "wall_props_static.glb")

# =========================================================================
# 10. Insulators and the wire run down the west wall.
#     The line is strung on real glass bells: a stacked skirt profile, not a
#     plain cylinder, with a wire that sits in the groove on top of each bell.
# =========================================================================
begin()

for name, base_z in (("InsulatorA", -1.700), ("InsulatorB", -0.350)):
    # Bells are stacked bottom-up: wide skirt, narrow neck, wide cap.
    cyl(name + "Skirt", (-2.820, 2.408, base_z), 0.040, 0.016, "enamel", axis=(1, 0, 0), sides=10, radius_top=0.028)
    cyl(name + "Belly", (-2.820, 2.428, base_z), 0.034, 0.024, "enamel", axis=(1, 0, 0), sides=10, radius_top=0.030)
    cyl(name + "Groove", (-2.820, 2.446, base_z), 0.024, 0.012, "enamel", axis=(1, 0, 0), sides=10)
    cyl(name + "Cap", (-2.820, 2.458, base_z), 0.030, 0.014, "enamel", axis=(1, 0, 0), sides=10, radius_top=0.018)
    # The iron pin the wire ties to, and a rust stain running down the wall.
    cyl(name + "Pin", (-2.820, 2.470, base_z), 0.008, 0.030, "iron", axis=(0, 1, 0), sides=6)
    box(name + "Rust", (-2.796, 2.360, base_z), (0.006, 0.070, 0.020), "rust")

# The two runs, with the sag a strung wire actually has: a few segments that
# dip between the pins instead of one straight bar.
WIRE_Z = (-1.700, -0.350)
for index, sy in enumerate((2.474, 2.364)):
    z_from, z_to = WIRE_Z[0], WIRE_Z[1]
    segments = 7
    for seg in range(segments):
        t0 = seg / segments
        t1 = (seg + 1) / segments
        z0 = z_from + (z_to - z_from) * t0
        z1 = z_from + (z_to - z_from) * t1
        sag0 = 0.012 * math.sin(math.pi * t0)
        sag1 = 0.012 * math.sin(math.pi * t1)
        cyl(
            "Wire%d_%d" % (index, seg),
            (-2.820, sy - (sag0 + sag1) * 0.5, (z0 + z1) * 0.5),
            0.007,
            abs(z1 - z0) + 0.008,
            "iron",
            axis=(0.02, (sag1 - sag0), (z1 - z0)),
            sides=5,
        )

wire_run = bake("wire_run_static")
wire_run_stats = export(wire_run, "wire_run_static.glb")



# --- save the editable source and the manifest -----------------------------
if "--save-source" in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "dead_wire_office_props_v1.blend"), copy=True)

report = {
    "oil_lamp_static": lamp_stats,
    "lamp_glass_static": glass_stats,
    "chair_static": chair_stats,
    "clock_static": clock_stats,
    "board_static": board_stats,
    "window_static": window_stats,
    "door_casing_static": door_casing_stats,
    "door_leaf_static": door_leaf_stats,
    "door_knob_static": door_knob_stats,
    "table_static": table_stats,
    "floor_wear_static": floor_wear_stats,
    "wall_props_static": wall_props_stats,
    "wire_run_static": wire_run_stats,
}
(OUT / "build_manifest.json").write_text(
    json.dumps(
        {
            "authoring": "Blender 5.2 bpy; deterministic PSX props (lamp + glass, chair, clock, train-order board, window, door, filing table)",
            "units": "metres",
            "atlas": "res://assets/textures/office_props_v1/props_atlas_256.png",
            "assemblies": report,
            "total_triangles": sum(item["triangles"] for item in report.values()),
        },
        indent=2,
    ),
    encoding="utf-8",
)
print(json.dumps(report, indent=2))
