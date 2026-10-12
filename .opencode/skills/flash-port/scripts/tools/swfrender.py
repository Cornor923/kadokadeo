"""Tiny Flash (AVM1-era) display-list compositor.

- reads DefineSprite timelines (PlaceObject/RemoveObject/labels/simple frame actions) with swfdump's parser
- leaf shapes are rasterized by FFDec (`-export shape -zoom Z`), image origin = shape bounds min
- nested clips advance with their own timeline (stop / play / gotoAndStop / gotoAndPlay actions are honoured),
  named children can be forced to a given frame (code-driven clips), hidden, or color transformed
- composition is done at Z (supersampled) in premultiplied float, then downscaled to the output scale.
"""
import os, struct, zlib, math, re, io, subprocess
import numpy as np
from PIL import Image
import swfdump as S
import swffilters as SF

IDENT = dict(a=1.0, b=0.0, c=0.0, d=1.0, tx=0.0, ty=0.0)
NOCX = dict(mult=[1.0, 1.0, 1.0, 1.0], add=[0, 0, 0, 0])


def mat_mul(p, c):
    """parent * child (child applied first)"""
    return dict(a=p['a'] * c['a'] + p['c'] * c['b'], b=p['b'] * c['a'] + p['d'] * c['b'],
                c=p['a'] * c['c'] + p['c'] * c['d'], d=p['b'] * c['c'] + p['d'] * c['d'],
                tx=p['a'] * c['tx'] + p['c'] * c['ty'] + p['tx'], ty=p['b'] * c['tx'] + p['d'] * c['ty'] + p['ty'])


def cx_mul(p, c):
    return dict(mult=[p['mult'][i] * c['mult'][i] for i in range(4)],
                add=[p['add'][i] + p['mult'][i] * c['add'][i] for i in range(4)])


def parse_actions(body):
    """very small AVM1 reader: returns list of ('stop',) ('play',) ('goto', frame1) ('label', name) ('other',)"""
    out = []
    i = 0
    while i < len(body):
        code = body[i]
        i += 1
        if code == 0:
            break
        ln = 0
        if code >= 0x80:
            ln = struct.unpack_from('<H', body, i)[0]
            i += 2
        data = body[i:i + ln]
        i += ln
        if code == 0x07:
            out.append(('stop',))
        elif code == 0x06:
            out.append(('play',))
        elif code == 0x81:
            out.append(('goto', struct.unpack_from('<H', data, 0)[0] + 1))
        elif code == 0x8C:
            out.append(('label', data[:-1].decode('latin1')))
        else:
            out.append(('other', code))
    return out


class SpriteDef:
    def __init__(self, sid, nframes):
        self.sid = sid
        self.nframes = nframes
        self.frames = []      # list of op lists
        self.labels = {}      # name -> frame (1-based)
        self.actions = {}     # frame -> parsed actions


