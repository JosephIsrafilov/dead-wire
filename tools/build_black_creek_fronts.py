"""Black Creek storefronts. Run with Blender --background --python tools/build_black_creek_fronts.py."""
from pathlib import Path
from math import pi, sin, cos
import random
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'assets/textures/town_v2'
OUT = ROOT / 'assets/models/town'
MATS = {}
R = random.Random(1890)


def xyz(p):
    x,y,z = p
    return x,-z,y


def mat(name, color, rough=.87, source=None, metal=0, tint_texture=False):
    if name in MATS: return MATS[name]
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    rgb=tuple((int(color[i:i+2],16)/255)**2.2 for i in (0,2,4))
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    if source:
        maps=[('print/'+source,'Base Color')] if source.startswith('print/') is False and (TEX/'print'/f'{source}.png').exists() else []
        if not maps: maps=[(source+'_'+a,b) for a,b in [('albedo','Base Color'),('normal','Normal'),('roughness','Roughness')]]
        for a,b in maps:
            t=nt.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(str(TEX/f'{a}.png'),check_existing=True)
            t.interpolation='Closest'
            if b!='Base Color': t.image.colorspace_settings.name='Non-Color'
            if b=='Normal':
                n=nt.nodes.new('ShaderNodeNormalMap'); n.inputs['Strength'].default_value=.65
                nt.links.new(t.outputs['Color'],n.inputs['Color']); nt.links.new(n.outputs['Normal'],p.inputs[b])
            elif b == 'Base Color' and tint_texture:
                tint = nt.nodes.new('ShaderNodeMix')
                tint.data_type = 'RGBA'
                tint.blend_type = 'MULTIPLY'
                tint.inputs['Factor'].default_value = 1.0
                next(socket for socket in tint.inputs if socket.identifier == 'B_Color').default_value = (*rgb, 1.0)
                nt.links.new(t.outputs['Color'], next(s for s in tint.inputs if s.identifier == 'A_Color'))
                nt.links.new(next(s for s in tint.outputs if s.identifier == 'Result_Color'), p.inputs[b])
            else: nt.links.new(t.outputs['Color'],p.inputs[b])
    MATS[name]=m
    return m


def mesh(name, verts, faces, material, scale=.45, paint=None, uv=None):
    m=bpy.data.meshes.new(name); m.from_pydata([xyz(p) for p in verts],[],faces); m.update()
    ob=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(ob); m.materials.append(material)
    layer=m.uv_layers.new(name='texel')
    col=m.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER') if paint else None
    for face in m.polygons:
        n=face.normal
        for li in face.loop_indices:
            idx=m.loops[li].vertex_index; x,y,z=verts[idx]
            coords=(x,y) if abs(n.y)>.45 else ((z,y) if abs(n.x)>.45 else (x,z))
            layer.data[li].uv=uv[idx] if uv else (coords[0]*scale,coords[1]*scale)
            if col:
                shadow=(.36+.64*min(1,max(0,y)/.45))*(.87 if y>paint[1] else 1)
                col.data[li].color=(*(c*shadow for c in paint[0]),1)
    if col: m.color_attributes.active_color=col
    return ob


def pigment(color):
    return tuple((int(color[i:i+2],16)/255)**1.65 for i in (0,2,4))


def box(name, at, size, material, paint=None, angle=0):
    w,h,d=(v/2 for v in size)
    v=[(-w,-h,-d),(w,-h,-d),(w,h,-d),(-w,h,-d),(-w,-h,d),(w,-h,d),(w,h,d),(-w,h,d)]
    x,y,z=at
    v=[(x+i*cos(angle)+k*sin(angle),y+j,z-i*sin(angle)+k*cos(angle)) for i,j,k in v]
    return mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],material,paint=paint)


def beam(name,a,b,size,material):
    p,q=Vector(xyz(a)),Vector(xyz(b))
    bpy.ops.mesh.primitive_cube_add(size=1,location=(p+q)*.5)
    o=bpy.context.object; o.name=name; o.rotation_euler=(q-p).to_track_quat('Z','Y').to_euler()
    o.scale=(size,size,(q-p).length); o.data.materials.append(material)
    return o


