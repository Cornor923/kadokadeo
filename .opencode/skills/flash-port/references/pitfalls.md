# Known pitfalls

Each of these cost hours on a previous port. Read them before writing the display code of a game, and again when a
bug looks impossible. The Flash / MTypes semantics are in [original.md](original.md).

## Contents
- Haxe and PixiJS
- Interpolation and display
- Replays and determinism
- Graphics pipeline

## Haxe and PixiJS

- **A method named `render()`** in a class extending a PIXI `DisplayObject` silently overrides
  `DisplayObject.render(renderer)` (missing from the externs): the whole stage is drawn into a RenderTexture.
  Never name a method `render`.
- **First use of a filter or a mask compiles a shader**: 10 to 80+ ms frozen, at the worst moment (first monster
  hit, first super hero). Warm every filter / mask the game uses in the constructor (`Game.warmShaders` of K-Slash
  and Manda) and check with `shaders.mjs`. Avoid masks during the game: draw the background over the masked part
  (Manda `bgTop`) or a piece of the texture (K-Slash `PlatGfx`).
- **`ASprite.zsort`** sorts all the children at each insertion and `DepthManager` reindexes beyond 1000 clips: with
  many clips, one container per plane (`manda/Plans.hx`).
- **`PIXI.Graphics` thick round strokes**: about 200 vertices per stroke, 3 to 9 ms for a long snake. Use a mesh
  (strip + textured anti-aliased discs) in a x2 supersampled RenderTexture (`manda/SnakeGfx.hx`).
- **`PIXI.Text` for numbers**: its layout depends on the fonts installed on the player's computer. Digits of the
  SWF's font as images (`Digits.hx`).
- **Sheets of 2048 px**: power-of-two textures get mipmaps that bleed into neighbouring sprites: `PACK_MAX=2040`.
- **PixiJS 6 `extract.pixels()`** already un-premultiplies; `renderer.render(obj, {transform})` applies the
  object's own transform too; filters assigned for a stamp stay on the sprite; a `Graphics` only removed (not
  destroyed) leaks its GPU geometry (Iron Chouquette's plasma).
- **A filter with several passes** (`FilterSystem.applyFilter` called more than once in `apply`): its 4th argument is a
  `CLEAR_MODES` number in PixiJS 6 (`1` clears), `true` leaves the old pixels of the pooled texture in the next pass;
  a fragment shader reading `inputSize` / `outputFrame` must declare them `highp` (else the program does not link).
- **A filter of several passes** (`filterManager.applyFilter` in a custom `apply`): the clear mode is compared with
  `===` to `CLEAR_MODES.CLEAR` (the number 1): passing `true` does not clear, and a pooled texture of
  `getFilterTexture()` keeps what a previous filter drew in it (Chakre Bouddha: chained glows filled their whole area).
  A pooled texture can also be bigger than the input: never sample two textures with the same `vTextureCoord`, and
  take the texel size of the texture sampled (`chakrebouddha/FlashFilters.hx`).
- **A PIXI sprite mask uses the red channel of its picture** (`SpriteMaskFilter`: `masky.r * masky.a`), Flash only the
  coverage of the mask: a green mask (Digestomax's `mcMask`) hides everything. Make mask pictures white.
- **`renderer.render(obj, {renderTexture, transform})` with filters on `obj`** (PixiJS 6.0.2): the filters are
  computed without the transform, the picture comes out blurred and dim (Pacifik's canon caches). Put `obj` in a
  container that carries the scale and the offset, and render that container.
- **Pictures drawn off the stage** (a cache rendered by the game, Pacifik `CanonMC`): KadoKadeo copies the current
  state to the previous one only for the stage tree; call `updateState()` on the off-stage tree at each step and
  `updateGraphics(alpha)` before drawing it (from a ticker listener between the NORMAL and LOW priorities), or it
  interpolates from its first state forever.
- **Reading the GPU back for gameplay** (pixels of a RenderTexture) gives different results on different graphics
  cards: a replay recorded on one machine diverged on another. Keep a CPU copy of what the gameplay reads.

## Interpolation and display

- **A sprite recreated or re-parented** loses its `_prevState`: no interpolation for a step, a visible jump. Carry
  the shown position over (Kanji's Nightmare `Sprite.setRoot(mc, true)`, Kanji's Adventure `Ent.display(true)`);
  check with `stutter.mjs`.
- **A teleport** (first placement, respawn, camera snap) slides across the screen unless the previous state is set
  to the current one (K-Slash: `snapped` hero, `_prevState.copyFrom(_curState)` on the planes).
- **A flip** (scale changing sign) interpolated shows the sprite squeezed flat ("paper" effect): `Clip.noFlipLerp`.
- **A wrapping map** (a torus): the map and the clips drawn at the copy nearest to the screen jump by a period;
  interpolated, they slide across the screen. Interpolate modulo the period, and move the previous state to the same
  side (Klinker Surprise `MC.wrap`).
- **A lagged display** (40 frames/s originals, `MC.hx`): a clip removed by the code must stay on screen until the
  display reaches the Flash frame it was removed in, or the old picture disappears one frame before the new one is
  shown (a whole map at a level change).
- **Gameplay must not read interpolated values.** `mc._x = mc.x` style code can copy an interpolated value back
  into the game state.

## Replays and determinism

- Visual random on `Seed.randomVfx`, gameplay random on `Seed.random`; trigonometry / powers of the gameplay
  rounded (`Cs.q`).
- Nothing in the gameplay reads the display: interpolated positions, PIXI bounds, pixels, `getBounds`.
- What accumulates on screen (paint, skid marks) is updated in `update`, not at render time, so a seek rebuilds
  it; what is only for the eye can be skipped during a seek.
- After the game over, no point may be added (end animations keep running).
- Mouse: `MouseManager` releases the buttons on `pointerleave`: `canvas.setPointerCapture` on `pointerdown`.
- Replay events: `recordEvent` without a frame is applied at the **next** frame. `consumeEvents()` only returns the
  events of a replay being played: in the live game set a flag when recording and apply it at the next `update`, the
  frame the replay gives it back at (K-Slash NIGHT: `nightTyped` then `setNight`; Puzzle-Manda `touchTyped`). Applying
  it only from `consumeEvents()` leaves the live game without it: its replay diverges.
- Statics survive from one game to the next in the same page (several games, replays): reset them.
- Shared behaviour of KadoKadeo: replay speed and pause only apply while watching a replay; hiding the tab does
  not pause a live game; keys typed in a text field of the page are ignored.

## Graphics pipeline

- `Data.hx` is generated: a fix made by hand disappears at the next `rebuild_assets.sh`. Fix the asset script.
- `G.flash_replace = True` on every `swfrender.SWF`, or shapes replaced at a used depth jump.
- Export only the frames the game can reach (`frames=`): every unused frame is sheet area.
- `clipexport.py`, `swfrender.py` and the other tools are shared by every port: add options, never change what
  existing options produce (rebuild K-Slash: the repository must stay unchanged).
- FFDec stops on an interactive question when a shape is empty: `prepare_game.sh` passes `-onerror ignore`; if
  you run FFDec by hand, pass it too.