class SWF:
    def __init__(self, path, shapes_dir, Z=4):
        self.Z = Z
        self.shapes_dir = shapes_dir
        self.svg_dir = None   # FFDec SVG export of the shapes (svg_<n>/), needed by shape_layers
        # Flash "low" quality (pixel art, Judo Commando): shapes placed with nearest sampling instead of bicubic (use
        # an export at the zoom of the output, so that nothing is resized)
        self.nearest = False
        self.nested_masks = False   # True: a mask placed under another mask is masked by it (see Renderer.collect)
        # True: inner glows / inner drop shadows are drawn (Flash: the blurred outside of the shape, drawn atop it); off:
        # they are skipped, as the renders made before this option
        self.inner_filters = False
        # True: blur filters are drawn (Flash: `passes` boxes on the colour and the alpha); off: skipped, as the renders
        # made before this option
        self.blur_filters = False
        # True: the colour transform of the parents of a filtered object is applied to its filtered picture (Flash: a
        # colour matrix or a glow of the object is tinted by the colour of its container, Kanji Gaiden's shurikens on
        # the coloured planes); its own colour transform stays before its filters. Off: the colour of the parents goes
        # under the filters too, as the renders made before this option
        self.parent_cx_after_filters = False
        raw = open(path, 'rb').read()
        data = raw[:8] + (zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:])
        b = S.Bits(data, 8)
        b.rect(); b.u16(); b.u16()
        tags = S.read_tags(data, b.pos, len(data))
        self.shapes = {}
        self.sprites = {}
        self.exports = {}
        self.texts = {}
        self.names = {}
        for code, body in tags:
            bb = S.Bits(body)
            if code in (2, 22, 32, 83):
                cid = bb.u16()
                self.shapes[cid] = bb.rect()  # xmin xmax ymin ymax
            elif code == 37:
                cid = bb.u16()
                self.texts[cid] = bb.rect()
            elif code in (46, 84):
                cid = bb.u16()
                r0 = bb.rect()
                r1 = bb.rect()
                self.shapes[cid] = [min(r0[0], r1[0]), max(r0[1], r1[1]), min(r0[2], r1[2]), max(r0[3], r1[3])]
                self.morphs = getattr(self, 'morphs', set()) | {cid}
            elif code == 39:
                cid = bb.u16()
                nf = bb.u16()
                sd = SpriteDef(cid, nf)
                cur = []
                for sc, sbody in S.read_tags(body, 4, len(body)):
                    if sc in (4, 26, 70):
                        p = S.parse_place(sc, sbody)
                        if sc == 70 and (sbody[1] & 0x03):
                            filters, blend = SF.parse_place3_extras(sbody)
                            if sbody[1] & 0x01:
                                p['filters'] = filters
                            if sbody[1] & 0x02:
                                p['blend'] = blend
                        cur.append(('place', p))
                    elif sc in (5, 28):
                        sb_ = S.Bits(sbody)
                        if sc == 5:
                            sb_.u16()
                        cur.append(('remove', sb_.u16()))
                    elif sc == 43:
                        sd.labels[S.Bits(sbody).string()] = len(sd.frames) + 1
                    elif sc == 12:
                        sd.actions.setdefault(len(sd.frames) + 1, []).extend(parse_actions(sbody))
                    elif sc == 1:
                        sd.frames.append(cur)
                        cur = []
                while len(sd.frames) < nf:
                    sd.frames.append([])
                self.sprites[cid] = sd
            elif code in (56, 57):
                if code == 57:
                    bb.string()
                n = bb.u16()
                for _ in range(n):
                    t = bb.u16()
                    name = bb.string()
                    self.exports[t] = name
                    self.names[name] = t
        self._shape_cache = {}
        # sprites drawn from FFDec renders (morph shapes, alpha-adding colour transforms...):
        # sid -> (folder of frames N.png at zoom Z, (x0, y0) origin in sprite coords, number of frames)
        self.leaves = {}

    def add_leaf(self, sid, folder, origin, nframes):
        self.leaves[sid] = (folder, origin, nframes)

    def leaf_image(self, sid, frame):
        key = ('leaf', sid, frame)
        if key not in self._shape_cache:
            folder = self.leaves[sid][0]
            self._shape_cache[key] = Image.open(os.path.join(folder, '%d.png' % frame)).convert('RGBA')
        return self._shape_cache[key]

    def shape_image(self, cid):
        if cid not in self._shape_cache:
            p = os.path.join(self.shapes_dir, '%d.png' % cid)
            im = Image.open(p).convert('RGBA')
            self._shape_cache[cid] = im
        return self._shape_cache[cid]

    def shape_layers(self, cid):
        """the shape as groups of fills that do not overlap, drawn one after the other: Flash composes the shape
        layers of a shape (fills drawn over other fills) one by one, so under an alpha < 1 the lower ones show
        through the upper ones (a single image would let the background through instead).
        -> virtual shape ids (cid, i) with the bounds of cid, each rendered by rsvg-convert from the FFDec SVG on
        the grid of the FFDec PNG; [cid] when no fill overlaps another (or no SVG / bitmap fills)"""
        key = ('layers', cid)
        if key in self._shape_cache:
            return self._shape_cache[key]
        out = [cid]
        p = os.path.join(self.svg_dir, '%d.svg' % cid) if self.svg_dir else None
        if p and os.path.exists(p) and cid not in getattr(self, 'morphs', ()):
            svg = open(p).read()
            paths = re.findall(r'<path [^>]*/>', svg)
            if len(paths) > 1 and 'pattern' not in svg and '<image' not in svg:
                w, h = self.shape_image(cid).size
                svg = re.sub(r'height="[^"]*px" width="[^"]*px"', 'height="%gpx" width="%gpx"' % (h / self.Z, w / self.Z),
                             svg, count=1)
                parts = re.split(r'<path [^>]*/>', svg)

                def render(keep):
                    s = parts[0] + ''.join(paths[i] + parts[i + 1] if i in keep else parts[i + 1] for i in range(len(paths)))
                    r = subprocess.run(['rsvg-convert', '-z', str(self.Z)], input=s.encode(), capture_output=True, check=True)
                    im = Image.open(io.BytesIO(r.stdout)).convert('RGBA')
                    assert im.size == (w, h), (cid, im.size, (w, h))
                    return im

                # consecutive fills grouped while they do not overlap (anti-aliased edges shared by two fills of
                # the same shape layer cover each pixel at most half and half: not an overlap)
                groups, acc = [], None
                for i in range(len(paths)):
                    a = np.asarray(render({i}), dtype=np.float32)[..., 3] / 255.0
                    if acc is None or (np.minimum(acc, a) > 0.6).sum() > 4:
                        groups.append([i])
                        acc = a
                    else:
                        groups[-1].append(i)
                        acc = np.maximum(acc, a)
                if len(groups) > 1:
                    out = []
                    for gi, g in enumerate(groups):
                        v = (cid, gi)
                        self.shapes[v] = self.shapes[cid]
                        self._shape_cache[v] = render(set(g))
                        out.append(v)
        self._shape_cache[key] = out
        return out

    def sid(self, name_or_id):
        return self.names[name_or_id] if isinstance(name_or_id, str) else name_or_id


