// Trigo: a bot plays a game with real mouse events (or taps of a finger: TOUCH=1), then its replay is played on a desktop
// browser and the end states compared. It makes triangles (3 blocks of a colour clicked one after the other, the mouse
// moving over the grid in between: the blocks light up, the triangle is drawn), chains combos with triangles around the
// blocks already taken (preferring new colours: RainbowCombo, or the same one: UniCombo), takes them with a click on the
// triangle, sometimes lets the time of a combo run out (the blocks are destroyed); it also clicks a block of another
// colour, the same block twice, out of the grid, and presses on a block to release out of the game (no click, like the
// CLICK of Flash). The triangles are chosen with the rule of the game (window.__trigoMask of the debug build).
// usage: node t3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params, e.g. '&test=tg&time=900&colors=3'),
//   TOUCH=1 (touch screen), PORT, HPORT, MAXT (actions before the bot lets the clock run out)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=trigo&cls=GameTrigo&h=500&seed=123' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9874)
const MAXT = +(process.env.MAXT || 120)
const TOUCH = process.env.TOUCH === '1'
const N = 15
// the centre of the block (x, y) (Block.center: 26 x + 25); the canvas is at (8, 8) of the page
const CELL = (x, y) => [26 * x + 25, 26 * y + 25]

// in the page: the best triangles for the state s (cells: x * 15 + y -> colour, + 10 grouped, -1 empty), with the rule
// of the game: [score, cells, colour, taken]; `pref`: 'new' a colour not in the combo yet, 'same' the colour of the last
// triangle
const FIND = `(s, pref, lastId, used) => {
  const N = 15, cells = s.cells, out = []
  const grouped = []
  for (let i = 0; i < N * N; i++) if (cells[i] >= 10) grouped.push(i)
  for (let id = 0; id < 5; id++) {
    const bl = []
    for (let i = 0; i < N * N; i++) if (cells[i] === id) bl.push([Math.floor(i / N), i % N])
    if (bl.length < 3) continue
    // (a sample of the triples: the grid has up to 50 blocks of a colour)
    const tries = Math.min(2500, bl.length * bl.length * bl.length / 6)
    for (let t = 0; t < tries; t++) {
      const a = bl[Math.floor(Math.random() * bl.length)], b = bl[Math.floor(Math.random() * bl.length)], c = bl[Math.floor(Math.random() * bl.length)]
      if (a === b || b === c || a === c) continue
      const xs = [a[0], b[0], c[0]], ys = [a[1], b[1], c[1]]
      if (Math.min(...xs) === Math.max(...xs) || Math.min(...ys) === Math.max(...ys)) continue
      const m = window.__trigoMask([a, b, c])
      let n = 0, ok = true
      for (const g of grouped) if (!m[g]) { ok = false; break }
      if (!ok) continue
      for (let i = 0; i < N * N; i++) if (m[i]) n++
      // (a combo: the smallest triangles around the blocks taken, so that more combos can follow)
      let score = pref === 'new' || pref === 'same' ? 1000 - n : n
      if (pref === 'new' && !used.includes(id)) score += 400
      if (pref === 'same' && id === lastId) score += 400
      if (pref === 'small') score = 1000 - n - (n < 8 ? 100 : 0)
      out.push([score, [a, b, c], id, n])
    }
  }
  out.sort((p, q) => q[0] - p[0])
  return out.slice(0, 5)
}`

