"""Builds the Charlotte's Quest graphics for KadoKadeo from the released game.swf of the Arkadeo game
(Arkadeo/games/charlotteQuest/swf: the symbols of gfx.swf, the font "def" of obj/gameResources.swf).

Charlotte's Quest is drawn at 1 canvas pixel per Flash pixel (the Arkadeo game area: 600 x 460), so the textures are at
1 px per Flash pixel (clipexport res 0.5, K = 2) from the FFDec export of the shapes at zoom 4, except what the game
scales up (the bricks of the background up to x3.6, the splashes x4 to x5: drawn at 4 px per Flash pixel). The images
are drawn 1.5 times finer (PHYS: the sheets at scale 1.5, sharp on a page zoomed to 150 % or on a high density screen;
the sizes the game knows do not change). One scale for the whole spritesheet: the spritesheets of the old versions
(resources/js/games/builds/atlas.mjs, the replays) take the scale of its first sheet for all its frames. The bricks and
splashes keep their 4 px per Flash pixel (res 4 / (K x PHYS) in their defs).
  - the variants of the enemies share their parts: the frame script of each part (gfx_fla.pacmansmc_155, globe_90,
    moustiquecorps_124...) shows the frame of the flag the frame script of the symbol sets on it (lib.Pacman: norm_,
    lib.Badman: bad_, lib.Shootman: shooter_, lib.Eye2: bad_, lib.Guepe: guepe_): the parts are exported on that frame;
  - Entity.cacheAnims: the enemies and the notes drawn once into bitmaps (120 x scale px, the registration point in the
    middle) with the filters the code put on the clip (the glows of the mines and of the worms, their colour), one
    picture per frame of the `_smc` of each label in the order cacheAnims drew them: its frames 2 to N, then N again
    (`_smc.nextFrame()` before each draw, nextFrame stops on the last frame);
  - Charlotte: the `_smc` of each label (the unicorn) drawn frame by frame with its nested clips (the hair, the arms play
    with it) and the filters of its placement (an outline, a contrast, a drop shadow) on the whole picture; the AS3
    frame scripts of its loops (licornewait, licorneup, licornedown, biglicorn); the big unicorn of the Uber keeps its
    `_smc` (Charlotte, turned by the code);
  - the clips the game plays (lib.Eye / Eye2, Tourelle, Blood, Puf, Ding, Pop, Bubble, PowerIcon) as Clip timelines;
    the leaves of the Tourelle take a random frame and rotation (frame script of gfx_fla.feuillebaseglobal_47): the
    instance is named `leaves_` for the game;
  - the pictures the game draws into its bitmaps: the bricks (Brick, Brick2), the background shapes (DecorBG), the
    herbs and bones (DecorHerbes / DecorBones drawn x2 in 100 x 100 like Room.draw), the splashes (Splash1, white:
    the game gives them their colour), the bedroom (lib.Room), the rainbow, the shot of each level (lib.Shoot), the dead
    Charlotte (lib.Dead), lib.Life;
  - the bitmaps of the game (shadow2.png, clouds2.png) at their native size;
  - the font "def" 16 (Game.createField): its glyphs, white (tinted by the game);
  - levels.png (the plans of the rooms, read by Room.generate) and the texts (texts.fr.xml) for Data.hx.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: charlottesquest_assets.py <archive folder Arkadeo/games/charlotteQuest> <out dir>
"""
import os, sys, json, shutil, math, zlib
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image
import swfrender as R
import clipexport as C
import swfdump as SD
import swffont

# game.swf + FFDec exports (sh ../../tools/prepare_game.sh <archive>/Arkadeo/games/charlotteQuest charlottequest game)
W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'charlottequest', '')
ARCH = sys.argv[1]
OUT = sys.argv[2]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'game.swf', W + 'shp4_game', Z=4)
G.flash_replace = True
G.blur_filter = True       # the BlurFilters of the timelines (Puf, the wings, the bubbles, the power-ups)
G.blur_filters = True      # (their margin in the bounds)
G.inner_filters = True     # the inner glows / drop shadows of the timelines


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


