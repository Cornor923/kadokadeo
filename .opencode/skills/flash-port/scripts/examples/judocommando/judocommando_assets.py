"""Builds the Judo Commando graphics for KadoKadeo from the original SWF (gfx.swf: the graphics of the released
game.swf, same shapes and timelines, readable instance names).

Judo Commando is pixel art drawn by Flash in "low" quality (root._quality = "low"): no anti-aliasing, bitmaps not
smoothed. Its 500 bitmap-filled shapes (and the 18 vector ones, pixel rectangles too) are taken from the FFDec
export at zoom 2 and composed with nearest sampling at 2 px per Flash pixel (the resolution of every texture), so
the textures are the pixels Flash drew; the game draws them x2 more (the map is zoomed x2) with nearest sampling.

Every symbol the game attaches is exported as a Clip (timeline tables played by judocommando.Clip, clipexport.py):
  - the hero (mcHero) on the frames of its labels (Hero.playAnim = gotoAndStop(label)), its animations (`smc`)
    flattened per frame; the markers `hold` / `center` (invisible clips whose position the code reads) are kept as
    layers without pictures (k=4: their matrices only);
  - the monsters (mcMonsters: frame 1 = the soldiers of the 4 first types, 5 = the ninja, 6 = the gorilla), their
    animation sets on the frames of their labels; the head / body / gun of the soldiers (sprites 446 / 439 / 449, 682)
    stay nested clips: their frame script picks the frame of the type (_hfr / _bfr / _gfr, set by Mon.setType);
  - the projectiles, bonuses, particles, the interface;
  - what Game draws into BitmapData once (the tiles of the level and of the tower, the background tiles, the
    windows): single pictures at 1 px per Flash pixel, drawn into render textures by the game;
  - the sky (mcBg, drawn then cut into bands of 15 px by Game.initBg): the colour of each band, in meta.json.
Writes <out>/src (images), <out>/pivots.json, <out>/clips.json and <out>/meta.json.
usage: judocommando_assets.py <out dir>   (after prepare_game.sh + the zoom 2 export, see rebuild_assets.sh)
"""
import os, sys, json, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
import numpy as np
from PIL import Image
import swfrender as R
import clipexport as C

W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'judocommando', '')
OUT = sys.argv[1]
SRC = os.path.join(OUT, 'src')
if os.path.isdir(SRC):
    shutil.rmtree(SRC)
os.makedirs(SRC)

G = R.SWF(W + 'gfx.swf', W + 'shp2_gfx', Z=2)       # clips: 2 px per Flash pixel
G1 = R.SWF(W + 'gfx.swf', W + 'shp1_gfx', Z=1)      # pictures drawn into the bitmaps of Game: 1 px per Flash pixel
for X in (G, G1):
    X.flash_replace = True
    X.nearest = True
K = C.K


def rng(*spans):
    out = []
    for a, b in spans:
        out += list(range(a, b + 1))
    return out


def label_frames(sid):
    return sorted(set(G.sprites[sid].labels.values()))


# ---------------------------------------------------------------- frame scripts (decompiled in as_gfx/)
RM = [['x', 'rmSelf']]           # removeMovieClip("")
KILL = [['x', 'kill']]           # obj.kill(): the mt.bumdum.Sprite of the clip (Phys) dies
CUSTOM = {
    (45, 12): RM, (50, 3): RM, (72, 9): RM, (139, 11): RM, (218, 12): RM, (238, 5): RM, (256, 10): RM,
    (162, 23): KILL, (285, 24): KILL,
    (324, 5): [['x', 'pstop1']],        # end of "land": _parent.gotoAndStop(1) (the hero's "stand")
    (974, 41): [['g', 37, 1]],          # gorilla piledriver: gotoAndPlay(_currentframe - 4)
    # head / body / gun of the soldiers: gotoAndStop(_hfr / _bfr / _gfr of the first parent that has one)
    (446, 1): [['x', 'hfr']], (439, 1): [['x', 'bfr']], (682, 1): [['x', 'bfr']], (449, 1): [['x', 'gfr']],
    # the monster in the hero's arm lock: gotoAndStop(_parent._parent._afr) (its type, Hero.updateCrouch)
    (584, 1): [['x', 'afr']], (591, 1): [['x', 'afr']], (598, 1): [['x', 'afr']], (605, 1): [['x', 'afr']],
    # markers (hold, center): _visible = false / smc._visible = false (exported without pictures, see marker())
    (453, 1): [], (506, 1): [], (528, 1): [], (490, 1): [], (507, 1): [],
}

E = C.Exporter(G, SRC, '', CUSTOM)
E.clip_res = [1.0]
E.fixed_res = 1.0

MARKERS = (453, 490, 507, 528)
HERO = 611
MONS = 1077
MON_SETS = (712, 834, 976)

