"""Builds the Trigo graphics for KadoKadeo from gfx.swf of the Arkadeo game (Arkadeo/games/trigo/swf).

Trigo is drawn at 1 canvas pixel per Flash pixel (the Arkadeo game area: 600 x 460), so the textures are at 1 px per Flash
pixel (clipexport res 0.5, K = 2), from the FFDec export of the shapes at zoom 4.
  - the symbols the League shows are Clip timelines (clipexport.py) named after their AS3 class (gfx.*), with the frame
    scripts of their classes: Blocks (a block, frames 1-5: the 5 colours, its `_blink` sparkle and `_hili` highlight,
    both added (blend mode "add")), Blocks2 (a block of a triangle made, its `_hili`), Clock (`_clock` and its `_col`
    disk, the `_time` hand of 180 frames with its drop shadow), ComboMeter (its `_txt`: gfx_fla.comboTXT_20, 22 frames,
    the `_current` / `_next` boxes of the number), Part (the particles);
  - the texts of the timelines (the "x" and "combo" of comboTXT, Fredoka One embedded) are drawn from the font of the
    SWF (swffont) and composed with their filters like shapes;
  - what the original flattened into bitmaps (Game.flatten of a Blocks / Blocks2: the block on its colour frame, its
    `_blink` and `_hili` hidden) is drawn at the size flatten gave it: ceil(bounds), pixel (0, 0) = bounds top left (the
    bounds count the hidden children, like AS3 getBounds), the bounds kept for the game;
  - the decor: gfx.BG and gfx.Board at (5, 5) in one picture (they never move); gfx.Render, the paper drawn over the
    whole game with the blend mode OVERLAY, as its own picture (the game applies it with arkadeo.OverlayLayer);
  - the number of the combo meter (the `_txt` field of `_current` / `_next`: Fredoka One 120, orange, centred, three
    drop shadows): the glyphs of the digits with the filters of the field baked;
  - the texts of Game.showText (a TextField in the device font "arial", bold, 18 to 24): the glyphs of the system Arial
    Bold, white (tinted by the game: textColor and the colours of the RainbowCombo);
  - gfx.Logo for the start screen.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: trigo_assets.py <out dir>      env: ARIAL_BOLD (default C:/Windows/Fonts/arialbd.ttf)
"""
import os, sys, json, shutil, math, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import swfrender as R
import clipexport as C
import swftext
import swffont

# gfx.swf + FFDec exports (sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/trigo trigo gfx)
W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'trigo', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)
ARIAL_BOLD = os.environ.get('ARIAL_BOLD', 'C:/Windows/Fonts/arialbd.ttf')

G = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)
G.flash_replace = True
G.overlay = True          # the icon and the gloss of a block (blend mode OVERLAY)
G.inner_filters = True    # the inner drop shadows of the icons and of the texts

# symbols (SymbolClass of gfx.swf)
BG, BOARD, RENDER, CLOCK, COMBO, BLOCKS, BLOCKS2, PART, LOGO = 114, 69, 38, 98, 83, 67, 57, 111, 37
COMBOTXT, NUMBOX = 81, 77
FONT = 3                  # Fredoka One

FONTS = swffont.read_fonts(W + 'gfx.swf')
FRED = FONTS[FONT]
STEXTS = swffont.read_texts(W + 'gfx.swf')
ETEXTS = swftext.all_edittexts(W + 'gfx.swf')
Z = G.Z


# ---------------------------------------------------------------- texts of the timelines, drawn like shapes
def glyphs_image(items, size, rgba):
    """glyphs [(index, pen x, pen y)] in Flash pixels at `size` px: (image at zoom Z, x0, y0 of its pixel (0, 0))"""
    parts = []
    for gi, px, py in items:
        im, ox, oy = swffont.render_glyph_index(FRED, gi, size * Z, rgba)
        parts.append((im, px * Z - ox, py * Z - oy))
    X0 = int(math.floor(min(x for _, x, _ in parts)))
    Y0 = int(math.floor(min(y for _, _, y in parts)))
    X1 = int(math.ceil(max(x + im.width for im, x, _ in parts)))
    Y1 = int(math.ceil(max(y + im.height for im, _, y in parts)))
    canvas = Image.new('RGBA', (X1 - X0, Y1 - Y0), rgba[:3] + (0,))
    for im, x, y in parts:
        canvas.alpha_composite(im, (int(round(x - X0)), int(round(y - Y0))))
    return canvas, X0 / Z, Y0 / Z


