#!/usr/bin/env python3
"""Vector redraw of the score digits (public/gfx/typo/<color>/*.svg, from the former GIFs).

The GIFs were Trebuchet MS Bold digits with an outline and an emboss. Each SVG
takes the glyph outline from the font, laid out in the GIF's pixel grid (same
height, scale and baseline fitted on the GIFs; like the GIFs, each image is
cropped to its drawing, see GAPS):
  - outline: the glyph stroked behind the body;
  - body color, thickened a bit at the small size (the 15px GIFs are bolder than
    the font), embossed by a filter like the original bitmaps: the blurred body
    alpha is the height map, its difference with a copy shifted along the light
    gives the slope. Faces turned to the light get the light color *added* (blue
    goes 3ac2dd -> 73fbff -> 8fffff -> fff, orange ffc600 -> ffd40e -> ffff47 ->
    ffffd4: the light tops out at d4d4d4), the gamma keeps it on the faces right
    under the light; faces turned away are blended towards the outline color
    (2bafca, 1493ac...). Every filter value is in GIF pixels, so the bevel scales
    with the digit.

Needs fontTools (pip install fonttools) and the font (macOS path by default,
TREBUCHET_BOLD=/path/to/trebucbd.ttf otherwise).

Usage: python3 typo-svg.py [color...]   (default: every color; TYPO_DIR=... to write elsewhere)
"""
import os
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONT = os.environ.get('TREBUCHET_BOLD', '/System/Library/Fonts/Supplemental/Trebuchet MS Bold.ttf')
# (the minus sign of the font, as wide as the plus, not the shorter hyphen)
CHARS = {**{str(i): str(i) for i in range(10)}, 'dot': '.', 'x': 'x', 'plus': '+', 'minus': '\u2212'}

# Like the GIFs, each image is cropped to its drawing (outline included), with a small gap
# on the left of 4, 6, 7, 8 and 9 and on both sides of the dot, the x and the signs: (left, right) in gaps.
GAPS = {**{c: (0, 0) for c in '01235'}, **{c: (1, 0) for c in '46789'}, **{c: (1, 1) for c in ('dot', 'x', 'plus', 'minus')}}

# GIF layout: font scale (px per font unit), baseline, outline stroke width, body thickening, gap,
# and margin added on both sides of every glyph
SMALL = {'height': 15, 'scale': .0074, 'baseline': 12.9, 'outline': 1.5, 'bold': .55, 'gap': .45,
         'margin': float(os.environ.get('SMALL_MARGIN', .5))}
BIG = {'height': 20, 'scale': .0113, 'baseline': 18.9, 'outline': 2, 'bold': .3, 'gap': .6, 'margin': 0}

# emboss: height map blur, light shift (direction and reach), light strength; light from straight above.
# Blue and green have a narrow bevel, orange and pink a wide one (their second row is still lit),
# the big ones a softer one.
NARROW = {'blur': .5, 'dx': 0, 'dy': .6, 'light': 5}
WIDE = {'blur': 1.1, 'dx': 0, 'dy': 1.5, 'light': 4}
SOFT = {'blur': .8, 'dx': 0, 'dy': .8, 'light': 3}
# outline (also the shadow color), body, layout, emboss, and optionally a lighter outline stroke and
# the light color (added, see above)
PALETTES = {
    'blue': {'outline': '#017c94', 'body': '#3ac2dd', 'layout': SMALL, 'emboss': NARROW},
    'green': {'outline': '#537a06', 'body': '#c4f75f', 'layout': SMALL, 'emboss': NARROW, 'stroke': '#7d8e59'},
    'orange': {'outline': '#ff5400', 'body': '#ffc600', 'layout': SMALL, 'emboss': WIDE, 'stroke': '#fb7333'},
    'pink': {'outline': '#f40b58', 'body': '#ffb5ce', 'layout': SMALL, 'emboss': WIDE, 'stroke': '#f84d85'},
    # the light of the big green GIFs is yellow (a9fc3f -> d4ff4f -> ffff62 -> ffffb9), body a bit lighter than a9fc3f
    'bigGreen': {'outline': '#537a06', 'body': '#b2fc52', 'layout': BIG, 'emboss': SOFT, 'stroke': '#7d8e59',
                 'light': '#d4d478'},
    'bigOrange': {'outline': '#ff5400', 'body': '#ffc600', 'layout': BIG, 'emboss': SOFT, 'stroke': '#fb7333'},
    'bigPink': {'outline': '#f40b58', 'body': '#feb5cf', 'layout': BIG, 'emboss': SOFT, 'stroke': '#f84d85'},
    # no GIF: the purples of the mission points (public/gfx/clan/clan_mission_points.png), drawn like pink
    'violet': {'outline': '#7d099a', 'body': '#e1adf4', 'layout': SMALL, 'emboss': WIDE, 'stroke': '#a637ba'},
    'bigViolet': {'outline': '#7d099a', 'body': '#e1adf4', 'layout': BIG, 'emboss': SOFT, 'stroke': '#a637ba'},
}
LIGHT = '#d4d4d4'
EMBOSS_SHADOW = 2
EMBOSS_GAMMA = 1.5