def fla(cls):
    return SYM['gfx_fla_.%s_' % cls]


# ---------------------------------------------------------------- variants (the frame scripts of the parts)
PAC_PARTS = [fla(n) for n in ('pacmanjoue_152', 'pacmansmc_155', 'pacmansmc2_160', 'pacmansmccopy_163')]
EYE_PARTS = [fla(n) for n in ('globe_90', 'iris2_95', 'iris_97')]
MOU_PARTS = [fla(n) for n in ('moustiquedard_116', 'moustiquetron_118', 'moustiquetronc2_120', 'moustiquetronc1_122',
                              'moustiquecorps_124', 't_130', 'oeilmoustique_132', 'dent_134')]


def parts(lst, f):
    return {p: f for p in lst}


VARIANT = {
    'Pacman': parts(PAC_PARTS, 1), 'Badman': parts(PAC_PARTS, 2), 'Shootman': parts(PAC_PARTS, 3),
    'Eye': parts(EYE_PARTS, 1), 'Eye2': parts(EYE_PARTS, 2),
    'Moustik': parts(MOU_PARTS, 1), 'Guepe': parts(MOU_PARTS, 2),
}

# ---------------------------------------------------------------- frame scripts of the AS3 classes (decompiled)
LICORNE_UP, LICORNE_DOWN, LICORNE_WAIT, BIG = fla('licorneup_65'), fla('licornedown_66'), fla('licornewait_58'), fla('biglicorn_67')
CUSTOM = {
    (LICORNE_WAIT, 43): [['g', 1, 1]],      # gotoAndPlay("wait")
    (LICORNE_UP, 1): [],                    # gotoAndPlay("Lloop"): no such label in this timeline (an error, nothing done)
    (LICORNE_UP, 27): [['g', 10, 1]],       # gotoAndPlay("Uloop")
    (LICORNE_DOWN, 1): [],                  # gotoAndPlay("Uloop"): no such label (nothing done)
    (LICORNE_DOWN, 27): [['g', 10, 1]],     # gotoAndPlay("Dloop")
    (BIG, 29): [['s']],
    (fla('tourellecharge2_105'), 24): [['g', 16, 1]],   # gotoAndPlay("loop")
    (fla('trotteuse_228'), 1): [['s']],
}
for cls in ('Pacman', 'Badman', 'Shootman', 'Eye', 'Eye2', 'Guepe', 'Moustik'):
    if (sid(cls), 1) not in CUSTOM:
        CUSTOM[(sid(cls), 1)] = [['s']] if cls != 'Moustik' else []
# the parts choose their frame once (forced by the variants), the rest of their scripts is not needed
for p in PAC_PARTS + EYE_PARTS + MOU_PARTS:
    CUSTOM[(p, 1)] = [['s']]

E = C.Exporter(G, SRC, '', CUSTOM)
meta = {}
# the images drawn at 1.5 px per pixel of their textures (the sheets at scale 1.5: sharp on a page at 150 %)
PHYS = 1.5
E.phys = PHYS
# (the bricks and splashes, scaled up by the game: 4 px per Flash pixel, as before the sheets at 1.5)
RES4 = 4.0 / (C.K * PHYS)


def place_of(parent, name=None, char=None):
    for fr in G.sprites[parent].frames:
        for k, v in fr:
            if k == 'place' and isinstance(v, dict) and ((name and v.get('name') == name) or (char and v.get('char') == char)):
                return v
    return None


def write_images(name, imgs, pivot=(0, 0)):
    d = os.path.join(SRC, name)
    os.makedirs(d, exist_ok=True)
    for i, im in enumerate(imgs):
        im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
    E.pivots[name] = [round(pivot[0], 6), round(pivot[1], 6)]
    E.area[name] = sum(im.width * im.height for im in imgs)


def collect(inst, M=R.IDENT, cx=R.NOCX):
    out = []
    R.Renderer(G, 1).collect(inst, M, cx, set(), out)
    return out


def wrap(cmds, filters):
    return [('layer', cmds, filters, None)] if filters and cmds else cmds


