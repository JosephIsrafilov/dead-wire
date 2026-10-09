"""Author the fixed hand's connected patch topology in sheet metres from the nib.
No collision clamp, skin-union/remesh or runtime IK. Build JSON is source, not mocap.
Run from the repository root, then tools/build_authored_writer_hand.gd in Godot.
"""
import json
from pathlib import Path
import numpy as np

OUT = Path("assets/models/operator/hand_authored_v1.json")
FRAME = json.loads(Path("assets/models/operator/hand_authored_frame.json").read_text())
axis, up, left, grip = [np.array(FRAME[k]) for k in ("axis", "up", "left", "grip")]
vertices, faces, groups, nail_faces = [], [], [], set()

def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)

def vertex(p):
    vertices.append(np.asarray(p, float))
    return len(vertices) - 1

def tri(a, b, c, part):
    faces.append([int(a), int(b), int(c)])
    groups.append(part)

def quad(a, b, c, d, part):
    tri(a, b, c, part)
    tri(a, c, d, part)

# Dorsal/volar nine-column patches: each pair of columns owns one finger.
# x-edge, x-edge, z, dorsal-y, volar-y, transverse crown.
palm_rows = [
    (.030, .090, .126, .041, .012, .002),
    (.026, .076, .104, .040, .011, .003),
    (.013, .078, .083, .040, .010, .004),
    (.017, .077, .079, .038, .012, .004),
]
top, bottom, middle = [], [], []
for lo, hi, z, ty, by, crown in palm_rows:
    ts, bs = [], []
    for i in range(9):
        t = i / 8
        # A slight cup, not a uniformly thick palm slab.
        x = lo + (hi - lo) * t
        ts.append(vertex([x, ty + crown * np.sin(np.pi*t), z + .004*(t-.5)]))
        bs.append(vertex([x, by + .002*np.sin(np.pi*t), z + .004*(t-.5)]))
    top.append(ts); bottom.append(bs)
    middle.append([vertex((vertices[ts[0]] + vertices[bs[0]])/2),
                   vertex((vertices[ts[-1]] + vertices[bs[-1]])/2)])
# MCP row is staggered; web points recede between the four knuckles.
xs = [.010, .018, .027, .035, .043, .051, .059, .067, .075]
zs = [.066, .054, .061, .051, .060, .054, .065, .061, .073]
tys = [.034, .039, .036, .035, .031, .030, .026, .025, .022]
bys = [.017, .020, .017, .017, .014, .014, .012, .012, .012]
ts=[vertex([x,y,z]) for x,y,z in zip(xs,tys,zs)]
bs=[vertex([x,y,z+.002]) for x,y,z in zip(xs,bys,zs)]
top.append(ts);bottom.append(bs)
web=[vertex((vertices[ts[i]]+vertices[bs[i]])/2) for i in range(0,9,2)]
middle.append([web[0],web[-1]])
for row in range(4):
    for col in range(8):
        quad(top[row][col],top[row+1][col],top[row+1][col+1],top[row][col+1],0)
        quad(bottom[row][col+1],bottom[row+1][col+1],bottom[row+1][col],bottom[row][col],0)
    # Ulnar side is continuous; radial side has one deliberately authored thumb port.
    quad(top[row][-1],top[row+1][-1],middle[row+1][1],middle[row][1],0)
    quad(middle[row][1],middle[row+1][1],bottom[row+1][-1],bottom[row][-1],0)
    if row not in (1,2):
        quad(top[row][0],middle[row][0],middle[row+1][0],top[row+1][0],0)
        quad(middle[row][0],bottom[row][0],bottom[row+1][0],middle[row+1][0],0)
# Closed wrist back, buried in the unchanged cuff.
back=top[0]+[middle[0][1]]+list(reversed(bottom[0]))+[middle[0][0]]
centre=vertex(np.mean([vertices[i] for i in back],axis=0))
for i in range(len(back)):tri(centre,back[(i+1)%len(back)],back[i],0)

# Ring order: dorsal left/centre/right, radial side, volar right/centre/left, ulnar side.
angles=np.array([3*np.pi/4,np.pi/2,np.pi/4,0,-np.pi/4,-np.pi/2,-3*np.pi/4,np.pi])

def ring(c, tangent, dorsal, width, depth):
    tangent=unit(tangent)
    dorsal=unit(np.asarray(dorsal)-tangent*np.dot(dorsal,tangent))
    side=unit(np.cross(tangent,dorsal))
    return [vertex(np.asarray(c)+side*np.cos(a)*width+dorsal*np.sin(a)*depth) for a in angles]

def bridge(a,b,part,nail=False):
    for k in range(8):
        start=len(faces)
        quad(a[k],b[k],b[(k+1)%8],a[(k+1)%8],part)
        if nail and k in (0,1):nail_faces.update((start,start+1))