# the animations of the hero and of the monsters: flattened per frame, the markers and nested animations apart
for sid in (HERO,) + MON_SETS:
    E.strategy_for[sid] = 'flat'
    E.code_for[sid] = ('smc',)
for sid in MON_SETS:
    # Mon.playAnim = root.smc.gotoAndStop(label): the frames of the labels, and frame 4 (the top of a ladder:
    # Human.updateLadder plays "crouch" then root.smc.gotoAndStop(4), the "stand" of frame 1 still there in the SWF;
    # left empty, the monster vanished until backToNormal)
    E.frames_for[sid] = sorted(set(label_frames(sid)) | {4})
for sid, sd in G.sprites.items():
    for ops in sd.frames:
        for k, v in ops:
            if k == 'place' and v.get('name') in ('hold', 'center'):
                E.code_for[sid] = ('hold', 'center')
                E.strategy_for[sid] = 'flat'

E.export(HERO, 'mcHero', frames=label_frames(HERO), code=('smc', 'animGroundRoll'))
E.export(MONS, 'mcMonsters', strategy='flat', code=('smc',), frames=[1, 2, 3, 4, 5, 6])

SIMPLE = {
    'mcBullet': 293, 'mcShuriken': 229, 'mcRocket': 223, 'mcMine': 287, 'fxSmoke': 218, 'fxTwinkle': 63,
    'mcVanish': 72, 'mcBlood': 45, 'fxShotImpact': 139, 'mcExplosion': 285, 'fxSpark': 162, 'fxSpark2': 147,
    'mcSwordSlash': 238, 'mcSlash': 256, 'fxBrickDust': 266, 'mcNum': 257, 'mcGround': 170, 'mcFlash': 50,
    'mcLifeBar': 203, 'mcLifePoint': 200,
}
for nm, sid in SIMPLE.items():
    E.export(sid, nm, strategy='flat')
E.export(119, 'mcBonus', strategy='flat', code=('smc',))
E.export(114, 'mcGem', strategy='flat', code=('smc',))
E.export(197, 'mcLevel', strategy='flat', code=('smc',))
E.export(77, 'mcBlinkPix', strategy='flat', code=('smc',))
# the bricks and planks thrown by an explosion: Col.setColor(p.root, 0, -30) (Game.explodeSquare)
DARK = dict(mult=[1.0, 1.0, 1.0, 1.0], add=[-30, -30, -30, 0])
E.export(262, 'partBrick', strategy='flat', cx=DARK)
E.export(243, 'partWood', strategy='flat', cx=DARK)
# the city in the background: plane 0 under Col.setPercentColor(mc, 50, 0xDD00DD)
E.export(56, 'mcScrolling', strategy='flat')
PURPLE = dict(mult=[0.5, 0.5, 0.5, 1.0], add=[int(0.5 * 0xDD), 0, int(0.5 * 0xDD), 0])
E.export(56, 'mcScrolling0', strategy='flat', cx=PURPLE, frames=[1])


# markers: a layer without picture (k=4) and what the code reads of it on each frame, `hm`: [_x, _y, _rotation] (Flash
# reads _rotation as atan2(b, a) of the matrix), null where it is not on the timeline
import math


def strip_markers():
    for nm, cdef in E.clips.items():
        for L in cdef['layers']:
            if L.get('nm') not in ('hold', 'center'):
                continue
            sid = int(nm[1:])
            assert nm == 'c%d' % sid, nm
            hm = []
            for f in range(1, cdef['n'] + 1):
                inst = R.Instance(G, sid, ctrl={sid: f, '__noactions__': True})
                es = [e for e in inst.display.values() if e['name'] == L['nm']]
                if not es:
                    hm.append(None)
                    continue
                m = es[0]['matrix']
                hm.append([round(m['tx'], 2), round(m['ty'], 2), round(math.degrees(math.atan2(m['b'], m['a'])), 4)])
            L['k'] = 4
            L['hm'] = hm
            for k in ('a', 't', 'p', 'm', 'm0'):
                L.pop(k, None)


strip_markers()

# clips no longer used and their images
ROOTS = ['mcHero', 'mcMonsters'] + list(SIMPLE) + ['mcBonus', 'mcGem', 'mcLevel', 'mcBlinkPix', 'partBrick',
                                                    'partWood', 'mcScrolling', 'mcScrolling0']
keep, todo = set(), list(ROOTS)
while todo:
    nm = todo.pop()
    if nm in keep:
        continue
    keep.add(nm)
    todo += [L['a'] for L in E.clips[nm]['layers'] if L['k'] == 2]
used = {L['a'] for nm in keep for L in E.clips[nm]['layers'] if L['k'] in (0, 1, 3)}
for nm in [nm for nm in E.clips if nm not in keep]:
    E.clips.pop(nm)
    print('  unused clip %s removed' % nm)