def render_anim(name, cmd_lists, res=0.5, margin=1.0):
    """pictures of command lists on one canvas (registration = pivot), K * res px per Flash pixel"""
    imgs, reg = E.render(cmd_lists, C.K * res, margin=margin)
    E.write_anim(name, imgs, reg)
    return len(imgs)


def snaps_playing(sid_, n, ctrl=None, start=1):
    """states of a sprite playing its timeline from `start` (its nested clips playing with it)"""
    inst = R.Instance(G, sid_, ctrl=ctrl)
    if start != 1:
        inst.goto_and_stop(start)
    out = []
    for i in range(n):
        out.append(R._snap(inst))
        inst.tick()
    return out


def simple_def(anim, n, res=0.5, acts=None, labels=None, still=False):
    d = dict(n=n, r=res, layers=[dict(k=0, a=anim, t=list(range(1, n + 1)))])
    if acts:
        d['acts'] = acts
    if labels:
        d['labels'] = labels
    if still:
        d['still'] = 1
    return d


def m0_of(v, res=0.5):
    m = v['matrix']
    return C.decompose(m['a'], m['b'], m['c'], m['d'], m['tx'] * C.K * res, m['ty'] * C.K * res)


def flat_timeline_clip(name, sid_, filters=None, res=0.5, ctrl=None):
    """a sprite whose nested clips play with it, drawn frame by frame (with the filters of its placement on the whole
    picture): a simple Clip with the frame scripts and labels of the sprite"""
    sd = G.sprites[sid_]
    n = sd.nframes
    states = snaps_playing(sid_, n, ctrl=ctrl)
    render_anim(name, [wrap(collect(s), filters) for s in states], res)
    acts = {}
    for f in range(1, n + 1):
        t = E.tokens(sid_, f)
        if t:
            acts[str(f)] = t
    E.clips[name] = simple_def(name, n, res, acts=acts or None, labels=dict(sd.labels) if sd.labels else None)
    return name


# ---------------------------------------------------------------- Charlotte (lib.Charlotte)
# (shown at 0.75 by Player: textures at 0.75 px per Flash pixel)
CRES = 0.375
CHARLOTTE = sid('Charlotte')
csd = G.sprites[CHARLOTTE]
sections = []      # (label, first frame, nested sprite, placement)
for fi, fr in enumerate(csd.frames):
    for k, v in fr:
        if k == 'place' and isinstance(v, dict) and v.get('name') == '_smc':
            sections.append((fi + 1, v))
labels = dict(csd.labels)
by_frame = {f: l for l, f in labels.items()}
layers = []
for i, (f0, v) in enumerate(sections):
    f1 = sections[i + 1][0] if i + 1 < len(sections) else csd.nframes + 1
    lab = by_frame[f0]
    nested = v['char']
    filters = v.get('filters') or []
    cname = 'Charlotte_' + lab
    if nested == BIG:
        # the big unicorn: its _smc (Charlotte) turned by the code
        E.wrap_for = {BIG: filters}
        E.export(BIG, cname, code=('_smc',), res=CRES)
        E.wrap_for = {}
    else:
        flat_timeline_clip(cname, nested, filters, res=CRES)
    p = [0] * csd.nframes
    for f in range(f0, f1):
        p[f - 1] = f0
    layers.append(dict(k=2, a=cname, p=p, nm='_smc', m0=m0_of(v, CRES)))
E.clips['Charlotte'] = dict(n=csd.nframes, r=CRES, layers=layers, labels=labels, acts={'1': [['s']]})

# ---------------------------------------------------------------- clips played by the game
# the eyes: the code turns the iris (_smc.gotoAndStop by the angle to Charlotte); shown at 0.35 to 0.6 (+ 0.15 when hit):
# 0.75 px per Flash pixel
E.fixed_res = 0.375
for cls in ('Eye', 'Eye2'):
    E.export(sid(cls), cls, ctrl=VARIANT[cls], code=('_smc',), frames=[1], res=0.375)
E.fixed_res = None

