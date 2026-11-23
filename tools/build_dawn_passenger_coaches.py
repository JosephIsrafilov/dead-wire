"""Author the three No. 17 cars in Blender (metres, +X forward, +Z up).

Run with Blender --background --factory-startup --python this_file.py.
Overwrites only the three coach GLBs and the local editable review blend.
"""
from math import cos, pi, sin
from pathlib import Path
from random import Random

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/models/dawn_train"
REVIEW = ROOT / ".dream-loop/coach-polish"


def paint(name, rgb, rough=0.84, metal=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    return mat


CHARCOAL = paint("Sooted canvas", (.057, .066, .071), .93)
SEAM = paint("Canvas seam and drip iron", (.028, .034, .039))
IRON = paint("Oxidized underframe", (.039, .049, .052), .79, .22)
TREAD = paint("Rubbed wheel rims", (.13, .14, .145), .55, .34)
GILT = paint("Old ochre paint", (.44, .288, .105), .87, glow=.10)
WOOD = paint("Worn sash oak", (.209, .114, .052), .82, glow=.07)
SHADE = paint("Window recess", (.029, .024, .022))
FABRIC = paint("Tobacco linen", (.24, .13, .065), .95, glow=.31)
SHADE_FABRIC = paint("Linen folds", (.14, .068, .036), .97, glow=.20)
GLASS = [paint(f"Lamp behind glass — {i}", rgb, .58, glow=power) for i, (rgb, power) in enumerate([
    ((.79, .44, .18), .69), ((.62, .305, .106), .53), ((.33, .157, .056), .43),
    ((.095, .079, .063), .09),
])]
RED = paint("Ruby marker glass", (.75, .062, .026), .51, glow=1.35)


def palette(label, rgb):
    return tuple(paint(f"{label} — {key}", tuple(v * factor for v in rgb), glow=.13)
                 for key, factor in (("paint", 1), ("shadow", .63), ("worn edge", 1.42)))


MAROON = palette("Old wine coach paint", (.151, .051, .041))
OLIVE = palette("Old olive baggage paint", (.097, .118, .080))
REDWOOD = palette("Red oxide conductor paint", (.178, .070, .046))


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def box(name, x, y, z, dx, dy, dz, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    for v in obj.data.vertices:
        v.co.x *= dx
        v.co.y *= dy
        v.co.z *= dz
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Worn corners", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def beam(name, a, b, width, depth, mat):
    a, b = Vector(a), Vector(b)
    offset = b - a
    obj = box(name, *((a + b) * .5), width, depth, offset.length, mat)
    obj.rotation_euler = offset.to_track_quat('Z', 'Y').to_euler()


def cylinder(name, a, b, radius, mat, sides=12):
    a, b = Vector(a), Vector(b)
    offset = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=offset.length,
                                       location=(a + b) * .5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = offset.to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(mat)
    return obj


def extrude(name, profile, y0, y1, mat):
    """Give a side-on silhouette thickness. Profile coordinates are (x,z)."""
    n = len(profile)
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces.extend((i, (i+1) % n, (i+1) % n + n, i+n) for i in range(n))
    return mesh(name, [(x, y, z) for y in (y0, y1) for x, z in profile], faces, mat)


def ring(name, outer, inner, y0, y1, mat):
    n = len(outer)
    verts = [(x, y, z) for y in (y0, y1) for p in (outer, inner) for x, z in p]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.extend([(i, j, n+j, n+i), (2*n+i, 3*n+i, 3*n+j, 2*n+j),
                      (i, 2*n+i, 2*n+j, j), (n+i, n+j, 3*n+j, 3*n+i)])
    mesh(name, verts, faces, mat)


def opening(x, z0, z1, width, corner=.105):
    half = width / 2
    return [(x-half, z0), (x+half, z0), (x+half, z1-corner),
            (x+half-corner, z1), (x-half+corner, z1), (x-half, z1-corner)]


def window(x, side, z0, z1, w, light, curtain=0):
    # The wall is built around this opening. Sash, glass and curtain sit at three depths.
    o = opening(x, z0, z1, w)
    inset = opening(x, z0+.072, z1-.072, w-.144, .085)
    ring("Deep window jamb", o, inset, side*1.255, side*1.116, SHADE)
    ring("Carved oak sash", opening(x, z0-.045, z1+.045, w+.09), inset,
         side*1.295, side*1.245, WOOD)
    extrude("Lamplit glass", inset, side*1.045, side*1.05, GLASS[light])
    box("Sash meeting rail", x, side*1.27, z0 + (z1-z0)*.64, w-.06, .06, .043, WOOD)
    box("Window sill", x, side*1.304, z0-.048, w+.135, .13, .074, WOOD, .014)
    if curtain:
        # The hand-drawn folds interrupt the rectangular light without a transparency sort.
        left = x - w*.43
        right = x + w*.43
        for sign in (-1, 1):
            edge = left if sign < 0 else right
            end = edge - sign * w * (.26 if sign == curtain else .12)
            points = [(edge, z0+.075), (end, z0+.075), (end-sign*.052, z1-.095), (edge, z1-.09)]
            extrude("Parted linen curtain", points, side*1.09, side*1.10, FABRIC)
            for i in (1, 2):
                u = i / 3
                xx = edge + (end-edge)*u
                beam("Curtain fold", (xx, side*1.106, z0+.08),
                     (xx-sign*.052*u, side*1.106, z1-.11), .023, .010, SHADE_FABRIC)


def roof(name, half, width, base, rise, mat, cap=.26):
    """Segmented barrel roof with dropped eaves and shaped ends."""
    profile = [(-width*cos(pi*i/12), base + rise*sin(pi*i/12)) for i in range(13)]
    profile += [(width, base-.09), (-width, base-.09)]
    n = len(profile)
    stations = [(-half, .95, -.075), (-half+cap, 1, 0), (half-cap, 1, 0), (half, .95, -.075)]
    verts = [(x, y*s, z+h) for x, s, h in stations for y, z in profile]
    faces = [tuple(reversed(range(n))), tuple(range(3*n, 4*n))]
    for j in range(3):
        for i in range(n):
            k = (i+1) % n
            faces.append((j*n+i, j*n+k, (j+1)*n+k, (j+1)*n+i))
    obj = mesh(name, verts, faces, mat)
    for face in obj.data.polygons:
        face.use_smooth = face.index >= n+2 and face.index < 2*n-1
    return obj


def boards(name, x0, x1, y, low, high, colors, seed):
    rng = Random(seed)
    count = max(1, round((x1-x0)/.165))
    step = (x1-x0)/count
    for i in range(count):
        box(name, x0+(i+.5)*step, y, (low+high)/2, step-.008, .067, high-low,
            rng.choices(colors, (7, 2, 1))[0])


def lettering(text, side, x, z, target_height):
    font = bpy.data.curves.new(text, "FONT")
    font.body, font.align_x, font.align_y = text, "CENTER", "CENTER"
    font.space_character = 1.23
    font.resolution_u = 4
    # Use the bundled font when running without system fonts; export only the letter meshes.
    serif = Path("C:/Windows/Fonts/georgia.ttf")
    if serif.is_file():
        font.font = bpy.data.fonts.load(str(serif), check_existing=True)
    obj = bpy.data.objects.new(text, font)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(GILT)
    obj.location = (x, side*1.277, z)
    obj.rotation_euler = (pi/2, 0, 0 if side < 0 else pi)
    bpy.context.view_layer.update()
    raw = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    height = max(v.co.y for v in raw.vertices) - min(v.co.y for v in raw.vertices)
    bpy.data.meshes.remove(raw)
    scale = target_height / height
    obj.scale = (scale, scale, scale)


def frame(half):
    box("Oak underframe", 0, 0, 1.11, 2*half+.90, 2.27, .30, IRON, .064)
    box("Cabin floor", 0, 0, 1.34, 2*half+.08, 2.43, .20, SHADE, .05)
    pivot = half - 1.37
    for x in (-pivot, pivot):
        box("Truck transom", x, 0, .86, 1.73, 1.77, .23, IRON, .07)
        for ax in (x-.67, x+.67):
            cylinder("Wheel axle", (ax,-.89,.49), (ax,.89,.49), .10, IRON)
            for side in (-1, 1):
                cylinder("Cast wheel", (ax,side*.639,.49), (ax,side*.80,.49), .425, IRON, 16)
                cylinder("Steel tread", (ax,side*.752,.49), (ax,side*.79,.49), .431, TREAD, 16)
                cylinder("Inset wheel web", (ax,side*.79,.49), (ax,side*.808,.49), .336, IRON, 14)
                box("Journal box", ax, side*.91, .57, .30, .22, .27, IRON, .034)
        for side in (-1, 1):
            y = side*.92
            box("Truck side frame", x, y, .69, 1.80, .14, .16, IRON, .024)
            for dz in (0, .045, .09):
                beam("Leaf spring", (x-.36,y,.64+dz), (x,y,.53+dz), .027, .092, TREAD)
                beam("Leaf spring", (x,y,.53+dz), (x+.36,y,.64+dz), .027, .092, TREAD)
    for sign in (-1, 1):
        x = sign*(half+.47)
        box("End platform and buffer beam", x, 0, 1.23, .86, 2.35, .26, IRON, .041)
        cylinder("Drawbar", (x,0,.87), (sign*(half+1.21),0,.87), .090, IRON)
        box("Knuckle", sign*(half+1.19), 0, .87, .14, .23, .16, IRON, .025)
        for side in (-1, 1):
            y = side*1.1
            for i in range(3):
                box("Boarding steps", x, side*(1.17+.065*i), 1.15-.22*i,
                    .51, .32, .082, IRON, .02)
            for xx in (sign*(half+.12), sign*(half+.83)):
                beam("Platform stanchion", (xx,y,1.30), (xx,y,2.20), .048, .05, IRON)
            beam("Boarding handrail", (sign*(half+.12),y,2.20), (sign*(half+.83),y,2.20), .057, .075, WOOD)
            beam("End gate", (sign*(half+.83),y,2.19), (sign*(half+.83),side*.44,2.19), .047, .053, IRON)
            beam("Truss rod", (-half, y*.77, 1.04), (-half*.40, y*.77, .79), .038, .039, IRON)
            beam("Truss rod", (half, y*.77, 1.04), (half*.40, y*.77, .79), .038, .039, IRON)
            beam("Truss tie", (-half*.40, y*.77, .79), (half*.40, y*.77, .79), .038, .039, IRON)


def car(name, half, colors, windows, label, number, kind):
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    base, dark, edge = colors
    eaves = 3.14 if kind != "guard" else 2.98
    frame(half)
    for sign in (-1, 1):
        box("Enclosed end wall", sign*(half-.063), 0, (1.40+eaves)/2, .126, 2.43, eaves-1.40, base, .037)
        box("Recessed vestibule door", sign*(half+.012), 0, 2.11, .065, .78, 1.53, dark, .037)
        box("Vestibule door glazing", sign*(half+.048), 0, 2.53, .016, .41, .41, GLASS[2], .016)
        cylinder("End grab iron", (sign*(half+.112),.49,1.62), (sign*(half+.112),.49,2.52), .033, IRON)
    for side in (-1, 1):
        y = side*1.221
        lo = 2.19 if kind != "guard" else 2.10
        hi = 2.83 if kind != "guard" else 2.69
        box("Lower wall backing", 0, side*1.174, 1.80, 2*half-.06, .09, .80, dark)
        boards("Vertical tongue and groove", -half, half, y, 1.44, lo-.046, colors, 14+side)
        box("Letterboard", 0, y, (hi+eaves)/2, 2*half, .079, eaves-hi, dark, .019)
        last = -half
        for x, w, light, curtain in windows:
            a, b = x-w/2, x+w/2
            if a > last:
                box("Solid mullion wall", (last+a)/2, y, (lo+hi)/2, a-last, .078, hi-lo, base)
            for edge_x, direction in ((a, 1), (b, -1)):
                extrude("Arched window shoulder", [(edge_x,hi-.105), (edge_x+direction*.105,hi), (edge_x,hi)],
                        side*1.17, side*1.26, base)
            window(x, side, lo, hi, w, light, curtain)
            last = b
        box("Solid tail panel", (last+half)/2, y, (lo+hi)/2, half-last, .078, hi-lo, base)
        for z, height, mat in ((1.49,.09,dark), (1.58,.027,GILT), (lo-.118,.035,GILT),
                               (hi+.075,.022,edge), (eaves-.04,.082,edge)):
            box("Moulded side rail", 0, side*1.273, z, 2*half-.045, .062, height, mat, .009)
        for x in (-half+.105, half-.105):
            box("Carriage corner pillar", x, side*1.278, (1.44+eaves)/2, .15, .093, eaves-1.44, edge, .032)
        if kind == "mail":
            box("Sliding freight door", .62, side*1.31, 2.14, 2.42, .13, 1.48, dark, .04)
            boards("Loading door planks", -.53, 1.77, side*1.376, 1.46, 2.81, colors, 73)
            box("Door track", .92, side*1.407, 2.93, 3.52, .093, .073, IRON, .022)
            for x in (-.39, 1.62):
                box("Sliding door strap", x, side*1.421, 2.19, .10, .05, 1.31, IRON)
            for z in (1.58, 2.71):
                box("Door crosspiece", .62, side*1.424, z, 2.27, .079, .079, edge, .012)
            beam("Diagonal loading door brace", (-.46,side*1.425,1.64), (1.70,side*1.425,2.65), .105, .079, edge)
            cylinder("Sliding door handle", (-.22,side*1.454,1.95), (-.22,side*1.454,2.29), .032, IRON)
            lettering(label, side, -2.94, 1.89, .192)
        else:
            lettering(label, side, 0, 1.88, .192)
        lettering(number, side, side*(-half+.53), 1.83, .154)

    roof("Swept canvas roof", half + .82, 1.39, eaves, .245, CHARCOAL)
    for side in (-1, 1):
        box("Eave gutter", 0, side*1.374, eaves-.026, 2*half+1.43, .067, .075, SEAM, .018)
    if kind == "passenger":
        box("Raised clerestory wall", 0, 0, eaves+.27, half*1.70, 1.42, .285, dark, .112)
        roof("Clerestory crown", half*.90, .78, eaves+.362, .150, CHARCOAL)
        for side in (-1, 1):
            for x, _, light, _ in windows:
                box("Clerestory ventilator", x*.91, side*.708, eaves+.315, .43, .042, .113,
                    GLASS[min(light+1, 3)], .021)
    elif kind == "mail":
        for x in (-2.4, 2.65):
            cylinder("Stove chimney", (x,0,eaves+.17), (x,0,eaves+.39), .095, IRON)
            cylinder("Chimney cap", (x,0,eaves+.39), (x,0,eaves+.43), .145, CHARCOAL)
    else:
        x = -1.43
        box("Conductor lookout", x, 0, eaves+.372, 2.02, 1.89, .63, base, .09)
        canopy = roof("Lookout cap", 1.15, 1.04, eaves+.641, .134, CHARCOAL)
        canopy.location.x = x
        for side in (-1, 1):
            for xx in (x-.463, x+.463):
                box("Lookout window frame", xx, side*.944, eaves+.445, .67, .091, .345, SHADE, .051)
                box("Lookout dim glass", xx, side*.991, eaves+.445, .48, .005, .218, GLASS[2], .035)
            y = side*1.16
            xx = -half-.38
            cylinder("Marker lantern body", (xx,y,2.22), (xx,y,2.61), .123, IRON)
            cylinder("Visible side marker lens", (xx,y,2.42), (xx,y+side*.134,2.42), .086, RED)
            cylinder("Rear marker lens", (xx,y,2.42), (xx-.136,y,2.42), .086, RED)
    return scene


def export(scene, filename):
    """Join evaluated copies for one render mesh; keep the source editable."""
    bpy.context.window.scene = scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts = [(bpy.data.meshes.new_from_object(src.evaluated_get(depsgraph)), src.matrix_world.copy())
             for src in scene.objects]
    staging = bpy.data.scenes.new("Coach export")
    bpy.context.window.scene = staging
    copies = []
    for data, transform in parts:
        obj = bpy.data.objects.new("Export part", data)
        staging.collection.objects.link(obj)
        obj.matrix_world = transform
        obj.select_set(True)
        copies.append(obj)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = scene.name
    result = bpy.ops.export_scene.gltf(filepath=str(ASSETS / filename), export_format="GLB",
                                       use_selection=True, use_active_scene=True,
                                       export_animations=False, export_cameras=False, export_lights=False)
    if 'FINISHED' not in result:
        raise RuntimeError(f"Could not export {filename}")
    data = joined.data
    bpy.context.window.scene = scene
    bpy.data.scenes.remove(staging)
    bpy.data.objects.remove(joined, do_unlink=True)
    for part, _ in parts:
        if part != data and part.users == 0:
            bpy.data.meshes.remove(part)
    bpy.data.meshes.remove(data)


def build():
    if not bpy.app.background:
        raise RuntimeError("Run on a separate Blender background process, not the open user file.")
    ASSETS.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    initial = bpy.context.scene
    passenger = [(-4.24, .70, 1, -1), (-2.83, .77, 0, 1), (-1.41, .77, 1, 0),
                 (0, .77, 3, -1), (1.41, .77, 0, 1), (2.83, .77, 2, -1), (4.24, .70, 1, 0)]
    designs = [
        (car("No. 08 — Passenger", 5.29, MAROON, passenger, "BLACK CREEK & WESTERN", "08", "passenger"),
         "passenger_coach.glb"),
        (car("No. 12 — Baggage & Mail", 5.01, OLIVE,
             [(-3.62,.57,2,0), (-2.46,.57,3,0), (3.52,.54,2,0)], "BAGGAGE & MAIL", "12", "mail"),
         "baggage_mail_car.glb"),
        (car("No. 04 — Conductor", 3.88, REDWOOD,
             [(-2.44,.59,2,-1), (-1.49,.59,2,1), (1.76,.60,1,-1), (2.70,.60,3,0)],
             "BLACK CREEK & WESTERN", "04", "guard"), "guard_observation_car.glb"),
    ]
    bpy.data.scenes.remove(initial)
    for scene, filename in designs:
        export(scene, filename)
    bpy.context.window.scene = designs[0][0]
    bpy.ops.wm.save_as_mainfile(filepath=str(REVIEW / "No17_Coaches.blend"), compress=True)


if __name__ == "__main__":
    build()