def fmt(v):
    s = f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def glyph(font, name, layout):
    """The font glyph scaled to px in its image: (image width, path)."""
    glyphs = font.getGlyphSet()
    gname = font.getBestCmap()[ord(CHARS[name])]
    g = font['glyf'][gname]
    s, ink = layout['scale'], (layout['outline'] + layout['bold']) / 2  # outline drawn outside the glyph
    gap_left, gap_right = (n * layout['gap'] + layout['margin'] for n in GAPS[name])
    left = gap_left + ink
    width = left + (g.xMax - g.xMin) * s + ink + gap_right
    pen = SVGPathPen(glyphs, ntos=fmt)
    glyphs[gname].draw(TransformPen(pen, (s, 0, 0, -s, left - g.xMin * s, layout['baseline'])))
    return width, pen.getCommands()


def svg(width, height, body, palette):
    outline, color, layout, e = palette['outline'], palette['body'], palette['layout'], palette['emboss']
    kl, ks = fmt(e['light']), fmt(EMBOSS_SHADOW)
    emboss = (
        '<filter id="e" x="-.2" y="-.2" width="1.4" height="1.4" color-interpolation-filters="sRGB">'
        f'<feGaussianBlur in="SourceAlpha" stdDeviation="{fmt(e["blur"])}" result="h"/>'
        f'<feOffset in="h" dx="{fmt(e["dx"])}" dy="{fmt(e["dy"])}" result="d"/>'
        # light: where the height map rises along the light
        f'<feComposite in="h" in2="d" operator="arithmetic" k2="{kl}" k3="-{kl}"/>'
        f'<feComponentTransfer result="l"><feFuncA type="gamma" exponent="{fmt(EMBOSS_GAMMA)}"/></feComponentTransfer>'
        # shadow: where it falls
        f'<feComposite in="d" in2="h" operator="arithmetic" k2="{ks}" k3="-{ks}" result="s"/>'
        f'<feFlood flood-color="{palette.get("light", LIGHT)}"/><feComposite in2="l" operator="in" result="lc"/>'
        f'<feFlood flood-color="{outline}"/><feComposite in2="s" operator="in" result="sc"/>'
        '<feComposite in="SourceGraphic" in2="lc" operator="arithmetic" k2="1" k3="1"/>'  # additive light
        '<feComposite in="sc" operator="over"/>'
        '<feComposite in2="SourceAlpha" operator="in"/></filter>')
    bold = layout['bold']  # body thickened by a stroke of its own color
    stroke = palette.get('stroke', outline)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(width)} {height}" width="{fmt(width)}" height="{height}">'
            f'<defs><path id="b" d="{body}"/>{emboss}</defs>'
            f'<use href="#b" fill="{stroke}" stroke="{stroke}" stroke-width="{fmt(layout["outline"] + bold)}" stroke-linejoin="round"/>'
            f'<use href="#b" fill="{color}" stroke="{color}" stroke-width="{fmt(bold)}" stroke-linejoin="round" filter="url(#e)"/></svg>\n')


if __name__ == '__main__':
    font = TTFont(FONT)
    root = os.environ.get('TYPO_DIR') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'public', 'gfx', 'typo')
    for color in sys.argv[1:] or PALETTES:
        palette = PALETTES[color]
        os.makedirs(os.path.join(root, color), exist_ok=True)
        for name in CHARS:
            width, body = glyph(font, name, palette['layout'])
            with open(os.path.join(root, color, name + '.svg'), 'w') as f:
                f.write(svg(width, palette['layout']['height'], body, palette))
