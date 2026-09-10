"""Author the low-poly operator's writing hand and tailored sleeve as OBJ meshes.

Cross-sections follow wrist, palm and bent finger anatomy. Re-run only when the
authored proportions change; the game loads the exported meshes directly.
"""
from pathlib import Path
from math import sin, cos, pi

OUT = Path(__file__).resolve().parents[1] / 'assets/models/operator'
OUT.mkdir(parents=True, exist_ok=True)

def mesh(name, parts):
    vertices, faces = [], []
    for rings in parts:
        base = len(vertices)
        sides = 10
        for x, y, z, rx, ry in rings:
            for i in range(sides):
                a = i * 2 * pi / sides
                vertices.append((x + cos(a)*rx, y + sin(a)*ry, z))
        faces.append(tuple(base+i+1 for i in reversed(range(sides))))
        for j in range(len(rings)-1):
            for i in range(sides):
                a=base+j*sides+i+1
                b=base+j*sides+(i+1)%sides+1
                faces.append((a,b,b+sides,a+sides))
        end=base+(len(rings)-1)*sides
        faces.append(tuple(end+i+1 for i in range(sides)))
    text=['# DEAD WIRE authored writing anatomy', 'o '+name, 's 1']
    text += ['v %.6f %.6f %.6f'%v for v in vertices]
    text += ['f '+' '.join(map(str,f)) for f in faces]
    (OUT/(name+'.obj')).write_text('\n'.join(text)+'\n')

mesh('hand', [
    # Wrist to metacarpals, palm and knuckles.
    [(0,0,.035,.018,.012),(0,0,.02,.023,.013),(.003,0,0,.031,.015),(.004,-.002,-.022,.03,.014),(.004,-.005,-.032,.025,.01)],
    # Index arches toward the pen; middle supports the grip below it.
    [(-.018,.002,-.022,.008,.008),(-.018,.011,-.04,.008,.007),(-.012,.004,-.057,.007,.007),(-.006,-.012,-.059,.006,.006),(-.004,-.019,-.05,.003,.004)],
    [(-.002,-.006,-.026,.008,.008),(.005,-.013,-.044,.008,.008),(.009,-.025,-.051,.007,.007),(.003,-.03,-.043,.004,.005)],
    [(.013,-.008,-.025,.008,.008),(.022,-.016,-.04,.008,.007),(.024,-.029,-.038,.007,.006),(.018,-.032,-.025,.004,.005)],
    [(.027,-.008,-.018,.007,.007),(.035,-.017,-.029,.007,.006),(.034,-.029,-.027,.006,.005),(.028,-.03,-.017,.003,.004)],
    # Opposing thumb, flattened pad closes onto shaft.
    [(-.023,-.003,.003,.012,.01),(-.031,-.008,-.014,.011,.009),(-.028,-.018,-.033,.009,.008),(-.013,-.022,-.047,.009,.007),(-.006,-.021,-.049,.004,.005)]
])
mesh('sleeve', [[(0,0,-.08,.019,.014),(.002,.004,-.04,.025,.020),(.006,.009,0,.030,.024),(.018,.018,.07,.035,.028),(.035,.025,.15,.039,.031),(.06,.035,.25,.040,.031),(.10,.06,.48,.050,.036)]])
mesh('cuff', [[(0,0,-.025,.023,.016),(0,0,-.019,.026,.019),(0,0,.02,.026,.02),(0,0,.026,.024,.018)]])
