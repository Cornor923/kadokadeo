"""Builds the Aqua Splash graphics for KadoKadeo from the released SWF (game.swf, archive folder `sploutch`).

Little nested logic: every picture is rendered at x2 ("simple renders" pipeline, like Hexile) and the code places
them like the timelines of the original did.
  - mcBg: the bitmap of the board at its native resolution (drawn x2);
  - slime (sprite 126): frames 1-4 hold a "goute" (sprites 114, 113, 112, 111) that plays once and stops; the
    goutes 3 and 4 end on blinking eyes (sprite 110 / eyeClose 109): one picture per goute frame, then the 3 frames
    of the blink. Frame 5 only holds shape 125, an invisible rounded square (the button hit area);
  - for the gameplay: the bounds of each slime picture as Flash computes them (Drop.onSlime: root.hitTest(s.mc),
    a bounding box test) and the hit areas of the buttons (the shapes, the invisible square included), as masks;
  - the timeline animations (explode, burn, flame, splash, powerup x2, play, playBonus) rendered frame by frame
    with their nested clips playing (swfrender.timeline);
  - the particles (part1 under Col.setColor(mc, 0xFF9900), partLight, partSmoke), the drop, the time bar;
  - nextLevel (59 frames over the whole screen): its 3 layers (gradient 62, banner 64, plate of levelburn 60) and
    their placement on each frame (translations, alpha, grey colour transform), the plate's text drawn by the code;
  - text fields (level number, "x" + chain of the score): glyphs of the embedded fonts, transformed by the matrix of
    the field's placement (both are skewed), laid out like Flash.
Writes <out>/src (images), <out>/pivots.json and <out>/meta.json.
usage: aquasplash_assets.py <out dir>   (after prepare_game.sh: $KKP_WORK/aquasplash holds game.swf and its exports)
"""
import os, sys, json, shutil, math, struct, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import swfrender as R
import swfdump as SD
import swftext

W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'aquasplash', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

K = 2          # texture pixels per Flash pixel (the game is drawn x2)
# game.swf is the released game (graphics compiled in, instance names obfuscated); gfx.swf is the same library
G = R.SWF(W + 'game.swf', W + 'shp4_game', Z=4)
G.flash_replace = True
G.overlay = True      # the orange copy of the ball in play (sprite 74) and playBonus (sprite 100) is an 'overlay' layer
Z = G.Z

pivots = {}
area = {}
meta = {}

S_SLIME, S_DROP, S_SPLASH, S_EXPLODE, S_BURN, S_FLAME = 126, 107, 22, 41, 56, 99
S_POWERUP, S_PLAY, S_PLAYFX, S_PLAYBONUS = 17, 75, 74, 100
S_PART1, S_LIGHT, S_SMOKE, S_TIMELINE = 8, 105, 77, 12
S_NEXT, S_NLBG, S_BANNER, S_BURNTXT, S_SCORE = 65, 62, 64, 60, 70
GOUTES = [114, 113, 112, 111]          # goute1..4: frames 1..4 of the slime
S_EYES, S_EYECLOSE = 110, 109
SH_HIT, SH_DROP, SH_TIMEBG, SH_TIMELEFT = 125, 106, 11, 9
SH_SCOREBACK, SH_SCOREFRONT, SH_PLATE = 66, 69, 57
T_LEVEL, T_SCORE = 59, 68              # DefineEditText ids
IMG_BG = 115


def save_anim(name, imgs, reg):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    w, h = imgs[0].size
    for i, im in enumerate(imgs):
        assert im.size == (w, h)
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    pivots[name] = [round(reg[0] / w, 6), round(reg[1] / h, 6)]
    a = 0
    for im in imgs:
        bb = im.split()[3].getbbox()
        if bb:
            a += (bb[2] - bb[0]) * (bb[3] - bb[1])
    area[name] = a


def instance(sid, ctrl=None):
    return R.Instance(G, sid, ctrl=dict(ctrl or {}, __noactions__=True))


def cmds_inst(inst, M=R.IDENT, cx=R.NOCX):
    out = []
    R.Renderer(G, K).collect(inst, M, cx, set(), out)
    return out


def cmds_of(sid, ctrl=None, M=R.IDENT, cx=R.NOCX):
    return cmds_inst(instance(sid, ctrl), M, cx)


def shape_cmds(cid, cx=R.NOCX):
    return [('shape', cid, R.IDENT, cx)]


