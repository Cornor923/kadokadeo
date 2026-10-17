"""Builds the Mel graphics for KadoKadeo from the released game.swf of the Arkadeo game (Arkadeo/games/mel/swf).

Mel is drawn at 1 canvas pixel per Flash pixel (the Arkadeo game area: 600 x 460), so the textures are at 1 px per
Flash pixel (clipexport res 0.5, K = 2), like the bitmaps the original drew with mt.deepnight.Lib.flatten.
  - the MovieClips the code plays (Mel, the fx, the burners, the grabbers, the swarm, the sentinels, the life bar)
    are Clip timelines (clipexport.py), with the frame scripts of their AS3 classes (gfx_fla.*: stop / gotoAndPlay);
    the instance names of the released SWF are obfuscated with a trailing '_' (smc_, wr_, wl_): renamed;
  - `_hit` boxes are invisible (alpha 0): not drawn, their rectangles are measured for the collisions (getRect);
  - what the original flattened into bitmaps (platform pieces, props, wall tiles, the planes of the background, the
    saw blade frames of McCache) is drawn at the size flatten gave it: ceil(bounds), pixel (0, 0) = bounds top left;
  - the texts are drawn with the glyphs of the fonts embedded in game.swf (galaxy, trana, Transponder AOE), with the
    filters of the original text fields baked in.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: mel_assets.py <out dir>
"""
import os, sys, json, shutil, math, struct, zlib, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import swfrender as R
import clipexport as C
import swftext
import swfdump as SD

# game.swf + FFDec exports (sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/mel mel game)
W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'mel', '')
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..', '..', '..'))
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'game.swf', W + 'shp4_game', Z=4)     # drawn
GM = R.SWF(W + 'game.swf', W + 'shp4_game', Z=4)    # measured (untouched: _hit boxes kept)
for S_ in (G, GM):
    S_.flash_replace = True

RENAME = {'smc_': 'smc', 'wr_': 'wr', 'wl_': 'wl'}
for S_ in (G, GM):
    for sd in S_.sprites.values():
        for ops in sd.frames:
            for k, v in ops:
                if k == 'place' and v.get('name') in RENAME:
                    v['name'] = RENAME[v['name']]
# the _hit boxes (alpha 0) are not drawn
for sd in G.sprites.values():
    hd = set()
    for ops in sd.frames:
        for k, v in ops:
            if k == 'place' and v.get('name') == '_hit':
                hd.add(v['depth'])
    if hd:
        for i, ops in enumerate(sd.frames):
            sd.frames[i] = [(k, v) for k, v in ops if not ((k == 'place' and v['depth'] in hd) or (k == 'remove' and v in hd))]

# frame scripts of the AS3 classes of the timelines (decompiled gfx_fla.*: addFrameScript)
CUSTOM = {
    (202, 17): [['s']],                      # Slash1
    (304, 18): [['s']], (304, 31): [['s']],  # _hero_crouch: crouch / uncrouch
    (301, 13): [['s']],                      # _hero_grab
    (292, 20): [['g', 12, 1]],               # _hero_jump: gotoAndPlay("loop")
    (292, 38): [['g', 28, 1]],               # gotoAndPlay("loopLeft")
    (292, 55): [['g', 45, 1]],               # gotoAndPlay("loopRight")
    (292, 63): [['s']],
    (268, 20): [['g', 1, 1]],                # _hero_run: gotoAndPlay("loop")
    (72, 1): [['s']], (326, 1): [['s']],     # blasterGun
    (104, 1): [['s']],                       # blink (life bar)
    (65, 1): [['s']], (322, 1): [['s']], (64, 1): [['s']], (321, 1): [['s']],   # burners
    (217, 14): [['s']],                      # kunaiFX
    (437, 1): [['s']],                       # robot1 (grabbers)
    (370, 35): [['g', 8, 1]],                # sentRun: gotoAndPlay("loop")
    (210, 22): [['s']],                      # slash3
}

