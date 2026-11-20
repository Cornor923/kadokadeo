"""Charlotte's Quest: start screen public/assets/img/gfx/artwork/charlottesquest.jpg (600 x 460, the game area of an Arkadeo
game): the start of a game drawn by the port (artwork.mjs), a little darkened, the title of the game (lib.Title of the SWF,
out/src/Title/1.png of charlottesquest_assets.py) over it.
usage: artwork.py <scene png (artwork.mjs)> <out/src/Title/1.png> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance

scene, logo, out = sys.argv[1:4]
bg = Image.open(scene).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.75)
lg = Image.open(logo).convert('RGBA')
bg.paste(lg, ((600 - lg.width) // 2, 460 - lg.height - 40), lg)
bg.save(out, quality=90)
print(out, bg.size)
