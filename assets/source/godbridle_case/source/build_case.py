"""Editable closed custody case model and game export. Run with Blender 4.3+."""
from pathlib import Path
from math import cos, sin, tau, pi, atan2
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
P = Vector
PARTS = []
TILES = {"wood": (0, 0), "leather": (1, 0), "bronze": (0, 1), "wax": (1, 1), "burnished": (0, 1), "thread": (1, 0)}


def packed_texture(name, space):
    im = bpy.data.images.load(str(ROOT/"textures"/(name + ".png")), check_existing=True)
    im.colorspace_settings.name = space
    im.pack()
    return im


def material():
    mat = bpy.data.materials.new("Custody case | worn grain, worked leather, dull bronze and royal sealing wax")
    mat.use_nodes = True
    mat.diffuse_color = (.25, .105, .045, 1)
    graph = mat.node_tree
    shader = graph.nodes.get("Principled BSDF")
    shader.location = (410, 110)
    graph.nodes.get("Material Output").location = (760, 110)
    inputs = [
        ("CustodyCase_Color", "sRGB", (-580, 250)),
        ("CustodyCase_RoughMetal", "Non-Color", (-580, -25)),
        ("CustodyCase_Normal", "Non-Color", (-580, -320)),
    ]
    nodes = []
    for name, space, pos in inputs:
        node = graph.nodes.new("ShaderNodeTexImage")
        node.location, node.label, node.image = pos, name, packed_texture(name, space)
        nodes.append(node)
    graph.links.new(nodes[0].outputs["Color"], shader.inputs["Base Color"])
    split = graph.nodes.new("ShaderNodeSeparateColor")
    split.location = (-140, 0)
    graph.links.new(nodes[1].outputs["Color"], split.inputs["Color"])
    graph.links.new(split.outputs["Green"], shader.inputs["Roughness"])
    graph.links.new(split.outputs["Blue"], shader.inputs["Metallic"])
    bump = graph.nodes.new("ShaderNodeNormalMap")
    bump.location = (-130, -260)
    bump.inputs["Strength"].default_value = .84
    graph.links.new(nodes[2].outputs["Color"], bump.inputs["Color"])
    graph.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return mat


def bv(v):
    return (v.x, -v.z, v.y)


def packed_uv(tile, u, v):
    x, y = TILES[tile]
    return ((x + .021 + u * .958) / 2.0, 1.0 - (y + .021 + v * .958) / 2.0)