class Instance:
    """runtime state of a sprite instance (playhead + display list with nested instances)"""

    def __init__(self, swf, sid, name=None, ctrl=None):
        self.swf = swf
        self.sd = swf.sprites[sid]
        self.sid = sid
        self.name = name
        self.ctrl = ctrl or {}
        self.frame = 0
        self.age = 0
        self.playing = True
        self.display = {}   # depth -> dict(char, matrix, cx, name, inst, clip)
        self._goto(1)
        self._run_actions()

    def forced(self):
        c = self.ctrl.get(self.name) if self.name else None
        if c is None:
            c = self.ctrl.get(self.sid)
        if isinstance(c, str):
            c = self.sd.labels[c]
        return c

    def _apply_ops(self, f):
        for kind, v in self.sd.frames[f - 1]:
            if kind == 'remove':
                self.display.pop(v, None)
                continue
            d = v['depth']
            e = self.display.get(d)
            if getattr(self.swf, 'flash_replace', False) and 'char' in v and v['move'] and e is not None and \
                    e['char'] != v['char'] and e['inst'] is None and v['char'] not in self.swf.sprites:
                # shape replaced at the same depth (frame by frame animation): like Flash, the new shape keeps the
                # matrix, colour transform... of the previous one unless the tag sets them
                e = dict(e, char=v['char'])
                self.display[d] = e
                v = {k: x for k, x in v.items() if k != 'char'}
            if 'char' in v and not (e is not None and v['move'] and e['char'] == v['char']):
                e = dict(char=v['char'], matrix=IDENT, cx=NOCX, name=None, inst=None, clip=None, filters=[], blend=None)
                self.display[d] = e
                if v['char'] in self.swf.sprites:
                    e['inst'] = Instance(self.swf, v['char'], v.get('name'), self.ctrl)
            if e is None:
                continue
            if 'matrix' in v:
                e['matrix'] = v['matrix']
            if 'cx' in v:
                e['cx'] = v['cx']
            if 'name' in v:
                e['name'] = v['name']
                if e['inst'] is not None and e['inst'].name != v['name']:
                    e['inst'].name = v['name']
                    e['inst']._run_actions()
            if 'clipDepth' in v:
                e['clip'] = v['clipDepth']
            if 'filters' in v:
                e['filters'] = v['filters']
            if 'blend' in v:
                e['blend'] = v['blend']

    def _rebuild(self, target):
        old = self.display
        self.display = {}
        for f in range(1, target + 1):
            self._apply_ops(f)
        for d, e in self.display.items():
            o = old.get(d)
            if o is not None and o['char'] == e['char'] and o['inst'] is not None:
                e['inst'] = o['inst']

    def _goto(self, f):
        f = max(1, min(self.sd.nframes, f))
        if f == self.frame:
            return
        if f < self.frame:
            self._rebuild(f)
        else:
            for g in range(self.frame + 1, f + 1):
                self._apply_ops(g)
        self.frame = f

    def _run_actions(self):
        forced = self.forced()
        if forced is not None:
            self.playing = False
            self._goto(forced)
            return
        acts = [] if self.ctrl.get('__noactions__') else self.sd.actions.get(self.frame, [])
        for i, a in enumerate(acts):
            if a[0] == 'stop':
                self.playing = False
            elif a[0] == 'play':
                self.playing = True
            elif a[0] == 'goto' or (a[0] == 'label' and a[1] in self.sd.labels):
                target = a[1] if a[0] == 'goto' else self.sd.labels[a[1]]
                nxt = acts[i + 1][0] if i + 1 < len(acts) else None
                self.playing = (nxt == 'play')
                self._goto(target)
                return

    def goto_and_stop(self, f):
        if isinstance(f, str):
            f = self.sd.labels[f]
        self._goto(f)
        self.playing = False

    def goto_and_play(self, f):
        if isinstance(f, str):
            f = self.sd.labels[f]
        self._goto(f)
        self.playing = True
        self._run_actions()

    def tick(self):
        self.age += 1
        existing = [e['inst'] for e in self.display.values() if e['inst'] is not None]
        if self.forced() is None and self.playing:
            nxt = self.frame + 1
            self._goto(1 if nxt > self.sd.nframes else nxt)
            self._run_actions()
        for inst in existing:
            if any(e['inst'] is inst for e in self.display.values()):
                inst.tick()