def digit(root, points, widths, part):
    # MCP/PIP/DIP/pad centres are authored; rings are skin, not extra joints.
    points=[np.asarray(p,float) for p in points]
    sections=[]
    if part == 5:
        sections.append((np.array([-.004,.027,.083]),unit([-.8,.02,-.6]),.012,.011))
    for i in range(1,len(points)-1):
        incoming=unit(points[i]-points[i-1])
        outgoing=unit(points[i+1]-points[i])
        # One anatomical joint plane, not three near-coincident rings whose
        # radii exceed their curvature radius on the inside of the bend.
        tangent=unit(incoming+outgoing)
        sections.append((points[i],tangent,widths[i],widths[i]*.78))
    tangent=unit(points[-1]-points[-2])
    sections.extend([(points[-1]-.004*tangent,tangent,widths[-1],widths[-1]*.78),
                     (points[-1],tangent,widths[-1]*.70,widths[-1]*.60)])
    prev=root
    root_centre=np.mean([vertices[k] for k in root],axis=0)
    old_tangent=unit(sections[0][0]-root_centre)
    dorsal=unit(vertices[root[1]]-vertices[root[5]])
    dorsal=unit(dorsal-old_tangent*np.dot(dorsal,old_tangent))
    for i,(c,t,w,h) in enumerate(sections):
        # Parallel transport preserves dorsal orientation through a curl.
        # Projecting one world-up vector per ring flips the underside at turns.
        turn=np.cross(old_tangent,t)
        cosine=np.dot(old_tangent,t)
        if np.linalg.norm(turn)>1e-9:
            dorsal=dorsal+np.cross(turn,dorsal)+np.cross(turn,np.cross(turn,dorsal))/(1+cosine)
        dorsal=unit(dorsal-t*np.dot(dorsal,t))
        old_tangent=t
        nxt=ring(c,t,dorsal,w,h)
        bridge(prev,nxt,part,nail=(i==len(sections)-2))
        prev=nxt
    cap=vertex(points[-1]+tangent*widths[-1]*.20)
    for k in range(8):tri(cap,prev[k],prev[(k+1)%8],part)

radius=.0040
it=grip+axis*.006+up*(radius+.0042)
md=unit(-up*.45-left*.90)
mt=grip-axis*.003+md*(radius+.0034)
tt=grip+axis*.001+left*(radius+.0060)
chains=[
    ([.018,.033,.055],[.019,.044,.027],[.002,.037,.014],it),
    ([.035,.027,.052],[.033,.017,.028],mt+md*.009+np.array([0,0,.006]),mt),
    ([.051,.023,.055],[.054,.013,.030],[.053,.008,.016],[.046,.008,.013]),
    ([.067,.019,.063],[.075,.012,.047],[.077,.008,.033],[.072,.008,.027]),
]
widths=[(.008,.0074,.0068,.0055),(.008,.007,.0062,.0055),(.0074,.007,.006,.0055),(.0063,.006,.0051,.0047)]
for j,pts in enumerate(chains):
    k=j*2
    root=[top[-1][k],top[-1][k+1],top[-1][k+2],web[j+1],bottom[-1][k+2],bottom[-1][k+1],bottom[-1][k],web[j]]
    digit(root,pts,widths[j],j+1)
# Thumb port belongs to the radial palm and spans the thenar, no intersecting overlay.
thumb_root=[top[1][0],top[2][0],top[3][0],middle[3][0],bottom[3][0],bottom[2][0],bottom[1][0],middle[1][0]]
digit(thumb_root,([.014,.026,.085],[-.012,.031,.061],[-.024,.030,.041],tt),(.014,.010,.008,.007),5)

# Orient connected faces by edge adjacency, then one global signed volume.
edges={}
for i,face in enumerate(faces):
    for a,b in zip(face,face[1:]+face[:1]):edges.setdefault(tuple(sorted((a,b))),[]).append((i,a<b))
assert all(len(v)==2 for v in edges.values()), 'Authoring error: open/nonmanifold edge'
adj=[[] for _ in faces]
for uses in edges.values():
    (a,da),(b,db)=uses;adj[a].append((b,da==db));adj[b].append((a,da==db))
flip={0:False};stack=[0]
while stack:
    a=stack.pop()
    for n,toggle in adj[a]:
        wanted=flip[a]^toggle
        if n in flip:assert flip[n]==wanted
        else:flip[n]=wanted;stack.append(n)
assert len(flip)==len(faces), 'Disconnected skin component'
for i in flip:
    if flip[i]:faces[i][1],faces[i][2]=faces[i][2],faces[i][1]
# Remove patch construction helpers not referenced by the final shell.
used=sorted(set(i for face in faces for i in face))
remap={old:new for new,old in enumerate(used)}
vertices=[vertices[i] for i in used]
faces=[[remap[i] for i in face] for face in faces]
vs=np.asarray(vertices)
volume=sum(np.dot(vs[a],np.cross(vs[b],vs[c])) for a,b,c in faces)
if volume<0:
    for face in faces:face[1],face[2]=face[2],face[1]
normals=np.zeros_like(vs)
for a,b,c in faces:
    normal=np.cross(vs[b]-vs[a],vs[c]-vs[a])
    for v in (a,b,c):normals[v]+=normal
assert np.all(np.linalg.norm(normals,axis=1)>1e-12)
normals/=np.linalg.norm(normals,axis=1)[:,None]
OUT.write_text(json.dumps({'units':'metres from nib in sheet space','authorship':'Project-authored connected patches. Anatomical reference, not live motion capture.','parts':['palm','index','middle','ring','little','thumb'],'vertices':np.round(vs,9).tolist(),'normals':np.round(normals,9).tolist(),'faces':faces,'groups':groups,'nail_faces':sorted(nail_faces)},indent=2)+'\n')
print(f'Authored {len(vertices)} welded vertices / {len(faces)} triangles, one closed shell: {OUT}')
