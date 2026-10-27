// Plays the replay of a run in a headless Chrome, as fast as possible, and gives the score it ends with: the score
// sent by the game can then be checked (App\Services\ReplayVerifier, App\Jobs\VerifyRunReplay).
//   usage: node verify.mjs <input.json>
//   input: { bundle: path of the game bundle (the version the run was played with), gameClass: "Game<Name>",
//            gameName: game_key, seed, replay, assetBase?: assets of an archived version,
//            module?: the bundle is an ES module (resources/js/games/builds/bundle.mjs), not a classic script,
//            analysis?: config of the analyzer of the game (analyzers/<gameName>.mjs, see analyzers/README.md), null: none,
//            gameOverAtFrame?: tests only, the replays of the test harness (rc.mjs) end with a game over forced there }
//   output (stdout, one JSON line): { ok: true, score, frames, analysis? } or { ok: false, error }
//            analysis: { analyzer, version, metrics, suspicious, reasons } or { analyzer, error } (never fails the run)
//   env: BROWSER (Chrome / Chromium, see browser.mjs), KADO_VERIFIER_CACHE (cache of the downloaded browser,
//        default storage/app/replay-verifier), KADO_VERIFIER_TIMEOUT (seconds: then it fails, its browser killed)
// The game runs like on the site (the same files of PIXI, pixi-tween, fonts), the physics is stepped by hand.
// Needs Node 22+ and Chrome / Chromium (downloaded when there is none: package @puppeteer/browsers).
import { existsSync } from 'node:fs'
import { readdir, readFile } from 'node:fs/promises'
import { createServer } from 'node:http'
import { basename, dirname, extname, join, normalize, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

import { findBrowser } from './browser.mjs'
import { deadline, launch, output } from './cdp.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')
const PUBLIC = join(ROOT, 'public')
const PIXI_TWEEN = join(ROOT, 'resources/js/pixi-tween')
// one analyzer of the moves by game (optional): analyzers/<game_key>.mjs
const ANALYZERS = join(dirname(fileURLToPath(import.meta.url)), 'analyzers')
const CACHE = process.env.KADO_VERIFIER_CACHE || join(ROOT, 'storage/app/replay-verifier')
// the files of the site (resources/views/layouts/default.blade.php)
const VENDOR = {
  'pixi.js': join(PUBLIC, 'vendor/pixi.js/6.0.2/pixi.min.js'),
  'pixi-filters.min.js': join(PUBLIC, 'vendor/pixi-filters/5.0.0/pixi-filters.min.js'),
}
const STEP_MS = 1000 / 32
// the game goes on after the last frame of the replay: end animation, then the fade of kado.GameOver (80 frames),
// during which points can still be won (the score sent is the one at the end of the fade)
const EXTRA_FRAMES = 32 * 60
const TYPES = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff': 'font/woff', '.woff2': 'font/woff2', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.fnt': 'text/xml', '.xml': 'text/xml' }

