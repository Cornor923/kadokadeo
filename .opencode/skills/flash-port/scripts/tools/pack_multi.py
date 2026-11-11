"""Multipack sprite sheet builder producing TexturePacker "pixijs4" JSON files.

- trim (1px margin), 1px extrude, identical frames aliased (autoAlias)
- skyline packing on sheets of at most MAX x MAX; the first sheet holds every animation and every
  sheet lists the others in meta.related_multi_packs (like TexturePacker MultiPackAuto)
- PACK_SCALE: pixels of the images per pixel of their textures (meta.scale of every sheet: PIXI gives the textures
  their size divided by it), images drawn finer than the pixels of the game. One scale for all the sheets: the
  spritesheets of the old versions (resources/js/games/builds/atlas.mjs) take the scale of the first one
usage: pack_multi.py <src dir> <out base name (…/name)> <pivots.json>
"""
import os, sys, re, json, hashlib
import numpy as np
from PIL import Image

SRC, OUT_BASE, PIVOTS_FILE = sys.argv[1], sys.argv[2], sys.argv[3]
MAX = int(os.environ.get('PACK_MAX', '2048'))
SCALE = os.environ.get('PACK_SCALE', '1')
EXT = 1
MARGIN = 1
pivots = json.load(open(PIVOTS_FILE))