def inject(cid, img, x0, y0):
    """a character of the SWF drawn by this script, placed like a shape (its picture at zoom Z from (x0, y0))"""
    G.shapes[cid] = [x0, x0 + img.width / Z, y0, y0 + img.height / Z]
    G._shape_cache[cid] = img


def static_text(cid):
    """DefineText: its records, pen at (x, y) of each record, advances of the record"""
    t = STEXTS[cid]
    m = t['matrix']
    assert (m['a'], m['b'], m['c'], m['d']) == (1.0, 0.0, 0.0, 1.0), m
    items, size, rgba = [], None, None
    for r in t['records']:
        assert r['font'] == FONT
        size, rgba = r['height'], tuple(r['color'][:3]) + (255,)
        x = r['x']
        for gi, adv in r['glyphs']:
            items.append((gi, m['tx'] + x, m['ty'] + r['y']))
            x += adv
    inject(cid, *glyphs_image(items, size, rgba))


def field_layout(t, s, size):
    """Flash's layout of a single line field: 2 px gutter, first baseline at 2 + ascent; [(glyph index, pen x)], width"""
    k = size / float(FRED['em'])
    gis = [FRED['codes'].index(ord(c)) for c in s]
    tw = sum(FRED['advances'][g] * k for g in gis)
    x0, x1 = t['bounds'][0], t['bounds'][1]
    if t.get('align') == 'center':
        x = x0 + 2 + ((x1 - x0 - 4) - tw) / 2
    elif t.get('align') == 'right':
        x = x1 - 2 - tw
    else:
        x = x0 + 2 + t.get('leftMargin', 0)
    out = []
    for g in gis:
        out.append((g, x))
        x += FRED['advances'][g] * k
    return out, tw


def edit_text(cid):
    """DefineEditText with a fixed html text (<font size color>): its text laid out like Flash"""
    t = ETEXTS[cid]
    html = t['text']
    s = re.sub(r'<[^>]+>', '', html).replace('&nbsp;', ' ')
    fs = re.search(r'size="(\d+)"', html)
    fc = re.search(r'color="#([0-9a-fA-F]{6})"', html)
    size = float(fs.group(1)) if fs else t['height']
    col = int((fc.group(1) if fc else t['color'][1:]), 16)
    rgba = ((col >> 16) & 255, (col >> 8) & 255, col & 255, 255)
    k = size / float(FRED['em'])
    base = t['bounds'][2] + 2 + FRED['ascent'] * k
    lay, _ = field_layout(t, s, size)
    inject(cid, *glyphs_image([(g, x, base) for g, x in lay], size, rgba))


for cid in (74, 79):            # "x" of comboTXT (orange; yellow on its frames 16 to 20)
    static_text(cid)
for cid in (75, 78, 80):        # "combo" of comboTXT (_txt2: orange; yellow on its frames 14 to 17)
    edit_text(cid)

# frame scripts of the AS3 classes (decompiled gfx_fla.*: addFrameScript ... stop()); the gfx.* classes have none (their
# timelines play: the code stops them)
CUSTOM = {
    (COMBOTXT, 1): [['s']], (COMBOTXT, 22): [['s']],   # comboTXT_20
    (110, 41): [['s']],                                 # vanish_8 (the third particle)
}

# _blink (the sparkle, added at 10 %) is drawn above the gloss of the block (sprite 66, blend mode OVERLAY) instead of
# under it: the overlay needs the layers under it in one picture, and a sparkle added at 10 % looks the same over or
# under a gloss
for k, v in G.sprites[BLOCKS].frames[0]:
    if k == 'place' and v.get('name') == '_blink':
        v['depth'] = 9

