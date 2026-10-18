# Graphics: from the SWF to the sprite sheet

Principle: **every picture comes from the original SWF**. Vector shapes are rasterized at 2 px per Flash pixel
(the game is drawn x2), bitmaps are kept at their native resolution, Flash timelines are replayed rather than
redrawn, and only the pictures the game can show are packed. The result must look like the Flash game zoomed x2,
down to the anti-aliasing.

## Contents
- Exports (FFDec)
- Choose a pipeline
- The Clip pipeline
- Colours
- Bitmaps, decor, measured values
- Text and numbers
- Data.hx, sheet, TexturePacker project, rebuild script
- Start screen
- Compare with the SWF
- Already met

## Exports (FFDec)

`sh scripts/tools/prepare_game.sh <archive game folder> <game> [swf names]` copies the SWF files into
`$KKP_WORK/<game>/` and writes, for each `<n>.swf`: `shp4_<n>/` (shapes at zoom 4, read by `swfrender`),
`shp1_<n>/` (zoom 1: bitmap fills at native resolution), `svg_<n>/` (matrices of the bitmap fills, curves),
`img_<n>/` (bitmaps), `fonts_<n>/` (embedded fonts as `.ttf`), `as_<n>/` (decompiled frame scripts) and
`dump_<n>.txt` (`swfdump.py`). Other exports when needed (`$FFDEC -help export`):

```sh
$FFDEC -format shape:png -zoom 8 -export shape shp8_gfx gfx.swf              # precise collision mask
$FFDEC -format sprite:png -zoom 4 -selectid 13 -export sprite leaf4 gfx.swf  # a sprite frame by frame ("morph" shapes)
```

## Choose a pipeline