def barrel(x,y,z):
    wood=mat('Oak staves','80694f',source='plank'); iron=mat('Hoop iron','4a4843',.68,None,.5)
    for j,(h,r1,r2,m) in enumerate([(.18,.27,.30,wood),(.44,.30,.31,wood),(.18,.31,.26,wood),(.046,.312,.312,iron),(.046,.282,.282,iron),(.046,.281,.281,iron)]):
        off=[.09,.40,.71,.41,.12,.72][j]
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r1,radius2=r2,depth=h,location=xyz((x,y+off,z)))
        ob=bpy.context.object; ob.name='Whisky barrel' if j<3 else 'Riveted hoop'; ob.data.materials.append(m)


def panel(stem,x,y,z,w,h,side,blade=False):
    if blade:
        v=[(x,y-h/2,z-w/2),(x,y-h/2,z+w/2),(x,y+h/2,z+w/2),(x,y+h/2,z-w/2)]
    else:
        v=[(x-side*w/2,y-h/2,z),(x+side*w/2,y-h/2,z),(x+side*w/2,y+h/2,z),(x-side*w/2,y+h/2,z)]
    m=mat('Print '+stem,'ffffff',.93,stem)
    return mesh('Print_'+stem,v,[(0,1,2,3)],m,uv=[(0,0),(1,0),(1,1),(0,1)])


def sash(x,y,z,w,h,s,trim,glass,transom=False):
    box('Reflective wavy glazing',(x,y,z),(w,h,.035),glass)
    for i in (-1,1):
        box('Sash stile',(x+i*w/2,y,z+s*.038),(.092,h+.14,.12),trim)
        box('Sash rail',(x,y+i*h/2,z+s*.038),(w+.14,.088,.12),trim)
    box('Putty muntin',(x,y,z+s*.052),(.035,h,.045),trim)
    if not transom:
        box('Meeting rail',(x,y,z+s*.053),(w,.067,.05),trim)
        box('Projected sill',(x,y-h*.5-.09,z+s*.105),(w+.28,.11,.32),trim)


def gable(w,d,h,rise,roof):
    v=[(-w/2,h,-d/2),(0,h+rise,-d/2),(w/2,h,-d/2),(-w/2,h,d/2),(0,h+rise,d/2),(w/2,h,d/2)]
    mesh('Seamed pitched roof',v,[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(0,2,5,3)],roof)


def paneled_door(x, floor, z, w, side, trim, leaf, glass, glazed=True):
    height = 2.10
    brass = mat('Aged brass', '8f7244', .38, metal=.65)
    iron = mat('Door hinge iron', '38322c', .62, metal=.55)
    for edge in (-1, 1):
        box('Door casing', (x+edge*(w/2+.055), floor+1.08, z), (.11, 2.24, .15), trim)
    box('Door lintel', (x, floor+2.17, z), (w+.22, .13, .15), trim)
    box('Oak threshold', (x, floor+.025, z+side*.06), (w+.20, .05, .29), trim)
    box('Door leaf', (x, floor+height/2, z), (w, height, .075), leaf)
    for edge in (-1, 1):
        box('Leaf stile', (x+edge*(w/2-.065), floor+1.06, z+side*.061), (.11, 2.04, .045), trim)
        box('Raised lower panel', (x+edge*w*.181, floor+.56, z+side*.057), (w*.27, .68, .045), trim)
    for y in (.13, 1.02, 2.01):
        box('Leaf rail', (x, floor+y, z+side*.06), (w-.16, .10, .046), trim)
    if glazed:
        opening_width = w - .24
        glazing_y = floor + 1.54
        bead_z = z + side * .071
        box('Door glazing', (x, glazing_y, z+side*.050), (opening_width, .72, .028), glass)
        for edge in (-1, 1):
            box('Glazing edge bead', (x+edge*(opening_width/2-.020), glazing_y, bead_z), (.040, .64, .024), trim)
            box('Glazing rail', (x, glazing_y+edge*.34, bead_z), (opening_width, .040, .024), trim)
        box('Glazing muntin', (x, glazing_y, bead_z), (.035, .64, .024), trim)
    else:
        box('Raised upper panel', (x, floor+1.53, z+side*.057), (w-.30, .71, .045), trim)
    for y in (.30, 1.83):
        box('Strap hinge', (x-side*(w/2-.065), floor+y, z+side*.089), (.19, .055, .035), iron)
    handle_x = x+side*(w/2-.12)
    box('Lock escutcheon', (handle_x, floor+1.02, z+side*.095), (.07, .17, .024), brass)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=.039,
                                         location=xyz((handle_x, floor+1.06, z+side*.14)))
    bpy.context.object.name = 'Turned brass knob'
    bpy.context.object.data.materials.append(brass)


