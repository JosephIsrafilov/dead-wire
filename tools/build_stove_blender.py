"""Authored stylized 1894 depot potbelly stove and wall-connected flue assembly.
Run with Blender 5.x Python (`blender -b -P tools/build_stove_blender.py`).
Builds a clean static mesh (`stove_static.glb`) in Godot metres, with an authored
nearest-filtered 256px atlas (`stove_atlas_256.png`) and saves the editable
`.blend` source under `docs/art/state_2026-10-15/stove/sources/`.
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
OUT = ROOT / "assets/models/stove_v1"
OUT.mkdir(parents=True, exist_ok=True)
TEX = ROOT / "assets/textures/stove_v1"
TEX.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "docs/art/state_2026-10-15/stove/sources"
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("", encoding="utf-8")

COLLECTION = "DW_Stove_v1"
old = bpy.data.collections.get(COLLECTION)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
coll = bpy.data.collections.new(COLLECTION)
bpy.context.scene.collection.children.link(coll)

TILES = {
    "iron": (0, 0),
    "sheet_iron": (1, 0),
    "brass": (2, 0),
    "brick": (3, 0),
    "coal": (0, 1),
    "wood": (1, 1),
}
COLORS = {
    "iron": (44, 42, 40),
    "sheet_iron": (56, 53, 50),
    "brass": (150, 118, 66),
    "brick": (108, 52, 38),
    "coal": (24, 22, 21),
    "wood": (86, 54, 34),
}

materials = scanned_materials(TEX / "stove_atlas_256.png", TILES, "dw_stove_")


def pos(v):
    return Vector((v[0], -v[2], v[1]))


parts = []


def finish(obj, kind):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(materials[kind])
    bpy.context.view_layer.objects.active = obj
    if not obj.data.uv_layers:
        obj.data.uv_layers.new()
    tx, ty = TILES[kind]
    for uv in obj.data.uv_layers.active.data:
        uv.uv.x = (tx * 64 + 2 + (uv.uv.x % 1.000001) * 60) / 256
        uv.uv.y = (ty * 64 + 2 + (uv.uv.y % 1.000001) * 60) / 256
    for face in obj.data.polygons:
        face.use_smooth = False
    parts.append(obj)
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


def torus(name, centre, major, minor, kind, rot_deg=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=16,
        minor_segments=6,
        location=pos(centre),
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, kind)


def cyl(name, centre, radius, depth, kind, axis=(0, 1, 0), sides=12, radius_top=None):
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


# 1. Hearth pad & bevelled floor plate
box("MortarBed", (0, .011, 0), (.87, .022, .85), "brick", .004)
for row in range(5):
    for col in range(4):
        x = -.325 + .216 * col
        z = -.336 + .168 * row
        box("HearthBrick", (x, .024, z), (.211, .034, .162), "brick", .004,
            rot_deg=(0, 180 * ((row + col) % 2), 0))

# 2. Four cast-iron cabriole legs
for sx in (-0.23, 0.23):
    for sz in (-0.23, 0.23):
        box("StoveFoot", (sx * 1.08, 0.035, sz * 1.08), (0.075, 0.035, 0.075), "iron", 0.004)
        box("StoveLeg", (sx, 0.105, sz), (0.062, 0.13, 0.062), "iron", 0.005)

# 3. Base apron, ash pit & draft damper
cyl("StoveBasePlate", (0, 0.18, 0), 0.31, 0.045, "iron", sides=14)
cyl("AshPitSection", (0, 0.29, 0), 0.25, 0.19, "iron", sides=14, radius_top=0.27)
box("AshLedge", (0, 0.21, -0.28), (0.24, 0.025, 0.12), "iron", 0.003)
box("AshDoor", (0, 0.28, -0.265), (0.20, 0.11, 0.03), "sheet_iron", 0.002)
cyl("AshDraftRosette", (0, 0.28, -0.285), 0.032, 0.012, "brass", axis=(0, 0, 1), sides=10)

# 4. Potbelly firebox body with cast ribs
cyl("LowerBellyBand", (0, 0.40, 0), 0.295, 0.04, "iron", sides=14)
cyl("PotbellyLower", (0, 0.53, 0), 0.285, 0.24, "iron", sides=14, radius_top=0.345)
cyl("MidBellyRing", (0, 0.65, 0), 0.36, 0.038, "sheet_iron", sides=14)
cyl("PotbellyUpper", (0, 0.78, 0), 0.345, 0.24, "iron", sides=14, radius_top=0.275)
cyl("UpperNeckRing", (0, 0.91, 0), 0.29, 0.035, "sheet_iron", sides=14)
cyl("TopCrown", (0, 0.97, 0), 0.275, 0.09, "iron", sides=14, radius_top=0.315)
cyl("TopCookingPlate", (0, 1.03, 0), 0.33, 0.04, "iron", sides=14)
cyl("TopLidRing", (0, 1.055, 0), 0.22, 0.015, "sheet_iron", sides=12)

# 4b. Eight vertical cast-iron belly ribs around the firebox body
for rib_i in range(8):
    ang = math.tau * rib_i / 8.0 + math.pi / 8.0
    # Skip ribs directly overlapping the front firebox door or rear seam
    if math.cos(ang) < -0.75:
        continue
    rx = math.sin(ang) * 0.335
    rz = math.cos(ang) * 0.335
    box(
        f"BellyRib_{rib_i}",
        (rx, 0.65, rz),
        (0.022, 0.36, 0.022),
        "iron",
        0.002,
        rot_deg=(0, math.degrees(ang), 0),
    )

# Ash-shaker crank spindle & wood grip on the lower right side (+X)
cyl("AshShakerSpindle", (0.29, 0.30, -0.05), 0.011, 0.08, "iron", axis=(1, 0, 0), sides=8)
box("AshShakerArm", (0.33, 0.335, -0.05), (0.016, 0.085, 0.020), "iron", 0.002)
cyl("AshShakerGrip", (0.365, 0.37, -0.05), 0.014, 0.055, "wood", axis=(1, 0, 0), sides=8)

# 5. Firebox door surround arch, hinges, recessed grate bars, damper & brass latch (-Z front)
box("FireDoorFrame", (0, 0.725, -0.328), (0.265, 0.275, 0.036), "iron", 0.004)
box("FireDoorArchCap", (0, 0.875, -0.334), (0.285, 0.032, 0.044), "iron", 0.004)
box("FireDoorSillLedge", (0, 0.568, -0.344), (0.280, 0.026, 0.052), "iron", 0.003)
for cx in (-0.112, 0.112):
    for cy in (0.855, 0.592):
        cyl(f"SurroundRivet_{cx:.2f}_{cy:.2f}", (cx, cy, -0.352), 0.009, 0.010, "brass", axis=(0, 0, 1), sides=6)

# Twin left hinge barrels & right latch keeper
for hy in (0.805, 0.640):
    cyl(f"FireDoorHinge_{hy:.2f}", (-0.122, hy, -0.348), 0.014, 0.048, "iron", axis=(0, 1, 0), sides=8)
    box(f"FireDoorHingeStrap_{hy:.2f}", (-0.085, hy, -0.354), (0.070, 0.020, 0.010), "sheet_iron", 0.001)
box("FireDoorLatchKeeper", (0.124, 0.725, -0.348), (0.022, 0.044, 0.022), "brass", 0.002)

# Upper beveled plate + sliding brass draft damper over the grate
box("FireDoorUpperPanel", (0, 0.775, -0.348), (0.215, 0.135, 0.024), "sheet_iron", 0.003)
box("FireDoorPanelTrim", (0, 0.775, -0.360), (0.175, 0.095, 0.008), "iron", 0.002)
box("DraftDamperPlate", (0.0, 0.775, -0.366), (0.095, 0.032, 0.008), "brass", 0.001)
cyl("DraftDamperKnob", (-0.032, 0.775, -0.376), 0.010, 0.014, "brass", axis=(0, 0, 1), sides=8)

# Crossbar above the open ember grate (y = 0.585..0.675 stays open to EmberSeam at z = -0.334!)
box("FireDoorMidBar", (0, 0.688, -0.350), (0.220, 0.034, 0.026), "iron", 0.002)
for gx in (-0.072, -0.036, 0.0, 0.036, 0.072):
    box("GrateBar", (gx, 0.628, -0.354), (0.014, 0.082, 0.018), "iron", 0.002)
box("FireDoorBottomLip", (0, 0.582, -0.350), (0.220, 0.024, 0.026), "sheet_iron", 0.002)

# Curved brass door latch lever on the right
cyl("FireDoorHandlePost", (0.105, 0.725, -0.366), 0.011, 0.028, "brass", axis=(0, 0, 1), sides=8)
cyl("FireDoorHandle", (0.105, 0.715, -0.382), 0.013, 0.082, "brass", axis=(0, 1, 0), sides=8)

# 6. Continuous stovepipe: vertical riser + segmented 90-deg elbow + horizontal flue into EastWall (+Z = +0.80m)
cyl("PipeCollar", (0, 1.09, 0), 0.105, 0.09, "iron", sides=12)
cyl("CollarBrassRing", (0, 1.135, 0), 0.108, 0.016, "brass", sides=12)
cyl("VerticalPipeLower", (0, 1.48, 0), 0.086, 0.70, "sheet_iron", sides=12)
cyl("PipeSeamRing1", (0, 1.83, 0), 0.092, 0.022, "iron", sides=12)
cyl("VerticalPipeUpper", (0, 2.05, 0), 0.086, 0.44, "sheet_iron", sides=12)

# Segmented sheet-metal 90-degree elbow from (0, 2.27, 0) curving smoothly to (0, 2.47, 0.20)
elbow_pts = [
    (0.0, 2.27, 0.00),
    (0.0, 2.34, 0.02),
    (0.0, 2.40, 0.06),
    (0.0, 2.45, 0.12),
    (0.0, 2.47, 0.20),
]
for i in range(len(elbow_pts) - 1):
    a = Vector(elbow_pts[i])
    b = Vector(elbow_pts[i + 1])
    mid = (a + b) * 0.5
    seg_len = (b - a).length + 0.028
    cyl(f"ElbowSeg_{i}", mid, 0.088, seg_len, "sheet_iron", axis=(b - a), sides=12)
    cyl(f"ElbowRing_{i}", b, 0.093, 0.018, "iron", axis=(b - a), sides=12)

# Horizontal flue pipe running all the way to the east wall (local +Z = 0.20 to 0.74)
cyl("HorizontalFluePipe", (0, 2.47, 0.47), 0.086, 0.56, "sheet_iron", axis=(0, 0, 1), sides=12)
cyl("HorizontalFlueSeam", (0, 2.47, 0.45), 0.092, 0.022, "iron", axis=(0, 0, 1), sides=12)
cyl("DamperKeySpindle", (0.10, 2.00, 0.0), 0.010, 0.08, "brass", axis=(1, 0, 0), sides=8)

# 7. Wall chimney breast / brick flue pad & cast-iron thimble flush against EastWall (local z = 0.72..0.75 <= 0.76)
box("ChimneyWallPadFrame", (0, 2.42, 0.73), (0.48, 0.56, 0.036), "iron", 0.004)
box("ChimneyBrickPad", (0, 2.42, 0.722), (0.42, 0.50, 0.040), "brick", 0.002)
cyl("WallThimbleOuter", (0, 2.47, 0.70), 0.145, 0.045, "iron", axis=(0, 0, 1), sides=14)
cyl("WallThimbleBrassCollar", (0, 2.47, 0.68), 0.112, 0.025, "brass", axis=(0, 0, 1), sides=14)

# 8. Grounded wall heat shield against EastWall (local z = 0.71) with floor standoffs
box("WallHeatShield", (0, 1.02, 0.71), (0.84, 1.88, 0.022), "sheet_iron", 0.003)
for sx in (-0.36, 0.36):
    box("ShieldStandoffTop", (sx, 1.82, 0.73), (0.04, 0.04, 0.04), "iron")
    box("ShieldStandoffBot", (sx, 0.12, 0.725), (0.04, 0.24, 0.04), "iron")

# 9. Coal scuttle, coal pile, shovel & ash pan
cyl("CoalScuttleBody", (-0.46, 0.16, 0.22), 0.135, 0.28, "sheet_iron", sides=12, radius_top=0.16)
cyl("CoalScuttleBase", (-0.46, 0.025, 0.22), 0.145, 0.04, "iron", sides=12)
cyl("CoalScuttleLip", (-0.46, 0.30, 0.22), 0.165, 0.02, "iron", sides=12)
cyl("CoalPile", (-0.46, 0.28, 0.22), 0.145, 0.07, "coal", sides=10, radius_top=0.06)
torus("CoalScuttleHandle", (-0.46, 0.335, 0.22), 0.10, 0.008, "iron", rot_deg=(90, 0, 0))
cyl("ShovelShaft", (-0.50, 0.44, 0.22), 0.013, 0.42, "wood", axis=(0.25, 0.96, 0.0), sides=8)
box("ShovelScoop", (-0.55, 0.22, 0.22), (0.11, 0.14, 0.03), "iron", 0.002, rot_deg=(0, 0, -15))
box("AshPan", (0.18, 0.035, -0.34), (0.24, 0.045, 0.18), "sheet_iron", 0.002)

# 10. Depot cast-iron tea kettle on the top cooking plate (authored via Blender MCP)
cyl("KettleBody", (-0.18, 1.10, -0.13), 0.095, 0.11, "iron", sides=12, radius_top=0.072)
cyl("KettleLid", (-0.18, 1.16, -0.13), 0.048, 0.018, "brass", sides=10)
cyl("KettleKnob", (-0.18, 1.178, -0.13), 0.014, 0.016, "brass", sides=8)
cyl("KettleSpout", (-0.26, 1.12, -0.19), 0.014, 0.09, "iron", axis=(-0.55, 0.65, -0.45), sides=8)
torus("KettleBailHandle", (-0.18, 1.175, -0.13), 0.072, 0.006, "iron", rot_deg=(90, 0, 0))

# Join, triangulate, and export GLB
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
stove_obj = bpy.context.object
stove_obj.name = "stove_static"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
tri = stove_obj.modifiers.new("Export triangles", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)
bake_vertex_ao(stove_obj)

bpy.ops.export_scene.gltf(
    filepath=str(OUT / "stove_static.glb"),
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

report = {
    "stove_static": {
        "triangles": len(stove_obj.data.polygons),
        "vertices": len(stove_obj.data.vertices),
        "materials": [m.name for m in stove_obj.data.materials],
    }
}

if "--save-source" in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "dead_wire_stove_v1.blend"), copy=True)
# After rebuilding, run `godot --headless --path . --script tools/import_stove.gd`
# and refresh the engine-measured `glb_vertices` / `res_surface_vertices` in the
# manifest: tests/presentation/stove_manifest_test.gd compares them to the
# integrated asset, and the Blender vertex count above is source-side only.
(OUT / "build_manifest.json").write_text(
    json.dumps(
        {
            "authoring": "Blender 5.2 bpy; deterministic depot potbelly stove and wall flue",
            "units": "metres",
            "atlas": "res://assets/textures/stove_v1/stove_atlas_256.png",
            "assemblies": report,
            "total_triangles": report["stove_static"]["triangles"],
        },
        indent=2,
    ),
    encoding="utf-8",
)
print(json.dumps(report, indent=2))
