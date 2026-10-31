import os, json, shutil, cairosvg
from PIL import Image
import geo, text
from geo import NAVY,INK,SLATE,PERI,MAUVE,FOAM

OUT='out'; shutil.rmtree(OUT,ignore_errors=True)
for d in ['icon','brand','store','web','ios/AppIcon.appiconset','preview',
          'android-res/drawable','android-res/drawable-v21','android-res/values','android-res/values-night',
          'android-res/values-v31','android-res/values-night-v31','android-res/mipmap-anydpi-v26']:
    os.makedirs(f'{OUT}/{d}',exist_ok=True)
def w(p,s,mode='w'): open(f'{OUT}/{p}',mode).write(s)
def png(svg,p,size,bg=None):
    cairosvg.svg2png(bytestring=svg.encode(),write_to=f'{OUT}/{p}',output_width=size[0],output_height=size[1] if len(size)>1 else size[0],background_color=bg)

ADAPT=0.86   # adaptive-icon foreground scale: keeps every slab corner inside the 72dp circular mask

# ---------------------------------------------------------------- icon
icon=geo.icon_svg(True); square=geo.icon_svg(False)
w('icon/app-icon.svg',icon); w('icon/app-icon-square.svg',square)
png(icon,'icon/app-icon-1024.png',(1024,)); png(icon,'icon/app-icon-512.png',(512,))
png(square,'icon/app-icon-square-1024.png',(1024,))
png(square,'store/play-store-icon-512.png',(512,))
Image.open(f'{OUT}/icon/app-icon-square-1024.png').convert('RGB').save(f'{OUT}/store/app-store-icon-1024.png')

# ---------------------------------------------------------------- marks
w('brand/mark-on-dark.svg',geo.mark_svg(geo.ON_DARK,MAUVE,'Foam Shop — mark on dark'))
w('brand/mark-on-light.svg',geo.mark_svg(geo.ON_LIGHT,PERI,'Foam Shop — mark on light'))
w('brand/mark-mono-white.svg',geo.mono_svg('#FFFFFF')); w('brand/mark-mono-ink.svg',geo.mono_svg(NAVY,'Foam Shop — monochrome mark (ink)'))
png(geo.mark_svg(geo.ON_DARK,MAUVE),'brand/mark-on-dark.png',(1448,1060)); png(geo.mark_svg(geo.ON_LIGHT,PERI),'brand/mark-on-light.png',(1448,1060))

# ---------------------------------------------------------------- wordmark + lockup
def wordmark(dark=True,descriptor=True):
    a_col,b_col,d_col=(FOAM,MAUVE,PERI) if dark else (NAVY,SLATE,SLATE)
    a,wa=text.text_path('Foam','Manrope-ExtraBold.ttf',150,0,150,-0.01,a_col)
    b,wb=text.text_path('Shop','Manrope-Medium.ttf',150,wa+34,150,-0.01,b_col)
    W=wa+34+wb; H=190; extra=''
    if descriptor:
        c,wc=text.text_path('DIGITAL  REGISTER','Manrope-SemiBold.ttf',34,4,214,0.30,d_col); extra=c; H=240; W=max(W,wc+8)
    return a+b+extra,W,H
def wm_svg(dark=True,descriptor=True):
    body,W,H=wordmark(dark,descriptor)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-6 0 {W+12:.0f} {H}" width="{W+12:.0f}" height="{H}" role="img"><title>Foam Shop</title>{body}</svg>',W+12,H
for name,dk in (('on-dark',True),('on-light',False)):
    s,W,H=wm_svg(dk); w(f'brand/wordmark-{name}.svg',s); png(s,f'brand/wordmark-{name}.png',(int(W*2),H*2))
def lockup(dark=True):
    body,ww,wh=wordmark(dark,True); H=300; pad=50; hm=210; k=hm/530; mw=724*k; gap=60
    ramp,pc=(geo.ON_DARK,MAUVE) if dark else (geo.ON_LIGHT,PERI)
    top=(H-hm)/2
    mk=f'<g transform="translate({pad} {top}) scale({k}) translate(-150 -250)">{geo.mark_body(ramp,pc)}</g>'
    ty=(H-wh)/2+4
    W=pad+mw+gap+ww+pad
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H}" width="{W:.0f}" height="{H}" role="img"><title>Foam Shop — Digital Register</title>'
            f'{mk}<g transform="translate({pad+mw+gap:.1f} {ty:.1f})">{body}</g></svg>'),W,H
for name,dk in (('on-dark',True),('on-light',False)):
    s,W,H=lockup(dk); w(f'brand/lockup-{name}.svg',s); png(s,f'brand/lockup-{name}.png',(int(W),H),bg=(INK if dk else FOAM))

