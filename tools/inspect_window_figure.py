"""Form inspection for the authored window figure: clay lighting + silhouette.

The in-game look is an unshaded silhouette against a night sky, so the only
question that matters is the OUTLINE, plus how the face reads inside it when the
brim's shadow lifts. Two passes:

  clay        bright neutral key from camera, so the geometry is legible
  silhouette  single bright backdrop, all figure materials pure black

    blender -b -P tools/inspect_window_figure.py
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".dream-loop/window_figure_checkpoint/form"
OUT.mkdir(parents=True, exist_ok=True)
GLB = ROOT / "assets/models/window_figure_v1"

NECK = Vector((0.0, -0.012, 0.545))
TILT = math.radians(20.0)
SOLE_Z = -0.94


def gz(y):
    return y - 0.96


for old in list(bpy.data.objects):
    bpy.data.objects.remove(old, do_unlink=True)


def load(name, location, tilt=0.0):
    bpy.ops.import_scene.gltf(filepath=str(GLB / (name + ".glb")))
    obj = [o for o in bpy.context.selected_objects if o.type == "MESH"][0]
    obj.name = name
    obj.location = location
    if tilt:
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (0.0, -tilt, 0.0)
    return obj


FIG = [
    load("figure_coat", Vector((0.0, 0.0, 0.0))),
    load("figure_head", NECK, TILT),
    load("figure_hat", NECK, TILT),
    load("figure_eye_glints", NECK, TILT),
]

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 760
scene.render.resolution_y = 1000
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"

world = bpy.data.worlds.new("w")
bpy.context.scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
scene.camera = cam

CLAY = bpy.data.materials.new("clay")
CLAY.use_nodes = True
CLAY.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
    0.62, 0.60, 0.56, 1)
CLAY.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.72

BLACK = bpy.data.materials.new("black")
BLACK.use_nodes = True
BLACK.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
    0.0, 0.0, 0.0, 1)
BLACK.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0


def aim(eye, target):
    cam.location = Vector(eye)
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (Vector(target) - Vector(eye)).to_track_quat(
        "-Z", "Y")


def render(name, lens=45.0):
    cam.data.lens = lens
    scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    print("FORM", name)


KEY = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
KEY.data.energy = 260.0
KEY.data.size = 3.2
KEY.data.color = (1.0, 0.98, 0.94)
bpy.context.collection.objects.link(KEY)
KEY.location = (-1.8, -3.0, 2.4)
KEY.rotation_mode = "QUATERNION"
KEY.rotation_quaternion = (Vector((0, 0, 0.2)) - KEY.location).to_track_quat(
    "-Z", "Y")

FILL = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
FILL.data.energy = 70.0
FILL.data.size = 4.0
FILL.data.color = (0.55, 0.62, 0.78)
bpy.context.collection.objects.link(FILL)
FILL.location = (2.6, -1.4, 1.2)
FILL.rotation_mode = "QUATERNION"
FILL.rotation_quaternion = (Vector((0, 0, 0.0)) - FILL.location).to_track_quat(
    "-Z", "Y")

# --- pass 1: clay, four views -------------------------------------------
for obj in FIG:
    for slot in range(len(obj.material_slots)):
        obj.material_slots[slot].material = CLAY
bg.inputs[0].default_value = (0.20, 0.21, 0.23, 1)
bg.inputs[1].default_value = 0.6

bpy.ops.mesh.primitive_plane_add(size=9.0, location=(0.0, 0.0, SOLE_Z))
floor_obj = bpy.context.object
floor_obj.data.materials.append(CLAY)

aim((0.0, -2.95, gz(0.92)), (0.0, 0.0, gz(0.92)))
render("c01_front")
aim((-2.1, -2.1, gz(1.05)), (0.0, 0.0, gz(0.90)))
render("c02_three_quarter")
aim((-2.95, 0.0, gz(0.92)), (0.0, 0.0, gz(0.92)))
render("c03_side")
aim((0.0, 2.6, gz(0.95)), (0.0, 0.0, gz(0.92)))
render("c04_back")

aim((0.26, -0.60, gz(1.55)), (0.0, 0.0, gz(1.50)))
render("c05_head", lens=70.0)
aim((0.0, -0.72, gz(1.52)), (0.0, 0.0, gz(1.49)))
render("c06_face", lens=70.0)

# --- pass 2: silhouette on bright sky -----------------------------------
for obj in FIG:
    for slot in range(len(obj.material_slots)):
        obj.material_slots[slot].material = BLACK
floor_obj.hide_render = True
KEY.data.energy = 0.0
FILL.data.energy = 0.0
bg.inputs[0].default_value = (0.34, 0.42, 0.56, 1)
bg.inputs[1].default_value = 1.0

aim((0.0, -3.6, gz(1.16)), (0.0, 0.0, gz(0.80)))
render("s01_seated_view", lens=42.0)
aim((0.0, -2.95, gz(0.92)), (0.0, 0.0, gz(0.92)))
render("s02_front")
aim((-2.2, -2.0, gz(1.0)), (0.0, 0.0, gz(0.92)))
render("s03_three_quarter")
aim((0.0, -0.78, gz(1.50)), (0.0, 0.0, gz(1.46)))
render("s04_head", lens=66.0)
print("FORM_DONE")
