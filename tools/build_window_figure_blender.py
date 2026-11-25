"""Build the Stage 1.1 window watcher (v3 uncanny pale visage & glaring eyes) as four GLB assemblies.

Run from repo root:
    blender -b -P tools/build_window_figure_blender.py
Then import into Godot ArrayMesh resources with their moon-rim shader:
    godot --headless --path . --script tools/import_window_figure.gd

Design intent (No, I'm Not a Human x 1890 Colorado mining telegraph horror):
  - Tall, gaunt, unnaturally proportioned frame peeking slightly forward: left
    shoulder sags, disproportionately long bony arms and splayed fingers dangle
    past the greatcoat cuffs.
  - Under a deep shadowed slouch hat brim, an elongated pale ashen-moonlit skull
    features hollow sunken cheekbones, a sharp crooked bridge, a thin tight grim
    mouth line, and deep pitch-black orbital cavities.
  - Inside the black sockets sit wide-open pale cold sclera ovals with pinpoint
    soot-black pupils staring directly through the bay window (zero Light3D).
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from office_blender_look import bake_vertex_ao

OUT = ROOT / "assets/models/window_figure_v1"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "docs/art/state_2026-10-20/figure/sources"
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("", encoding="utf-8")

COLLECTION = "DW_WindowFigure_v1"
old = bpy.data.collections.get(COLLECTION)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
coll = bpy.data.collections.new(COLLECTION)
bpy.context.scene.collection.children.link(coll)


def pos(v):
    """Godot figure-local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def godot(bco):
    """Blender coordinate back to Godot figure-local (x, y, z)."""
    return (bco.x, bco.z, -bco.y)