E = C.Exporter(G, SRC, '', CUSTOM)
E.clip_res = [0.5]
E.effects = True          # the blend mode of the nested clips (_blink, _hili, the particles) and their filters
E.shadows = True          # (with effects) the drop shadow of _time
E.code_clips = True       # the named children the code drives are clips, even with one frame (_hili, _col, _clock)
E.white_for = {87}        # _col, the disk of the clock: tinted by mt.fx.Radiate (Col.setPercentColor: multiplied + added colour)
E.code_for = {93: ('_col',), COMBOTXT: ('_current', '_next')}
# comboTXT: its texts ("x", "combo") in flat pictures, composed with their three drop shadows (a CUT picture drops them)
E.strategy_for = {COMBOTXT: 'flat'}

meta = {}

# ---------------------------------------------------------------- clips played by the code
# Blocks / Blocks2: frames 1-5 (the 5 colours; the Arkadeo prizes of frames 6-9 are not in KadoKadeo)
meta['clipNames'] = {
    'Blocks': E.export(BLOCKS, 'Blocks', code=('_blink', '_hili'), frames=[1, 2, 3, 4, 5], res=0.5),
    'Blocks2': E.export(BLOCKS2, 'Blocks2', code=('_hili',), frames=[1, 2, 3, 4, 5], res=0.5),
    'Clock': E.export(CLOCK, 'Clock', code=('_clock', '_time'), res=0.5),
    'ComboMeter': E.export(COMBO, 'ComboMeter', code=('_txt',), res=0.5),
    'Part': E.export(PART, 'Part', res=0.5),
}
print('clips', len(E.clips), 'warnings', E.warnings)


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    E.pivots[name] = [round(pivot[0], 6), round(pivot[1], 6)]
    E.area[name] = sum(im.width * im.height for im in imgs)


def cmds_of(sid, frame=1, ctrl=None, M=R.IDENT, cx=R.NOCX, hide=()):
    ct = {sid: frame, '__noactions__': True}
    if ctrl:
        ct.update(ctrl)
    out = []
    R.Renderer(G, 1).collect(R.Instance(G, sid, ctrl=ct), M, cx, set(hide), out)
    return out


def draw_at(cmds, x0, y0, w, h):
    """picture of w x h pixels whose pixel (0, 0) is the world point (x0, y0), at 1 px per world unit"""
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


# ---------------------------------------------------------------- Game.flatten of a block (its picture at rest)
# Blocks (colour frame id + 1, _blink stopped on its frame 1 and hidden, _hili hidden) then Blocks2 (_hili hidden):
# flatten draws ceil(width) x ceil(height) pixels from the top left of the bounds (the hidden children count in AS3
# getBounds, the drop shadows of the icon are cut there), the Bitmap placed at the bounds
BLK = []
blk_imgs = []
for sid in (BLOCKS, BLOCKS2):
    for f in (1, 2, 3, 4, 5):
        x0, y0, x1, y1 = shape_bounds(cmds_of(sid, f, {'_blink': 1}))
        w, h = int(math.ceil(x1 - x0)), int(math.ceil(y1 - y0))
        blk_imgs.append(draw_at(cmds_of(sid, f, {'_blink': 1}, hide=('_blink', '_hili')), x0, y0, w, h))
        BLK.append([round(x0, 4), round(y0, 4)])
write_images('blk', blk_imgs, (0, 0))
meta['blk'] = BLK

# ---------------------------------------------------------------- decor: gfx.BG + gfx.Board at (5, 5), 600 x 460
decor = cmds_of(BG, 1) + cmds_of(BOARD, 1, M=dict(R.IDENT, tx=5.0, ty=5.0))
write_images('decor', [draw_at(decor, 0, 0, 600, 460)], (0, 0))
# gfx.Render: the paper over the whole game (blend mode OVERLAY, applied by the game)
write_images('render', [draw_at(cmds_of(RENDER, 1), 0, 0, 600, 460)], (0, 0))