def render(items, pad=0.5):
    """items: command lists, or (commands, post) pairs, drawn on one common canvas (x4, reduced to x2);
    post(canvas) runs at x4 before the reduction. Returns (images, registration in px)."""
    items = [it if isinstance(it, tuple) else (it, None) for it in items]
    rd = R.Renderer(G, K)
    bb = None
    for cmds, _ in items:
        b = rd.bounds(cmds)
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    if bb is None:
        bb = (0, 0, 1, 1)
    step = 1.0 / K
    ox = math.floor((bb[0] - pad) / step) * step
    oy = math.floor((bb[1] - pad) / step) * step
    ex = math.ceil((bb[2] + pad) / step) * step
    ey = math.ceil((bb[3] + pad) / step) * step
    Wz, Hz = int(round((ex - ox) * Z)), int(round((ey - oy) * Z))
    w, h = int(round((ex - ox) * K)), int(round((ey - oy) * K))
    imgs = []
    for cmds, post in items:
        canvas = np.zeros((Hz, Wz, 4), dtype=np.float32)
        rd.draw(cmds, canvas, (ox, oy))
        if post:
            canvas = post(canvas)
        im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
        imgs.append(im.resize((w, h), Image.LANCZOS).convert('RGBA'))
    return imgs, (-ox * K, -oy * K)


def play(sid, n, ctrl=None):
    """the first n frames of a clip playing its timeline (nested clips playing too), as command lists"""
    return [cmds_inst(s) for s in R.timeline(G, sid, n, ctrl=ctrl)]


def twips(v):
    return round(v * 20) / 20.0


# ---------------------------------------------------------------- Flash bounds (getBounds / hitTest)
def rect_tf(m, r):
    xs, ys = [], []
    for px, py in ((r[0], r[2]), (r[1], r[2]), (r[0], r[3]), (r[1], r[3])):
        xs.append(m['a'] * px + m['c'] * py + m['tx'])
        ys.append(m['b'] * px + m['d'] * py + m['ty'])
    return [min(xs), max(xs), min(ys), max(ys)]


def flash_bounds(inst):
    """bounds of a clip in its own coordinates [xmin, xmax, ymin, ymax], like the Flash player: the bounds of each
    child (shape rectangle, or the bounds of a nested clip) transformed by its matrix, corners to rectangle"""
    out = None
    for d in sorted(inst.display):
        e = inst.display[d]
        r = flash_bounds(e['inst']) if e['inst'] is not None else G.shapes.get(e['char'])
        if r is None:
            continue
        r = rect_tf(e['matrix'], r)
        out = r if out is None else [min(out[0], r[0]), max(out[1], r[1]), min(out[2], r[2]), max(out[3], r[3])]
    return out


# ---------------------------------------------------------------- board
bg = Image.open(W + 'img_game/%d.jpg' % IMG_BG).convert('RGBA')
assert bg.size == (300, 300)
save_anim('bg', [bg], (0, 0))   # native resolution (res 1): drawn x2 like the zoomed Flash player

# ---------------------------------------------------------------- slimes
HIT = G.shapes[SH_HIT]          # [-19.6, 19.9, -19.8, 19.7], corners of radius 10 (svg_game/125.svg)


def in_hit_square(x, y):
    x0, x1, y0, y1 = HIT
    r = 10.0
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def mask_of(im, reg):
    """hit area of a slime picture: the pixels (texture pixels, from the clip origin) whose centre is in the shapes
    of the clip: the visible ones (alpha >= 50 %) and the invisible square 125"""
    a = np.asarray(im)[..., 3] >= 128
    h, w = a.shape
    for y in range(h):
        for x in range(w):
            if not a[y, x] and in_hit_square((x + 0.5 - reg[0]) / K, (y + 0.5 - reg[1]) / K):
                a[y, x] = True
    ys, xs = np.nonzero(a)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    rows = []
    for y in range(y0, y1):
        r = a[y, x0:x1].astype(np.int8)
        dd = np.diff(np.concatenate([[0], r, [0]]))
        st, en = np.nonzero(dd == 1)[0], np.nonzero(dd == -1)[0]
        rows.append(','.join('%d-%d' % (s + x0 - int(reg[0]), e + x0 - int(reg[0])) for s, e in zip(st, en)))
    return dict(y=int(y0 - reg[1]), rows=';'.join(rows))


