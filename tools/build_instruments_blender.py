"""Authored stylized telegraph instruments; run with Blender 5.x Python.
Builds only a new collection, leaves all unrelated scene objects intact.
Coordinates supplied in Godot metres; exports seven isolated moving/static meshes.
No downloaded meshes or image textures; no museum image reproduction.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/instruments_v1'
OUT.mkdir(parents=True, exist_ok=True)
TEX = ROOT / 'assets/textures/instruments_v1'
TEX.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'docs/art/state_2026-10-10/instruments/sources'
SOURCE.mkdir(parents=True, exist_ok=True)
COLLECTION = 'DW_Instruments_v1'
old = bpy.data.collections.get(COLLECTION)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
coll = bpy.data.collections.new(COLLECTION)
bpy.context.scene.collection.children.link(coll)
# Six 64px tiles in a 256px atlas. Spare tiles remain dark.
TILES = {'wood': (0, 0), 'brass': (1, 0), 'iron': (2, 0),
         'coil': (3, 0), 'ebonite': (0, 1), 'paper': (1, 1)}
COLORS = {'wood': (87, 53, 32), 'brass': (151, 121, 70), 'iron': (52, 53, 51),
          'coil': (63, 48, 36), 'ebonite': (33, 29, 24), 'paper': (166, 152, 123)}
rng = random.Random(1894)
image = bpy.data.images.new('DW_Instrument_Atlas_256', width=256, height=256)
pixels = [0.025, 0.022, 0.02, 1.0] * (256 * 256)
for kind, (tx, ty) in TILES.items():
    base = COLORS[kind]
    for y in range(64):
        for x in range(64):
            noise = rng.uniform(-3, 3)
            if kind == 'wood':
                detail = 6 * math.sin(x * .58 + 1.8 * math.sin(y * .08)) + 3 * math.sin(x * 2.0)
            elif kind == 'coil':
                detail = -14 if y % 5 == 0 else (6 if y % 5 == 1 else -1)
            elif kind == 'brass':
                detail = 5 * math.sin(x * .21) * math.sin(y * .13)
                if ((x - 17) ** 2 + (y - 42) ** 2) < 54:
                    detail -= 13
            elif kind == 'iron':
                detail = 3 * math.sin(x * .43 + y * .31)
            elif kind == 'paper':
                detail = 2 * math.sin(y * .7)
            else:
                detail = 1.5 * math.sin(x * .2)
            idx = ((ty * 64 + y) * 256 + tx * 64 + x) * 4
            for c in range(3):
                # Restrained quantized values, not universal high-frequency grime.
                pixels[idx+c] = round(max(0, min(255, base[c] + detail + noise)) / 8) * 8 / 255
            pixels[idx+3] = 1
image.pixels.foreach_set(pixels)
image.filepath_raw = str(TEX / 'instrument_atlas_256.png')
image.file_format = 'PNG'
image.save()
image.pack()
materials = {}
for kind in TILES:
    mat = bpy.data.materials.new('dw_' + kind)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .65 if kind == 'brass' else .88
    bsdf.inputs['Metallic'].default_value = .5 if kind in ('brass', 'iron') else 0
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.interpolation = 'Closest'
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    materials[kind] = mat

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
    # Primitive UVs are predictable; inset tile borders prevent neighbouring tile bleed.
    if not obj.data.uv_layers:
        obj.data.uv_layers.new()
    tx, ty = TILES[kind]
    for uv in obj.data.uv_layers.active.data:
        uv.uv.x = (tx*64 + 2 + (uv.uv.x % 1.000001)*60) / 256
        uv.uv.y = (ty*64 + 2 + (uv.uv.y % 1.000001)*60) / 256
    for face in obj.data.polygons:
        face.use_smooth = False
    parts.append(obj)
    return obj

def box(name, centre, size, kind, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos(centre))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Authored edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, kind)

def cyl(name, centre, radius, depth, kind, axis=(0, 1, 0), sides=12, radius_top=None):
    loc = pos(centre)
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius_top, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(pos(axis).normalized())
    return finish(obj, kind)

def rod(name, a, b, radius, kind, sides=8):
    av, bv = Vector(a), Vector(b)
    return cyl(name, (av+bv)*.5, radius, (bv-av).length, kind, bv-av, sides)

def screw(name, centre, radius=.003, height=.004, axis=(0,1,0)):
    cyl(name, centre, radius, height, 'brass', axis, 10)
    if tuple(axis) == (0,1,0):
        c = Vector(centre) + Vector((0,height*.505,0))
        box(name+'_slot', c, (radius*1.5,.00015,radius*.25), 'ebonite')

def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Bake a deterministic explicit triangle mesh for identical Godot topology.
    tri = obj.modifiers.new('Export triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB',
        use_selection=True, export_apply=True, export_yup=True, export_texcoords=True,
        export_normals=True, export_materials='EXPORT', export_cameras=False,
        export_lights=False, export_animations=False)
    report[name] = {'triangles':len(obj.data.polygons),'vertices':len(obj.data.vertices),
                    'materials':[m.name for m in obj.data.materials]}
    parts.clear()
    return obj

report = {}
# KEY: dark wooden plinth, brass platform, forked bearing and contact hardware.
box('KeyWalnutPlinth',(0,.006,0),(.09,.012,.19),'wood',.003)
box('KeyBrassBed',(0,.014,0),(.075,.008,.16),'brass',.0015)
for x in (-.029,.029):
    box('KeyPivotFoot',(x,.026,.005),(.011,.02,.026),'brass',.001)
    screw('KeyFootScrew',(x,.037,-.002),.0035,.004)
    cyl('KeyBindingPost',(x,.025,-.064),.006,.018,'brass',sides=10)
    cyl('KeyBindingCap',(x,.036,-.064),.008,.004,'brass',sides=10)
    screw('KeyMount',(x,.012,.075),.003,.003)
rod('KeyPivotAxle',(-.037,.029,.004),(.037,.029,.004),.003,'iron')
screw('KeyRearContact',(0,.032,-.052),.004,.019)
screw('KeyFrontContact',(0,.024,.058),.0045,.012)
box('KeyInsulator',(0,.019,.058),(.013,.004,.018),'ebonite',.0007)
rod('KeyReturnSpring',(0,.018,-.035),(0,.028,-.017),.0018,'iron')
export('key_static')
# Moving geometry is relative to the existing Lever origin at y=.022.
box('KeyLeverBeam',(0,.006,.005),(.012,.012,.14),'brass',.001)
cyl('KeyGripFoot',(0,.013,.060),.009,.007,'brass')
cyl('KeyEboniteGrip',(0,.024,.060),.025,.016,'ebonite',sides=16,radius_top=.022)
cyl('KeyGripFace',(0,.033,.060),.021,.002,'ebonite',sides=16)
screw('KeyGripCentre',(0,.035,.060),.002,.002)
export('key_lever')
# SOUNDER: paired electromagnets with period-like wood/brass support.
box('SounderBase',(0,.01,0),(.15,.024,.20),'wood',.003)
box('SounderBed',(0,.024,-.002),(.134,.004,.172),'brass',.001)
for x in (-.025,.025):
    cyl('CoilFoot',(x,.030,-.020),.022,.006,'iron')
    cyl('WoundMagnet',(x,.038,-.020),.020,.024,'coil',sides=14)
    cyl('CoilCap',(x,.052,-.020),.020,.004,'brass',sides=12)
    cyl('MagnetCore',(x,.0545,-.020),.008,.001,'iron',sides=10)
for x in (-.048,.048):
    screw('SounderMount',(x,.028,.067),.0035,.004)
    cyl('SounderBindingPost',(x,.035,-.068),.006,.020,'brass')
    screw('SounderTerminal',(x,.047,-.068),.006,.005)
box('SounderAnvil',(0,.037,.047),(.012,.040,.014),'brass',.0008)
box('SounderRearFrame',(0,.047,-.074),(.012,.045,.012),'brass',.001)
box('SounderFrameBridge',(0,.071,-.055),(.012,.009,.050),'brass',.001)
screw('SounderStop',(0,.080,.040),.006,.018)
screw('SounderRearAdjust',(0,.079,-.052),.005,.015)
rod('SounderLeadLeft',(-.025,.029,-.020),(-.048,.027,-.068),.0012,'ebonite')
rod('SounderLeadRight',(.025,.029,-.020),(.048,.027,-.068),.0012,'ebonite')
export('sounder_static')
# Existing ArmatureBar at y=.065,z=.005; preserve its vertical motion contract.
box('Armature',(0,0,0),(.018,.007,.100),'brass',.0006)
box('ArmatureMagnetPlate',(0,-.004,-.025),(.068,.003,.030),'iron',.0005)
screw('ArmatureFastener',(0,.004,-.032),.003,.002)
export('sounder_armature')
# REGISTER: visual casing only; preserved raw tape still comes from scheduler.
box('RegisterPlinth',(0,.005,0),(.172,.010,.122),'wood',.002)
box('RegisterCabinet',(0,.0375,0),(.160,.055,.110),'wood',.002)
box('RegisterTop',(0,.067,0),(.150,.004,.100),'brass',.0008)
box('RegisterNamePlate',(0,.036,.0555),(.06,.012,.0012),'brass',.0003)
for x in (-.064,.064):
    for z in (-.040,.040):
        screw('RegisterPlateFixing',(x,.070,z),.0027,.002)
    box('RegisterCornerBand',(x,.037,.0556),(.005,.049,.001),'iron')
for x in (-.0145,.0145):
    box('RegisterSpoolCheek',(x,.097,-.025),(.004,.058,.050),'brass',.001)
    screw('RegisterCheekFixing',(x,.128,-.025),.0025,.002)
# Side door and ring, not a transparent unmodelled gear-box.
box('ClockworkSidePlate',(.0805,.038,0),(.001,.037,.073),'brass',.0005)
cyl('WindingArbor',(.085,.040,-.010),.004,.012,'brass',(1,0,0),8)
box('WindingKey',(.093,.040,-.010),(.004,.022,.012),'brass',.001)
# Tape receiving tray stays at the original location.
box('TrayFloor',(0,.003,.172),(.060,.006,.055),'wood',.001)
box('TrayLip',(0,.012,.198),(.060,.024,.005),'wood',.001)
for x in (-.028,.028):
    box('TraySide',(x,.010,.172),(.004,.018,.055),'wood',.0007)
cyl('InkWheel',(0,.078,.052),.006,.012,'iron',(1,0,0),10)
export('register_static')
# Spool uses the current rotated local frame; cylinder local axis Y.
cyl('PaperRoll',(0,0,0),.027,.020,'paper',sides=16)
cyl('RollHub',(0,0,0),.008,.034,'brass',sides=10)
for y in (-.012,.012):
    cyl('RollFlange',(0,y,0),.029,.003,'brass',sides=16)
box('HubSpoke',(0,0,0),(.036,.021,.004),'brass',.0004)
export('register_spool')
box('StylusBeam',(0,0,-.012),(.004,.004,.040),'brass',.0004)
cyl('StylusTip',(0,-.0055,.007),.0018,.008,'iron',sides=6)
export('register_stylus')
# Compose an editable source turntable layout AFTER independent GLB export.
# The exported origins stay correct; the source shows assembled mechanisms.
layout = {'key_static':(-.24,0,0), 'key_lever':(-.24,.022,0),
          'sounder_static':(0,0,0), 'sounder_armature':(0,.065,.005),
          'register_static':(.24,0,0), 'register_spool':(.24,.105,-.025),
          'register_stylus':(.24,.081,.030)}
for name, location in layout.items():
    coll.objects[name].location = pos(location)
spool = coll.objects['register_spool']
spool.rotation_mode = 'XYZ'
spool.rotation_euler = (0, math.pi/2, 0)
# Save the complete editable source without importing .blend in Godot.
# Hide unrelated scene contents in the saved source only; restore live visibility.
other_visibility = [(o, o.hide_render, o.hide_viewport) for o in bpy.context.scene.objects if o.name not in coll.objects]
for obj, _, _ in other_visibility:
    obj.hide_render = True
    obj.hide_viewport = True
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'dead_wire_instruments_v1.blend'), copy=True)
for obj, render_hidden, viewport_hidden in other_visibility:
    obj.hide_render = render_hidden
    obj.hide_viewport = viewport_hidden
(OUT/'build_manifest.json').write_text(json.dumps({'authoring':'Blender bpy; no generated AI meshes',
    'units':'metres','atlas':'res://assets/textures/instruments_v1/instrument_atlas_256.png',
    'assemblies':report,'total_triangles':sum(v['triangles'] for v in report.values()),
    'reference_urls':['https://americanhistory.si.edu/collections/object/nmah_706904',
                      'https://americanhistory.si.edu/collections/object/nmah_712418',
                      'https://americanhistory.si.edu/collections/object/nmah_706654'],
    'historical_claim':'period-plausible stylized instruments, not museum replicas'},indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
print('TOTAL_TRIANGLES',sum(v['triangles'] for v in report.values()))