async function page(input) {
  // the fonts of the site: some games measure their texts
  const css = await readFile(join(ROOT, 'resources/css/app.css'), 'utf8')
  const fontFaces = (css.match(/@font-face\s*{[^}]*}/g) || []).join('\n')
  const params = {
    replayData: input.replay,
    seed: input.seed,
    name: input.gameName,
    gameId: 0,
    isDaily: false,
    contractScore: 0,
    contractPoints: 0,
    // nothing is seen: the game skips its effects drawn at each frame (kado.KadoKadeoManager.headless)
    headless: true,
    // the size of the canvas of the site (resources/js/components/games/GameScript.vue)
    canvasWidth: 600,
    canvasHeight: input.arkadeo ? 500 : 640,
    ...(input.assetBase ? { assetBase: input.assetBase } : {}),
  }
  const json = (v) => JSON.stringify(v).replace(/</g, '\\u003c')
  // the classes of the game: the default export of an ES module (imported after pixi-tween, part of the bundle of the
  // site), or put on window by a classic script (the versions built before the ES modules)
  const legacyLoader = `<script src="/__bundle.js"></script>
<!-- pixi-tween (part of the bundle of the site) as ES modules: they run in order, after the classic scripts -->
<script type="module" src="/__pixi-tween/index.js"></script>`
  const moduleLoader = `await import('/__pixi-tween/index.js')
  window.__classes = (await import('/__bundle.js')).default()`
  return `<!doctype html>
<html><head><meta charset="utf-8"><style>${fontFaces} body { margin: 0 }</style>
<script>
  window.Kado = { public_key: '' }
  window.evts = new EventTarget()
  window.__crash = null
  evts.addEventListener('gameCrash', (e) => { window.__crash = e.detail })
</script>
<script src="/__vendor/pixi.js"></script>
<script src="/__vendor/pixi-filters.min.js"></script>
</head><body>
<canvas id="c" width="600" height="640"></canvas>
${input.module ? '' : legacyLoader}
<script type="module">
  ${input.module ? moduleLoader : ''}
  const classes = window.__classes || window
  const gameOverAtFrame = ${json(input.gameOverAtFrame ?? null)}
  if (gameOverAtFrame) {
    const proto = classes[${json(input.gameClass)}].prototype, update = proto.update
    proto.update = function (dt) {
      update.call(this, dt)
      this.__frames = (this.__frames || 0) + 1
      if (this.__frames === gameOverAtFrame) window.kk.gameOver({})
    }
  }
  window.kk = new classes.KadoKadeo(document.getElementById('c'), classes[${json(input.gameClass)}], ${json(params)})
</script>
</body></html>`
}

async function serve(input) {
  const files = {
    '/': [await page(input), 'text/html'],
    '/__bundle.js': [await readFile(input.bundle), 'text/javascript'],
  }
  // its imports have no extension
  for (const name of await readdir(PIXI_TWEEN)) {
    files['/__pixi-tween/' + name] = files['/__pixi-tween/' + basename(name, '.js')] = [await readFile(join(PIXI_TWEEN, name)), 'text/javascript']
  }
  for (const name of Object.keys(VENDOR)) files['/__vendor/' + name] = [await readFile(VENDOR[name]), 'text/javascript']

  const server = createServer(async(req, res) => {
    const path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname)
    if (files[path]) {
      res.writeHead(200, { 'Content-Type': files[path][1] })
      return res.end(files[path][0])
    }
    // the analyzers (and their modules), then the assets of the games (public/)
    const analyzer = path.startsWith('/__analyzers/')
    const root = analyzer ? ANALYZERS : PUBLIC
    const file = normalize(join(root, analyzer ? path.slice('/__analyzers/'.length) : path))
    if (!file.startsWith(root + sep)) {
      res.writeHead(403)
      return res.end()
    }
    try {
      const data = await readFile(file)
      res.writeHead(200, { 'Content-Type': TYPES[extname(file).toLowerCase()] || 'application/octet-stream' })
      res.end(data)
    } catch {
      res.writeHead(404)
      res.end()
    }
  })
  await new Promise((r) => server.listen(0, '127.0.0.1', r))
  return server
}

function analyzerOf(input) {
  if (!input.analysis || !/^[a-z0-9]+$/.test(input.gameName ?? '')) return null
  return existsSync(join(ANALYZERS, `${input.gameName}.mjs`)) ? input.gameName : null
}

