"""Foam Shop — "Foam Layers" mark, FLAT edition (v1.5.6). One geometry, every output.
Solid colours only: no gradients, no transparency, no blur, no glow."""
from shapely.geometry import box, Point
from shapely.ops import unary_union

# ---- palette (existing AppColors values; nothing new) ----
NAVY="#182346"; INK="#0E0D15"; SLATE="#3D5387"; PERI="#7C83AD"; MAUVE="#BFA9BA"; FOAM="#F7F4F2"

# ---- geometry, 1024 x 1024 design space ----
W,H,R   = 600,224,80                    # slab size and corner radius
XS      = [178,212,246]                 # bottom, middle, top  (stack leans right going up)
YS      = [528,404,280]
GAP     = 24                            # cut-out between layers
PORES   = [(470,120,26),(520,82,15),(428,88,10)]   # (dx,dy,r) on the TOP slab
TILE_RX = 232                           # app-icon corner radius (22.66 %)
ACCENT  = (968,996,262)                 # flat slate disc in the bottom-right corner (cx,cy,r), clear of the stack
RES     = 16                            # arc segments per quarter turn

def rr(x,y,w=W,h=H,r=R): return box(x+r,y+r,x+w-r,y+h-r).buffer(r,resolution=RES)
def slabs():
    bot,mid,top=[rr(x,y) for x,y in zip(XS,YS)]
    return dict(
        bottom=bot.difference(mid.buffer(GAP,resolution=RES)).difference(top.buffer(GAP,resolution=RES)),
        middle=mid.difference(top.buffer(GAP,resolution=RES)),
        top=top)
def pores():
    tx,ty=XS[2],YS[2]
    return [Point(tx+dx,ty+dy).buffer(r,resolution=RES) for dx,dy,r in PORES]
def mono(with_pores=True):
    s=slabs(); g=unary_union([s['bottom'],s['middle'],s['top']])
    if with_pores: g=g.difference(unary_union(pores()))
    return g

def d_of(geom,nd=1):
    polys=[geom] if geom.geom_type=="Polygon" else list(geom.geoms)
    out=[]
    for p in polys:
        for ring in [p.exterior]+list(p.interiors):
            pts=list(ring.coords)[:-1]
            out.append("M"+" L".join(f"{x:.{nd}f},{y:.{nd}f}" for x,y in pts)+" Z")
    return " ".join(out)

# colour ramps for the three layers (top, middle, bottom)
ON_DARK =(FOAM,MAUVE,PERI)      # on Deep Navy
ON_LIGHT=(NAVY,SLATE,PERI)      # on Foam White
def mark_body(ramp=ON_DARK,pore_col=MAUVE,scale=1.0,cx=512,cy=512):
    s=slabs(); t,m,b=ramp
    inner=(f'<path d="{d_of(s["bottom"])}" fill="{b}"/>'
           f'<path d="{d_of(s["middle"])}" fill="{m}"/>'
           f'<path d="{d_of(s["top"])}" fill="{t}"/>'
           +"".join(f'<path d="{d_of(p)}" fill="{pore_col}"/>' for p in pores()))
    if scale==1.0: return inner
    return f'<g transform="translate({cx} {cy}) scale({scale}) translate(-{cx} -{cy})">{inner}</g>'
def mono_body(fill,scale=1.0,with_pores=True,cx=512,cy=512):
    inner=f'<path d="{d_of(mono(with_pores))}" fill="{fill}" fill-rule="evenodd"/>'
    if scale==1.0: return inner
    return f'<g transform="translate({cx} {cy}) scale({scale}) translate(-{cx} -{cy})">{inner}</g>'
def bg_body(): return (f'<rect width="1024" height="1024" fill="{NAVY}"/>'
                       f'<circle cx="{ACCENT[0]}" cy="{ACCENT[1]}" r="{ACCENT[2]}" fill="{SLATE}"/>')

def icon_svg(rounded=True):
    rx=TILE_RX if rounded else 0
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" role="img">'
            f'<title>Foam Shop — app icon</title><defs><clipPath id="c"><rect width="1024" height="1024" rx="{rx}"/></clipPath></defs>'
            f'<g clip-path="url(#c)">{bg_body()}{mark_body()}</g></svg>')
def mark_svg(ramp=ON_DARK,pore_col=MAUVE,title="Foam Shop — mark"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="150 250 724 530" width="724" height="530" role="img">'
            f'<title>{title}</title>{mark_body(ramp,pore_col)}</svg>')
def mono_svg(fill="#FFFFFF",title="Foam Shop — monochrome mark"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="150 250 724 530" width="724" height="530" role="img">'
            f'<title>{title}</title>{mono_body(fill)}</svg>')
