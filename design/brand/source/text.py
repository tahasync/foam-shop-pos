from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
import os
FONTS=os.environ.get('FOAM_FONTS','assets/fonts/')  # point at the repo's assets/fonts/
_cache={}
def _f(name):
    if name not in _cache: _cache[name]=TTFont(FONTS+name)
    return _cache[name]
def text_path(s, font, size, x=0, y=0, tracking=0.0, fill="#fff", extra=""):
    """Return (<path .../>, width) with glyph outlines baked in (no font dependency)."""
    f=_f(font); gs=f.getGlyphSet(); cmap=f.getBestCmap(); upm=f['head'].unitsPerEm
    sc=size/upm; cx=0; d=[]
    for ch in s:
        gn=cmap.get(ord(ch))
        if gn is None: continue
        pen=SVGPathPen(gs)
        tp=TransformPen(pen,(sc,0,0,-sc,x+cx,y))
        gs[gn].draw(tp)
        d.append(pen.getCommands())
        cx+=f['hmtx'][gn][0]*sc+tracking*size
    return f'<path d="{" ".join(d)}" fill="{fill}" {extra}/>', cx-tracking*size