# ---------------------------------------------------------------- Android vector drawables (single geometry, 1024 viewport)
S=geo.slabs(); P=geo.pores()
def vec(size_dp,body,comment):
    return (f'<?xml version="1.0" encoding="utf-8"?>\n<!-- {comment}\n     Generated from design/brand (mark.json). Do not hand-edit the pathData; regenerate the kit. -->\n'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n    android:width="{size_dp}dp"\n    android:height="{size_dp}dp"\n'
            f'    android:viewportWidth="1024"\n    android:viewportHeight="1024">\n{body}</vector>\n')
def pth(d,color,even=False):
    return f'    <path\n        android:fillColor="{color}"\n' + ('        android:fillType="evenOdd"\n' if even else '') + f'        android:pathData="{d}"/>\n'
def grp(inner,scale,cx=512,cy=512):
    return f'    <group\n        android:pivotX="{cx}"\n        android:pivotY="{cy}"\n        android:scaleX="{scale}"\n        android:scaleY="{scale}">\n{inner}    </group>\n'
circ=lambda cx,cy,r:f"M{cx-r},{cy} a{r},{r} 0 1,0 {2*r},0 a{r},{r} 0 1,0 {-2*r},0 Z"
bg_xml=vec(108, pth('M0,0h1024v1024h-1024z','@color/brand_navy')+pth(circ(*geo.ACCENT),'@color/brand_slate'),
           'Adaptive icon BACKGROUND: flat Deep Navy + one flat Slate disc. Full-bleed, not pre-rounded: the launcher owns the mask.')
fg_inner=(pth(geo.d_of(S['bottom']),'@color/brand_periwinkle')+pth(geo.d_of(S['middle']),'@color/brand_mauve')+pth(geo.d_of(S['top']),'@color/brand_foam')
          +''.join(pth(geo.d_of(p),'@color/brand_mauve') for p in P))
fg_xml=vec(108,grp(fg_inner,ADAPT),'Adaptive icon FOREGROUND: three flat layers + pores, scaled to the 72dp safe zone. Transparent canvas.')
mono_xml=vec(108,grp(pth(geo.d_of(geo.mono(True)),'#FFFFFFFF',True),ADAPT),'Adaptive icon MONOCHROME (Android 13+ themed icons): single-colour silhouette, layers separated by cut-outs, pores as holes.')
stat_xml=vec(24,grp(pth(geo.d_of(geo.mono(False)),'#FFFFFFFF',True),1.3,512,516),'Notification small icon: white on transparent, no pores (they would be sub-pixel at 24dp).')
splash_inner=pth(circ(512,512,341),'@color/brand_navy')+grp(fg_inner,0.64)
splash_xml=vec(288,splash_inner,'Splash icon: flat Deep Navy disc (192dp = the Android 12 splash safe circle) with the mark inside.')
w('android-res/drawable/ic_launcher_background.xml',bg_xml); w('android-res/drawable/ic_launcher_foreground.xml',fg_xml)
w('android-res/drawable/ic_launcher_monochrome.xml',mono_xml); w('android-res/drawable/ic_stat_foam_shop.xml',stat_xml); w('android-res/drawable/splash_icon.xml',splash_xml)
launch='''<?xml version="1.0" encoding="utf-8"?>
<!-- Pre-Android-12 launch screen: the app's own page colour (light #F7F4F2 / dark #14141A, so the
     hand-off to the first Flutter frame has no colour jump) with the logo badge centred (180dp item = 120dp navy disc). -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item
        android:width="180dp"
        android:height="180dp"
        android:gravity="center"
        android:drawable="@drawable/splash_icon" />
</layer-list>
'''
w('android-res/drawable/launch_background.xml',launch); w('android-res/drawable-v21/launch_background.xml',launch)
adaptive='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
'''
w('android-res/mipmap-anydpi-v26/ic_launcher.xml',adaptive); w('android-res/mipmap-anydpi-v26/ic_launcher_round.xml',adaptive)
w('android-res/values/brand_colors.xml',f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Foam Shop brand palette. These are the app's existing AppColors values (lib/theme/app_theme.dart),
         declared once on the Android side so the icon and splash vectors cannot disagree. -->
    <color name="brand_ink">#FF0E0D15</color>
    <color name="brand_navy">#FF182346</color>
    <color name="brand_slate">#FF3D5387</color>
    <color name="brand_periwinkle">#FF7C83AD</color>
    <color name="brand_mauve">#FFBFA9BA</color>
    <color name="brand_foam">#FFF7F4F2</color>
    <!-- Launch-screen page colour = the Flutter light theme surface (AppColors.surface). -->
    <color name="splash_background">#FFF7F4F2</color>
</resources>
''')
w('android-res/values-night/brand_colors.xml','''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Dark theme surface (AppColors.surface in dark mode = 0xFF14141A). -->
    <color name="splash_background">#FF14141A</color>
</resources>
''')
v31='''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>
    </style>
</resources>
'''
w('android-res/values-v31/styles.xml',v31)
w('android-res/values-night-v31/styles.xml',v31.replace('Theme.Light.NoTitleBar','Theme.Black.NoTitleBar'))

