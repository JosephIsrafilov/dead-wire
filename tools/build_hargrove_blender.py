"""Author the Hargrove facade and Room 4 furniture in Blender, then export to Godot.

Run with Blender -b --python tools/build_hargrove_blender.py. Geometry is authored
in metres, Blender +Y is the exterior frontage (Godot -Z), and origins are at grade.
"""
import math
import random
from collections import defaultdict
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/town'
SOURCE = ROOT / '.dream-loop/black_creek_art/blender'
RNG = random.Random(1890)
GEO = defaultdict(lambda: [[], []])
MATS = {}


def palette(name, hex_color, roughness=0.88, metal=0.0):
    rgb = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(x / 12.92 if x < 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in rgb)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    MATS[name] = mat
    return name


def mesh(mat, verts, faces):
    v, f = GEO[mat]
    f.extend(tuple(len(v) + j for j in face) for face in faces)
    v.extend(verts)


FACES = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def box(mat, at, size, rot=0.0):
    x, y, z = at
    a, b, c = (q / 2 for q in size)
    co, si = math.cos(rot), math.sin(rot)
    mesh(mat, [(x + dx * co - dy * si, y + dx * si + dy * co, z + dz)
               for dz in (-c, c) for dx, dy in [(-a, -b), (a, -b), (a, b), (-a, b)]], FACES)


def lathe(mat, x, y, profile, n=10, cap=True):
    verts = [(x + r * math.cos(i * math.tau/n), y + r * math.sin(i * math.tau/n), z)
             for z, r in profile for i in range(n)]
    faces = [tuple(reversed(range(n)))] if cap else []
    for k in range(len(profile)-1):
        for i in range(n):
            a, b = k*n+i, k*n+(i+1)%n
            faces.append((a, b, b+n, a+n))
    if cap:
        faces.append(tuple(range(len(verts)-n, len(verts))))
    mesh(mat, verts, faces)


def beam(mat, p, q, width, depth=None):
    p, q = Vector(p), Vector(q)
    rot = (q-p).to_track_quat('Z', 'Y')
    a, b, c = width/2, (depth or width)/2, (q-p).length/2
    mesh(mat, [(p+q)/2 + rot @ Vector((x,y,z)) for z in (-c,c)
               for x,y in [(-a,-b),(a,-b),(a,b),(-a,b)]], FACES)


def sash(x, y, z, w, h, side=1):
    # Deep frame, separate upper/lower sash, glazing inset behind rails.
    trim, glass = 'Cream', 'WindowBlue'
    yy = y + 0.035*side
    box('DarkSage', (x, yy, z), (w+0.24, .09, h+.24))
    box(glass, (x, yy+.052*side, z), (w, .028, h))
    for dx in (-w/2, 0, w/2):
        box(trim, (x+dx, yy+.084*side, z), (.055 if dx == 0 else .10, .09, h+.10))
    for dz in (-h/2, -h/4, 0, h/4, h/2):
        box(trim, (x, yy+.088*side, z+dz), (w+.09, .085, .07 if dz == 0 else .04))
    box(trim, (x, yy+.086*side, z-h/2-.085), (w+.31, .22, .085))
    box(trim, (x, yy+.084*side, z+h/2+.076), (w+.25, .14, .11))
    if side == 1:
        for sx in (x-w/2-.29, x+w/2+.29):
            box('DarkSage', (sx, yy+.026, z), (.37, .08, h+.08))
            for j in range(13):
                box('ShutterEdge', (sx, yy+.078, z-h*.44+j*h*.073), (.29,.033,.027))