def box_blur(a, rx, ry, passes):
    """Flash-like box blur of a 2D array: total widths rx, ry (pixels), repeated `passes` times"""
    out = a
    for _ in range(max(1, passes)):
        for axis, r in ((1, rx), (0, ry)):
            w = int(round(r))
            if w < 2:
                continue
            lo, hi = w // 2, w - w // 2
            pad = [(0, 0), (0, 0)]
            pad[axis] = (lo + 1, hi)
            c = np.cumsum(np.pad(out, pad), axis=axis)
            n = out.shape[axis]
            if axis == 1:
                out = (c[:, w:w + n] - c[:, 0:n]) / w
            else:
                out = (c[w:w + n, :] - c[0:n, :]) / w
    return out


def apply_filter(layer, f, Z, inner=False, blur=False):
    """layer: premultiplied float32 HxWx4 at Z pixels per world unit (inner: inner glows / shadows drawn; blur: blur
    filters drawn)"""
    t = f['type']
    if t == 'blur':
        if not blur:
            return layer
        return np.stack([box_blur(layer[..., i], f['blurX'] * Z, f['blurY'] * Z, f.get('passes', 1)) for i in range(4)],
                        axis=-1).astype(np.float32)
    if t == 'colormatrix':
        m = np.array(f['matrix'], dtype=np.float32).reshape(4, 5)
        a = layer[..., 3:4]
        rgb = np.where(a > 0, layer[..., :3] / np.maximum(a, 1e-6), 0)
        src = np.concatenate([rgb, a], axis=-1)
        res = src @ m[:, :4].T + m[:, 4] / 255.0
        res = np.clip(res, 0, 1)
        na = res[..., 3:4]
        return np.concatenate([res[..., :3] * na, na], axis=-1).astype(np.float32)
    if t in ('glow', 'dropshadow'):
        if f.get('knockout'):
            return layer
        if f.get('inner'):
            if not inner:
                return layer
            # the outside of the shape (1 - alpha), offset for a shadow, blurred, drawn atop the shape (inside only); the
            # outside of the canvas is outside of the shape: 1 - the blurred alpha (zero padded)
            a = layer[..., 3]
            s = a
            if t == 'dropshadow':
                dx = int(round(f['distance'] * math.cos(f['angle']) * Z))
                dy = int(round(f['distance'] * math.sin(f['angle']) * Z))
                s = np.zeros_like(a)
                H, W = a.shape
                s[max(0, dy):H + min(0, dy), max(0, dx):W + min(0, dx)] = a[max(0, -dy):H + min(0, -dy), max(0, -dx):W + min(0, -dx)]
            g = 1 - box_blur(s, f['blurX'] * Z, f['blurY'] * Z, f.get('passes', 1))
            r, gg, b, ca = f['color']
            g = (np.clip(g * f['strength'], 0, 1) * (ca / 255.0))[..., None]
            col = np.array([r / 255.0, gg / 255.0, b / 255.0], dtype=np.float32)
            rgb = layer[..., :3] * (1 - g) + col * g * a[..., None]
            return np.concatenate([rgb, a[..., None]], axis=-1).astype(np.float32)
        a = layer[..., 3]
        if t == 'dropshadow':
            dx = int(round(f['distance'] * math.cos(f['angle']) * Z))
            dy = int(round(f['distance'] * math.sin(f['angle']) * Z))
            a = np.roll(np.roll(a, dy, axis=0), dx, axis=1)
        g = box_blur(a, f['blurX'] * Z, f['blurY'] * Z, f.get('passes', 1))
        r, gg, b, ca = f['color']
        g = np.clip(g * f['strength'], 0, 1) * (ca / 255.0)
        glow = np.stack([g * (r / 255.0), g * (gg / 255.0), g * (b / 255.0), g], axis=-1).astype(np.float32)
        return layer + glow * (1 - layer[..., 3:4])
    return layer