def make(name, vertices, faces, uv_faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([bv(v) for v in vertices], [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="Custody case material atlas")
    for poly, uv_set in zip(mesh.polygons, uv_faces):
        poly.use_smooth = True
        for li, coords in zip(poly.loop_indices, uv_set):
            uv.data[li].uv = coords
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MATERIAL)
    PARTS.append(obj)
    return obj


def curving(points, steps, closed=False):
    points = list(map(P, points))
    m = len(points)
    output = []
    get = (lambda n: points[n % m]) if closed else (lambda n: points[max(0,min(n,m-1))])
    for i in range(m if closed else m-1):
        a,b,c,d = [get(x) for x in (i-1,i,i+1,i+2)]
        for j in range(steps):
            f=j/steps
            output.append(.5*((2*b) + (c-a)*f + (2*a-5*b+4*c-d)*f*f+(-a+3*b-3*c+d)*f*f*f))
    if not closed:
        output.append(points[-1])
    return output


def loft(name, path, levels, tile, closed=False, accents=(), bank=(0,0,1)):
    verts, faces, uv = [], [], []
    S=len(levels[0])
    n=len(path)
    reference=P(bank)
    for i,point in enumerate(path):
        previous=(i-1)%n if closed else max(i-1,0)
        following=(i+1)%n if closed else min(i+1,n-1)
        forward=(path[following]-path[previous]).normalized()
        u=forward.cross(reference)
        if u.length < .01:
            u=forward.cross(P((0,1,0)))
        u.normalize()
        v=u.cross(forward).normalized()
        for a,b in levels[i]:
            verts.append(point + u*a + v*b)
    M=n if closed else n-1
    for i in range(M):
        end=(i+1)%n
        for j in range(S):
            nxt=(j+1)%S
            faces.append((i*S+j,end*S+j,end*S+nxt,i*S+nxt))
            mat_tile = "burnished" if j in accents else tile
            uv.append(tuple(packed_uv(mat_tile,u,v) for u,v in
                ((j/S,i/M),(j/S,(i+1)/M),((j+1)/S,(i+1)/M),((j+1)/S,i/M))))
    if not closed:
        for ring, order in [(0, list(reversed(range(S)))),(n-1,list(range(S)))]:
            faces.append(tuple(ring*S+j for j in order))
            uv.append(tuple(packed_uv(tile,.45+.19*cos(tau*j/S),.45+.19*sin(tau*j/S)) for j in order))
    return make(name, verts, faces, uv)


def sectional(width, depth, radius):
    w, d = width*.5, depth*.5
    return [(-w+radius,-d),(w-radius,-d),(w,-d+radius),(w,d-radius),
            (w-radius,d),(-w+radius,d),(-w,d-radius),(-w,-d+radius)]


def strap(name, coords, width, thickness, *, closed=False, steps=2):
    path=curving(coords,steps,closed)
    L=len(path)
    levels=[sectional(width*(.96+.055*sin(tau*i/L+.3)),thickness,.00155) for i in range(L)]
    loft(name,path,levels,"leather",closed)
    return path


def tube(name, path, radius, tile="bronze", *, closed=False, sides=8, accents=(), bank=(0,0,1)):
    levels=[]
    for i in range(len(path)):
        r=radius[i] if isinstance(radius,list) else radius
        levels.append([(r*cos(tau*j/sides),r*sin(tau*j/sides)) for j in range(sides)])
    return loft(name,path,levels,tile,closed,accents,bank)


def ring(name, center, W, H, depth, phase, detail=20):
    c=P(center)
    path=[]
    for i in range(detail):
        a=tau*i/detail
        path.append(c+P((W*cos(a)*(1+.028*sin(3*a+phase)),H*sin(a),
                         .0018*sin(2*a+phase))))
    rad=[depth*(1+.083*sin(tau*i/detail*3+phase)) for i in range(detail)]
    return tube(name,path,rad,closed=True,sides=8,accents=(2,3))


def stitch_run(name,path,width,thickness,spacing=.010):
    previous=None
    length=0.
    for j,center in enumerate(path[1:-1],1):
        if previous is not None:
            length+=(center-previous).length
        previous=center
        if length < spacing:
            continue
        length=0
        tangent=(path[j+1]-path[j-1]).normalized()
        outward=tangent.cross(P((0,0,1))).normalized()
        for side in (-1,1):
            at=center+outward*width*.345*side + P((0,0,thickness*.5+.00053))
            lea=at-tangent*.0021-outward*.0014
            end=at+tangent*.0021+outward*.00135
            width_vector=outward*.00068
            ridge=at+P((0,0,.00074))
            points=[lea-width_vector,lea+width_vector,end+width_vector,end-width_vector,ridge]
            faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]
            patch=[packed_uv("thread", .12,.35),packed_uv("thread",.12,.66),
                   packed_uv("thread",.78,.66),packed_uv("thread",.78,.35),packed_uv("thread",.45,.5)]
            make(name,points,faces,[[patch[i] for i in f] for f in faces])