def boarding():
    for name, color in [('Cream','C9BEA6'),('DarkSage','2E3F34'),('ShutterEdge','475749'),
                        ('WindowBlue','334650'),('Stone','635B55'),('Mortar','484541'),
                        ('Shingle','34373A'),('ShingleL','434545'),('ShingleD','2D3234'),
                        ('Deck','7C6450'),('DeckL','8C735C'),('DeckD','66513F'),
                        ('Door','4B3526'),('DoorInset','38271E'),('Brass','9B7842'),('Brick','843F32')]:
        palette(name, color)
    sage = [palette(f'Sage{i}', c) for i,c in enumerate(('6F7A72','758078','68746C','727C72','637068'))]
    box('Mortar',(0,0,.16),(9.92,11.9,.32))
    for row in range(2):
        for j in range(15):
            x = -4.67+j*.666
            box('Stone',(x,5.99,.077+.152*row),(.63,.11,.134))
    box(sage[0],(0,0,2.69),(9.92,11.90,4.78))
    # Clapboard faces are staggered in depth, doing the work instead of flat stripes.
    for i in range(30):
        z = .34+i*.159
        for side in (-1,1):
            box(RNG.choice(sage),(0,side*5.981,z),(9.94,.084,.148))
            box(RNG.choice(sage),(side*4.98,0,z),(.078,11.91,.148))
    for side in (-1,1):
        for x in (-4.93,4.93):
            box('Cream',(x,side*6.01,2.65),(.19,.16,4.77))
        for i in range(13):
            z=5.01+i*.183
            w=10*(1-(i+.48)/13.3)
            box(RNG.choice(sage),(0,side*5.98,z),(w,.10,.19))
        for x in (-3,0,3):
            sash(x,6*side,4.0,.91,1.36,side)
        for x in (-3,3):
            sash(x,6*side,1.83,.97,1.48,side)
    for side in (-1,1):
        a=(0,6.28,7.45)
        b=(side*5.35,6.28,4.96)
        beam('Cream',a,b,.20,.14)
        beam('Cream',(0,-6.3,7.45),(side*5.35,-6.3,4.96),.20,.14)
        roof_tiles((0,0,7.45),(side*5.36,0,4.97),12.65)
        box('Cream',(side*5.12,0,4.97),(.25,12.65,.15))
    box('ShingleD',(0,0,7.44),(.25,12.7,.12))
    sash(0,6,5.96,.48,.63)
    for i in range(11):
        box('Brick',(3.23,-2.0,5.78+i*.138),(.58,.55,.123))
    box('Stone',(3.23,-2.0,7.32),(.70,.67,.13))
    # Two-riser approach uses the shared boardwalk as its lower landing.
    for i in range(39):
        box(RNG.choice(['Deck','DeckL','DeckD']),(-4.68+i*.246,7.20,.27),(.242,2.40,.10))
    box('DarkSage',(0,8.385,.19),(9.6,.15,.23))
    for x in (-4.52,-1.57,1.57,4.52):
        lathe('Cream',x,8.13,[(.32,.13),(.43,.13),(.45,.105),(.88,.10),(1.00,.07),
                              (1.19,.089),(1.31,.063),(2.60,.063),(2.72,.093),(2.89,.093),(2.97,.14)], 8)
        for side in (-1,1):
            beam('Cream',(x,8.13,2.62),(x+side*.30,8.13,2.96),.075)
    for x in (-3.07,3.07):
        for z in (.50,1.16):
            box('Cream',(x,8.12,z),(2.92,.11,.10))
        for i in range(14):
            lathe('Cream',x-1.34+i*.205,8.12,[(.55,.035),(.66,.023),(.82,.045),(1.05,.023),(1.12,.035)], 6)
    box('Cream',(0,8.29,3.015),(9.7,.22,.23))
    for i in range(22):
        x=-4.72+i*.45
        beam('DeckD',(x,6.0,3.43),(x,8.38,3.02),.07,.10)
    roof_tiles((0,5.92,3.54),(0,8.55,3.12),9.96,along_x=True)
    box('Cream',(0,8.53,3.08),(10.02,.10,.14))
    box('Cream',(0,6.075,1.53),(1.53,.17,2.45))
    box('Door',(0,6.183,1.47),(1.19,.09,2.30))
    for zz in (.78,1.28,2.13):
        for xx in (-.27,.27):
            box('DoorInset',(xx,6.24,zz),(.35,.035,.35 if zz < 2 else .63))
    box('Brass',(.44,6.251,1.40),(.076,.044,.174))
    box('Brass',(.44,6.307,1.414),(.068,.071,.068))
    box('DarkSage',(0,8.39,2.81),(3.12,.16,.31))
    lathe('Brass',.85,6.49,[(2.39,.095),(2.45,.065),(2.68,.065),(2.72,.115),(2.77,.01)], 8)
    lathe('WindowBlue',.85,6.49,[(2.45,.079),(2.67,.086)], 8)


def roof_tiles(a, b, width, along_x=False):
    a,b = Vector(a),Vector(b)
    t = b-a
    other = Vector((1,0,0) if along_x else (0,1,0))
    corners = [a-other*width/2, b-other*width/2, b+other*width/2, a+other*width/2]
    if t.cross(other).z < 0:
        corners.reverse()
    mesh('ShingleD', [p-Vector((0,0,.018)) for p in corners], [(0,1,2,3)])
    for n in range(16):
        mat = ['Shingle','Shingle','ShingleL','ShingleD']
        for j in range(int(width/.38)+1):
            p=a+t*n/16+other*(-width/2+j*width/(int(width/.38)+1))+Vector((0,0,(16-n)*.002))
            q=p+t*.066
            w=width/(int(width/.38)+1)-.006
            # Upward roof normals on either roof slope.
            pts=[p,q,q+other*w,p+other*w]
            if (q-p).cross(other).z<0:
                pts.reverse()
            mesh(RNG.choice(mat),pts,[(0,1,2,3)])


