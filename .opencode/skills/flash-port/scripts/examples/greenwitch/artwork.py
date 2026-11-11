"""Green Witch: start screen public/assets/img/gfx/artwork/greenwitch.jpg (600 x 460, the game area of an Arkadeo game): a
dungeon drawn by the port (artwork.mjs), darkened, the title of the game (assets/title.png of the original, the picture of
its TitleLogo) in its middle.
usage: artwork.py <dungeon png (artwork.mjs)> <Arkadeo/games/greenWitch/assets/title.png> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance

scene, logo, out = sys.argv[1:4]
bg = Image.open(scene).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.6)
lg = Image.open(logo).convert('RGBA')
bg.paste(lg, ((600 - lg.width) // 2, (460 - lg.height) // 2), lg)
bg.save(out, quality=90)
print(out, bg.size)
