// Charlotte's Quest with the real GPU (GPU=1): Charlotte flies and shoots for a while (with EXTRA, e.g. the late game
// '&test=cq&inv=1&dif=28&pow=8&uber=900': worms, bees, mines, every shot, the Uber and its particles), while the rooms are
// drawn as they come (the bricks and their filters, the glows of the walls); prints the shader programs compiled after
// the start of the game (warmShaders: none expected), the length of the browser frames and the longest ones with the
// frame of the game.
// DPR=1.5 CSSW=696: a page at 150 % showing the canvas 696 px wide like the site (the rooms and filters at 2 px per
// Flash pixel, the sheets at 1.5).
// usage: GPU=1 node cperf.mjs [seconds]      env: EXTRA, PORT, HPORT, DPR, CSSW
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const secs = +(process.argv[2] || 60)
const b = await launch(+(process.env.PORT || 9690))
if (process.env.DPR)
  await b.send('Emulation.setDeviceMetricsOverride', { width: 900, height: 800, deviceScaleFactor: +process.env.DPR, mobile: false })
if (process.env.CSSW)
  await b.send('Page.addScriptToEvaluateOnNewDocument', { source: `document.addEventListener('DOMContentLoaded', () => {
    const s = document.createElement('style'); s.textContent = 'canvas { width: ${+process.env.CSSW}px !important; height: ${+process.env.CSSW * 5 / 6}px !important }'
    document.head.appendChild(s) })` })
const K = { left: [37, 'ArrowLeft'], up: [38, 'ArrowUp'], right: [39, 'ArrowRight'], down: [40, 'ArrowDown'], space: [32, ' ', 'Space'] }
const send = (type, [code, k, c]) => b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: c || k })
let rs = 7
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
try {
  await b.goto(HOST + '/game.html?game=charlottesquest&cls=GameCharlottesQuest&h=500&seed=123' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && kk.game.player)', 60000)
  await b.eval(`(() => {
    const S = kk.renderer.shader
    window.__progs = []
    const gen = S.generateShader.bind(S)
    S.generateShader = function (shader) { const t = performance.now(); const r = gen(shader); __progs.push({ ms: +(performance.now() - t).toFixed(1), frame: kk.game.frameCount }); return r }
    window.__ft = []
    window.__long = []
    let last = performance.now()
    PIXI.Ticker.system.add(() => { const t = performance.now(); __ft.push(t - last); if (t - last > 34) __long.push([+(t - last).toFixed(0), kk.game.frameCount, kk.game.curRoom ? kk.game.curRoom.distance : -1]); last = t })
  })()`)
  await send('keyDown', K.space)
  const t0 = Date.now()
  const held = new Set()
  while (Date.now() - t0 < secs * 1000) {
    if (await b.eval('!!window.__over')) break
    const s = JSON.parse(await b.eval('JSON.stringify(kk.game.botState())'))
    const want = new Set()
    if (s.px < 220) want.add('right'); else if (s.px > 380) want.add('left')
    if (s.py < 170) want.add('down'); else if (s.py > 290) want.add('up')
    if (rnd(4) === 0) want.add(['left', 'right', 'up', 'down'][rnd(4)])
    for (const k of [...held]) if (!want.has(k)) { await send('keyUp', K[k]); held.delete(k) }
    for (const k of want) if (!held.has(k)) { await send('keyDown', K[k]); held.add(k) }
    await b.sleep(120)
  }
  const r = JSON.parse(await b.eval(`JSON.stringify({ progs: __progs, n: __ft.length, long: __long.slice(0, 40),
    st: kk.game.debugState(), med: (() => { const a = __ft.slice(30).sort((x, y) => x - y); return a.length ? [a[a.length >> 1], a[Math.floor(a.length * 0.95)], a[Math.floor(a.length * 0.99)], a[a.length - 1]].map((v) => +v.toFixed(1)) : [] })() })`))
  console.log('shaders after the start', r.progs.length, JSON.stringify(r.progs))
  console.log('browser frames', r.n, 'median / p95 / p99 / max ms', JSON.stringify(r.med))
  console.log('frames > 34 ms', r.long.length, JSON.stringify(r.long))
  console.log('state', JSON.stringify(r.st))
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
