// NosuShi with the real GPU (GPU=1): a bot game (clicks on the biggest group, with the bonuses of EXTRA), the shader
// programs compiled after the start of the game (warmShaders: none expected) and the length of the browser frames.
// usage: GPU=1 node nperf.mjs [clicks]      env: EXTRA (e.g. '&test=ns&bonus=3'), PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const clicks = +(process.argv[2] || 12)
const b = await launch(+(process.env.PORT || 9877))
const N = 9
const CELL = (x, y) => [(x - y) * 24 + 223, (x + y) * 24 + 28]
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1, pointerType: 'mouse' })
function biggest(cells) {
  const id = (x, y) => (x < 0 || y < 0 || x >= N || y >= N ? -2 : (cells[x * N + y] < 0 ? -1 : Math.floor(cells[x * N + y] / 10)))
  const seen = new Set(); let best = null
  for (let x = 0; x < N; x++) for (let y = 0; y < N; y++) {
    if (seen.has(x * N + y) || id(x, y) < 0) continue
    const g = [], todo = [[x, y]]; seen.add(x * N + y)
    while (todo.length) { const [cx, cy] = todo.pop(); g.push([cx, cy]); for (const [dx, dy] of [[1, 0], [0, 1], [-1, 0], [0, -1]]) { const nx = cx + dx, ny = cy + dy; if (id(nx, ny) !== id(x, y) || seen.has(nx * N + ny)) continue; seen.add(nx * N + ny); todo.push([nx, ny]) } }
    if (!best || g.length > best.length) best = g
  }
  return best
}
try {
  await b.goto(HOST + '/game.html?game=nosushi&cls=GameNosushi&h=500&seed=123' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && window.__nosushi)', 60000)
  await b.eval(`(() => {
    const S = kk.renderer.shader
    window.__progs = []
    const gen = S.generateShader.bind(S)
    S.generateShader = function (shader) { const t = performance.now(); const r = gen(shader); __progs.push({ ms: +(performance.now() - t).toFixed(1), frame: kk.replay.getCurrentFrame(), name: shader.program.name || '' }); return r }
    window.__ft = []
    let last = performance.now()
    PIXI.Ticker.system.add(() => { const t = performance.now(); __ft.push(t - last); last = t })
  })()`)
  for (let i = 0; i < clicks; i++) {
    let s
    while (true) { s = await b.eval('window.__over ? null : window.__nosushi'); if (!s || s.step === 'S_Play') break; await b.sleep(50) }
    if (!s) break
    const g = biggest(s.cells)
    const [x, y] = CELL(...g[0])
    await mouse('mouseMoved', x, y); await b.sleep(200)
    await mouse('mousePressed', x, y, 1); await b.sleep(40); await mouse('mouseReleased', x, y)
    await b.sleep(300)
  }
  const r = JSON.parse(await b.eval(`JSON.stringify({ progs: __progs, n: __ft.length, ft: __ft.slice(5).sort((a, c) => a - c) })`))
  const ft = r.ft
  const q = (p) => ft[Math.min(ft.length - 1, Math.floor(ft.length * p))].toFixed(1)
  console.log('shaders after start', r.progs.length, JSON.stringify(r.progs).slice(0, 400))
  console.log('frames', ft.length, 'median', q(0.5), 'p95', q(0.95), 'p99', q(0.99), 'max', ft[ft.length - 1].toFixed(1), 'over 34 ms', ft.filter((v) => v > 34).length)
  console.log(b.consoleLines.filter((l) => /EXCEPTION|rror/.test(l)).slice(0, 5).join('\n'))
} finally { await b.close() }
