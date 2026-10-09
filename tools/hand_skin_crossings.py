"""Strict non-adjacent triangle crossing diagnostic for the authored hand."""
import json
from pathlib import Path
import numpy as np

def crossings(data):
    v=np.asarray(data["vertices"]); f=np.asarray(data["faces"]); t=v[f]
    hits=set()
    for i,tri in enumerate(t):
        valid=np.all(f[:,None,:]!=f[i][None,:,None],axis=(1,2))
        ids=np.where(valid & (np.max(t,axis=1)>=np.min(tri,axis=0)-1e-9).all(axis=1) & (np.min(t,axis=1)<=np.max(tri,axis=0)+1e-9).all(axis=1))[0]
        ids=ids[ids>i]
        if not len(ids):continue
        # Test both directions: an edge from either triangle can pierce the other.
        for edge in range(3):
            for reverse in (False,True):
                if reverse:
                    a,b=t[ids,edge],t[ids,(edge+1)%3];other=np.broadcast_to(tri,(len(ids),3,3))
                else:
                    a,b=tri[edge],tri[(edge+1)%3];other=t[ids]
                direction=b-a;e1=other[:,1]-other[:,0];e2=other[:,2]-other[:,0]
                h=np.cross(direction,e2);det=np.einsum("ij,ij->i",e1,h)
                ok=np.abs(det)>1e-12;inv=np.zeros_like(det);inv[ok]=1/det[ok]
                s=a-other[:,0];u=inv*np.einsum("ij,ij->i",s,h);q=np.cross(s,e1)
                w=inv*np.sum(direction*q,axis=1);along=inv*np.einsum("ij,ij->i",e2,q)
                yes=ok&(u>1e-6)&(w>1e-6)&(u+w<1-1e-6)&(along>1e-6)&(along<1-1e-6)
                for j in ids[yes]:hits.add((int(i),int(j)))
    return sorted(hits)

if __name__=="__main__":
    d=json.loads(Path("assets/models/operator/hand_authored_v1.json").read_text())
    hits=crossings(d);v=np.asarray(d["vertices"]);f=np.asarray(d["faces"])
    print("Strict non-adjacent crossings:",len(hits))
    from collections import Counter
    print(Counter(tuple(d["parts"][d["groups"][x]] for x in pair) for pair in hits))
    for a,b in hits[:18]:print(a,b,np.round(v[f[a]].mean(0),4),np.round(v[f[b]].mean(0),4))
    Path(".dream-loop/hand_authored_crossings.json").write_text(json.dumps(hits))

    raise SystemExit(1 if hits else 0)
