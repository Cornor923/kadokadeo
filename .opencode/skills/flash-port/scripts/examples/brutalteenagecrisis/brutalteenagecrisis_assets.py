"""Brutal Teenage Crisis (Arkadeo): atlases of the game -> single images + data for the KadoKadeo sheet.

The game is not a SWF: its graphics are the original SpriteLib atlases of the Arkadeo game (`btc/web` of the
Arkadeo port): `sheet.png` + `sheet.xml` (ShoeBox) + `sheet.anims.xml`, `backgrounds.png` + `backgrounds.xml`
(TexturePacker), and the collision map `testLevel.png`.

usage: brutalteenagecrisis_assets.py <btc/web folder> <out folder>
writes:
  out/src/<group>/<n>.png      one picture per frame of sheet.xml, grouped like the runtime ShoeBox.importXml did
                               (group = name without its trailing number and "_", frame = that number)
  out/src/bgs/<group>/<n>.png  the frames of backgrounds.xml used by the game (TexturePacker.importXml rules)
  out/pivots.json              {} : the pivots are set by the game (BSprite.setCenter / setPivotCoord), anchors at 0
  out/meta.json                anim definitions, collision map, attach points (see brutalteenagecrisis_data.py)
"""
import os, re, sys, json, shutil
import xml.etree.ElementTree as ET
from PIL import Image
import numpy as np

SRC, OUT = sys.argv[1], sys.argv[2]
# groups of backgrounds.xml the game reads (Level.render: "bg"); the "texture*" groups are never used
BG_GROUPS = ['bg']
# colours searched by Hero in its frames (Hero.HAIR_ATTACH / CHAIN_ATTACH, getColorBoundsRect)
ATTACH = {'hair': (0x00, 0xbd, 0xff), 'chain': (0x18, 0xff, 0xf7)}
# collision map of the League (Level.readFromFile(0)): 23 columns, 17 rows + the row under the last one
LWID, LHEI = 23, 17

shutil.rmtree(os.path.join(OUT, 'src'), ignore_errors=True)
os.makedirs(os.path.join(OUT, 'src'))


def save(img, rel):
    path = os.path.join(OUT, 'src', rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


# ---------------------------------------------------------------- sheet.xml (ShoeBox.importXml)
sheet = Image.open(os.path.join(SRC, 'sheet.png')).convert('RGBA')
groups = {}
attach = {k: {} for k in ATTACH}
for st in ET.parse(os.path.join(SRC, 'sheet.xml')).getroot().iter('SubTexture'):
    name = re.sub(r'\.(png|gif|jpeg|jpg)', '', st.get('name'), flags=re.I)
    x, y, w, h = (int(st.get(k)) for k in ('x', 'y', 'width', 'height'))
    m = re.search(r'([0-9]*)$', name)
    if m.group(1):
        group, frame = name[:m.start()].rstrip('_'), int(m.group(1))
    else:
        group, frame = name, 0
    if frame in groups.setdefault(group, {}):
        raise SystemExit('frame twice: %s %d' % (group, frame))
    groups[group][frame] = (w, h)
    crop = sheet.crop((x, y, x + w, y + h))
    save(crop, '%s/%d.png' % (group, frame))
    px = np.array(crop)
    for k, (r, g, b) in ATTACH.items():
        ys, xs = np.nonzero((px[..., 0] == r) & (px[..., 1] == g) & (px[..., 2] == b) & (px[..., 3] == 255))
        if len(xs):
            attach[k]['%s#%d' % (group, frame)] = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]

lower = {}
for g in groups:
    if g.lower() in lower:
        raise SystemExit('groups differing only by case (one folder on Windows / macOS): %s %s' % (g, lower[g.lower()]))
    lower[g.lower()] = g

anims = []
for a in ET.parse(os.path.join(SRC, 'sheet.anims.xml')).getroot().iter('a'):
    anims.append(dict(g=a.get('group'), d=(a.text or '').strip(), t=int(a.get('timing')) if a.get('timing') else None))

# ---------------------------------------------------------------- backgrounds.xml (TexturePacker.importXml)
bgs = Image.open(os.path.join(SRC, 'backgrounds.png')).convert('RGBA')
bg_frames = {}
seen = {}
for st in ET.parse(os.path.join(SRC, 'backgrounds.xml')).getroot().iter('SubTexture'):
    name = re.sub(r'\.(png|gif|jpeg|jpg)', '', st.get('name'), flags=re.I)
    name = name[name.rfind('/') + 1:]
    name = re.sub(r'[0-9]*$', '', name).rstrip('_')
    x, y, w, h = (int(st.get(k)) for k in ('x', 'y', 'width', 'height'))
    if any(st.get(k) for k in ('frameX', 'frameY', 'frameWidth', 'frameHeight')):
        raise SystemExit('trimmed frame in backgrounds.xml (realFrame not handled): %s' % st.get('name'))
    if name not in BG_GROUPS:
        continue
    key = (name, x, y, w, h)
    if key in seen:
        continue
    frame = bg_frames.setdefault(name, 0)
    seen[key] = frame
    bg_frames[name] = frame + 1
    save(bgs.crop((x, y, x + w, y + h)), 'bgs/%s/%d.png' % (name, frame))

# ---------------------------------------------------------------- testLevel.png (Level.readFromFile)
lvl = np.array(Image.open(os.path.join(SRC, 'testLevel.png')).convert('RGB')).astype(np.int64)
rows = []
for y in range(LHEI + 1):
    row = ''
    for x in range(LWID):
        v = (lvl[y, x, 0] << 16) | (lvl[y, x, 1] << 8) | lvl[y, x, 2]
        row += '#' if v == 0xFFFFFF else 'H' if v == 0xFF0000 else '.'
    rows.append(row)

json.dump({}, open(os.path.join(OUT, 'pivots.json'), 'w'))
json.dump(dict(anims=anims, level=rows, attach=attach,
               groups={g: max(f) + 1 for g, f in groups.items()}, bgs=bg_frames),
          open(os.path.join(OUT, 'meta.json'), 'w'), indent=1, sort_keys=True)

print('%d groups, %d frames, backgrounds %s, %d anims, attach hair %d chain %d' % (
    len(groups), sum(len(f) for f in groups.values()), bg_frames, len(anims), len(attach['hair']), len(attach['chain'])))
print('\n'.join(rows))