slimes = []
for g, gs in enumerate(GOUTES, 1):
    n = G.sprites[gs].nframes
    states = []
    for f in range(1, n + 1):
        states.append({S_SLIME: g, gs: f})
    # goutes 3 and 4 end on sprite 110 (eyes, eyeClose frames 2-4 = the blink; 5 = 1)
    last = instance(S_SLIME, {S_SLIME: g, gs: n})
    blink = any(e['inst'] is not None and e['inst'].sid == S_EYES
                for e in last.display[2]['inst'].display.values())
    if blink:
        for e in (2, 3, 4):
            states.append({S_SLIME: g, gs: n, S_EYECLOSE: e})
    insts = [instance(S_SLIME, c) for c in states]
    imgs, reg = render([cmds_inst(i) for i in insts])
    save_anim('slime%d' % g, imgs, reg)
    assert reg[0] == int(reg[0]) and reg[1] == int(reg[1])
    bounds = [[twips(v) for v in flash_bounds(i)] for i in insts]
    masks = [mask_of(im, reg) for im in imgs]
    slimes.append(dict(n=n, blink=blink, bounds=bounds, masks=masks))
    print('slime%d' % g, n, blink, bounds[0], bounds[-1])
meta['slimes'] = slimes
# frame 5: shape 125 alone
meta['slime5'] = dict(bounds=[twips(v) for v in flash_bounds(instance(S_SLIME, {S_SLIME: 5}))],
                      mask=mask_of(Image.new('RGBA', (100, 100)), (50, 50)))

# ---------------------------------------------------------------- drop
inst = instance(S_DROP)
meta['dropBounds'] = [twips(v) for v in flash_bounds(inst)]
imgs, reg = render([cmds_inst(inst)])
save_anim('drop', imgs, reg)


# ---------------------------------------------------------------- timeline animations
def anim(name, sid, n, ctrl=None):
    imgs, reg = render(play(sid, n, ctrl))
    save_anim(name, imgs, reg)


# removeMovieClip() on the last frame: those frames are never drawn
anim('splash', S_SPLASH, 4)
anim('explode', S_EXPLODE, 6)
anim('burn', S_BURN, 15)
anim('flame', S_FLAME, 29)
# powerup: smc.gotoAndStop(1) (+1 play, a chain) or 2 (a bonus)
smc = [e['inst'].sid for e in instance(S_POWERUP).display.values() if e['name'] == 'smc'][0]
anim('powerup1', S_POWERUP, 24, {smc: 1})
anim('powerup2', S_POWERUP, 24, {smc: 2})
anim('playBonus', S_PLAYBONUS, 20)
# play: frame 1 (lost), 2 (left), 3: a new one, sprite 74 playing its 31 frames (stop() on 31)
lists = [cmds_of(S_PLAY, {S_PLAY: 1}), cmds_of(S_PLAY, {S_PLAY: 2})]
lists += [cmds_of(S_PLAY, {S_PLAY: 3, S_PLAYFX: f}) for f in range(1, 32)]
imgs, reg = render(lists)
save_anim('play', imgs, reg)

# ---------------------------------------------------------------- particles
# Col.setColor(mc, 0xFF9900): multipliers 100 %, offsets (r - 255, g - 255, b - 255)
ORANGE = dict(mult=[1.0, 1.0, 1.0, 1.0], add=[0, 0x99 - 255, -255, 0])
imgs, reg = render([cmds_of(S_PART1, {S_PART1: f}, cx=ORANGE) for f in (1, 2)])
save_anim('part1', imgs, reg)
imgs, reg = render([cmds_of(S_LIGHT, {S_LIGHT: f}) for f in (1, 2)])
save_anim('partLight', imgs, reg)
imgs, reg = render([cmds_of(S_SMOKE)])
save_anim('partSmoke', imgs, reg)

# ---------------------------------------------------------------- time bar (timeLine: frame shape + _timeLeft)
for name, cid in (('timeBg', SH_TIMEBG), ('timeLeft', SH_TIMELEFT)):
    imgs, reg = render([shape_cmds(cid)])
    save_anim(name, imgs, reg)
tl = instance(S_TIMELINE)
for d, e in tl.display.items():
    if e['name'] == '_timeLeft':
        assert e['matrix'] == R.IDENT or (e['matrix']['tx'] == 0 and e['matrix']['ty'] == 0)
