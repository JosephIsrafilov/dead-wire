"""Hollow kerosene-lamp chimney, with rolled rim and a continuous shoulder."""
from pathlib import Path
from math import sin, cos, pi

profile=[(.034,.16),(.039,.17),(.046,.195),(.047,.214),(.043,.237),(.029,.265),(.023,.278),(.023,.385),(.026,.391),(.026,.396)]
vertices=[]
faces=[]
n=24
for inner in [False,True]:
    for r,y in profile:
        r -= .0015 if inner else 0
        for i in range(n):
            angle=i*2*pi/n
            vertices.append((r*cos(angle),y,r*sin(angle)))
for side in range(2):
    offset=side*len(profile)*n
    for j in range(len(profile)-1):
        for i in range(n):
            a=offset+j*n+i+1
            b=offset+j*n+(i+1)%n+1
            face=(a,a+n,b+n,b)
            faces.append(face if side==0 else face[::-1])
for j in [0,len(profile)-1]:
    for i in range(n):
        a=j*n+i+1;b=j*n+(i+1)%n+1;offset=len(profile)*n
        faces.append((a,b,b+offset,a+offset))
p=Path(__file__).resolve().parents[1]/'assets/models/office/chimney.obj'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('\n'.join(['o lamp_chimney','s 1']+['v %.6f %.6f %.6f'%v for v in vertices]+['f '+' '.join(map(str,f)) for f in faces])+'\n')