def material(name, rgb, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.20
    return mat


CLOTH = material("dw_figure_cloth", (0.024, 0.026, 0.032), 0.94)
HAT = material("dw_figure_hat", (0.018, 0.020, 0.026), 0.89)

CURRENT = []


def begin():
    CURRENT.clear()


def finish(obj, mat, smooth=True):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    CURRENT.append(obj)
    return obj


def loft_rings(name, rings, mat=CLOTH, cap_low=True, cap_high=True, smooth=True):
    """Create a clean closed mesh from precomputed rings of (x, y, z) tuples."""
    segments = len(rings[0])
    verts = []
    faces = []
    for ring in rings:
        verts.extend(ring)
    for r in range(len(rings) - 1):
        base = r * segments
        nxt = (r + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base + i, nxt + i, nxt + j, base + j))
    if cap_low:
        faces.append(tuple(range(segments)))
    if cap_high:
        last = (len(rings) - 1) * segments
        faces.append(tuple(last + i for i in range(segments - 1, -1, -1)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([pos(v) for v in verts], [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, smooth=smooth)


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def paint_color(obj, rule, multiply=True):
    """Paint baked vertex color (scalar multiplier or RGB tuple) in Godot space."""
    layer = obj.data.color_attributes.active_color
    for poly in obj.data.polygons:
        for loop_index in poly.loop_indices:
            local = godot(obj.data.vertices[obj.data.loops[loop_index].vertex_index].co)
            val = rule(local)
            if val is None:
                continue
            c = layer.data[loop_index].color
            if isinstance(val, (tuple, list)):
                if multiply:
                    r, g, b = c[0] * val[0], c[1] * val[1], c[2] * val[2]
                else:
                    r, g, b = val[0], val[1], val[2]
            else:
                r, g, b = c[0] * val, c[1] * val, c[2] * val
            layer.data[loop_index].color = (
                max(0.0, min(1.0, r)),
                max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)),
                1.0,
            )


def bake(name, mat=CLOTH):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in CURRENT:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = CURRENT[0]
    if len(CURRENT) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tri = obj.modifiers.new("Export triangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bake_vertex_ao(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def export(obj, filename, path=None):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str((path or OUT) / filename),
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
    corners = [obj.matrix_world @ v.co for v in obj.data.vertices]
    godot_corners = [godot(c) for c in corners]
    return {
        "triangles": len(obj.data.polygons),
        "vertices": len(obj.data.vertices),
        "materials": [m.name for m in obj.data.materials],
        "aabb_godot": [
            round(min(c[0] for c in godot_corners), 4),
            round(min(c[1] for c in godot_corners), 4),
            round(min(c[2] for c in godot_corners), 4),
            round(max(c[0] for c in godot_corners), 4),
            round(max(c[1] for c in godot_corners), 4),
            round(max(c[2] for c in godot_corners), 4),
        ],
    }


manifest = {
    "version": "window_figure_v3",
    "authoring": "Blender 5.2 bpy; gaunt towering silhouette + pale uncanny face + glaring eyes",
    "units": "metres",
    "assemblies": {},
}


# =========================================================================
# 1. TALL GAUNT STOOPING GREATCOAT & ELONGATED ARMS (soles at y = -0.940)
# =========================================================================
begin()
SEG_COAT = 24
COAT_LOW = -0.560
coat_specs = [
    (-0.560, 0.252, 0.164, 0.008, 0.0),
    (-0.420, 0.234, 0.152, 0.007, 0.0),
    (-0.240, 0.212, 0.140, 0.005, 0.0),
    (-0.040, 0.184, 0.124, 0.004, 0.0),
    (0.095, 0.162, 0.112, 0.004, 0.0),   # sunken narrow ribcage / waist
    (0.235, 0.188, 0.122, 0.008, 0.0),
    (0.365, 0.208, 0.124, 0.014, 0.0),   # thin bony hunched chest
    (0.455, 0.206, 0.114, 0.018, 0.0),   # narrow high stooping shoulders
    (0.500, 0.145, 0.098, 0.014, 0.35),
    (0.535, 0.110, 0.088, 0.012, 0.75),  # tall upturned coat collar around neck
    (0.575, 0.096, 0.084, 0.010, 1.00),
]

coat_rings = []
for y, hw, hd, cz, collar in coat_specs:
    ring = []
    for i in range(SEG_COAT):
        theta = math.tau * i / SEG_COAT
        c = math.cos(theta)
        s = math.sin(theta)
        ex = math.copysign(abs(c) ** 0.78, c)
        ez = math.copysign(abs(s) ** 0.78, s)
        lower_t = smoothstep(0.10, COAT_LOW, y)
        fold = 1.0 + lower_t * (0.068 * math.sin(theta * 5.0 + 0.5) + 0.032 * math.cos(theta * 3.0))
        lapel = 0.012 * math.exp(-(c * c) / 0.05) if s > 0.3 and y < 0.46 else 0.0
        sh_droop = -0.030 * smoothstep(0.24, 0.48, y) * max(0.0, -c)
        throat_dip = -0.042 * collar * smoothstep(0.30, 0.92, s)
        ring.append((ex * hw * fold, y + sh_droop + throat_dip, cz + ez * hd * fold + lapel))
    coat_rings.append(ring)
loft_rings("CoatTorso", coat_rings, mat=CLOTH)

# Abnormally long hanging arms + pale gaunt bony fingertips past cuffs
SEG_ARM = 14
for side, sx in (("L", -1.0), ("R", 1.0)):
    droop = -0.032 if sx < 0 else 0.0
    elbow_out = 0.215 if sx < 0 else 0.205
    arm_pts = [
        (sx * 0.138, 0.455 + droop, 0.014, 0.060, 0.058),
        (sx * 0.186, 0.440 + droop, 0.015, 0.062, 0.060),
        (sx * 0.204, 0.285 + droop, 0.020, 0.048, 0.048),
        (sx * elbow_out, 0.115 + droop, 0.030, 0.044, 0.044),
        (sx * elbow_out, -0.060 + droop, 0.046, 0.040, 0.040),
        (sx * (elbow_out - 0.005), -0.220 + droop, 0.060, 0.038, 0.040),
        (sx * (elbow_out - 0.010), -0.232 + droop, 0.060, 0.028, 0.030),
        (sx * (elbow_out - 0.010), -0.305 + droop, 0.066, 0.022, 0.034),
        (sx * (elbow_out - 0.008), -0.382 + droop, 0.074, 0.016, 0.026),
        (sx * (elbow_out - 0.006), -0.415 + droop, 0.076, 0.008, 0.012),
    ]
    arm_rings = []
    for cx, y, cz, rx, rz in arm_pts:
        ring = []
        for i in range(SEG_ARM):
            th = math.tau * i / SEG_ARM
            ring.append((cx + math.cos(th) * rx, y, cz + math.sin(th) * rz))
        arm_rings.append(ring)
    loft_rings("Arm" + side, arm_rings, mat=CLOTH)

# Trousers and boots down to y = -0.940
SEG_LEG = 14
for side, sx in (("L", -1.0), ("R", 1.0)):
    stance_z = 0.014 if sx < 0 else -0.004
    leg_pts = [
        (sx * 0.095, -0.420, stance_z, 0.068, 0.072),
        (sx * 0.095, -0.620, stance_z + 0.004, 0.062, 0.064),
        (sx * 0.095, -0.805, stance_z + 0.006, 0.052, 0.056),
        (sx * 0.095, -0.840, stance_z + 0.012, 0.058, 0.066),
        (sx * 0.095, -0.895, stance_z + 0.042, 0.062, 0.110),
        (sx * 0.095, -0.940, stance_z + 0.046, 0.060, 0.112),
    ]
    leg_rings = []
    for cx, y, cz, rx, rz in leg_pts:
        ring = []
        for i in range(SEG_LEG):
            th = math.tau * i / SEG_LEG
            ring.append((cx + math.cos(th) * rx, y, cz + math.sin(th) * rz))
        leg_rings.append(ring)
    loft_rings("LegBoot" + side, leg_rings, mat=CLOTH)

coat = bake("figure_coat", CLOTH)
paint_color(coat, lambda p: 0.40 if p[1] < COAT_LOW + 0.04 else None)
paint_color(coat, lambda p: 0.30 if p[1] > 0.48 and p[2] > 0.03 and abs(p[0]) < 0.065 else None)
paint_color(coat, lambda p: 0.62 if p[1] < -0.56 else None)
paint_color(coat, lambda p: (1.45, 1.50, 1.58) if p[1] < -0.25 and abs(p[0]) > 0.17 else None)  # pale gaunt fingers
manifest["assemblies"]["figure_coat"] = export(coat, "figure_coat.glb")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "window_figure_coat.blend"))