# the turret: its _smc turned by the code (the drop shadow of its placement at run time, it stays in the stage), the
# leaves on a random frame and rotation
TOURELLE = sid('Tourelle')
LEAVES = fla('feuillebaseglobal_47')
lv = place_of(TOURELLE, char=LEAVES)
leaves_filters = lv['filters']
lv['filters'] = []
lv['name'] = 'leaves_'
E.effects = True
E.shadows = True
# (the leaves: one picture per frame, the colour matrix of each leaf and the filters of the placement on the whole picture)
E.strategy_for[LEAVES] = 'flat'
E.wrap_for = {LEAVES: leaves_filters}
E.export(TOURELLE, 'Tourelle', code=('_smc', 'leaves_'), res=0.5)
E.wrap_for = {}
E.effects = False
E.shadows = False

# Drop: mc._smc.scaleY
E.export(sid('Blood'), 'Blood', code=('_smc',), res=0.5)

# Fx.anim (gotoAndStop(1), then nextFrame each frame), Item: the bubble of the capture (plays)
for cls in ('Puf', 'Ding', 'Pop', 'Bubble'):
    flat_timeline_clip(cls, sid(cls))

# the power-ups: PowerIcon.gotoAndStop(kind), the icon of each frame playing
PI = sid('PowerIcon')
psd = G.sprites[PI]
players = []
for f in range(1, psd.nframes + 1):
    inst = R.Instance(G, PI)
    inst.goto_and_stop(f)
    # the length of the loop of the icon: the longest nested timeline of the frame
    nn = max([e['inst'].sd.nframes for e in inst.display.values() if e['inst'] is not None] + [1])
    states = []
    for i in range(nn):
        states.append(R._snap(inst))
        inst.tick()
    cname = 'PowerIcon_%d' % f
    render_anim(cname, [collect(s) for s in states])
    E.clips[cname] = simple_def(cname, nn)
    p = [0] * psd.nframes
    p[f - 1] = f
    players.append(dict(k=2, a=cname, p=p, m0=[0, 0, 1, 1, 0]))
E.clips['PowerIcon'] = dict(n=psd.nframes, r=0.5, layers=players, acts={'1': [['s']]})

for cls in ('Life',):
    flat_timeline_clip(cls, sid(cls))

print('clips', len(E.clips), 'warnings', E.warnings)


# ---------------------------------------------------------------- Entity.cacheAnims
def cache_anim(key, cls, scale, filters=(), ctrl=None):
    """the pictures cacheAnims drew: for each label of the clip, its _smc frames 2..N then N, drawn at `scale` with the
    filters of the clip in a size x size bitmap, the registration point in the middle"""
    size = int(math.ceil(120 * scale))
    S = sid(cls)
    sd = G.sprites[S]
    labs = sorted(sd.labels.items(), key=lambda kv: kv[1])
    out = []
    for lab, f in labs:
        inst = R.Instance(G, S, ctrl=ctrl)
        inst.goto_and_stop(f)
        smc = [e['inst'] for e in inst.display.values() if e['name'] == '_smc'][0]
        n = smc.sd.nframes
        cmds = []
        for af in range(n):
            smc.goto_and_stop(min(n, smc.frame + 1))
            M = dict(a=scale, b=0, c=0, d=scale, tx=0, ty=0)
            cmds.append(wrap(collect(R._snap(inst), M), list(filters)))
        Z = G.Z
        rd = R.Renderer(G, 1)
        imgs = []
        ps = int(round(size * PHYS))
        assert ps == size * PHYS, size
        for cm in cmds:
            canvas = np.zeros((size * Z, size * Z, 4), dtype=np.float32)
            rd.draw(cm, canvas, (-size / 2.0, -size / 2.0))
            im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
            imgs.append(im.resize((ps, ps), Image.LANCZOS).convert('RGBA'))
        aname = 'k_%s_%s' % (key, lab)
        write_images(aname, imgs, (0, 0))
        out.append([lab, n, aname])
    meta.setdefault('cache', {})[key] = dict(size=size, labels=out)


