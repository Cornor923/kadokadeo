# Porting the code

Read `mt-to-haxe` (syntax) and `mt-to-kadokadeo` (API) first, and [original.md](original.md) for the cases where a
literal conversion changes the game. This file is the structure of a port and what the recent ports learned.

## Contents
- Structure of a port
- Scale: the root at x2
- Display: depths, clips, interpolation
- Inputs: keyboard, mouse, touch
- Randomness and determinism
- Timing, score, game over
- Register the game in the repository
- Compile

## Structure of a port

`resources/hx/games/<game>/`, `<game>` = game key of the database name (`App\Models\Game::getGameKeyAttribute`:
lowercase, only `a-z0-9`: `K-Slash !` -> `kslash`, `Opalus 2` -> `opalus2`).

- One `.hx` per original file, same names (`Game`, `Cs`, `Hero`, `Monster`...). `Manager.mt` (the Flash entry
  point) disappears: `Game` is created by KadoKadeo.
- `import.hx`: the package and the common imports (K-Slash):
  ```haxe
  package kslash;
  using Std; using Lambda; using StringTools;
  import kado.KadoKadeoManager; import kado.Seed;
  import common_haxe_avm1.display.ASprite; import common_haxe_avm1.KKApi;
  import mt.Timer; import mt.bumdum.Lib;
  ```
- Helpers that are not the game (a Flash API, an `mt.*` class of the original libs) come from `resources/hx/lib`:
  `common_haxe_avm1` (AS1 / AS2 display: `ASprite`, the base of every sprite, interpolated by KadoKadeoManager),
  `arkadeo` (the AS3 display list of the Arkadeo games over `ASprite`: DisplayObject / Sprite / Shape / Bitmap /
  MovieClip + Clip / TextField, filters, `DepthManager` on `mt.DepthManager`, the AS3 `Rand`; per-game settings in
  `arkadeo.Flash`), `mt.*` (`mt.DepthManager`, `mt.bumdum`, `mt.deepnight` Cooldown / Delayer / Tweenie / Mode /
  Particle, SpriteLib `mt.deepnight.slb`, `mt.fx` effects, `mt.gx` Pool / FTimer, `mt.MLib`...). A class missing there,
  or one that does not compile in Haxe 4 / JS (`Hash`, `flash.*`), is added to or fixed in the lib (on `ASprite` /
  `arkadeo`), not copied into the game, and no second display stack is written next to them.
- `Game.hx` implements `kado.GameInterface` (`update(delta)`, `destroy()`) and is exposed as `Game<Name>`, the name
  the page loads:
  ```haxe
  @:expose('GameKSlash')
  class Game implements kado.GameInterface {
      public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {...};       // see Inputs
      public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

      public function new(root:ASprite, ?isReplay:Bool = false) {
          KadoKadeoManager.kkm.replay.init({recordedKeys: keys, recordInputs: true, recordEvents: false,
              recordMousePosition: false, recordedMouseButtons: new UInt16Array(0)});
          Cs.game = this;
          Hero.SPEED = 5;                         // statics of the original: reset for every game
          this.root = root.createEmptyMovieClip("scene", 0);
          this.root._xscale = this.root._yscale = 100 * Clip.K;      // the original's 300x300 pixels, drawn x2
          dm = new DepthManager(this.root);
          ...                                     // then the original constructor, line by line
          warmShaders();
      }
      public function update(delta:Float) { ... }  // the original main(): one frame of the Flash player
      public function destroy():Void { ... }       // reset the statics, flush pending removals
  }
  ```
