"""Builds the Fafi 360 graphics for KadoKadeo from the released game.swf of the Arkadeo game (Arkadeo/games/fafi360/swf).

Fafi 360 draws its scene in a 300 x 230 buffer shown x2 (mt.deepnight.Buffer, UPSCALE 2): the pictures are pixel art
(bitmaps of the SWF at whole positions), so every texture is at 1 px per Flash pixel (clipexport res 0.5, K = 2), from the
FFDec export of the shapes at zoom 1 composed with nearest sampling: the pixels Flash drew; the game shows them x2 without
smoothing.
  - every symbol of the library the League uses (lib.*) is a Clip timeline (clipexport.py) named after its class: the
    players (Perso: _shoes, _maillot, _skin, _hair and its _sub, driven by the code), the announce (its _bg Scrollstripe
    and _illu Scroll_illu; its _field text field is laid out by the game: `annonce` of meta.json), the explosion
    (Badaboom), the items, the pieces of the stadium the game draws into its bitmaps; with the frame scripts of their AS3
    classes (stop);
  - tiles.png (GfxTiles: the textures of the ball, the smoke) cut like the SpriteLibBitmap of Game.new;
  - the texts are drawn with the glyphs of the fonts embedded in game.swf (big, small, time), white (tinted by the game);
  - the French texts of the game (texts.fr.xml) for Data.hx.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: fafi360_assets.py <archive folder Arkadeo/games/fafi360> <out dir>
"""
import os, sys, json, shutil, math, struct, zlib, re
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import swfrender as R
import clipexport as C
import swftext
import swfdump as SD
import swffont

# game.swf + FFDec exports (sh ../../tools/prepare_game.sh <archive>/Arkadeo/games/fafi360 fafi360 game)
W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'fafi360', '')
ARCH = sys.argv[1]
OUT = sys.argv[2]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'game.swf', W + 'shp1_game', Z=1)
G.nearest = True


def symbol_classes(path):
    """AS3 SymbolClass: class name -> character id (the released names end with '_')"""
    raw = open(path, 'rb').read()
    data = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
    bb = SD.Bits(data, 8); bb.rect(); bb.u16(); bb.u16()
    out = {}
    for code, body in SD.read_tags(data, bb.pos, len(data)):
        if code == 76:
            b = SD.Bits(body)
            for _ in range(b.u16()):
                t = b.u16()
                out[b.string()] = t
    return out


SYM = symbol_classes(W + 'game.swf')


def sid(cls):
    return SYM['lib_.%s_' % cls]


# the frame scripts of the AS3 classes (decompiled lib_.* / gfx_fla_.*: addFrameScript ... stop())
CUSTOM = {
    (sid('Scroll_illu'), 28): [['s']], (sid('Scroll_illu'), 70): [['s']],
    (sid('Badaboom'), 19): [['s']],
    (SYM['gfx_fla_.shoot_skin_70_'], 6): [['s']], (SYM['gfx_fla_.shoot_maillot_69_'], 6): [['s']],
    (SYM['gfx_fla_.shoot_shoes_68_'], 6): [['s']], (SYM['gfx_fla_.fail_hail_67_'], 6): [['s']],
}

E = C.Exporter(G, SRC, '', CUSTOM)
E.fixed_res = 0.5
E.code_clips = True

# the hair of each pose of Perso holds the 38 hair styles in _sub (Player.setAnim: _hair._sub.gotoAndStop(hairId))
PERSO = sid('Perso')
for fr in G.sprites[PERSO].frames:
    for k, v in fr:
        if k == 'place' and v.get('name') == '_hair' and v.get('char') in G.sprites:
            E.code_for[v['char']] = ('_sub',)

meta = {}

# ---------------------------------------------------------------- clips
CLIPS = [
    # (class, code-driven children)
    ('Perso', ('_shoes', '_maillot', '_skin', '_hair')),
    ('Scrollstripe', ()), ('Scroll_illu', ('_sub',)),
    ('Badaboom', ()), ('Bonus', ()), ('Mine', ()), ('Item_colision', ()), ('MissileTrainee', ()), ('Chrono', ()),
    ('Bg_score', ()),
    # the stadium, drawn by the game into its bitmaps
    ('Gazon', ()), ('Taches', ()), ('Item_deco', ()), ('Noise', ()), ('Damier', ()), ('Gradins_fixe', ()),
    ('Public_cotes', ()), ('Muret', ()),
    ('But_back', ()), ('But_back_shadow', ()), ('But_front', ()), ('But_front_shadow', ()), ('But_tile', ()),
    ('But_tile_shadow', ()),
]
# (the League plays on grass: Gazon frame 2 is the leather of a LvUP team)
FRAMES = {'Gazon': [1]}
for cls, code in CLIPS:
    E.export(sid(cls), cls, code=code, frames=FRAMES.get(cls), res=0.5)
