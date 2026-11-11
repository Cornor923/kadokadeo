"""Builds the Green Witch graphics, data and sounds for KadoKadeo from the Arkadeo game folder (Arkadeo/games/greenWitch).

Green Witch draws its scene in a 300 x 230 buffer shown x2 (mt.deepnight.Buffer, UPSCALE 2) from the PNG atlases of the
original (the @:bitmap classes GfxTiles, GfxCharacters, GfxLevels): pixel art at 1 px per Flash pixel, shown x2 without
smoothing.
  - tiles.png and characters.png go whole into the sheet: the game cuts them itself (the slices of Play.new, the assets of
    levelInfos.xml copied by their coordinates into the walls), mt.deepnight.retro.SpriteLibBitmap making one texture per
    frame from the picture of the sheet (no table of coordinates repeated here);
  - levels.png (GfxLevels) is gameplay: the plans of the dungeons (one pixel per square: walls, doors, starts, assets...)
    are not read from a picture at run time but written into Data.hx (the 3 dungeons of the League: Level.createLeagueLevel
    takes the 32 x 32 at (id x 32, 32), id < 3);
  - the texts are drawn with the glyphs of the font "small" embedded in obj/greenwitchResources.swf (Play.createField: size
    16), white (tinted by the game), and the glow every field of createField gets (GlowFilter(0, 1, 2, 2, 5): a black
    outline) drawn once into pictures of the outlines, laid under the glyphs (no filter pass for the texts);
  - levelInfos.xml and the French texts (texts.fr.xml) for Data.hx;
  - the sounds (sounds/*.wav, music.mp3): mp3 files of public/assets/sound/greenwitch (lameenc; the original Arkadeo
    build had them off with -D disableSfx, the Arkadeo HTML5 port plays them).
Writes <out>/src (images), <out>/pivots.json, <out>/meta.json and <out>/sound/*.mp3.
usage: greenwitch_assets.py <archive folder Arkadeo/games/greenWitch> <out dir>
"""
import os, sys, json, shutil, wave
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image
import swffont
import swfrender as R

ARCH = sys.argv[1]
OUT = sys.argv[2]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)
pivots = {}
meta = {}


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    pivots[name] = [round(pivot[0], 6), round(pivot[1], 6)]


# ---------------------------------------------------------------- the atlases (GfxTiles, GfxCharacters), whole
ATLAS = {name: Image.open(os.path.join(ARCH, 'assets', name + '.png')).convert('RGBA') for name in ('tiles', 'characters')}