E = C.Exporter(G, SRC, '', CUSTOM)
E.code_for = {437: ('wr', 'wl')}
HERO_SUBS = (249, 268, 292, 298, 301, 304)
FX_SUBS = (125, 132, 141, 151, 154, 172, 184, 195, 202, 210, 217)
E.strategy_for = {s: 'flat' for s in HERO_SUBS + FX_SUBS + (321, 322, 369, 370, 437)}
E.clip_res = [0.5, 1.0]
E.white_solid = True   # the targetExplode fx: a nested clip solid orange on some frames

meta = {}

# ---------------------------------------------------------------- clips played by the code
E.export(305, 'hero', code=('smc',), res=0.5, white=True)
E.export(218, 'movefx', code=('smc',), res=0.5)
E.export(328, 'danger', code=('smc',), frames=[1, 2], res=0.5)
E.export(438, 'grabbers', code=('smc',), res=0.5)
E.export(402, 'swarm', res=1.0, white=True)
E.export(371, 'sentinel', code=('smc',), res=0.5)
E.export(107, 'lifebar', code=('_blink',), res=0.5)

K = C.K
pivots = E.pivots
area = E.area


def save_anim(name, imgs, reg):
    E.write_anim(name, imgs, reg)


# ---------------------------------------------------------------- flatten (mt.deepnight.Lib.flatten)
def cmds_of(Gx, sid, frame=1, ctrl=None, M=R.IDENT, cx=R.NOCX):
    ct = {sid: frame, '__noactions__': True}
    if ctrl:
        ct.update(ctrl)
    inst = R.Instance(Gx, sid, ctrl=ct)
    out = []
    R.Renderer(Gx, 1).collect(inst, M, cx, set(), out)
    return out


def bounds_of(Gx, cmds):
    return R.Renderer(Gx, 1).bounds(cmds)


def draw_at(cmds, x0, y0, w, h, scale=1.0):
    """picture of w x h output pixels whose pixel (0, 0) is the world point (x0, y0), at `scale` px per world unit"""
    Z = G.Z
    rd = R.Renderer(G, scale)
    zs = Z / scale
    canvas = np.zeros((int(round(h * zs)), int(round(w * zs)), 4), dtype=np.float32)
    rd.draw(cmds, canvas, (x0, y0))
    im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
    if zs != 1:
        im = im.resize((w, h), Image.LANCZOS)
    return im.convert('RGBA')


def flatten(sid, frame=1, ctrl=None):
    """(image, bounds x, bounds y) like flatten(mc): ceil(bounds) pixels, pixel (0, 0) at the bounds top left"""
    cm = cmds_of(G, sid, frame, ctrl)
    b = bounds_of(GM, cmds_of(GM, sid, frame, ctrl))     # bounds count the _hit boxes too
    if b is None:
        return Image.new('RGBA', (1, 1)), 0.0, 0.0
    w = int(math.ceil(b[2] - b[0]))
    h = int(math.ceil(b[3] - b[1]))
    return draw_at(cm, b[0], b[1], max(1, w), max(1, h)), b[0], b[1]


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    pivots[name] = list(pivot)
    area[name] = sum(im.width * im.height for im in imgs)


def single(name, im):
    """one picture per animation, drawn from its top left corner"""
    write_images(name, [im])
    return [im.width, im.height]


# ---------------------------------------------------------------- platforms, props, walls (Data.new)
tiles = {'plat': [], 'props': [], 'walls': []}
for p in range(1, 6):
    # tilesSrc.gotoAndStop('p<n>'): the last child (smc) frame by frame, frames 1 .. totalFrames - 1
    inst = R.Instance(GM, 553, ctrl={553: p, '__noactions__': True})
    smc = inst.display[max(inst.display)]['inst']
    sd = GM.sprites[smc.sid]
    labs = sorted(sd.labels.items(), key=lambda kv: kv[1])
    corner, mid = [], []
    for f in range(1, sd.nframes):
        lab = None
        for nm, fr in labs:
            if fr <= f:
                lab = nm
        im, bx, by = flatten(smc.sid, f)
        key = 'pc%d_%d' % (p, f)
        single(key, im)
        if lab == 'start':
            corner.append(dict(a=key, w=im.width, h=im.height))
        elif lab == 'body':
            mid.append(dict(a=key, w=im.width, h=im.height, ofsY=round(by, 3)))
    tiles['plat'].append(dict(corner=corner, mid=mid))
