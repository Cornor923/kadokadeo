"""Flash sprite -> KadoKadeo "Clip" exporter (timeline tables + minimal textures).

A Flash MovieClip is exported as a small timeline played at runtime by the game's Clip class. Layers (z order):
  k=0 FLAT : the static entries between two dynamic ones flattened in one image per frame (index table `t`)
  k=1 CUT  : one static entry (shape or frozen sprite) drawn as an image moved by a matrix per frame; a depth
             showing a frame by frame shape animation is one CUT layer whose image changes (table `t`)
  k=2 CLIP : a nested clip with its own playhead (Flash nested timelines keep playing even when the parent is
             stopped), exported recursively
  k=3 MASK : a mask (clipDepth) of the layers above it that reference it (`mk`)
Dynamic entries are the nested sprites whose own timeline plays (or contains playing timelines) and the
instances named in `code` (driven by the game code). The FLAT strategy gives the exact Flash anti-aliasing
(characters), the CUT strategy keeps tweened clips light (hair, fingers, spinning shuriken, particles).

Colour transforms: alpha -> `al` table; multiply only -> runtime tint (`tn` / `tns`, also propagated to nested
clips); solid colour (multiply 0 + offset) -> white texture + tint; anything else is baked in the textures.

Frame actions are tokens: ['s'] stop, ['p'] play, ['g', frame, play], ['r', lo, hi] (gotoAndPlay a random frame,
visual random), ['x', name] (custom script of the runtime). Coordinates are output pixels (world units x K x
resolution of the clip), matrices [a, b, c, d, tx, ty].
"""
import math, hashlib, os
import numpy as np
from PIL import Image
import swfrender as R

K = 2
RES_STEPS = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
WHITE = dict(mult=[0.0, 0.0, 0.0, 1.0], add=[255, 255, 255, 0])
IDENTITY_MATRIX = (1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0)


def lod(s, steps=RES_STEPS):
    for r in steps:
        if r >= s * 0.9:
            return r
    return steps[-1]


def cx_key(cx):
    return (tuple(round(v, 4) for v in cx['mult']), tuple(int(v) for v in cx['add']))


def split_alpha(cx):
    """(colour part, alpha multiplier)"""
    m, a = cx['mult'], cx['add']
    return dict(mult=[m[0], m[1], m[2], 1.0], add=[a[0], a[1], a[2], a[3]]), m[3]


def colour_mode(col):
    """('tint', rgb) | ('solid', rgb) | ('bake', cx) for the colour part of a colour transform"""
    m, a = col['mult'], col['add']
    if a[3] != 0:
        return ('bake', col)
    if m[:3] == [0.0, 0.0, 0.0]:
        return ('solid', (a[0] / 255.0, a[1] / 255.0, a[2] / 255.0))
    if a[:3] == [0, 0, 0]:
        return ('tint', (m[0], m[1], m[2]))
    return ('tintadd', ((m[0], m[1], m[2]), (a[0] / 255.0, a[1] / 255.0, a[2] / 255.0)))


def decompose(a, b, c, d, tx, ty):
    """matrix -> [x, y, scaleX, scaleY, rotation (deg)] (+ [skewX, skewY] (rad, rotation 0) when it is skewed)"""
    det = a * d - b * c
    sx = math.hypot(a, b)
    if det < 0:
        sx = -sx
    if abs(sx) < 1e-9:
        return [round(tx, 2), round(ty, 2), 0, 0, 0]
    rot = math.atan2(b / sx, a / sx)
    sy = det / sx
    if abs(c + sy * math.sin(rot)) + abs(d - sy * math.cos(rot)) < 2e-3:
        return [round(tx, 2), round(ty, 2), round(sx, 5), round(sy, 5), round(math.degrees(rot), 3)]
    # skewed (PIXI decomposition)
    skx = -math.atan2(-c, d)
    sky = math.atan2(b, a)
    return [round(tx, 2), round(ty, 2), round(math.hypot(a, b), 5), round(math.hypot(c, d), 5), 0, round(skx, 5), round(sky, 5)]


def rgb_int(t):
    c = [max(0, min(255, int(round(v * 255)))) for v in t]
    return (c[0] << 16) | (c[1] << 8) | c[2]