print('clips', len(E.clips), 'warnings', E.warnings)


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    E.pivots[name] = [round(pivot[0], 6), round(pivot[1], 6)]
    E.area[name] = sum(im.width * im.height for im in imgs)


# ---------------------------------------------------------------- tiles.png (GfxTiles): SpriteLibBitmap of Game.new
# setSliceGrid(16, 16); slice("ballTexture", 0, 0, 24, 36, 2); sliceGrid("smoke", 0, 4)
tiles = Image.open(os.path.join(ARCH, 'png', 'tiles.png')).convert('RGBA')
write_images('ballTexture', [tiles.crop((24 * i, 0, 24 * i + 24, 36)) for i in range(2)])
write_images('smoke', [tiles.crop((0, 64, 16, 80))])

# ---------------------------------------------------------------- fonts: the glyphs of the embedded fonts, white (the game
# tints them), one picture per character on one canvas (the pen position on the baseline at the pivot)
FONTS = swffont.read_fonts(W + 'game.swf')
BY_NAME = {f['name']: f for f in FONTS.values()}


def glyph_anim(name, font, size):
    chars = [c for c in font['codes'] if 32 <= c < 0x10000]
    rend = [swffont.render_glyph_index(font, font['codes'].index(c), size) for c in chars]
    left = max(ox for _, ox, _ in rend)
    top = max(oy for _, _, oy in rend)
    right = max(im.width - ox for im, ox, _ in rend)
    bottom = max(im.height - oy for im, _, oy in rend)
    w, h = left + right, top + bottom
    imgs = []
    for im, ox, oy in rend:
        c = Image.new('RGBA', (w, h), (255, 255, 255, 0))
        c.alpha_composite(im, (left - ox, top - oy))
        imgs.append(c)
    write_images(name, imgs, (left / w, top / h))
    em = float(font['em'])
    k = size / em
    return dict(a=name, size=size, chars=''.join(chr(c) for c in chars),
                adv=[round(font['advances'][font['codes'].index(c)] * k, 4) for c in chars],
                ascent=round(font['ascent'] * k, 4), descent=round(font['descent'] * k, 4), leading=round(font['leading'] * k, 4))


# Game.createField: FSmall "small" 16, FBig "big" 8, FTime "time" 8; the _field of lib.Annonce: Volter (Goldfish) 36
meta['fonts'] = {
    'small': glyph_anim('fSmall', BY_NAME['small'], 16),
    'big': glyph_anim('fBig', BY_NAME['big'], 8),
    'time': glyph_anim('fTime', BY_NAME['time'], 8),
    'volter': glyph_anim('fVolter', BY_NAME['Volter (Goldfish)'], 36),
}
for k_, v in meta['fonts'].items():
    print('font %-7s %3d glyphs, ascent %.2f descent %.2f leading %.2f' % (k_, len(v['chars']), v['ascent'], v['descent'], v['leading']))

# ---------------------------------------------------------------- the _field of lib.Annonce (laid out by the game)
TEXTS = swftext.all_edittexts(W + 'game.swf')
ann = [v for k, v in G.sprites[sid('Annonce')].frames[0] if k == 'place' and v.get('name') == '_field'][0]
t = TEXTS[ann['char']]
meta['annonce'] = dict(x=ann['matrix']['tx'], y=ann['matrix']['ty'], w=round(t['bounds'][1] - t['bounds'][0], 3),
                       h=round(t['bounds'][3] - t['bounds'][2], 3), color=int(t['color'][1:], 16), size=t['height'],
                       depths=[(v['depth'], v.get('name')) for k, v in G.sprites[sid('Annonce')].frames[0] if k == 'place'])
print('annonce', meta['annonce'])

# ---------------------------------------------------------------- texts of the game (texts.fr.xml: Lang)
meta['texts'] = {e.get('id'): e.text or '' for e in ET.parse(os.path.join(ARCH, 'texts.fr.xml')).getroot().iter('t')}

# ---------------------------------------------------------------- the title (lib.TitleLogo, for the start screen)
TITLE = sid('TitleLogo')
for f in range(1, G.sprites[TITLE].nframes + 1):
    cm = []
    R.Renderer(G, 1).collect(R.Instance(G, TITLE, ctrl={TITLE: f, '__noactions__': True}), R.IDENT, R.NOCX, set(), cm)
    imgs, reg = E.render([cm], 1.0, margin=1)
    os.makedirs(os.path.join(OUT, 'title'), exist_ok=True)
    imgs[0].save(os.path.join(OUT, 'title', '%d.png' % f))

json.dump(E.clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(E.pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
tot = sum(E.area.values())
print('anims %d, area %.2f Mpx' % (len(E.area), tot / 1e6))
for k_, v in sorted(E.area.items(), key=lambda x: -x[1])[:20]:
    print('  %-24s %8d px' % (k_, v))
