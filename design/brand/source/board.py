import cairosvg, geo, text
from geo import NAVY,INK,SLATE,PERI,MAUVE,FOAM
OUT='out'
def T(s,font,size,x,y,fill,tr=0):
    p,wd=text.text_path(s,font,size,x,y,tr,fill); return p,wd
def tile(x,y,size,rounded=True,rx=None):
    k=size/1024; r=geo.TILE_RX if rx is None else rx
    return (f'<g transform="translate({x} {y}) scale({k})"><defs><clipPath id="t{int(x)}{int(y)}"><rect width="1024" height="1024" rx="{r}"/></clipPath></defs>'
            f'<g clip-path="url(#t{int(x)}{int(y)})">{geo.bg_body()}{geo.mark_body()}</g></g>')
def mark_at(x,y,h,ramp,pc):
    k=h/530; return f'<g transform="translate({x} {y}) scale({k}) translate(-150 -250)">{geo.mark_body(ramp,pc)}</g>'
def mono_at(x,y,h,fill):
    k=h/530; return f'<g transform="translate({x} {y}) scale({k}) translate(-150 -250)">{geo.mono_body(fill)}</g>'
def wm(x,y,dark,size=150):
    a_col,b_col=(FOAM,MAUVE) if dark else (NAVY,SLATE)
    a,wa=text.text_path('Foam','Manrope-ExtraBold.ttf',size,x,y,-0.01,a_col); b,wb=text.text_path('Shop','Manrope-Medium.ttf',size,x+wa+size*0.23,y,-0.01,b_col)
    return a+b,wa+size*0.23+wb

W,H=1920,1320
P=[f'<rect width="{W}" height="{H}" fill="{FOAM}"/>']
# ---- hero (dark panel)
P.append(f'<rect x="0" y="0" width="1240" height="620" fill="{INK}"/>')
P.append(f'<rect x="1240" y="0" width="680" height="620" fill="{FOAM}"/>')
P.append(tile(110,110,380))
a,wd=wm(556,296,True,112); P.append(a)
d,_=T('DIGITAL  REGISTER','Manrope-SemiBold.ttf',28,562,350,PERI,0.30); P.append(d)
t,_=T('Every sale. Every stock. Every khata.','Manrope-Medium.ttf',32,562,420,FOAM); P.append(t)
l,_=T('FOAM SHOP  ·  BRAND BOARD  ·  v1.5.6  ·  FLAT, SOLID COLOUR — NO GLASS','Inter-SemiBold.ttf',16,110,570,PERI,0.18); P.append(l)
# ---- clear space (right panel)
t,_=T('CLEAR SPACE','Manrope-ExtraBold.ttf',20,1300,120,SLATE,0.2); P.append(t)
mh=170; mx,my=1420,230; k=mh/530; cs=224*k*1.0   # clear space = height of the top layer
mw=724*k
P.append(f'<rect x="{mx-cs}" y="{my-cs}" width="{mw+2*cs}" height="{mh+2*cs}" fill="none" stroke="{SLATE}" stroke-width="2" stroke-dasharray="10 8"/>')
P.append(mark_at(mx,my,mh,geo.ON_LIGHT,PERI))
t,_=T('X = height of the top layer','Inter-Medium.ttf',18,1300,my+mh+cs+44,NAVY); P.append(t)
t,_=T('Keep X free on every side.','Inter-Medium.ttf',18,1300,my+mh+cs+72,SLATE); P.append(t)
t,_=T('Minimum size: icon 32 px · mark 24 px tall · wordmark 96 px wide.','Inter-Medium.ttf',18,1300,my+mh+cs+108,SLATE); P.append(t)
# ---- mark variants
y0=690; t,_=T('MARK VARIANTS','Manrope-ExtraBold.ttf',20,110,y0,SLATE,0.2); P.append(t)
cards=[('On dark',INK,lambda x,y:mark_at(x,y,150,geo.ON_DARK,MAUVE)),('On light',FOAM,lambda x,y:mark_at(x,y,150,geo.ON_LIGHT,PERI)),
       ('Mono white',NAVY,lambda x,y:mono_at(x,y,150,'#FFFFFF')),('Mono ink',MAUVE,lambda x,y:mono_at(x,y,150,NAVY))]
