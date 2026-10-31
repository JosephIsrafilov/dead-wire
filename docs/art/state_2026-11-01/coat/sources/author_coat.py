"""Coat shape/material study. Run in Blender through MCP, or headless:

    blender --background --factory-startup --python author_coat.py

Writes coat_A.glb / coat_B.glb and dead_wire_coat.blend next to this file;
the game uses coat_B.glb copied to assets/models/office_props_v1/coat_tailored.glb.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector
import numpy as np
ROOT = Path(__file__).resolve().parent
NAME = 'DW_Coat_Study_Tailored'
if bpy.app.background:
    # Headless runs start from factory settings: the default scene is ours.
    scene = bpy.context.scene
    for o in list(scene.objects): bpy.data.objects.remove(o, do_unlink=True)
    scene.name = NAME
else:
    # Work in a separate scene, never delete the user's original scene.
    scene = bpy.data.scenes.new(NAME)
    bpy.context.window.scene = scene
verts, faces, uvfaces = [], [], []
def vertex(p):
    verts.append(tuple(p)); return len(verts)-1
def face(ids, uv=None):
    faces.append(ids)
    uvfaces.append(uv or [(verts[i][0]*3, verts[i][1]*3) for i in ids])
N = 24
profile = [(1.985,.068,.037),(1.953,.115,.052),(1.900,.173,.065),
           (1.840,.181,.075),(1.760,.166,.068),(1.690,.151,.063),
           (1.590,.160,.070),(1.490,.173,.077),(1.390,.185,.082),
           (1.290,.196,.087),(1.180,.203,.087)]
grid=[]
for r,(y,w,d) in enumerate(profile):
    t=r/(len(profile)-1)
    opening=.007 + .044*max(0,1-t*2.7)**2 + .025*max(0,(t-.55)/.45)**2
    gap=math.asin(min(.9,opening/w))
    row=[]
    for c in range(N+1):
        theta=-math.pi/2+gap+(2*math.pi-2*gap)*c/N
        # Broad tension folds, not a uniformly corrugated tube.
        fold=(.007*math.sin(theta*5+.4)+.004*math.cos(theta*9-.6))*max(0,(t-.22)/.78)
        x=math.cos(theta)*(w+fold)
        z=math.sin(theta)*(d+fold*.75)
        yy=y-.014
        if r<3: yy-=.035*abs(math.cos(theta)) + (.034 if r==0 else .014)*max(0,-math.sin(theta))
        yy+=.007*math.sin(theta*2+.5)*t*t
        row.append(vertex((x,yy,z)))
    grid.append(row)
# Excise two real armholes. Their boundary vertices are shared with sleeves.
holes=[(4,7,1),(17,20,-1)]
for r in range(len(grid)-1):
    for c in range(N):
        if 2<=r<4 and any(a<=c<b for a,b,s in holes): continue
        ids=[grid[r][c],grid[r+1][c],grid[r+1][c+1],grid[r][c+1]]
        circumference=2*math.pi*math.sqrt((profile[r][1]**2+profile[r][2]**2)/2)
        u0=c/N*circumference*3; u1=(c+1)/N*circumference*3
        face(ids,[(u0,profile[r][0]*3),(u0,profile[r+1][0]*3),(u1,profile[r+1][0]*3),(u1,profile[r][0]*3)])
seams=[]
for a,b,side in holes:
    boundary=[grid[2][c] for c in range(a,b+1)]
    boundary += [grid[r][b] for r in range(3,5)]
    boundary += [grid[4][c] for c in range(b-1,a-1,-1)]
    boundary += [grid[3][a]]
    seams.extend([(boundary[i],boundary[(i+1)%len(boundary)]) for i in range(len(boundary))])
    center=sum((Vector(verts[i]) for i in boundary),Vector())/len(boundary)
    angles=[math.atan2((verts[i][2]-center.z)/.065,(verts[i][1]-center.y)/.067) for i in boundary]
    prev=boundary
    # Soft shoulder cap, heavy upper arm, compressed elbow, flattened cuff.
    sections=[(.181,1.792,-.007,.046,.043),(.192,1.735,-.018,.045,.037),
              (.198,1.645,-.035,.040,.031),(.194,1.595,-.045,.040,.028),
              (.183,1.515,-.058,.036,.024),(.176,1.425,-.063,.033,.020),
              (.175,1.401,-.062,.034,.020)]
    for k,(cx,cy,cz,rx,rz) in enumerate(sections):
        curr=[]
        # A coat on a hook has no arm in it: at the armhole the sleeve ring
        # stands upright like the armhole itself, and only turns into a hanging
        # tube by the elbow. A level ring there pulled the armhole's top out to
        # the sleeve's outer edge and made a hard, raised shoulder point.
        hang=min(1.0,k/2)
        for ang in angles:
            wrinkle=1+.06*math.sin(ang*3+k*.6)
            curr.append(vertex((side*(cx+math.cos(ang)*rx*wrinkle*hang),
                cy +(.012 if side<0 else .025)+math.cos(ang)*rx*(.18*hang+.85*(1-hang)),
                cz+math.sin(ang)*rz*wrinkle)))
        for j in range(len(prev)):
            jj=(j+1)%len(prev)
            u=j/len(prev)*.30*3; un=(j+1)/len(prev)*.30*3
            face([prev[j],curr[j],curr[jj],prev[jj]],[(u,(cy+.06)*3),(u,cy*3),(un,cy*3),(un,(cy+.06)*3)])
        prev=curr
# Rolled collar grows from neckline; no separate floating ring.
prev=grid[0]
for scale,dy in [(1.14,.018),(1.12,.040)]:
    curr=[vertex((verts[i][0]*scale,verts[i][1]+dy,verts[i][2]*scale)) for i in grid[0]]
    for j in range(N): face([prev[j],prev[j+1],curr[j+1],curr[j]])
    prev=curr
# Narrow folded lapels, joined to the two front opening edges.
for col,side in [(0,1),(N,-1)]:
    edge=[grid[r][col] for r in range(6)]
    width=[.014,.038,.045,.034,.016,0]
    outer=[]
    for r,i in enumerate(edge):
        p=Vector(verts[i]); p.x+=side*width[r]; p.z-=.010+width[r]*.35
        outer.append(vertex(p))
    for r in range(5): face([edge[r],edge[r+1],outer[r+1],outer[r]])

def wool(name, rgb, seed):
    rng=np.random.default_rng(seed); size=64
    yy,xx=np.mgrid[:size,:size]
    weave=((xx+yy*2)%4==0)*1.5-((xx-yy)%4==0)*1.0
    noise=rng.normal(0,1.4,(size,size))+weave
    data=np.ones((size,size,4),np.float32)
    for c in range(3): data[:,:,c]=np.clip((rgb[c]+noise)/255,0,1)
    im=bpy.data.images.new(name, width=size,height=size,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.ravel())
    im.filepath_raw=str(ROOT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value=1
    p.inputs['Specular IOR Level'].default_value=0
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
    mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    return mat
charcoal=wool('Wool_A_charcoal',(112,115,114),12)
peat=wool('Wool_B_peat',(119,111,98),12)
lining=bpy.data.materials.new('Dark cotton lining'); lining.diffuse_color=(.045,.043,.039,1); lining.use_nodes=True
lining.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=lining.diffuse_color
lining.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=1
# Convert Godot metres to Blender coordinates, origin is the coat's floor centre.
mesh=bpy.data.meshes.new('Continuous tailored shell')
mesh.from_pydata([(x,-z,y) for x,y,z in verts],[],faces); mesh.update()
uv=mesh.uv_layers.new(name='Wool metre scale')
for poly,coords in zip(mesh.polygons,uvfaces):
    for li,coord in zip(poly.loop_indices,coords): uv.data[li].uv=coord
obj=bpy.data.objects.new('Tailored_coat_JOINED_sleeves',mesh); scene.collection.objects.link(obj)
obj.data.materials.append(charcoal); obj.data.materials.append(lining)
bm=bmesh.new(); bm.from_mesh(mesh)
# The excised armhole centre vertices are no longer needed.
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
# Same outer vertex at either side of every armhole edge = no disconnected sleeve.
bm=bmesh.new(); bm.from_mesh(mesh)
bm.verts.ensure_lookup_table()
visited=set(); stack=[bm.verts[0]]
while stack:
    v=stack.pop()
    if v in visited: continue
    visited.add(v); stack.extend(e.other_vert(v) for e in v.link_edges)
assert len(visited)==len(bm.verts), 'Shell is disconnected'
assert not [e for e in bm.edges if len(e.link_faces)>2], 'Non-manifold outer shell'
print('SHELL connected vertices',len(visited),'faces',len(mesh.polygons),'armhole shared edges',len(seams))
bm.free()
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
solid=obj.modifiers.new('Wool edge thickness 2mm','SOLIDIFY'); solid.thickness=.002; solid.offset=-1; solid.material_offset=1; solid.material_offset_rim=1
bpy.ops.object.modifier_apply(modifier=solid.name)
# Applied, closed shell includes lining and cuff rims; no subdivision.
# Two restrained pocket flaps and dark horn buttons, attached details rather than noise.
for side in [-1,1]:
    vv=[(side*.052,1.571,-.077),(side*.139,1.579,-.057),(side*.137,1.552,-.064),(side*.051,1.544,-.083)]
    me=bpy.data.meshes.new('Pocket flap'); me.from_pydata([(x,-z,y) for x,y,z in vv],[],[(0,1,2,3)]); me.update()
    po=bpy.data.objects.new('Pocket_L' if side<0 else 'Pocket_R',me); scene.collection.objects.link(po); me.materials.append(charcoal)
    uv=me.uv_layers.new(name='Wool metre scale')
    for loop in me.loops:
        x,y,z=vv[loop.vertex_index]; uv.data[loop.index].uv=(x*3,y*3)
    so=po.modifiers.new('Turned pocket edge','SOLIDIFY'); so.thickness=.002
    bpy.context.view_layer.objects.active=po; bpy.ops.object.modifier_apply(modifier=so.name)
buttonmat=bpy.data.materials.new('Dull horn buttons'); buttonmat.diffuse_color=(.035,.030,.024,1)
for y,z in [(1.718,-.077),(1.654,-.078),(1.590,-.086)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.0055,depth=.002,location=(.025,-z,y),rotation=(math.pi/2,0,0))
    b=bpy.context.object; b.name='Horn button'; b.data.materials.append(buttonmat)
# Save only study objects for GLB export, in local coordinates.
models=[o for o in scene.objects if o.type=='MESH']
for variant,mat in [('A',charcoal),('B',peat)]:
    for o in models:
        if o.data.materials and o.data.materials[0] in (charcoal,peat): o.data.materials[0]=mat
    bpy.ops.object.select_all(action='DESELECT')
    for o in models: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/('coat_'+variant+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
# Owner selected B: leave the saved study in the warm-grey wool.
# Neutral modelling presentation only, not a replacement for room lighting.
world=bpy.data.worlds.new('Coat study neutral'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.06,.07,.08,1); scene.world=world
bpy.ops.object.camera_add(location=(.9,2.1,1.85)); camera=bpy.context.object; camera.name='Coat study camera'
camera.rotation_euler=(Vector((0,0,1.60))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=1.12; scene.camera=camera
for name,loc,power,size in [('Key',(-1.2,1.8,2.8),95,1.6),('Rim',(1,-.8,2.3),65,1.0)]:
    bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; l.name='Study '+name; l.data.energy=power; l.data.shape='DISK'; l.data.size=size; l.rotation_euler=(Vector((0,0,1.6))-l.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=900; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(ROOT/'blender_study.png')
scene.view_settings.view_transform='Standard'
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
for area in (bpy.context.screen.areas if bpy.context.screen else []):
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=1.4; area.spaces.active.region_3d.view_location=(0,0,1.60)
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'dead_wire_coat.blend'))
print('SAVED',ROOT,'shell triangles',sum(len(p.vertices)-2 for p in obj.data.polygons))