def furniture(bed_only=False):
    for n,c in [('Iron','262627'),('Brass','9A733E'),('Ticking','B1A392'),('Linen','D5C8AF'),
                ('Pillow','CCAFA0'),('QuiltRed','775552'),('QuiltBlue','596369'),('QuiltOchre','977E59'),
                ('QuiltCream','AA9B7E'),('Oak','73533B'),('OakDark','503A2D'),('Ceramic','D5C8AD'),
                ('Glaze','485F72'),('Water','637F84')]:
        palette(n,c, .36 if n in ['Ceramic','Glaze','Water'] else .88, .32 if n in ['Iron','Brass'] else 0)
    for x in (-.59,.59):
        box('Iron',(x,0,.32),(.048,2.02,.088))
        for y in (-.97,.97):
            h = 1.08 if y>0 else .82
            lathe('Iron',x,y,[(0,.038),(.07,.039),(.14,.024),(h-.05,.024),(h,.035)], 8)
            lathe('Brass',x,y,[(h,.025),(h+.035,.043),(h+.075,.033),(h+.096,.002)], 8)
    for y,h in ((.97,1.08),(-.97,.82)):
        for i in range(9):
            x=-.49+i*.1225
            z=h-.115+.105*(1-(x/.63)**2)
            lathe('Iron',x,y,[(.34,.018),(.52,.013),(z,.013)], 7)
            if i<8:
                nx=x+.1225
                beam('Iron',(x,y,z),(nx,y,h-.115+.105*(1-(nx/.63)**2)),.032)
        box('Iron',(0,y,.44),(1.2,.036,.041))
    soft_box('Ticking',(0,0,.435),(1.17,1.94,.21))
    soft_box('Pillow',(0,.69,.58),(.71,.37,.145))
    # Low-poly draped patchwork with stitched horizontal/vertical seams.
    cloth=['QuiltRed','QuiltBlue','QuiltOchre','QuiltCream']
    for j in range(10):
        for i in range(10):
            def pt(u,v):
                x=-.665+u*.133
                y=-1.02+v*.147
                z=.556-.175*max(0,(abs(u-5)-4)/1.0)-.08*max(0,1-v)
                return (x,y,z+math.sin(u*1.4+v*.71)*.015)
            mesh(cloth[(i*3+j*5+(i//2+j//2)%3)%4],[pt(i,j),pt(i+1,j),pt(i+1,j+1),pt(i,j+1)],[(0,1,2,3)])
    flush('room04_iron_bed')
    if bed_only:
        return
    box('Oak',(0,0,.815),(.77,.57,.075))
    box('OakDark',(0,-.276,.71),(.68,.038,.134))
    for x in (-.28,.28):
        for y in (-.20,.20):
            lathe('Oak',x,y,[(.01,.029),(.15,.022),(.23,.04),(.67,.034),(.78,.047)],8)
    box('Oak',(0,0,.27),(.65,.47,.047))
    box('Oak',(0,.24,.895),(.75,.053,.115))
    box('Brass',(0,-.304,.71),(.079,.04,.037))
    lathe('Ceramic',-.10,0,[(.852,.115),(.874,.151),(.916,.187),(.96,.219),(.975,.206),(.965,.185),(.914,.14),(.884,.03)],16)
    lathe('Glaze',-.10,0,[(.941,.207),(.947,.211)],16,cap=False)
    lathe('Water',-.10,0,[(.916,.155),(.925,.157)],16)
    lathe('Ceramic',.23,.068,[(.855,.069),(.89,.09),(.96,.104),(1.055,.065),(1.102,.077),(1.105,.065),(1.068,.049)],12)
    lathe('Glaze',.23,.068,[(1.086,.072),(1.093,.075)],12,cap=False)
    points=[(.27,.071,1.057),(.35,.071,1.061),(.38,.071,1.003),(.355,.071,.932),(.302,.071,.915)]
    for p,q in zip(points,points[1:]):
        beam('Ceramic',p,q,.022)
    flush('room04_washstand')


def soft_box(mat, at, size):
    x,y,z=at
    a,b,c=(i/2 for i in size)
    verts=[]
    for zz,k in ((-c,.88),(-c*.56,1),(.54*c,1),(c,.82)):
        verts += [(x+dx*a*k,y+dy*b*k,z+zz) for dx,dy in [(-.78,-1),(.78,-1),(1,-.73),(1,.73),(.78,1),(-.78,1),(-1,.73),(-1,-.73)]]
    faces=[tuple(reversed(range(8))),tuple(range(24,32))]
    faces += [(k+i,k+(i+1)%8,k+8+(i+1)%8,k+8+i) for k in (0,8,16) for i in range(8)]
    mesh(mat,verts,faces)


def flush(name, export=True):
    bpy.ops.object.select_all(action='DESELECT')
    full = bpy.data.meshes.new(name)
    verts, faces, indices = [], [], []
    for mi, (mat, (v,f)) in enumerate(GEO.items()):
        faces.extend(tuple(len(verts)+i for i in ff) for ff in f)
        indices.extend([mi]*len(f))
        verts.extend(v)
        full.materials.append(MATS[mat])
    full.from_pydata(verts,[],faces)
    full.update()
    for p,index in zip(full.polygons,indices):
        p.material_index=index
    obj=bpy.data.objects.new(name,full)
    bpy.context.collection.objects.link(obj)
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    if export:
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
    full.calc_loop_triangles()
    print(f'{name}: {len(full.loop_triangles)} triangles')
    GEO.clear()
    return obj


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    SOURCE.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system='METRIC'
    boarding()
    flush('hargrove_boarding_house')
    furniture()
    bpy.data.objects['room04_iron_bed'].location.x=16
    bpy.data.objects['room04_washstand'].location.x=18
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'hargrove_room04.blend'))


if __name__ == '__main__':
    main()