# =========================================================================
# 2. ELONGATED PALE UNCANNY SKULL (neck pivot y=0 -> (0, 0.545, 0.012))
# Tall neck + sculpted cheekbones/nose/tight mouth rising CLEAR of fence rail!
# =========================================================================
begin()
SEG_HEAD = 32
head_levels = [
    (-0.145, 0.042, 0.044, 0.004),  # deep inside collar
    (-0.070, 0.038, 0.042, 0.012),  # unnaturally long gaunt neck
    (-0.024, 0.036, 0.050, 0.034),  # narrow jutting chin
    (0.002, 0.052, 0.066, 0.026),   # tight jaw / mouth level
    (0.028, 0.060, 0.072, 0.020),   # hollow gaunt lower cheeks
    (0.054, 0.070, 0.080, 0.016),   # sharp projecting cheekbone crest
    (0.074, 0.073, 0.083, 0.014),   # lower eye socket rim
    (0.090, 0.074, 0.084, 0.012),   # eye center plane (+0.635 -> 1.60m world!)
    (0.112, 0.075, 0.086, 0.010),   # heavy overhanging brow shelf
    (0.136, 0.072, 0.082, 0.006),   # high pale forehead under brim
    (0.162, 0.064, 0.074, 0.002),
    (0.184, 0.046, 0.054, -0.002),
    (0.198, 0.022, 0.026, -0.004),  # crown top inside hat
]

head_rings = []
for y, rx, rz, cz in head_levels:
    ring = []
    for i in range(SEG_HEAD):
        theta = math.tau * i / SEG_HEAD
        nx = math.cos(theta)
        nz = math.sin(theta)
        x = nx * rx
        z = cz + nz * rz
        if nz > 0.12 and y > -0.032:
            # 1) Deep sunken pitch-black orbital cavities (y ~ 0.072..0.106)
            sock_l = math.exp(-((nx + 0.43) ** 2) / 0.052 - ((y - 0.087) ** 2) / 0.00028)
            sock_r = math.exp(-((nx - 0.41) ** 2) / 0.052 - ((y - 0.085) ** 2) / 0.00028)
            z -= 0.022 * max(sock_l, sock_r)
            # 2) Sharp overhanging brow shelf casting shadow down over eyes
            brow = math.exp(-(nx * nx) / 0.55 - ((y - 0.114) ** 2) / 0.00018)
            z += 0.014 * brow * max(0.0, nz)
            # 3) Long aquiline crooked nose ridge catching moonlight
            nose_b = math.exp(-((nx - 0.015) ** 2) / 0.020 - ((y - 0.068) ** 2) / 0.00075)
            nose_t = math.exp(-((nx - 0.020) ** 2) / 0.024 - ((y - 0.042) ** 2) / 0.00020)
            z += (0.017 * nose_b + 0.015 * nose_t) * max(0.0, nz)
            # 4) Emaciated jagged cheekbones + hollowed sunken cheeks below
            cheek_hi = math.exp(-((abs(nx) - 0.62) ** 2) / 0.055 - ((y - 0.056) ** 2) / 0.00018)
            cheek_lo = math.exp(-((abs(nx) - 0.50) ** 2) / 0.075 - ((y - 0.026) ** 2) / 0.00024)
            z += 0.010 * cheek_hi - 0.010 * cheek_lo
            x += math.copysign(0.006 * cheek_hi - 0.004 * cheek_lo, nx) if abs(nx) > 0.1 else 0.0
            # 5) Wide tight thin-lipped mouth slash (No, I'm Not a Human grim expression)
            mouth = math.exp(-(nx * nx) / 0.18 - ((y - 0.008) ** 2) / 0.000042)
            z -= 0.0075 * mouth
        ring.append((x, y, z))
    head_rings.append(ring)
