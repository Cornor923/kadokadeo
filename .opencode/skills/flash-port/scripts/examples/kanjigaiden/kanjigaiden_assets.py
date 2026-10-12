"""Builds the Kanji Gaiden graphics for KadoKadeo from the original SWF (gfx.swf: the graphics library of the released
game.swf, same shapes and timelines, readable names).

Every symbol the game attaches is exported as a Clip (timeline tables played by kanjigaiden.Clip, see clipexport.py):
  - the hero (Kanji's arm: hero > hero_wait > hand > the shuriken held, `smc` at each level driven by the code); the
    motion blur of the throw (blur filters tweened on the layers of hero_wait) is applied at run time ('bf');
  - the monkeys, one copy per plane: the plane's scale (cz) is the resolution of the pictures and the colour the
    original gives to the planes 1 and 2 (Col.setPercentColor on their container) is baked in; a copy at 100 % for
    the monkey that lands on the player at the game over. Their parts are cut pictures moved by the timeline (their
    colour matrix filters are identities), the banana they hold (`smc`, the kind of monkey) a nested clip driven by
    the code; its blur when it flies off the dead monkey is applied at run time. The brown outline (a glow filter on
    monkey_N, around the monkey and its banana) is drawn at run time ('fl');
  - the shots (kunai: the shuriken of each kind spinning, with the glows of its kind pushed into its timeline, and
    their bounce), the bonus icon (4 kinds, its entrance and vanishing filters baked), the rising score (the 6 values
    the game can show, drawn with the SWF font and the filters of the text field; its blur applied at run time), the
    warnings, the foreground and the background.
The bamboo forest of each plane is drawn by the game at run time into a bitmap (Plan.initBambooDraw: random kinds,
positions and offsets), from the parts of the bamboo exported here at the plane's scale and colour (the inner glow of
the leaves in bitmap pixels). What the code measures on the display (mcMonkey._width for the shots, the size of the
warning) is measured on the SWF and written in meta.json.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: kanjigaiden_assets.py <out dir>      (after prepare_game.sh: $KKP_WORK/kanjigaiden holds gfx.swf and its exports)
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

W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'kanjigaiden', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)
Gb = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)     # untouched timelines, for the measures
for X in (G, Gb):
    X.flash_replace = True
    X.inner_filters = True
    X.blur_filters = True
    # the colour of the planes 1 and 2 on the filtered pictures (the shurikens the monkeys carry: colour matrices of
    # one picture) after their filters, like Flash
    X.parent_cx_after_filters = True
K = C.K


def rng(*spans):
    out = []
    for a, b in spans:
        out += list(range(a, b + 1))
    return out


# ---------------------------------------------------------------- planes
# Game.initPlan: the planes of the bamboos (cz 0.5, 0.25, 0.125), the last two coloured by Col.setPercentColor(mc, prc,
# 0xD4FBA2): multiply 100 - prc %, offset int(prc / 100 * channel)
PLAN_CZ = [0.5, 0.25, 0.125]
PLAN_PRC = [0, 25, 50]


def percent_color(prc, col):
    c = prc / 100.0
    m = (100 - int(prc)) / 100.0
    return dict(mult=[m, m, m, 1.0], add=[int(c * ((col >> 16) & 0xFF)), int(c * ((col >> 8) & 0xFF)), int(c * (col & 0xFF)), 0])


PLAN_CX = [percent_color(p, 0xD4FBA2) if p else R.NOCX for p in PLAN_PRC]


def cx_rgb(cx, rgb):
    """a colour (0xRRGGBB) through a colour transform"""
    out = 0
    for i, s in enumerate((16, 8, 0)):
        v = int(round(((rgb >> s) & 0xFF) * cx['mult'][i] + cx['add'][i]))
        out |= max(0, min(255, v)) << s
    return out


# ---------------------------------------------------------------- sprites cloned with the filters of their placement
def clone(sid, nid, patch):
    sd = G.sprites[sid]
    nd = R.SpriteDef(nid, sd.nframes)
    nd.labels = dict(sd.labels)
    nd.actions = dict(sd.actions)
    for f, ops in enumerate(sd.frames, 1):
        nd.frames.append([(k, patch(f, dict(v)) if k == 'place' else v) for k, v in ops])
    G.sprites[nid] = nd
    return nid


def with_filters(sid, filters, nid):
    """a copy of sprite `sid` whose placements get `filters` after their own (a filter of a clip that holds one shape
    or sprite per frame: the same as on the clip)"""
    def p(f, v):
        if 'char' in v and not v.get('move'):
            v['filters'] = list(v.get('filters') or []) + list(filters)
        elif v.get('move') and v.get('filters') is not None:
            v['filters'] = list(v['filters']) + list(filters)
        return v
    for ops in G.sprites[sid].frames:
        depths = {v['depth'] for k, v in ops if k == 'place'}
        assert len(depths) <= 1, (sid, depths)
    return clone(sid, nid, p)


def non_blur(fl):
    return [f for f in fl or [] if f['type'] != 'blur']


def push_filters(parent, depth, base):
    """the non blur filters of the placements at `depth` of `parent` moved into copies of the placed sprite (its
    blurs stay, applied at run time); one copy per distinct list of filters"""
    copies = {}
    src, fl, shown, mtx, cxf = None, '[]', None, R.IDENT, None

    def p(f, v):
        nonlocal src, fl, shown, mtx, cxf
        if v['depth'] != depth:
            return v
        new = 'char' in v and not v.get('move')
        if new:
            mtx, cxf = R.IDENT, None
        if 'matrix' in v:
            mtx = v['matrix']
        if 'cx' in v:
            cxf = v['cx']
        if 'char' in v:
            src = v['char']
        if new:
            fl = repr(non_blur(v.get('filters')))
        if v.get('filters') is not None:
            fl = repr(non_blur(v['filters']))
            v['filters'] = [x for x in v['filters'] if x['type'] == 'blur']
        want = src
        if fl != '[]':
            key = (src, fl)
            if key not in copies:
                copies[key] = with_filters(src, eval(fl), base + len(copies))
            want = copies[key]
        # (a move keeps the instance unless the picture changes: the copy replaces the sprite only when its filters do,
        # with the matrix and colour of the instance it replaces, which a new instance would not keep)
        if new or want != shown:
            v['char'] = want
            if not new:
                v['matrix'] = mtx
                if cxf is not None:
                    v['cx'] = cxf
        shown = want
        return v
    nid = clone(parent, parent + 50000, p)
    return nid, copies


# ---------------------------------------------------------------- frame scripts
GOTO = lambda f: [['g', f, 1]]
MONKEYS = (81, 94, 107)
CUSTOM = {
    (32, 45): GOTO(1),                  # hero_wait: this.gotoAndPlay("_stand")
    (32, 59): GOTO(1),
    (15, 9): [['x', 'rmParent']],       # bounce: _parent.removeMovieClip() (the kunai)
    (43, 30): [['x', 'rmSelf']],        # bonus: this.removeMovieClip()
    (47, 25): [['x', 'rmSelf']],        # score
}
for s in MONKEYS:
    CUSTOM[(s, 30)] = GOTO(1)           # this.gotoAndPlay("_stand")
    CUSTOM[(s, 59)] = GOTO(45)          # "_run"
    CUSTOM[(s, 75)] = GOTO(1)
    CUSTOM[(s, 105)] = GOTO(1)
    CUSTOM[(s, 120)] = GOTO(1)
    CUSTOM[(s, 155)] = [['x', 'rmParent']]    # _parent.removeMovieClip() (the dead monkey)
    CUSTOM[(s, 185)] = GOTO(171)        # "_stunted"

# the shuriken spinning in a kunai (14: smc of the kunai, its frame = the kind of shot): the glows of each kind pushed
# into a copy of the spinning clip (10)
KUNAI_IN, KCOPIES = push_filters(14, 1, 80000)
KUNAI = clone(16, 80016, lambda f, v: dict(v, char=KUNAI_IN) if v.get('char') == 14 else v)
BOUNCE = clone(15, 80015, lambda f, v: dict(v, char=KUNAI_IN) if v.get('char') == 14 else v)
KUNAI = clone(KUNAI, 80017, lambda f, v: dict(v, char=BOUNCE) if v.get('char') == 15 else v)
CUSTOM[(BOUNCE, 9)] = CUSTOM[(15, 9)]


# ---------------------------------------------------------------- filters in stage pixels
# A filter baked in a picture is drawn in the pixels of its clip; Flash draws it in stage pixels, whatever the scale of
# the clip. The filters of the clips the game shows at another scale are divided by that scale: the shuriken in the
# hand (hero_wait at 0.589 in the hero), the bonus (80 %), the banana of the monkeys (one copy per plane, at cz).
# (The glows of the kunai stay at its scale 1: from 120 % thrown to 45 % at the background.)
def stage_scaled(fl, k):
    out = []
    for f in fl:
        f = dict(f)
        for key in ('blurX', 'blurY', 'distance'):
            if key in f:
                f[key] = f[key] / k
        out.append(f)
    return out


def scale_in_place(sid, k):
    for ops in G.sprites[sid].frames:
        for kind, v in ops:
            if kind == 'place' and v.get('filters'):
                v['filters'] = stage_scaled(v['filters'], k)


HERO_K = R.Instance(G, 33, ctrl={'__noactions__': True}).display[1]['matrix']['a']
scale_in_place(21, HERO_K)
scale_in_place(42, 0.8)
scale_in_place(43, 0.8)
# the monkeys of each plane: 108 > monkey_N > banana (58) with the banana's filters at 1 / cz
MONKEY_OF = {}          # plane -> the monkey clip (108 or its copy)
MONKEY_SIDS = set(MONKEYS)
for p in range(3):
    ban = clone(58, 90058 + p * 1000, lambda f, v: dict(v, filters=stage_scaled(v['filters'], PLAN_CZ[p])) if v.get('filters') else v)
    kids = {}
    for s in MONKEYS:
        kids[s] = clone(s, 90000 + p * 1000 + s, lambda f, v: dict(v, char=ban) if v.get('char') == 58 else v)
        MONKEY_SIDS.add(kids[s])
        for f in range(1, G.sprites[s].nframes + 1):
            if (s, f) in CUSTOM:
                CUSTOM[(kids[s], f)] = CUSTOM[(s, f)]
    MONKEY_OF[p] = clone(108, 90108 + p * 1000, lambda f, v: dict(v, char=kids[v['char']]) if v.get('char') in kids else v)


class Exporter(C.Exporter):
    pass


E = Exporter(G, SRC, '', CUSTOM)
E.effects = True
E.blurs = True
# (at most 1: the banana raised towards the camera by the jump, up to 2.9 times its size for a few frames, would need
# textures 3 times bigger than the rest of the monkey)
E.clip_res = [0.25, 0.5, 0.75, 1.0]
E.strategy_for = {32: 'cut', 27: 'cut', 21: 'flat', 58: 'flat', KUNAI_IN: 'flat'}
for s in MONKEY_SIDS:
    E.strategy_for[s] = 'cut'
for p in range(3):
    E.strategy_for[90058 + p * 1000] = 'flat'
E.code_for = {
    33: ('smc',), 32: ('smc',), 27: ('smc',),           # kanji.smc.smc.smc.gotoAndStop(sType)
    108: ('smc',),                                      # mcMonkey.smc.smc (the banana)
    KUNAI: ('smc',), BOUNCE: ('smc',),                  # mc.smc.gotoAndStop(sType) / mc.smc.smc
}
for s in MONKEY_SIDS:
    E.code_for[s] = ('smc',)
for p in range(3):
    E.code_for[MONKEY_OF[p]] = ('smc',)
for c in KCOPIES.values():
    E.strategy_for[c] = 'flat'

E.export(33, 'hero')
E.export(KUNAI, 'kunai')
# the monkeys of the planes: frames reached (155 removes the dead monkey, 156-170 never reached)
MONKEY_FRAMES = rng((1, 155), (171, 185))
for s in MONKEY_SIDS:
    E.frames_for[s] = MONKEY_FRAMES
for p in range(3):
    E.export(MONKEY_OF[p], 'monkey%d' % p, cx=PLAN_CX[p], res=PLAN_CZ[p])
# the monkey that lands on the player (Game.addAMonkeySpecial) only plays "_land" then "_stand", exported like the others
# (the same tables: see the shared timelines); its pictures at 1 (the parts scaled up by the jump, which it never plays,
# would get pictures at 2)
E.fixed_res = 1.0
E.export(108, 'monkeyD', res=1.0)
E.fixed_res = None
for s in MONKEY_SIDS:
    E.frames_for.pop(s)
# (Bonus.new: shown at 80 %; the frames blurred by 8 pixels or more (the entrance, the vanishing) at half that resolution,
# a second layer drawn x2: a blurred picture has no detail to lose)
BLURRED = [f for f in range(1, 31) if max(max(fl['blurX'], fl['blurY']) for fl in
                                         R.Instance(G, 43, ctrl={'__noactions__': True, 43: f}).display[1]['filters'] if fl['type'] == 'blur') >= 8]
SHARP = [f for f in range(1, 31) if f not in BLURRED]
print('bonus frames blurred', BLURRED)
for t in range(1, 5):
    a = E.export(43, 'bonus%d' % t, ctrl={42: t}, strategy='flat', res=0.75, frames=SHARP)
    lo = E.export(43, 'bonus%dlo' % t, ctrl={42: t}, strategy='flat', res=0.375, frames=BLURRED)
    la, ll = E.clips[a]['layers'], E.clips.pop(lo)['layers']
    assert len(la) == 1 and len(ll) == 1 and 'm' not in la[0] and 'm' not in ll[0], (la, ll)
    ll[0]['m0'] = [0, 0, 2, 2, 0]
    la.append(ll[0])
E.export(47, 'score', code=('mct',))
E.export(50, 'warning')
E.export(38, 'fg', strategy='flat')
# (two radial gradients without edge on the screen: a smooth picture, half the resolution is the same once drawn)
E.export(128, 'mcBg', strategy='flat', res=0.5)

# the glow of the monkeys through the colour of their plane
for p in range(3):
    for Ly in E.clips['monkey%d' % p]['layers']:
        for f in Ly.get('fl', []):
            f[3] = cx_rgb(PLAN_CX[p], int(f[3]))

clips, pivots, area = E.clips, E.pivots, E.area


meta = {}


# ---------------------------------------------------------------- score: the text field of mct (Junegull 30, right)
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


TX = swftext.all_edittexts(W + 'gfx.swf')
FONTS = font_layouts(W + 'gfx.swf')
T45 = TX[45]
assert T45['font'] == 44 and T45['align'] == 'right' and not T45['html'], T45
# Monkey.kill -> Game.scoreIt: Cs.PTS (50, 150, 350) or Cs.BONUS[1..3] (500, 1500, 3500)
SCORES = ['50', '150', '350', '500', '1500', '3500']
inst46 = R.Instance(Gb, 46, ctrl={'__noactions__': True})
e45 = [e for e in inst46.display.values() if e['char'] == 45][0]
m45 = e45['matrix']
assert m45['a'] == 1 and m45['d'] == 1 and m45['b'] == 0 and m45['c'] == 0, m45


def text_layer(txt, Z):
    """the text field (in sprite 46, Z px per Flash pixel) on a canvas: (array, origin of the canvas in 46)"""
    lay, size = FONTS[44], T45['height']
    x0, x1, y0, y1 = T45['bounds']
    pad = 16
    O = (m45['tx'] + x0 - pad, m45['ty'] + y0 - pad)
    w = int(math.ceil((x1 - x0 + 2 * pad) * Z))
    h = int(math.ceil((y1 - y0 + 2 * pad) * Z))
    font = ImageFont.truetype(W + 'fonts_gfx/44_Junegull.ttf', int(round(size * Z)))
    # Flash text field: 2 px gutter, right aligned, first baseline at top + 2 + ascent
    width = sum(lay['adv'][c] for c in txt) * size
    pen = (x1 - 2 - width) + m45['tx']
    base = y0 + 2 + lay['ascent'] * size + m45['ty']
    al = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(al)
    for c in txt:
        d.text(((pen - O[0]) * Z, (base - O[1]) * Z), c, font=font, fill=255, anchor='ls')
        pen += lay['adv'][c] * size
    a = np.asarray(al, dtype=np.float32) / 255.0
    col = [int(T45['color'][i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    arr = np.stack([a * col[0], a * col[1], a * col[2], a], axis=-1)
    for f in e45['filters']:
        arr = R.apply_filter(arr, f, Z, True)
    return arr, O


Z = G.Z
txts = []
for t in SCORES:
    arr, O = text_layer(t, Z)
    im = Image.fromarray(np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
    im = im.resize((int(round(im.width * K / Z)), int(round(im.height * K / Z))), Image.LANCZOS).convert('RGBA')
    txts.append(im)
E.write_anim('scoreTxt', txts, (-O[0] * K, -O[1] * K))
mct = [Ly for Ly in clips['score']['layers'] if Ly.get('nm') == 'mct']
assert len(mct) == 1 and mct[0]['k'] == 1, clips['score']
old = mct[0]['a']
mct[0]['a'] = 'scoreTxt'
mct[0]['t'] = [1 if x else 0 for x in mct[0]['t']]
if not any(Ly['a'] == old for c in clips.values() for Ly in c['layers']):
    shutil.rmtree(os.path.join(SRC, old))
    area.pop(old)
    pivots.pop(old)
# (the clip's own resolution: the text pictures are at 2 px per Flash pixel)
assert clips['score']['r'] == 1.0, clips['score']['r']
meta['scores'] = [int(s) for s in SCORES]


# ---------------------------------------------------------------- bamboo parts (drawn by the game, Plan.drawB)
def entry_of(sid, name=None, char=None):
    inst = R.Instance(Gb, sid, ctrl={'__noactions__': True})
    es = [(d, e) for d, e in inst.display.items() if (name and e['name'] == name) or (char and e['char'] == char)]
    assert len(es) == 1, (sid, name, char)
    return es[0][1]


def mat(m):
    return [round(m['a'], 6), round(m['b'], 6), round(m['c'], 6), round(m['d'], 6), round(m['tx'], 4), round(m['ty'], 4)]


def write_frames(name, cmd_lists, res):
    imgs, reg = E.render(cmd_lists, K * res)
    E.write_anim(name, imgs, reg)


def sprite_cmds(sid, frame, cx, filters=()):
    inst = R.Instance(G, sid, ctrl={'__noactions__': True, sid: frame})
    cmds = []
    R.Renderer(G, K).collect(inst, R.IDENT, cx, set(), cmds)
    if filters:
        cmds = [('layer', cmds, list(filters), None)]
    return cmds


B = 126
stalk = entry_of(B, char=115)        # the mask (clipDepth 7): the bamboo's outline
vine = entry_of(B, name='mask')      # the masked strip (mask._y = random(385))
dot = entry_of(B, char=119)
bottom = entry_of(B, name='bottom')
taupe = entry_of(B, name='taupe')
assert stalk['clip'] == 7 and vine['char'] == 118
nb = G.sprites[113].nframes
nt = G.sprites[125].nframes


def scaled_filters(fl, k):
    """filters of a part drawn at scale k into the bitmap: Flash filters are in bitmap pixels, not scaled"""
    out = []
    for f in fl:
        f = dict(f)
        for key in ('blurX', 'blurY', 'distance'):
            if key in f:
                f[key] = f[key] / k
        out.append(f)
    return out


for p in range(3):
    cz, cx = PLAN_CZ[p], PLAN_CX[p]
    # the outline as a white silhouette (alpha of the mask), the strip in the colour of the plane
    write_frames('bbStalk%d' % p, [sprite_cmds(115, 1, C.WHITE)], cz)
    write_frames('bbVine%d' % p, [sprite_cmds(118, 1, cx)], cz)
    write_frames('bbDot%d' % p, [[('shape', 119, R.IDENT, cx)]], cz)
    write_frames('bbBottom%d' % p, [sprite_cmds(113, f, cx) for f in range(1, nb + 1)], cz)
    write_frames('bbTaupe%d' % p, [sprite_cmds(125, f, cx, scaled_filters(taupe.get('filters') or [], cz)) for f in range(1, nt + 1)], cz)
    write_frames('herbes%d' % p, [sprite_cmds(35, 1, cx)], cz)
meta['bamboo'] = dict(stalk=mat(stalk['matrix']), vine=mat(vine['matrix']), dot=mat(dot['matrix']), bottom=mat(bottom['matrix']),
                      taupe=mat(taupe['matrix']), bottoms=nb, taupes=nt)
print('bamboo', meta['bamboo'])


# ---------------------------------------------------------------- values the code reads on the display
def flash_bounds(sid, ctrl):
    """Flash's bounds of a sprite (getBounds: the box of the boxes of its children, each through its matrix)"""
    inst = R.Instance(Gb, sid, ctrl=dict(ctrl, __noactions__=True))
    return inst_bounds(inst)


