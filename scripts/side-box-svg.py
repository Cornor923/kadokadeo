#!/usr/bin/env python3
"""The backgrounds of the titles and of the boxes (public/gfx/bgTitle<Color>.svg, bgContainerTop<Color>.svg), drawn in
SVG from two colours each, instead of the former JPGs (the profiles below were measured on them, the same for every
colour):
  - the title (890 x 35, the h2 of the site and of the boxes of the side column): a square in the vivid colour, then
    a bar in the light one, both shaded by the same vertical profile (the colour mixed with white, a darker lower half),
    the bar faded to white towards its right end;
  - the top of a box (954 x 154, the boxes of the side column, #bodySection): the background colour, lighter at the
    top, and a curved band from the top right in the tint, fading to the background downwards, with a white highlight
    along the curve.
A background image can't read the CSS variables of the page: a new colour is a new pair of files, made by this script.

Usage: python3 scripts/side-box-svg.py [color...]   (default: every color)
"""
import os
import sys

# title: vivid colour of the square, light colour of the bar
# box: background colour (the bottom of the image, close to the background-color of the box), tint of the curved band
PALETTES = {
    'Blue': {'vivid': '#00c2fc', 'light': '#9ee8fe', 'background': '#eaf8fb', 'tint': '#c8ebef'},
    'Green': {'vivid': '#86f101', 'light': '#cbf993', 'background': '#f3ffd7', 'tint': '#d4ff7a'},
    'Pink': {'vivid': '#fd0237', 'light': '#ffdbe3', 'background': '#fff3f7', 'tint': '#ffd6e4'},
    # the pink ones turned to the purple of the missions (public/gfx/clan/clan_mission_points.png)
    'Violet': {'vivid': '#c11adf', 'light': '#f6dffa', 'background': '#fbf3fe', 'tint': '#f2dafc'},
}

# the title: share of the colour (mixed with white) of each of the 35 rows
TITLE_ROWS = [.61, .23, .12, .14, .16, .18, .18, .20, .23, .24, .25, .27, .29, .31, .33, .34, .35, .37, .47, .89, .99,
              .97, .94, .93, .90, .87, .85, .82, .80, .78, .75, .72, .71, .69, .57]
TITLE_WIDTH, TITLE_HEIGHT, SQUARE = 890, 35, 33
# the bar keeps its colour up to FADE_FROM, then fades to FADE_TO of it at its end
FADE_FROM, FADE_TO = 240, .22

# the box: share of the background colour (mixed with white) from the top, share of the tint (mixed with the background)
# in the band from its top; (y, share)
BOX_WIDTH, BOX_HEIGHT = 954, 154
BOX_BACKGROUND = [(0, .42), (14, .45), (28, .62), (49, .7), (70, .88), (98, 1)]
BOX_BAND = [(6, 1), (28, .92), (56, .74), (84, .5), (112, .3), (140, .15), (154, .12)]
# the curve of the band (fitted on the JPGs: 0.6 px)
BOX_CURVE = 'M90 154C275 40 625 15 954 4'


def rgb(c):
    return [int(c[i:i + 2], 16) for i in (1, 3, 5)]


def mix(a, b, share):
    """a mixed with b, `share` of b."""
    return '#' + ''.join(f'{round(x + (y - x) * share):02x}' for x, y in zip(rgb(a), rgb(b)))


def fmt(v):
    return f'{v:.4f}'.rstrip('0').rstrip('.') or '0'


def title(p):
    def rows(gid, color):
        stops = ''.join(f'<stop offset="{fmt((y + .5) / TITLE_HEIGHT)}" stop-color="{color}" stop-opacity="{t}"/>'
                        for y, t in enumerate(TITLE_ROWS))
        return f'<linearGradient id="{gid}" x2="0" y2="1">{stops}</linearGradient>'
    fade_from = (FADE_FROM - SQUARE) / (TITLE_WIDTH - SQUARE)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{TITLE_WIDTH}" height="{TITLE_HEIGHT}" viewBox="0 0 {TITLE_WIDTH} {TITLE_HEIGHT}">'
            f'<defs>{rows("s", p["vivid"])}{rows("b", p["light"])}'
            f'<linearGradient id="f"><stop offset="{fmt(fade_from)}" stop-color="#fff" stop-opacity="0"/>'
            f'<stop offset="1" stop-color="#fff" stop-opacity="{fmt(1 - FADE_TO)}"/></linearGradient></defs>'
            f'<rect width="{TITLE_WIDTH}" height="{TITLE_HEIGHT}" fill="#fff"/>'
            f'<rect width="{SQUARE}" height="{TITLE_HEIGHT}" fill="url(#s)"/>'
            f'<rect x="{SQUARE}" width="{TITLE_WIDTH - SQUARE}" height="{TITLE_HEIGHT}" fill="url(#b)"/>'
            f'<rect x="{SQUARE}" width="{TITLE_WIDTH - SQUARE}" height="{TITLE_HEIGHT}" fill="url(#f)"/></svg>\n')


def box(p):
    background = ''.join(f'<stop offset="{fmt(y / BOX_HEIGHT)}" stop-color="{mix("#ffffff", p["background"], s)}"/>'
                         for y, s in BOX_BACKGROUND)
    band = ''.join(f'<stop offset="{fmt(y / BOX_HEIGHT)}" stop-color="{mix(p["background"], p["tint"], s)}"/>'
                   for y, s in BOX_BAND)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{BOX_WIDTH}" height="{BOX_HEIGHT}" viewBox="0 0 {BOX_WIDTH} {BOX_HEIGHT}">'
            f'<defs><linearGradient id="g" x2="0" y2="1">{background}</linearGradient>'
            f'<linearGradient id="b" x2="0" y2="{BOX_HEIGHT}" gradientUnits="userSpaceOnUse">{band}</linearGradient></defs>'
            f'<rect width="{BOX_WIDTH}" height="{BOX_HEIGHT}" fill="url(#g)"/>'
            f'<path d="{BOX_CURVE}V{BOX_HEIGHT}Z" fill="url(#b)"/>'
            f'<path d="{BOX_CURVE}" transform="translate(0 -1.5)" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="1.5"/></svg>\n')


if __name__ == '__main__':
    root = os.environ.get('GFX_DIR') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'public', 'gfx')
    for color in sys.argv[1:] or PALETTES:
        with open(os.path.join(root, f'bgTitle{color}.svg'), 'w') as f:
            f.write(title(PALETTES[color]))
        with open(os.path.join(root, f'bgContainerTop{color}.svg'), 'w') as f:
            f.write(box(PALETTES[color]))