loft_rings("HeadSculpt", head_rings, mat=CLOTH)

for sx in (-1.0, 1.0):
    ear_rings = []
    for ey, erx, erz in [(0.056, 0.004, 0.011), (0.078, 0.007, 0.014), (0.100, 0.005, 0.011)]:
        ering = []
        for i in range(10):
            th = math.tau * i / 10
            ering.append((sx * (0.071 + erx * 0.5 * math.cos(th)), ey, 0.004 + erz * math.sin(th)))
        ear_rings.append(ering)
    loft_rings("Ear" + ("L" if sx < 0 else "R"), ear_rings, mat=CLOTH)

head = bake("figure_head", CLOTH)


def head_pallor(p):
    # Deep pitch-black orbital cavities so white sclera + tiny pupils pop ruthlessly
    if 0.068 < p[1] < 0.106 and p[2] > 0.058 and 0.012 < abs(p[0]) < 0.056:
        return (0.025, 0.025, 0.032)
    # Dark throat collar shadow
    if p[1] < -0.045:
        return (0.14, 0.15, 0.18)
    # Heavy under-brim shadow above brow
    if p[1] > 0.120:
        return (0.15, 0.16, 0.20)
    # Thin grim mouth furrow stays dark
    if -0.001 < p[1] < 0.014 and abs(p[0]) < 0.034 and p[2] > 0.068:
        return (0.10, 0.10, 0.12)
    # Front-facing cheekbones, nose ridge, brow ridge, chin get cold corpse-ash pallor
    if p[2] > 0.056:
        return (0.86, 0.90, 0.96)
    return (0.48, 0.52, 0.58)


paint_color(head, head_pallor, multiply=False)
manifest["assemblies"]["figure_head"] = export(head, "figure_head.glb")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "window_figure_head.blend"))


# =========================================================================
# 3. CONTINUOUS BATTERED MINER'S SLOUCH HAT (atop taller head)
# =========================================================================
begin()
SEG_HAT = 32
SEAT = 0.138
hat_profile = [
    (SEAT + 0.004, 0.070, 0.074, 0.004, 0.0, 0.0),
    (SEAT - 0.004, 0.155, 0.162, 0.004, 0.45, 0.0),
    (SEAT + 0.000, 0.208, 0.214, 0.004, 1.0, 0.0),
    (SEAT + 0.008, 0.212, 0.218, 0.004, 1.0, 0.0),
    (SEAT + 0.016, 0.154, 0.160, 0.004, 0.45, 0.0),
    (SEAT + 0.022, 0.100, 0.106, 0.004, 0.0, 0.0),
    (SEAT + 0.038, 0.095, 0.101, 0.003, 0.0, 0.0),
    (SEAT + 0.072, 0.091, 0.098, 0.001, 0.0, 0.0),
    (SEAT + 0.108, 0.085, 0.092, 0.000, 0.0, 0.0),
    (SEAT + 0.136, 0.074, 0.084, -0.002, 0.0, 0.4),
    (SEAT + 0.140, 0.048, 0.062, -0.002, 0.0, 1.0),
]