def box(m, b):
    xs, ys = [], []
    for (px, py) in ((b[0], b[2]), (b[1], b[2]), (b[0], b[3]), (b[1], b[3])):
        xs.append(m['a'] * px + m['c'] * py + m['tx'])
        ys.append(m['b'] * px + m['d'] * py + m['ty'])
    return [min(xs), max(xs), min(ys), max(ys)]


def inst_bounds(inst, skip=None):
    out = None
    for d, e in inst.display.items():
        if skip and skip(d, e):
            continue
        if e['inst'] is not None:
            b = inst_bounds(e['inst'])
        elif e['char'] in Gb.shapes:
            b = list(Gb.shapes[e['char']])
        else:
            b = None
        if b is None:
            continue
        b = box(e['matrix'], b)
        out = b if out is None else [min(out[0], b[0]), max(out[1], b[1]), min(out[2], b[2]), max(out[3], b[3])]
    return out


# mcMonkey._width (Plan.hittest): monkey on frame diff, its smc (monkey_N) on frame f, the banana (smc.smc) on frame k
# (absent on some frames): the width at _xscale 100 (the game multiplies it by |cz|)
widths = []
for di, s in enumerate(MONKEYS):
    m108 = [e for e in R.Instance(Gb, 108, ctrl={'__noactions__': True, 108: di + 1}).display.values() if e['name'] == 'smc'][0]['matrix']
    rows = []
    for f in range(1, Gb.sprites[s].nframes + 1):
        inst = R.Instance(Gb, s, ctrl={'__noactions__': True, s: f})
        body = inst_bounds(inst, lambda d, e: e['name'] == 'smc')
        ban = [e for e in inst.display.values() if e['name'] == 'smc']
        vals = []
        for k in range(1, 9):
            b = body
            if ban:
                bi = R.Instance(Gb, 58, ctrl={'__noactions__': True, 58: k})
                bb = inst_bounds(bi)
                if bb is not None:
                    bb = box(ban[0]['matrix'], bb)
                    b = bb if b is None else [min(b[0], bb[0]), max(b[1], bb[1]), min(b[2], bb[2]), max(b[3], bb[3])]
            # (frame 155: nothing left, the dead monkey removes itself)
            if b is None:
                vals.append(0)
                continue
            b = box(m108, b)
            vals.append(round(b[1] - b[0], 3))
        rows.append(vals[0] if len(set(vals)) == 1 else vals)
    widths.append(rows)
