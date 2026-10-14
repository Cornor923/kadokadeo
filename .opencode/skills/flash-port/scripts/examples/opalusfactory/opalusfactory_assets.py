"""Builds the Opalus Factory graphics for KadoKadeo from the original SWF (gfx.swf: the graphics library the released
game.swf was compiled with, same shapes and timelines, readable instance names).

Every symbol the game attaches is exported as a Clip (timeline tables played by opalusfactory.Clip, see clipexport.py):
  - the decor: mcBg (a 300 x 300 bitmap, native resolution), subRoll, wallUp (its three pistons `_p1` .. `_p3`, sprite
    35, played by the code from frame 4) and the door (`_top` / `_bottom`, moved by the code);
  - the roll: `case` (one hexagon) and `coin` (frame id + 1: 1 the nut-coin, 2..8 the opals, 9 the golden coin);
  - the holes: `order` (its `smc` is the coloured hole, sprite 21, whose text field the game draws) and `blockHole`
    (`_wheel`, `_bounce`, `_empty` where the code attaches the nuts, `_count` and its text field), `ecrou_2` (the nuts);
  - the hero, the score that rises (`points`, its text drawn by the game), `vanish`, `parts`.
The code puts filters on clips at run time (setLineShadow, setFocus, updateGlow, coinFalls). The drop shadows (blur 1:
no blur) are white silhouettes tinted by the game (`caseW`, `coinW`); the white inner glow of the focused cases
(Filt.glow(mc, 2, 10, 0xFFFFFF, true)) is baked as an overlay of the case at the two scales a playable line has
(`caseRim`: 100 % and 75 %). The buttons of the cases are hit tested on the shape of the case (a run-length mask).
The text fields (Trebuchet MS Bold: the digits of the font embedded in the SWF) are white glyphs tinted by the game.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: opalusfactory_assets.py <out dir>      (after prepare_game.sh: $KKP_WORK/opalusfactory holds gfx.swf and its exports)
"""
import os, sys, json, shutil, math, struct, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageFont, ImageDraw
import swfrender as R
import clipexport as C
import swftext
import swfdump as SD

W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'opalusfactory', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)
Gb = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)     # untouched timelines, for the measures
G1 = R.SWF(W + 'gfx.swf', W + 'shp1_gfx', Z=1)     # zoom 1: the bitmap of mcBg at its native resolution
for X in (G, Gb, G1):
    X.flash_replace = True
# the shine of the opals (sprites 49 and 51 in `coin`) is drawn in "overlay" mode; the hole of an order clip comes in
# blurred (BlurFilter of order.smc, 5 -> 0 px)
G.overlay = True
G.blur_filter = True
K = C.K


def clone(sid, nid, patch):
    """a copy of sprite sid whose placements go through patch(frame, placement) (None: dropped)"""
    sd = G.sprites[sid]
    nd = R.SpriteDef(nid, sd.nframes)
    nd.labels = dict(sd.labels)
    nd.actions = dict(sd.actions)
    for f, ops in enumerate(sd.frames, 1):
        out = []
        for k, v in ops:
            if k == 'place':
                v = patch(f, dict(v))
                if v is None:
                    continue
            out.append((k, v))
        nd.frames.append(out)
    G.sprites[nid] = nd
    return nid

# ---------------------------------------------------------------- clips
# frame scripts that are not plain playhead moves (decompiled in as_gfx/)
CUSTOM = {
    (25, 22): [['x', 'rmSelf']],        # points: removeMovieClip("")
}

E = C.Exporter(G, SRC, '', CUSTOM)
E.bitmaps = (G1, [125])
E.clip_res = [0.5, 1.0, 1.5, 2.0]