def cx_key(cx):
    return (tuple(cx['mult']), tuple(cx['add']))


def apply_cx(layer, c):
    """a colour transform on a premultiplied layer"""
    a = layer[..., 3:4]
    rgb = np.where(a > 0, layer[..., :3] / np.maximum(a, 1e-6), 0)
    rgb = np.clip(rgb * np.array(c['mult'][:3], dtype=np.float32) + np.array(c['add'][:3], dtype=np.float32) / 255.0, 0, 1)
    a2 = np.clip(a * c['mult'][3] + c['add'][3] / 255.0, 0, 1)
    a2 = np.where(a > 0, a2, 0)
    return np.concatenate([rgb * a2, a2], axis=-1).astype(layer.dtype)


def blend_into(canvas, layer, blend):
    la = layer[..., 3:4]
    if blend in ('add',):
        out_a = canvas[..., 3:4] + la * (1 - canvas[..., 3:4])
        rgb = np.minimum(canvas[..., :3] + layer[..., :3], out_a)
        canvas[..., :3] = rgb
        canvas[..., 3:4] = out_a
    elif blend == 'screen':
        rgb = canvas[..., :3] + layer[..., :3] - canvas[..., :3] * layer[..., :3]
        canvas[..., 3:4] = canvas[..., 3:4] + la * (1 - canvas[..., 3:4])
        canvas[..., :3] = rgb
    elif blend == 'multiply':
        rgb = canvas[..., :3] * layer[..., :3] + canvas[..., :3] * (1 - la) + layer[..., :3] * (1 - canvas[..., 3:4])
        canvas[..., 3:4] = canvas[..., 3:4] + la * (1 - canvas[..., 3:4])
        canvas[..., :3] = rgb
    else:
        canvas *= (1 - la)
        canvas += layer


def blend_overlay(canvas, layer):
    """Flash 'overlay' (multiply where the backdrop is darker than 50 % grey, screen where it is lighter), premultiplied
    (W3C separable blend): Cs (1 - ab) + Cb (1 - as) + as ab B(cb, cs). Opt-in (SWF.overlay = True): without it the layer
    is drawn normally, as the renders made before it were"""
    la, ca = layer[..., 3:4], canvas[..., 3:4]
    cs = np.where(la > 0, layer[..., :3] / np.maximum(la, 1e-6), 0)
    cb = np.where(ca > 0, canvas[..., :3] / np.maximum(ca, 1e-6), 0)
    b = np.where(cb <= 0.5, 2 * cs * cb, 1 - 2 * (1 - cs) * (1 - cb))
    rgb = layer[..., :3] * (1 - ca) + canvas[..., :3] * (1 - la) + la * ca * b
    canvas[..., 3:4] = ca + la * (1 - ca)
    canvas[..., :3] = rgb


