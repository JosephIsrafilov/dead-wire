"""Rebuild the Hargrove boarding house and Room 4 from a common measured plan.

Blender +Y is north; glTF maps it to Godot -Z. The rentable corner room occupies
X = 0.49..3.85, Y = 0.10..4.30, with finish floor at Z = 3.17 in the house.
The lower floor and landing are planning geometry, not exported gameplay space.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
if __name__ == '__main__':
    sys.modules[Path(__file__).stem] = sys.modules[__name__]
import build_hargrove_blender as kit


OUT = kit.OUT
SOURCE = kit.ROOT / '.dream-loop/hargrove_1890'
POLISH = kit.ROOT / '.dream-loop/hargrove_polish'
box, beam, mesh, lathe, palette = kit.box, kit.beam, kit.mesh, kit.lathe, kit.palette
ROOM = (2.17, 2.20, 3.17)
HOUSE_W, HOUSE_D = 7.90, 8.60
ROOM_W, ROOM_D, ROOM_H = 3.36, 4.20, 2.62
NORTH, EAST = .48, -.68  # Window offsets in room X and room Y (Blender).
OPEN_W, SILL, HEAD = .86, .82, 2.36


def materials():
    for n, c in {
        'Sage':'697668','SageShade':'5C685F','SageLight':'758174','Batten':'756653',
        'Plinth':'5D574D','Stone':'797064','StoneD':'665E52','Brick':'815044','BrickD':'694236',
        'OldWhite':'C3B69D','Apron':'8A7A61','DarkGreen':'394C40','DarkGlass':'41565C',
        'Roof':'464743','RoofD':'3C3D39','RoofL':'51504A','Fir':'85694F','FirD':'705740',
        'FirL':'967B5D','Shadow':'40352A','BrassAged':'977542','Soot':'362F29',
        'Plaster':'B9AF95','Paper':'AAA186','PaperFaded':'A29980','ChairRail':'74604B',
        'Desk':'7E5D44','DeskD':'5E4333','Canvas':'8A725D','Indigo':'5B5D63',
        'LampGlass':'AD9471','RoadOchre':'94795E','Ridge':'63717B','RidgeD':'515D68',
        'Snow':'ADB4B6','SashShadow':'716858', 'PlanInk':'936447', 'PlanBlue':'6A829A',
    }.items():
        palette(n,c, .34 if n in ('DarkGlass','LampGlass') else .88, .28 if n=='BrassAged' else 0)


def spans(lo, hi, holes):
    for a,b in sorted(holes):
        if a>lo: yield lo,a
        lo=max(lo,b)
    if hi>lo: yield lo,hi


def along(axis, u, v, z):
    return (u,v,z) if axis=='X' else (v,u,z)


def slab(mat, axis, a, b, fixed, z0, z1, depth):
    if b-a < .002 or z1-z0 < .002: return
    box(mat,along(axis,(a+b)/2,fixed,(z0+z1)/2),
        ((b-a),depth,z1-z0) if axis=='X' else (depth,(b-a),z1-z0))


def wall(axis, a, b, fixed, z0, z1, apertures=(), outside=True):
    # The wall's backing and its finish both stop at the openings, not under the sash.
    cuts=sorted({z0,z1,*[z for _,_,s,t in apertures for z in (s,t)]})
    for lo,hi in zip(cuts,cuts[1:]):
        if lo<z0 or hi>z1: continue
        holes=[(x-w/2,x+w/2) for x,w,s,t in apertures if s < hi-.001 and t > lo+.001]
        for u,v in spans(a,b,holes):
            slab('Sage' if outside else 'Plaster',axis,u,v,fixed,lo,hi,.15)
    if outside:
        sign=1 if fixed>0 else -1
        rows=math.ceil((z1-z0)/.145)
        for i in range(rows):
            lo,hi=z0+i*.145,min(z0+(i+1)*.145,z1)
            splits=sorted({lo,hi,*[q for _,_,s,t in apertures for q in (s,t) if lo<q<hi]})
            for bot,top in zip(splits,splits[1:]):
                holes=[(x-w/2,x+w/2) for x,w,s,t in apertures if s < top-.001 and t > bot+.001]
                for u,v in spans(a,b,holes):
                    slab(kit.RNG.choices(['Sage','SageShade','SageLight'],[7,2,2])[0],axis,u,v,
                         fixed+.085*sign,bot,top-.002,.035)
    else:
        # Quietly aged plaster/paper above a continuous skirting line.
        holes=[(x-w/2,x+w/2) for x,w,s,_ in apertures if s<.18]
        for u,v in spans(a,b,holes):
            slab('ChairRail',axis,u,v,fixed-math.copysign(.088,fixed),.015,.15,.035)
            slab('Apron',axis,u,v,fixed-math.copysign(.101,fixed),.139,.179,.027)


def sash(axis, u, fixed, floor, outside, glass=False):
    # Double-hung: two 2-over-2 sashes, deep reveal, sill and drip hood.
    mat= 'OldWhite' if outside else 'Apron'
    sign=1 if fixed>0 else -1
    face=fixed+(sign if outside else -sign)*.096
    for dx in (-OPEN_W/2, OPEN_W/2):
        slab(mat,axis,u+dx-.055,u+dx+.055,face,floor+SILL-.04,floor+HEAD+.045,.10)
    for h in (SILL,1.57,HEAD):
        slab(mat,axis,u-.48,u+.48,face,floor+h-.032,floor+h+.032,.095)
    for h0,h1 in ((SILL,1.57),(1.57,HEAD)):
        slab('OldWhite',axis,u-.017,u+.017,face,floor+h0,floor+h1,.04)
    slab(mat,axis,u-.54,u+.54,face,floor+SILL-.075,floor+SILL+.001,.20)
    slab(mat,axis,u-.50,u+.50,face,floor+HEAD+.02,floor+HEAD+.075,.145)
    if glass:
        slab('DarkGlass',axis,u-.413,u+.413,fixed,floor+SILL+.03,floor+HEAD-.027,.020)
    if outside and axis=='X' and fixed>0:
        for s in (-1,1):
            c=u+s*.655
            slab('DarkGreen',axis,c-.165,c+.165,face-.017,floor+SILL+.025,floor+HEAD-.04,.07)
            for y in (SILL+.14, 1.60, HEAD-.17):
                slab('SageShade',axis,c-.151,c+.151,face+.022,floor+y-.018,floor+y+.018,.017)


def openings(centres, floor, doorway=None):
    result=[(x,OPEN_W,floor+SILL,floor+HEAD) for x in centres]
    if doorway is not None:
        u,w=doorway
        result.append((u,w,floor,floor+2.28))
    return result


def door(axis,u,fixed,floor,width,inside=False):
    sign=1 if fixed>0 else -1
    mid=fixed+(-sign if inside else sign)*.027
    top=2.25 if inside else 2.18
    for d in (-width*.5,width*.5):
        slab('OldWhite' if not inside else 'Apron',axis,u+d-.052,u+d+.052,mid,floor,floor+2.29,.15)
    slab('OldWhite' if not inside else 'Apron',axis,u-width*.5-.05,u+width*.5+.05,mid,
         floor+2.20,floor+2.30,.15)
    slab('FirD',axis,u-width/2+.032,u+width/2-.032,mid,floor+.018,floor+top,.068)
    front=mid+(-sign if inside else sign)*.04
    for d in (-1,1):
        for z0,z1 in ((.27,.83),(1.11,1.95)):
            x=u+d*width*.22
            slab('Shadow',axis,x-width*.158,x+width*.158,front,floor+z0,floor+z1,.026)
            slab('Fir',axis,x-width*.127,x+width*.127,front+(-sign if inside else sign)*.016,
                 floor+z0+.04,floor+z1-.04,.014)
    x=u+width*.36
    lathe('BrassAged',*along(axis,x,front+(-sign if inside else sign)*.055,0)[:2],
          [(floor+.974,.025),(floor+1.013,.043),(floor+1.057,.026)],8)


def roof_panel(a,b,wide,other):
    a,b,other=Vector(a),Vector(b),Vector(other)
    d=b-a
    for row in range(11):
        t=row/11
        for j in range(6):
            off=(j/6-.5)*wide
            p=a+d*t+other*off
            q=p+d/11
            vertices=[p,q,q+other*wide/6,p+other*wide/6]
            if d.cross(other).z<0: vertices.reverse()
            mesh(kit.RNG.choices(['Roof','RoofD','RoofL'],[8,2,2])[0],vertices,[(0,1,2,3)])


def exterior():
    north_lower=[1.98]; north_upper=[-2.48, ROOM[0]+NORTH]
    wall('X',-3.95,3.95,4.30,.46,5.88,
         openings(north_lower,.46,(-1.46,1.22))+openings(north_upper,ROOM[2]))
    wall('X',-3.95,3.95,-4.30,.46,5.88,
         openings([2.40],.46)+openings([-2.27,2.24],ROOM[2]))
    east_lower=[-2.67,2.28]; east_upper=[-1.65,ROOM[1]+EAST]
    wall('Y',-4.30,4.30,3.95,.46,5.88,openings(east_lower,.46)+openings(east_upper,ROOM[2]))
    wall('Y',-4.30,4.30,-3.95,.46,5.88,openings([-.82,2.51],.46)+openings([-2.46,1.97],ROOM[2]))
    for axis,v,ls,us in [('X',4.30,north_lower,north_upper),('X',-4.30,[2.4],[-2.27,2.24]),
                         ('Y',3.95,east_lower,east_upper),('Y',-3.95,[-.82,2.51],[-2.46,1.97])]:
        for u in ls: sash(axis,u,v,.46,True,True)
        for u in us: sash(axis,u,v,ROOM[2],True,True)
        for side in (-1,1):
            edge=(3.89 if axis=='X' else 4.25)*side
            slab('OldWhite',axis,edge-.072,edge+.072,v+math.copysign(.10,v),.43,5.88,.09)
    door('X',-1.46,4.30,.46,1.22)
    box('Plinth',(0,0,.21),(7.96,8.67,.44))
    for axis, fixed, limit in [('X',4.33,3.95),('X',-4.33,3.95),('Y',3.98,4.27),('Y',-3.98,4.27)]:
        for row in range(2):
            x=-limit
            while x<limit-.01:
                width=min(kit.RNG.uniform(.33,.69),limit-x)
                slab(kit.RNG.choice(['Stone','StoneD']),axis,x+.008,x+width-.008,fixed,
                     .03+row*.197+(kit.RNG.random()*.018),.21+row*.197,.10)
                x+=width
    for y in (-4.30,4.30):
        for i in range(13):
            lo=5.87+i*.145
            def half(z): return 3.95*(7.79-z)/(7.79-5.87)
            verts=[(-half(lo),y,lo),(half(lo),y,lo),(half(lo+.145),y,lo+.145),(-half(lo+.145),y,lo+.145)]
            if y>0: verts.reverse()
            mesh('Sage' if i%4 else 'SageShade',verts,[(0,1,2,3)])
    for s in (-1,1):
        roof_panel((0,0,7.87),(s*4.27,0,5.82),9.29,(0,1,0))
        for y in (-4.65,4.65):
            beam('OldWhite',(0,y,7.86),(s*4.28,y,5.81),.135,.11)
        box('Apron',(s*4.20,0,5.77),(.17,9.31,.17))
    beam('RoofD',(0,-4.67,7.87),(0,4.67,7.87),.11)
    # Main flue at an interior partition, not perched on the eave.
    box('Brick',(3.58,.29,6.845),(.54,.52,1.71))
    for i in range(10):
        z=6.29+i*.14
        slab('BrickD','X',3.32,3.84,.555,z,z+.024,.023)
    box('StoneD',(3.58,.29,7.73),(.66,.64,.11))
    # Narrow street veranda; rafters bear on posts, joists on piers.
    for i in range(23):
        box(kit.RNG.choice(['Fir','Fir','FirL','FirD']),(-3.82+i*.347,5.39,.416),(.342,2.15,.088))
    box('FirD',(0,6.46,.29),(7.92,.17,.18))
    for x in (-3.72,-2.61,-.30,1.94,3.74):
        box('StoneD',(x,6.29,.145),(.33,.34,.29))
        box('Apron',(x,6.27,1.75),(.15,.16,2.59))
        box('OldWhite',(x,6.27,2.91),(.22,.22,.14))
    for a,b in [(-3.71,-2.61),(-.3,1.94),(1.94,3.74)]:
        for z in (.55,1.24): slab('Apron','X',a,b,6.28,z,z+.08,.10)
        for j in range(1,math.ceil((b-a)/.19)):
            t=a+j*.19
            if t<b-.08: box('Apron',(t,6.28,.90),(.047,.049,.70))
    for x in (-2.61,-.30):
        beam('Apron',(x,6.27,2.69),(x+math.copysign(.28,-1.46-x),6.27,2.97),.06)
    box('OldWhite',(0,6.31,3.005),(7.99,.21,.17))
    for i in range(16):
        x=-3.8+i*.505
        beam('FirD',(x,4.27,3.38),(x,6.54,3.04),.065,.09)
    roof_panel((0,4.24,3.47),(0,6.63,3.10),8.12,(1,0,0))
    box('DarkGreen',(-1.46,6.41,2.79),(2.12,.14,.29))
    box('FirD',(-1.46,6.64,.38),(2.20,.38,.16))
    # Economy of construction: a lower, unpainted rear kitchen added to the house.
    x=-1.90
    box('StoneD',(x,-5.61,.17),(3.8,2.60,.34))
    box('Batten',(x,-5.59,1.49),(3.8,2.55,2.67))
    for j in range(17):
        box('FirD',(-3.74+j*.231,-6.88,1.49),(.035,.031,2.65))
    roof_panel((x,-4.29,3.27),(x,-7.04,2.65),4.13,(1,0,0))
    sash('X',-2.73,-6.87,.25,True,True)
    door('X',-.92,-6.87,.33,1.12)
    box('FirD',(-.92,-7.08,.08),(1.32,.40,.16))
    box('Fir',(-.92,-7.05,.245),(1.32,.34,.17))
    box('BrickD',(-3.28,-5.68,3.18),(.36,.38,1.56))
    return kit.flush('hargrove_house_1890')


def room_shell():
    x,z=ROOM_W/2,ROOM_D/2
    for i in range(25):
        cx=-x+.07+i*.134
        split=-.93+(i*13%19)*.095
        for a,b in ((-z,split),(split,z)):
            box(kit.RNG.choices(['Fir','FirD','FirL'],[8,2,2])[0],(cx,(a+b)/2,-.045),(.132,b-a-.008,.09))
    import build_black_creek_residential_kit as residential
    residential.ceiling(-x,x,-z,z,ROOM_H)
    residential.inner_wall('X',-x,x,z,0,ROOM_H,openings([NORTH],0),-1,striped=True)
    residential.inner_wall('Y',-z,z,x,0,ROOM_H,openings([EAST],0),-1,striped=True)
    residential.inner_wall('X',-x,x,-z,0,ROOM_H,openings([],0,(-.29,1.12)),1,striped=True)
    residential.inner_wall('Y',-z,z,-x,0,ROOM_H,(),1,striped=True)
    for axis,fix,u in [('X',z,NORTH),('Y',x,EAST)]:
        sash(axis,u,fix,0,False)
        # Short cotton curtains finish just above the sill, clear of the bedside stool.
        for side in (-1,1):
            p=u+side*.53
            for i in range(4):
                k=p+(i-1.5)*.045
                slab('Paper' if i%2==0 else 'Plaster',axis,k-.021,k+.022,fix-.16-(i%2)*.025,
                     SILL+.085+(i%2)*.019,2.35,.028)
        slab('Shadow',axis,u-.63,u+.63,fix-.19,2.36,2.389,.029)
    for xj in (-.85,.27):
        slab('Apron','X',xj-.04,xj+.04,-z,0,2.29,.21)
    slab('Apron','X',-.89,.31,-z,2.23,2.30,.21)
    # Door leaf open against the inner partition, leaving the clear width.
    box('FirD',(-.87,-1.56,1.115),(.065,1.05,2.19))
    for yy in (-1.85,-1.34):
        for zz in (.58,1.56):
            box('Shadow',(-.833,yy,zz),(.026,.34,.65))
            box('Fir',(-.815,yy,zz),(.017,.28,.55))
    box('FirD',(-.29,-z+.08,.019),(1.13,.15,.038))
    # Rag runner follows the walking line rather than carpeting the entire room.
    for i in range(38):
        box(['Indigo','Canvas','PaperFaded','Canvas'][i%4],(.02,-.92+i*.049,.006),(.77,.049,.011))
    kit.flush('hargrove_room04_shell')


def room_desk():
    box('Desk',(0,0,.738),(.64,1.09,.05))
    box('DeskD',(-.282,0,.657),(.045,1.025,.116))
    box('Desk',(-.319,0,.66),(.047,.77,.111))
    box('BrassAged',(-.352,0,.66),(.024,.108,.026))
    for x in (-.258,.258):
        for y in (-.461,.461):
            lathe('Desk',x,y,[(.0,.032),(.13,.031),(.52,.026),(.61,.038),(.715,.036)],7)
    box('DeskD',(.259,0,.237),(.054,.94,.053))
    # Paper-wrapped slide box, with the tray and match heads visible towards the writer.
    angle = math.radians(-12)
    mx, my = -.100, .355

    def matchbox_piece(material, dx, dy, z, size):
        x = mx + dx * math.cos(angle) - dy * math.sin(angle)
        y = my + dx * math.sin(angle) + dy * math.cos(angle)
        box(material,(x,y,z),size,angle)

    matchbox_piece('Canvas',0,0,.775,(.066,.043,.024))
    matchbox_piece('Paper',0,0,.788,(.060,.038,.003))
    matchbox_piece('DeskD',0,.0215,.772,(.058,.003,.011))
    matchbox_piece('Apron',-.032,0,.767,(.033,.035,.007))
    for j in (-1,0,1):
        matchbox_piece('FirL',-.037,j*.009,.774,(.022,.003,.003))
        matchbox_piece('BrickD',-.047,j*.009,.775,(.007,.005,.006))
    desk = kit.flush('hargrove_room04_desk', export=False)
    palette('KeroseneWornBrass', 'C39355', .49, .22)
    lathe('KeroseneWornBrass',.146,.37,[(.764,.078),(.792,.070),(.810,.042),(.856,.075),(.903,.057),(.915,.035)],10)
    box('Soot',(.146,.37,.923),(.022,.010,.025))
    burner = kit.flush('KeroseneBurner', export=False)
    lathe('ClearChimney',.146,.37,[(.911,.037),(.943,.045),(.997,.053),(1.06,.040),(1.145,.032),(1.161,.036)],10,cap=False)
    chimney = kit.flush('KeroseneChimney', export=False)
    for obj in (burner, chimney):
        obj.parent = desk
    for obj in (desk, burner, chimney):
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'hargrove_room04_desk.glb'),
                             export_format='GLB', use_selection=True)


def planning_model():
    # Two floors shown side by side on the Y/Z axes in the authoring file.
    for ident in (0,1):
        ox=12+ident*10
        def part(x,y,w,d): box('PlanInk',(ox+x,y,.27),(w,d,.44))
        box('FirL',(ox,0,.027),(7.90,8.60,.054))
        for s in (-1,1): part(s*3.92,0,.10,8.60); part(0,s*4.28,7.90,.10)
        if ident==0:
            part(-.23,.55,.10,3.75); part(-2.74,1.46,2.35,.10)
            box('FirD',(ox-.91,.95,.10),(1.28,4.5,.18))
            for i in range(16): box('Apron',(ox-.91,3.15-i*.282,.19+i*.163),(1.18,.27,.18))
            box('Batten',(ox-1.90,-5.6,.025),(3.8,2.6,.05))
        else:
            part(.43,2.10,.12,4.20); part(-1.56,.95,.09,4.21)
            part(.905,.10,.83,.12); part(3.195,.10,1.39,.12); part(-2.72,-1.20,2.30,.12)
            part(0,-2.28,7.8,.12)
            box('PlanBlue',(ox+ROOM[0],2.2,.074),(3.36,4.10,.04))
            box('FirD',(ox-.91,1.30,.088),(1.09,4.38,.06))
            box('FirD',(ox,-.54,.086),(7.8,1.16,.06))
            box('Apron',(ox+2.17+NORTH,4.27,.36),(.86,.14,.18))
    kit.flush('hargrove_floor_plans', export=False)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    SOURCE.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system='METRIC'
    materials()
    palette('ClearChimney','D6DDD9', .16)
    glass=kit.MATS['ClearChimney']
    glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.15
    import build_black_creek_residential_kit as residential
    residential.register()
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if '--room-lamps' in args:
        room_desk()
        residential.room_details()
        bpy.data.objects['hargrove_room04_desk'].location = (1.25, .70, 0)
        target = POLISH.with_name('hargrove_finish')
        target.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(target/'room04_lamps.blend'))
        return
    if '--room04' in args:
        room_shell()
        room_desk()
        residential.room_details()
        bpy.data.objects['hargrove_room04_desk'].location = (1.25, .70, 0)
        target = POLISH.with_name('hargrove_final')
        target.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(target/'room04.blend'))
        return
    if '--polish' in args:
        room_desk()
        residential.common()
        kit.furniture(bed_only=True)
        bpy.data.objects['hargrove_room04_desk'].location.x = 6
        bpy.data.objects['room04_iron_bed'].location.x = 8
        POLISH.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(POLISH/'hargrove_polish.blend'))
        return
    exterior()
    room_shell()
    room_desk()
    bpy.data.objects['hargrove_room04_shell'].location.x=34
    bpy.data.objects['hargrove_room04_desk'].location=(35.25, .70, 0)
    for name, location in [('room04_iron_bed', (33.0, .91, 0)), ('room04_washstand', (35.22, -1.63, 0))]:
        bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
        for obj in bpy.context.selected_objects:
            if obj.parent is None:
                obj.location=location
    residential.build()
    bpy.data.objects['hargrove_common_1890'].location.x=45
    bpy.data.objects['hargrove_room04_details'].location.x=34
    for i,name in enumerate(('oil_lantern','lantern_bracket','chamberstick','spruce','cottage_a','cottage_b')):
        bpy.data.objects['black_creek_'+name].location.x=55+i*5
    planning_model()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'hargrove_architecture.blend'))
    render_plan()


def render_plan():
    scene=bpy.context.scene
    scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='STUDIO'
    scene.display.shading.color_type='MATERIAL'
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type='BOTH'
    scene.display.shading.show_specular_highlight=False
    scene.world=bpy.data.worlds.new('Drafting Background')
    scene.world.color=(.14,.15,.17)
    bpy.ops.object.camera_add(location=(17,0,20))
    cam=bpy.context.object
    cam.rotation_euler=(0,0,0)
    cam.data.type='ORTHO'
    cam.data.ortho_scale=20.2
    scene.camera=cam
    scene.render.resolution_x=1400
    scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.filepath=str(SOURCE/'floor_plans.png')
    for obj in scene.objects:
        obj.hide_render=obj.name not in (cam.name,'hargrove_floor_plans')
    bpy.ops.render.render(write_still=True)


if __name__=='__main__':
    main()