# Hero.new: the attach point of the staff in each of the 28 frames of the group "hero" (32 x 44, 7 by row from (0, 0)): the
# bounds of its magenta pixels (getColorBoundsRect(0xFFFFFFFF, 0xFFFF00FF), (0, 0) when none), the pixel at their corner
# erased from the atlas (setPixel32(..., 0x0))
chars = np.array(ATLAS['characters'])
meta['heroAttach'] = []
for f in range(28):
    fx, fy = (f % 7) * 32, (f // 7) * 44
    reg = chars[fy:fy + 44, fx:fx + 32]
    m = (reg[..., 3] == 255) & (reg[..., 0] == 255) & (reg[..., 1] == 0) & (reg[..., 2] == 255)
    ys, xs = np.nonzero(m)
    bx, by = (int(xs.min()), int(ys.min())) if len(xs) else (0, 0)
    meta['heroAttach'] += [bx, by]
    chars[fy + by, fx + bx] = (0, 0, 0, 0)
ATLAS['characters'] = Image.fromarray(chars, 'RGBA')
print('hero attach points', meta['heroAttach'])

for name, im in ATLAS.items():
    write_images(name, [im])
    print('atlas %-10s %dx%d' % (name, im.width, im.height))

# ---------------------------------------------------------------- the plans of the League dungeons (GfxLevels)
levels = Image.open(os.path.join(ARCH, 'assets', 'levels.png')).convert('RGB')
px = np.array(levels).astype(np.int64)
rgb = (px[..., 0] << 16) | (px[..., 1] << 8) | px[..., 2]
meta['league'] = []
for lid in range(3):
    plan = rgb[32:64, lid * 32:lid * 32 + 32]
    meta['league'].append([int(v) for v in plan.flatten()])
    print('league dungeon %d: %d walls' % (lid, int((plan == 0xFFFFFF).sum())))

# ---------------------------------------------------------------- the font "small" (createField), and its outline
FONTS = swffont.read_fonts(os.path.join(ARCH, 'obj', 'greenwitchResources.swf'))
BY_NAME = {f['name']: f for f in FONTS.values()}
SMALL = BY_NAME['small']
SIZE = 16
# GlowFilter(0x0, 1, 2, 2, 5) of Play.createField: a box of 2 px, strength 5, quality 1
OUTLINE = dict(type='glow', color=(0, 0, 0, 255), blurX=2, blurY=2, strength=5, passes=1)
PAD = 2


def glyph_anims(font, size):
    chars = [c for c in font['codes'] if 32 <= c < 0x10000]
    rend = [swffont.render_glyph_index(font, font['codes'].index(c), size) for c in chars]
    left = max(ox for _, ox, _ in rend) + PAD
    top = max(oy for _, _, oy in rend) + PAD
    right = max(im.width - ox for im, ox, _ in rend) + PAD
    bottom = max(im.height - oy for im, _, oy in rend) + PAD
    w, h = left + right, top + bottom
    glyphs, outlines = [], []
    for im, ox, oy in rend:
        c = Image.new('RGBA', (w, h), (255, 255, 255, 0))
        c.alpha_composite(im, (left - ox, top - oy))
        glyphs.append(c)
        # the glow alone (black, where the glyph is not): drawn under every glyph of the field
        a = np.array(c)[..., 3].astype(np.float32) / 255
        layer = np.zeros((h, w, 4), np.float32)
        layer[..., 3] = a
        g = R.apply_filter(layer, OUTLINE, 1)[..., 3] - a
        o = np.zeros((h, w, 4), np.uint8)
        o[..., 3] = np.clip(np.round(g * 255), 0, 255).astype(np.uint8)
        outlines.append(Image.fromarray(o, 'RGBA'))
    write_images('fSmall', glyphs, (left / w, top / h))
    write_images('fSmallOutline', outlines, (left / w, top / h))
    k = size / float(font['em'])
    return dict(a='fSmall', o='fSmallOutline', glow=dict(color=0, alpha=1, blurX=2, blurY=2, strength=5), size=size,
                chars=''.join(chr(c) for c in chars), adv=[round(font['advances'][font['codes'].index(c)] * k, 4) for c in chars],
                ascent=round(font['ascent'] * k, 4), descent=round(font['descent'] * k, 4), leading=round(font['leading'] * k, 4))


meta['fonts'] = {'small': glyph_anims(SMALL, SIZE)}
f = meta['fonts']['small']
print('font small %d glyphs, ascent %.2f descent %.2f leading %.2f' % (len(f['chars']), f['ascent'], f['descent'], f['leading']))

# ---------------------------------------------------------------- data of the game
meta['levelInfos'] = open(os.path.join(ARCH, 'levelInfos.xml'), encoding='utf-8').read()
meta['texts'] = {e.get('id'): e.text or '' for e in ET.parse(os.path.join(ARCH, 'texts.fr.xml')).getroot().iter('t')}

# ---------------------------------------------------------------- the sounds (S.BANK = Sfx.importDirectory("sounds"))
SND = os.path.join(OUT, 'sound')
if os.path.isdir(SND):
    shutil.rmtree(SND)
os.makedirs(SND)
import lameenc
sdir = os.path.join(ARCH, 'sounds')
names = []
for fn in sorted(os.listdir(sdir)):
    base, ext = os.path.splitext(fn)
    if ext.lower() == '.mp3':
        shutil.copy(os.path.join(sdir, fn), os.path.join(SND, base + '.mp3'))
        names.append(base)
    elif ext.lower() == '.wav':
        w = wave.open(os.path.join(sdir, fn), 'rb')
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        data = w.readframes(n)
        w.close()
        if sw == 1:  # 8 bits unsigned -> 16 bits
            data = ((np.frombuffer(data, np.uint8).astype(np.int16) - 128) << 8).tobytes()
        elif sw != 2:
            raise SystemExit('%s: %d bytes per sample' % (fn, sw))
        enc = lameenc.Encoder()
        enc.set_bit_rate(96)
        enc.set_in_sample_rate(rate)
        enc.set_channels(ch)
        enc.set_quality(2)
        mp3 = enc.encode(data) + enc.flush()
        open(os.path.join(SND, base + '.mp3'), 'wb').write(mp3)
        names.append(base)
meta['sounds'] = names
print('sounds %d (%s)' % (len(names), ', '.join(names)))

json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
