"""Fafi 360: start screen public/assets/img/gfx/artwork/fafi360.jpg (600 x 460, the game area of an Arkadeo game): the
match drawn by the port (artwork.mjs), darkened, the logo of the game (lib.TitleLogo, last frame, rendered by
fafi360_assets.py) in its middle.
usage: artwork.py <match png (artwork.mjs)> <title png (out/title/8.png)> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance

match, logo, out = sys.argv[1:4]
bg = Image.open(match).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.6)
lg = Image.open(logo).convert('RGBA')
bg.paste(lg, ((600 - lg.width) // 2, (460 - lg.height) // 2), lg)
bg.save(out, quality=90)
print(out, bg.size)