def combination_depot():
    """The west office uses M1's door, north opening and stove axes."""
    wood = mat('Photographic pine', 'ffffff', source='plank')
    trim = mat('Depot oxide red', 'bd8873', source='plank', tint_texture=True)
    leaf = mat('Depot painted leaf', '9b7563', source='plank', tint_texture=True)
    stone = mat('Rubble foundation', 'ffffff', source='stone')
    roofing = mat('Split slate', '777e83', source='roof', tint_texture=True)
    brick = mat('Chimney brick', 'ffffff', source='brick')
    iron = mat('Signal iron', '413a34', .56, metal=.55)
    glass = mat('Depot cylinder glass', '9d7652', .27, metal=.1)
    bay_glass = mat('Operator bay glazing', '82664f', .30)
    green = mat('Telegraph glass insulators', '4c8278', .25)
    signal = mat('Signal red enamel', 'a24b39')
    linen = mat('Semaphore white stripe', 'cdc1a0')
    wall = (pigment('d5ad67'), 3.05)
    box('Continuous masonry sill', (4.4, .16, -.24), (15.2, .32, 5.32), stone)
    box('Depot clapboard body', (4.4, 1.75, -.24), (15.2, 2.90, 5.27), wood, wall)
    for z in (-2.91, 2.43):
        box('Painted water table', (4.4, .42, z), (15.28, .18, .15), trim)
        for x in (-3.12, 3.04, 6.15, 11.92):
            box('Corner and division casing', (x, 1.81, z), (.16, 2.80, .15), trim)
    # SouthDoor centre and 0.30 m floor datum shared with the town deck.
    paneled_door(-1.6, .30, 2.47, 1.15, 1, trim, leaf, glass)
    for x in (.73, 4.91):
        sash(x, 1.74, 2.45, 1.05, 1.38, 1, trim, glass)
    for x in (1.0, 4.9):
        sash(x, 1.74, -2.91, 1.12, 1.36, -1, trim, glass)
    # Bolt the board to two timber stays above the eave, clear of the casing below.
    for x in (.38, 2.90):
        beam('Station board stay', (x, 3.38, 2.80), (x, 3.75, 3.15), .14, trim)
        box('Station board upright', (x, 3.63, 3.17), (.14, .83, .13), trim)
    box('Station name frame', (1.64, 3.70, 3.27), (3.08, .99, .14), trim)
    panel('depot', 1.64, 3.70, 3.346, 2.95, 2.95 * 116 / 384, 1)
    box('Western Union sign frame', (2.96, 2.37, 2.49), (1.54, .30, .11), trim)
    panel('western_union', 2.96, 2.37, 2.55, 1.42, .25, 1)
    box('Glazed notices frame', (2.96, 1.68, 2.47), (1.24, 1.02, .12), trim)
    panel('depot_notices', 2.96, 1.68, 2.54, 1.12, .88, 1)

    # A continuous canted bay with a sill and head following the same footprint.
    bay = [(-2.87, -2.88), (-2.30, -3.78), (-.70, -3.78), (-.13, -2.88)]
    for a, b in zip(bay, bay[1:]):
        ax, az = a
        bx, bz = b
        mesh('Bay masonry plinth', [(ax, 0, az), (bx, 0, bz), (bx, .34, bz), (ax, .34, az)],
             [(3, 2, 1, 0)], stone)
        mesh('Bay apron', [(ax, .34, az), (bx, .34, bz), (bx, 1.22, bz), (ax, 1.22, az)],
             [(3, 2, 1, 0)], wood, paint=wall)
        mesh('Bay glazing', [(ax, 1.22, az), (bx, 1.22, bz), (bx, 2.44, bz), (ax, 2.44, az)],
             [(3, 2, 1, 0)], bay_glass)
        for y in (1.22, 1.83, 2.44):
            beam('Bay sill and sash rails', (ax, y, az-.04), (bx, y, bz-.04), .092, trim)
        beam('Bay sash muntin', ((ax+bx)/2, 1.22, (az+bz)/2-.028),
             ((ax+bx)/2, 2.44, (az+bz)/2-.028), .037, trim)
    for x, z in bay:
        box('Bay corner post', (x, 1.45, z), (.13, 2.26, .13), trim)
    # Closed roof ring with the rear edge embedded below the main eave.
    lower = [(-3.01, -2.83), (-2.38, -3.97), (-.62, -3.97), (.01, -2.83)]
    upper = [(-2.75, -2.74), (-2.23, -2.70), (-.77, -2.70), (-.25, -2.74)]
    for a, b in zip(range(3), range(1, 4)):
        mesh('Bay roof pitch',
             [(lower[a][0], 2.52, lower[a][1]), (lower[b][0], 2.52, lower[b][1]),
              (upper[b][0], 3.16, upper[b][1]), (upper[a][0], 3.16, upper[a][1])],
             [(3, 2, 1, 0)], roofing)
        beam('Bay fascia', (lower[a][0], 2.51, lower[a][1]), (lower[b][0], 2.51, lower[b][1]), .12, trim)
    # Ridge runs parallel to the railway.
    ridge = [(x, y, z) for x in (-3.91, 12.71) for y, z in [(3.19, -3.48), (5.07, -.24), (3.19, 3.18)]]
    mesh('Main pitched roof', ridge, [(0, 1, 4, 3), (1, 2, 5, 4), (0, 2, 1), (3, 4, 5), (0, 3, 5, 2)], roofing)
    for z in (-3.48, 3.18):
        side = 1 if z > 0 else -1
        beam('Eave fascia', (-3.91, 3.18, z), (12.71, 3.18, z), .16, trim)
        brackets = (-2.93, -.89, 4.65, 7.1, 9.42, 11.75) if side > 0 else (
                   -2.93, -.02, 2.28, 4.65, 7.1, 9.42, 11.75)
        for x in brackets:
            beam('Eave bracket', (x, 2.66, z-side*.69), (x, 3.13, z-side*.10), .105, trim)
    for x in (-2.76, -.43):
        box('Porch post', (x, 1.67, 3.08), (.16, 2.74, .16), trim)
    box('Stove chimney', (2.10, 4.15, 1.55), (.55, 2.32, .51), brick)
    box('Chimney drip cap', (2.10, 5.34, 1.55), (.68, .13, .66), stone)
    box('Telegraph roof riser', (0, 4.81, 1.2), (.15, 1.35, .15), trim)
    box('Roof wire crossarm', (0, 5.42, 1.2), (1.2, .11, .14), trim)
    for x in (-.46, 0, .46):
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=.079, radius2=.053,
                                        depth=.12, location=xyz((x, 5.54, 1.2)))
        bpy.context.object.data.materials.append(green)

    # Signal on the lever side of the bay, with two opposed blades and spectacle boxes.
    sx, sz = -3.48, -3.58
    box('Train order signal mast', (sx, 3.73, sz), (.16, 6.78, .16), iron)
    for side, y in [(-1, 6.45), (1, 5.71)]:
        box('Semaphore blade', (sx+side*.67, y, sz), (1.58, .21, .095), signal)
        box('Semaphore stripe', (sx+side*1.11, y, sz), (.20, .216, .109), linen)
        box('Semaphore lantern', (sx, y, sz), (.31, .28, .30), iron)
        box('Semaphore lens', (sx, y, sz-.159), (.127, .119, .031), signal)
        beam('Semaphore operating rod', (sx+side*.08, .42, sz), (sx+side*.08, y, sz), .034, iron)
    # The loading door meets the freight side of the same continuous deck.
    for z, side in [(-2.94, -1), (2.47, 1)]:
        box('Freight sliding leaf', (8.82, 1.45, z), (2.55, 2.30, .14), wood, (pigment('9c694c'), 2.62))
        for y in (.38, 2.51):
            box('Freight door rail', (8.82, y, z+side*.09), (2.51, .13, .10), trim)
        beam('Freight door diagonal', (7.65, .41, z+side*.11), (9.99, 2.49, z+side*.11), .11, trim)
        box('Overhead sliding track', (9.42, 2.73, z+side*.08), (4.08, .09, .09), iron)
        for x in (7.82, 9.79):
            box('Freight door hanger', (x, 2.63, z+side*.10), (.10, .27, .10), iron)
    for x, z, y in [(10.75, -4.20, .58), (11.28, -4.17, .56), (10.84, -4.19, 1.08)]:
        box('Banded freight case', (x, y, z), (.50, .50, .51), wood)
        for edge in (-1, 1):
            box('Freight case batten', (x+edge*.17, y, z-.27), (.06, .50, .05), trim)
    barrel(10.9, .30, 3.05)
    box('Freight truck bed', (9.12, .62, -4.37), (.76, .14, 1.19), wood)
    for x in (8.84, 9.40):
        beam('Freight truck handle', (x, .65, -4.91), (x, 1.17, -5.03), .063, trim)
    beam('Freight truck grip', (8.84, 1.17, -5.03), (9.40, 1.17, -5.03), .057, trim)
    for x in (8.72, 9.52):
        for z in (-4.72, -4.02):
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.135, depth=.055,
                                                location=xyz((x, .435, z)), rotation=(0, pi/2, 0))
            bpy.context.object.name = 'Freight truck cast wheel'
            bpy.context.object.data.materials.append(iron)
    export_model('black_creek_depot')


