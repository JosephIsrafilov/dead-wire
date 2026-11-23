"""Build the No. 17 locomotive and tender. Blender metres, +X forward."""
from math import cos, pi, sin
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/models/dawn_train"
DEST.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new("Black Creek & Western — No. 17")
bpy.context.window.scene = scene
collection = bpy.data.collections.new("No. 17 — American 4-4-0")
scene.collection.children.link(collection)


def material(name, color, metal=0.0, glow=0.10):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.7
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = glow
    return mat


iron = material("Sooted cast iron", (0.047, 0.056, 0.061), 0.62)
steel = material("Dull slate boiler jacket", (0.058, 0.066, 0.072), 0.32, 0.035)
tread = material("Worn steel tread", (0.092, 0.095, 0.094), 0.36, 0.08)
red = material("Oxblood paint", (0.097, 0.043, 0.031), glow=0.035)
brass = material("Dulled brass", (0.128, 0.103, 0.057), 0.52, 0.025)
coal = material("Coal", (0.026, 0.022, 0.019))
wood = material("Weathered cab paint", (0.052, 0.064, 0.053), glow=0.035)
glass = material("Warm headlight", (0.92, 0.65, 0.29), glow=2.1)


def attach(name, mat):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def box(name, point, size, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = attach(name, mat)
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Worn edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return obj


def cone(name, start, end, r0, r1, mat, sides=12):
    start, end = Vector(start), Vector(end)
    axis = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=r0, radius2=r1, depth=axis.length, location=(start + end) / 2)
    obj = attach(name, mat)
    obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    return obj


def rod(name, start, end, radius, mat, sides=12):
    return cone(name, start, end, radius, radius, mat, sides)


def wheel_tire(x, y, z, radius, side):
    segments = 24
    profile = [(radius, -0.065), (radius, 0.065),
               (radius - 0.098, 0.065), (radius - 0.098, -0.065)]
    vertices = []
    for r, lateral in profile:
        for i in range(segments):
            angle = 2 * pi * i / segments
            vertices.append((x + r * cos(angle), y + lateral, z + r * sin(angle)))
    faces = []
    for ring in range(len(profile)):
        this_ring = ring * segments
        next_ring = (ring + 1) % len(profile) * segments
        for i in range(segments):
            following = (i + 1) % segments
            faces.append((this_ring + i, next_ring + i, next_ring + following, this_ring + following))
    mesh = bpy.data.meshes.new("Open wheel tire")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(iron)
    mesh.materials.append(tread)
    visible_rings = (0, 1 if side > 0 else 3)
    for face in mesh.polygons:
        ring = face.index // segments
        face.material_index = int(ring in visible_rings)
        face.use_smooth = ring == 0
    collection.objects.link(bpy.data.objects.new("Open wheel tire", mesh))


box("Locomotive frame", (-0.60, 0, 0.93), (7.45, 2.30, 0.42), iron, 0.07)
box("Pilot beam", (3.43, 0, 0.85), (0.26, 2.58, 0.34), red, 0.025)
rod("Boiler jacket", (-2.20, 0, 1.94), (2.23, 0, 1.94), 0.79, steel, 16)
rod("Smokebox", (2.10, 0, 1.94), (3.10, 0, 1.94), 0.76, iron, 16)
cone("Smokebox door", (3.09, 0, 1.94), (3.30, 0, 1.94), 0.70, 0.58, iron, 16)
rod("Door latch", (3.31, 0, 1.97), (3.34, 0.24, 1.97), 0.026, brass, 8)
for x in (-1.83, -0.75, 0.65, 1.85):
    rod("Boiler band", (x - 0.028, 0, 1.94), (x + 0.028, 0, 1.94), 0.807, iron, 16)
for i in range(12):
    angle = i * pi / 6
    y, z = 0.65 * cos(angle), 1.94 + 0.65 * sin(angle)
    rod("Smokebox rivet", (3.14, y, z), (3.20, y, z), 0.026, brass, 6)

rod("Stack base", (2.45, 0, 2.56), (2.45, 0, 2.90), 0.27, iron)
cone("Tapered stack", (2.45, 0, 2.88), (2.45, 0, 3.64), 0.163, 0.19, iron)
rod("Stack lip", (2.45, 0, 3.62), (2.45, 0, 3.73), 0.225, iron)
rod("Steam dome", (-0.95, 0, 2.57), (-0.95, 0, 3.00), 0.29, brass)
cone("Steam dome cap", (-0.95, 0, 2.99), (-0.95, 0, 3.20), 0.29, 0.14, brass)
rod("Sand dome", (0.58, 0, 2.61), (0.58, 0, 2.96), 0.25, steel)
cone("Bell", (1.32, 0, 2.78), (1.32, 0, 3.10), 0.21, 0.10, brass)
box("Lamp stand", (3.02, 0, 2.68), (0.32, 0.33, 0.28), iron)
box("Headlight housing", (3.04, 0, 2.91), (0.43, 0.53, 0.55), iron, 0.055)
rod("Headlight bezel", (3.24, 0, 2.91), (3.31, 0, 2.91), 0.208, brass)
rod("Headlight glass", (3.30, 0, 2.91), (3.33, 0, 2.91), 0.176, glass)
for i in range(-5, 6):
    y = i * 0.205
    rod("Pilot slat", (3.46, y, 0.76), (4.15 - 0.34 * abs(y), 0.88 * y, 0.17), 0.045, red, 6)

