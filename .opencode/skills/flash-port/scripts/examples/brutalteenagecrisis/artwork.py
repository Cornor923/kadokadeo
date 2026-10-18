"""Brutal Teenage Crisis: start screen public/assets/img/gfx/artwork/brutalteenagecrisis.jpg (600 x 460, the game area
of an Arkadeo game), like the thumbnail of the game: the level drawn by the port, darkened, the logo under the hero.
usage: artwork.py <level png (artwork.mjs)> <logo.png of btc/web> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance

level, logo, out = sys.argv[1:4]
bg = Image.open(level).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.6)
lg = Image.open(logo).convert('RGBA')
bg.paste(lg, ((600 - lg.width) // 2, (460 - lg.height) // 2 + 45), lg)
bg.save(out, quality=90)
print(out, bg.size)
