"""Preview the authored window figure the way the office sees it.

Not a game asset step - a check. Renders the four meshes assembled at their
scene transforms, from the two cameras that matter: the seated view through the
glass at ~3 m, and the yard closeup. Writes PNGs to .dream-loop/ under
window_figure_checkpoint/blender_preview/.

    blender -b -P tools/preview_window_figure.py
"""
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".dream-loop/window_figure_checkpoint/blender_preview"
OUT.mkdir(parents=True, exist_ok=True)
GLB = ROOT / "assets/models/window_figure_v1"

NECK = Vector((0.0, -0.012, 0.545))    # Blender coords of the neck pivot
TILT = math.radians(20.0)              # about Godot +Z, which is Blender -Y
SOLE_Z = -0.94


def gz(godot_world_y):
    """Office world height -> preview Blender z (soles at -0.94, yard at 0.96)."""
    return godot_world_y - 0.96


# Godot -> Blender for placement: (x, y, z)_godot -> (x, -z, y)_blender
def b(v):
    return Vector((v[0], -v[2], v[1]))


for old in list(bpy.data.objects):
    bpy.data.objects.remove(old, do_unlink=True)


def load(name, location, tilt_z=0.0):
    bpy.ops.import_scene.gltf(filepath=str(GLB / (name + ".glb")))
    obj = [o for o in bpy.context.selected_objects if o.type == "MESH"][0]
    obj.name = name
    obj.location = location
    if tilt_z:
        obj.rotation_mode = "XYZ"
        # Godot +Z rotation is Blender -Y rotation (both about the up axis)
        obj.rotation_euler = (0.0, -tilt_z, 0.0)
    return obj


coat = load("figure_coat", Vector((0, 0, 0)))
head = load("figure_head", NECK, TILT)
hat = load("figure_hat", NECK, TILT)
glints = load("figure_eye_glints", NECK, TILT)

# The yard at the figure's soles.
bpy.ops.mesh.primitive_plane_add(size=9.0, location=(0.0, 0.0, SOLE_Z))
ground = bpy.context.object
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.024, 0.032, 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
ground.data.materials.append(gm)

# A cold key from the moon's direction, high behind-left, plus a faint fill.
moon_data = bpy.data.lights.new("moon", "SUN")
moon_data.energy = 1.35
moon_data.color = (0.62, 0.72, 0.95)
moon = bpy.data.objects.new("moon", moon_data)
bpy.context.collection.objects.link(moon)
moon.rotation_euler = (math.radians(62.0), 0.0, math.radians(-142.0))

fill_data = bpy.data.lights.new("fill", "AREA")
fill_data.energy = 6.0
fill_data.size = 2.0
fill_data.color = (0.30, 0.36, 0.48)
fill = bpy.data.objects.new("fill", fill_data)
bpy.context.collection.objects.link(fill)
fill.location = (0.0, -2.4, 0.4)          # behind the figure, rimming the edge
fill.rotation_euler = (math.radians(108.0), 0.0, math.radians(180.0))

world = bpy.data.worlds.new("w")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.043, 0.062, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
scene.camera = cam

HEAD_WORLD = NECK + Vector((0.0, 0.06, 0.0))   # roughly, for aiming


def shoot(name, eye, target, lens=68.0):
    """eye/target in Blender coordinates; the room is -y, the yard +y."""
    cam.location = Vector(eye)
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (Vector(target) - Vector(eye)).to_track_quat(
        "-Z", "Y")
    cam.data.lens = lens
    scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", name)


# 1. Seated at the desk looking out: eye at world 1.24, figure 3.1 m beyond the
#    glass, the frame carrying the whole man and a little yard either side.
shoot("p01_seated_stage_b", (0.0, -2.60, gz(1.24)), (0.0, 0.0, gz(0.62)), 44.0)
# 2. Leaning toward the glass, aimed at the head, tighter.
shoot("p02_seated_lean", (0.0, -1.55, gz(1.36)), (0.0, 0.0, gz(1.46)), 58.0)
# 3. Yard closeup, 1.6 m, three-quarter: what an inspection camera sees.
shoot("p03_closeup_three_quarter", (1.28, -1.05, gz(1.42)),
      (0.0, 0.0, gz(1.34)), 48.0)
# 4. Full figure, front elevation: proportions and ground contact.
shoot("p04_front_elevation", (0.0, -2.90, gz(0.98)), (0.0, 0.0, gz(0.98)), 40.0)
# 5. Head only, close: the face, the brim, the sockets.
shoot("p05_head_close", (0.30, -0.62, gz(1.52)), (0.0, 0.0, gz(1.51)), 62.0)
print("PREVIEWS_DONE")
