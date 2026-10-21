"""Rock Faller (Arkadeo): pictures of the Arkadeo HTML5 port + the font of the original gfx.swf -> single images and
data for the KadoKadeo sheet.

The source pictures are the `rockfaller/web/img/content/rockfaller` folder of the Arkadeo HTML5 port: its atlas
(rockfaller-0.png / json, the symbols of gfx.swf rendered at 1 px per Flash pixel: gems, rock, tubes with their value,
plays, sparkles, vanish, mud), the Background (bg.png), the Foreground (fg.png) and the mask of its gems (fg_mask.png).
The numbers of the score are drawn with the glyphs of the font embedded in the original gfx.swf ("Alba", read by
tools/swffont.py: no FFDec needed).

usage: rockfaller_assets.py <port content folder> <gfx.swf of the original> <out folder>
writes:
  out/src/<anim>/<n>.png    the frames of the atlas animations, each animation on one canvas (its frames keep their
                            own pivot: the canvas puts every pivot on the same pixel)
  out/src/bg.png            the Background as the port frames it, cut to the game area (600 x 460, placed at (0, 0))
  out/src/fg.png            the Foreground without its gems, as the port frames it (600 x 460)
  out/src/fgGem<i>/<c>.png  the gem _g<i> of the Foreground in colour c (1-4, frames of gfx.Stone), turned and scaled
                            like in the SWF, cut by the mask of the Foreground (baked: no PIXI mask during the game)
The decor follows the framing of the Arkadeo port (its Game.hx: a scene of 600 x 480, the Background scaled 1.023 at
(-64, 0), the Foreground stretched to 600 x 480, the grid at y 50), shown from its row VIEW_Y: the 460 rows of the
Arkadeo game area, the grid at y 35 (the STAGE_Y of the original), the tubes whole under the rocky lip.
  out/src/glow/<n>.png      the white glow of a selected stone (Filt.glow of the original), baked: 1-4 the gems, 5 rock
  out/src/scoreDigit/<n>.png  digit n - 1 of gfx.Score (Alba 14 px, white), pivot on its origin
  out/src/scorePts/1.png      "pts" of gfx.Score (Alba 10 px, white), pivot on its origin
  out/src/title/1.png         "Rock Faller" in Alba (start screen only, not packed)
  out/pivots.json, out/meta.json (see rockfaller_data.py)
"""
import os, sys, json, math, shutil
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import swffont

SRC, SWF, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
# the game area of an Arkadeo game
W, H = 600, 460
# the scene of the Arkadeo port (600 x 480): Background scaled BG_SCALE at (BG_X, BG_Y), Foreground stretched to it
SCENE_W, SCENE_H = 600, 480
BG_SCALE = 1.023
BG_X, BG_Y = -64, 0
# first row of that scene shown in the game area
VIEW_Y = 15
# gfx.Stone frames of the gems of the Foreground (gotoAndStop(rand(4) + 1)): Deco 1-4
GEM_COLORS = 4
# Filt.glow(stone.mc, 1.7, 10, 0xFFFFFF) of Slot.select: a white glow a bit larger than the stone
GLOW_SCALE = 1.06
GLOW_BLUR = 2.5
# gfx.Score: edittext _text (Alba 14 px, white, centred in [-2, 62.25] x [-2, 24.8] placed at (-30.1, -14.9)) and
# the static text "pts" (Alba 10 px, at (23, 11) of the text placed at (-30.1, -1.3))
SCORE_SIZE, PTS_SIZE = 14, 10
SCORE_FIELD = dict(x=-30.1, y=-14.9, xmin=-2.0, xmax=62.25, ymin=-2.0)
PTS_ORIGIN = (-30.1 + 23.0, -1.3 + 11.0)

shutil.rmtree(os.path.join(OUT, 'src'), ignore_errors=True)
os.makedirs(os.path.join(OUT, 'src'))
pivots = {}
meta = {}