def beveled(name, pos, size, radius, tile, style=0):
    w,h,d=[k/2 for k in size]
    shapefaces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]
    corners=[(-w,-h,-d),(w,-h,-d),(w,h,-d),(-w,h,-d),(-w,-h,d),(w,-h,d),(w,h,d),(-w,h,d)]
    if style:
        corners=[(x* (1-.031*style if y > 0 else 1),y + z*.018,z* (1-.031*style if y>0 else 1)) for x,y,z in corners]
    obj=make(name,[P(v)+P(pos) for v in corners],shapefaces,[[packed_uv(tile,0,0)]*4]*6)
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new("Crafted softened joins",'BEVEL')
    mod.width=radius
    mod.segments=2 if radius > .009 else 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.update()
    mesh=obj.data
    mesh.update()
    uv=mesh.uv_layers[0]
    for poly in mesh.polygons:
        poly.use_smooth=True
        for idx in poly.loop_indices:
            raw=mesh.vertices[mesh.loops[idx].vertex_index].co
            x,y,z=raw.x-pos[0],raw.z-pos[1],-raw.y-pos[2]
            p=P((abs(poly.normal.x),abs(poly.normal.z),abs(poly.normal.y)))
            if p.x>max(p.y,p.z):
                u,v = .5+.94*z/(2*d),.5+.94*y/(2*h)
            elif p.y>p.z:
                u,v = .5+.94*x/(2*w),.5+.94*z/(2*d)
            else:
                u,v=.5+.94*x/(2*w),.5+.94*y/(2*h)
            uv.data[idx].uv=packed_uv(tile,u%1.,(v*.65+.14+pos[1]*.37)%1.)
    # Flat broad panels with rounded highlights just along joinery.
    normal=obj.modifiers.new(" weighted joinery normals",'WEIGHTED_NORMAL')
    normal.weight=60
    normal.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def stud(name,at,r,axis=(0,0,1),depth=.005,tile="bronze"):
    c=P(at); a=P(axis)
    path=[c-a*depth*.61, c+a*depth*.14, c+a*depth*.42]
    ref=(0,1,0) if abs(a.y)<.8 else (0,0,1)
    return tube(name,path,[r*.83,r,r*.57],tile,sides=7,bank=ref)


def loop(name,at,ux,uy,Rx,Ry,r,sides=16):
    return tube(name,[P(at)+P(ux)*Rx*cos(i*tau/sides)+P(uy)*Ry*sin(i*tau/sides) for i in range(sides)],
        r,"bronze",closed=True,sides=6)