def storefront(cfg):
    stem,w,d,h,s,tint,trimc,sign,blade=cfg
    sal=stem=='copper_mule'; clinic=stem=='crane_clinic'; assay=stem=='bcw_assay_office'
    z=s*d*.5; gap=1.78 if sal else 1.34
    wood=mat('Photographic pine','ffffff',source='plank'); trim=mat('Trim '+stem,trimc)
    face=mat('Pressed brick','ffffff',source='brick') if assay else wood
    stone=mat('Rubble foundation','ffffff',source='stone'); roof=mat('Split slate','ffffff',source='roof')
    iron=mat('Patinated cast iron','403932',.64,None,.47)
    door=mat('Door '+stem,'4a332c' if sal else '635442')
    glass=mat('Amber glass' if sal else 'Cold cylinder glass','ae8660' if sal else '526266',.23,None,.12)
    paint=(pigment(tint),h-.24)
    # The storefront is three volumes: recessed central bay, forward wings and a raised sign wall.
    box('Stone apron',(0,.19,-s*.28),(w,.46,d-.54),stone)
    box('Back and side shell',(0,(h+.44)/2,-s*.48),(w,h-.44,d-.96),face,paint)
    for k in (-1,1):
        x=k*(w+gap)/4
        box('Shop wing',(x,1.69,z-s*.45),((w-gap)/2,2.58,.91),face,paint)
        box('Foundation return',(x,.22,z-s*.49),((w-gap)/2,.44,.98),stone)
        box('Plinth rail',(x,.53,z+s*.075),((w-gap)/2,.16,.12),trim)
        count=2 if w>9 else 1
        for i in range(count):
            cx=x+(i-(count-1)/2)*((w-gap)/2/count*.90); sw=(w-gap)/2/count*.73
            box('Framed kickplate',(cx,.83,z+s*.04),(sw+.16,.58,.10),trim)
            box('Raised bulkhead panel',(cx,.83,z+s*.11),(sw,.41,.085),door)
            sash(cx,1.79,z+s*.082,sw,1.20,s,trim,glass)
            sash(cx,2.61,z+s*.082,sw,.27,s,trim,glass,True)
            if assay:
                for j in range(9):
                    a=j*pi/8
                    box('Radiating arch voussoir',(cx+cos(a)*(sw/2+.07),2.44+sin(a)*.38,z+s*.12),(.15,.18,.13),stone,angle=0)
        box('Facade corner casing',(k*(w/2-.075),1.70,z+s*.06),(.17,2.73,.19),trim)
        box('Vestibule pilaster',(k*(gap/2+.06),1.63,z+s*.11),(.17,2.61,.29),trim)
        if sal:
            sash(k*(gap/2+.19),1.84,z-s*.38,.36,1.16,s,trim,glass)
    door_z = z-s*.87
    paneled_door(0, .30, door_z, gap-.22, s, trim, door, glass)
    if sal:
        for side in (-1,1):
            x=side*.49; zz=z-s*.43
            v=[(x+side*.36,.85,zz),(x-side*.34,.85,zz),(x-side*.34,1.81,zz),
               (x-side*.15,1.85,zz),(x+side*.15,1.98,zz),(x+side*.36,1.98,zz)]
            mesh('Carved batwing leaf',v,[tuple(range(6))],door)
            for yy in (.91,1.67):
                box('Batwing spring hinge',(x+side*.31,yy,zz+s*.022),(.14,.054,.05),iron)
            for j in range(4):
                box('Batwing recessed beading',(x+(j-1.5)*.15,1.33,zz+s*.035),(.018,.69,.020),trim)
    sash(0, 2.67, door_z+s*.09, gap-.19, .28, s, trim, glass, True)
    step_depth=3.3 if sal else (1.85 if clinic else .94)
    box('Porch',(0,.225,z+s*(step_depth/2-.12)),(w+.27,.15,step_depth),wood)
    box('Outer tread',(0,.075,z+s*(step_depth+.17)),(min(w,4.2),.15,.58),wood)
    face_height=h-1.1
    box('Upper street elevation',(0,(2.98+face_height)/2,z-s*.083),(w,face_height-2.98,.17),face,paint)
    gable(w+.52,d+.50,face_height-.30,1.47 if clinic else 1.04,roof)
    if not clinic:
        box('Raised parapet',(0,h-.33,z-s*.026),(w+.12,.90,.20),face,paint)
        box('Crown center',(0,h+.27,z-s*.02),(w*.71,.32,.24),face,paint)
        for k in (-1,1): box('Stepped shoulders',(k*w*.408,h+.095,z-s*.01),(w*.17,.28,.25),trim)
        for y,depth in [(h-.72,.24),(h-.25,.33),(h+.05,.38)]:
            box('Projecting cornice',(0,y,z+s*.114),(w+.26,.12,depth),trim)
        for i in range(round(w/.37)):
            x=-w*.48+i*.37
            box('Dentil',(x,h-.43,z+s*.20),(.15,.19,.19),trim)
        for i in range(9 if sal else 7):
            x=(i/(8 if sal else 6)-.5)*w*.86
            for dx in (-.095,.095): beam('Carved bracket',(x+dx,h-.77,z),(x+dx,h-.30,z+s*.30),.085,trim)
    if sal or assay:
        for x in (-w*.32,0,w*.32):
            sash(x,h-3.15,z+s*.08,.83,1.53,s,trim,glass)
    if clinic:
        for x in (-w*.29,w*.29):
            box('Painted window apron',(x,1.03,z+s*.12),(2.57,.12,.14),trim)
    if sal or clinic or stem=='miller_mercantile':
        depth=2.45 if sal else 1.55
        canopy=3.20 if not sal else 3.59
        box('Deep porch canopy',(0,canopy,z+s*depth*.51),(w+.30,.17,depth+.23),trim)
        for x in (-w*.44,-w*.21,w*.21,w*.44):
            box('Chamfered column',(x,(canopy+.30)/2,z+s*depth),(.19,canopy-.30,.22),trim)
            for y in (.42,canopy-.30): box('Post cap',(x,y,z+s*depth),(.27,.13,.28),trim)
            beam('Knee brace',(x,canopy-.66,z+s*depth),(x,canopy-.08,z+s*(depth-.59)),.113,trim)
        if sal:
            for i in range(43):
                x=-w*.49+i*.28
                for yy,sz in ((.21,.054),(.45,.079),(.68,.05)):
                    box('Turned balcony spindle',(x,canopy+yy,z+s*depth),(sz,.25,sz),trim)
            for y in (.20,.88): box('Balustrade rail',(0,canopy+y,z+s*depth),(w,.14,.15),trim)
        if stem=='miller_mercantile':
            canvas=mat('Faded canvas','cba57e'); stripe=mat('Ochre painted canvas','8f644b')
            for i in range(27):
                xx=(i-13)*w/27
                box('Striped valance',(xx,canopy-.15,z+s*1.73),(w/27,.23,.045),canvas if i%2 else stripe)
    chimney_x=w*.31
    box('Brick stovepipe chimney',(chimney_x,face_height+.39,-s*d*.25),(.51,1.87,.48),mat('Chimney brick','ffffff',source='brick'))
    box('Chimney crown',(chimney_x,face_height+1.35,-s*d*.25),(.68,.16,.64),stone)
    if sign:
        sign_y= h-1.08 if sal else (h-1.12)
        sign_width=w*(.78 if sal else .70)
        box('Carved sign surround',(0,sign_y,z+s*.21),(sign_width+.16,.87,.15),trim)
        panel(sign,0,sign_y,z+s*.30,sign_width,.76,s)
    if blade:
        bx=w*.33; by=2.56; bz=z+s*1.19
        beam('Wrought sign bracket',(bx,by+.50,z),(bx,by+.50,bz+s*.65),.058,iron)
        beam('Bracket scroll',(bx,by+.29,z),(bx,by+.50,bz+s*.29),.036,iron)
        box('Hanging blade core',(bx,by,bz),(.08,.60,1.27),trim)
        for dz in (-.43,.43): beam('Swing loop',(bx,by+.25,bz+dz),(bx,by+.51,bz+dz),.025,iron)
        front=panel(blade,bx+.047,by,bz,1.18,.51,s,True)
        panel(blade,bx-.047,by,bz,1.18,.51,s,True)
        for uv in front.data.uv_layers[0].data: uv.uv.x=1-uv.uv.x
    base_z=z+s*(1.57 if sal else .43)
    if sal or stem=='miller_mercantile':
        for x in (-w*.41,w*.43): barrel(x,.30,base_z)
    if sal:
        panel('billiards',w*.31,1.85,z+s*.155,1.25,.54,s)
        panel('beer',-gap*.71,1.29,z+s*.109,.39,.48,s)
        panel('silver_spur',gap*.73,1.34,z+s*.112,.40,.46,s)
    if assay: panel('paymaster',w*.30,1.77,z+s*.16,1.23,.50,s)
    if clinic:
        sign_z=z+s*1.66
        box('Physician sign fascia',(0,3.15,sign_z),(3.42,.80,.11),iron)
        panel('clinic_physician',0,3.15,sign_z+s*.061,3.32,.70,s)
        for x in (-1.42,1.42):
            beam('Physician fascia strap',(x,3.12,sign_z),(x,3.66,z+s*.82),.064,iron)
        panel('closed',-w*.30,1.85,z+s*.169,.49,.40,s)
    if stem=='miller_mercantile':
        panel('miller_ghost',0,3.7,z+s*.009,w*.75,.68,s)
        for x,y in [(-3,.55),(-3.17,1.05),(-2.48,.54)]: box('Freight case',(x,y,z+s*.73),(.52,.49,.47),wood)
    if stem=='chronicle_print_shop':
        panel('newspaper',-w*.27,1.78,z+s*.153,.49,.67,s)
        panel('newspaper_2',w*.27,1.92,z+s*.153,.47,.65,s)
    export_model(stem)


