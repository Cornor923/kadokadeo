# The icon of the rankings of the clans (the podium of public/assets/img/gfx/icons/clan_score.gif) in SVG, pixel for pixel:
# one path by colour of the GIF. --color gives another dominant colour (the fill of the bars, #CFFB6A in the GIF): every
# colour keeps its shift of hue, its saturation and its lightness relative to the dominant one, the white halo stays white.
# Needs ImageMagick (magick).
#   python3 scripts/clan_rank_icon.py                                  public/gfx/clan/clan_rank.svg, as the GIF
#   python3 scripts/clan_rank_icon.py --color '#d78bf0' -o public/gfx/clan/clan_rank_missions.svg
import argparse
import colorsys
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GIF = os.path.join(ROOT, 'public/assets/img/gfx/icons/clan_score.gif')
DOMINANT = '#CFFB6A'


def pixels():
    txt = subprocess.run(['magick', GIF, '-coalesce', 'txt:-'], capture_output=True, text=True, check=True).stdout
    size = re.match(r'# ImageMagick pixel enumeration: (\d+),(\d+)', txt)
    width, height = int(size.group(1)), int(size.group(2))
    grid = {}
    for line in txt.splitlines()[1:]:
        m = re.match(r'(\d+),(\d+):.*?#([0-9A-F]{6})([0-9A-F]{2})', line)
        x, y, rgb, alpha = int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)
        if alpha != '00':
            grid[x, y] = '#' + rgb
    return width, height, grid


def hls(color):
    return colorsys.rgb_to_hls(*(int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)))


def recolor(color, target):
    if color == '#FFFFFF' or target is None:
        return color
    h, l, s = hls(color)
    dh, dl, ds = hls(DOMINANT)
    th, tl, ts = hls(target)
    # the lightness: darker or lighter than the dominant colour in the same proportion, white and black stay
    nl = l * tl / dl if l <= dl else tl + (l - dl) * (1 - tl) / (1 - dl)
    ns = min(1, s * ts / ds) if ds else ts
    r, g, b = colorsys.hls_to_rgb((th + h - dh) % 1, nl, ns)
    return '#{:02X}{:02X}{:02X}'.format(*(round(c * 255) for c in (r, g, b)))


def svg(target=None):
    width, height, grid = pixels()
    # the pixels of a colour, a rectangle by run of a row
    runs = {}
    for y in range(height):
        x = 0
        while x < width:
            color = grid.get((x, y))
            if color is None:
                x += 1
                continue
            end = x
            while grid.get((end + 1, y)) == color:
                end += 1
            runs.setdefault(color, []).append(f'M{x} {y}h{end - x + 1}v1h-{end - x + 1}z')
            x = end + 1
    paths = '\n'.join(f'  <path fill="{recolor(color, target)}" d="{"".join(d)}"/>' for color, d in sorted(runs.items()))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" '
            f'shape-rendering="crispEdges">\n{paths}\n</svg>\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--color', help='the dominant colour (#RRGGBB), the one of the GIF by default')
    parser.add_argument('-o', '--out', default=os.path.join(ROOT, 'public/gfx/clan/clan_rank.svg'))
    args = parser.parse_args()
    open(args.out, 'w').write(svg(args.color.upper() if args.color else None))
    print(args.out)
