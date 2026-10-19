# The letters of the names of the clans (public/gfx/clan/typo/kword, resources/js/components/clan/Name.vue) drawn in SVG
# from the Junegull font, in the style of the GIFs of KadoKado: a white halo, a dark teal outline, an inner rim and a
# glossy two-tone fill. Needs rsvg-convert and ImageMagick (magick) to measure the glyphs.
#   python3 scripts/clan_letters.py            all the characters
#   python3 scripts/clan_letters.py p q        some of them
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'public/fonts/Junegull-Regular.svg')
OUT = os.path.join(ROOT, 'public/gfx/clan/typo/kword')
src = open(FONT).read()

# the characters and their files (Name.vue: the same names)
FILES = {c: c for c in 'abcdefghijklmnopqrstuvwxyz0123456789'}
# (no "_": it goes under the baseline, out of the 32 px)
FILES.update({'-': 'dash', "'": 'apostrophe', '.': 'dot', '!': 'exclamation', '?': 'question'})
ENTITIES = {"'": '&apos;'}
SPACE = 12  # px, as the GIF of the space

def glyph(ch):
    for m in re.finditer(r'<glyph\b([^>]*?)/>', src, re.S):
        a = m.group(1)
        u = re.search(r'unicode="([^"]*)"', a)
        if u and u.group(1) in (ch, ENTITIES.get(ch)):
            d = re.search(r'\sd="([^"]*)"', a, re.S).group(1)
            return ' '.join(d.split())
    raise SystemExit(f'no glyph {ch!r}')

def bbox(d):
    # the bounding box of the glyph (font units, y up), measured on a big render
    with tempfile.TemporaryDirectory() as tmp:
        svg, png = os.path.join(tmp, 'g.svg'), os.path.join(tmp, 'g.png')
        open(svg, 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-300 -1100 1600 1500" width="1600" height="1500"><path transform="scale(1,-1)" d="{d}"/></svg>')
        subprocess.run(['rsvg-convert', svg, '-o', png], check=True)
        g = subprocess.run(['magick', png, '-alpha', 'extract', '-format', '%@', 'info:'], capture_output=True, text=True, check=True).stdout
    w, h, x, y = map(int, re.match(r'(\d+)x(\d+)\+(\d+)\+(\d+)', g).groups())
    return x - 300, 1100 - (y + h), x - 300 + w, 1100 - y  # xmin, ymin, xmax, ymax

CAP = 704          # font units of the height of the letters
BOLD = 1.0         # px added around the glyph: the letters of the GIFs are bolder than the font
BODY = 23.5 - 2 * BOLD  # px: the height of the glyph (the GIFs: the letter with its outline from y=3 to y=28)
TOP = 4.0 + BOLD   # px: the top of the glyph in the 32 px of the image
PAD = 4.0 + BOLD   # px: bold + outline + halo on the left and on the right

def svg(ch):
    d = glyph(ch)
    s = BODY / CAP
    x0, y0, x1, y1 = bbox(d)
    width = round((x1 - x0) * s + 2 * PAD, 2)
    tx, ty = PAD - x0 * s, TOP + CAP * s  # baseline
    px = lambda v: round(v / s, 2)  # px -> font units (the strokes are drawn in the glyph space)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 32" width="{width}" height="32">
<defs>
<path id="g" d="{d}"/>
<clipPath id="c"><use href="#g"/></clipPath>
<linearGradient id="f" gradientUnits="userSpaceOnUse" x1="0" y1="{CAP}" x2="0" y2="0">
<stop offset="0" stop-color="#fff"/><stop offset=".21" stop-color="#fff"/><stop offset=".63" stop-color="#e3fbff"/>
<stop offset=".635" stop-color="#84e2f3"/><stop offset=".68" stop-color="#79e0f3"/><stop offset="1" stop-color="#c1f4fe"/>
</linearGradient>
<filter id="h" x="-.5" y="-.5" width="2" height="2"><feGaussianBlur stdDeviation="{px(0.5)}"/></filter>
</defs>
<g transform="translate({round(tx, 2)} {round(ty, 2)}) scale({round(s, 5)} {-round(s, 5)})" stroke-linejoin="round">
<use href="#g" fill="#fff" stroke="#fff" stroke-width="{px(8.5 + 2 * BOLD)}" filter="url(#h)"/>
<use href="#g" fill="#1f6776" stroke="#1f6776" stroke-width="{px(2.8 + 2 * BOLD)}"/>
<use href="#g" fill="#5babbb" stroke="#5babbb" stroke-width="{px(2 * BOLD)}"/>
<use href="#g" fill="url(#f)"/>
<use href="#g" fill="none" stroke="#cef5fe" stroke-width="{px(2)}" clip-path="url(#c)"/>
</g>
</svg>
'''

if __name__ == '__main__':
    chars = [c.lower() for c in sys.argv[1:]] or [*FILES, ' ']
    for ch in chars:
        if ch == ' ':
            content = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SPACE} 32" width="{SPACE}" height="32"/>\n'
            name = 'space'
        else:
            content, name = svg(ch.upper()), FILES[ch]
        open(os.path.join(OUT, f'{name}.svg'), 'w').write(content)
        print(name)
