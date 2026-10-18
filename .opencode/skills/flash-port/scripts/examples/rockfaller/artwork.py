"""Rock Faller: start screen public/assets/img/gfx/artwork/rockfaller.jpg (600 x 460, the game area of an Arkadeo game):
the board drawn by the port, darkened, the name of the game in the font of the original (Alba) over it.
usage: artwork.py <board png (artwork.mjs)> <title png (out/art/title.png of rockfaller_assets.py)> <out jpg>
"""
import sys
from PIL import Image, ImageEnhance, ImageFilter, ImageChops

board, title, out = sys.argv[1:4]
bg = Image.open(board).convert('RGB').resize((600, 460))
bg = ImageEnhance.Brightness(bg).enhance(0.55).convert('RGBA')
t = Image.open(title).convert('RGBA')
pad = 16
a = Image.new('L', (t.width + 2 * pad, t.height + 2 * pad), 0)
a.paste(t.split()[3], (pad, pad))
# a dark outline (the alpha grown by 4 px) and a soft shadow under the white letters
outline = a.filter(ImageFilter.MaxFilter(9))
shadow = outline.filter(ImageFilter.GaussianBlur(6))
x, y = (600 - a.width) // 2, (460 - a.height) // 2
for mask, colour in ((shadow, (0, 0, 0, 200)), (outline, (40, 24, 12, 255))):
    layer = Image.new('RGBA', a.size, colour[:3] + (0,))
    layer.putalpha(ImageChops.multiply(mask, Image.new('L', a.size, colour[3])))
    bg.alpha_composite(layer, (x, y))
bg.alpha_composite(t, (x + pad, y + pad))
bg.convert('RGB').save(out, quality=90)
print(out, bg.size)