- `Data.hx` is **generated** by `<game>_data.py` (timelines, pivots, layouts, numbers measured in the SWF).
- Optional helpers copied from the closest port and adapted: `Clip.hx` (Flash timeline player), `Tex.hx`
  (textures of this game's sheets only), `Digits.hx` (numbers drawn with the SWF font), `PlatGfx.hx`-like classes
  for what the original drew with masks.
- In debug builds, expose the end state for the test bots (compared between a game and its replay):
  ```haxe
  #if debug
  untyped js.Browser.window.__over = {frame: frameCount, score: KadoKadeoManager.kkm.score.get(), hx: hero.x, ...};
  #end
  ```
  Put in it whatever would reveal a divergence (positions, difficulty, counts, stats).

## Scale: the root at x2

The originals are 300x300, KadoKadeo is 600x600. **Keep every coordinate of the original and scale the root
container x2** (`root._xscale = root._yscale = 200`). Positions, speeds, collisions and roundings are then exactly
the original's, and nothing can be forgotten. The textures are exported at 2 px per Flash pixel, so they are drawn
at their native resolution.

The other method of the repository (multiply every value by `KadoKadeoManager.S()` / `I()`, skill `scale`) was
used by older ports (Ellon in the Dark, Kanji's Adventure...): it is error-prone (a missed value is a bug) and
changes the roundings. Do not use it for a new port.

## Display: depths, clips, interpolation

- Same depths as the original (`DP_BG`, `DP_HERO`...), same `DepthManager` structure (K-Slash: `dm` for the
  planes, `mdm` for the map).
- MovieClips animated by timelines (characters, effects) are `Clip` instances played from exported tables
  (`Clip.attach(mdm, "mcHero", DP_HERO)`): `gotoAndPlay`, `gotoAndStop`, named children (`clip.get("blade")`),
  frame scripts handled by the game (`clip.onScript = name -> ...`), `onRemoved`. See [graphics.md](graphics.md).
- PIXI draws between two game steps by interpolating `_prevState` -> `_curState` (`ASprite`). Consequences:
  - a sprite moved somewhere else in one step (teleport, first placement, camera snap) must copy its current state
    into the previous one, otherwise it slides (K-Slash `hero.snapped` in `updateScroll`);
  - a sprite recreated or re-parented loses its previous state: carry the shown position over;
  - a scale that changes its sign must not be interpolated (`Clip.noFlipLerp`).
- Gameplay never reads the display back (`_x` of an interpolated sprite is fine, PIXI bounds and pixels are not).
- First use of a filter or mask compiles a shader (10-80 ms freeze): warm them in the constructor
  (`Game.warmShaders` of K-Slash renders a `ColorMatrixFilter` once into a small RenderTexture).
- Numbers are drawn with the digits of the SWF's embedded font (`Digits.hx`), never with `PIXI.Text`.

## Inputs: keyboard, mouse, touch

- Read inputs **by polling in `update`** (`KeyboardManager.isDown`, `MouseManager.getX()`...), never with
  events: the replay records the polled state and replays it at the same frame. `recordedKeys` lists every key
  the game reads (K-Slash: LEFT, RIGHT, UP, DOWN, SPACE, CONTROL).
- `KEY_ALIASES`: `ALIASES_MOVE` (ZQSD / WASD by physical key = arrows), `ALIASES_ENTER_SPACE` (Enter = Space),
  `ALIASES_CONTROL_SPACE`. Aliases are applied before recording: nothing to add to `recordedKeys`.
- Something the original read from key events that is not a recorded key (K-Slash's secret code N-I-G-H-T):
  detect it live with `KeyboardManager.getFrameKeyChanges()` (only when `!isReplay`), record a replay event
  (`replay.recordEvent({k: EV_NIGHT})`, `recordEvents: true`) and apply it at the start of the next `update`: in a
  replay when `replay.consumeEvents()` returns it, in the live game through a flag set with the recording (a live
  game does not get its own events back from `consumeEvents()`: K-Slash `nightTyped`) (`replay-system`).
- Mouse games: call `canvas.setPointerCapture` on `pointerdown` (KadoKadeo releases the buttons on `pointerleave`;
  Flash kept the mouse while the button was held), read `MouseManager.getX()` clamped to `>= 0` like the replay
  recorder, `recordMousePosition: true`.
- Touch: `TOUCH_CONTROLS` (`kado.TouchControlsConfig`): `mode: KEYBOARD` with buttons that press keys, or
  `mode: JOYSTICK` (floating with `dynamicCenter: true`, 4 or 8 `directions`) plus buttons. A joystick is turned
  into key presses in `pollTouchControls()` (called by KadoKadeo before each step, recorded like the keyboard):
  ```haxe
  public function pollTouchControls():Void {
      var j = KadoKadeoManager.kkm.getTouchJoystickState();
      if (j == null) return;
      var ax = j.active ? j.dirX : 0;
      setDirectionalKey(KeyboardManager.LEFT, ax < 0);    // KeyboardManager.setKeyDown / setKeyUp
      setDirectionalKey(KeyboardManager.RIGHT, ax > 0);
      ...
  }
  ```
  For a mouse game, a finger held on the screen is the mouse (Mini-Race). Flash buttons played with a finger
  (Puzzle-Manda): a finger does not hover and its press / release of a drag would click: the first `pointerdown` of
  type `touch` records a replay event that turns on a touch mode (no rollOver, a release clicks only after a tap),
  the desktop behaviour stays the original's (`puzzlemanda/Buttons.hx`, `ptouch.mjs`).

## Randomness and determinism

- Gameplay random -> `Seed.random(n)` / `Seed.rand()`; random that only changes pictures (particles, sparkles,
  a random night in K-Slash) -> `Seed.randomVfx(n)` / `Seed.randVfx()`. An original that keeps `mt.Rand` objects drawing
  from the seed of the game: `Seed.random` / `range` / `irange` / `sign` (gameplay) and `Seed.randomVfx` / `rangeVfx`
  / `irangeVfx` / `signVfx` (pictures), the formulas of `mt.Rand`. A visual effect must never draw from the
  gameplay random, or seeking and display settings change the game.
- Trigonometry and powers whose result affects the game: round them (`Math.cos/sin/atan2/pow/sqrt` can differ in
  the last bits between browsers). K-Slash rounds to 1/65536, an exact binary fraction:
  ```haxe
  public static inline function q(v:Float):Float return Math.round(v * 65536) / 65536;
  s.vx = Cs.q(Math.cos(a + da) * speed);
  ```
  (Manda used `Math.round(v * 1e9) / 1e9`; `fix-replays-float` uses `Num.q`. Any fixed rounding works; round at
  the point where the value enters the game state.)
- Nothing may depend on the time, `Date`, the window size, the rendering, or the order of a `Map` iteration.
- Reset every static of the original in `Game.new` (and `destroy`): one page plays several games and replays.

## Timing, score, game over

- KadoKadeo calls `update` 32 times per second with `mt.Timer.tmod = 1`: games written for `Timer.wantedFPS = 32`
  keep their speeds. Keep every `* Timer.tmod` of the original.
- `update` must do what one frame of the Flash player did, in the same order. Each step KadoKadeo calls
  `pollTouchControls()`, `replay.beginFrame()`, `gameRoot.update()` (every `ASprite` / `Clip` advances its
  timeline: playheads move before the game code, like Flash), then `game.update(dt)`, then `replay.endFrame()`.
- Score: `KadoKadeoManager.kkm.addScore(n)`, and nothing more after the game over (K-Slash `Game.addScore`
  checks `over`). Game over: `KadoKadeoManager.kkm.gameOver(stats)` once.

## Register the game in the repository

- `compile.hxml`: a block for the game (`-js ./resources/js/games/<game>.js` + `<game>.Game`, between `--next`).
  `compile-dev.hxml`: the game being worked on (it compiles one game). Add or remove a game in both.
- `database/seeders/GameSeeder.php`: the game's line with `'is_active' => true`.
- Sheets in `public/assets/img/content/<game>/`: KadoKadeo loads `<game>-0.json` before creating the game
  (`KadoKadeoManager.startGame`); other sheets are listed in its `related_multi_packs`.
- Start screen `public/assets/img/gfx/artwork/<game>.jpg`, 600x600, required (an empty start screen otherwise):
  composed from SWF renders, after the old thumbnail `artwork/old/<game>.gif` when there is one.
- Never edit `resources/js/games/*.js` or `public/gamesdata/*`: `make compile-games` (Docker) regenerates them.
- An **Arkadeo** game (600 x 460): `'is_arkadeo' => true` in `GameSeeder.php`. The site gives it a canvas of 600 x 500 (the game
  area + the score bar, `KadoKadeoManager.gameAreaHeight()` = 460), its start screen is 600 x 460, test it in the harness with
  `&h=500` (Mel, Brutal Teenage Crisis).

## Compile

- While porting: `sh .opencode/skills/flash-port/scripts/harness/build.sh <game>` (debug, seconds) then reload the
  harness page. `build.sh <game> prod` before committing: the production build (no `-debug`) sometimes rejects
  what debug accepts, and `#if debug` test code must not break it.
- In Docker: `make compile-games` (all games + bundles), or one game:
  ```sh
  docker exec -u dev -w /www kadokadeo_app haxe -L pixijs -L crypto -L jsImport -cp ./resources/hx/lib \
      -cp ./resources/hx/games -debug -js /tmp/<game>.js <game>.Game
  ```
