// Trigo with the real GPU (GPU=1): a bot makes triangles, combos around them and takes them (the flips with their drop
// shadows, the fades of the blocks, the particles, the texts, the clock, the paper drawn by the overlay filter), then
// lets a combo run out (the blocks destroyed); prints the shader programs compiled after the start of the game
// (warmShaders: none expected) and the length of the browser frames.
// usage: GPU=1 node tperf.mjs [rounds]      env: BIG=1 (the biggest triangles: the most blocks made again), EXTRA, PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const rounds = +(process.argv[2] || 4)
const b = await launch(+(process.env.PORT || 9878))
const CELL = (x, y) => [26 * x + 25, 26 * y + 25]
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1, pointerType: 'mouse' })
const click = async ([cx, cy]) => {
  const [x, y] = CELL(cx, cy)
  await mouse('mouseMoved', x, y); await b.sleep(120)
  await mouse('mousePressed', x, y, 1); await b.sleep(40); await mouse('mouseReleased', x, y); await b.sleep(120)
}
// the smallest triangle (at least 6 blocks) around the blocks taken, searched here (a search in the page would make its
// frames long): the rule of the game (Group.computeMask), the same as window.__trigoMask of the debug build
const cr = (o, a, q) => (a[0] - o[0]) * (q[1] - o[1]) - (a[1] - o[1]) * (q[0] - o[0])
const near = (a, c, q) => {
  const ex = c[0] - a[0], ey = c[1] - a[1], px = q[0] - a[0], py = q[1] - a[1], l2 = ex * ex + ey * ey, t = px * ex + py * ey
  if (t <= 0) return 2 * (px * px + py * py) <= 1
  if (t >= l2) return 2 * ((q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2) <= 1
  const k = ex * py - ey * px
  return 2 * k * k <= l2
}
const maskOf = (A, B, C) => {
  const S = cr(A, B, C), m = []
  for (let x = 0; x < 15; x++) for (let y = 0; y < 15; y++) {
    const q = [x, y]
    let ins = false
    if (S !== 0) { const e = [cr(A, B, q), cr(B, C, q), cr(C, A, q)]; ins = S > 0 ? e.every((v) => v >= 0) : e.every((v) => v <= 0) }
    m.push(ins || near(A, B, q) || near(B, C, q) || near(C, A, q))
  }
  return m
}
function find(s) {
  const N = 15, cells = s.cells, grouped = []
  for (let i = 0; i < N * N; i++) if (cells[i] >= 10) grouped.push(i)
  let best = null
  for (let id = 0; id < 5; id++) {
    const bl = []
    for (let i = 0; i < N * N; i++) if (cells[i] === id) bl.push([Math.floor(i / N), i % N])
    for (let t = 0; t < 3000 && bl.length >= 3; t++) {
      const a = bl[Math.floor(Math.random() * bl.length)], b = bl[Math.floor(Math.random() * bl.length)], c = bl[Math.floor(Math.random() * bl.length)]
      if (a === b || b === c || a === c) continue
      const xs = [a[0], b[0], c[0]], ys = [a[1], b[1], c[1]]
      if (Math.min(...xs) === Math.max(...xs) || Math.min(...ys) === Math.max(...ys)) continue
      const m = maskOf(a, b, c)
      if (grouped.some((g) => !m[g])) continue
      const n = m.filter((v) => v).length
      if (n >= grouped.length + 6 && (!best || (process.env.BIG ? n > best[1] : n < best[1]))) best = [[a, b, c], n]
    }
  }
  return best ? best[0] : null
}
const wait = async (steps) => {
  for (;;) { const s = await b.eval('window.__over ? null : window.__trigo'); if (!s || (steps.includes(s.step) && s.swaping === 0)) return s; await b.sleep(50) }
}
try {
  await b.goto(HOST + '/game.html?game=trigo&cls=GameTrigo&h=500&seed=123' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && window.__trigo && window.__trigoMask)', 60000)
  await b.eval(`(() => {
    const S = kk.renderer.shader
    window.__progs = []
    const gen = S.generateShader.bind(S)
    S.generateShader = function (shader) { const t = performance.now(); const r = gen(shader); __progs.push({ ms: +(performance.now() - t).toFixed(1), frame: kk.replay.getCurrentFrame(), name: shader.program.name || '' }); return r }
    window.__ft = []
    let last = performance.now()
    window.__long = []
    PIXI.Ticker.system.add(() => { const t = performance.now(); __ft.push(t - last); if (t - last > 34 && window.__trigo) __long.push([+(t - last).toFixed(0), __trigo.frame, __trigo.step, __trigo.fx]); last = t })
  })()`)
  for (let i = 0; i <= rounds; i++) {
    for (let k = 0; k < 3; k++) {
      if (!(await wait(['S_Play', 'S_FPlay']))) break
      const tri = find(await b.eval('window.__trigo'))
      if (!tri) break
      for (const c of tri) await click(c)
    }
    const s = await wait(['S_FPlay'])
    if (!s) break
    if (i < rounds) {
      // take the triangle: a click on a block of it
      const gi = s.cells.findIndex((c) => c >= 10)
      await click([Math.floor(gi / 15), gi % 15])
    } else {
      // the last one runs out: its blocks are destroyed
      await b.waitFor('window.__trigo.step === "S_Destroy" || !!window.__over', 60000)
      await b.sleep(3000)
    }
  }
  const r = JSON.parse(await b.eval(`JSON.stringify({ progs: __progs, n: __ft.length, ft: __ft.slice(5).sort((a, c) => a - c), score: window.__trigo.score })`))
  const ft = r.ft
  const q = (p) => ft[Math.min(ft.length - 1, Math.floor(ft.length * p))].toFixed(1)
  console.log('score', r.score, 'shaders after start', r.progs.length, JSON.stringify(r.progs).slice(0, 400))
  console.log('frames', ft.length, 'median', q(0.5), 'p95', q(0.95), 'p99', q(0.99), 'max', ft[ft.length - 1].toFixed(1), 'over 34 ms', ft.filter((v) => v > 34).length)
  console.log('long frames [ms, frame, step, effects]', await b.eval('JSON.stringify(window.__long)'))
  console.log(b.consoleLines.filter((l) => /EXCEPTION|rror/.test(l)).slice(0, 5).join('\n'))
} finally { await b.close() }