let b = await launch(PORT)
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1, pointerType: 'mouse' })
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
let mx = 300, my = 230
const moveTo = async (x, y) => {
  if (TOUCH) { mx = x; my = y; return }
  const n = 2 + rnd(3)
  for (let i = 1; i <= n; i++) { await mouse('mouseMoved', mx + (x - mx) * i / n, my + (y - my) * i / n); await b.sleep(10 + rnd(30)) }
  mx = x; my = y
}
// press at (x, y), release at (x2, y2) (a finger: no hover, the press is the first position)
const press = async (x, y, x2, y2, hold) => {
  if (TOUCH) {
    await touch('touchStart', [{ x: 8 + x, y: 8 + y, id: 1, radiusX: 4, radiusY: 4, force: 1 }])
    if (x2 !== x || y2 !== y) { await b.sleep(hold / 2); await touch('touchMove', [{ x: 8 + x2, y: 8 + y2, id: 1, radiusX: 4, radiusY: 4, force: 1 }]) }
    await b.sleep(hold)
    await touch('touchEnd', [])
  } else {
    await moveTo(x, y)
    await mouse('mousePressed', x, y, 1)
    await b.sleep(hold / 2)
    if (x2 !== x || y2 !== y) await moveTo(x2, y2)
    await b.sleep(hold / 2)
    await mouse('mouseReleased', x2, y2)
  }
}
const jit = () => rnd(15) - 7
const clickCell = async ([x, y]) => {
  const [px, py] = CELL(x, y)
  await press(px + jit(), py + jit(), px + jit() / 2, py + jit() / 2, 30 + rnd(90))
  await b.sleep(40 + rnd(80))
}
const state = () => b.eval('window.__over ? null : window.__trigo')
const stats = { triangles: 0, combos: 0, taken: 0, expired: 0, wrong: 0, twice: 0, outside: 0, dragOut: 0, maxCombo: 0, maxBlocks: 0 }
let data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && window.__trigo && window.__trigoMask)', 60000)
  let snap = 0, used = [], lastId = -1, letExpire = false
  while (t < MAXT) {
    const s = await state()
    if (!s) break
    if (s.step !== 'S_Play' && s.step !== 'S_FPlay') {
      if (!TOUCH && rnd(3) === 0) await moveTo(...CELL(rnd(N), rnd(N)))
      await b.sleep(60)
      continue
    }
    if (s.swaping > 0) { await b.sleep(50); continue }
    t++
    if (shots && snap < 60) await b.screenshot(shots + '/t' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    const r = rnd(24)
    if (r === 0) {
      // out of the grid: a click on nothing (the triangle being made is dropped)
      await press(430 + rnd(150), 300 + rnd(140), 430 + rnd(150), 300 + rnd(140), 40 + rnd(80))
      stats.outside++
      continue
    }
    if (r === 1 && !TOUCH) {
      // a press on a block released out of the game: no click
      const [x, y] = CELL(rnd(N), rnd(N))
      await press(x, y, 610 + rnd(40), 20 + rnd(400), 80 + rnd(120))
      stats.dragOut++
      continue
    }
    if (s.step === 'S_FPlay') {
      stats.maxCombo = Math.max(stats.maxCombo, s.combo)
      if (letExpire) { await b.sleep(100); continue }
      // a combo around the blocks taken, or take them (a click on the triangle), or let the time of the combo run out
      const best = rnd(4) && s.combo < 12 ? await b.eval(`(${FIND})(${JSON.stringify(s)}, ${rnd(2) ? "'new'" : "'same'"}, ${lastId}, ${JSON.stringify(used)})`) : []
      if (process.env.DBG) console.log('fplay', s.frame, 'combo', s.combo, 'grouped', s.cells.filter((c) => c >= 10).length, 'best', best.length, best.length ? best[0][3] : '')
      if (best.length && rnd(5)) {
        const [, tri, id, n] = best[rnd(Math.min(2, best.length))]
        for (const c of tri) { if (!TOUCH) await moveTo(...CELL(...c)); await clickCell(c) }
        stats.combos++; stats.triangles++; used.push(id); lastId = id; stats.maxBlocks = Math.max(stats.maxBlocks, n)
      } else if (rnd(12) === 0) {
        letExpire = true
        stats.expired++
      } else {
        const gi = s.cells.findIndex((c) => c >= 10)
        if (gi >= 0) { await clickCell([Math.floor(gi / N), gi % N]); stats.taken++ }
      }
      continue
    }
    // S_Play: a new triangle
    letExpire = false
    used = []
    if (r === 2) {
      // a block, then a block of another colour (refused), then the first one again (the triangle is dropped)
      const i0 = rnd(N * N), c0 = s.cells[i0]
      const i1 = s.cells.findIndex((c, i) => c !== c0 && c >= 0 && c < 10 && i !== i0)
      await clickCell([Math.floor(i0 / N), i0 % N])
      if (i1 >= 0) await clickCell([Math.floor(i1 / N), i1 % N])
      await clickCell([Math.floor(i0 / N), i0 % N])
      stats.wrong++; stats.twice++
      continue
    }
    const best = await b.eval(`(${FIND})(${JSON.stringify(s)}, ${rnd(3) ? "'small'" : "'none'"}, -1, [])`)
    if (!best.length) { await b.sleep(100); continue }
    const [, tri, id, n] = best[rnd(Math.min(3, best.length))]
    for (const c of tri) {
      if (!TOUCH) { await moveTo(...CELL(rnd(N), rnd(N))); await moveTo(...CELL(...c)) }
      await clickCell(c)
    }
    stats.triangles++; used = [id]; lastId = id; stats.maxBlocks = Math.max(stats.maxBlocks, n)
    await b.sleep(80)
  }
  // the clock runs out (the mouse still wanders)
  while (!(await b.eval('!!window.__over'))) {
    if (!TOUCH) await moveTo(...CELL(rnd(N), rnd(N)))
    await b.sleep(300)
  }
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver.slice(0, 200), JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('trigo', 'replays') + '/t_replay_' + process.argv[2] + (TOUCH ? '_touch' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__trigo)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep === liveOver ? 'MATCH' : 'MISMATCH ' + rep.slice(0, 300))
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
