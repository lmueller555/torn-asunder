"""Original custody case material tiles, deterministic color/roughness/normal."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
P = Path(__file__).resolve().parents[1]/"textures"
rng = np.random.default_rng(8619)
s = 256
y,x = np.mgrid[0:s,0:s].astype(float)/s

def noise(samples):
    a = Image.fromarray(rng.integers(0,255,samples,dtype=np.uint8))
    return np.array(a.resize((s,s),Image.Resampling.BICUBIC),float)/255-.5

n1,n2,n3,n4 = [noise(k) for k in [(7,6),(19,16),(57,70),(256,256)]]
def bands():
    qx,qy=(x-.773)*.60,(y-.392)*2.9
    knot = np.exp(-8.0*(qx*qx + qy*qy))
    eye = np.exp(-39.0*(qx*qx + qy*qy))
    warped = y + .020*n1 + .011*np.sin(x*4 + 2*y) + .009*n2 + .068*knot*(qy+.17*np.sin(8*x))
    # Vessels run generally with the grain, but end unevenly and bend by
    # the seam; the eye darkens a few runs instead of filling the panel.
    stem = noise((85,4))
    pores = np.power(np.maximum(0,-stem-.17)*3.3,1.6)
    waves = np.sin(262*warped + 3.9*n2 + 1.6*np.sin(4*warped+8*x))
    scuff = np.exp(-((x-.142)/.19)**2-((y-.57)/.018)**2)
    return (.22+.09*n2)*waves+.055*np.sin(warped*672+6*n1)+.34*stem-.60*pores-.38*eye+.14*scuff
wood = bands()
# warm travel-dark walnut with rubbed/high handled regions
rub = .12*np.sin(3*x+1.4*y) + .25*n1 + .14*n2
f = wood*.19+rub*.51+n3*.058
close = np.sqrt((x-.69)**2+(y-.15)**2)
edge = np.exp(-close*9)
colors = [
    np.array([101,66,42]) + (68*f)[...,None] + 17*edge[...,None]*np.array([1,.89,.64]),
    np.array([74,47,34]) + (22*n1+24*n2+16*n3+9*n4)[...,None],
    np.array([145,124,86]) + (28*n1+16*n2+9*n3)[...,None] + 26*edge[...,None],
    np.array([114,40,26]) + (31*n1+17*n2+6*n3)[...,None] + 16*edge[...,None]*np.array([1,.66,.38]),
]
rough = [.63-.12*wood-.25*edge,.75 + .15*n2 - .13*edge,.49+.27*n1+.13*n2-.20*edge,.47+.10*n1-.17*edge]
metal = [0,0,.70,0]
heights = [.064*wood+.10*n2+.025*n3, .17*n3+.052*n4+.06*n2,
           .078*n2+.09*n3+.053*n4,.08*n2+.05*n3]
color = np.zeros((s*2,s*2,3),dtype=np.uint8)
rmetal = np.zeros_like(color)
normal = np.zeros_like(color)
for i in range(4):
    j,k=divmod(i,2); tile=np.s_[s*j:s*j+s,s*k:s*k+s]
    color[tile]=np.clip(colors[i],0,255).astype('uint8')
    rmetal[tile]=np.stack([np.full_like(x,255),rough[i]*255,np.full_like(x,metal[i]*255)],2).astype('uint8')
    dy,dx=np.gradient(heights[i])
    norm=np.stack([-dx*4,dy*4,np.ones_like(x)],2)
    norm/=np.linalg.norm(norm,axis=2,keepdims=True)
    normal[tile]=np.clip(norm*.5*255+.5*255,0,255).astype('uint8')
for key,a in [('Color',color),('RoughMetal',rmetal),('Normal',normal)]:
    Image.fromarray(a).save(P/f'CustodyCase_{key}.png',optimize=True)
