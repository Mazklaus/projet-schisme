# Textures procédurales de l interface (UI/UX) : plaque de métal sombre tuilable 512 px.
# Lancer depuis la racine du dépôt : python3 tools/ui/generer_textures.py (graine fixe, résultat stable).
import numpy as np
from PIL import Image
rng=np.random.default_rng(31)
def bruit_tuilable(n, octaves):
    acc=np.zeros((n,n))
    for o,amp in octaves:
        k=n//o
        g=rng.standard_normal((o,o))
        # upscale periodic via fft-free bilinear wrap
        x=np.arange(n)/k
        i0=np.floor(x).astype(int)%o; i1=(i0+1)%o; f=x-np.floor(x); f=f*f*(3-2*f)
        rows=g[i0]*(1-f)[:,None]+g[i1]*f[:,None]
        acc+=amp*(rows[:,i0]*(1-f)[None,:]+rows[:,i1]*f[None,:])
    return acc
n=512
# Plaque métal sombre : bruit + brossage horizontal + piqûres
b=bruit_tuilable(n,[(4,1),(16,.5),(64,.25),(128,.15)])
bros=np.repeat(rng.standard_normal((n,1)),n,1)*0.25
bros=bros+np.roll(bros,1,0)*.5
pits=(rng.random((n,n))>0.9985)*-2.5
v=b+bros+pits+rng.standard_normal((n,n))*0.12
v=(v-v.mean())/v.std()
base=np.array([0x16,0x13,0x10],float); 
img=np.clip(base[None,None,:]+v[...,None]*np.array([5,4.4,3.6]),0,255).astype(np.uint8)
img=np.dstack([img, np.full(img.shape[:2], 255, np.uint8)])  # RGBA : le RGB8 sort blanc sous Godot Compatibility
Image.fromarray(img).save('assets/ui/ui_plaque_metal.png')
# Parchemin : clair, taches
b=bruit_tuilable(n,[(2,1),(8,.6),(32,.3),(128,.15)])
v=(b-b.mean())/b.std()+rng.standard_normal((n,n))*0.15
base=np.array([0xE6,0xDD,0xC8],float)
img=np.clip(base[None,None,:]+v[...,None]*np.array([9,10,13]),0,255).astype(np.uint8)
Image.fromarray(img).save('/tmp/ui_parchemin.png')