def natural_key(s):
    return [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', s)]


items = []
for root, _, files in os.walk(SRC):
    for f in files:
        if f.lower().endswith('.png'):
            full = os.path.join(root, f)
            name = os.path.relpath(full, SRC).replace('\\', '/')
            items.append((name, full))
items.sort(key=lambda t: natural_key(t[0]))

sprites = []
unique = {}
for name, full in items:
    im = Image.open(full).convert('RGBA')
    bb = im.split()[3].getbbox()
    if bb is None:
        rect = (0, 0, min(2, im.width), min(2, im.height))
        crop = Image.new('RGBA', (rect[2], rect[3]), (0, 0, 0, 0))
    else:
        rect = (max(0, bb[0] - MARGIN), max(0, bb[1] - MARGIN), min(im.width, bb[2] + MARGIN), min(im.height, bb[3] + MARGIN))
        crop = im.crop(rect)
    # clear fully transparent pixels before hashing
    arr = np.array(crop)
    arr[arr[..., 3] == 0] = 0
    crop = Image.fromarray(arr, 'RGBA')
    h = hashlib.sha1(crop.tobytes() + bytes(str(crop.size), 'ascii')).hexdigest()
    group = name.rsplit('/', 1)[0] if '/' in name else name[:-4]
    s = dict(name=name, rect=rect, src=im.size, group=group, hash=h)
    if h not in unique:
        unique[h] = dict(img=crop, w=crop.width + 2 * EXT, h=crop.height + 2 * EXT)
    sprites.append(s)

# ---------------------------------------------------------------- skyline packing in sheets
order = sorted(unique.keys(), key=lambda k: (-unique[k]['h'], -unique[k]['w']))
sheets = []
left = order
while left:
    sky = [[0, 0, MAX]]  # x, y, width
    placed = {}
    rest = []
    for k in left:
        w, h = unique[k]['w'], unique[k]['h']
        best = None
        for i in range(len(sky)):
            x = sky[i][0]
            if x + w > MAX:
                break
            # max y over the segments covered by [x, x+w)
            y = 0
            j = i
            rem = w
            while rem > 0:
                if j >= len(sky):
                    y = None
                    break
                y = max(y, sky[j][1])
                rem -= sky[j][2] - (x - sky[j][0] if j == i else 0)
                j += 1
            if y is None or y + h > MAX:
                continue
            if best is None or (y + h, x) < (best[1] + h, best[0]):
                best = (x, y, i)
        if best is None:
            rest.append(k)
            continue
        x, y, i = best
        placed[k] = (x, y)
        # update skyline
        new = [x, y + h, w]
        nsky = []
        for seg in sky:
            sx, sy, sw = seg
            if sx + sw <= x or sx >= x + w:
                nsky.append(seg)
                continue
            if sx < x:
                nsky.append([sx, sy, x - sx])
            if sx + sw > x + w:
                nsky.append([x + w, sy, sx + sw - (x + w)])
        nsky.append(new)
        nsky.sort(key=lambda s: s[0])
        merged = []
        for seg in nsky:
            if merged and merged[-1][1] == seg[1] and merged[-1][0] + merged[-1][2] == seg[0]:
                merged[-1][2] += seg[2]
            else:
                merged.append(seg)
        sky = merged
    if not placed:
        raise SystemExit('sprite too big: %s' % [unique[k]['w'] for k in rest[:3]])
    W = max(x + unique[k]['w'] for k, (x, y) in placed.items())
    H = max(y + unique[k]['h'] for k, (x, y) in placed.items())
    sheets.append(dict(placed=placed, W=W, H=H))
    left = rest

loc = {}
base = os.path.basename(OUT_BASE)
for si, sh in enumerate(sheets):
    atlas = Image.new('RGBA', (sh['W'], sh['H']), (0, 0, 0, 0))
    for k, (x, y) in sh['placed'].items():
        img = unique[k]['img']
        w, h = img.size
        ext = Image.new('RGBA', (w + 2 * EXT, h + 2 * EXT), (0, 0, 0, 0))
        ext.paste(img, (EXT, EXT))
        for e in range(EXT):
            ext.paste(img.crop((0, 0, w, 1)), (EXT, e))
            ext.paste(img.crop((0, h - 1, w, h)), (EXT, EXT + h + e))
        for e in range(EXT):
            ext.paste(ext.crop((EXT, 0, EXT + 1, h + 2 * EXT)), (e, 0))
            ext.paste(ext.crop((EXT + w - 1, 0, EXT + w, h + 2 * EXT)), (EXT + w + e, 0))
        atlas.paste(ext, (x, y))
        loc[k] = (si, x + EXT, y + EXT, w, h)
    atlas.save('%s-%d.png' % (OUT_BASE, si), optimize=True)
    sh['file'] = '%s-%d' % (base, si)

anims = {}
for s in sprites:
    m = re.match(r'^(.*)/(\d+)\.png$', s['name'])
    if m:
        anims.setdefault(m.group(1), []).append(s['name'])


def num(v):
    return ('%.6f' % v).rstrip('0').rstrip('.') if isinstance(v, float) else str(v)


def j(o):
    return json.dumps(o, separators=(',', ':'))


for si, sh in enumerate(sheets):
    frames = [s for s in sprites if loc[s['hash']][0] == si]
    lines = ['{"frames": {', '']
    for i, s in enumerate(frames):
        _, x, y, w, h = loc[s['hash']]
        rx, ry, rx2, ry2 = s['rect']
        sw, shh = s['src']
        ax, ay = pivots.get(s['group'], [0, 0])
        lines += ['"%s":' % s['name'], '{',
                  '\t"frame": %s,' % j(dict(x=x, y=y, w=w, h=h)),
                  '\t"rotated": false,',
                  '\t"trimmed": %s,' % ('true' if (rx, ry, rx2, ry2) != (0, 0, sw, shh) else 'false'),
                  '\t"spriteSourceSize": %s,' % j(dict(x=rx, y=ry, w=w, h=h)),
                  '\t"sourceSize": %s,' % j(dict(w=sw, h=shh)),
                  '\t"anchor": {"x":%s,"y":%s}' % (num(float(ax)), num(float(ay))),
                  '}' + (',' if i < len(frames) - 1 else '')]
    lines.append('},')
    if si == 0:
        lines.append('"animations": {')
        keys = sorted(anims)
        for i, k in enumerate(keys):
            lines.append('\t"%s": [%s]%s' % (k, ','.join('"%s"' % n for n in anims[k]), ',' if i < len(keys) - 1 else ''))
        lines.append('},')
    others = ['%s.json' % o['file'] for o in sheets if o is not sh]
    lines += ['"meta": {',
              '\t"app": "https://www.codeandweb.com/texturepacker",',
              '\t"version": "1.1",',
              '\t"image": "%s.png",' % sh['file'],
              '\t"format": "RGBA8888",',
              '\t"size": {"w":%d,"h":%d},' % (sh['W'], sh['H']),
              '\t"scale": "%s"' % SCALE + (',' if others else '')]
    if others:
        lines.append('\t"related_multi_packs": [%s]' % ', '.join('"%s"' % o for o in others))
    lines += ['}', '}']
    open('%s-%d.json' % (OUT_BASE, si), 'w', newline='\n').write('\n'.join(lines) + '\n')
    json.load(open('%s-%d.json' % (OUT_BASE, si)))

print('%d frames, %d unique, %d sheets%s: %s' % (len(sprites), len(unique), len(sheets), '' if SCALE == '1' else ' at scale ' + SCALE,
                                                ', '.join('%dx%d' % (s['W'], s['H']) for s in sheets)))