E.export(126, 'mcBg')
E.export(78, 'subRoll')
# wallUp without its tapi (depth 1, drawn by the game in "overlay" mode over what is under it, see below)
WALL = clone(43, 100043, lambda f, v: None if v.get('depth') == 1 else v)
E.export(WALL, 'wallUp', code=('_p1', '_p2', '_p3'))
E.export(5, 'door', code=('_top', '_bottom'))
E.export(76, 'case')
E.export(60, 'coin', strategy='flat')
E.export(22, 'order', code=('smc',))
E.export(96, 'ecrou_2', strategy='flat')
E.export(123, 'blockHole', code=('_wheel', '_bounce', '_empty', '_count'))
E.export(74, 'hero')
E.export(25, 'points', code=('_p',))
E.export(85, 'vanish')
E.export(87, 'parts')

ROOTS = ['mcBg', 'subRoll', 'wallUp', 'door', 'case', 'coin', 'order', 'ecrou_2', 'blockHole', 'hero', 'points',
         'vanish', 'parts']
keep, todo = set(), list(ROOTS)
while todo:
    nm = todo.pop()
    if nm in keep:
        continue
    keep.add(nm)
    todo += [Ly['a'] for Ly in E.clips[nm]['layers'] if Ly['k'] == 2]
used = {Ly['a'] for nm in keep for Ly in E.clips[nm]['layers'] if Ly['k'] != 2}
for nm in [nm for nm in E.clips if nm not in keep]:
    for Ly in E.clips.pop(nm)['layers']:
        if Ly['k'] != 2 and Ly['a'] not in used:
            for a in (Ly['a'], Ly['a'] + 'W'):
                if a in E.area:
                    shutil.rmtree(os.path.join(SRC, a))
                    E.area.pop(a)
                    E.pivots.pop(a)
    print('  unused clip %s removed' % nm)

clips, pivots, area = E.clips, E.pivots, E.area
meta = {}

# the nested clips the code drives: their clip names
def nested(clip, name):
    ls = [Ly for Ly in clips[clip]['layers'] if Ly.get('nm') == name]
    assert len(ls) == 1, (clip, name, ls)
    return ls[0]


for c, n in (('order', 'smc'), ('blockHole', '_wheel'), ('blockHole', '_bounce'), ('blockHole', '_empty'),
             ('blockHole', '_count'), ('wallUp', '_p1'), ('door', '_top'), ('door', '_bottom'), ('points', '_p')):
    Ly = nested(c, n)
    print('%s.%s: k=%d %s' % (c, n, Ly['k'], Ly['a']))
meta['holeClip'] = nested('order', 'smc')['a']
meta['countClip'] = nested('blockHole', '_count')['a']
meta['pClip'] = nested('points', '_p')['a']
meta['emptyClip'] = nested('blockHole', '_empty')['a']


# ---------------------------------------------------------------- run time filters: silhouettes and rims
def cmds_of(sid, frame=1, M=R.IDENT, cx=R.NOCX):
    inst = R.Instance(G, sid, ctrl={'__noactions__': True, sid: frame})
    out = []
    R.Renderer(G, K).collect(inst, M, cx, set(), out)
    return out


# setLineShadow / coinFalls: DropShadowFilter(d, -90, colour, 5, 1, 1, 0.6): a blur of 1 px is none, the shadow is the
# silhouette of the clip moved d stage pixels up, at 60 % (the game tints these white silhouettes)
imgs, reg = E.render([cmds_of(76, 1, cx=C.WHITE)], K)
E.write_anim('caseW', imgs, reg)
imgs, reg = E.render([cmds_of(60, f, cx=C.WHITE) for f in range(1, 10)], K)
E.write_anim('coinW', imgs, reg)