# ---------------------------------------------------------------- legacy launcher PNGs (pre-API-26)
dens={'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}
round_svg=geo.icon_svg(True).replace(f'rx="{geo.TILE_RX}"','rx="512"')
for k,px in dens.items():
    os.makedirs(f'{OUT}/android-res/mipmap-{k}',exist_ok=True)
    png(icon,f'android-res/mipmap-{k}/ic_launcher.png',(px,)); png(round_svg,f'android-res/mipmap-{k}/ic_launcher_round.png',(px,))

# ---------------------------------------------------------------- web
png(icon,'web/Icon-192.png',(192,)); png(icon,'web/Icon-512.png',(512,)); png(icon,'web/favicon.png',(64,))
def maskable(px):
    s=(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="{px}" height="{px}">{geo.bg_body()}{geo.mark_body(scale=ADAPT)}</svg>'); return s
png(maskable(192),'web/Icon-maskable-192.png',(192,)); png(maskable(512),'web/Icon-maskable-512.png',(512,))
w('web/manifest.json',json.dumps({
 "name":"Foam Shop","short_name":"Foam Shop","start_url":".","display":"standalone",
 "background_color":"#F7F4F2","theme_color":"#182346",
 "description":"Foam Shop \u2014 Digital Register. Every sale. Every stock. Every khata.",
 "orientation":"portrait-primary","prefer_related_applications":False,
 "icons":[{"src":"icons/Icon-192.png","sizes":"192x192","type":"image/png"},{"src":"icons/Icon-512.png","sizes":"512x512","type":"image/png"},
          {"src":"icons/Icon-maskable-192.png","sizes":"192x192","type":"image/png","purpose":"maskable"},{"src":"icons/Icon-maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}]},indent=4)+"\n")

# ---------------------------------------------------------------- iOS (full-bleed, opaque; iOS applies its own mask)
ios={'Icon-App-20x20@1x':20,'Icon-App-20x20@2x':40,'Icon-App-20x20@3x':60,'Icon-App-29x29@1x':29,'Icon-App-29x29@2x':58,'Icon-App-29x29@3x':87,
     'Icon-App-40x40@1x':40,'Icon-App-40x40@2x':80,'Icon-App-40x40@3x':120,'Icon-App-50x50@1x':50,'Icon-App-50x50@2x':100,'Icon-App-57x57@1x':57,'Icon-App-57x57@2x':114,
     'Icon-App-60x60@2x':120,'Icon-App-60x60@3x':180,'Icon-App-72x72@1x':72,'Icon-App-72x72@2x':144,'Icon-App-76x76@1x':76,'Icon-App-76x76@2x':152,
     'Icon-App-83.5x83.5@2x':167,'Icon-App-1024x1024@1x':1024}
sq1024=Image.open(f'{OUT}/icon/app-icon-square-1024.png').convert('RGB')
for n,px in ios.items(): sq1024.resize((px,px),Image.LANCZOS).save(f'{OUT}/ios/AppIcon.appiconset/{n}.png')

# ---------------------------------------------------------------- mark.json (single source for drift tests)
mj={"version":"1.5.6","space":1024,"slab":{"w":geo.W,"h":geo.H,"r":geo.R,"gap":geo.GAP,"xs":geo.XS,"ys":geo.YS},
    "pores":[list(p) for p in geo.PORES],"tileRadius":geo.TILE_RX,"accent":list(geo.ACCENT),"adaptiveScale":ADAPT,
    "palette":{"ink":INK,"navy":NAVY,"slate":SLATE,"periwinkle":PERI,"mauve":MAUVE,"foam":FOAM},
    "paths":{"bottom":geo.d_of(S['bottom']),"middle":geo.d_of(S['middle']),"top":geo.d_of(S['top']),"pores":[geo.d_of(p) for p in P],
             "mono":geo.d_of(geo.mono(True)),"monoNoPores":geo.d_of(geo.mono(False)),"accentDisc":circ(*geo.ACCENT)}}
w('brand/mark.json',json.dumps(mj,indent=1)+"\n")
print('core built')