def blur_layer(layer, f, Z):
    """Flash BlurFilter on a premultiplied layer: box blurs of blurX x blurY stage pixels, `passes` times"""
    out = np.empty_like(layer)
    for ch in range(4):
        out[..., ch] = box_blur(layer[..., ch], f['blurX'] * Z, f['blurY'] * Z, f.get('passes', 1))
    return out


def blend_lighten(canvas, layer):
    """Flash 'lighten' (the brighter colour per channel), premultiplied: Cs (1 - ab) + Cb (1 - as) + max(as Cb, ab Cs).
    Opt-in (SWF.lighten = True): without it the layer is drawn normally, as the renders made before it were"""
    la, ca = layer[..., 3:4], canvas[..., 3:4]
    cs, cb = layer[..., :3], canvas[..., :3]
    rgb = cs * (1 - ca) + cb * (1 - la) + np.maximum(la * cb, ca * cs)
    canvas[..., 3:4] = ca + la * (1 - ca)
    canvas[..., :3] = rgb


class Renderer:
    def __init__(self, swf, out_scale=2):
        self.swf = swf
        self.Z = swf.Z
        self.k = out_scale

    def collect(self, inst, M, cx, hide, out, clipstack=None):
        """flatten the display list into draw commands [(shape_id, M, cx, mask_group)]"""
        depths = sorted(inst.display)
        masks = []  # (maskDepth, clipDepth, commands)
        for d in depths:
            e = inst.display[d]
            if e['name'] in hide or (e['inst'] is not None and e['inst'].sid in hide):
                continue
            m = mat_mul(M, e['matrix'])
            c = cx_mul(cx, e['cx'])
            target = out
            for (md, cd, group) in masks:
                if md < d <= cd:
                    target = group['items']
            if e['clip'] is not None:
                group = dict(mask=[], items=[])
                self._emit(e, m, c, hide, group['mask'])
                masks.append((d, e['clip'], group))
                # (nested_masks: a mask inside the range of another one is masked by it too, like Flash; off: drawn
                # outside of it, as the renders made before this option)
                (target if getattr(self.swf, 'nested_masks', False) else out).append(('mask', group))
                continue
            if e.get('filters') or e.get('blend') not in (None, 'normal', 'layer'):
                sub = []
                if e.get('filters') and getattr(self.swf, 'parent_cx_after_filters', False) and cx_key(cx) != cx_key(NOCX):
                    self._emit(e, m, e['cx'], hide, sub)
                    if sub:
                        target.append(('layer', sub, e.get('filters') or [], e.get('blend'), cx))
                    continue
                self._emit(e, m, c, hide, sub)
                if sub:
                    target.append(('layer', sub, e.get('filters') or [], e.get('blend')))
                continue
            self._emit(e, m, c, hide, target)

    def _emit(self, e, m, c, hide, out):
        if e['inst'] is not None and e['inst'].sid in self.swf.leaves:
            folder, origin, n = self.swf.leaves[e['inst'].sid]
            out.append(('leaf', e['inst'].sid, (e['inst'].age % n) + 1, m, c))
        elif e['inst'] is not None:
            self.collect(e['inst'], m, c, hide, out)
        elif e['char'] in self.swf.shapes:
            out.append(('shape', e['char'], m, c))

    def bounds(self, cmds):
        xs, ys = [], []
        for cmd in cmds:
            if cmd[0] == 'layer':
                bx = self.bounds(cmd[1])
                if bx:
                    gx = gy = 0.0
                    for f in cmd[2]:
                        if f['type'] == 'blur' and getattr(self.swf, 'blur_filters', False):
                            n = max(1, f.get('passes', 1))
                            gx, gy = max(gx, f['blurX'] * n * 0.5 + 1), max(gy, f['blurY'] * n * 0.5 + 1)
                        if f['type'] in ('glow', 'dropshadow') and not f.get('inner'):
                            n = max(1, f.get('passes', 1))
                            ex, ey = f['blurX'] * n * 0.5 + 1, f['blurY'] * n * 0.5 + 1
                            if f['type'] == 'dropshadow':
                                ex += abs(f['distance'] * math.cos(f['angle']))
                                ey += abs(f['distance'] * math.sin(f['angle']))
                            gx, gy = max(gx, ex), max(gy, ey)
                        elif f['type'] == 'blur' and getattr(self.swf, 'blur_filter', False):
                            n = max(1, f.get('passes', 1))
                            gx, gy = max(gx, f['blurX'] * n * 0.5 + 1), max(gy, f['blurY'] * n * 0.5 + 1)
                    xs += [bx[0] - gx, bx[2] + gx]
                    ys += [bx[1] - gy, bx[3] + gy]
                continue
            if cmd[0] == 'mask':
                bx = self.bounds(cmd[1]['items'])
                if bx:
                    xs += [bx[0], bx[2]]
                    ys += [bx[1], bx[3]]
                continue
            if cmd[0] == 'leaf':
                _, sid, fr, m, c = cmd
                im = self.swf.leaf_image(sid, fr)
                ox, oy = self.swf.leaves[sid][1]
                x0, x1, y0, y1 = ox, ox + im.width / self.Z, oy, oy + im.height / self.Z
            else:
                _, sid, m, c = cmd
                x0, x1, y0, y1 = self.swf.shapes[sid]
            for (px, py) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
                xs.append(m['a'] * px + m['c'] * py + m['tx'])
                ys.append(m['b'] * px + m['d'] * py + m['ty'])
        if not xs:
            return None
        return (min(xs), min(ys), max(xs), max(ys))

    def draw(self, cmds, canvas, O):
        """canvas: float32 HxWx4 premultiplied at scale Z, O = world coords of canvas (0,0)"""
        Z = self.Z
        H, W = canvas.shape[:2]
        for cmd in cmds:
            if cmd[0] == 'layer':
                layer = np.zeros_like(canvas)
                self.draw(cmd[1], layer, O)
                for f in cmd[2]:
                    # (blur: opt-in, SWF.blur_filter = True; the renders made before it ignore it)
                    if f['type'] == 'blur' and getattr(self.swf, 'blur_filter', False):
                        layer = blur_layer(layer, f, Z)
                    else:
                        layer = apply_filter(layer, f, Z)
                if len(cmd) > 4:
                    layer = apply_cx(layer, cmd[4])
                if cmd[3] == 'lighten' and getattr(self.swf, 'lighten', False):
                    blend_lighten(canvas, layer)
                elif cmd[3] == 'overlay' and getattr(self.swf, 'overlay', False):
                    blend_overlay(canvas, layer)
                else:
                    blend_into(canvas, layer, cmd[3])
                continue
            if cmd[0] == 'mask':
                g = cmd[1]
                layer = np.zeros_like(canvas)
                self.draw(g['items'], layer, O)
                mk = np.zeros_like(canvas)
                self.draw(g['mask'], mk, O)
                a = np.clip(mk[..., 3:4], 0, 1)
                layer *= a
                canvas *= (1 - layer[..., 3:4])
                canvas += layer
                continue
            if cmd[0] == 'leaf':
                _, sid, fr, m, c = cmd
                im = self.swf.leaf_image(sid, fr)
                x0, y0 = self.swf.leaves[sid][1]
            else:
                _, sid, m, c = cmd
                if sid in getattr(self.swf, 'morphs', ()):
                    continue
                im = self.swf.shape_image(sid)
                x0, x1, y0, y1 = self.swf.shapes[sid]
            A = np.array([[m['a'], m['c']], [m['b'], m['d']]], dtype=np.float64)
            det = np.linalg.det(A)
            if abs(det) < 1e-9:
                continue
            t = Z * (A @ np.array([x0, y0]) + np.array([m['tx'], m['ty']]) - np.array(O))
            # destination bbox
            w, h = im.size
            corners = np.array([[0, 0], [w, 0], [0, h], [w, h]], dtype=np.float64)
            dst = (A @ corners.T).T + t
            bx0 = int(math.floor(dst[:, 0].min())) - 2
            by0 = int(math.floor(dst[:, 1].min())) - 2
            bx1 = int(math.ceil(dst[:, 0].max())) + 2
            by1 = int(math.ceil(dst[:, 1].max())) + 2
            bx0, by0 = max(0, bx0), max(0, by0)
            bx1, by1 = min(W, bx1), min(H, by1)
            if bx1 <= bx0 or by1 <= by0:
                continue
            Ai = np.linalg.inv(A)
            tt = t - np.array([bx0, by0])
            off = -Ai @ tt
            data = (Ai[0, 0], Ai[0, 1], off[0], Ai[1, 0], Ai[1, 1], off[1])
            rs = Image.NEAREST if getattr(self.swf, 'nearest', False) else Image.BICUBIC
            src = im.convert('RGBa').transform((bx1 - bx0, by1 - by0), Image.AFFINE, data, resample=rs)
            arr = np.asarray(src, dtype=np.float32) / 255.0
            mult, add = c['mult'], c['add']
            if mult != [1.0, 1.0, 1.0, 1.0] or add != [0, 0, 0, 0]:
                a = arr[..., 3:4]
                rgb = np.where(a > 0, arr[..., :3] / np.maximum(a, 1e-6), 0)
                rgb = np.clip(rgb * np.array(mult[:3], dtype=np.float32) + np.array(add[:3], dtype=np.float32) / 255.0, 0, 1)
                a2 = np.clip(a * mult[3] + add[3] / 255.0, 0, 1)
                a2 = np.where(a > 0, a2, 0)
                arr = np.concatenate([rgb * a2, a2], axis=-1)
            sub = canvas[by0:by1, bx0:bx1]
            sub *= (1 - arr[..., 3:4])
            sub += arr

    def render_frames(self, states, hide=(), M=IDENT, cx=NOCX, margin=1.0, pad_to=None):
        """states: list of Instance snapshots (already positioned); returns (images at out scale, reg (px))"""
        cmd_lists = []
        for inst in states:
            cmds = []
            if inst.sid in self.swf.leaves:
                # the clip itself is rendered by FFDec
                n = self.swf.leaves[inst.sid][2]
                cmds.append(('leaf', inst.sid, (inst.age % n) + 1, M, cx))
            else:
                self.collect(inst, M, cx, set(hide), cmds)
            cmd_lists.append(cmds)
        bb = None
        for cmds in cmd_lists:
            b = self.bounds(cmds)
            if b:
                bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
        if bb is None:
            bb = (0, 0, 1, 1)
        step = 1.0 / self.k  # world units per output pixel
        ox = math.floor((bb[0] - margin) / step) * step
        oy = math.floor((bb[1] - margin) / step) * step
        ex = math.ceil((bb[2] + margin) / step) * step
        ey = math.ceil((bb[3] + margin) / step) * step
        Wz, Hz = int(round((ex - ox) * self.Z)), int(round((ey - oy) * self.Z))
        imgs = []
        for cmds in cmd_lists:
            canvas = np.zeros((Hz, Wz, 4), dtype=np.float32)
            self.draw(cmds, canvas, (ox, oy))
            im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
            im = im.resize((int(round((ex - ox) * self.k)), int(round((ey - oy) * self.k))), Image.LANCZOS).convert('RGBA')
            imgs.append(im)
        reg = (-ox * self.k, -oy * self.k)
        return imgs, reg


