"""Start screen of Mel (public/assets/img/gfx/artwork/mel.jpg, 600 x 460: the game area of an Arkadeo game) and the
picture of the list of games (public/assets/img/games/Mel.png, 176 x 106), composed from renders of game.swf: the
background of the game (gfx.Background), Mel, a few grabbers and pulpz, the logo (gfx.Title).
usage: mel_artwork.py <artwork.jpg> <thumbnail.png>"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
from PIL import Image, ImageFilter
import swfrender as R

W = os.path.join(os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port')), 'mel', '')
G = R.SWF(W + 'game.swf', W + 'shp4_game', Z=4)
G.flash_replace = True
RENAME = {'smc_': 'smc', 'wr_': 'wr', 'wl_': 'wl'}
for sd in G.sprites.values():
    hd = set()
    for ops in sd.frames:
        for k, v in ops:
            if k == 'place' and v.get('name') == '_hit':
                hd.add(v['depth'])
    if hd:
        for i, ops in enumerate(sd.frames):
            sd.frames[i] = [(k, v) for k, v in ops if not ((k == 'place' and v['depth'] in hd) or (k == 'remove' and v in hd))]


def render(sid, frame=1, scale=1.0, ctrl=None):
    ct = {sid: frame, '__noactions__': True}
    if ctrl:
        ct.update(ctrl)
    inst = R.Instance(G, sid, ctrl=ct)
    imgs, reg = R.Renderer(G, scale).render_frames([inst], margin=2)
    return imgs[0], reg


def paste(canvas, sid, x, y, scale=1.0, frame=1, ctrl=None, flip=False, alpha=1.0):
    im, reg = render(sid, frame, scale, ctrl)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
        reg = (im.width - reg[0], reg[1])
    if alpha < 1:
        a = im.split()[3].point(lambda v: int(v * alpha))
        im.putalpha(a)
    canvas.alpha_composite(im, (int(round(x - reg[0])), int(round(y - reg[1]))))


bg, reg = render(576, 1, 1.0)
art = Image.new('RGBA', (600, 460), (0, 0, 0, 255))
art.alpha_composite(bg, (int(-reg[0]), int(-reg[1])))
# a few enemies in the city, Mel jumping
paste(art, 438, 470, 300, 1.4)
paste(art, 438, 110, 380, 1.1, flip=True)
paste(art, 402, 520, 420, 2.0)
paste(art, 402, 80, 250, 1.3)
paste(art, 402, 420, 430, 1.0)
paste(art, 305, 300, 445, 2.2, frame=3, ctrl={292: 12})
# the logo
title = Image.open(W + 'out/title.png').convert('RGBA')
k = 0.95
title = title.resize((int(title.width * k), int(title.height * k)), Image.LANCZOS)
art.alpha_composite(title, ((600 - title.width) // 2, 10))
art.convert('RGB').save(sys.argv[1], quality=92)
th = art.convert('RGB').resize((176, int(round(460 * 176 / 600))), Image.LANCZOS)
out = Image.new('RGB', (176, 106))
out.paste(th, (0, (106 - th.height) // 2))
th2 = art.convert('RGB').crop((0, (460 - 600 * 106 // 176) // 2, 600, (460 - 600 * 106 // 176) // 2 + 600 * 106 // 176)).resize((176, 106), Image.LANCZOS)
th2.save(sys.argv[2])
print('ok', art.size)