class Exporter:
    def __init__(self, G, src_dir, prefix='', custom=None, log=print):
        self.G = G
        self.src = src_dir
        self.prefix = prefix
        self.custom = custom or {}     # (sid, frame) -> tokens (replaces the parsed actions of that frame)
        self.clips = {}                # name -> def
        self.variants = {}
        self.leaves = {}               # leaf key -> anim name
        self.pivots = {}
        self.anim_frames = {}
        self.area = {}
        self.log = log
        self._alive = {}
        self._names = {}
        self.clip_res = None           # resolutions allowed for nested clips (None = RES_STEPS)
        self.strategy_for = {}         # sid -> strategy of the nested clips
        self.code_for = {}             # sid -> instance names driven by the code in nested clips
        self.families = []             # sets of shapes drawn as one shared image sequence (frame by frame animations)
        self.family_res = None         # resolution of the family sequences (None: the one each use needs)
        # (SWF rendered at zoom 1, shape ids filled with a bitmap): a CUT layer drawing only those shapes is rendered
        # from that SWF at res 0.5, the bitmaps at their native resolution (None: every shape from self.G)
        self.bitmaps = None
        # a layer whose frames mix plain colours and a solid colour (multiply 0 + offset) is drawn with a black tint +
        # an additive white silhouette on its solid frames (False: the colour of its first frame is baked)
        self.white_solid = False
        self._subtree = {}
        self.warnings = 0
        # nested clips keep their glow filters ('fl': [[blurX, blurY, strength, 0xRRGGBB, alpha, passes]]) and blend
        # mode ('bl'), applied at run time (the game's Clip); off: they are dropped (FLAT images always compose them)
        self.effects = False
        # every CUT / CLIP / MASK layer at this resolution (None: the one its scale needs); with a SWF rendered with
        # `nearest` at the zoom K x fixed_res, the textures are the Flash pixels and the matrices are applied at run time
        self.fixed_res = None
        self.frames_for = {}           # sid -> frames used by the game in nested clips (as `frames` of export)
        # in the FLAT strategy, a mask (clipDepth) whose range holds a dynamic layer (a nested clip: the fruit in
        # Digestomax's beak) stays a MASK layer of it (False: the mask is drawn into the flat group and the dynamic
        # layer above it is not masked)
        self.flat_masks = False
        # the blur filters of the CUT / CLIP layers are applied at run time ('bf': [blurX, blurY, passes] of each frame,
        # 0 = none, in stage pixels), never baked in their images; off: dropped (FLAT images always compose them)
        self.blurs = False
        # a CUT picture keeps the filters of its placement (baked in its own coordinates: a glow scaled with the layer's
        # matrix), and a CUT layer, or a FLAT group of entries, placed with blend mode "add" is drawn without it and
        # gets 'bl': 'add' (applied at run time, onto what is under the clip); off: the filters of CUT pictures are
        # dropped and FLAT groups compose their blend mode over the lower layers of the clip (Punch-In's glove shines)
        self.effect_layers = False
        # the colour matrix filters of the nested clips are applied at run time ('cms': the 20 values of the Flash
        # ColorMatrixFilter of each frame, offsets in 0..255, 0 = none), with the glows of `effects`; off: dropped with
        # a warning
        self.color_matrix = False
        # a named instance driven by the code is a nested clip even with a single frame (Fafi 360: the code plays the
        # _skin / _shoes of every pose of a player, some have one picture); off: a single picture is a CUT layer
        self.code_clips = False

    # ------------------------------------------------------------------ helpers
    @staticmethod
    def mkctrl(ctrl, sid, f):
        c = dict(ctrl)
        c[sid] = f
        c['__noactions__'] = True
        return c

    def subtree(self, sid):
        """sprite ids and instance names reachable from a sprite (for the forced frames that matter)"""
        if sid in self._subtree:
            return self._subtree[sid]
        out = {sid}
        self._subtree[sid] = out
        for ops in self.G.sprites[sid].frames:
            for k, v in ops:
                if k == 'place':
                    if v.get('name'):
                        out.add(v['name'])
                    c = v.get('char')
                    if c in self.G.sprites:
                        out |= self.subtree(c)
        return out

    def warn(self, msg):
        self.warnings += 1
        self.log('  WARN ' + msg)

    def uname(self, base):
        n = self._names.get(base, 0)
        self._names[base] = n + 1
        return base if n == 0 else '%s_%d' % (base, n)

    def stops_at_1(self, sid):
        acts = self.custom.get((sid, 1)) or self.parsed_tokens(sid, 1)
        for t in acts:
            if t[0] == 's':
                return True
            if t[0] in ('g', 'r'):
                return False
        return False

    def alive(self, sid, ctrl):
        key = (sid, tuple(sorted((str(k), str(v)) for k, v in ctrl.items())))
        if key in self._alive:
            return self._alive[key]
        self._alive[key] = False
        sd = self.G.sprites[sid]
        forced = ctrl.get(sid)
        res = False
        if forced is None and sd.nframes > 1 and not self.stops_at_1(sid):
            res = True
        else:
            f = forced if isinstance(forced, int) else (sd.labels.get(forced, 1) if forced else 1)
            inst = R.Instance(self.G, sid, ctrl=self.mkctrl(ctrl, sid, f))
            for e in inst.display.values():
                if e['inst'] is not None and self.alive(e['inst'].sid, ctrl):
                    res = True
        self._alive[key] = res
        return res

    def parsed_tokens(self, sid, f):
        sd = self.G.sprites[sid]
        acts = sd.actions.get(f, [])
        out = []
        i = 0
        while i < len(acts):
            a = acts[i]
            nxt = acts[i + 1][0] if i + 1 < len(acts) else None
            if a[0] == 'stop':
                out.append(['s'])
            elif a[0] == 'play':
                out.append(['p'])
            elif a[0] in ('goto', 'label') and (a[0] == 'goto' or a[1] in sd.labels):
                out.append(['g', a[1] if a[0] == 'goto' else sd.labels[a[1]], 1 if nxt == 'play' else 0])
                if nxt == 'play':
                    i += 1
            elif a[0] == 'other':
                out.append(['?'])
            i += 1
        return out

    def tokens(self, sid, f):
        if (sid, f) in self.custom:
            return self.custom[(sid, f)]
        t = self.parsed_tokens(sid, f)
        if any(x[0] == '?' for x in t):
            self.warn('unhandled script in sprite %d frame %d -> ignored' % (sid, f))
            t = [x for x in t if x[0] != '?']
        return t

    # ------------------------------------------------------------------ rendering
    def render(self, cmd_lists, scale, margin=0.5, G=None):
        """command lists drawn on a common canvas at `scale` px per world unit -> (images, registration px)"""
        G = G or self.G
        rd = R.Renderer(G, scale)
        bb = None
        for cmds in cmd_lists:
            b = rd.bounds(cmds) if cmds else None
            if b:
                bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
        if bb is None:
            bb = (0, 0, 1 / scale, 1 / scale)
        step = 1.0 / scale
        ox = math.floor((bb[0] - margin) / step) * step
        oy = math.floor((bb[1] - margin) / step) * step
        ex = math.ceil((bb[2] + margin) / step) * step
        ey = math.ceil((bb[3] + margin) / step) * step
        Z = G.Z
        Wz, Hz = int(round((ex - ox) * Z)), int(round((ey - oy) * Z))
        W, H = int(round((ex - ox) * scale)), int(round((ey - oy) * scale))
        imgs = []
        for cmds in cmd_lists:
            canvas = np.zeros((Hz, Wz, 4), dtype=np.float32)
            if cmds:
                rd.draw(cmds, canvas, (ox, oy))
            im = Image.fromarray(np.clip(canvas * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBa')
            if (W, H) != (Wz, Hz):
                im = im.resize((W, H), Image.NEAREST if getattr(G, 'nearest', False) else Image.LANCZOS)
            imgs.append(im.convert('RGBA'))
        return imgs, (-ox * scale, -oy * scale)

    def write_anims(self, name, cmds, ents, res, white, white_cmds, G=None):
        """an animation (and its white silhouette `name`W on the same canvas when `white`)"""
        if not white:
            imgs, reg = self.render(cmds, K * res, G=G)
            self.write_anim(name, imgs, reg)
            return
        wc = [white_cmds(e) for e in ents]
        imgs, reg = self.render(cmds + wc, K * res, G=G)
        self.write_anim(name, imgs[:len(cmds)], reg)
        self.write_anim(name + 'W', imgs[len(cmds):], reg)

    def write_anim(self, name, imgs, reg):
        d = os.path.join(self.src, name)
        os.makedirs(d, exist_ok=True)
        w, h = imgs[0].size
        for i, im in enumerate(imgs):
            im.save(os.path.join(d, '%d.png' % (i + 1)), optimize=True)
        self.pivots[name] = [round(reg[0] / w, 6), round(reg[1] / h, 6)]
        self.anim_frames[name] = len(imgs)
        area = 0
        for im in imgs:
            bb = im.split()[3].getbbox()
            if bb:
                area += (bb[2] - bb[0]) * (bb[3] - bb[1])
        self.area[name] = area

    def group_cmds(self, entries, cx):
        """draw commands of display entries [(depth, entry)] (masks included) at the identity"""
        class Fake:
            pass
        f = Fake()
        f.display = dict(entries)
        out = []
        R.Renderer(self.G, K).collect(f, R.IDENT, cx, set(), out)
        return out

    def entry_cmds(self, e, cx):
        out = []
        R.Renderer(self.G, K)._emit(dict(e, matrix=R.IDENT, cx=R.NOCX), R.IDENT, cx, set(), out)
        if self.effect_layers and self.entry_filters(e) and out:
            out = [('layer', out, self.entry_filters(e), None)]
        return out

    def entry_filters(self, e):
        """the filters of a placement that change its picture (effect_layers)"""
        return [f for f in e.get('filters') or [] if not (f['type'] == 'blur' and f['blurX'] < 1 and f['blurY'] < 1)
                and not (f['type'] in ('glow', 'dropshadow') and f['strength'] <= 0)]

    def entry_blend(self, e):
        b = e.get('blend')
        return b if self.effect_layers and b not in (None, 'normal', 'layer') else None

    def runtime_blur(self, f):
        return self.blurs and f['type'] == 'blur'

    def blur_of(self, e):
        """[blurX, blurY, passes] of the blur filter of an entry applied at run time, or 0"""
        if not self.blurs:
            return 0
        for f in e.get('filters') or []:
            if f['type'] == 'blur' and (f['blurX'] >= 1 or f['blurY'] >= 1):
                return [round(f['blurX'], 3), round(f['blurY'], 3), max(1, f.get('passes', 1))]
        return 0

    def inst_key(self, inst):
        if inst is None:
            return None
        return (inst.sid, inst.frame, tuple(sorted((d, self.inst_key(x['inst']), x['char']) for d, x in inst.display.items())))

    def bitmap_only(self, ents):
        """the entries draw only shapes filled with a bitmap (see self.bitmaps)"""
        if self.bitmaps is None:
            return False
        ids = set()
        for e in ents:
            for c in self.entry_cmds(e, R.NOCX):
                if c[0] != 'shape':
                    return False
                ids.add(c[1])
        return bool(ids) and ids <= set(self.bitmaps[1])

    def leaves_anim(self, ents, bake, res, white=False, G=None):
        """one image per distinct entry (shape / frozen sprite) on a common canvas -> (anim, {entry key: frame})"""
        keys = []
        cmds = []
        fam = None
        if all(e['inst'] is None for e in ents):
            chars = {e['char'] for e in ents}
            for F in self.families:
                if chars <= set(F):
                    fam = F
        if fam is not None:
            ents = [dict(char=c, inst=None, matrix=R.IDENT, cx=R.NOCX, name=None, clip=None, filters=[], blend=None) for c in sorted(fam)]
        uents = []
        for e in ents:
            k = (e['char'], self.inst_key(e['inst'])) + ((repr(self.entry_filters(e)),) if self.effect_layers else ())
            if k not in keys:
                keys.append(k)
                uents.append(e)
                cmds.append(self.entry_cmds(e, bake))
        lkey = (tuple(keys), cx_key(bake), res, white) + ((id(G),) if G is not None else ())
        if lkey not in self.leaves:
            name = self.uname('%sl%d' % (self.prefix, ents[0]['char']))
            self.write_anims(name, cmds, uents, res, white, lambda e: self.entry_cmds(e, WHITE), G=G)
            self.leaves[lkey] = name
        return self.leaves[lkey], {k: i + 1 for i, k in enumerate(keys)}

    # ------------------------------------------------------------------ clips
    def export(self, sid, name=None, ctrl=None, strategy=None, code=(), frames=None, cx=None, res=1.0, cut_depths=(), white=False,
               stack=False):
        """export sprite `sid` as a clip; returns the clip name.
        ctrl: frames forced for nested sprites (by sid or instance name), as in swfrender
        strategy: 'flat' | 'cut' | None (automatic)
        code: instance names driven by the game code (kept as their own layers)
        frames: frames of the clip used by the game (the others stay empty), None = all
        cx: colour transform baked in the clip (inherited from the parent instance)
        res: resolution of the textures (1 = K px per world unit)
        cut_depths: depths kept as CUT layers in the FLAT strategy (sparse particles...)
        stack: the code gives the clip an alpha < 1 (`_alpha`): Flash applies it to every shape (and shape layer)
               on its own, so a FLAT layer becomes several layers of shapes that do not overlap (Pixi applies the
               alpha of a container to each sprite on its own too), see stack_layers; nested clips as well"""
        ctrl = dict(ctrl or {})
        cx = cx or R.NOCX
        code = tuple(code) or self.code_for.get(sid, ())
        if strategy is None:
            strategy = self.strategy_for.get(sid)
        if frames is None:
            frames = self.frames_for.get(sid)
        sub = self.subtree(sid)
        ctrl = {k: v for k, v in ctrl.items() if k in sub}
        vkey = (sid, tuple(sorted((str(k), str(v)) for k, v in ctrl.items())), strategy, tuple(code), tuple(frames or ()),
                cx_key(cx), res, tuple(cut_depths), white, stack)
        if vkey in self.variants:
            return self.variants[vkey]
        G = self.G
        sd = G.sprites[sid]
        n = sd.nframes
        cname = name or self.uname('%sc%d' % (self.prefix, sid))
        self.variants[vkey] = cname
        used = set(frames) if frames else set(range(1, n + 1))
        forced = ctrl.get(sid)
        if forced is not None:
            used = {forced if isinstance(forced, int) else sd.labels[forced]}

        # display list of the used frames + placement ids (frame where the instance at a depth was created)
        states, pids, cur = {}, {}, {}
        for f in range(1, n + 1):
            for kind, v in sd.frames[f - 1]:
                if kind == 'remove':
                    cur.pop(v, None)
                elif 'char' in v and not (v.get('move') and v['depth'] in cur and
                                          (cur[v['depth']][0] == v['char'] or v['char'] not in G.sprites)):
                    cur[v['depth']] = (v['char'], f)
            pids[f] = dict(cur)
            if f in used:
                states[f] = R.Instance(G, sid, ctrl=self.mkctrl(ctrl, sid, f))
        if strategy is None:
            strategy = self.auto_strategy(states)

        # depths showing several shapes (frame by frame animation): one CUT layer with an image per shape
        depth_chars = {}
        for st in states.values():
            for d, e in st.display.items():
                if e['inst'] is None:
                    depth_chars.setdefault(d, set()).add(e['char'])
        seq_depths = {d for d, c in depth_chars.items() if len(c) > 1}

        layers, order, per_frame = {}, [], {}
        for f in sorted(states):
            st = states[f]
            seq = []
            depths = sorted(st.display)
            masks = [(d, st.display[d]['clip']) for d in depths if st.display[d]['clip'] is not None]
            group, gkey = [], None
            for d in depths:
                e = st.display[d]
                sub = e['inst']
                is_dyn = sub is not None and (e['name'] in code or self.alive(sub.sid, ctrl))
                is_named_leaf = sub is not None and e['name'] in code and not self.alive(sub.sid, ctrl) and \
                    G.sprites[sub.sid].nframes == 1 and not self.code_clips
                keep_mask = self.flat_masks and e['clip'] is not None and any(
                    d < d2 <= e['clip'] and st.display[d2]['inst'] is not None and
                    (st.display[d2]['name'] in code or self.alive(st.display[d2]['inst'].sid, ctrl)) for d2 in depths)
                if strategy == 'flat' and not is_dyn and not keep_mask and (d not in cut_depths or sub is not None):
                    group.append((d, e))
                    continue
                if group:
                    seq.append(('flat', ('f', gkey), group))
                    group = []
                if e['clip'] is not None:
                    item = ('mask', ('m', d), (d, e))
                elif is_named_leaf:
                    item = ('cut', ('n', e['name']), (d, e))
                elif is_dyn:
                    item = ('clip', ('c', d, e['char'], e['name']), (d, e))
                elif d in seq_depths and sub is None:
                    item = ('cut', ('q', d), (d, e))
                else:
                    item = ('cut', ('s', d, e['char']), (d, e))
                masked_by = [md for (md, cd) in masks if md < d <= cd]
                if masked_by and e['clip'] is None:
                    item = item + (('mask', ('m', masked_by[-1])),)
                seq.append(item)
                gkey = item[1]
            if group:
                seq.append(('flat', ('f', gkey), group))
            per_frame[f] = [(it[0], it[1]) for it in seq]
            for it in seq:
                lk = (it[0], it[1])
                if lk not in layers:
                    layers[lk] = dict(kind=it[0], rows={}, masked=None)
                    order.append(lk)
                layers[lk]['rows'][f] = it[2]
                if len(it) > 3:
                    layers[lk]['masked'] = it[3]
        # z order of the layers: topological sort of the order seen in every frame (ties: first seen first)
        first = {lk: i for i, lk in enumerate(order)}
        after = {lk: set() for lk in order}
        indeg = {lk: 0 for lk in order}
        for lst in per_frame.values():
            for x, y in zip(lst, lst[1:]):
                if y not in after[x]:
                    after[x].add(y)
                    indeg[y] += 1
        order2 = []
        ready = sorted([lk for lk in order if indeg[lk] == 0], key=lambda k: first[k])
        while ready:
            x = ready.pop(0)
            order2.append(x)
            for y in after[x]:
                indeg[y] -= 1
                if indeg[y] == 0:
                    ready.append(y)
            ready.sort(key=lambda k: first[k])
        if len(order2) != len(order):
            self.warn('%s: cyclic layer order' % cname)
            order2 += [lk for lk in order if lk not in order2]
        order = order2
        # the merged order must respect the order of every frame
        pos = {lk: i for i, lk in enumerate(order)}
        for f, lst in per_frame.items():
            ix = [pos[lk] for lk in lst]
            if ix != sorted(ix):
                self.warn('%s: layer order of frame %d differs from the merged order %s' % (cname, f, [(lk[1], pos[lk]) for lk in lst]))
                break

        # (a FLAT layer of a stacked clip gives several layers: out index of the first one of each)
        out_layers, at = [], {}
        for i, lk in enumerate(order):
            at[lk] = len(out_layers)
            if stack and layers[lk]['kind'] == 'flat':
                out_layers += self.stack_layers(cname, layers[lk], n, cx, res, i, white)
            else:
                out_layers.append(self.build_layer(cname, layers[lk], n, pids, ctrl, cx, res, i, white, stack))
        for lk in order:
            m = layers[lk]['masked']
            if m is not None and m in at:
                out_layers[at[lk]]['mk'] = at[m]

        cdef = dict(n=n, r=res, layers=out_layers)
        if white:
            cdef['w'] = 1
        if forced is None:
            acts = {}
            for f in range(1, n + 1):
                t = self.tokens(sid, f)
                if t:
                    acts[str(f)] = t
            if acts:
                cdef['acts'] = acts
        else:
            cdef['start'] = min(used)
            cdef['still'] = 1
        if sd.labels:
            cdef['labels'] = dict(sd.labels)
        self.clips[cname] = cdef
        self.log('clip %-14s sprite %-4d %-4s frames=%-3d layers=%-2d res=%.2f' % (cname, sid, strategy, n, len(out_layers), res))
        return cname

    def clip_effects(self, cname, li, rows, out, n=None):
        """glow filters and blend mode of a nested clip (the same on every frame of the layer); with `color_matrix`,
        the colour matrix of each frame (n: frames of the clip)"""
        if self.color_matrix:
            def cm_of(e):
                for f in e.get('filters') or []:
                    if f['type'] == 'colormatrix' and not all(abs(a - b) < 1e-6 for a, b in zip(f['matrix'], IDENTITY_MATRIX)):
                        return [round(v, 6) for v in f['matrix']]
                return 0
            cms = [cm_of(rows[f]) if f in rows else 0 for f in range(1, n + 1)]
            if any(c != 0 for c in cms):
                out['cms'] = cms
            rows = {f: dict(e, filters=[x for x in e.get('filters') or [] if x['type'] != 'colormatrix'])
                    for f, e in rows.items()}
        fls = {repr(e.get('filters') or []) for e in rows.values()}
        bls = {e.get('blend') for e in rows.values()}
        if len(fls) > 1 or len(bls) > 1:
            self.warn('%s layer %d: filters or blend mode change over frames (first kept)' % (cname, li))
        e = rows[min(rows)]
        fl = []
        for f in e.get('filters') or []:
            if self.runtime_blur(f):
                continue
            if f['type'] == 'colormatrix' and all(abs(a - b) < 1e-6 for a, b in zip(f['matrix'], IDENTITY_MATRIX)):
                continue
            if f['type'] != 'glow' or f.get('inner') or f.get('knockout'):
                self.warn('%s layer %d: %s filter dropped' % (cname, li, f['type']))
                continue
            r, g, b, a = f['color']
            fl.append([f['blurX'], f['blurY'], f['strength'], (r << 16) | (g << 8) | b, round(a / 255.0, 4), f.get('passes', 1)])
        if fl:
            out['fl'] = fl
        if e.get('blend') not in (None, 'normal', 'layer'):
            out['bl'] = e['blend']

    def auto_strategy(self, states):
        chars, cxs, masks = set(), set(), False
        for st in states.values():
            for e in st.display.values():
                chars.add(e['char'])
                masks = masks or e['clip'] is not None
                col, _ = split_alpha(e['cx'])
                if colour_mode(col)[0] == 'bake':
                    cxs.add(cx_key(col))
        if masks or len(cxs) > 2:
            return 'flat'
        return 'cut' if len(chars) * 3 < len(states) else 'flat'

    def stack_layers(self, cname, L, n, cx_in, res, li, white):
        """a FLAT layer of a stacked clip: the shapes of each frame (split in their shape layers) drawn in order,
        cut in slices of shapes that do not overlap -> one FLAT layer per slice (k=0, `<clip>_<li>s<j>`)"""
        rows = L['rows']
        frames = sorted(rows)
        rd = R.Renderer(self.G, K)

        def expand(cmds):
            out = []
            for c in cmds:
                if c[0] == 'shape':
                    out += [('shape', v) + c[2:] for v in self.G.shape_layers(c[1])]
                else:
                    out.append(c)
            return out

        slices, wslices = {}, {}
        for f in frames:
            cmds = expand(self.group_cmds(rows[f], cx_in))
            wcmds = expand(self.group_cmds(rows[f], WHITE))
            assert len(cmds) == len(wcmds), (cname, f)
            bb = rd.bounds(cmds)
            groups, acc = [], None
            if bb:
                Z = self.G.Z
                O = (bb[0] - 1, bb[1] - 1)
                shape = (int((bb[3] - bb[1] + 2) * Z) + 1, int((bb[2] - bb[0] + 2) * Z) + 1, 4)
                for i, c in enumerate(cmds):
                    cv = np.zeros(shape, dtype=np.float32)
                    rd.draw([c], cv, O)
                    a = cv[..., 3]
                    if acc is None or (np.minimum(acc, a) > 0.6).sum() > 4:
                        groups.append([i])
                        acc = a
                    else:
                        groups[-1].append(i)
                        acc = np.maximum(acc, a)
            slices[f] = [[cmds[i] for i in g] for g in groups]
            wslices[f] = [[wcmds[i] for i in g] for g in groups]
        out = []
        for j in range(max(len(s) for s in slices.values())):
            fs = [f for f in frames if j < len(slices[f])]
            uniq, ids, idx = [], {}, {}
            for f in fs:
                c = slices[f][j]
                h = hashlib.sha1(repr(c).encode()).hexdigest()
                if h not in ids:
                    ids[h] = len(uniq) + 1
                    uniq.append(c)
                idx[f] = ids[h]
            aname = self.uname('%s_%ds%d' % (cname, li, j))
            ufr = sorted(set(idx.values()))
            first = {v: f for f, v in sorted(idx.items(), reverse=True)}
            self.write_anims(aname, uniq, [first[v] for v in ufr], res, white, lambda f: wslices[f][j])
            out.append(dict(k=0, a=aname, t=[idx.get(f, 0) for f in range(1, n + 1)]))
        return out

    def build_layer(self, cname, L, n, pids, ctrl, cx_in, res, li, white, stack=False):
        kind, rows = L['kind'], L['rows']
        if kind == 'flat':
            frames = sorted(rows)
            bl = None
            if self.effect_layers:
                bls = {self.entry_blend(e) for f in frames for d, e in rows[f]}
                if len(bls) == 1 and None not in bls:
                    bl = next(iter(bls))
                    rows = {f: [(d, dict(e, blend=None)) for d, e in rows[f]] for f in frames}
                elif bls - {None}:
                    self.warn('%s layer %d: FLAT group mixing blend modes (composed in the picture)' % (cname, li))
            cmd_lists = [self.group_cmds(rows[f], cx_in) for f in frames]
            uniq, ids, idx = [], {}, {}
            for f, c in zip(frames, cmd_lists):
                h = hashlib.sha1(repr(c).encode()).hexdigest()
                if h not in ids:
                    ids[h] = len(uniq) + 1
                    uniq.append(c)
                idx[f] = ids[h]
            aname = self.uname('%s_%d' % (cname, li))
            ufr = sorted(set(idx.values()))
            first = {v: f for f, v in sorted(idx.items(), reverse=True)}
            self.write_anims(aname, uniq, [first[v] for v in ufr], res, white, lambda f: self.group_cmds(rows[f], WHITE))
            out = dict(k=0, a=aname, t=[idx.get(f, 0) for f in range(1, n + 1)])
            if bl is not None:
                out['bl'] = bl
            return out

        f0 = min(rows)
        depth = {f: de[0] for f, de in rows.items()}
        rows = {f: de[1] for f, de in rows.items()}
        e0 = rows[f0]
        name = e0['name']
        alphas, tints, adds, scales = {}, {}, {}, []
        cols = {}
        for f, e in rows.items():
            m = e['matrix']
            scales.append(max(math.hypot(m['a'], m['b']), math.hypot(m['c'], m['d'])))
            col, alpha = split_alpha(R.cx_mul(cx_in, e['cx']))
            alphas[f] = alpha
            cols[f] = col
        # effect_layers: Flash applies the colour transform of a placement (its alpha too) before its filters (a glow
        # shows through a translucent object): baked in the picture with the filter
        fx = kind == 'cut' and self.effect_layers and any(self.entry_filters(e) for e in rows.values())
        if fx:
            full = {f: R.cx_mul(cx_in, e['cx']) for f, e in rows.items()}
            if len({cx_key(c) for c in full.values()}) > 1:
                self.warn('%s layer %d: colour of a filtered layer changes over frames (first kept)' % (cname, li))
            cols = {f: full[f0] for f in rows}
            alphas = {f: 1.0 for f in rows}
        modes = {f: (('tint', (1, 1, 1)) if kind == 'mask' else ('bake', c) if fx else colour_mode(c))
                 for f, c in cols.items()}
        constant = len({cx_key(c) for c in cols.values()}) == 1
        need_white = not constant and any(md[0] == 'tintadd' for md in modes.values())
        if self.white_solid and not constant and any(md[0] == 'solid' for md in modes.values()):
            need_white = True
        bake = None
        for f in rows:
            mode, v = modes[f]
            if need_white and mode == 'solid':
                # solid frames of a colour tween: black tint + added colour
                tints[f], adds[f], bk = (0, 0, 0), v, R.NOCX
            elif mode == 'tint':
                tints[f], bk = v, R.NOCX
            elif mode == 'solid':
                tints[f], bk = v, WHITE
            elif mode == 'tintadd' and not constant:
                # colour tween: tint + additive white silhouette at run time
                tints[f], adds[f], bk = v[0], v[1], R.NOCX
                need_white = True
            else:
                tints[f], bk = (1, 1, 1), cols[f]
            if bake is None:
                bake = bk
            elif cx_key(bake) != cx_key(bk):
                self.warn('%s layer %d: baked colour changes over frames (first kept)' % (cname, li))
        smax = max(scales) * res
        if kind == 'clip':
            child_res = lod(smax, self.clip_res or RES_STEPS)
        elif kind == 'mask':
            child_res = lod(smax, [0.5, 1.0])
        else:
            child_res = lod(smax)
        if name in ('arm', 'leg0', 'leg1', 'head'):
            child_res = res   # parts turned by the code: same resolution as the body around them
        if self.fixed_res is not None:
            child_res = self.fixed_res
        if kind == 'cut' and self.family_res and all(e['inst'] is None for e in rows.values()):
            chars = {e['char'] for e in rows.values()}
            if any(chars <= set(F) for F in self.families):
                child_res = self.family_res   # one shared sequence for every use of the family

        alt = None
        if kind == 'cut' and self.bitmap_only(list(rows.values())):
            alt, child_res = self.bitmaps[0], 0.5
        out = {}
        tex = None
        wh = white or need_white
        if kind == 'clip':
            out['k'] = 2
            out['a'] = self.export(e0['inst'].sid, ctrl=ctrl, cx=bake, res=child_res, white=wh)
            if self.effects:
                self.clip_effects(cname, li, rows, out, n)
        else:
            if stack and kind == 'cut':
                for e in rows.values():
                    cm = self.entry_cmds(e, R.NOCX)
                    if len(cm) > 1 or (cm and cm[0][0] == 'shape' and len(self.G.shape_layers(cm[0][1])) > 1):
                        self.warn('%s layer %d: CUT layer of several shapes or shape layers in a stacked clip (one image)' % (cname, li))
                        break
            out['k'] = 1 if kind == 'cut' else 3
            ents = [rows[f] for f in sorted(rows)]
            out['a'], tex = self.leaves_anim(ents, bake, child_res, wh and kind == 'cut', G=alt)
            if len(tex) > 1:
                out['t'] = [tex[(rows[f]['char'], self.inst_key(rows[f]['inst'])) +
                                ((repr(self.entry_filters(rows[f])),) if self.effect_layers else ())] if f in rows else 0
                            for f in range(1, n + 1)]
        if name:
            out['nm'] = name
        if kind == 'cut' and self.effect_layers:
            bls = {self.entry_blend(e) for e in rows.values()}
            if len(bls) == 1 and None not in bls:
                out['bl'] = next(iter(bls))
            elif bls - {None}:
                self.warn('%s layer %d: blend mode changes over frames (dropped)' % (cname, li))
        p = [0] * n
        for f, e in rows.items():
            p[f - 1] = pids[f][depth[f]][1] if kind == 'clip' and depth[f] in pids[f] else 1
        if kind == 'clip':
            out['p'] = p
        elif 't' not in out:
            out['t'] = [1 if x else 0 for x in p]
        kr = res / child_res
        mats = [None] * n
        for f, e in rows.items():
            m = e['matrix']
            mats[f - 1] = decompose(m['a'] * kr, m['b'] * kr, m['c'] * kr, m['d'] * kr, m['tx'] * K * res, m['ty'] * K * res)
        ms = [x for x in mats if x is not None]
        if all(x == ms[0] for x in ms):
            out['m0'] = ms[0]
        else:
            out['m'] = mats
        if self.blurs:
            bf = [self.blur_of(rows[f]) if f in rows else 0 for f in range(1, n + 1)]
            if any(bf):
                out['bf'] = bf
        if any(abs(a - 1) > 1e-4 for a in alphas.values()):
            al = [round(alphas.get(f, 1.0), 4) for f in range(1, n + 1)]
            if len(set(alphas.values())) == 1:
                out['al0'] = al[f0 - 1]
            else:
                out['al'] = al
        if adds:
            av = {rgb_int(adds.get(f, (0, 0, 0))) for f in rows}
            if len(av) == 1:
                out['ad'] = next(iter(av))
            else:
                out['ads'] = [rgb_int(adds.get(f, (0, 0, 0))) for f in range(1, n + 1)]
        tv = set(tints.values())
        if tv != {(1, 1, 1)} and tv != {(1.0, 1.0, 1.0)}:
            if len(tv) == 1:
                out['tn'] = rgb_int(next(iter(tv)))
            else:
                out['tns'] = [rgb_int(tints[f]) if f in tints else 0xFFFFFF for f in range(1, n + 1)]
        return out