def timeline(swf, sid, nframes=None, ctrl=None, start=1, name=None):
    """snapshots of a sprite playing its own timeline from `start` (nested clips advance too)"""
    inst = Instance(swf, sid, name=name, ctrl=ctrl)
    if start != 1:
        inst.goto_and_play(start)
    n = nframes or swf.sprites[sid].nframes
    snaps = []
    for i in range(n):
        snaps.append(_snap(inst))
        inst.tick()
    return snaps


def _snap(inst):
    import copy
    swf = inst.swf
    inst.swf = None
    def strip(i):
        i.swf = None
        for e in i.display.values():
            if e['inst'] is not None:
                strip(e['inst'])
    for e in inst.display.values():
        if e['inst'] is not None:
            strip(e['inst'])
    c = copy.deepcopy(inst)
    def restore(i):
        i.swf = swf
        for e in i.display.values():
            if e['inst'] is not None:
                restore(e['inst'])
    restore(inst)
    restore(c)
    return c


def frame_states(swf, sid, frames, ctrl=None, name=None):
    """snapshots of a sprite stopped on each of `frames` (1-based or labels), nested clips at their first frame
    unless forced through ctrl"""
    out = []
    for f in frames:
        inst = Instance(swf, sid, name=name, ctrl=ctrl)
        inst.goto_and_stop(f)
        out.append(_snap(inst))
    return out
