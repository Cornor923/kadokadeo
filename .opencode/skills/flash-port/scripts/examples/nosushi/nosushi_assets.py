"""Builds the NosuShi graphics for KadoKadeo from gfx.swf of the Arkadeo game (Arkadeo/games/nosushi/swf).

NosuShi is drawn at 1 canvas pixel per Flash pixel (the Arkadeo game area: 600 x 460), so the textures are at 1 px per
Flash pixel (clipexport res 0.5, K = 2), from the FFDec export of the shapes at zoom 4.
  - the symbols the League uses are Clip timelines (clipexport.py) named after their AS3 class (gfx.*), with the frame
    scripts of their classes (stop): Bloc (the food, its `_block` that breaks and its `_bonus` icon, with white
    silhouettes for the colour of the blinking bombs), Bonus (the icon that flies away), Plate (its `_order`: the food
    falling on the plate), Explode (the blast of a bomb);
  - the colour matrix of the brochette's `_block` (x 1.12 - 7.62: a colour transform) is baked in its pictures;
  - what the original flattened into bitmaps (Game.flatten of a Bloc: its `_block` on frame 1, its `_bonus` icon) is
    drawn at the size flatten gave it: ceil(bounds), pixel (0, 0) = bounds top left, the bounds kept for the game;
  - the decor: gfx.Bg on its League frame (2) and gfx.Plateau composed together (the multiply / overlay layers of the
    Plateau blend with the Bg under it, they never move);
  - the moves counter (the `_moves` field of gfx.Bg, ZapfChancery 70 embedded, centred, glow + drop shadow): its 21
    values (0 to 20) laid out like Flash and drawn with their filters;
  - the points (a TextField in the device font "arial", bold 18): the glyphs of the system Arial Bold, white (tinted by
    the game);
  - gfx.Logo for the start screen.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: nosushi_assets.py <out dir>      env: ARIAL_BOLD (default C:/Windows/Fonts/arialbd.ttf)
"""
import os, sys, json, shutil, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import swfrender as R
import clipexport as C
import swftext
import swffont

# gfx.swf + FFDec exports (sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/nosushi nosushi gfx)
W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'nosushi', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)
ARIAL_BOLD = os.environ.get('ARIAL_BOLD', 'C:/Windows/Fonts/arialbd.ttf')

G = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)
G.flash_replace = True
G.overlay = True        # the overlay layer of gfx.Plateau
G.mask_blend = True     # its multiply / overlay layers under masks blend with the Bg under them
G.blur_filter = True    # the BlurFilters of the timelines (the shadow of the Plateau, the dust of Explode, the orders)

# symbols (SymbolClass of gfx.swf)
BG, BLOC, BONUS, PLATEAU, PLATE, EXPLODE, LOGO = 281, 268, 209, 195, 126, 42, 284
BROCHETTE = 226

# the colour matrix on the brochette's _block (Bloc frame 1): x 1.12 - 7.62 on r, g, b = a colour transform, baked
for k, v in G.sprites[BLOC].frames[0]:
    if k == 'place' and v.get('char') == BROCHETTE:
        m = v['filters'][0]['matrix']
        assert v['filters'][0]['type'] == 'colormatrix' and m[1] == 0 and m[0] == m[6] == m[12] and m[18] == 1
        v['filters'] = []
        v['cx'] = dict(mult=[m[0], m[6], m[12], 1.0], add=[m[4], m[9], m[14], 0.0])

# frame scripts of the AS3 classes (decompiled gfx.* / gfx_fla.*: addFrameScript ... stop())
CUSTOM = {
    (BLOC, 1): [['s']], (BLOC, 2): [['s']], (BLOC, 3): [['s']], (BLOC, 4): [['s']],
    (BONUS, 1): [['s']],
    (PLATE, 1): [['s']],
    (85, 1): [['s']], (107, 1): [['s']], (125, 1): [['s']],         # plat_96, sushiOrder_99, ramenOrder_100
    (BROCHETTE, 1): [['s']], (243, 1): [['s']], (265, 1): [['s']],  # brochette_8, sushi_25, ramenBox_34
    (41, 25): [['s']],                                              # Explode_111
    (11, 1): [['s']], (11, 2): [['s']], (11, 3): [['s']], (11, 4): [['s']],     # cendre_112
    (31, 7): [['s']],                                               # dust_113
}
for sid in (81, 106, 113):                                          # brochetteHd_58, sushiHd_75, ramenHd_101
    for f in (1, 18, 36, 54, 71):
        CUSTOM[(sid, f)] = [['s']]
for f in (1, 19, 37, 55, 72):                                       # ramenHdBox_86
    CUSTOM[(181, f)] = [['s']]