async function verify(input) {
  // the first verification downloads the browser when there is none (stderr: the output is the last line of stdout)
  const { path } = await findBrowser({ cacheDir: join(CACHE, 'browser'), install: true, log: (m) => console.error(m) })
  const server = await serve(input)
  const b = await launch(path)
  try {
    await b.goto(`http://127.0.0.1:${server.address().port}/`)
    await b.waitFor('!!window.__crash || !!(window.kk && kk.ff)', 120000)
    // the physics is only stepped by hand once the replay plays (own properties: the prototypes of the game may be
    // frozen). The live loop is stopped in its step that would play the first frame of the replay (kado.FixedFramerate
    // calls its `update` once per step), so the analyzer sees every frame; an older build without it: stopped when
    // the replay is seen playing, a few frames later
    const analyzer = analyzerOf(input)
    await b.eval(`(() => {
      // the picture of the page is not drawn (slow in the software WebGL of the browser): the transforms of the display
      // objects are still updated, as the render would do. The renders of the game in its own textures stay
      const renderer = kk.renderer, render = renderer.render
      renderer.render = function (object) {
        if (object === kk.stage && arguments.length === 1) {
          const parent = object.enableTempParent()
          object.updateTransform()
          object.disableTempParent(parent)
          return
        }
        return render.apply(this, arguments)
      }
      const ff = kk.ff, update = ff.update
      // the analyzer of the game: reads the game before each frame (read only), its errors only end the analysis
      window.__createAnalyzer = () => {
        const m = window.__analyzerModule
        if (!m || window.__analyzer || window.__analyzerError) return
        try {
          window.__analyzerMeta = m.meta
          window.__analyzer = m.create({ kk, config: ${JSON.stringify(input.analysis)} })
        } catch (e) { window.__analyzerError = String((e && e.message) || e) }
      }
      window.__start = () => {
        if (!window.__started) {
          window.__started = true
          Object.defineProperty(ff, 'onTick', { value: function () {}, configurable: true, writable: true })
        }
        window.__createAnalyzer()
      }
      if (typeof update !== 'function') return
      try {
        Object.defineProperty(ff, 'update', { configurable: true, writable: true, value: function (dt) {
          if (!window.__started && kk.game && kk.replay.isPlayingReplay()) {
            window.__start()
            // ends the loop of this tick (FixedFramerate.onTick: while accumulator >= STEP)
            ff.accumulator = 0
            return
          }
          return update.call(this, dt)
        } })
      } catch { /* not extensible: stopped later */ }
    })()`)
    if (analyzer) {
      await b.eval(`import('/__analyzers/${analyzer}.mjs').then((m) => { window.__analyzerModule = m },
        (e) => { window.__analyzerError = String((e && e.message) || e) })`)
    }
    await b.waitFor('!!window.__crash || !!window.__started || !!(kk.game && kk.replay.isPlayingReplay())', 120000)
    // a build without FixedFramerate.update, or the replay began before the analyzer was loaded
    await b.eval('window.__start()')
    const maxFrames = (await b.eval('kk.getReplayLength()')) + EXTRA_FRAMES
    let state
    do {
      state = await b.eval(`(() => {
        // the end of the fade shows the end screen (the live game sends its score at that moment)
        for (let i = 0; i < 500; i++) {
          if (window.__crash || kk.endScene != null) break
          if (window.__analyzer) {
            try { window.__analyzer.beforeFrame(kk.replay.getCurrentFrame()) } catch (e) {
              window.__analyzerError = String((e && e.message) || e)
              window.__analyzer = null
            }
          }
          kk.updatePhysics(${STEP_MS})
        }
        return { over: kk.endScene != null, frame: kk.replay.getCurrentFrame(), crash: window.__crash ? JSON.stringify(window.__crash) : null }
      })()`)
      if (state.crash) throw new Error('the game crashed: ' + state.crash.slice(0, 300))
      if (!state.over && state.frame > maxFrames) throw new Error(`the replay did not end (${state.frame} frames)`)
    } while (!state.over)
    const score = await b.eval('kk.score.get()')
    const result = { ok: true, score, frames: state.frame }
    if (analyzer) {
      result.analysis = await b.eval(`(() => {
        const head = { analyzer: ${JSON.stringify(analyzer)}, version: window.__analyzerMeta ? window.__analyzerMeta.version : null }
        if (window.__analyzerError || !window.__analyzer) return { ...head, error: (window.__analyzerError || 'no analyzer').slice(0, 300) }
        try { return { ...head, ...window.__analyzer.finish({ score: ${score}, frames: ${state.frame} }) } } catch (e) {
          return { ...head, error: String((e && e.message) || e).slice(0, 300) }
        }
      })()`)
    }
    return result
  } catch(e) {
    // the errors of the page say why
    const errors = b.consoleLines.filter((l) => /EXCEPTION/.test(l)).slice(0, 2)
    throw new Error([e.message, ...errors].join(' | '))
  } finally {
    await b.close()
    server.close()
  }
}

deadline((seconds) => ({ ok: false, error: `the verification took more than ${seconds} s` }))
try {
  const input = JSON.parse(await readFile(process.argv[2], 'utf8'))
  output(await verify(input))
} catch(e) {
  output({ ok: false, error: String(e?.message || e).slice(0, 1000) })
}