def build():
    # Compact enough for the physically coiled, non-magical-looking harness.
    # Center body at origin, lid up; front faces +Z (camera in neutral fixture).
    beveled("Walnut core | foot rail", (0,-.101,0),(.534,.034,.251),.018,"wood")
    beveled("Walnut core | box", (0,-.010,0),(.550,.188,.267),.018,"wood",1)
    beveled("Rebated inner leather seal around closed lid",(0,.082,0),(.551,.017,.270),.010,"leather")
    beveled("Walnut lid | shaped brow",(0,.106,0),(.565,.053,.282),.018,"wood",1)
    beveled("Walnut lid | shallow crown",(0,.131,0),(.535,.032,.252),.021,"wood",1)

    # Leather end harnesses follow the lid down the front and rear.
    for x in [-.191,.191]:
        path=[(x,-.116,.095),(x,-.108,.120),(x,-.077,.136),(x,.074,.140),
              (x,.096,.145),(x,.117,.143),(x,.132,.137),(x,.145,.129),
              (x,.150,.114),(x,.151,.090),(x,.151,-.083),(x,.149,-.108),
              (x,.143,-.127),(x,.129,-.138),(x,.104,-.141),(x,.068,-.140),
              (x,-.077,-.136),(x,-.107,-.123),(x,-.115,-.093),(x,-.116,.087)]
        # Tangent to local X, never twists across a top corner.
        sc=curving(path,2,True)
        loft("Leather end binding",sc,[[(b,a) for a,b in sectional(.039,.0068,.0015)] for _ in sc],"leather",True,bank=(1,0,0))
        # A top and front trim panel gives leather a chamfer on the light edge.
        for sign in [-1,1]:
            for dy in [-.067,.069]:
                stud("Front / rear leather retaining rivet",(x,dy,sign*.144),.0052,axis=(0,0,sign))
        for z in [-.07,.07]:
            stud("Lid rail mushroom rivet",(x,.158,z),.0054,axis=(0,1,0))

    # Metal corners are three planes wrapping onto the next plank. They are
    # actual parts, not painted Xs, and keep square stop edges at the lid split.
    for sx in (-1,1):
        for sz in (-1,1):
            for sy in (-1,1):
                yy=.104 if sy>0 else -.085
                beveled("Rounded corner strap | end face",(sx*.271,yy,sz*.108),(.014,.034,.063),.0046,"bronze")
                beveled("Rounded corner strap | long face",(sx*.248,yy,sz*.133),(.067,.032,.014),.0046,"bronze")
                stud("Corner flat-head peen",(sx*.228,yy,sz*.142),.0054,axis=(0,0,sz))
    for x in [-.10,.097]:
        beveled("Rear plate hinge | bottom leaf",(x,.041,-.140),(.038,.049,.011),.0038,"bronze")
        beveled("Rear plate hinge | top leaf",(x,.112,-.142),(.038,.029,.012),.0038,"bronze")
        tube("Hinge pin forged barrel",[P((x-.022,.080,-.150)),P((x+.022,.080,-.150))],.0089,"bronze")
    # Front hasp and catch; handle works in the vertical plane on the lid.
    for at,size in [((0,.119,.144),(.058,.036,.012)),((0,.046,.143),(.061,.036,.012)),((0,.082,.154),(.032,.077,.013))]:
        beveled("Closed catch | flat forged plate",at,size,.0045,"bronze")
    loop("Hasp staple", (0,.055,.166),(1,0,0),(0,1,0),.015,.013,.0036)
    for x in [-.081,.081]:
        beveled("Handle bracket | screwed base",(x,.157,0),(.037,.013,.042),.005,"bronze")
        loop("Handle bracket | free D link",(x,.168,0),(0,1,0),(0,0,1),.016,.017,.0046)
    h=curving([(-.096,.169,0),(-.086,.188,0),(-.066,.224,-.006),
        (-.024,.235,-.009),(.025,.234,-.006),(.065,.222,0),(.086,.187,.002),(.098,.169,0)],3)
    loft("Upright folded leather hand strap",h,[[(b,a) for a,b in sectional(.031,.012,.0024)] for _ in h],"leather",bank=(0,0,1))
    stitch_run("Double saddle stitch along the handle",h,.009,.0305,.0140)
    # Red-brown twisted cord stands exactly across the front/rear lid split.
    for j in [-1,1]:
        start=j*.161
        p=curving([(start,.141,-.097),(start*.93,.159,-.041),(start*.85,.162,.052),
            (start*.78,.149,.119),(start*.69,.126,.145),(start*.44,.100,.153),
            (start*.24,.066,.162),(j*.010,.047,.176)],3)
        tube("Wax cord | closed across lid and front lip",p,.0044,"leather",sides=6)
        q=curving([(j*.007,.043,.179),(j*.014,.022,.172),(j*.030,.011,.168),(j*.044,.003,.166)],2)
        tube("Wax cord | short pinched tail",q,.0034,"leather",sides=6)
    # Irregular compressed disk. Bridle-shaped impression is not heraldry;
    # it is a small mark on the wax so the sealed object's purpose can read.
    c=P((0,.060,.171)); N=23
    vertices=[]
    for rr,zz in [(.031,0),(.028,.009),(.023,.0098)]:
        for i in range(N):
            a=i*tau/N
            r=rr*(1+.06*sin(5*a+.23)+.046*sin(11*a))
            vertices.append(c+P((r*cos(a),r*.90*sin(a),zz)))
    vertices.append(c+P((0,0,.00995)))
    idx=[]; uv=[]
    def sealface(face):
        idx.append(face)
        uv.append([packed_uv("wax",.50+(vertices[i].x-c.x)*9,.57+(vertices[i].y-c.y)*9) for i in face])
    for l in [0,1]:
        for i in range(N):
            j=(i+1)%N
            sealface((l*N+i,l*N+j,(l+1)*N+j,(l+1)*N+i))
    for i in range(N):
        sealface((2*N+i,2*N+(i+1)%N,3*N))
    make("Mara's pressed wax custody seal",vertices,idx,uv)
    stamp=curving([(-.012,-.006,0),(-.010,.006,0),(-.005,.013,0),(.004,.013,0),(.010,.007,0),(.012,-.006,0)],2)
    tube("Wax impression | bridle-outline blind tooling",[P((a.x,.062+a.y,.1812)) for a in stamp],.0010,"wax",sides=5)
    tube("Wax impression | bridle bit", [P((-.016,.054,.1811)),P((.016,.054,.1811))],.0011,"wax",sides=5)