meta['monkeyWidth'] = widths

# Game.new: warn_l._width / _height of the warning on its first frame
wb = flash_bounds(50, {50: 1})
meta['warn'] = [round(wb[1] - wb[0], 4), round(wb[3] - wb[2], 4)]
print('warn', meta['warn'])

# clips no root uses and their images
ROOTS = ['hero', 'kunai', 'monkey0', 'monkey1', 'monkey2', 'monkeyD', 'bonus1', 'bonus2', 'bonus3', 'bonus4', 'score', 'warning',
         'fg', 'mcBg']
keep, todo = set(), list(ROOTS)
while todo:
    nm = todo.pop()
    if nm in keep:
        continue
    keep.add(nm)
    todo += [Ly['a'] for Ly in clips[nm]['layers'] if Ly['k'] == 2]
used = {Ly['a'] for nm in keep for Ly in clips[nm]['layers'] if Ly['k'] != 2}
for nm in [nm for nm in clips if nm not in keep]:
    for Ly in clips.pop(nm)['layers']:
        if Ly['k'] != 2 and Ly['a'] not in used:
            for a in (Ly['a'], Ly['a'] + 'W'):
                if a in area:
                    shutil.rmtree(os.path.join(SRC, a))
                    area.pop(a)
                    pivots.pop(a)
    print('  unused clip %s removed' % nm)

