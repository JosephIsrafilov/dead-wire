"""Author high-craft sculpted 1890s Victorian furniture for Mrs. Hargrove's
Boarding House in Blender 5.2, bake per-corner ambient occlusion, and export GLBs
into assets/models/town/.

All coordinates in helpers use Godot prop-local meters (+Y up, +Z toward viewer);
pos() transforms into Blender Z-up before glTF Y-up export, preserving exact parity.
"""
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/town"
sys.path.insert(0, str(ROOT / "tools"))
from office_blender_look import bake_vertex_ao  # noqa: E402

MAT_DEFS = {
    "Desk": ("7E5D44", 0.62, 0.0),
    "DeskD": ("5E4333", 0.64, 0.0),
    "Apron": ("8A7A61", 0.68, 0.0),
    "FirD": ("705740", 0.88, 0.0),
    "FirL": ("967B5D", 0.85, 0.0),
    "Brick": ("815044", 0.90, 0.0),
    "BrickD": ("4E3129", 0.92, 0.0),
    "StoneD": ("665E52", 0.92, 0.0),
    "IronTrim": ("35332F", 0.62, 0.52),
    "BrassAged": ("977542", 0.36, 0.78),
    "Copper": ("A85D37", 0.32, 0.82),
    "Tin": ("736E5E", 0.42, 0.68),
    "Velvet": ("5E2C28", 0.88, 0.0),
    "LinenCloth": ("B8AA8D", 0.94, 0.0),
    "TrunkCanvas": ("746750", 0.94, 0.0),
    "LeatherTrim": ("4D382C", 0.56, 0.0),
    "Ceramic": ("C4BCA8", 0.24, 0.0),
    "Glaze": ("485F72", 0.22, 0.0),
    "Ember": ("B84922", 0.85, 0.0),
    "Mirror": ("586868", 0.14, 0.88),
    "Bread": ("9E713C", 0.88, 0.0),
    "ParlorRug": ("6D3830", 0.96, 0.0),
}

MATS = {}
PARTS = []


def ensure_materials():
    for name, (hx, rough, metal) in MAT_DEFS.items():
        if name in MATS:
            continue
        rgb = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        lin = tuple(x / 12.92 if x < 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in rgb)
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*lin, 1.0)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = mat.diffuse_color
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        MATS[name] = mat