for a in [a for a in E.area if a not in used]:
    shutil.rmtree(os.path.join(SRC, a))
    E.area.pop(a)
    E.pivots.pop(a)
    print('  unused anim %s removed' % a)

clips, pivots, area = dict(E.clips), dict(E.pivots), dict(E.area)
meta = {}

# ---------------------------------------------------------------- pictures drawn into the bitmaps of Game
E1 = C.Exporter(G1, SRC, 'b', {})


def pictures(name, cmd_lists, origin):
    """single pictures at 1 px per Flash pixel, their pivot at `origin` (Flash coordinates of the clip)"""
    rd = R.Renderer(G1, 1)
    imgs = []
    bb = (origin[0], origin[1], origin[0] + 1, origin[1] + 1)
    for cmds in cmd_lists:
        b = rd.bounds(cmds)
        bb = (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    import math
    ox, oy = math.floor(bb[0]), math.floor(bb[1])
    w, h = int(math.ceil(bb[2])) - ox, int(math.ceil(bb[3])) - oy
    for cmds in cmd_lists:
        cv = np.zeros((h, w, 4), dtype=np.float32)
        rd.draw(cmds, cv, (ox, oy))
        imgs.append(Image.fromarray(np.clip(cv * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa').convert('RGBA'))
    E1.write_anim(name, imgs, (-ox, -oy))
    pivots[name] = E1.pivots[name]
    area[name] = E1.area[name]


def sprite_frames(sid, cx=R.NOCX):
    out = []
    for f in range(1, G1.sprites[sid].nframes + 1):
        inst = R.Instance(G1, sid, ctrl={sid: f, '__noactions__': True})
        cmds = []
        R.Renderer(G1, 1).collect(inst, R.IDENT, cx, set(), cmds)
        out.append(cmds)
    return out


# mcSquare: frame 2 = brick (smc 1107, 66 frames), 3 = plank (smc 1121, 40 frames, yscale 1.0121), ladder (1079)
def square_smc(sq_frame, cx):
    inst = R.Instance(G1, 1122, ctrl={1122: sq_frame, '__noactions__': True})
    e = [e for e in inst.display.values() if e['name'] == 'smc'][0]
    out = []
    for f in range(1, G1.sprites[e['char']].nframes + 1):
        sub = R.Instance(G1, e['char'], ctrl={e['char']: f, '__noactions__': True})
        cmds = []
        R.Renderer(G1, 1).collect(sub, {k: e['matrix'][k] for k in e['matrix']}, R.cx_mul(cx, e['cx']), set(), cmds)
        out.append(cmds)
    return out


pictures('tileBrick', square_smc(2, R.NOCX), (0, 0))                 # the tower
pictures('tileBrickD', square_smc(2, DARK), (0, 0))                  # the level: Col.setColor(mc.smc, 0, -30)
pictures('tilePlankD', square_smc(3, DARK), (0, 0))
inst = R.Instance(G1, 1122, ctrl={1122: 1, '__noactions__': True})
lad = [e for e in inst.display.values() if e['name'] == 'ladder'][0]
cmds = []
R.Renderer(G1, 1).collect(R.Instance(G1, lad['char'], ctrl={'__noactions__': True}), lad['matrix'], lad['cx'], set(), cmds)
pictures('tileLadder', [cmds], (0, 0))
# mcTiles: its smc (sprite 33, 193 frames of 10 x 10), mcWindow
pictures('bgTile', sprite_frames(33), (0, 0))
pictures('bgWindow', sprite_frames(142), (0, 0))
meta['nTiles'] = G1.sprites[33].nframes
meta['nBrick'] = G1.sprites[1107].nframes
meta['nPlank'] = G1.sprites[1121].nframes

# mcBg (shape 1123, a vector gradient): Game.initBg draws it, then fills each band of 15 px with the colour of its
# pixel (0, (i + 0.5) * 15)
sky = Image.open(W + 'shp1_gfx/1123.png').convert('RGB')
x0, x1, y0, y1 = G1.shapes[1123]
assert (x0, y0) == (0.0, 0.0) and sky.size == (300, 300), (G1.shapes[1123], sky.size)
meta['sky'] = ['0x%06X' % ((lambda p: (p[0] << 16) | (p[1] << 8) | p[2])(sky.getpixel((0, int((i + 0.5) * 15)))))
               for i in range(20)]
print('sky', meta['sky'])

json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
json.dump(clips, open(os.path.join(OUT, 'clips.json'), 'w'), separators=(',', ':'))
json.dump(pivots, open(os.path.join(OUT, 'pivots.json'), 'w'), indent=0)
tot = sum(area.values())
print('clips %d, anims %d, trimmed area %.2f Mpx, warnings %d' % (len(clips), len(area), tot / 1e6, E.warnings))
for k, v in sorted(area.items(), key=lambda x: -x[1])[:30]:
    print('  %-24s %8d px' % (k, v))