def far_shape():
    beveled("Distant walnut core",(0,-.016,0),(.55,.206,.267),.009,"wood")
    beveled("Distant lid",(0,.107,0),(.565,.064,.282),.009,"wood")
    beveled("Distant top crown",(0,.135,0),(.535,.026,.252),.006,"wood")
    beveled("Distant sealing wax",(0,.060,.173),(.056,.050,.009),.004,"wax")
    lp=curving([(-.093,.159,0),(-.063,.219,0),(0,.235,0),(.063,.219,0),(.093,.159,0)],2)
    loft("Distant hand strap",lp,[[(b,a) for a,b in sectional(.030,.009,.001)] for _ in lp],"leather")
    for x in (-.19,.19):
        beveled("Distant leather bridge",(x,.153,0),(.039,.008,.245),.002,"leather")


def carry_clip():
    # Built in the rest case's coordinates. In the tested mount, the short
    # open-width end goes against the carrier and the closed tail threads
    # through the handle. This separate rigid rig goes hidden on the ground.
    yaw=pi*62/180
    def to_case(x,y,z):
        X, Z=x-.630,z-.095
        return (X*cos(yaw)-Z*sin(yaw),y-.790,X*sin(yaw)+Z*cos(yaw))
    patch=beveled("Carrier keeper | folded side contact",(.364,1.044,.101),(.018,.091,.084),.005,"leather")
    for v in patch.data.vertices:
        x,y,z=v.co.x,v.co.z,-v.co.y
        v.co=bv(P(to_case(x,y,z)))
    patch.data.update()
    upper=curving([to_case(*k) for k in [
        (.370,1.033,.101),(.380,1.042,.100),(.445,1.044,.097),
        (.513,1.035,.094),(.585,1.013,.093),(.613,1.012,.093),
        (.643,1.021,.094),(.649,1.035,.094),(.624,1.050,.094),
        (.561,1.046,.094),(.483,1.068,.096),(.397,1.067,.101),
        (.371,1.056,.101)]],2,True)
    loft("Carrier loop | doubled leather through handle",upper,
         [[(b,a) for a,b in sectional(.030,.0068,.0018)] for _ in upper],"leather",True,bank=(.883,0,-.469))
    # Soft surfaces and loop maintain one texture atlas in Godot.
    at=to_case(.423,1.066,.096)
    stud("Carrier loop stitched strap head",at,.0061,axis=(0,1,0))
    for z in [.077,.125]:
        stud("Carrier keeper stable rivet",to_case(.375,1.061,z),.0045,
            axis=(cos(yaw),0,sin(yaw)),depth=.0038)

def consolidate(objects,label):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.view_layer.objects.active
    obj.name=label
    tri=obj.modifiers.new("Export fixed triangle selection",'TRIANGULATE')
    tri.keep_custom_normals=True
    bpy.ops.object.modifier_apply(modifier=tri.name)
    obj.data.calc_loop_triangles()
    print(label, f"TRIANGLES={len(obj.data.loop_triangles)} MATERIALS={len(obj.data.materials)} POSITION_COUNT={len(obj.data.vertices)}")
    return obj


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    MATERIAL=material()
    build()
    detailed=PARTS.copy()
    far_shape()
    far=PARTS[len(detailed):]
    carry_clip()
    clip=PARTS[len(detailed)+len(far):]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PARTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"source"/"godbridle_custody_case.blend"))
    meshes=[consolidate(each,label) for each,label in [
        (detailed,"Custody_Near"),(far,"Custody_Far"),(clip,"Custody_Carry_Loop")]]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"godbridle_custody_case.glb"),export_format="GLB",
        export_apply=True,export_tangents=True,use_selection=True)