def glow(color, alpha, bx, by, strength, quality=1, inner=False):
    return dict(type='glow', color=((color >> 16) & 255, (color >> 8) & 255, color & 255, int(round(alpha * 255))),
                blurX=bx, blurY=by, strength=strength, inner=inner, knockout=False, passes=quality)


def blur(bx, by, quality=1):
    return dict(type='blur', blurX=bx, blurY=by, passes=quality)


def colorize(col, rn, ro):
    r, g, b = [rn * ((col >> s) & 255) / 255.0 for s in (16, 8, 0)]
    return dict(type='colormatrix', matrix=(ro + r, r, r, 0, 0, g, ro + g, g, 0, 0, b, b, ro + b, 0, 0, 0, 0, 0, 1, 0))


# en.Pacman (0.6), en.Mosquito (0.75), en.Bee (1), en.Chest (1), it.Score (0.7, gold 1)
cache_anim('pacman0', 'Pacman', 0.6, ctrl=VARIANT['Pacman'])
cache_anim('pacman1', 'Badman', 0.6, ctrl=VARIANT['Badman'])
cache_anim('pacman2', 'Shootman', 0.6, ctrl=VARIANT['Shootman'])
cache_anim('mosquito', 'Moustik', 0.75, ctrl=VARIANT['Moustik'])
cache_anim('bee', 'Guepe', 1, ctrl=VARIANT['Guepe'])
cache_anim('chest', 'Coffre', 1)
for t, s in ((0, 0.7), (1, 0.7), (2, 1)):
    cache_anim('score_%d' % t, 'Billet', s)
# en.Worm: GlowFilter(0, 0.7, 16, 16, 2) (+ a colorize for the types 1 and 2)
WG = glow(0x0, 0.7, 16, 16, 2)
cache_anim('worm_0', 'Scuti', 0.5, [WG])
cache_anim('worm_1', 'Scuti', 0.8, [WG, colorize(0x841324, 0.5, 0.5)])
cache_anim('worm_2', 'Scuti', 0.5, [WG, colorize(0x680606, 0.6, 0.6)])
# en.Mine: a blur and four glows (+ a colorize for the type 1)
MF = [blur(8, 8), glow(0x96B002, 1, 6, 6, 20, 3), glow(0x728602, 1, 16, 16, 50, 3), glow(0x465201, 0.7, 32, 32, 2, 1, True),
      glow(0x96AF03, 1, 2, 2, 2)]
cache_anim('mine0', 'MineBalls', 0.7, MF)
cache_anim('mine1', 'MineBalls', 0.7, MF + [colorize(0x487E99, 0.7, 0.3)])


# ---------------------------------------------------------------- pictures drawn into the bitmaps of the game
def frames_of(name, sid_, res=0.5, frames=None, white=False, filters=None, silhouettes=False):
    """silhouettes: also the white silhouettes `name`W on the same canvas (a colour transform with offsets set by the code:
    a tint + the silhouette drawn ADD, arkadeo.Clip)"""
    sd = G.sprites[sid_]
    frames = frames or list(range(1, sd.nframes + 1))
    cmds, wcmds = [], []
    for f in frames:
        inst = R.Instance(G, sid_, ctrl={sid_: f, '__noactions__': True})
        cx = C.WHITE if white else R.NOCX
        cmds.append(wrap(collect(inst, cx=cx), filters))
        if silhouettes:
            wcmds.append(wrap(collect(inst, cx=C.WHITE), filters))
    if silhouettes:
        imgs, reg = E.render(cmds + wcmds, C.K * res, margin=1.0)
        E.write_anim(name, imgs[:len(cmds)], reg)
        E.write_anim(name + 'W', imgs[len(cmds):], reg)
        n = len(cmds)
    else:
        n = render_anim(name, cmds, res)
    # (a MovieClip of the game: gotoAndStop(frame), totalFrames)
    E.clips[name] = simple_def(name, n, res, still=True)
    return n