E = C.Exporter(G, SRC, '', CUSTOM)
E.clip_res = [0.5]

meta = {}

# ---------------------------------------------------------------- clips played by the code
# Bloc: frames 1-3 (brochette, sushi, ramen; the stone of the LvUP is not in the League), _bonus on its frames 1-5
# (B_None, B_Dynamite, B_Bombe, B_MorePlay, B_X2: the Arkadeo prizes are not ported)
E.frames_for = {BONUS: [1, 2, 3, 4, 5]}
# (the clip of a symbol already exported as a nested clip keeps that name: meta['clipNames'])
meta['clipNames'] = {
    'Bloc': E.export(BLOC, 'Bloc', code=('_block', '_bonus'), frames=[1, 2, 3], res=0.5, white=True),
    'Bonus': E.export(BONUS, 'Bonus', frames=[1, 2, 3, 4, 5], res=0.5, white=True),
    'Plate': E.export(PLATE, 'Plate', code=('_order',), res=0.5),
    'Explode': E.export(EXPLODE, 'Explode', res=0.5),
}
print('clips', len(E.clips), 'warnings', E.warnings)

K = C.K


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    E.pivots[name] = [round(pivot[0], 6), round(pivot[1], 6)]
    E.area[name] = sum(im.width * im.height for im in imgs)


def cmds_of(sid, frame=1, ctrl=None, M=R.IDENT, cx=R.NOCX):
    ct = {sid: frame, '__noactions__': True}
    if ctrl:
        ct.update(ctrl)
    out = []
    R.Renderer(G, 1).collect(R.Instance(G, sid, ctrl=ct), M, cx, set(), out)
    return out


def draw_at(cmds, x0, y0, w, h):
    """picture of w x h pixels whose pixel (0, 0) is the world point (x0, y0), at 1 px per world unit"""
    Z = G.Z
    rd = R.Renderer(G, 1)
    canvas = np.zeros((h * Z, w * Z, 4), dtype=np.float32)
    rd.draw(cmds, canvas, (x0, y0))
    im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
    return im.resize((w, h), Image.LANCZOS).convert('RGBA')


def shape_bounds(cmds):
    """Flash's getBounds: the shapes only (the glows of the filters are not counted)"""
    def strip(cs):
        return [(c[0], strip(c[1]), []) + tuple(c[3:]) if c[0] == 'layer' else c for c in cs]
    return R.Renderer(G, 1).bounds(strip(cmds))


# ---------------------------------------------------------------- Game.flatten of a Bloc (the picture of a block at rest)
# bounds of the Bloc with its _block on frame 1 (fixe) and its _bonus on frame b; flatten draws ceil(width) x
# ceil(height) pixels from the top left of the bounds (the glow of the bonus icon is cut there, like in Flash), the
# Bitmap placed at the bounds (bmpOffset)
BLK = []
blk_imgs = []
for food in (1, 2, 3):
    for b in (1, 2, 3, 4, 5):
        cm = cmds_of(BLOC, food, {'_block': 1, '_bonus': b})
        x0, y0, x1, y1 = shape_bounds(cm)
        w, h = int(math.ceil(x1 - x0)), int(math.ceil(y1 - y0))
        blk_imgs.append(draw_at(cm, x0, y0, w, h))
        BLK.append([round(x0, 4), round(y0, 4)])
write_images('blk', blk_imgs, (0, 0))
meta['blk'] = BLK

# ---------------------------------------------------------------- decor: gfx.Bg (League) + gfx.Plateau, 600 x 460
TEXTS = swftext.all_edittexts(W + 'gfx.swf')
decor = cmds_of(BG, 2) + cmds_of(PLATEAU, 1)
write_images('decor', [draw_at(decor, 0, 0, 600, 460)], (0, 0))