def export_model(stem):
    # Keep each material to a draw call; do not merge unlike attributes.
    groups={}
    for ob in list(bpy.context.scene.objects):
        m=ob.data.materials[0]
        key=(m.name,bool(ob.data.color_attributes),ob.name.startswith('Print_'))
        if not key[2]: groups.setdefault(key,[]).append(ob)
    for (name,col,_), objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects: ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1: bpy.ops.object.join()
        objects[0].name=name+(' | grade and eave AO' if col else '')
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{stem}.glb'),export_format='GLB',export_vertex_color='ACTIVE')


CONFIGS=[('copper_mule',12,15,8.75,-1,'ae6557','ae8657','copper_mule','saloon'),
         ('miller_mercantile',10,13.6,6.17,-1,'c4a05f','9f7951','miller','post'),
         ('bcw_assay_office',9,10,6.2,1,'d4b4a5','7a766a','assay',None),
         ('crane_clinic',8,10,4.8,-1,'889ca9','a49a85',None,None),
         ('chronicle_print_shop',6,9.5,5.5,1,'ccc5a5','61705c','chronicle','printer')]

if __name__=='__main__':
    import sys
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if not wanted or 'black_creek_depot' in wanted:
        bpy.ops.wm.read_factory_settings(use_empty=True); MATS.clear()
        combination_depot()
    for cfg in CONFIGS:
        if wanted and cfg[0] not in wanted: continue
        bpy.ops.wm.read_factory_settings(use_empty=True); MATS.clear()
        storefront(cfg)
