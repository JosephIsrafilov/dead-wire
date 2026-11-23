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


def mat(name, color, rough=.87, source=None, metal=0):
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


def storefront(cfg):
    stem,w,d,h,s,tint,trimc,sign,blade=cfg
    sal=stem=='copper_mule'; depot=stem=='black_creek_depot'; clinic=stem=='crane_clinic'; assay=stem=='bcw_assay_office'
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
    sx=-1.6 if depot else 0
    door_z=z-s*.87 if not depot else z-.21
    box('Door jamb',(sx,1.49,door_z),(gap,2.31,.11),trim)
    box('Door recess',(sx,1.46,door_z+s*.072),(gap-.22,2.11,.06),door)
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
    else:
        for j in (-1,1):
            box('Door field panel',(sx+j*.29,1.12,door_z+s*.118),(.46,1.05,.065),trim)
    sash(sx,2.67,door_z+s*.09,gap-.19,.28,s,trim,glass,True)
    if not depot:
        step_depth=3.3 if sal else (1.85 if clinic else .94)
        box('Porch',(0,.225,z+s*(step_depth/2-.12)),(w+.27,.15,step_depth),wood)
        box('Outer tread',(0,.075,z+s*(step_depth+.17)),(min(w,4.2),.15,.58),wood)
    face_height=h-(1.1 if not depot else .68)
    box('Upper street elevation',(0,(2.98+face_height)/2,z-s*.083),(w,face_height-2.98,.17),face,paint)
    gable(w+.52,d+.50,face_height-.30,1.47 if clinic or depot else 1.04,roof)
    if not clinic and not depot:
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
        sign_y= h-1.08 if sal else (3.02 if depot else h-1.12)
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
    if depot:
        bx=3.3
        box('Glazed notices frame',(bx,1.8,2.19),(1.30,.99,.14),trim)
        panel('depot_notices',bx,1.8,2.267,1.18,.87,1)
        panel('western_union',-2.52,2.60,2.26,1.26,.46,1)
        for x in (-.81,0,.81):
            zz=-d*.51-(.75 if not x else .43)
            box('Telegraph bay sill',(x,1.17,zz),(.94,.14,.89),trim)
            sash(x,1.96,zz-.35,.71,1.29,-1,trim,glass)
        box('Roof wire riser',(0,4.46,2.0),(.17,1.14,.17),trim)
        box('Roof crossarm',(0,4.94,2.0),(1.14,.11,.15),trim)
        for x in (-.42,0,.42): box('Roof insulator',(x,5.03,2.0),(.09,.08,.09),glass)
        box('Loading door',(w*.30,1.48,-d*.53),(1.62,2.03,.18),door)
        for i in (-1,1): beam('Sliding door cross buck',(w*.30-.73,1.48+i*.91,-d*.56),(w*.30+.73,1.48-i*.91,-d*.56),.10,trim)
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
         ('black_creek_depot',8,4.2,4.26,1,'c5ae6d','805240','depot',None),
         ('crane_clinic',8,10,4.8,-1,'889ca9','a49a85',None,None),
         ('chronicle_print_shop',6,9.5,5.5,1,'ccc5a5','61705c','chronicle','printer')]

if __name__=='__main__':
    import sys
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for cfg in CONFIGS:
        if wanted and cfg[0] not in wanted: continue
        bpy.ops.wm.read_factory_settings(use_empty=True); MATS.clear()
        storefront(cfg)