# ---------------------------------------------------------------- the moves counter: bg._moves.text = leftPlay (0 - 20)
FONTS = swffont.read_fonts(W + 'gfx.swf')
mv = [v for k, v in G.sprites[BG].frames[0] if k == 'place' and v.get('name') == '_moves'][0]
t = TEXTS[mv['char']]
font = FONTS[t['font']]
size = t['height']
k_ = size / float(font['em'])
fx0, fx1, fy0, fy1 = t['bounds']
col = int(t['color'][1:], 16)
rgb = ((col >> 16) & 255, (col >> 8) & 255, col & 255, 255)
ox_, oy_ = mv['matrix']['tx'], mv['matrix']['ty']
PAD = 16
moves = []
for n in range(21):
    s = str(n)
    gis = [font['codes'].index(ord(c)) for c in s]
    tw = sum(font['advances'][g] * k_ for g in gis)
    # Flash: 2 px gutter, centred in the box, first baseline at 2 + ascent
    x = fx0 + 2 + ((fx1 - fx0 - 4) - tw) / 2
    base = fy0 + 2 + font['ascent'] * k_
    X0, Y0 = int(math.floor(ox_ + fx0)) - PAD, int(math.floor(oy_ + fy0)) - PAD
    w, h = int(math.ceil(fx1 - fx0)) + 2 * PAD, int(math.ceil(fy1 - fy0)) + 2 * PAD
    canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for g in gis:
        im, gx, gy = swffont.render_glyph_index(font, g, size, rgb)
        canvas.alpha_composite(im, (int(round(ox_ + x - X0 - gx)), int(round(oy_ + base - Y0 - gy))))
        x += font['advances'][g] * k_
    a = np.asarray(canvas).astype(np.float32) / 255
    layer = np.concatenate([a[..., :3] * a[..., 3:4], a[..., 3:4]], axis=-1)
    for f in mv.get('filters') or []:
        layer = R.apply_filter(layer, f, 1)
    im = Image.fromarray(np.clip(layer * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa').convert('RGBA')
    moves.append((im, X0, Y0))
# one canvas for the 21 values: the pivot is the stage point (0, 0)
mx0 = min(X0 for _, X0, _ in moves)
my0 = min(Y0 for _, _, Y0 in moves)
mw = max(X0 + im.width for im, X0, _ in moves) - mx0
mh = max(Y0 + im.height for im, _, Y0 in moves) - my0
imgs = []
for im, X0, Y0 in moves:
    c = Image.new('RGBA', (mw, mh), (0, 0, 0, 0))
    c.alpha_composite(im, (X0 - mx0, Y0 - my0))
    imgs.append(c)
write_images('moves', imgs, (0, 0))
meta['moves'] = [mx0, my0]
print('moves field at', (ox_, oy_), 'box', t['bounds'], 'filters', [f['type'] for f in mv.get('filters') or []])

# ---------------------------------------------------------------- the points: device font "arial", bold, 18
# Flash lays out a device font with the metrics of the system font: the glyphs of Arial Bold at 18 px, white (tinted
# by the game: textColor), the pen on the baseline at the pivot; the white glow of the points is drawn by the game
PSIZE = 18
pil = ImageFont.truetype(ARIAL_BOLD, PSIZE * 8)     # 8x: the advances and metrics to 1/8 px


def adv(c):
    return pil.getlength(c) / 8


CHARS = '0123456789'
G_PAD = 2
asc = pil.getmetrics()[0] / 8
desc = pil.getmetrics()[1] / 8
glyphs = []
for c in CHARS:
    bw = int(math.ceil(adv(c))) + 2 * G_PAD
    bh = int(math.ceil(asc + desc)) + 2 * G_PAD
    big = Image.new('L', (bw * 8, bh * 8), 0)
    ImageDraw.Draw(big).text((G_PAD * 8, (G_PAD + asc) * 8), c, font=pil, fill=255, anchor='ls')
    im = Image.new('RGBA', (bw, bh), (255, 255, 255, 0))
    im.putalpha(big.resize((bw, bh), Image.BOX))
    glyphs.append(im)
gw = max(im.width for im in glyphs)
gh = max(im.height for im in glyphs)
imgs = []
for im in glyphs:
    c = Image.new('RGBA', (gw, gh), (255, 255, 255, 0))
    c.alpha_composite(im, (0, 0))
    imgs.append(c)
write_images('fPts', imgs, (G_PAD / gw, (G_PAD + asc) / gh))
meta['fonts'] = {'pts': dict(a='fPts', size=PSIZE, chars=CHARS, adv=[round(adv(c), 4) for c in CHARS],
                             ascent=round(asc, 4), descent=round(desc, 4), leading=0)}

# ---------------------------------------------------------------- the logo (gfx.Logo, for the start screen)
cm = cmds_of(LOGO, 1)
x0, y0, x1, y1 = R.Renderer(G, 1).bounds(cm)
os.makedirs(os.path.join(OUT, 'title'), exist_ok=True)
draw_at(cm, int(math.floor(x0)) - 1, int(math.floor(y0)) - 1, int(math.ceil(x1 - x0)) + 3,
        int(math.ceil(y1 - y0)) + 3).save(os.path.join(OUT, 'title', 'logo.png'))

json.dump(E.clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(E.pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
tot = sum(E.area.values())
print('anims %d, area %.2f Mpx' % (len(E.area), tot / 1e6))
for k_, v in sorted(E.area.items(), key=lambda x: -x[1])[:20]:
    print('  %-24s %8d px' % (k_, v))