for f in range(1, GM.sprites[545].nframes + 1):
    im, bx, by = flatten(545, f)
    tiles['props'].append(dict(a='prop%d' % f, w=im.width, h=im.height))
    single('prop%d' % f, im)
for f in range(1, GM.sprites[552].nframes + 1):
    im, bx, by = flatten(552, f)
    tiles['walls'].append(dict(a='wall%d' % f, w=im.width, h=im.height))
    single('wall%d' % f, im)
meta['tiles'] = tiles
print('tiles', json.dumps({k: [(len(v['corner']), len(v['mid'])) for v in tiles['plat']] if k == 'plat' else len(tiles[k]) for k in tiles}))
for t in tiles['plat']:
    print('  corner', [(c['w'], c['h']) for c in t['corner']], 'mid', [(c['w'], c['h']) for c in t['mid']])

# ---------------------------------------------------------------- background planes
planes = {}


def plane(key, sid, frames):
    out = []
    for f in frames:
        im, bx, by = flatten(sid, f)
        nm = '%s%d' % (key, f)
        single(nm, im)
        out.append(dict(a=nm, w=im.width, h=im.height, x=round(bx, 3), y=round(by, 3)))
    planes[key] = out


plane('plan1', 478, range(1, 4))
plane('plan2', 558, range(1, 5))
plane('plan3', 562, range(1, 4))
plane('plan4', 567, range(1, 5))
plane('bg', 573, [1])
plane('moodp4', 571, [1])
plane('moodp2', 569, [1])
# _width / _height of each Plan4 frame (Level.makeMate reads them before going to the next detail)
planes['plan4dims'] = []
for f in range(1, 5):
    b = bounds_of(GM, cmds_of(GM, 567, f))
    planes['plan4dims'].append([round(b[2] - b[0], 4), round(b[3] - b[1], 4)])
meta['planes'] = planes

# ---------------------------------------------------------------- the saw blade: McCache of Danger frame 3 (smc)
blade = []
bimgs = []
for f in range(1, GM.sprites[325].nframes + 1):
    cm = cmds_of(GM, 325, f)
    b = bounds_of(GM, cm)
    w = int(math.ceil(b[2] - b[0]))
    h = int(math.ceil(b[3] - b[1]))
    # _hit.getRect(mc)
    inst = R.Instance(GM, 325, ctrl={325: f, '__noactions__': True})
    hr = None
    for d, e in inst.display.items():
        if e['name'] == '_hit':
            hr = rect_of = None
            sub = []
            R.Renderer(GM, 1).collect(e['inst'], e['matrix'], R.NOCX, set(), sub)
            hb = bounds_of(GM, sub)
            hr = [round(hb[0], 4), round(hb[1], 4), round(hb[2] - hb[0], 4), round(hb[3] - hb[1], 4)]
    blade.append(dict(bx=round(b[0], 4), by=round(b[1], 4), w=w, h=h, hit=hr))
    bimgs.append(cmds_of(G, 325, f))
imgs, reg = E.render(bimgs, 1.0, margin=1)
save_anim('blade', imgs, reg)
meta['blade'] = blade

# ---------------------------------------------------------------- _hit rectangles of the enemies (getRect)


def hit_rect_in(inst, M):
    """rectangle of the _hit box of an instance (searched in it and in its smc) in the space of M"""
    for d, e in sorted(inst.display.items()):
        if e['name'] == '_hit':
            sub = []
            R.Renderer(GM, 1).collect(e['inst'], R.mat_mul(M, e['matrix']), R.NOCX, set(), sub)
            hb = bounds_of(GM, sub)
            return [round(hb[0], 4), round(hb[1], 4), round(hb[2] - hb[0], 4), round(hb[3] - hb[1], 4)]
    return None


