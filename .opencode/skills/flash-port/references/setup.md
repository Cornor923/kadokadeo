# Setup

Done once per machine. Everything runs on the host (macOS, Linux or Windows with Git Bash); Docker is only needed
for the final `make compile-games`.

## Contents
- Prerequisites
- The original sources
- Work folder and environment variables
- Check the setup
- Scripts map

## Prerequisites

| Tool | Why | Check |
|---|---|---|
| Haxe 4.3.7 + libs `pixijs`, `crypto`, `jsImport` | compile a game outside Docker (`harness/build.sh`) | `haxe -version`, `haxelib list` |
| Python 3.10+ with `pillow numpy scipy fonttools` | SWF rendering, sheet packing | `python3 -c "import PIL, numpy, scipy, fontTools"` |
| JPEXS FFDec (26.x) + Java 8+ | rasterizes the SWF shapes, exports bitmaps, fonts, scripts | `java -version` |
| `rsvg-convert` (librsvg) | shape layers of the clips exported with `stack=True` (code-driven alpha) | `rsvg-convert --version` |
| Node.js 22+ | test scripts (they use the global `WebSocket` of Node 22) | `node --version` |
| Chrome, Edge or Chromium | headless browser driven by the tests | |
| `npx` (comes with Node) | runs esbuild when the repository's `node_modules` was installed inside Docker | |

Install notes:
- Haxe libs: from the repository root, `haxelib install resources/hx/install.hxml` (pins `pixijs` to the
  KadoKadeo fork and `jsImport` to git).
- Python: a virtual environment is fine:
  `python3 -m venv ~/kadokadeo-port/venv && ~/kadokadeo-port/venv/bin/pip install pillow numpy scipy fonttools`,
  then put `~/kadokadeo-port/venv/bin` first in `PATH` while porting.
- FFDec: macOS app `/Applications/FFDec.app` is found automatically by `prepare_game.sh`; elsewhere set
  `FFDEC` to the command (`FFDEC="java -jar /path/ffdec.jar"`, or `ffdec-cli.exe` on Windows).
- Node 20/21 also work with `node --experimental-websocket`. With nvm: `nvm use 22`.
- Browser: found automatically (Chrome on macOS, Edge on Windows, `google-chrome` / `chromium` on Linux); else
  set `BROWSER=<path of the executable>`.

## The original sources

```sh
git clone --filter=blob:none --sparse https://github.com/motion-twin/WebGamesArchives.git
git -C WebGamesArchives sparse-checkout add "KadoKado/Games/<Name>"     # one game at a time (the full archive is large)
git -C WebGamesArchives ls-tree -d --name-only HEAD KadoKado/Games/     # list of the games
```

## Work folder and environment variables

A port produces large intermediate files (FFDec exports, rendered frames, screenshots, replays) that do not belong
in the repository. They live in `$KKP_WORK/<game>/`, `~/kadokadeo-port/<game>/` by default.

| Variable | Default | Used by |
|---|---|---|
| `KKP_WORK` | `~/kadokadeo-port` | every script: work folders, `build/` (compiled games), `vendor/` (PixiJS cache) |
| `FFDEC` | macOS app / `ffdec-cli.exe` / `ffdec` | `prepare_game.sh` |
| `HAXE` | `haxe` | `build.sh` |
| `BROWSER` | detected | `cdp.mjs` |
| `HPORT` | `8765` | test scripts: port of `server.py` |
| `PORT` | per script (9xxx) | test scripts: DevTools port of the browser they launch |
| `GPU=1` | off (software renderer) | `cdp.mjs`: real GPU, for performance tests |

Several sessions can work at the same time (one per game, in separate git worktrees): give each its own
`HPORT` (server port) and `PORT` values, and never switch branches in a worktree another session uses.

## Check the setup

From the repository root (`SK=.opencode/skills/flash-port/scripts`), with K-Slash, the reference port:

```sh
SK=.opencode/skills/flash-port/scripts
# 1. FFDec exports of the original (a few seconds)
sh $SK/tools/prepare_game.sh <WebGamesArchives>/KadoKado/Games/kslash kslash gfx decor
# 2. graphics rebuilt from them: must leave the repository unchanged (same Data.hx, same sheet)
sh $SK/examples/kslash/rebuild_assets.sh && git status --short public resources
# 3. game compiled and bundled for the harness
sh $SK/harness/build.sh kslash                                  # BUILD_OK
python3 $SK/harness/server.py &                                 # http://127.0.0.1:8765, stop it at the end
# 4. a random game, seeks in its replay, end of the replay
node $SK/harness/s3.mjs kslash GameKSlash 9333 600
#    {"game":"kslash",...,"again60":"SAME","playedVsSeek":"SAME","end":"..","endMatch":"MATCH"}
# 5. a bot plays a real game, then its replay
node $SK/examples/kslash/k3.mjs 1                               # ... replay {...} MATCH
```
Then open `http://127.0.0.1:8765/game.html?game=kslash&cls=GameKSlash&seed=123` to play it. Step 2 may rewrite
a few `src/*.png` with identical pixels (PNG compression of another Pillow version): `git checkout` them.

## Scripts map

`scripts/tools/` (Python, run with the venv):

| Script | Role |
|---|---|
| `prepare_game.sh` | copies a game's SWF files into `$KKP_WORK/<game>/` and runs every FFDec export + `swfdump.py` |
| `swfdump.py` | minimal SWF parser: header (frame rate), exported symbols, timelines, matrices, colour transforms |
| `swfrender.py` | Flash display-list compositor: nested timelines, stop / play / goto, named children forced to a frame, colour transforms, filters and blend modes; shapes rasterized by FFDec, composed supersampled then reduced |
| `swffilters.py`, `swftext.py` | SWF 8 filters / blend modes (PlaceObject3), text fields (DefineEditText) |
| `swffont.py` | embedded fonts (DefineFont2 / 3) and static texts without FFDec: glyphs rasterized with Pillow (Rock Faller's score) |
| `clipexport.py` | Flash MovieClip -> timeline tables + minimal textures, played at runtime by the game's `Clip.hx` |
| `pack_multi.py` | sprite sheets in TexturePacker "pixijs4" JSON (trim, extrude, identical frames aliased, multipack); run with `PACK_MAX=2040` |
| `make_tps.py` + `tpl.tps` | TexturePacker project with the pivots, so the sheet can be rebuilt in TexturePacker |
| `cmp_pages.py` | game pages vs SWF pages: side by side + difference |
| `replaystat.py` | decodes a replay string (versions 1 to 3), size of each section |
| `contact.py`, `area_report.py` | contact sheet of FFDec sprite exports; texture area per animation (what makes the sheet big) |

`scripts/harness/` (Node 22):

| Script | Role |
|---|---|
| `build.sh <game> [prod]` | compiles the game like `compile-dev.hxml` and bundles it like `build-games.mjs`, into `$KKP_WORK/build/` |
| `server.py [port]` | serves `www/game.html`, the builds, `modes/`, the repository's `public/`, and PixiJS (cached) |
| `www/game.html` | test page: `?game=<pkg>&cls=Game<Name>&seed=123[&replay=...][&test=<mode>]` |
| `modes/<game>.js` | test modes of a game (coverage: bonuses given, immortal hero...), loaded by `game.html` |
| `cdp.mjs` | minimal DevTools-protocol driver of a headless browser: `launch`, `goto`, `eval`, `waitFor`, keys, mouse, `screenshot` |
| `paths.mjs` | `HOST` (harness URL) and `gameDir(game, ...)` (work folder) for test scripts |
| `s3.mjs` | any game: random inputs, then seeks in the replay and end of the replay |
| `step.mjs` | frame-by-frame screenshots (physics stepped by hand) |
| `stutter.mjs`, `hitch.mjs`, `hitchprof.mjs`, `shaders.mjs` | smoothness, long frames, CPU profile of long frames, shaders and textures created during the game |
| `rmouse.mjs` | any mouse game: hand-like mouse moves, then the replay |
| `rc.mjs` | replays recorded with one build played by another (shared-code changes) |