def pos(v):
    """Godot prop-local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    MATS.clear()
    PARTS.clear()
    ensure_materials()


def _attach_obj(name, verts, faces, mat_name):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(MATS[mat_name])
    for poly in me.polygons:
        poly.use_smooth = False
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    PARTS.append(obj)
    return obj


def box(name, centre, size, mat_name, bevel=0.0, segs=1, rot_deg=(0.0, 0.0, 0.0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(size[0], size[2], size[1]), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.edges) + list(bm.verts),
            offset=min(bevel, min(size) * 0.42),
            segments=segs,
            affect="EDGES",
            clamp_overlap=True,
        )
    rx, ry, rz = math.radians(rot_deg[0]), math.radians(-rot_deg[2]), math.radians(rot_deg[1])
    bm.to_mesh(bpy.data.meshes.new(name))
    me = bpy.data.meshes[name]
    bm.free()
    me.materials.append(MATS[mat_name])
    for poly in me.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, me)
    obj.location = pos(centre)
    obj.rotation_euler = (rx, ry, rz)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    PARTS.append(obj)
    return obj


def cushion(name, centre, size, mat_name, bevel=0.032, rot_deg=(0.0, 0.0, 0.0)):
    return box(name, centre, size, mat_name, bevel=bevel, segs=2, rot_deg=rot_deg)


def lathe(name, centre_xz, profile_yr, mat_name, n=12, cap=True, y_offset=0.0, rot_deg=(0.0, 0.0, 0.0)):
    cx, cz = centre_xz
    verts = []
    for y_val, rad in profile_yr:
        r = max(rad, 0.0005)
        for i in range(n):
            a = i * math.tau / n
            gx = cx + r * math.cos(a)
            gz = cz + r * math.sin(a)
            gy = y_val + y_offset
            verts.append(pos((gx, gy, gz)))
    faces = []
    if cap:
        faces.append(tuple(range(n)))
    for k in range(len(profile_yr) - 1):
        for i in range(n):
            a = k * n + i
            b = k * n + (i + 1) % n
            faces.append((b, a, a + n, b + n))
    if cap:
        top0 = (len(profile_yr) - 1) * n
        faces.append(tuple(reversed(range(top0, top0 + n))))
    obj = _attach_obj(name, verts, faces, mat_name)
    if any(rot_deg):
        piv = pos((cx, y_offset, cz))
        obj.location = (0, 0, 0)
        for v in obj.data.vertices:
            v.co -= piv
        obj.rotation_euler = (math.radians(rot_deg[0]), math.radians(-rot_deg[2]), math.radians(rot_deg[1]))
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        obj.select_set(False)
        for v in obj.data.vertices:
            v.co += piv
        obj.data.update()
    return obj


def tube(name, p_godot, q_godot, r0, r1, mat_name, n=8):
    p, q = pos(p_godot), pos(q_godot)
    axis = q - p
    length = axis.length
    if length < 1e-5:
        return None
    up = axis.normalized()
    ref = Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))
    u = up.cross(ref).normalized()
    w = up.cross(u).normalized()
    verts = []
    for end_pt, rad in ((p, r0), (q, r1)):
        for i in range(n):
            a = i * math.tau / n
            verts.append(end_pt + (u * math.cos(a) + w * math.sin(a)) * rad)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
    return _attach_obj(name, verts, faces, mat_name)


def polyline_tube(name, pts_godot, rad, mat_name, n=8):
    for i in range(len(pts_godot) - 1):
        tube(f"{name}_{i}", pts_godot[i], pts_godot[i + 1], rad, rad, mat_name, n=n)


def turned_leg(prefix, x, z, h, r_foot, r_swell, r_top, mat_name="DeskD", n=10):
    profile = [
        (0.0, r_foot * 0.85),
        (0.025, r_foot),
        (0.055, r_foot * 0.65),
        (h * 0.25, r_foot * 0.68),
        (h * 0.45, r_swell),
        (h * 0.65, r_foot * 0.72),
        (h * 0.78, r_top),
        (h, r_top),
    ]
    lathe(f"{prefix}_leg", (x, z), profile, mat_name, n=n)


def export_assembly(filename):
    bpy.ops.object.select_all(action="DESELECT")
    valid = [o for o in PARTS if o is not None and len(o.data.polygons) > 0]
    for obj in valid:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = valid[0]
    bpy.ops.object.join()
    hero = bpy.context.object
    hero.name = filename
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tri = hero.modifiers.new("Tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bm = bmesh.new()
    bm.from_mesh(hero.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(hero.data)
    bm.free()
    hero.data.update()
    bake_vertex_ao(hero)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{filename}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_vertex_color="ACTIVE",
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    print(f"HERO {filename}.glb: {len(hero.data.polygons)} tris")
    PARTS.clear()


def build_fireplace():
    clear_scene()
    # Corbeled brick chimney breast rising cleanly to ceiling y=2.62 (front faces +X)
    box("ChimneyLower", (-0.08, 0.62, 0.0), (0.36, 1.24, 1.48), "Brick", bevel=0.008)
    box("ChimneyCorbel1", (-0.09, 1.32, 0.0), (0.34, 0.18, 1.42), "Brick", bevel=0.006)
    box("ChimneyUpper", (-0.12, 2.02, 0.0), (0.28, 1.24, 1.18), "Brick", bevel=0.008)
    box("FireboxRecess", (0.02, 0.44, 0.0), (0.24, 0.72, 0.80), "BrickD", bevel=0.006)
    box("FirebackArch", (0.12, 0.80, 0.0), (0.08, 0.09, 0.88), "IronTrim", bevel=0.006)

    # Beveled flagstone hearth pad on parlor floor
    box("HearthSlab", (0.16, 0.032, 0.0), (0.84, 0.065, 1.60), "StoneD", bevel=0.012, segs=2)

    # Grate basket, brass ball andirons, split firewood & sculpted glowing ember bed
    for sz in (-0.23, 0.23):
        box(f"AndironBase_{sz}", (0.18, 0.085, sz), (0.24, 0.04, 0.055), "IronTrim", bevel=0.004)
        lathe(f"AndironPost_{sz}", (0.28, sz), [(0.08, 0.022), (0.20, 0.014), (0.24, 0.032), (0.29, 0.004)], "BrassAged", n=10)
    for bar_z in (-0.20, -0.10, 0.0, 0.10, 0.20):
        tube(f"GrateBar_{bar_z}", (0.10, 0.12, bar_z), (0.24, 0.12, bar_z), 0.010, 0.010, "IronTrim", n=6)
    tube("GrateFront", (0.24, 0.14, -0.24), (0.24, 0.14, 0.24), 0.012, 0.012, "IronTrim", n=6)
    tube("Log1", (0.15, 0.15, -0.22), (0.18, 0.17, 0.22), 0.042, 0.038, "FirD", n=8)
    tube("Log2", (0.13, 0.20, -0.18), (0.20, 0.22, 0.19), 0.036, 0.032, "FirD", n=8)
    tube("Log3", (0.16, 0.25, -0.14), (0.13, 0.28, 0.15), 0.030, 0.028, "FirD", n=8)
    cushion("EmberBed", (0.16, 0.12, 0.0), (0.24, 0.08, 0.44), "Ember", bevel=0.03)
    cushion("EmberCore", (0.18, 0.15, 0.04), (0.16, 0.07, 0.26), "Ember", bevel=0.025)

    # Carved Victorian walnut mantel surround + corbels + fluted pilasters + shelf
    for sz in (-0.58, 0.58):
        box(f"PilasterBase_{sz}", (0.15, 0.11, sz), (0.14, 0.10, 0.22), "DeskD", bevel=0.006)
        box(f"PilasterShaft_{sz}", (0.15, 0.59, sz), (0.11, 0.88, 0.18), "Desk", bevel=0.006)
        box(f"Flute_{sz}", (0.205, 0.59, sz), (0.015, 0.72, 0.06), "DeskD", bevel=0.003)
        box(f"Corbel_{sz}", (0.21, 1.04, sz), (0.14, 0.18, 0.14), "DeskD", bevel=0.015, segs=2)
    box("MantelFrieze", (0.16, 1.02, 0.0), (0.11, 0.28, 1.24), "Desk", bevel=0.008)
    box("MantelPanel", (0.215, 1.02, 0.0), (0.02, 0.16, 0.78), "DeskD", bevel=0.004)
    box("BrassMedallion", (0.226, 1.02, 0.0), (0.012, 0.09, 0.09), "BrassAged", bevel=0.004, rot_deg=(0, 0, 45))
    box("MantelShelfLower", (0.20, 1.185, 0.0), (0.26, 0.045, 1.54), "DeskD", bevel=0.008)
    box("MantelShelf", (0.21, 1.23, 0.0), (0.31, 0.055, 1.62), "Desk", bevel=0.012, segs=2)

    # Ornate overmantel mirror + beveled frame
    box("MirrorBack", (0.07, 1.72, 0.0), (0.05, 0.80, 0.96), "DeskD", bevel=0.006)
    box("MirrorGlass", (0.092, 1.72, 0.0), (0.016, 0.64, 0.80), "Mirror")
    box("MirrorFilletTop", (0.10, 2.05, 0.0), (0.02, 0.03, 0.84), "BrassAged")
    box("MirrorFilletBot", (0.10, 1.39, 0.0), (0.02, 0.03, 0.84), "BrassAged")
    box("MirrorCrown", (0.085, 2.15, 0.0), (0.08, 0.07, 1.04), "Desk", bevel=0.01)

    # Mantel shelf antique gothic clock + twin candlesticks
    box("ClockBase", (0.20, 1.28, 0.0), (0.11, 0.04, 0.22), "DeskD", bevel=0.005)
    box("ClockCase", (0.20, 1.40, 0.0), (0.095, 0.22, 0.17), "Desk", bevel=0.016, segs=2)
    box("ClockCrest", (0.20, 1.525, 0.0), (0.092, 0.04, 0.12), "DeskD", bevel=0.012)
    lathe("ClockDialRim", (0.244, 0.0), [(0.0, 0.062), (0.012, 0.062)],
          "BrassAged", n=14, y_offset=1.42, rot_deg=(0, 0, -90))
    lathe("ClockFaceDisc", (0.252, 0.0), [(0.0, 0.052), (0.010, 0.052)],
          "LinenCloth", n=14, y_offset=1.42, rot_deg=(0, 0, -90))
    box("ClockHandMin", (0.260, 1.434, 0.0), (0.005, 0.036, 0.006), "IronTrim")
    box("ClockHandHr", (0.260, 1.422, 0.012), (0.005, 0.006, 0.026), "IronTrim")
    for cz in (-0.52, 0.52):
        lathe(f"MantelStick_{cz}", (0.20, cz),
              [(1.258, 0.055), (1.275, 0.025), (1.36, 0.018), (1.38, 0.038), (1.39, 0.022)], "BrassAged", n=12)
        lathe(f"MantelCandle_{cz}", (0.20, cz), [(1.385, 0.014), (1.47, 0.013)], "LinenCloth", n=10)

    # Fireside iron tool stand on right side (z = +0.69)
    lathe("ToolBase", (0.26, 0.70), [(0.064, 0.085), (0.09, 0.075)], "IronTrim", n=12)
    tube("ToolStandPost", (0.26, 0.07, 0.70), (0.26, 0.68, 0.70), 0.012, 0.010, "IronTrim", n=8)
    lathe("ToolTopKnob", (0.26, 0.70), [(0.68, 0.022), (0.71, 0.004)], "BrassAged", n=8)
    for tz_off, tx_off in ((-0.035, 0.03), (0.0, -0.03), (0.035, 0.02)):
        tube(f"ToolRod_{tz_off}", (0.26 + tx_off, 0.10, 0.70 + tz_off),
             (0.26 + tx_off, 0.63, 0.70 + tz_off), 0.007, 0.007, "IronTrim", n=6)
        lathe(f"ToolGrip_{tz_off}", (0.26 + tx_off, 0.70 + tz_off), [(0.61, 0.014), (0.66, 0.004)], "BrassAged", n=6)

    export_assembly("hargrove_fireplace")


def build_victorian_settee():
    clear_scene()
    # Origin floor center; front faces -X toward fireplace, fits collider (0.58 x 0.90 x 1.44)
    for lx in (-0.23, 0.23):
        for lz in (-0.64, 0.64):
            turned_leg(f"Settee_{lx}_{lz}", lx, lz, 0.27, 0.026, 0.036, 0.032, "DeskD", n=10)
            lathe(f"Caster_{lx}_{lz}", (lx, lz), [(0.0, 0.018), (0.028, 0.022)], "BrassAged", n=8)

    # Molded walnut seat frame apron
    box("SeatFrame", (0.0, 0.305, 0.0), (0.54, 0.08, 1.38), "DeskD", bevel=0.008)
    box("FrontRailMolding", (-0.27, 0.31, 0.0), (0.025, 0.055, 1.36), "Desk", bevel=0.006)

    # Two thick sculpted velvet seat cushions with piped seams
    for side_z in (-0.315, 0.315):
        cushion(f"SeatCushion_{side_z}", (-0.02, 0.425, side_z), (0.52, 0.16, 0.62), "Velvet", bevel=0.042)

    # Sculpted curved velvet backrest + diamond tufting button indentations
    cushion("BackUpholstery", (0.19, 0.69, 0.0), (0.15, 0.50, 1.30), "Velvet", bevel=0.04)
    for bx_row, by_val in ((0.116, 0.58), (0.116, 0.74)):
        step_pts = (-0.42, -0.14, 0.14, 0.42) if by_val < 0.65 else (-0.28, 0.0, 0.28)
        for bz in step_pts:
            lathe(f"TuftBtn_{by_val}_{bz}", (bx_row, bz), [(-0.01, 0.016), (0.012, 0.016)], "LeatherTrim",
                  n=8, rot_deg=(0, 0, 90))
            box(f"TuftRidge_{by_val}_{bz}", (bx_row + 0.005, by_val, bz), (0.014, 0.12, 0.025),
                "Velvet", bevel=0.004, rot_deg=(45, 0, 0))

    # Camelback carved show-wood crest rail across top & back casing
    box("BackShell", (0.255, 0.66, 0.0), (0.04, 0.56, 1.38), "DeskD", bevel=0.01)
    crest_pts = [(-0.68, 0.90), (-0.45, 0.96), (-0.22, 0.95), (0.0, 1.02), (0.22, 0.95), (0.45, 0.96), (0.68, 0.90)]
    for i in range(len(crest_pts) - 1):
        z0, y0 = crest_pts[i]
        z1, y1 = crest_pts[i + 1]
        tube(f"CrestRail_{i}", (0.24, y0, z0), (0.24, y1, z1), 0.036, 0.036, "Desk", n=8)
    lathe("CrestScrollCenter", (0.24, 0.0), [(1.02, 0.042), (1.06, 0.022), (1.075, 0.004)], "DeskD", n=10)

    # Rolled Victorian armrests with curved walnut stump posts
    for sz in (-0.65, 0.65):
        cushion(f"ArmBolster_{sz}", (-0.01, 0.62, sz), (0.54, 0.16, 0.13), "Velvet", bevel=0.048)
        tube(f"ArmFacing_{sz}", (-0.24, 0.34, sz), (-0.25, 0.58, sz), 0.032, 0.028, "Desk", n=8)
        box(f"ArmSidePanel_{sz}", (0.02, 0.48, sz), (0.48, 0.24, 0.05), "DeskD", bevel=0.008)

    # Two soft accent pillows tucked in the sofa corners
    cushion("ThrowPillowL", (-0.03, 0.59, -0.44), (0.11, 0.28, 0.30), "TrunkCanvas", bevel=0.038, rot_deg=(-12, 18, -14))
    cushion("ThrowPillowR", (-0.02, 0.58, 0.45), (0.11, 0.26, 0.28), "LinenCloth", bevel=0.036, rot_deg=(14, -15, -14))

    export_assembly("hargrove_victorian_settee")


def build_victorian_armchair():
    clear_scene()
    # Origin floor center; front faces +Z (collider 0.42..0.68 footprint)
    for lx in (-0.23, 0.23):
        for lz in (-0.22, 0.22):
            turned_leg(f"Chair_{lx}_{lz}", lx, lz, 0.27, 0.025, 0.035, 0.031, "DeskD", n=10)
            lathe(f"ChairCaster_{lx}_{lz}", (lx, lz), [(0.0, 0.016), (0.024, 0.020)], "BrassAged", n=8)
    box("ChairApron", (0.0, 0.30, 0.0), (0.52, 0.08, 0.50), "DeskD", bevel=0.008)
    cushion("ChairSeat", (0.0, 0.42, 0.02), (0.48, 0.16, 0.50), "Velvet", bevel=0.044)
    cushion("ChairBack", (0.0, 0.72, -0.20), (0.50, 0.54, 0.14), "Velvet", bevel=0.044)
    box("ChairBackWood", (0.0, 0.70, -0.255), (0.54, 0.56, 0.04), "DeskD", bevel=0.01)
    tube("ChairCrest", (-0.22, 0.99, -0.24), (0.22, 0.99, -0.24), 0.034, 0.034, "Desk", n=8)
    for sx in (-0.26, 0.26):
        cushion(f"ChairWing_{sx}", (sx * 0.92, 0.82, -0.10), (0.09, 0.28, 0.24), "Velvet", bevel=0.032)
        cushion(f"ChairArm_{sx}", (sx, 0.60, 0.02), (0.12, 0.15, 0.48), "Velvet", bevel=0.044)
        tube(f"ChairArmPost_{sx}", (sx, 0.34, 0.22), (sx, 0.58, 0.22), 0.028, 0.024, "Desk", n=8)
    for bx, by in ((-0.10, 0.66), (0.10, 0.66), (0.0, 0.78), (-0.11, 0.86), (0.11, 0.86)):
        lathe(f"ArmBtn_{bx}_{by}", (bx, -0.13), [(-0.01, 0.015), (0.012, 0.015)], "LeatherTrim",
              n=8, y_offset=by, rot_deg=(-90, 0, 0))
    export_assembly("hargrove_victorian_armchair")


def build_parlor_table():
    clear_scene()
    # Pie-crust round pedestal parlor table, top flat at y=0.725 so oil lamp rests cleanly at center!
    lathe("TableTop", (0.0, 0.0), [(0.67, 0.33), (0.695, 0.365), (0.725, 0.365), (0.725, 0.345)], "Desk", n=18)
    lathe("TableApron", (0.0, 0.0), [(0.625, 0.25), (0.67, 0.28)], "DeskD", n=14)
    lathe("PedestalShaft", (0.0, 0.0),
          [(0.11, 0.042), (0.18, 0.078), (0.26, 0.046), (0.38, 0.068), (0.50, 0.038), (0.625, 0.064)], "DeskD", n=12)
    for i in range(3):
        a = i * math.tau / 3.0 + 0.3
        dx, dz = math.cos(a), math.sin(a)
        polyline_tube(f"TripodLeg_{i}", [
            (dx * 0.05, 0.14, dz * 0.05),
            (dx * 0.18, 0.11, dz * 0.18),
            (dx * 0.29, 0.032, dz * 0.29),
        ], 0.025, "DeskD", n=8)
        lathe(f"TripodFoot_{i}", (dx * 0.29, dz * 0.29), [(0.0, 0.030), (0.035, 0.022)], "DeskD", n=8)

    # Woven centerpiece mat + 2 stacked leather-bound parlor books off to side
    lathe("DoilyMat", (0.0, 0.0), [(0.725, 0.21), (0.728, 0.205)], "LinenCloth", n=14)
    box("Book1Cover", (0.14, 0.742, -0.10), (0.17, 0.030, 0.22), "LeatherTrim", bevel=0.004, rot_deg=(0, 18, 0))
    box("Book1Pages", (0.14, 0.742, -0.10), (0.155, 0.024, 0.205), "LinenCloth", bevel=0.002, rot_deg=(0, 18, 0))
    box("Book2Cover", (0.15, 0.770, -0.09), (0.15, 0.026, 0.20), "Velvet", bevel=0.004, rot_deg=(0, 6, 0))
    box("Book2Pages", (0.15, 0.770, -0.09), (0.135, 0.020, 0.185), "LinenCloth", bevel=0.002, rot_deg=(0, 6, 0))

    export_assembly("hargrove_parlor_table")


def _table_setting(idx, x, z, rot_y):
    # Plates centered cleanly above tabletop & runner
    lathe(f"Plate_{idx}", (x, z), [(0.768, 0.08), (0.774, 0.12), (0.784, 0.13)], "Ceramic", n=16)
    lathe(f"Bowl_{idx}", (x, z), [(0.785, 0.045), (0.810, 0.072), (0.824, 0.076)], "Glaze", n=14)
    off = 0.165 * (-1.0 if rot_y > 0 else 1.0)
    box(f"Fork_{idx}", (x - off * 0.15, 0.772, z - 0.16), (0.16, 0.005, 0.016), "Tin")
    box(f"Knife_{idx}", (x - off * 0.15, 0.772, z + 0.16), (0.18, 0.005, 0.018), "Tin")
    lathe(f"Mug_{idx}", (x - off * 0.45, z + 0.15), [(0.768, 0.036), (0.848, 0.040), (0.850, 0.034)], "Ceramic", n=12)


def build_dining_table():
    clear_scene()
    # Grand communal walnut boarding-house dining table (1.22 x 2.40 m, top at y=0.765)
    box("TableTopMain", (0.0, 0.738, 0.0), (1.22, 0.055, 2.40), "Desk", bevel=0.012, segs=2)
    box("TableApron", (0.0, 0.675, 0.0), (1.06, 0.095, 2.22), "DeskD", bevel=0.008)
    for lx in (-0.49, 0.49):
        for lz in (-1.04, 1.04):
            box(f"ApronBlock_{lx}_{lz}", (lx, 0.675, lz), (0.10, 0.10, 0.10), "DeskD", bevel=0.005)
            turned_leg(f"DiningLeg_{lx}_{lz}", lx, lz, 0.64, 0.042, 0.062, 0.052, "DeskD", n=10)
    box("StretcherMain", (0.0, 0.17, 0.0), (0.08, 0.055, 2.04), "DeskD", bevel=0.006)
    for sz in (-1.04, 1.04):
        box(f"StretcherCross_{sz}", (0.0, 0.17, sz), (0.98, 0.055, 0.08), "DeskD", bevel=0.006)

    # Woven linen runner overhanging both table ends cleanly
    box("RunnerTop", (0.0, 0.767, 0.0), (0.50, 0.008, 2.44), "LinenCloth", bevel=0.003)
    for sz in (-1.22, 1.22):
        box(f"RunnerDrop_{sz}", (0.0, 0.65, sz), (0.50, 0.24, 0.010), "LinenCloth", bevel=0.004)
        box(f"RunnerTrim_{sz}", (0.0, 0.54, sz), (0.50, 0.025, 0.012), "ParlorRug")

    # 6 Full Table Settings
    idx = 0
    for cz in (-0.72, 0.0, 0.72):
        _table_setting(idx, -0.39, cz, -1.0)
        idx += 1
        _table_setting(idx, 0.39, cz, 1.0)
        idx += 1

    # Centerpiece Pitcher, Soup Tureen, Wooden Board + Loaf of Bread, Cruets (resting cleanly on runner top 0.771)
    lathe("WaterPitcher", (0.04, -0.40),
          [(0.772, 0.065), (0.835, 0.095), (0.94, 0.070), (0.98, 0.052), (1.02, 0.064)], "Ceramic", n=16)
    lathe("PitcherBand", (0.04, -0.40), [(0.91, 0.080), (0.93, 0.075)], "Glaze", n=16, cap=False)
    polyline_tube("PitcherHandle", [(0.11, 0.99, -0.40), (0.16, 0.95, -0.40), (0.15, 0.85, -0.40), (0.09, 0.82, -0.40)],
                  0.011, "Ceramic", n=8)
    lathe("SoupTureen", (-0.03, 0.38),
          [(0.772, 0.085), (0.835, 0.138), (0.88, 0.140), (0.92, 0.095), (0.94, 0.018)], "Ceramic", n=16)
    lathe("TureenKnob", (-0.03, 0.38), [(0.938, 0.022), (0.96, 0.006)], "Glaze", n=12)
    box("BreadBoard", (0.02, 0.782, -0.82), (0.28, 0.020, 0.40), "FirL", bevel=0.006)
    cushion("BreadLoaf", (0.02, 0.826, -0.82), (0.15, 0.085, 0.25), "Bread", bevel=0.032)
    lathe("SaltCruet", (-0.11, -0.14), [(0.772, 0.020), (0.825, 0.016), (0.842, 0.021)], "Tin", n=12)
    lathe("PepperCruet", (0.11, 0.14), [(0.772, 0.020), (0.825, 0.016), (0.842, 0.021)], "BrassAged", n=12)

    export_assembly("hargrove_dining_table")


def build_china_hutch():
    clear_scene()
    # Front faces -Z (into dining room); back is at +Z = +0.24
    box("HutchPlinth", (0.0, 0.045, 0.0), (1.36, 0.09, 0.50), "DeskD", bevel=0.008)
    box("CredenzaBody", (0.0, 0.50, 0.01), (1.32, 0.82, 0.46), "DeskD", bevel=0.008)
    box("CredenzaCounter", (0.0, 0.935, 0.0), (1.38, 0.055, 0.52), "Desk", bevel=0.010)
    # 2 paneled cupboard doors + 2 drawers facing -Z
    for dx in (-0.32, 0.32):
        box(f"HutchDoor_{dx}", (dx, 0.40, -0.225), (0.58, 0.54, 0.028), "Desk", bevel=0.006)
        box(f"HutchDoorPanel_{dx}", (dx, 0.40, -0.240), (0.44, 0.40, 0.016), "DeskD", bevel=0.004)
        lathe(f"HutchKnob_{dx}", (dx - math.copysign(0.20, dx), -0.252),
              [(0.0, 0.014), (0.022, 0.018)], "BrassAged", n=8, y_offset=0.52, rot_deg=(-90, 0, 0))
        box(f"HutchDrawer_{dx}", (dx, 0.78, -0.228), (0.58, 0.14, 0.028), "Desk", bevel=0.006)
        box(f"HutchPull_{dx}", (dx, 0.78, -0.252), (0.08, 0.024, 0.018), "BrassAged", bevel=0.003)

    # Upper display hutch (back at +Z = +0.22)
    box("HutchBackboard", (0.0, 1.44, 0.215), (1.28, 0.96, 0.03), "DeskD", bevel=0.004)
    for sx in (-0.63, 0.63):
        box(f"HutchSide_{sx}", (sx, 1.44, 0.09), (0.055, 0.96, 0.28), "Desk", bevel=0.008)
    for sy in (1.24, 1.56):
        box(f"HutchShelf_{sy}", (0.0, sy, 0.09), (1.22, 0.032, 0.26), "Desk", bevel=0.005)
    box("HutchCrownFrieze", (0.0, 1.93, 0.08), (1.32, 0.09, 0.30), "DeskD", bevel=0.008)
    box("HutchCrownMolding", (0.0, 1.995, 0.07), (1.40, 0.055, 0.34), "Desk", bevel=0.010)

    # Dishware display across shelves
    for px in (-0.42, -0.14, 0.14, 0.42):
        lathe(f"DisplayPlate_{px}", (px, 0.16),
              [(0.0, 0.125), (0.018, 0.130)], "Ceramic", n=14, y_offset=1.39, rot_deg=(80, 0, 0))
        lathe(f"DisplayBowl_{px}", (px, 0.05),
              [(1.576, 0.055), (1.64, 0.088), (1.655, 0.092)], "Glaze", n=12)
    lathe("CounterCrock", (-0.45, -0.06), [(0.962, 0.085), (1.14, 0.088), (1.17, 0.068)], "Ceramic", n=12)
    lathe("CopperTeapot", (0.0, -0.05),
          [(0.962, 0.065), (1.03, 0.105), (1.11, 0.072), (1.15, 0.048), (1.18, 0.018)], "Copper", n=12)
    lathe("TeapotKnob", (0.0, -0.05), [(1.175, 0.016), (1.195, 0.004)], "BrassAged", n=8)
    polyline_tube("TeapotSpout", [(0.08, 1.03, -0.05), (0.15, 1.08, -0.05), (0.18, 1.13, -0.05)], 0.014, "Copper", n=6)
    lathe("SugarJar", (0.42, -0.04), [(0.962, 0.055), (1.09, 0.058), (1.12, 0.040)], "Glaze", n=10)

    export_assembly("hargrove_china_hutch")


def build_cookstove():
    clear_scene()
    # Front faces +X into kitchen; flue rises smoothly to y=2.28 into kitchen ceiling
    box("StoveHearthPad", (0.02, 0.022, 0.0), (0.86, 0.045, 0.96), "StoneD", bevel=0.010)
    for lx in (-0.28, 0.28):
        for lz in (-0.34, 0.34):
            polyline_tube(f"CookLeg_{lx}_{lz}",
                          [(lx, 0.04, lz), (lx * 0.92, 0.12, lz * 0.92), (lx * 0.85, 0.22, lz * 0.85)],
                          0.032, "IronTrim", n=8)
    box("CookBody", (-0.02, 0.51, 0.0), (0.68, 0.58, 0.82), "IronTrim", bevel=0.018)
    box("CookTopRim", (0.01, 0.81, 0.0), (0.76, 0.048, 0.88), "IronTrim", bevel=0.010)
    box("AshLedge", (0.36, 0.27, 0.0), (0.14, 0.035, 0.78), "IronTrim", bevel=0.006)
    # Embossed oven door + firebox door facing +X
    box("OvenDoor", (0.33, 0.50, -0.14), (0.03, 0.34, 0.38), "Tin", bevel=0.006)
    box("OvenDoorTrim", (0.345, 0.50, -0.14), (0.016, 0.24, 0.28), "IronTrim", bevel=0.004)
    box("FireboxDoor", (0.33, 0.56, 0.22), (0.03, 0.24, 0.22), "IronTrim", bevel=0.006)
    box("FireboxLatch", (0.355, 0.56, 0.15), (0.022, 0.06, 0.02), "BrassAged", bevel=0.003)
    tube("OvenTowelRail", (0.40, 0.77, -0.38), (0.40, 0.77, 0.38), 0.011, 0.011, "Tin", n=8)
    # 4 cast-iron stove-lid burner plates
    for bx in (-0.13, 0.15):
        for bz in (-0.21, 0.21):
            lathe(f"Burner_{bx}_{bz}", (bx, bz), [(0.832, 0.12), (0.840, 0.115)], "IronTrim", n=14)
    # Raised rear warming backguard shelf + chimney stovepipe up to ceiling y=2.28
    box("BackguardSplash", (-0.31, 1.11, 0.0), (0.04, 0.58, 0.84), "IronTrim", bevel=0.008)
    box("WarmingShelf", (-0.21, 1.38, 0.0), (0.24, 0.035, 0.84), "IronTrim", bevel=0.006)
    lathe("StoveFluePipe", (-0.24, 0.0), [(0.83, 0.088), (2.28, 0.082)], "IronTrim", n=12)
    lathe("FlueDamperCollar", (-0.24, 0.0), [(1.42, 0.098), (1.46, 0.098)], "BrassAged", n=12)

    # Copper teakettle & cast-iron skillet resting on top burners (y=0.840)
    lathe("CopperKettle", (0.15, 0.21),
          [(0.840, 0.085), (0.89, 0.118), (0.96, 0.085), (0.99, 0.055), (1.005, 0.060)], "Copper", n=14)
    lathe("KettleKnob", (0.15, 0.21), [(1.005, 0.016), (1.028, 0.004)], "BrassAged", n=8)
    polyline_tube("KettleSpout", [(0.23, 0.90, 0.21), (0.29, 0.96, 0.21), (0.31, 1.00, 0.21)], 0.015, "Copper", n=6)
    polyline_tube("KettleBail", [(0.15, 0.98, 0.11), (0.15, 1.07, 0.15), (0.15, 1.10, 0.21),
                                 (0.15, 1.07, 0.27), (0.15, 0.98, 0.31)], 0.007, "IronTrim", n=6)
    lathe("SkilletPan", (-0.13, -0.21), [(0.840, 0.115), (0.875, 0.128), (0.880, 0.120)], "IronTrim", n=14)
    tube("SkilletHandle", (-0.13, 0.87, -0.09), (-0.13, 0.89, 0.07), 0.012, 0.009, "IronTrim", n=6)

    export_assembly("hargrove_cookstove")


def build_reception_props():
    clear_scene()
    # Origin sits ON tabletop y=0 (world -0.30, 0.768, -3.96); back north wall at local z = -0.22
    # Open curved Guest Register leather cover + layered cream pages
    box("RegisterCover", (-0.02, 0.012, 0.0), (0.38, 0.022, 0.26), "LeatherTrim", bevel=0.004)
    box("RegisterSpine", (-0.02, 0.018, 0.0), (0.04, 0.032, 0.27), "LeatherTrim", bevel=0.004)
    for px in (-0.105, 0.065):
        cushion(f"RegisterPageBlock_{px}", (px, 0.026, 0.0), (0.16, 0.022, 0.235), "LinenCloth", bevel=0.006)

    # Brass counter service bell & brass inkstand + pen
    lathe("ServiceBellBase", (0.26, 0.06), [(0.0, 0.048), (0.012, 0.044)], "DeskD", n=12)
    lathe("ServiceBellDome", (0.26, 0.06), [(0.012, 0.040), (0.042, 0.034), (0.060, 0.014), (0.072, 0.006)],
          "BrassAged", n=14)
    box("InkStand", (-0.28, 0.018, -0.05), (0.11, 0.028, 0.08), "BrassAged", bevel=0.005)
    lathe("InkwellCup", (-0.28, -0.05), [(0.028, 0.022), (0.058, 0.015)], "IronTrim", n=10)
    tube("DeskPen", (-0.24, 0.032, -0.03), (-0.18, 0.145, 0.03), 0.005, 0.002, "DeskD", n=6)

    # Wall Key Rack against north wall (local y = +0.76..+1.06, z = -0.21 -> world z = -4.17)
    box("KeyRackBack", (0.0, 0.86, -0.205), (0.68, 0.26, 0.036), "DeskD", bevel=0.008)
    box("KeyRackCrown", (0.0, 1.00, -0.195), (0.72, 0.04, 0.052), "Desk", bevel=0.006)
    for i, kx in enumerate((-0.21, -0.07, 0.07, 0.21)):
        box(f"KeyPlaque_{i}", (kx, 0.93, -0.184), (0.048, 0.034, 0.008), "BrassAged")
        lathe(f"KeyHook_{i}", (kx, -0.175), [(0.0, 0.008), (0.025, 0.005)], "BrassAged", n=6,
              y_offset=0.87, rot_deg=(90, 0, 0))
        if i < 3:
            lathe(f"KeyBow_{i}", (kx, -0.165), [(0.84, 0.016), (0.855, 0.016)], "IronTrim", n=8, rot_deg=(90, 0, 0))
            tube(f"KeyShaft_{i}", (kx, 0.83, -0.165), (kx, 0.77, -0.165), 0.004, 0.004, "IronTrim", n=6)
            box(f"KeyBit_{i}", (kx + 0.008, 0.78, -0.165), (0.014, 0.016, 0.005), "IronTrim")

    # Floor-standing leather Gladstone valise tucked neatly beside foyer console (+0.58, -0.768, +0.02)
    cushion("ValiseBody", (0.58, -0.60, 0.02), (0.24, 0.30, 0.44), "LeatherTrim", bevel=0.032)
    for sz in (-0.12, 0.12):
        box(f"ValiseStrap_{sz}", (0.58, -0.59, 0.02 + sz), (0.252, 0.31, 0.035), "DeskD", bevel=0.004)
        box(f"ValiseBuckle_{sz}", (0.58, -0.45, 0.02 + sz), (0.04, 0.022, 0.042), "BrassAged")
    polyline_tube("ValiseHandle", [(0.58, -0.45, -0.05), (0.58, -0.39, -0.03),
                                   (0.58, -0.39, 0.07), (0.58, -0.45, 0.09)], 0.012, "LeatherTrim", n=6)

    export_assembly("hargrove_reception_props")


def main():
    build_fireplace()
    build_victorian_settee()
    build_victorian_armchair()
    build_parlor_table()
    build_dining_table()
    build_china_hutch()
    build_cookstove()
    build_reception_props()


if __name__ == "__main__":
    main()