# Filt.glow(c.mc, 2, 10, 0xFFFFFF, true) on a case (its coin inside the opaque hexagon: only the hexagon's outline
# matters): Flash's inner glow (quality 1: one box blur of 2 x 2 stage pixels) = the colour at alpha
# clamp((1 - blurred alpha) * strength), drawn on the clip where it is opaque. In stage pixels: drawn for the scales a
# playable line can have (line 3: 75 %, the others 100 %)
RIM_SCALES = [1.0, 0.75]
rims = []
base = None
for ys in RIM_SCALES:
    im, rg = E.render([cmds_of(76, 1, M=dict(R.IDENT, d=ys))], K, margin=3)
    a = np.asarray(im[0], dtype=np.float32)[..., 3] / 255.0
    # the seams between the fills of the hexagon (anti-aliased one by one here, not in Flash: alpha 0.92..0.96 along
    # the inner hexagon) would glow at strength 10: the hexagon is convex, each row is opaque between its first and
    # last opaque pixels
    a = a.copy()
    for y in range(a.shape[0]):
        xs = np.nonzero(a[y] >= 0.99)[0]
        if len(xs):
            a[y, xs[0]:xs[-1] + 1] = 1.0
    b = R.box_blur(a, 2 * K, 2 * K, 1)
    g = np.clip((1 - b) * 10.0, 0, 1) * a
    rgba = np.zeros(a.shape + (4,), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = np.clip(g * 255 + 0.5, 0, 255).astype(np.uint8)
    rims.append((Image.fromarray(rgba, 'RGBA'), rg))
# one canvas: the biggest (100 %), the 75 % one centred on the same registration point
W0, H0 = rims[0][0].size
rg0 = rims[0][1]
canv = []
for im, rg in rims:
    c = Image.new('RGBA', (W0, H0), (255, 255, 255, 0))
    c.paste(im, (int(round(rg0[0] - rg[0])), int(round(rg0[1] - rg[1]))))
    canv.append(c)
E.write_anim('caseRim', canv, rg0)
meta['rimScales'] = [s * 100 for s in RIM_SCALES]


# ---------------------------------------------------------------- wallUp's tapi: "overlay" over what is under it
# depth 1 of wallUp (sprite 27, a grey gradient) is placed with BlurFilter(29, 2) and blendMode "overlay": it shades
# the roll, the holes and the hero under it (darker at the top, lighter at the bottom). Drawn here blurred, in normal
# mode; the game applies it in overlay mode on everything under DP_INTER (OverlayFilter)
TAPI = clone(43, 200043, lambda f, v: dict(v, blend=None) if v.get('depth') == 1 else None)
inst = R.Instance(G, TAPI, ctrl={'__noactions__': True})
cm = []
R.Renderer(G, K).collect(inst, R.IDENT, R.NOCX, set(), cm)
imgs, reg = E.render([cm], K, margin=1)
E.write_anim('tapi', imgs, reg)
meta['tapi'] = dict(x=-reg[0] / K, y=-reg[1] / K, w=imgs[0].size[0] / K, h=imgs[0].size[1] / K)
print('tapi', meta['tapi'])

# ---------------------------------------------------------------- order: the hole of each colour coming in, blurred
# (frames 1..15 of order: smc blurred by 5 -> 0 px; the game shows these pictures instead of smc on those frames)
INTRO = 15
assert all(f.get('type') == 'blur' for f in G.sprites[22].frames[0][0][1].get('filters', [])), G.sprites[22].frames[0]
for i in range(1, 8):
    cmds = []
    for f in range(1, INTRO + 1):
        inst = R.Instance(G, 22, ctrl={'__noactions__': True, 22: f, 21: i})
        cm = []
        R.Renderer(G, K).collect(inst, R.IDENT, R.NOCX, set(), cm)
        cmds.append(cm)
    imgs, reg = E.render(cmds, K * clips['order']['r'])
    E.write_anim('orderIn%d' % i, imgs, reg)
meta['orderIntro'] = INTRO


# ---------------------------------------------------------------- the button of a case: its shape (hit test)
# Flash tests the mouse on the shapes of a button clip: the hexagon (shape 75) and its coin, which stays inside it
HZ = 4
case_cmds = cmds_of(76, 1)
cmd_lists = [case_cmds] + [cmds_of(60, f) for f in range(1, 10)]
imgs, reg = E.render(cmd_lists, HZ, margin=1)
A = [np.asarray(im, dtype=np.uint8)[..., 3] >= 128 for im in imgs]
case_mask = A[0]
union = case_mask.copy()
for k, m in enumerate(A[1:], 1):
    out = m & ~case_mask
    if out.any():
        print('  coin frame %d outside the case: %d px (added to the hit mask)' % (k, out.sum()))
    union |= m
rows = []
for y in range(union.shape[0]):
    r = union[y]
    runs = []
    x = 0
    while x < len(r):
        if r[x]:
            x0 = x
            while x < len(r) and r[x]:
                x += 1
            runs.append([x0, x])
        else:
            x += 1
    rows.append(runs)
meta['hit'] = dict(z=HZ, ox=-reg[0] / HZ, oy=-reg[1] / HZ, rows=rows)


# ---------------------------------------------------------------- values the code reads on the display
def bounds(sid, ctrl=None, M=R.IDENT):
    inst = R.Instance(Gb, sid, ctrl=dict(ctrl or {}, __noactions__=True))
    rd = R.Renderer(Gb, 1)
    cmds = []
    rd.collect(inst, M, R.NOCX, set(), cmds)
    b = rd.bounds(cmds)
    return [round(b[0], 4), round(b[2], 4), round(b[1], 4), round(b[3], 4)]    # xMin xMax yMin yMax


def child(sid, frame, name):
    inst = R.Instance(Gb, sid, ctrl={'__noactions__': True, sid: frame})
    es = [e for e in inst.display.values() if e['name'] == name]
    assert len(es) == 1, (sid, frame, name)
    return es[0]['matrix']


# mcDoor._top._height / mcDoor._bottom._height (the shape bounds of the SWF, strokes included)
def shape_bounds(sid):
    """ShapeBounds of DefineShape `sid` (Flash's _width / _height use them)"""
    raw = open(W + 'gfx.swf', 'rb').read()
    data = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
    bb = SD.Bits(data, 8); bb.rect(); bb.u16(); bb.u16()
    for code, body in SD.read_tags(data, bb.pos, len(data)):
        if code in (2, 22, 32, 83) and struct.unpack_from('<H', body, 0)[0] == sid:
            b = SD.Bits(body, 2)
            return b.rect()
    raise KeyError(sid)


top = child(5, 1, '_top')
bot = child(5, 1, '_bottom')
assert top['a'] == 1 and top['d'] == 1 and bot['a'] == 1 and bot['d'] == 1, (top, bot)
tb = shape_bounds(1)
bb_ = shape_bounds(3)
print('door shapes', tb, bb_)
meta['doorTopHeight'] = round(tb[3] - tb[2], 4)
meta['doorBottomHeight'] = round(bb_[3] - bb_[2], 4)
# Game.initPlays: c.mc.hitTest(_xmouse, _ymouse): the bounds of the case clip (its coin inside them)
cb = shape_bounds(75)
meta['caseBounds'] = cb
for f in range(1, 10):
    b = bounds(60, {60: f})
    assert cb[0] <= b[0] and b[1] <= cb[1] and cb[2] <= b[2] and b[3] <= cb[3], (f, b, cb)
print('door', meta['doorTopHeight'], meta['doorBottomHeight'], 'case', cb)


# ---------------------------------------------------------------- text fields: Trebuchet MS Bold digits
def font_layouts(path):
    raw = open(path, 'rb').read()
    data = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
    bb = SD.Bits(data, 8); bb.rect(); bb.u16(); bb.u16()
    out = {}
    for code, body in SD.read_tags(data, bb.pos, len(data)):
        if code not in (48, 75):
            continue
        em = 20480.0 if code == 75 else 1024.0
        fid, flags, lang, nl = struct.unpack_from('<HBBB', body, 0)
        q = 5 + nl
        ng = struct.unpack_from('<H', body, q)[0]; q += 2
        wide = flags & 0x08
        wide_codes = code == 75 or (flags & 0x04)
        base = q
        q += ng * (4 if wide else 2)
        cto = struct.unpack_from('<I' if wide else '<H', body, q)[0]
        q = base + cto
        if wide_codes:
            codes = [struct.unpack_from('<H', body, q + 2 * i)[0] for i in range(ng)]
            q += 2 * ng
        else:
            codes = list(body[q:q + ng])
            q += ng
        assert flags & 0x80, 'font %d without layout' % fid
        asc, desc, lead = struct.unpack_from('<HHh', body, q); q += 6
        adv = struct.unpack_from('<%dh' % ng, body, q)
        out[fid] = dict(codes=codes, ascent=asc / em, descent=desc / em, adv={chr(c): v / em for c, v in zip(codes, adv)})
    return out


GLYPHS = '0123456789'


def glyph_alpha(ttf, size, res, pad):
    """alpha (0..1) of the digits rendered from the font at res (texture px = K * res), pen on the baseline at (ox, oy)"""
    SS = 4
    sc = K * res
    font = ImageFont.truetype(ttf, int(round(size * sc * SS)))
    lay = FONTS[7]
    w = int(math.ceil(max(lay['adv'][c] for c in GLYPHS) * size * sc)) + 2 * pad + 4
    h = int(math.ceil((lay['ascent'] + lay['descent']) * size * sc)) + 2 * pad + 2
    ox, oy = pad + 1, pad + int(math.ceil(lay['ascent'] * size * sc))
    out = []
    for ch in GLYPHS:
        big = Image.new('L', (w * SS, h * SS), 0)
        ImageDraw.Draw(big).text((ox * SS, oy * SS), ch, font=font, fill=255, anchor='ls')
        out.append(np.asarray(big.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0)
    return out, (ox, oy)


def flash_glow(a, f, sc):
    """alpha of Flash's outer GlowFilter / DropShadowFilter of an alpha layer (sc px per stage pixel)"""
    if f['type'] == 'dropshadow':
        dx = int(round(f['distance'] * math.cos(f['angle']) * sc))
        dy = int(round(f['distance'] * math.sin(f['angle']) * sc))
        assert dx == 0 and dy == 0, f
    g = R.box_blur(a, f['blurX'] * sc, f['blurY'] * sc, f.get('passes', 1))
    return np.clip(g * f['strength'], 0, 1) * (f['color'][3] / 255.0)


def write_alpha_anim(name, alphas, org):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    a = 0
    for i, al in enumerate(alphas):
        h, w = al.shape
        g = np.zeros((h, w, 4), dtype=np.uint8)
        g[..., :3] = 255
        g[..., 3] = np.clip(al * 255 + 0.5, 0, 255).astype(np.uint8)
        Image.fromarray(g, 'RGBA').save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
        bb = Image.fromarray(g[..., 3]).getbbox()
        if bb:
            a += (bb[2] - bb[0]) * (bb[3] - bb[1])
    pivots[name] = [round(org[0] / alphas[0].shape[1], 6), round(org[1] / alphas[0].shape[0], 6)]
    area[name] = a


def rgb(c):
    return (c[0] << 16) | (c[1] << 8) | c[2]


def field_layers(base, size, filters, extra=None):
    """the glyphs of a field and the layers of its filters (applied in order, each one on the result of the previous
    ones: a glow is drawn under what it surrounds); extra: a drop shadow of the parent clip (its distance applied by the
    game). Returns the layers from the bottom: [anim, colour, kind]"""
    pad = 16
    al, org = glyph_alpha(TTF, size, 1.0, pad)
    write_alpha_anim(base, al, org)
    layers = [[base, None, 'glyph']]
    comp = list(al)
    for n, f in enumerate([f for f in filters if not (f['type'] == 'blur' and f['blurX'] == 0 and f['blurY'] == 0)]):
        assert f['type'] == 'glow' and not f['inner'] and not f['knockout'], f
        gl = [flash_glow(a, f, K) for a in comp]
        name = '%sG%d' % (base, n)
        write_alpha_anim(name, gl, org)
        layers.insert(0, [name, rgb(f['color']), 'glow'])
        comp = [a + g * (1 - a) for a, g in zip(comp, gl)]
    if extra is not None:
        f = dict(extra, distance=0)
        sh = [flash_glow(a, f, K) for a in comp]
        name = '%sS' % base
        write_alpha_anim(name, sh, org)
        layers.insert(0, [name, rgb(f['color']), 'shadow'])
    return layers


TX = swftext.all_edittexts(W + 'gfx.swf')
FONTS = font_layouts(W + 'gfx.swf')
TTF = W + 'fonts_gfx/7_Trebuchet MS.ttf'
assert set(GLYPHS) <= set(FONTS[7]['adv']), FONTS[7]['adv']


def field_entry(sid, frame):
    inst = R.Instance(Gb, sid, ctrl={'__noactions__': True, sid: frame})
    es = [e for e in inst.display.values() if e['name'] == '_field']
    assert len(es) == 1, (sid, frame)
    return es[0]


def field(e, size):
    """layout of the text field of placement e: Flash's 2 px gutter, centred, first baseline at top + 2 + ascent"""
    t = TX[e['char']]
    m = e['matrix']
    assert t['font'] == 7 and t['align'] == 'center' and not t['html'] and t['height'] == size, t
    assert m['b'] == 0 and m['c'] == 0 and abs(m['a'] - 1) < 1e-9 and abs(m['d'] - 1) < 3e-3, m
    asc = FONTS[7]['ascent'] * size
    return dict(x=round(m['tx'] + t['bounds'][0] + 2, 3), w=round(t['bounds'][1] - t['bounds'][0] - 4, 3),
                base=round(m['ty'] + t['bounds'][2] + 2 + asc, 3), color=int(t['color'][1:], 16))


def adv(size):
    return [round(FONTS[7]['adv'][c] * size, 4) for c in GLYPHS]


# order.smc (hole, sprite 21): one field per frame (its colour, the colour of its glow); the same glow on each
e1 = field_entry(21, 1)
holeLayers = field_layers('dig14', 14.0, e1['filters'])
holeFields = []
for f in range(1, 8):
    e = field_entry(21, f)
    assert [dict(x, color=None) for x in e['filters']] == [dict(x, color=None) for x in e1['filters']], f
    fd = field(e, 14.0)
    fd['layers'] = [[a, fd['color'] if k == 'glyph' else rgb(e['filters'][0]['color']), k] for a, c, k in holeLayers]
    holeFields.append(fd)
meta['holeFields'] = holeFields
# blockHole._count._field (sprite 121)
e = field_entry(121, 1)
cf = field(e, 14.0)
cf['layers'] = [[a, cf['color'] if k == 'glyph' else c, k] for a, c, k in field_layers('dig14c', 14.0, e['filters'])]
meta['countField'] = cf
# points._p._field (sprite 24), and the drop shadow of _p (points, sprite 25): its distance on each frame
e = field_entry(24, 1)
P_SH = [v['filters'] for ops in G.sprites[25].frames for k, v in ops if k == 'place' and v.get('depth') == 1 and v.get('filters')]
sh0 = P_SH[0][0]
assert all(len(x) == 1 and dict(x[0], distance=0) == dict(sh0, distance=0) for x in P_SH), P_SH
assert abs(sh0['angle'] - math.pi / 2) < 1e-3, sh0
pf = field(e, 12.0)
pf['layers'] = [[a, pf['color'] if k == 'glyph' else c, k] for a, c, k in field_layers('dig12', 12.0, e['filters'], sh0)]
meta['pField'] = pf
meta['pShadow'] = [round(x[0]['distance'], 4) for x in P_SH]
meta['dig14'] = adv(14.0)
meta['dig12'] = adv(12.0)
print('fields', meta['holeFields'][0], meta['countField'], meta['pField'], meta['pShadow'])

json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
json.dump(clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
tot = sum(area.values())
print('clips %d, anims %d, trimmed area %.2f Mpx, warnings %d' % (len(clips), len(area), tot / 1e6, E.warnings))
for k, v in sorted(area.items(), key=lambda x: -x[1])[:30]:
    print('  %-24s %8d px' % (k, v))