for side in (-1, 1):
    y = side * 1.05
    rod("Handrail", (-2.2, side * 0.79, 2.22), (2.83, side * 0.74, 2.22), 0.027, brass, 8)
    box("Running board", (0.12, y, 1.37), (5.22, 0.34, 0.105), iron, 0.026)
    box("Cab side", (-3.20, side * 1.14, 1.87), (2.03, 0.115, 1.08), wood, 0.025)
    box("Cab waist stripe", (-3.18, side * 1.202, 2.36), (2.01, 0.017, 0.054), brass)
    for x in (-4.18, -3.23, -2.21):
        box("Cab window post", (x, side * 1.14, 2.81), (0.115, 0.125, 0.90), wood, 0.018)
    box("Cab step", (-4.00, side * 1.22, 0.97), (0.37, 0.35, 0.10), steel, 0.023)
    box("Cab upper lintel", (-3.20, side * 1.14, 3.12), (2.13, 0.12, 0.30), wood, 0.02)
    box("Cab interior", (-2.36, side * 0.60, 2.42), (0.16, 0.79, 1.58), iron, 0.03)

    # The main line has wheel contact at Y +/-0.72 m and rail heads at Z 0.06 m.
    wheel_y = side * 0.72
    driver_radius = 0.8382  # Baldwin's 66-inch driver, 1889.
    for x, radius, spokes in [
        (-2.81, driver_radius, 12), (-0.98, driver_radius, 12), (1.37, 0.38, 8), (2.41, 0.38, 8),
        (-5.33, 0.41, 8), (-6.28, 0.41, 8), (-7.52, 0.41, 8), (-8.47, 0.41, 8),
    ]:
        z = radius + 0.06
        wheel_tire(x, wheel_y, z, radius, side)
        rod("Axle hub", (x, wheel_y - 0.086, z), (x, wheel_y + 0.086, z), radius * 0.18, iron)
        for spoke in range(spokes):
            angle = spoke * 2 * pi / spokes
            end = (x + (radius - 0.06) * cos(angle), wheel_y, z + (radius - 0.06) * sin(angle))
            rod("Cast spoke", (x, wheel_y, z), end, max(0.021, radius * 0.037), iron, 7)
    link_y = wheel_y + side * 0.145
    pin_z = driver_radius + 0.06 - 0.105
    rear_pin, front_pin = -2.81 + 0.17, -0.98 + 0.17
    for pin in (rear_pin, front_pin):
        rod("Driving crank pin", (pin, wheel_y, pin_z), (pin, link_y, pin_z), 0.091, iron, 9)
    rod("Coupling rod", (rear_pin, link_y, pin_z), (front_pin, link_y, pin_z), 0.048, steel, 8)
    rod("Main rod", (front_pin, link_y, pin_z), (1.80, link_y, 1.03), 0.057, steel, 8)
    box("Piston casing", (1.88, link_y, 1.03), (0.64, 0.39, 0.44), iron, 0.07)

box("Pilot truck bolster", (1.89, 0, 0.64), (1.61, 1.38, 0.21), iron, 0.045)
for center in (-5.81, -8.00):
    box("Tender bogie", (center, 0, 0.63), (1.53, 1.51, 0.31), iron, 0.05)

roof_profile = [(-1.30, 3.17), (-1.04, 3.35), (-0.58, 3.46), (0, 3.51),
                (0.58, 3.46), (1.04, 3.35), (1.30, 3.17)]
roof_verts = [(x, y, z) for x in (-4.41, -2.00) for y, z in roof_profile]
roof_faces = [(i, i + 1, i + 8, i + 7) for i in range(6)]
roof_mesh = bpy.data.meshes.new("Cab roof profile")
roof_mesh.from_pydata(roof_verts, [], roof_faces)
roof_mesh.materials.append(iron)
roof = bpy.data.objects.new("Arched cab roof", roof_mesh)
collection.objects.link(roof)
roof.modifiers.new("Sheet metal thickness", "SOLIDIFY").thickness = 0.046
box("Cab floor", (-3.22, 0, 1.30), (2.10, 2.28, 0.17), iron)

box("Tender chassis", (-6.63, 0, 0.83), (4.24, 2.30, 0.36), iron, 0.05)
box("Tender tank", (-6.70, 0, 1.57), (4.13, 2.40, 1.39), steel, 0.078)
box("Tender trim", (-6.70, 0, 2.20), (4.23, 2.48, 0.075), red, 0.025)
box("Coal bunker", (-6.08, 0, 2.22), (2.40, 1.98, 0.27), coal, 0.14)
for i in range(12):
    x = -7.00 + (i % 4) * 0.56
    y = -0.63 + (i // 4) * 0.62
    lump = box("Broken coal", (x, y, 2.34 + 0.05 * (i % 3)), (0.46, 0.39, 0.28), coal, 0.11)
    lump.rotation_euler.z = (i % 5) * 0.3
rod("Tender water cap", (-8.14, 0, 2.21), (-8.14, 0, 2.39), 0.28, iron)

for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = collection.objects["Boiler jacket"]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
bpy.context.object.name = "No. 17 — Locomotive and tender"
bpy.ops.export_scene.gltf(filepath=str(DEST / "no17.glb"), use_selection=True, use_active_scene=True, export_format="GLB")
print(f"No. 17 exported to {DEST / 'no17.glb'}")
