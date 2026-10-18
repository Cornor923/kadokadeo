"""Embedded fonts of a SWF without FFDec: DefineFont2 / DefineFont3 glyphs rasterized with Pillow, and the static texts
(DefineText / DefineText2) that use them.

- a glyph is a SWF shape (one fill): its contours are flattened (quadratic curves cut in 8) and filled even-odd,
  supersampled then reduced (anti-aliasing close to the Flash player's)
- DefineFont3 coordinates are in 1/20 of the EM square (20480 units), DefineFont2 in EM units (1024)
usage (module): fonts = read_fonts(swf); texts = read_texts(swf)
                img, ox, oy = render_glyph(fonts[id], ch, size_px, color)   # (ox, oy): position of the origin in img
usage (cli):    swffont.py <swf>   lists the fonts, their characters and the static texts
"""
import sys, zlib, struct, os
from PIL import Image, ImageDraw, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import swfdump as S

SUPER = 8


def _tags(path):
    raw = open(path, 'rb').read()
    data = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
    b = S.Bits(data, 8); b.rect(); b.u16(); b.u16()
    return S.read_tags(data, b.pos, len(data))


def _shape(body, pos):
    """contours of a glyph shape: [[(x, y), ...], ...] in font units"""
    b = S.Bits(body, pos)
    nfill, nline = b.ub(4), b.ub(4)
    x = y = 0
    contours, cur = [], None
    while True:
        if b.ub(1) == 0:
            flags = b.ub(5)
            if flags == 0:
                break
            if flags & 1:
                n = b.ub(5)
                x, y = b.sb(n), b.sb(n)
                if cur and len(cur) > 1:
                    contours.append(cur)
                cur = [(x, y)]
            if flags & 2:
                b.ub(nfill)
            if flags & 4:
                b.ub(nfill)
            if flags & 8:
                b.ub(nline)
            if flags & 16:
                raise ValueError('new styles in a glyph')
        else:
            if cur is None:
                cur = [(x, y)]
            if b.ub(1):
                n = b.ub(4) + 2
                if b.ub(1):
                    x += b.sb(n); y += b.sb(n)
                elif b.ub(1):
                    y += b.sb(n)
                else:
                    x += b.sb(n)
                cur.append((x, y))
            else:
                n = b.ub(4) + 2
                cx, cy = x + b.sb(n), y + b.sb(n)
                ax, ay = cx + b.sb(n), cy + b.sb(n)
                for i in range(1, 9):
                    t = i / 8
                    u = 1 - t
                    cur.append((u * u * x + 2 * u * t * cx + t * t * ax, u * u * y + 2 * u * t * cy + t * t * ay))
                x, y = ax, ay
    if cur and len(cur) > 1:
        contours.append(cur)
    return contours


def read_fonts(path):
    fonts = {}
    for t in _tags(path):
        code, body = t[0], t[1]
        if code not in (48, 75):
            continue
        fid, flags, _lang, nl = struct.unpack_from('<HBBB', body, 0)
        name = body[5:5 + nl].decode('latin1').rstrip('\0')
        p = 5 + nl
        ng = struct.unpack_from('<H', body, p)[0]
        p += 2
        base = p
        wide = flags & 0x08
        fmt, sz = ('<I', 4) if wide else ('<H', 2)
        offs = [struct.unpack_from(fmt, body, p + i * sz)[0] for i in range(ng)]
        code_off = struct.unpack_from(fmt, body, p + ng * sz)[0]
        glyphs = [_shape(body, base + o) for o in offs]
        q = base + code_off
        if flags & 0x04:
            codes = list(struct.unpack_from('<%dH' % ng, body, q)); q += 2 * ng
        else:
            codes = list(body[q:q + ng]); q += ng
        font = dict(id=fid, name=name, em=20480 if code == 75 else 1024, glyphs=glyphs, codes=codes,
                    bold=bool(flags & 1), italic=bool(flags & 2))
        if flags & 0x80:
            font['ascent'], font['descent'], font['leading'] = struct.unpack_from('<hhh', body, q); q += 6
            font['advances'] = list(struct.unpack_from('<%dh' % ng, body, q))
        fonts[fid] = font
    return fonts