- **Clip pipeline** (K-Slash, Kanji's Nightmare, Pioutch, Mini-Race): the code drives animated, nested
  MovieClips (`gotoAndPlay("run")`, named children, tints, frame scripts). Their timelines are exported as tables
  and replayed by the game's `Clip.hx`, like the Flash player did.
- **Simple renders** (Manda, Xian Xiang): fixed sprites or short animations with no nested logic. The asset script
  renders each animation with `clipexport.Exporter.render` / `write_anim` and writes the bounds the code needs in
  `meta.json`.
- What the original code **drew** with the Flash drawing API (Manda's snake, Mini-Race's skid marks) is redone
  with meshes or a RenderTexture, not `PIXI.Graphics` (too slow, see [pitfalls.md](pitfalls.md)).

## The Clip pipeline

`scripts/examples/kslash/kslash_assets.py` is the model; copy it to `<game>_assets.py` (it can live in
`scripts/examples/<game>/` with the rest of the port's tooling) and replace the symbol list.

```python
Gg = R.SWF(W + 'gfx.swf', W + 'shp4_gfx', Z=4)      # shapes rasterized by FFDec at zoom 4
Gg.flash_replace = True                             # Flash rule: a shape placed at a used depth keeps matrix + colour
Eg = C.Exporter(Gg, SRC, '', CUSTOM_G)               # CUSTOM_G: frame scripts that are not plain stop/play/goto
Eg.export(73, 'mcHero', strategy='flat', code=('bfx', 'kunai'), frames=HERO_FRAMES)
Eg.export(385, 'mcMonster', strategy='flat', code=('b1', 'b3', 'b4', 'b5'), frames=MON_FRAMES, cut_depths=(14, 18, 20))
Eg.export(311, 'mcNinjaShot')                       # automatic strategy
```

`Exporter.export(sid, name, ...)` splits a sprite into layers:

| Layer | When | Result |
|---|---|---|
| `FLAT` (k=0) | static entries between two dynamic ones | one image per frame: exact Flash anti-aliasing (characters) |
| `CUT` (k=1) | one shape moved by a matrix (hair, spinning shuriken, particles) | one image + a matrix per frame: few textures |
| `CLIP` (k=2) | a nested sprite whose timeline plays, or an instance named in `code` | a nested clip with its own playhead (Flash nested timelines keep playing when the parent stops) |
| `MASK` (k=3) | a mask layer (clipDepth) | masks the layers that reference it (avoid at run time if possible: shader) |

Arguments: `strategy` (`'flat'`, `'cut'`, automatic), `code` (instance names the game drives: they stay
accessible with `clip.get(name)`), `frames` (only the frames the game can reach: the rest stays empty, which keeps
the sheet small), `cut_depths` (depths kept as CUT inside a FLAT clip: sparse particles), `cx` (colour transform
baked in), `res` (texture resolution: 1 = 2 px per Flash pixel, 0.5 for bitmaps), `white` (white silhouettes for
colour tweens). Exporter settings: `clip_res` (resolutions allowed for nested clips shown bigger than their
symbol), `code_for` / `strategy_for` (per nested sprite id), `families` + `family_res` (frame-by-frame shapes drawn
by several clips exported once: K-Slash's monster explosion is one white sequence tinted at run time).

Frame scripts become tokens: `['s']` stop, `['p']` play, `['g', frame, play]`, `['r', lo, hi]` (gotoAndPlay a
random frame: visual random), `['x', name]` (a custom script, handled by `Clip.hx` or the game's
`clip.onScript`). The simple ones are read from the SWF; the others are written in `CUSTOM_G` from the decompiled
scripts (`as_<swf>/`), for example K-Slash:

```python
CUSTOM_G = {
    (40, 1): [['x', 'kflip']],      # k._xscale = _parent._xscale (headband letter never mirrored)
    (225, 1): [['r', 2, 6]],        # partSpark: gotoAndPlay(random(_totalframes - 1) + 2)
    (212, 19): [['x', 't0']],       # partSmoke: t = 0 (the particle dies)
    (385, 126): [['x', 'rmSelf']],  # monster death: removeMovieClip()
    (4, 60): [],                    # _parent.removeMovieClip(): its parent is placed on a timeline, Flash ignores it
}
```

The asset script writes `out/src/<anim>/<n>.png` (one folder per animation), `out/pivots.json`,
`out/clips.json` (the timeline tables) and `out/meta.json` (anything else the code needs). It should end by
removing the clips no root uses (K-Slash walks the clip tree from its `ROOTS`) and printing the texture area per
animation: the biggest entries are where to look when the sheet is too big.

**Runtime**: copy `resources/hx/games/kslash/Clip.hx` (the most complete for the AVM1 order: first-frame scripts
of nested clips after their placement, deferred self-removal with `Clip.flushRemoved()`, no interpolated flips)
and adapt the custom scripts. Other variants: `pioutch/Clip.hx` (`Clip.runLater` for frame scripts after a `goto`
of the code, blend modes, forced visibility), `minirace/Clip.hx` (tint + added colour, `setOverride`,
`snapshot` / `freeze`), `kanjisnightmare/Clip.hx` (the first version).

## Colours

`clipexport` sorts the colour transforms of the timelines:
- alpha only -> an alpha table (`al`);
- multiplication only -> a tint at run time (`tn` / `tns`, also applied to the nested clips);
- a solid colour (multiply 0 + offset) -> a white texture tinted;
- anything else -> baked in the textures.

Cases met in K-Slash:
- the super hero's afterimages (`mcShade`): a colour tween on a purple silhouette gives one flat colour per frame:
  exported as white silhouettes (`cx=C.WHITE`) tinted by the code with the colour computed from the SWF;
- the gems: a colour transform with negative offsets that no tint + added colour can reproduce: one variant of
  the gem per colour, baked (`Eg.export(317, 'gem%d' % f, cx=...)`);
- the 3 soldier levels: one clip, the skin (`b1`) and spikes (`b3`..`b5`) driven by the code as in the original,
  the death pieces take the skin frame (`['x', 'skin']`).

Code-driven colour (`Color.setTransform` in the original): reproduce Flash's integer rounding (`Cs.setPercentColor`)
with a `ColorMatrixFilter`, warmed at start (shader). `setTransform` also replaces the alpha (`aa: 100`): a clip
given an `_alpha` by the code becomes opaque (Paradice `MC.setPercentColor`).

Code-driven alpha (`mc._alpha = ...` on a clip of several shapes): Flash applies it to every shape, and to every
shape layer of a shape (fills drawn over other fills), on its own; a flattened image under the same alpha lets the
background through where Flash shows the lower shapes. Export such clips with `stack=True` (`clipexport`): their
FLAT layers are cut in slices of shapes that do not overlap (shapes split by `swfrender` `shape_layers`, from the
FFDec SVG export rendered by `rsvg-convert`: set `svg_dir` on the SWF), one texture each; Pixi applies a container's
alpha to each sprite, like Flash. Paradice balls (`root._alpha = 45 + random * 45`): an opaque square under the gem
body keeps it almost opaque in Flash, only the white glass shows the decor.

## Bitmaps, decor, measured values

- Bitmaps embedded in the SWF (decor, textures) are exported at their native resolution (`shp1_*`, `res=0.5`)
  and drawn x2 like the zoomed Flash player, never resampled.
- A shape filled with a bitmap: read the fill matrix in the FFDec SVG export (`patternTransform`) and place the
  bitmap with it (K-Slash `decor_frame`: the decor planes are a few bitmaps with matrices, `Data.DECOR_*`).
- A masked strip (K-Slash platforms: a texture strip under a mask scaled by the code) can often be drawn as a
  piece of the texture instead of a mask (`PlatGfx.hx`): no mask, no shader.
- Values the code measures on the display (`m._width` of the decor frames for the parallax factor) are measured
  in the SWF by the asset script and written in `Data.hx` (`FRONT_WIDTH`).

## Text and numbers

Never `PIXI.Text` for numbers: its placement depends on the fonts installed on the player's computer (the
Kanji's Nightmare counter was off on another machine). Render the digits 0-9 of the font embedded in the SWF
(`fonts_<swf>/*.ttf`, layout read from DefineFont2/3: advances, ascent) into images, and place them like Flash
lays out a text field: 2 px gutter, first baseline = top + 2 + ascent, left or centred (`digit_anims` and
`field_rect` in `kslash_assets.py`, `Digits.hx` at run time). Fixed texts are rendered with the clip that holds
them.

## Data.hx, sheet, TexturePacker project, rebuild script

- `<game>_data.py` turns `clips.json` + `meta.json` into `resources/hx/games/<game>/Data.hx` (K-Slash:
  `kslash_data.py`): the clip tables as one JSON string parsed once, and typed constants for the rest.
- `PACK_MAX=2040 python3 tools/pack_multi.py out/src sheet/<game> out/pivots.json`: TexturePacker "pixijs4"
  sheets (trim, 1 px extrude, identical frames aliased, multipack with `related_multi_packs`). 2040 and not 2048:
  a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites.
- `python3 tools/make_tps.py tools/tpl.tps out/src out/pivots.json <dest>/<game>.tps <game>`: the TexturePacker
  project with the pivots, delivered with `src/` so the sheet can be rebuilt in TexturePacker.
- `rebuild_assets.sh` chains everything and writes into the repository: copy
  `scripts/examples/kslash/rebuild_assets.sh`. Run it after every change of the asset scripts; it must be
  reproducible (K-Slash: rebuilding gives the committed files again).

K-Slash result: 52 clips, 66 animations, 634 frames (614 unique), one sheet of 2040 x 1891 (2.6 MB), against
4.8 MB in two sheets for the previous port.

## Start screen

`public/assets/img/gfx/artwork/<game>.jpg`, 600x600, required. Compose it from SWF renders (`swfrender`: the
decor, the hero, a few enemies, the title if the SWF has one) after the layout of the old thumbnail
(`public/assets/img/gfx/artwork/old/<game>.gif`) when there is one. Show it to the user.

## Compare with the SWF

Every animation drawn by the game must match the same clip rendered from the SWF:

1. a `pages.json` lists items `[clip name, frame, x, y, scale(, {nested clip: frame})]`
   (`scripts/examples/kslash/pages.json`: hero, afterimages, soldiers of the 3 levels and their death, tanker,
   flyer, bonuses, icons, shots, particles, interface, platforms);
2. `ref.py` renders those pages from the SWF (`$KKP_WORK/<game>/check/ref<i>.png`);
3. the game draws the same pages with its runtime (`Game.debugShow`, debug build) and `ncheck.mjs` screenshots them
   (`run<i>.png`);
4. `python3 tools/cmp_pages.py $KKP_WORK/<game>/check` writes `cmp<i>.png` (game | SWF | difference x4).
   A thin outline in the difference is anti-aliasing; a lit-up sprite is an offset, a wrong frame or colour;
   random effects (sparkles) differ by design.

Look at the pages (and show them to the user) before saying the graphics are right.

## Already met

- Flash filters (glow, blur) are in stage pixels: with the root at x2, a blur of 4 is 2 in map units. Bake them in
  the pictures (Mini-Race glows) rather than PIXI filters at run time.
- Stretched light streaks: `NineSlicePlane` with an untrimmed texture (corner pixels at 1/255 alpha count).
- Accumulated painting (skid marks): a RenderTexture updated once per game step, in `update` (seeks rebuild it).
- `hitTest` on an invisible shape: a run-length binary mask from a zoom 8 FFDec export, in `Data.hx`.
- "Morph" shapes: render the sprite that holds them frame by frame with FFDec (`-export sprite`).
- Obfuscated export / instance names in a released SWF (Pioutch): map them by hand in the asset script, with the
  decompiled code.
- Blend modes and SWF 8 filters on timelines: `swfrender` composes them (`swffilters.py`), so they survive inside
  a FLAT image, but `clipexport` has no blend or filter layer of its own. Pioutch needed blend layers and filters
  baked per clip: extend `clipexport.py` with new options, without changing what the existing options produce
  (rebuild K-Slash afterwards: the repository must stay unchanged).
- Bitmaps inside animated clips (Paradice: the portraits sliding in, the board of the multiplier panel):
  `Exporter.bitmaps = (SWF loaded from shp1_*, ids of the bitmap-filled shapes)` renders every CUT layer drawing
  only those shapes from the zoom 1 export at res 0.5 (native pixels); the vector layers of the same clip keep res 1.
- A nested clip under a solid colour (multiply 0 + offset) on some frames only (Paradice: the penguin eye that
  becomes the chick's beak): `Exporter.white_solid = True` draws those frames with a black tint + an additive white
  silhouette instead of baking the colour of the first frame.
- A text field in a device font (not embedded: Paradice's multiplier panel in Verdana Bold Italic): glyph images
  drawn from the system TTF with its own metrics (`ttf_layout` in `paradice_assets.py`), laid out at run time like
  the embedded ones (`paradice/Txt.hx`).
- A glow filter or a blend mode on a nested clip whose parts move on their own (Schizo Fuzz: the hero's outline on
  its `sub`, the `add` flash of the acorn): `Exporter.effects = True` keeps them on the CLIP layers (`fl`, `bl`), the
  game's `Clip` applies them at run time (`schizofuzz/FlashGlow.hx`, `arkadeo.FlashGlow` for the AS3 games: Flash's
  glow, a box blur of the alpha drawn under the clip; PIXI blends sprites, not containers: `add` is given to every picture inside). Baking a glow in each part
  would draw outlines inside the picture. A `lighten` layer inside a FLAT image: `SWF.lighten = True` (swfrender
  draws it normally otherwise, as the renders made before it did).
- Pixel art in Flash's "low" quality (Judo Commando: `root._quality = "low"`, bitmaps never smoothed): FFDec draws
  bitmap fills without smoothing at any zoom, so export the shapes at the zoom of the textures (`-zoom 2`, 2 px per
  Flash pixel), load them with `SWF.nearest = True` (nearest sampling instead of bicubic) and set
  `Exporter.fixed_res = 1.0` (every layer at that resolution, the matrices applied at run time); at run time the sheet
  is sampled without smoothing (`baseTexture.scaleMode = NEAREST`) and the sprites drawn on whole pixels
  (`roundPixels`). `Exporter.frames_for` gives the frames used by nested clips (the animation sets that the code only
  sends to their labels).
- A mask inside a clip given an alpha (Hypercube: the time ring `ha`, masked by a rotating quarter, under `horloge` at 20 %): `swfrender` gives the mask shape the colour transform of its parents, so the masked content is multiplied by the alpha twice (a Flash mask is only coverage). Render such a clip without the parent's alpha and apply the alpha at run time (or to the rendered layer, `examples/hypercube/ref.py`).
- Bitmap fills marked non-smoothed (fill style 0x42 / 0x43, "Allow smoothing" off in the FLA) are drawn by Flash 8 with
  the nearest pixel, even at high quality (Chakre Bouddha: the backgrounds, the lotus grown up to 900 %): pack them in
  their own sheet sampled with `NEAREST` (listed in the `related_multi_packs` of `<game>-0.json`), the vector pictures in
  the smoothed one (`chakrebouddha/rebuild_assets.sh`, `Tex.hx`).
- A mask (clipDepth) over a nested clip inside a clip exported FLAT (Digestomax: the fruit in Pioupiou's beak, a nested
  clip the code sets, under a moving disc mask): `Exporter.flat_masks = True` keeps it a MASK layer of that clip (otherwise
  the mask is drawn into the flat picture and the nested clip shows unmasked); make its pictures white (pitfalls).
- `swfdump.py` prints the first 99 frames of a sprite: read the labels of a longer timeline in `swfrender`
  (`G.sprites[sid].labels`); Schizo Fuzz's `launch` label (frame 136) only shows there.
- Blur filters were never drawn by `swfrender` (`apply_filter` had no case for them), nor inner glows / inner drop
  shadows: `SWF.blur_filters = True` / `SWF.inner_filters = True` draw them (off by default: the renders made before
  stay the same). Kanji Gaiden: the bonus icon's entrance and vanishing, the yellow highlight of the score digits, the
  inner glow of the bamboo leaves.
- A filter baked in a picture is in the pixels of its clip, Flash draws it in stage pixels: divide the blurs and
  distances of the filters by the scale the game shows the clip at (Kanji Gaiden: the hand at 0.589, the bonus at 0.8, a
  copy of the banana per plane at 0.5 / 0.25 / 0.125). Into a BitmapData drawn with a scaling matrix, the filters of the
  drawn clip are in bitmap pixels too (the bamboo leaves).
- Blurs tweened by a timeline on nested clips or cut layers (a throw, a rising score): `Exporter.blurs = True` writes
  them as `bf` tables applied at run time (`kanjigaiden/FlashBlur.hx`); a clip whose frames are mostly blurred can export
  those frames at half resolution as a second FLAT layer drawn x2 (Kanji Gaiden's bonus).
- Copies of a clip that only differ by scale and colour (one per plane) play the same timeline: store one table and
  derive the others (`base` / `ls`, `Clip.getDef`), from the copy at the highest resolution (a slight skew that a smaller
  copy's decomposition rounds to a rotation).
- Blend mode "overlay" and BlurFilter on placements inside a timeline (Opalus Factory: the glass of the opals, a hole
  coming in blurred): `SWF.overlay = True` and `SWF.blur_filter = True` compose them in `swfrender` (off, they are
  drawn normally / ignored, as the renders made before them). An "overlay" layer over moving clips (the tapi over the
  roll) cannot be baked: the planes under it are drawn together and a filter blends its picture over them
  (`opalusfactory/OverlayFilter.hx`).
- Outlines thinner than a pixel (FFDec SVG: `ffdec:has-small-stroke`, `original-stroke-width` 0.1): Flash draws them
  one pixel wide whatever the scale. Baked into a scaled picture they get faint when it shrinks and thick when it
  grows (Phagocytoz: the rim of the cells, from a few pixels to more than the screen). Draw the picture without that
  path (the SVG minus it, `rsvg-convert`) and the path at run time with a line of 1 stage pixel (2 canvas pixels)
  divided by the scale (`phagocytoz/MovieClip.hx` `Leaf.drawHair`, redrawn when the scale changes by 8 %).
- Line art of strokes thinner than 1 pixel (Pacifik: 0.25 px): Flash draws a stroke at least 1 stage pixel wide, and
  FFDec does the same at its export zoom, so a zoom 4 render reduced to 2 px per Flash pixel draws them half a Flash
  pixel wide (half their alpha). Compose such pictures from FFDec's SVG paths (shape coordinates) with each stroke
  max(width x scale, 1 Flash pixel) wide and rasterize them with `rsvg-convert` at 2 px per Flash pixel
  (`pacifik_assets.py`). Clips the code scales a lot (sparks grown 9 times, `_yscale = 0`) are drawn as segments at
  run time (`pacifik/Part.hx`). The archive's own screenshots (`sc/*.jpg`, real Flash at 300 x 300) are the reference
  for the look: Ruffle at 600 x 600 draws these strokes 1 screen pixel wide.
- Filters and `add` on the placements of CUT pictures (Punch-In: the glove shines, white shapes with a GlowFilter of 17 px
  placed in `add` mode at 77 %): CUT layers drop them by default. `Exporter.effect_layers = True` bakes the filters in the
  picture (after the placement's colour and alpha, Flash's order; in the picture's own coordinates, so the glow scales with
  the layer's matrix) and gives an `add` layer (or a FLAT group of `add` entries) `bl: 'add'`, drawn ADD at run time
  (`punchin/Clip.hx`). Nested frozen sprites keep their inner effects composed in their picture.
- A ColorMatrixFilter on a nested clip whose content moves (Puzzle-Manda: the bonuses 2 and 3 are bonus 1 recoloured,
  its stars turning at random inside): `Exporter.color_matrix = True` writes the matrix of each frame of the layer
  (`cms`, 0 = none) instead of dropping it, applied at run time by a PIXI ColorMatrixFilter (`puzzlemanda/Clip.hx`
  `setCm`; Flash's offsets are 0..255, PIXI's 0..1). With `effects`, a blurred nested clip in "add" (`bl` + `bf`)
  gets the blend on its blur filter: Flash adds the filtered picture, not each sprite.