hat_rings = []
for y, rx, rz, cz, brim_w, crown_w in hat_profile:
    ring = []
    for i in range(SEG_HAT):
        theta = math.tau * i / SEG_HAT
        c = math.cos(theta)
        s = math.sin(theta)
        brim_warp = brim_w * (-0.016 * max(0.0, s) - 0.012 * max(0.0, -c) * max(0.0, s + 0.3) + 0.010 * (1.0 - abs(s)))
        valley = -0.018 * crown_w * math.exp(-(c * c) / 0.16)
        pinch_in = 1.0 - (0.09 * smoothstep(0.06, 0.13, y - SEAT) * math.exp(-((abs(c) - 0.55) ** 2) / 0.14) if s > 0.25 else 0.0)
        ring.append((c * rx * pinch_in, y + brim_warp + valley, cz + s * rz))
    hat_rings.append(ring)

loft_rings("SlouchHat", hat_rings, mat=HAT, cap_low=True, cap_high=True)
hat = bake("figure_hat", HAT)
paint_color(hat, lambda p: 0.22 if p[1] < SEAT + 0.010 else None)
paint_color(hat, lambda p: 0.45 if p[1] < SEAT + 0.022 and (p[0] * p[0] + p[2] * p[2]) > 0.012 else None)
manifest["assemblies"]["figure_hat"] = export(hat, "figure_hat.glb")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "window_figure_hat.blend"))


# =========================================================================
# 4. WIDE-OPEN PALE UNBLINKING EYES + PINPOINT BLACK PUPILS
# =========================================================================
begin()
EYE_Y = 0.087
EYE_Z = 0.084
for side, sx, dy, rx_scl, ry_scl, p_off_x in (
    ("L", -1.0, 0.0014, 0.0112, 0.0064, 0.0005),
    ("R", 1.0, -0.0010, 0.0104, 0.0056, -0.0004),
):
    cx = sx * 0.0325
    cy = EYE_Y + dy
    # Pale cold sclera bulb
    sclera_rings = []
    for rz_off, scale_r in ((-0.0018, 1.0), (0.0006, 0.92), (0.0022, 0.55)):
        ring = []
        for i in range(14):
            th = math.tau * i / 14
            ring.append((
                cx + math.cos(th) * rx_scl * scale_r,
                cy + math.sin(th) * ry_scl * scale_r,
                EYE_Z + rz_off,
            ))
        sclera_rings.append(ring)
    loft_rings("Sclera" + side, sclera_rings, mat=CLOTH, smooth=True)

    # Pinpoint black pupil proud of the sclera center
    px = cx + p_off_x
    pupil_rings = []
    for rz_off, rad in ((0.0016, 0.0031), (0.0030, 0.0028), (0.0036, 0.0014)):
        ring = []
        for i in range(12):
            th = math.tau * i / 12
            ring.append((px + math.cos(th) * rad, cy + math.sin(th) * rad, EYE_Z + rz_off))
        pupil_rings.append(ring)
    loft_rings("Pupil" + side, pupil_rings, mat=CLOTH, smooth=True)

glints = bake("figure_eye_glints", CLOTH)


def eye_palette(p):
    # Tiny pupils at z > EYE_Z + 0.0024 and near either eye horizontal center are soot-black
    for cx_e in (-0.0320, 0.0321):
        if math.hypot(p[0] - cx_e, p[1] - EYE_Y) < 0.0038 and p[2] > EYE_Z + 0.0021:
            return (0.015, 0.015, 0.020)
    # Surrounding sclera catches cold pale moonlit contrast
    return (0.90, 0.93, 0.96)


paint_color(glints, eye_palette, multiply=False)
manifest["assemblies"]["figure_eye_glints"] = export(glints, "figure_eye_glints.glb")

manifest["pivots"] = {
    "figure_coat": "figure origin, boots at y = -0.94",
    "figure_head": "neck top (VisualIndicator-local y 0.545)",
    "figure_hat": "neck top (VisualIndicator-local y 0.545)",
    "figure_eye_glints": "neck top (VisualIndicator-local y 0.545)",
}
manifest["total_triangles"] = sum(a["triangles"] for a in manifest["assemblies"].values())
(OUT / "build_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

print("WINDOW_FIGURE_V3_BUILD_OK")
for name, stats in manifest["assemblies"].items():
    print("  %-18s tris=%4d verts=%4d aabb=%s"
          % (name, stats["triangles"], stats["vertices"], stats["aabb_godot"]))
print("  total triangles:", manifest["total_triangles"])
