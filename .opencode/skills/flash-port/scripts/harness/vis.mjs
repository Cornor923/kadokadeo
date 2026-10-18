// Display fingerprint of a replay at chosen frames, to compare two builds (a refactor of the display code): the replay is
// paused, sought to each frame, then every visible leaf of the PIXI tree under the game root is listed in draw order
// (picture, world corners, world alpha, tint, blend, filters and mask of its parents, text) into tree_<frame>.json, with a
// screenshot shot_<frame>.png of the game area.
//   node vis.mjs <pkg> <cls> <replay file> <out dir> <frames, e.g. 100,500,900> [bundle name]
//   node vis.mjs cmp <dir a> <dir b>     the leaves that differ per frame (count, first ones)
//   env: EXTRA (url params of the test mode of the replay), PORT, H (canvas height, default 500)
// A build that smooths at render time (Brutal Teenage Crisis before the arkadeo lib: game.smooth) is drawn at its last
// sample, like a build interpolated by ASprite after a seek.
import { launch } from './cdp.mjs'
import { HOST } from './paths.mjs'
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from 'node:fs'

if (process.argv[2] === 'cmp') {
  const [da, db] = process.argv.slice(3)
  for (const f of readdirSync(da).filter((f) => f.startsWith('tree_')).sort((x, y) => parseInt(x.slice(5)) - parseInt(y.slice(5)))) {
    if (!existsSync(db + '/' + f)) { console.log(f, 'missing in', db); continue }
    const a = JSON.parse(readFileSync(da + '/' + f, 'utf8')), b = JSON.parse(readFileSync(db + '/' + f, 'utf8'))
    const n = Math.max(a.length, b.length)
    const diffs = []
    for (let i = 0; i < n; i++) if (JSON.stringify(a[i]) !== JSON.stringify(b[i])) diffs.push(i)
    console.log(f, a.length + ' / ' + b.length + ' leaves', diffs.length ? diffs.length + ' differ' : 'SAME')
    for (const i of diffs.slice(0, +(process.env.SHOW || 4))) console.log('  ' + i + '\n  < ' + JSON.stringify(a[i]) + '\n  > ' + JSON.stringify(b[i]))
  }
  process.exit(0)
}

const [pkg, cls, file, out, frames, js] = process.argv.slice(2)
const PORT = +(process.env.PORT || 10311)
const data = readFileSync(file, 'utf8').split('\n')[0].trim()
mkdirSync(out, { recursive: true })
const TREE = `(() => {
  const g = kk.game
  if (g.smooth) { g.smooth.tracks.forEach((t) => { t.s0x = t.s1x; t.s0y = t.s1y }); g.smooth.beforeRender(1) }
  const tp = kk.stage.enableTempParent(); kk.stage.updateTransform(); kk.stage.disableTempParent(tp)
  const r2 = (v) => Math.round(v * 100) / 100
  const out = []
  const walk = (o, fx) => {
    if (!o.visible || !o.renderable || o.worldAlpha <= 0) return
    if (o.filters && o.filters.length) fx = fx.concat(o.filters.map((f) => f.constructor.name + ':' + JSON.stringify(Object.fromEntries(
      Object.entries(f.uniforms || {}).filter(([k, v]) => typeof v === 'number' || (v && v.length < 8)).map(([k, v]) => [k, typeof v === 'number' ? r2(v) : Array.from(v).map(r2)])))))
    if (o.mask) fx = fx.concat(['mask'])
    const e = { a: r2(o.worldAlpha), fx: fx.length ? fx : undefined }
    if (o.text != null) { e.t = o.text; const bb = o.getBounds(); e.b = [bb.x, bb.y, bb.width, bb.height].map(r2) }
    else if (o.geometry && o.geometry.graphicsData) { if (o.geometry.graphicsData.length) { const bb = o.getBounds(); e.g = [bb.x, bb.y, bb.width, bb.height].map(r2); e.bl = o.blendMode } }
    else if (o.texture && o.texture !== PIXI.Texture.EMPTY && o.texture.valid) {
      o.calculateVertices()
      e.p = (o.texture.textureCacheIds && o.texture.textureCacheIds[0]) || (o.texture.baseTexture.resource && o.texture.baseTexture.resource.url) || 'rt:' + o.texture.width + 'x' + o.texture.height
      e.v = Array.from(o.vertexData).map(r2); e.tint = o.tint; e.bl = o.blendMode
    }
    if (e.t != null || e.g || e.p) out.push(e)
    for (const c of o.children || []) walk(c, fx)
  }
  walk(kk.gameRoot, [])
  if (g.smooth) g.smooth.afterRender()
  return JSON.stringify(out)
})()`
const b = await launch(PORT)
try {
  await b.goto(HOST + `/game.html?game=${pkg}&cls=${cls}&seed=123&h=${process.env.H || 500}` + (js ? '&js=' + js : '') +
    (process.env.EXTRA || '') + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game)', 60000)
  await b.eval('kk.setReplayPaused(true)')
  for (const f of frames.split(',').map(Number)) {
    await b.eval(`kk.seekReplay(${f})`)
    await b.waitFor('kk.seekTarget == null', 300000)
    await b.sleep(300)
    writeFileSync(`${out}/tree_${f}.json`, await b.eval(TREE))
    // (the samples of a smoothing build were made equal by TREE: its renders show the last one)
    await b.sleep(200)
    await b.screenshot(`${out}/shot_${f}.png`, { x: 8, y: 8, width: 600, height: 460 })
    console.log('frame', f, 'at', await b.eval('kk.replay.getCurrentFrame()'))
  }
} finally {
  const errs = b.consoleLines.filter((l) => /EXCEPTION|rror|CRASH/i.test(l))
  if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