def hits_of(sid, frame, sub_frames):
    """[_hit rect of the clip for each frame of its smc] (or the clip's own _hit)"""
    inst = R.Instance(GM, sid, ctrl={sid: frame, '__noactions__': True})
    own = hit_rect_in(inst, R.IDENT)
    if own is not None:
        return own
    for d, e in sorted(inst.display.items()):
        if e['name'] == 'smc' and e['inst'] is not None:
            out = []
            for f in range(1, (sub_frames or GM.sprites[e['inst'].sid].nframes) + 1):
                si = R.Instance(GM, e['inst'].sid, ctrl={e['inst'].sid: f, '__noactions__': True})
                out.append(hit_rect_in(si, e['matrix']))
            return out
    return None


hits = {}
hits['swarm'] = [hits_of(402, f, None) for f in range(1, GM.sprites[402].nframes + 1)]
hits['grabbers'] = hits_of(438, 1, None)
hits['torch'] = [hits_of(328, 1, None), hits_of(328, 2, None)]
hits['sentinel'] = [hits_of(371, 1, None), hits_of(371, 2, None)]
meta['hits'] = hits
for k, v in hits.items():
    flat = json.dumps(v)
    print('hits', k, flat[:160])

# ---------------------------------------------------------------- power ups (lib.PowerUps, Ui.makePow)
GLOW_POW = dict(type='glow', color=(0, 0, 0, int(round(0.2 * 255))), blurX=4.0, blurY=4.0, strength=1.0, inner=False,
                knockout=False, passes=1)
GREY = dict(type='colormatrix', matrix=[0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0])
pow_rects = []
pc, pu, pg = [], [], []
for f in range(1, 7):
    cm = cmds_of(GM, 453, f)
    b = bounds_of(GM, cm)
    pow_rects.append([round(b[0], 4), round(b[1], 4), round(b[2] - b[0], 4), round(b[3] - b[1], 4)])
    sc = dict(a=0.8, b=0.0, c=0.0, d=0.8, tx=0.0, ty=0.0)
    pc.append([('layer', cmds_of(G, 453, f, M=sc), [GLOW_POW], None)])
    su = dict(a=0.6, b=0.0, c=0.0, d=0.6, tx=0.0, ty=0.0)
    pu.append(cmds_of(G, 453, f, M=su))
    pg.append([('layer', cmds_of(G, 453, f, M=su), [GREY], None)])
meta['powRects'] = pow_rects
for name, lst in (('pow', pc), ('powUi', pu), ('powGrey', pg)):
    imgs, reg = E.render(lst, 1.0, margin=1)
    save_anim(name, imgs, reg)
    if name == 'powUi':
        ui_imgs, ui_reg = imgs, reg


def orange_to_red(im):
    """the orange of an icon in red (hue 15-60 deg, saturated pixels only): the Mag Grips switched off (key G, the port)"""
    hsv = np.asarray(im.convert('RGB').convert('HSV')).astype(np.int32)
    h, s = hsv[..., 0], hsv[..., 1]
    m = (h >= 10) & (h <= 43) & (s > 60)
    hsv[..., 0] = np.where(m, 0, h)
    out = Image.fromarray(hsv.astype(np.uint8), 'HSV').convert('RGB').convert('RGBA')
    out.putalpha(im.split()[3])
    return out


save_anim('powUiRed', [orange_to_red(im) for im in ui_imgs], ui_reg)