# ---------------------------------------------------------------- shared timelines
# the 12 clips of monkey_N (3 kinds x 4 copies: planes and game over) play the same timeline with other pictures and
# resolutions: one table, the others written as {base, r, ls: [[picture or clip, scale of the layer]]} (Clip.getDef)
def compose(m):
    if m is None:
        return None
    if len(m) == 5:
        x, y, sx, sy, r = m
        r = math.radians(r)
        return (math.cos(r) * sx, math.sin(r) * sx, -math.sin(r) * sy, math.cos(r) * sy, x, y)
    x, y, sx, sy, _, skx, sky = m
    # (PIXI: c = -sin(rotation - skew.x) * scale.y)
    return (math.cos(sky) * sx, math.sin(sky) * sx, math.sin(skx) * sy, math.cos(skx) * sy, x, y)


def derived(B, V):
    b, v = clips[B], clips[V]
    if b['n'] != v['n'] or len(b['layers']) != len(v['layers']) or b.get('acts') != v.get('acts') or b.get('labels') != v.get('labels'):
        return None
    kr = v['r'] / b['r']
    ls = []
    for lb, lv in zip(b['layers'], v['layers']):
        if any(lb.get(key) != lv.get(key) for key in set(lb) | set(lv) if key not in ('a', 'm', 'm0')):
            return None
        mb = lb['m'] if 'm' in lb else [lb.get('m0')] * b['n']
        mv = lv['m'] if 'm' in lv else [lv.get('m0')] * v['n']
        sc = None
        for x, y in zip(mb, mv):
            if (x is None) != (y is None):
                return None
            if x is None:
                continue
            cx_ = compose(x)
            nb = math.hypot(cx_[0], cx_[1]) + math.hypot(cx_[2], cx_[3])
            if nb > 1e-3:
                cy_ = compose(y)
                sc = (math.hypot(cy_[0], cy_[1]) + math.hypot(cy_[2], cy_[3])) / nb
                break
        sc = 1.0 if sc is None else sc
        for x, y in zip(mb, mv):
            if x is None:
                continue
            cx_, cy_ = compose(x), compose(y)
            for j in range(4):
                if abs(cx_[j] * sc - cy_[j]) > 4e-3:
                    return None
            for j in (4, 5):
                if abs(cx_[j] * kr - cy_[j]) > 0.03:
                    return None
        ls.append([lv['a'], round(sc if sc is not None else 1.0, 6)])
    return dict(n=v['n'], base=B, r=v['r'], ls=ls)


# (the base: the copy at the highest resolution, whose matrices were decomposed the most exactly: a slight skew that a
# smaller copy rounds to a rotation)
names = [n for k, n in E.variants.items() if k[0] in MONKEY_SIDS and n in clips]
base = max(names, key=lambda n: (clips[n]['r'], n.startswith('c%d' % MONKEYS[0])))
for V in names:
    if V == base:
        continue
    dv = derived(base, V)
    assert dv is not None, V
    clips[V] = dv
print('shared timelines: %d from %s' % (len(names) - 1, base))

json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
json.dump(clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
tot = sum(area.values())
print('clips %d, anims %d, trimmed area %.2f Mpx, warnings %d' % (len(clips), len(area), tot / 1e6, E.warnings))
for k, v in sorted(area.items(), key=lambda x: -x[1])[:40]:
    print('  %-24s %8d px' % (k, v))
