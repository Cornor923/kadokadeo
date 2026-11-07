"""Trigo: start screen public/assets/img/gfx/artwork/trigo.jpg (600 x 460, the game area of an Arkadeo game): the game
drawn by the port at its start (artwork.mjs), darkened, the logo of the game (gfx.Logo, rendered by trigo_assets.py) in its
middle.
usage: artwork.py <game png (artwork.mjs)> <logo png (out/title/logo.png)> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance

game, logo, out = sys.argv[1:4]
bg = Image.open(game).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.6)
lg = Image.open(logo).convert('RGBA')
bg.paste(lg, ((600 - lg.width) // 2, (460 - lg.height) // 2), lg)
bg.save(out, quality=90)
print(out, bg.size)