# ---------------------------------------------------------------- hurt flash (Data.bmpHit): a black 600 x 460 rect with
# an inner red glow of 120 px (quality 1, strength 2), drawn in ADD
HW, HH = 600, 460
k = 2
a = np.ones((HH // k, HW // k), dtype=np.float32)
g = 1 - R.box_blur(np.pad(a, 60 // k), 120 / k, 120 / k, 1)[60 // k:-60 // k, 60 // k:-60 // k]
g = np.clip(g * 2, 0, 1) * 0.9
rgb = np.stack([g * 1.0, g * 7 / 255.0, g * 7 / 255.0], axis=-1)
im = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').convert('RGBA')
single('hitflash', im)

# ---------------------------------------------------------------- fonts


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
        name = body[5:5 + nl].split(b'\0')[0].decode('latin1')
        q = 5 + nl
        ng = struct.unpack_from('<H', body, q)[0]; q += 2
        wide = flags & 0x08
        base = q
        q += ng * (4 if wide else 2)
        cto = struct.unpack_from('<I' if wide else '<H', body, q)[0]
        q = base + cto
        codes = [struct.unpack_from('<H', body, q + 2 * i)[0] for i in range(ng)]
        q += 2 * ng
        if not flags & 0x80:
            continue
        asc, desc, lead = struct.unpack_from('<HHh', body, q); q += 6
        adv = struct.unpack_from('<%dh' % ng, body, q)
        out[fid] = dict(name=name, codes=codes, ascent=asc / em, descent=desc / em, leading=lead / em,
                        adv={chr(c): v / em for c, v in zip(codes, adv)})
    return out


FONTS = font_layouts(W + 'game.swf')
for fid, f in FONTS.items():
    print('font', fid, f['name'], 'glyphs', len(f['codes']), 'ascent %.3f descent %.3f' % (f['ascent'], f['descent']))
TTF = {588: W + 'fonts_game/588_galaxy.ttf', 589: W + 'fonts_game/589_trana.ttf', 467: W + 'fonts_game/467_Transponder AOE.ttf',
       455: W + 'fonts_game/455_Transponder Grid AOE.ttf'}

# the texts of the game (texts.fr.xml of the archive, in resources/hx/games/mel/Text.hx)
TEXTS = {}
for k, v in re.findall(r'\t\t"([^"]+)" => ("(?:[^"\\]|\\.)*"),', open(os.path.join(REPO, 'resources/hx/games/mel/Text.hx'), encoding='utf-8').read()):
    TEXTS[k] = json.loads(v)


def text_of(tid):
    return TEXTS[tid]


def flash_glow(color, alpha, blur, strength, inner=False, passes=1):
    r, g_, b = (color >> 16) & 255, (color >> 8) & 255, color & 255
    return dict(type='glow', color=(r, g_, b, int(round(alpha * 255))), blurX=blur, blurY=blur, strength=strength, inner=inner,
                knockout=False, passes=passes)


ORANGE_IN = flash_glow(0xff8200, 0.3, 12, 1, inner=True)          # Data.getOrangeFilter
BLACK_OUT = flash_glow(0x000000, 0.4, 4, 4)                      # Data.getOuterBlackFilter


def glyph_anim(name, fid, size, color, chars, filters=(), pad=0):
    """one picture per character (same canvas): the glyph at its pen position, baseline at the pivot"""
    lay = FONTS[fid]
    SS = 4
    font = ImageFont.truetype(TTF[fid], int(round(size * SS)))
    chars = sorted(set(c for c in chars if c in lay['adv'] and c not in '\n\r\t'))
    margin = int(math.ceil(pad)) + 2
    maxadv = max(lay['adv'][c] for c in chars) * size
    # extents of the glyph pictures
    boxes = [font.getbbox(c, anchor='ls') for c in chars]
    x0 = min(0, min(bx[0] for bx in boxes) / SS) - margin
    x1 = max(maxadv, max(bx[2] for bx in boxes) / SS) + margin
    y0 = min(-lay['ascent'] * size, min(bx[1] for bx in boxes) / SS) - margin
    y1 = max(lay['descent'] * size, max(bx[3] for bx in boxes) / SS) + margin
    w, h = int(math.ceil(x1 - x0)), int(math.ceil(y1 - y0))
    ox, oy = -math.floor(x0), -math.floor(y0)
    w, h = int(math.ceil(x1 + ox)), int(math.ceil(y1 + oy))
    rgb = ((color >> 16) & 255, (color >> 8) & 255, color & 255)
    imgs = []
    for c in chars:
        big = Image.new('L', (w * SS, h * SS), 0)
        ImageDraw.Draw(big).text((ox * SS, oy * SS), c, font=font, fill=255, anchor='ls')
        al = np.asarray(big.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
        layer = np.zeros((h, w, 4), dtype=np.float32)
        for i in range(3):
            layer[..., i] = al * rgb[i] / 255.0
        layer[..., 3] = al
        for f in filters:
            layer = R.apply_filter(layer, f, 1, inner=True)
        imgs.append(Image.fromarray(np.clip(layer * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa').convert('RGBA'))
    write_images(name, imgs, (round(ox / w, 6), round(oy / h, 6)))
    return dict(a=name, size=size, chars=''.join(chars), adv=[round(lay['adv'][c] * size, 4) for c in chars],
                ascent=round(lay['ascent'] * size, 4), descent=round(lay['descent'] * size, 4),
                leading=round(lay['leading'] * size, 4))


def chars_of(*tids):
    s = ''
    for t in tids:
        s += text_of(t)
    return s


# the arrows of fx.Init: an orange triangle (32, 0) (64, 64) (0, 64) with the filters of the words, cacheAsBitmap
SS = 4
PAD = 8
big = Image.new('L', ((64 + 2 * PAD) * SS, (64 + 2 * PAD) * SS), 0)
ImageDraw.Draw(big).polygon([((32 + PAD) * SS, PAD * SS), ((64 + PAD) * SS, (64 + PAD) * SS), (PAD * SS, (64 + PAD) * SS)], fill=255)
al = np.asarray(big.resize((64 + 2 * PAD, 64 + 2 * PAD), Image.LANCZOS)).astype(np.float32) / 255.0
layer = np.zeros(al.shape + (4,), dtype=np.float32)
for i, v in enumerate((0xff, 0x82, 0x00)):
    layer[..., i] = al * v / 255.0
layer[..., 3] = al
for f in (ORANGE_IN, BLACK_OUT):
    layer = R.apply_filter(layer, f, 1, inner=True)
im = Image.fromarray(np.clip(layer * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa').convert('RGBA')
write_images('arrow', [im], (round(PAD / im.width, 6), round(PAD / im.height, 6)))

fonts = {}
fonts['score'] =glyph_anim('fScore', 588, 10, 0xFFFFFF, chars_of('bonusTxtHit_0', 'bonusTxtHit_1', 'bonusTxtHit_2', 'bonusTxtHit_3',
                                                                  'bonusTxtHit_4') + '+0123456789', (ORANGE_IN, BLACK_OUT), 6)
fonts['big'] = glyph_anim('fBig', 588, 50, 0xff8200, chars_of('jump', 'flee_0', 'well_done'), (ORANGE_IN, BLACK_OUT), 6)
fonts['sms'] = glyph_anim('fSms', 589, 24, 0xff8200, chars_of('sms_flash', 'var_p', 'var_n', 'flee_1', 'sms_kdo'),
                          (flash_glow(0xff9900, 1.0, 5, 0.5),), 4)
fonts['tip'] = glyph_anim('fTip', 588, 8, 0xffa000, chars_of('txt_cp0', 'txt_cp1', 'txt_cp2', 'txt_cp3', 'txt_cp4'))
fonts['height'] = glyph_anim('fHeight', 467, 18, 0xddb500, '0123456789M')
for k_, v in fonts.items():
    missing = sorted(set(c for c in {'score': chars_of('bonusTxtHit_0'), 'sms': chars_of('sms_flash', 'flee_1'),
                                     'big': chars_of('jump', 'flee_0'), 'tip': chars_of('txt_cp0')}.get(k_, '') if c not in v['chars']
                         and c not in '\n\r\t|'))
    print('font %s: %d glyphs, missing %s' % (k_, len(v['chars']), ''.join(missing)))
meta['fonts'] = fonts

# ---------------------------------------------------------------- the height sign (gfx.Height): the plate and its static
# texts (black digits of Transponder Grid AOE), the _txt field drawn at run time
TG = swftext.all_edittexts(W + 'game.swf')
inst = R.Instance(G, 469, ctrl={'__noactions__': True})
plate_cmds = []
R.Renderer(G, 1).collect(inst, R.IDENT, R.NOCX, set(), plate_cmds)
b = bounds_of(GM, cmds_of(GM, 469, 1))
pad = 2
x0, y0 = math.floor(b[0]) - pad, math.floor(b[1]) - pad
w, h = int(math.ceil(b[2] - x0)) + pad, int(math.ceil(b[3] - y0)) + pad
im = draw_at(plate_cmds, x0, y0, w, h)
SS = 4
for d, e in sorted(inst.display.items()):
    t = TG.get(e['char'])
    if t is None or e['name'] == '_txt':
        continue
    txt = re.sub('<[^>]+>', '', t['text'])
    fid = t['font']
    font = ImageFont.truetype(TTF[fid], int(round(t['height'] * SS)))
    lay = FONTS[fid]
    m = e['matrix']
    px = (m['tx'] + t['bounds'][0] + 2 - x0) * SS
    py = (m['ty'] + t['bounds'][2] + 2 + lay['ascent'] * t['height'] - y0) * SS
    big = Image.new('L', (w * SS, h * SS), 0)
    ImageDraw.Draw(big).text((px, py), txt, font=font, fill=255, anchor='ls')
    al = big.resize((w, h), Image.LANCZOS)
    col = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    col.putalpha(al)
    im = Image.alpha_composite(im, col)
write_images('heightPlate', [im], (round(-x0 / w, 6), round(-y0 / h, 6)))
t = TG[468]
txtm = [e['matrix'] for e in inst.display.values() if e['name'] == '_txt'][0]
# height of the clip (DisplayObject.height): the plate and the boxes of its text fields
ys0, ys1 = [b[1]], [b[3]]
for d, e in inst.display.items():
    tt = TG.get(e['char'])
    if tt is not None:
        ys0.append(e['matrix']['ty'] + tt['bounds'][2])
        ys1.append(e['matrix']['ty'] + tt['bounds'][3])
meta['height'] = dict(fullH=round(max(ys1) - min(ys0), 3), x=round(txtm['tx'] + t['bounds'][0], 3), y=round(txtm['ty'] + t['bounds'][2], 3),
                      w=round(t['bounds'][1] - t['bounds'][0], 3), h=round(t['bounds'][3] - t['bounds'][2], 3),
                      bounds=[round(b[0], 3), round(b[1], 3), round(b[2] - b[0], 3), round(b[3] - b[1], 3)])

# ---------------------------------------------------------------- the title (gfx.Title: the logo, for the start screen)
im, bx, by = flatten(80, 1)
im.save(os.path.join(OUT, 'title.png'))

# ---------------------------------------------------------------- hero: height of the clip on each label (Bonus.onProc
# places the score at char.mc.height + 50 above Mel: the bounds of the current smc frame, frame 1 here)
hh = {}
for f, lab in enumerate(['stand', 'walk', 'jump', 'doubleJump', 'grip', 'crouch']):
    b = bounds_of(GM, cmds_of(GM, 305, f + 1))
    hh[lab] = round(b[3] - b[1], 3)
meta['heroHeight'] = hh

# ---------------------------------------------------------------- level design (Data.ldBmp: BmpLd = gfx/ld.png)
ld = Image.open(W + 'img_game/587_BmpLd_.png').convert('RGBA')
la = np.asarray(ld).astype(np.int64)
rgb = (la[..., 0] << 16) | (la[..., 1] << 8) | la[..., 2]
rgb[la[..., 3] == 0] = 0          # getPixel of a transparent pixel (premultiplied): 0
meta['ld'] = dict(w=ld.width, h=ld.height)
np.save(os.path.join(OUT, 'ld.npy'), rgb.astype(np.int32))

json.dump(E.clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
tot = sum(area.values())
print('clips %d, anims %d, area %.2f Mpx, warnings %d' % (len(E.clips), len(area), tot / 1e6, E.warnings))
for k_, v in sorted(area.items(), key=lambda x: -x[1])[:25]:
    print('  %-24s %8d px' % (k_, v))