# ---------------------------------------------------------------- the number of the combo meter
# the `_txt` field (edittext 76) of the _current / _next boxes (sprite 77): Fredoka One 120, orange, centred in its
# box, at (2, 2) in the box; the glyphs of the digits with the three drop shadows of the field baked
fld = [v for k, v in G.sprites[NUMBOX].frames[0] if k == 'place' and v.get('name') == '_txt'][0]
t = ETEXTS[fld['char']]
NSIZE = 120.0
ncol = int(re.search(r'color="#([0-9a-fA-F]{6})"', t['text']).group(1), 16)
nrgb = ((ncol >> 16) & 255, (ncol >> 8) & 255, ncol & 255, 255)
kf = NSIZE / float(FRED['em'])
DIG = '0123456789'
PAD = 12
nglyphs = []
for c in DIG:
    gi = FRED['codes'].index(ord(c))
    im, ox, oy = swffont.render_glyph_index(FRED, gi, NSIZE * Z, nrgb)
    w = int(math.ceil(im.width / Z)) + 2 * PAD
    h = int(math.ceil(im.height / Z)) + 2 * PAD
    big = Image.new('RGBA', (w * Z, h * Z), nrgb[:3] + (0,))
    big.paste(im, (PAD * Z, PAD * Z))
    small = big.resize((w, h), Image.LANCZOS)
    a = np.asarray(small).astype(np.float32) / 255
    layer = np.concatenate([a[..., :3] * a[..., 3:4], a[..., 3:4]], axis=-1)
    for f in fld.get('filters') or []:
        layer = R.apply_filter(layer, f, 1)
    img = Image.fromarray(np.clip(layer * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa').convert('RGBA')
    # pen origin of the glyph in the picture
    nglyphs.append((img, PAD + ox / Z, PAD + oy / Z))
gw = int(math.ceil(max(im.width - px for im, px, _ in nglyphs) + max(px for _, px, _ in nglyphs)))
gh = int(math.ceil(max(im.height - py for im, _, py in nglyphs) + max(py for _, _, py in nglyphs)))
PX = max(px for _, px, _ in nglyphs)
PY = max(py for _, _, py in nglyphs)
imgs = []
for im, px, py in nglyphs:
    c = Image.new('RGBA', (gw, gh), (0, 0, 0, 0))
    c.alpha_composite(im, (int(round(PX - px)), int(round(PY - py))))
    imgs.append(c)
write_images('fNum', imgs, (PX / gw, PY / gh))
FONTDEFS = {'num': dict(a='fNum', size=NSIZE, chars=DIG,
                        adv=[round(FRED['advances'][FRED['codes'].index(ord(c))] * kf, 4) for c in DIG],
                        ascent=round(FRED['ascent'] * kf, 4), descent=round(FRED['descent'] * kf, 4),
                        leading=t.get('leading', 0))}
meta['num'] = dict(x=fld['matrix']['tx'], y=fld['matrix']['ty'], bounds=t['bounds'], color=ncol)
print('number field at', (fld['matrix']['tx'], fld['matrix']['ty']), 'box', t['bounds'], 'filters',
      [f['type'] for f in fld.get('filters') or []])

# ---------------------------------------------------------------- the texts of Game.showText: device font "arial", bold
# Flash lays out a device font with the metrics of the system font: the glyphs of Arial Bold at each size the game
# uses (points: 17 + ceil(min(pts / 10000, 7)) = 18 to 24, "Combo +1": 18, "UniCombo" / "RainbowCombo": 22), white
# (tinted by the game), the pen on the baseline at the pivot; the white glow of the texts is drawn by the game
CHARS = '0123456789 +CURabimnow'
G_PAD = 2
for size in range(18, 25):
    pil = ImageFont.truetype(ARIAL_BOLD, size * 8)     # 8x: the advances and metrics to 1/8 px

    def adv(c):
        return pil.getlength(c) / 8

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
    name = 'fA%d' % size
    write_images(name, imgs, (G_PAD / gw, (G_PAD + asc) / gh))
    FONTDEFS['a%d' % size] = dict(a=name, size=size, chars=CHARS, adv=[round(adv(c), 4) for c in CHARS],
                                  ascent=round(asc, 4), descent=round(desc, 4), leading=0)
meta['fonts'] = FONTDEFS

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
