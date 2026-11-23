"""Authored PSX molded frame and hanging hardware for the north-wall DivisionMap.
Run with Blender 5.2 headless (`blender -b -P tools/build_wall_frames_blender.py`).
Reuses `assets/textures/office_props_v1/props_atlas_256.png` read-only and exports
`assets/models/office_props_v1/division_map_frame_static.glb` centred around the
map origin in Godot local space (map face on local z = 0, facing +Z into room).
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/office_props_v1"
OUT.mkdir(parents=True, exist_ok=True)
ATLAS = ROOT / "assets/textures/office_props_v1/props_atlas_256.png"

COLLECTION = "DW_WallFrames_v1"
old = bpy.data.collections.get(COLLECTION)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
coll = bpy.data.collections.new(COLLECTION)
bpy.context.scene.collection.children.link(coll)

TILES = {
    "dark_wood": (0, 0),
    "mid_wood": (1, 0),
    "brass": (2, 0),
    "iron": (3, 0),
}

image = bpy.data.images.load(str(ATLAS), check_existing=True)
materials = {}
for kind in TILES:
    mat = bpy.data.materials.new("dw_props_" + kind)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.55 if kind == "brass" else 0.9
    bsdf.inputs["Metallic"].default_value = 0.6 if kind in ("brass", "iron") else 0.0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    materials[kind] = mat


def pos(v):
    """Godot local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


PARTS = []
UV_PERIOD = 0.35


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
    extent = max(obj.dimensions) if max(obj.dimensions) > 0.0 else UV_PERIOD
    uv_repeat = max(1.0, round(extent / UV_PERIOD))
    for uv in obj.data.uv_layers.active.data:
        u = (uv.uv.x * uv_repeat) % 1.000001
        v = (uv.uv.y * uv_repeat) % 1.000001
        uv.uv.x = (tx * 64 + 2 + u * 60) / 256
        uv.uv.y = (ty * 64 + 2 + v * 60) / 256
    for face in obj.data.polygons:
        face.use_smooth = False
    PARTS.append(obj)
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


def cyl(name, centre, radius, depth, kind, axis=(0, 1, 0), sides=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos(centre))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(pos(axis).normalized())
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, kind)


# Map quad is 0.90 x 0.56 centred at (0, 0, 0), facing +Z.
# Stepped dark_wood outer rails with chamfer + inner mid_wood bevel fillet + corner blocks & brass tacks.
OUTER_W = 0.98
OUTER_H = 0.64
RAIL_W = 0.044
INNER_W = 0.916
INNER_H = 0.576

box("MapOuterTop", (0.0, 0.30, 0.012), (OUTER_W, RAIL_W, 0.026), "dark_wood", 0.003)
box("MapOuterBottom", (0.0, -0.30, 0.012), (OUTER_W, RAIL_W, 0.026), "dark_wood", 0.003)
for sx in (-0.468, 0.468):
    box(f"MapOuterSide_{sx:.2f}", (sx, 0.0, 0.012), (RAIL_W, OUTER_H, 0.026), "dark_wood", 0.003)

box("MapFilletTop", (0.0, 0.278, 0.016), (INNER_W, 0.016, 0.014), "mid_wood", 0.001)
box("MapFilletBottom", (0.0, -0.278, 0.016), (INNER_W, 0.016, 0.014), "mid_wood", 0.001)
for sx in (-0.450, 0.450):
    box(f"MapFilletSide_{sx:.2f}", (sx, 0.0, 0.016), (0.016, INNER_H, 0.014), "mid_wood", 0.001)

# Corner rosettes & brass dome tacks
for cx in (-0.468, 0.468):
    for cy in (-0.30, 0.30):
        box(f"MapCornerRosette_{cx:.2f}_{cy:.2f}", (cx, cy, 0.024), (0.048, 0.048, 0.008), "mid_wood", 0.002)
        cyl(f"MapCornerTack_{cx:.2f}_{cy:.2f}", (cx, cy, 0.030), 0.007, 0.006, "brass", axis=(0, 0, 1), sides=6)

# Hanging wire V-cord & brass wall hook nail above top rail
hook_y = 0.42
for sx in (-0.30, 0.30):
    a = Vector((sx, 0.31, 0.004))
    b = Vector((0.0, hook_y, 0.004))
    mid = (a + b) * 0.5
    cyl(f"MapHangWire_{sx:.1f}", mid, 0.0035, (b - a).length, "iron", axis=(b - a), sides=6)
    cyl(f"MapWireEyelet_{sx:.1f}", (sx, 0.312, 0.006), 0.008, 0.008, "brass", axis=(0, 0, 1), sides=6)

cyl("MapWallHookPlate", (0.0, hook_y, 0.002), 0.018, 0.006, "brass", axis=(0, 0, 1), sides=8)
cyl("MapWallHookPin", (0.0, hook_y, 0.012), 0.006, 0.018, "brass", axis=(0, 0, 1), sides=6)

bpy.ops.object.select_all(action="DESELECT")
for obj in PARTS:
    obj.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.join()
frame_obj = bpy.context.object
frame_obj.name = "division_map_frame_static"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
tri = frame_obj.modifiers.new("Export triangles", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)

bpy.ops.export_scene.gltf(
    filepath=str(OUT / "division_map_frame_static.glb"),
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
print("Exported division_map_frame_static.glb tris=", len(frame_obj.data.polygons))