for i,(n,bg,fn) in enumerate(cards):
    x=110+i*290; P.append(f'<rect x="{x}" y="{y0+24}" width="270" height="220" rx="28" fill="{bg}"/>')
    if bg==FOAM: P.append(f'<rect x="{x}" y="{y0+24}" width="270" height="220" rx="28" fill="none" stroke="{MAUVE}" stroke-width="2"/>')
    P.append(fn(x+ (270-150*724/530)/2, y0+24+35))
    l,_=T(n,'Inter-SemiBold.ttf',17,x,y0+272,NAVY); P.append(l)
# ---- icon masks & sizes (right)
t,_=T('APP ICON','Manrope-ExtraBold.ttf',20,1280,y0,SLATE,0.2); P.append(t)
P.append(tile(1280,y0+24,160)); P.append(tile(1460,y0+24,160,rx=512))
sx=1650
for s in (80,56,40,32):
    P.append(tile(sx,y0+24+(160-s),s)); sx+=s+14
for n,x in (('Squircle',1280),('Round',1460)):
    l,_=T(n,'Inter-SemiBold.ttf',17,x,y0+232,NAVY); P.append(l)
l,_=T('80 · 56 · 40 · 32 px','Inter-SemiBold.ttf',17,1650,y0+232,NAVY); P.append(l)
# ---- colour
y1=1000; t,_=T('COLOUR — EXISTING APP PALETTE, NOTHING NEW','Manrope-ExtraBold.ttf',20,110,y1,SLATE,0.2); P.append(t)
pal=[('Deep Ink',INK,'Splash (dark), text'),('Deep Navy',NAVY,'Icon field, primary'),('Slate Blue',SLATE,'Accent disc, secondary'),
     ('Periwinkle',PERI,'Bottom layer'),('Dusty Mauve',MAUVE,'Middle layer, pores'),('Foam White',FOAM,'Top layer, light page')]
for i,(n,hx,role) in enumerate(pal):
    x=110+i*290
    P.append(f'<rect x="{x}" y="{y1+24}" width="270" height="110" rx="24" fill="{hx}"/>')
    if hx==FOAM: P.append(f'<rect x="{x}" y="{y1+24}" width="270" height="110" rx="24" fill="none" stroke="{MAUVE}" stroke-width="2"/>')
    l,_=T(n,'Inter-Bold.ttf',19,x,y1+168,NAVY); h,_=T(hx,'Inter-Medium.ttf',17,x,y1+194,SLATE); r_,_=T(role,'Inter-Medium.ttf',15,x,y1+218,SLATE); P+= [l,h,r_]
f,_=T('Solid fills only on the logo and icon. No gradients, transparency, blur or glow. The app UI is unchanged from v1.5.5.','Inter-Medium.ttf',16,110,1290,PERI); P.append(f)
svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{"".join(P)}</svg>'
open(f'{OUT}/brand/brand-board.svg','w').write(svg); cairosvg.svg2png(bytestring=svg.encode(),write_to=f'{OUT}/brand/brand-board.png',output_width=W,output_height=H)

# ================= Play Store feature graphic 1024x500 (flat, no invented figures)
W,H=1024,500
P=[f'<rect width="{W}" height="{H}" fill="{NAVY}"/>',f'<circle cx="1030" cy="580" r="240" fill="{SLATE}"/>',f'<circle cx="1000" cy="40" r="120" fill="{INK}"/>']
P.append(mark_at(64,150,200,geo.ON_DARK,MAUVE))
a,wd=wm(372,262,True,100); P.append(a)
d,_=T('DIGITAL  REGISTER','Manrope-SemiBold.ttf',22,376,306,PERI,0.30); P.append(d)
t,_=T('Every sale. Every stock. Every khata.','Manrope-Medium.ttf',26,376,364,FOAM); P.append(t)
svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{"".join(P)}</svg>'
open(f'{OUT}/store/feature-graphic-1024x500.svg','w').write(svg); cairosvg.svg2png(bytestring=svg.encode(),write_to=f'{OUT}/store/feature-graphic-1024x500.png',output_width=W,output_height=H)
print('board ok')