def save(img, rel):
    path = os.path.join(OUT, 'src', rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def group_canvas(name, frames):
    """frames: [(image, pivot x px, pivot y px)] -> one canvas for all, every pivot on the same pixel"""
    left = max(int(math.ceil(px)) for _, px, _ in frames)
    top = max(int(math.ceil(py)) for _, _, py in frames)
    right = max(int(math.ceil(im.width - px)) for im, px, _ in frames)
    bottom = max(int(math.ceil(im.height - py)) for im, _, py in frames)
    cw, ch = left + right, top + bottom
    for i, (im, px, py) in enumerate(frames):
        c = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        c.paste(im, (int(round(left - px)), int(round(top - py))))
        save(c, '%s/%d.png' % (name, i + 1))
    pivots[name] = [left / cw, top / ch]
    return left, top


# ---------------------------------------------------------------- atlas of the port
atlas = json.load(open(os.path.join(SRC, 'rockfaller-0.json')))
sheet = Image.open(os.path.join(SRC, atlas['meta']['image'])).convert('RGBA')
frames_of = {}
for anim, names in atlas['animations'].items():
    lst = []
    for n in names:
        f = atlas['frames'][n]
        r = f['frame']
        im = sheet.crop((r['x'], r['y'], r['x'] + r['w'], r['y'] + r['h']))
        ss, src = f['spriteSourceSize'], f['sourceSize']
        if f.get('trimmed'):
            full = Image.new('RGBA', (src['w'], src['h']), (0, 0, 0, 0))
            full.paste(im, (ss['x'], ss['y']))
            im = full
        a = f.get('anchor', {'x': 0.5, 'y': 0.5})
        lst.append((im, a['x'] * im.width, a['y'] * im.height))
    frames_of[anim] = lst
    group_canvas(anim, lst)
print('atlas: %d animations, %d frames' % (len(frames_of), sum(len(v) for v in frames_of.values())))

# ---------------------------------------------------------------- Background, Foreground
def resized(im, w, h):
    # (premultiplied: no dark fringe on the transparent edges)
    return im.convert('RGBa').resize((w, h), Image.BILINEAR).convert('RGBA')


def view(scene):
    return scene.crop((0, VIEW_Y, W, VIEW_Y + H))


bg = Image.open(os.path.join(SRC, 'bg.png')).convert('RGBA')
scene = Image.new('RGBA', (SCENE_W, SCENE_H), (0, 0, 0, 0))
b = resized(bg, round(bg.width * BG_SCALE), round(bg.height * BG_SCALE))
scene.paste(b, (BG_X, BG_Y), b)
save(view(scene), 'bg.png')
pivots['bg'] = [0, 0]
fg = Image.open(os.path.join(SRC, 'fg.png')).convert('RGBA')
save(view(resized(fg, SCENE_W, SCENE_H)), 'fg.png')
pivots['fg'] = [0, 0]

# the gems of the Foreground (_g0.._g4): the Deco frame turned / scaled by its matrix, times the mask (alpha x red)
mask = np.array(Image.open(os.path.join(SRC, 'fg_mask.png')).convert('RGBA')).astype(np.float64)
mask = (mask[..., 0] / 255.0) * (mask[..., 3] / 255.0)
mask = np.pad(mask, ((0, max(0, SCENE_H - mask.shape[0])), (0, max(0, SCENE_W - mask.shape[1]))))[:SCENE_H, :SCENE_W]


def place(im, px, py, x, y, scale, rot):
    """`im` (pivot px, py) drawn in the scene at (x, y), scaled and turned (degrees): premultiplied bilinear"""
    a = math.radians(rot)
    ca, sa = math.cos(a) * scale, math.sin(a) * scale
    # scene -> image: inverse of [ca -sa; sa ca] then + pivot
    det = ca * ca + sa * sa
    ia, ib, ic, id_ = ca / det, sa / det, -sa / det, ca / det
    arr = np.array(im).astype(np.float64)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    pre = Image.fromarray(arr.clip(0, 255).astype(np.uint8), 'RGBA')
    coeffs = (ia, ib, px - ia * x - ib * y, ic, id_, py - ic * x - id_ * y)
    out = pre.transform((SCENE_W, SCENE_H), Image.AFFINE, coeffs, resample=Image.BILINEAR)
    return np.array(out).astype(np.float64)


gems = atlas['meta'].get('fgGems', [])
meta['fgGems'] = []
for gi, gm in enumerate(gems):
    layers = []
    for c in range(GEM_COLORS):
        im, px, py = frames_of['Deco'][c]
        o = place(im, px, py, gm['x'], gm['y'], gm['scale'], gm['rot'])
        o *= mask[..., None]
        layers.append(o[VIEW_Y:VIEW_Y + H])
    alpha = np.max([l[..., 3] for l in layers], axis=0)
    ys, xs = np.nonzero(alpha > 0.5)
    if len(xs) == 0:
        print('WARN fgGem%d hidden by the mask' % gi)
        continue
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    for c, l in enumerate(layers):
        l = l[y0:y1, x0:x1].copy()
        a = l[..., 3:4]
        rgb = np.where(a > 0, l[..., :3] * 255.0 / np.maximum(a, 1e-6), 0)
        img = np.concatenate([rgb, a], axis=2).clip(0, 255).round().astype(np.uint8)
        save(Image.fromarray(img, 'RGBA'), 'fgGem%d/%d.png' % (gi, c + 1))
    pivots['fgGem%d' % gi] = [0, 0]
    meta['fgGems'].append([int(x0), int(y0)])

# ---------------------------------------------------------------- glows of the selection
glows = [frames_of['G%d' % i][0] for i in range(4)] + [frames_of['Rock'][0]]
gl = []
for im, px, py in glows:
    pad = 8
    sw, sh = int(math.ceil(im.width * GLOW_SCALE)), int(math.ceil(im.height * GLOW_SCALE))
    sil = im.split()[3].resize((sw, sh), Image.BILINEAR)
    c = Image.new('L', (sw + 2 * pad, sh + 2 * pad), 0)
    c.paste(sil, (pad, pad))
    c = c.filter(ImageFilter.GaussianBlur(GLOW_BLUR))
    g = Image.new('RGBA', c.size, (255, 255, 255, 0))
    g.putalpha(c)
    gl.append((g, pad + px * GLOW_SCALE, pad + py * GLOW_SCALE))
group_canvas('glow', gl)

# ---------------------------------------------------------------- gfx.Score in the font of the SWF
fonts = swffont.read_fonts(SWF)
alba = [f for f in fonts.values() if f['name'] == 'Alba'][0]
k = SCORE_SIZE / alba['em']
digits = []
for d in '0123456789':
    img, ox, oy = swffont.render_glyph(alba, d, SCORE_SIZE)
    digits.append((img, ox, oy))
group_canvas('scoreDigit', digits)
pts = []
x = 0.0
canvas = Image.new('RGBA', (40, 20), (0, 0, 0, 0))
for ch in 'pts':
    img, ox, oy = swffont.render_glyph(alba, ch, PTS_SIZE)
    canvas.alpha_composite(img, (int(round(4 + x - ox)), int(round(14 - oy))))
    x += alba['advances'][swffont.glyph_index(alba, ch)] * PTS_SIZE / alba['em']
group_canvas('scorePts', [(canvas.crop(canvas.getbbox()), 4 - canvas.getbbox()[0], 14 - canvas.getbbox()[1])])
f = SCORE_FIELD
meta['score'] = {
    'advances': [round(alba['advances'][swffont.glyph_index(alba, d)] * k, 4) for d in '0123456789'],
    # centre of the text area (2 px gutter on each side) and baseline of the first line (gutter + ascent)
    'cx': round(f['x'] + f['xmin'] + 2 + (f['xmax'] - f['xmin'] - 4) / 2, 4),
    'baseline': round(f['y'] + f['ymin'] + 2 + alba['ascent'] * k, 4),
    'pts': [round(PTS_ORIGIN[0], 4), round(PTS_ORIGIN[1], 4)],
}

# title of the start screen (not in the sheet)
size = 64
t = Image.new('RGBA', (600, 120), (0, 0, 0, 0))
x = 0.0
for ch in 'Rock Faller':
    gi = swffont.glyph_index(alba, ch)
    if ch != ' ':
        img, ox, oy = swffont.render_glyph_index(alba, gi, size)
        t.alpha_composite(img, (int(round(20 + x - ox)), int(round(90 - oy))))
    x += alba['advances'][gi] * size / alba['em']
os.makedirs(os.path.join(OUT, 'art'), exist_ok=True)
t.crop(t.getbbox()).save(os.path.join(OUT, 'art', 'title.png'))

json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=1, sort_keys=True)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1, sort_keys=True)
print('pivots %d, fg gems %d, score %s' % (len(pivots), len(meta['fgGems']), meta['score']))
