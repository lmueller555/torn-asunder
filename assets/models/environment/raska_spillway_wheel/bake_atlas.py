from pathlib import Path
import numpy as np
from PIL import Image

s=192
Y,X=np.mgrid[0:s,0:s]/(s-1)
rng=np.random.default_rng(51786)

def field(h,w):
    raw=rng.integers(0,255,(h,w),dtype=np.uint8)
    return np.asarray(Image.fromarray(raw).resize((s,s),Image.Resampling.BICUBIC)).astype(float)/255-.5

def put(col, value, tint=(1,1,1)):
    return np.clip(np.array(col)+value[...,None]*np.array(tint),0,255).astype('uint8')

b,m,f,grain=field(6,9),field(18,23),field(96,128),field(100,6)
seam=Y+.025*np.sin(X*8.6)+.043*b+.012*m
splinter=np.exp(-((seam-.37)/.017)**2)*np.sqrt(np.clip((X-.44)*1.7,0,1))
wood=20*b+16*m+14*f+18*grain+7*np.sin(seam*229+4*b)-26*splinter
bronze=29*b+9*m+13*f + 9*np.cos(X*13+2*m)*np.clip(Y-.15,0,1)
# Compact chipped-dress grain, not periodic or directionally stretched.
# Same original b/m/f data; independent stone variation only.
stone_cell=field(21,22)
stone_grit=field(121,129)
grain_cut=field(32,38)
mica=np.maximum(0.0,stone_grit-.23)
pore=np.maximum(0.0,-stone_grit-.19)
facets=np.maximum(0.0,.18-np.abs(grain_cut+.28*m))
stone=34*b+27*m+18*stone_cell+15*stone_grit + 36*mica - 41*pore + 17*facets
dark=22*b+20*m+13*f + 4*np.sin(X*170+5*m)
wet=np.exp(-((X-.73-.025*m)/.08)**2)*np.clip((Y-.40),0,1)
tiles=[
    put((132,94,62),wood,(1,.84,.68)), # long grain oak
    put((123,120,109),stone,(1,.92,.82)), # weathered dressed masonry
    put((62,67,61),dark,(1,1,.88)), # wrought iron
    put((138,105,64),bronze,(1,.80,.44)), # rubbed bearing bronze
    put((81,81,72),stone*.56+15*b-wet*17,(1,.93,.8)), # wet basal stone
    put((162,138,95),bronze+13*f,(1,.85,.54)) # worn edges only
]
atlas=Image.new('RGB',(s*3,s*2))
for i,tile in enumerate(tiles):
    atlas.paste(Image.fromarray(tile),((i%3)*s,(i//3)*s))
atlas.save(Path(__file__).with_name("spanwater_wheel_atlas.png"),optimize=True)