def read_texts(path):
    """static texts: {id: {'matrix':..., 'records': [{'font', 'height', 'color', 'x', 'y', 'glyphs': [(index, advance)]}]}}"""
    texts = {}
    for t in _tags(path):
        code, body = t[0], t[1]
        if code not in (11, 33):
            continue
        cid = struct.unpack_from('<H', body, 0)[0]
        b = S.Bits(body, 2)
        b.rect()
        b.align()
        m = b.matrix()
        gbits, abits = b.u8(), b.u8()
        recs, font, height, color, x, y = [], None, 0, None, 0, 0
        while True:
            b.align()
            flags = b.u8()
            if flags == 0:
                break
            if flags & 0x08:
                font = b.u16()
            if flags & 0x04:
                color = tuple(b.u8() for _ in range(4 if code == 33 else 3))
            if flags & 0x01:
                x = struct.unpack('<h', bytes([b.u8(), b.u8()]))[0] / 20
            if flags & 0x02:
                y = struct.unpack('<h', bytes([b.u8(), b.u8()]))[0] / 20
            if flags & 0x08:
                height = b.u16() / 20
            n = b.u8()
            gl = []
            for _ in range(n):
                gl.append((b.ub(gbits), b.sb(abits) / 20))
            recs.append(dict(font=font, height=height, color=color, x=x, y=y, glyphs=gl))
        texts[cid] = dict(matrix=m, records=recs)
    return texts


def glyph_index(font, ch):
    return font['codes'].index(ord(ch))


def render_glyph_index(font, gi, size, color=(255, 255, 255, 255)):
    """the glyph at `size` px: (image, ox, oy), (ox, oy) = where the origin (pen position on the baseline) is"""
    k = size / font['em']
    pts = [p for c in font['glyphs'][gi] for p in c]
    if not pts:
        return Image.new('RGBA', (1, 1), (0, 0, 0, 0)), 0, 0
    x0 = min(p[0] for p in pts) * k
    y0 = min(p[1] for p in pts) * k
    x1 = max(p[0] for p in pts) * k
    y1 = max(p[1] for p in pts) * k
    ox, oy = -int(x0 // 1) + 1, -int(y0 // 1) + 1
    w, h = int(x1 + ox) + 2, int(y1 + oy) + 2
    acc = Image.new('L', (w * SUPER, h * SUPER), 0)
    for c in font['glyphs'][gi]:
        m = Image.new('L', acc.size, 0)
        ImageDraw.Draw(m).polygon([((px * k + ox) * SUPER, (py * k + oy) * SUPER) for px, py in c], fill=255)
        acc = ImageChops.logical_xor(acc.convert('1'), m.convert('1')).convert('L')
    a = acc.resize((w, h), Image.BOX)
    img = Image.new('RGBA', (w, h), color[:3] + (0,))
    alpha = a.point(lambda v: v * (color[3] if len(color) > 3 else 255) // 255)
    img.putalpha(alpha)
    return img, ox, oy


def render_glyph(font, ch, size, color=(255, 255, 255, 255)):
    return render_glyph_index(font, glyph_index(font, ch), size, color)


if __name__ == '__main__':
    fonts = read_fonts(sys.argv[1])
    for f in fonts.values():
        print('font %d %r em %d glyphs %d ascent %s descent %s' % (f['id'], f['name'], f['em'], len(f['glyphs']),
                                                                   f.get('ascent'), f.get('descent')))
        print('  ' + ''.join(chr(c) for c in f['codes'] if c < 0x10000))
    for tid, t in read_texts(sys.argv[1]).items():
        for r in t['records']:
            f = fonts.get(r['font'])
            s = ''.join(chr(f['codes'][g]) for g, _ in r['glyphs']) if f else '?'
            print('text %d font %s h %.2f color %s at (%.2f, %.2f): %r advances %s' % (
                tid, r['font'], r['height'], r['color'], r['x'], r['y'], s, [a for _, a in r['glyphs']]))