meta['timeLeftW'] = G.shapes[SH_TIMELEFT][1] - G.shapes[SH_TIMELEFT][0]
meta['timeLeftH'] = G.shapes[SH_TIMELEFT][3] - G.shapes[SH_TIMELEFT][2]

# ---------------------------------------------------------------- score (shape 66, the field, shape 69 over it)
for name, cid in (('scoreBack', SH_SCOREBACK), ('scoreFront', SH_SCOREFRONT)):
    imgs, reg = render([shape_cmds(cid)])
    save_anim(name, imgs, reg)

# ---------------------------------------------------------------- blurred variants (BlurFilter of a timeline)
def to_img(c):
    """premultiplied float canvas -> RGBA image"""
    a = c[..., 3:4]
    rgb = np.where(a > 0, c[..., :3] / np.maximum(a, 1e-6), 0)
    return Image.fromarray(np.clip(np.concatenate([rgb, a], -1) * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBA')


def to_canvas(im):
    c = np.asarray(im.convert('RGBA'), dtype=np.float32) / 255.0
    return np.concatenate([c[..., :3] * c[..., 3:4], c[..., 3:4]], -1)


def blurred(canvases, reg, bx, by):
    """a BlurFilter (quality 1: one box blur, widths in stage pixels) on pictures at x2 sharing a registration.
    The result is smooth over bx * K pixels horizontally: it is kept at 1 / s of the horizontal resolution (the game
    draws it s times wider). Returns (images, registration, s)."""
    px, py = int(math.ceil(bx * K / 2)) + 2, int(math.ceil(by * K / 2)) + 2
    s = max(1, int(bx * K / 8))
    out = []
    for c in canvases:
        h, w = c.shape[:2]
        wp = int(math.ceil((w + 2 * px) / s)) * s
        big = np.zeros((h + 2 * py, wp, 4), dtype=np.float32)
        big[py:py + h, px:px + w] = c
        big = np.stack([R.box_blur(big[..., i], bx * K, by * K, 1) for i in range(4)], -1)
        big = big.reshape(big.shape[0], wp // s, s, 4).mean(axis=2)
        out.append(to_img(big))
    return out, ((reg[0] + px) / s, reg[1] + py), s


def blur_key(f):
    return (round(f['blurX'], 4), round(f['blurY'], 4))


# ---------------------------------------------------------------- nextLevel: layers + table
# d1: gradient 62 drawn "add" under a grey colour transform (c * m + a): tinted by m, plus a white square tinted a,
# both added; d7: banner 64 and d3: levelburn 60 (plate 57 + the field), each with a horizontal BlurFilter on most
# frames of their slides
for name, cmds in (('nlBg', cmds_of(S_NLBG)), ('nlBanner', cmds_of(S_BANNER)), ('nlPlate', shape_cmds(SH_PLATE))):
    imgs, reg = render([cmds])
    save_anim(name, imgs, reg)
    if name == 'nlBanner':
        banner = (imgs, reg)
    if name == 'nlPlate':
        plate = (imgs, reg)
save_anim('white', [Image.new('RGBA', (4, 4), (255, 255, 255, 255))], (0, 0))
nl = []
blurs = {3: [], 7: []}
for f in range(1, G.sprites[S_NEXT].nframes):
    i = instance(S_NEXT, {S_NEXT: f})
    row = {}
    for d, e in i.display.items():
        m, c = e['matrix'], e['cx']
        assert abs(m['a'] - 1) < 1e-4 and abs(m['d'] - 1) < 1e-4 and abs(m['b']) < 1e-4 and abs(m['c']) < 1e-4
        assert c['mult'][0] == c['mult'][1] == c['mult'][2] and c['add'][0] == c['add'][1] == c['add'][2]
        assert c['add'][3] == 0
        r = [twips(m['tx']), twips(m['ty']), round(c['mult'][3], 4), round(c['mult'][0], 4), c['add'][0]]
        if d == 1:
            assert e['blend'] == 'add' and not e['filters']
        else:
            assert len(e['filters']) == 1 and e['filters'][0]['type'] == 'blur' and e['filters'][0]['passes'] == 1
            k = blur_key(e['filters'][0])
            if k[0] < 0.5 and k[1] < 0.5:
                r.append(-1)
            else:
                if k not in blurs[d]:
                    blurs[d].append(k)
                r.append(blurs[d].index(k))
        row[d] = r
    assert set(row) <= {1, 3, 7}
    nl.append([row.get(1), row.get(3), row.get(7)])
meta['nextLevel'] = nl
# blurred banners
bs = []
for i, (bx, by) in enumerate(blurs[7]):
    imgs, reg, s = blurred([to_canvas(banner[0][0])], banner[1], bx, by)
    save_anim('nlBanner_B%d' % i, imgs, reg)
    bs.append(s)
meta['bannerBlurS'] = bs
bs = []
for i, (bx, by) in enumerate(blurs[3]):
    imgs, reg, s = blurred([to_canvas(plate[0][0])], plate[1], bx, by)
    save_anim('nlPlate_B%d' % i, imgs, reg)
    bs.append(s)
meta['plateBlurS'] = bs
for e in instance(S_BURNTXT).display.values():
    if e['char'] == SH_PLATE:
        assert e['matrix']['tx'] == 0 and e['matrix']['ty'] == 0

# ---------------------------------------------------------------- text fields
TX = swftext.all_edittexts(W + 'game.swf')
raw = open(W + 'game.swf', 'rb').read()
DATA = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
_hb = SD.Bits(DATA, 8)
_hb.rect(); _hb.u16(); _hb.u16()
TAGS = SD.read_tags(DATA, _hb.pos, len(DATA))


def font_layout(fid):
    for code, body in TAGS:
        if code not in (48, 75) or struct.unpack_from('<H', body, 0)[0] != fid:
            continue
        em = 20480.0 if code == 75 else 1024.0
        _, flags, lang, nl_ = struct.unpack_from('<HBBB', body, 0)
        q = 5 + nl_
        ng = struct.unpack_from('<H', body, q)[0]; q += 2
        wide = flags & 0x08
        base = q
        q += ng * (4 if wide else 2)
        q = base + struct.unpack_from('<I' if wide else '<H', body, q)[0]
        codes = [struct.unpack_from('<H', body, q + 2 * i)[0] for i in range(ng)]
        q += 2 * ng
        asc, desc, lead = struct.unpack_from('<HHh', body, q); q += 6
        adv = struct.unpack_from('<%dh' % ng, body, q)
        return dict(ascent=asc / em, descent=desc / em, adv={chr(c): v / em for c, v in zip(codes, adv)})


def field_place(sid, tid):
    for d, e in instance(sid).display.items():
        if e['char'] == tid:
            return e


def glyphs(name, sid, tid, chars, blur_list=()):
    """the glyphs of a text field (its font, size and colour) under the matrix of its placement (scale + skew baked):
    pivot = the pen position on the baseline. The filters of the field (in stage pixels, each one on the result of
    the previous) are layers under the glyph, from the bottom: name + '_L0', '_L1'... (the glyph is the last one): the
    game draws every glyph's layer 0, then every glyph's layer 1... as Flash draws the filters of a field under its
    whole text. blur_list: BlurFilters of the clip holding the field: name + '_B<i>', each glyph with its layers
    composed then blurred (see blurred). Layout (meta[name]): the pen moves along the field's x axis, the glyph of pen
    position p (field units) is placed at M * (p, base) in the clip holding the field."""
    t = TX[tid]
    e = field_place(sid, tid)
    m = e['matrix']
    filters = e.get('filters') or []
    fl = font_layout(t['font'])
    ttf = [f for f in os.listdir(W + 'fonts_game') if f.startswith('%d_' % t['font'])][0]
    size = t['height']
    SS = 4                        # supersampling of the output
    HR = 8                        # glyph pixels per field unit before the transform
    font = ImageFont.truetype(W + 'fonts_game/' + ttf, int(round(size * HR)))
    rgb = tuple(int(t['color'][i:i + 2], 16) for i in (1, 3, 5))
    pad = 30                      # room for the filters (output pixels)
    gx0, gx1 = -0.2 * size, max(fl['adv'][c] for c in chars) * size + 0.2 * size
    gy0, gy1 = -(fl['ascent'] + 0.2) * size, (fl['descent'] + 0.2) * size
    corners = [(m['a'] * x + m['c'] * y, m['b'] * x + m['d'] * y) for x in (gx0, gx1) for y in (gy0, gy1)]
    ox = -math.floor(min(c[0] for c in corners) * K) + pad
    oy = -math.floor(min(c[1] for c in corners) * K) + pad
    w = int(math.ceil(max(c[0] for c in corners) * K)) + ox + pad
    h = int(math.ceil(max(c[1] for c in corners) * K)) + oy + pad
    det = m['a'] * m['d'] - m['b'] * m['c']
    ia, ib, ic, id_ = m['d'] / det, -m['c'] / det, -m['b'] / det, m['a'] / det
    sx0, sy0 = -gx0 * HR, -gy0 * HR    # pen point in the glyph picture
    layers = None
    for ch in chars:
        big = Image.new('L', (int((gx1 - gx0) * HR) + 1, int((gy1 - gy0) * HR) + 1), 0)
        ImageDraw.Draw(big).text((sx0, sy0), ch, font=font, fill=255, anchor='ls')
        # output pixel U (at SS) -> parent p = ((U + .5) / SS - o) / K -> field = Minv p -> glyph pixel = field * HR + s0
        f = 1.0 / (SS * K)
        A, B, D, E = HR * ia * f, HR * ib * f, HR * ic * f, HR * id_ * f
        C = HR * (ia * (0.5 / SS - ox) / K + ib * (0.5 / SS - oy) / K) + sx0 - 0.5
        F = HR * (ic * (0.5 / SS - ox) / K + id_ * (0.5 / SS - oy) / K) + sy0 - 0.5
        a = big.transform((w * SS, h * SS), Image.AFFINE, (A, B, C, D, E, F), resample=Image.BILINEAR)
        a = np.asarray(a.resize((w, h), Image.BOX), dtype=np.float32) / 255.0
        stack = [(rgb, a)]
        ca = a
        for fi in filters:
            if fi['type'] == 'glow':
                g = R.box_blur(ca, fi['blurX'] * K, fi['blurY'] * K, fi.get('passes', 1))
            elif fi['type'] == 'dropshadow':
                dx = int(round(fi['distance'] * math.cos(fi['angle']) * K))
                dy = int(round(fi['distance'] * math.sin(fi['angle']) * K))
                g = np.roll(np.roll(ca, dy, axis=0), dx, axis=1)
                g = R.box_blur(g, fi['blurX'] * K, fi['blurY'] * K, fi.get('passes', 1))
            else:
                raise ValueError(fi['type'])
            assert not fi.get('inner') and not fi.get('knockout')
            g = np.clip(g * fi['strength'], 0, 1) * (fi['color'][3] / 255.0)
            stack.insert(0, (tuple(fi['color'][:3]), g))
            ca = ca + g * (1 - ca)
        if layers is None:
            layers = [[] for _ in stack]
        for k, (c, al) in enumerate(stack):
            layers[k].append(np.concatenate([np.array(c, dtype=np.float32)[None, None, :] / 255.0 * al[..., None],
                                             al[..., None]], -1))
    for k, cs in enumerate(layers):
        save_anim('%s_L%d' % (name, k), [to_img(c) for c in cs], (ox, oy))
    bs = []
    for i, (bx, by) in enumerate(blur_list):
        comp = []
        for j in range(len(chars)):
            c = np.zeros_like(layers[0][j])
            for k in range(len(layers)):
                c = layers[k][j] + c * (1 - layers[k][j][..., 3:4])
            comp.append(c)
        imgs, reg, s = blurred(comp, (ox, oy), bx, by)
        save_anim('%s_B%d' % (name, i), imgs, reg)
        bs.append(s)
    b = t['bounds']
    # Flash layout: 2 px gutter, first baseline at top + 2 + ascent (field units)
    meta[name] = dict(chars=chars, adv=[round(fl['adv'][c] * size, 4) for c in chars],
                      x0=b[0] + 2, x1=b[1] - 2, base=round(b[2] + 2 + fl['ascent'] * size, 4), align=t['align'],
                      layers=len(layers), blurS=bs, wrap=bool(t['wordWrap'] and t['multiline']),
                      lineH=round((fl['ascent'] + fl['descent']) * size + t['leading'], 4),
                      m=[round(m[k], 6) for k in ('a', 'b', 'c', 'd')] + [twips(m['tx']), twips(m['ty'])])
    print(name, meta[name], [fi['type'] for fi in filters])


glyphs('glyphLevel', S_BURNTXT, T_LEVEL, '0123456789', blurs[3])
glyphs('glyphScore', S_SCORE, T_SCORE, '0123456789x')


json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
tot = sum(area.values())
print('anims %d, trimmed area %.2f Mpx' % (len(area), tot / 1e6))
for k, v in sorted(area.items(), key=lambda x: -x[1])[:14]:
    print('  %-24s %8d px' % (k, v))