frames_of('Brick', sid('Brick'), res=RES4)
# (Room.draw: the bricks of the bubble themes coloured by Color.getColorizeCT, a colour transform with offsets)
frames_of('Brick2', sid('Brick2'), res=RES4, silhouettes=True)
frames_of('DecorBG', sid('DecorBG'))
frames_of('Splash1', sid('Splash1'), res=RES4, white=True)
frames_of('Room', sid('Room'))
frames_of('Rainbow', sid('Rainbow'))
frames_of('Shoot', sid('Shoot'))
frames_of('Dead', sid('Dead'))
frames_of('Title', sid('Title'))


# Room.draw: DecorHerbes / DecorBones drawn x2 in a 100 x 100 BitmapData, the registration point in the middle
def cache100(name, cls):
    S = sid(cls)
    imgs = []
    rd = R.Renderer(G, 1)
    for f in range(1, G.sprites[S].nframes + 1):
        inst = R.Instance(G, S, ctrl={S: f, '__noactions__': True})
        cm = collect(inst, dict(a=2, b=0, c=0, d=2, tx=0, ty=0))
        Z = G.Z
        canvas = np.zeros((100 * Z, 100 * Z, 4), dtype=np.float32)
        rd.draw(cm, canvas, (-50.0, -50.0))
        im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
        imgs.append(im.resize((int(100 * PHYS), int(100 * PHYS)), Image.LANCZOS).convert('RGBA'))
    write_images(name, imgs, (0, 0))


cache100('Herbes', 'DecorHerbes')
cache100('Bones', 'DecorBones')

# the bitmaps of the game (@:bitmap): their native pixels, stretched by the game (to 600 x 460: their size does not matter)
for png in ('shadow2', 'clouds2'):
    im = Image.open(os.path.join(ARCH, 'gfx', png + '.png')).convert('RGBA')
    write_images(png, [im], (0, 0))

# ---------------------------------------------------------------- the font "def" 16 (Game.createField)
FONTS = swffont.read_fonts(W + 'game.swf')
BY_NAME = {f['name']: f for f in FONTS.values()}


def glyph_anim(name, font, size):
    chars = [c for c in font['codes'] if 32 <= c < 0x10000]
    rend = [swffont.render_glyph_index(font, font['codes'].index(c), size * PHYS) for c in chars]
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


meta['fonts'] = {'def': glyph_anim('fDef', BY_NAME['def'], 16)}
for k_, v in meta['fonts'].items():
    print('font %-7s %3d glyphs, ascent %.2f descent %.2f leading %.2f' % (k_, len(v['chars']), v['ascent'], v['descent'], v['leading']))

# ---------------------------------------------------------------- levels.png: Game.new slices it in 20 x 15 units
# (Room.CWID x Room.CHEI: one pixel per square, white = wall): sliceUnit(group, x, y, count) on one row
lv = Image.open(os.path.join(ARCH, 'gfx', 'levels.png')).convert('RGB')
UW, UH = 20, 15
levels = {}
for group, ux, uy, n in (('horizontal', 1, 0, 21), ('vertical', 1, 2, 26), ('toUp', 1, 4, 19), ('bedroom', 1, 6, 1)):
    frames = []
    for i in range(n):
        x0, y0 = (ux + i) * UW, uy * UH
        rows = []
        for y in range(UH):
            rows.append(''.join('1' if lv.getpixel((x0 + x, y0 + y)) == (255, 255, 255) else '0' for x in range(UW)))
        frames.append(rows)
    levels[group] = frames
meta['levels'] = levels

# ---------------------------------------------------------------- texts (texts.fr.xml: Lang)
meta['texts'] = {e.get('id'): e.text or '' for e in ET.parse(os.path.join(ARCH, 'texts.fr.xml')).getroot().iter('t')}

# the placement of the _smc of the Tourelle (Turret: basePtX / basePtY) and of the Blood
meta['tourelle_smc'] = [round(v, 4) for v in m0_of(place_of(TOURELLE, name='_smc'))[:2]]

json.dump(E.clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(E.pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
tot = sum(E.area.values())
print('anims %d, area %.2f Mpx' % (len(E.area), tot / 1e6))
for k_, v in sorted(E.area.items(), key=lambda x: -x[1])[:25]:
    print('  %-24s %8d px' % (k_, v))
