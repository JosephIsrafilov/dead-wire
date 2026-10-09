import json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
parts=json.loads(Path('.dream-loop/hand_mesh.json').read_text())
out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
views={'macro':([.06,.16,.2],[0,.03,0]),'top':([0,.5,.05],[0,0,0]),'left':([-.36,.12,.05],[0,.04,.02]),'right':([.38,.12,.05],[0,.04,.02]),'eye':([.02,.36,.42],[0,.03,.02])}
W,H=1000,750
for name,(eye,target) in views.items():
 eye=np.array(eye); forward=np.array(target)-eye; forward/=np.linalg.norm(forward)
 right=np.cross(forward,[0,1,0]); right/=np.linalg.norm(right); up=np.cross(right,forward)
 img=np.full((H,W,3),[41.,43.,47.]); depth=np.full((H,W),np.inf)
 light=np.array([-.3,.8,.4]); light/=np.linalg.norm(light)
 for part in parts:
  vs=np.array(part['vertices']); cs=np.array(part['colors'])
  if 'SleeveMesh' in part['name']: continue
  for t in range(0,len(vs),3):
   tri=vs[t:t+3]; cam=(tri-eye)@np.array([right,up,forward]).T
   if np.any(cam[:,2]<.01):continue
   xy=cam[:,:2]/cam[:,2,None]* (H/2/np.tan(np.deg2rad(25)))
   xy[:,0]+=W/2; xy[:,1]=H/2-xy[:,1]
   xmin=max(0,int(np.floor(xy[:,0].min()))); xmax=min(W-1,int(np.ceil(xy[:,0].max())))
   ymin=max(0,int(np.floor(xy[:,1].min()))); ymax=min(H-1,int(np.ceil(xy[:,1].max())))
   if xmin>xmax or ymin>ymax:continue
   a,b,c=xy; den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
   if abs(den)<1e-8:continue
   y,x=np.mgrid[ymin:ymax+1,xmin:xmax+1]
   u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
   v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den; w=1-u-v
   z=1/(u/cam[0,2]+v/cam[1,2]+w/cam[2,2])
   mask=(u>=0)&(v>=0)&(w>=0)&(z<depth[ymin:ymax+1,xmin:xmax+1])
   n=np.cross(tri[1]-tri[0],tri[2]-tri[0]); n/=max(np.linalg.norm(n),1e-12)
   shade=.48+.52*abs(n@light)
   color=cs[t:t+3].mean(axis=0)*255*shade
   img[ymin:ymax+1,xmin:xmax+1][mask]=color; depth[ymin:ymax+1,xmin:xmax+1][mask]=z[mask]
 im=Image.fromarray(np.uint8(np.clip(img,0,255))); ImageDraw.Draw(im).text((20,20),'SOFTWARE GEOMETRY PREVIEW - NOT GODOT ACCEPTANCE / '+name,fill='white'); im.save(out/(name+'.png'))
