// Quadrikolor bot + replay: plays a real game with mouse events (and Space): for each shot it looks for a ball it can
// send into a hole (ghost ball: the ship aimed at the point that touches the ball on the side away from the corner),
// moves the mouse there like a hand, clicks (direction), waits for the power it wants on the gauge and clicks again;
// sometimes it presses Space during the choice of the power (back to the direction), plays a random shot or a bank
// shot, clicks during the score sheet (it closes). Then it plays the replay and compares the end state (MATCH expected).
// usage: node q3.mjs [bot seed] [replay speed]
// env: PORT (DevTools, default 9962; the replay uses PORT + 1), HPORT, EXTRA (url params, test modes), LOG=1
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor&seed=123' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9962)
let b = await launch(PORT)
// game pixel -> page pixel (canvas at (8, 8), drawn x2)
const P = (v) => 8 + v * 2
const stats = { shots: 0, cancels: 0, skips: 0, random: 0, banks: 0 }
const STATE = `(() => { const g = kk.game; const st = window.__state
  return { over: !!window.__over, state: g.state, speed: g.speed, start: g.start_time, frame: st && st.frame, score: st && st.score,
    balls: g.balls.map(b => [b.ship ? -1 : b.id, b.x, b.y]) } })()`
const HOLES = [[0, 14], [300, 14], [0, 300], [300, 300]]
let mx = 150, my = 150
async function moveTo(x, y) {
  x = Math.max(1, Math.min(299, x)); y = Math.max(1, Math.min(299, y))
  const n = 6 + rnd(8)
  for (let i = 1; i <= n; i++) {
    const t = i / n
    await b.move(P(mx + (x - mx) * t), P(my + (y - my) * t))
    await b.sleep(15 + rnd(20))
  }
  mx = x; my = y
}
// the aim of the next shot: [x, y] for the mouse, wanted power (1..30)
function plan(s) {
  const ship = s.balls.find(b => b[0] < 0)
  const others = s.balls.filter(b => b[0] >= 0)
  let best = null
  for (const o of others) for (const h of HOLES) {
    const bx = h[0] - o[1], by = h[1] - o[2], bd = Math.hypot(bx, by)
    const cx = o[1] - bx / bd * 26, cy = o[2] - by / bd * 26
    const ax = cx - ship[1], ay = cy - ship[2], ad = Math.hypot(ax, ay)
    if (ad < 5) continue
    const cos = (ax * bx + ay * by) / (ad * bd)
    if (cos < 0.35) continue
    const v = cos * 2 - (ad + bd) / 300
    if (!best || v > best.v) best = { v, x: cx, y: cy, d: ad + bd }
  }
  const r = rnd(10)
  if (!best || r == 0) {
    stats.random++
    return [rnd(300), 14 + rnd(286), 5 + rnd(25)]
  }
  if (r == 1) {
    // a bank shot: aim at the mirror of the target in a wall
    stats.banks++
    const o = others[rnd(others.length)]
    const w = rnd(4)
    const m = w == 0 ? [-o[1] + 26, o[2]] : w == 1 ? [600 - o[1] - 26, o[2]] : w == 2 ? [o[1], 28 - o[2] + 26] : [o[1], 600 - o[2] - 26]
    return [ship[1] + (m[0] - ship[1]) * 0.5, ship[2] + (m[1] - ship[2]) * 0.5, 22 + rnd(8)]
  }
  return [best.x, best.y, Math.min(30, 12 + best.d / 25 + rnd(6))]
}
let live, data, liveOver, t = 0
try {
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  let want = 20
  for (; ; t++) {
    const s = await b.eval(STATE)
    if (s.over) break
    if (s.state == 0 && s.start < 0) {
      const [x, y, p] = plan(s)
      want = p
      await moveTo(x, y)
      await b.sleep(150 + rnd(700))
      await b.click(P(mx), P(my), 40 + rnd(80))
      await b.waitFor('kk.game.state != 0 || !!window.__over', 3000).catch(() => {})
      if (process.env.LOG) console.log(t, 'aim', x.toFixed(1), y.toFixed(1), 'power', want.toFixed(1), s.frame, s.score)
    } else if (s.state == 1) {
      if (rnd(40) == 0) {
        await b.send('Input.dispatchKeyEvent', { type: 'keyDown', windowsVirtualKeyCode: 32, nativeVirtualKeyCode: 32, key: ' ', code: 'Space' })
        await b.sleep(60 + rnd(60))
        await b.send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: 32, nativeVirtualKeyCode: 32, key: ' ', code: 'Space' })
        stats.cancels++
        await b.waitFor('kk.game.state != 1 || !!window.__over', 3000).catch(() => {})
      } else if (Math.abs(s.speed - want) < 2.5) {
        await b.click(P(mx), P(my), 40 + rnd(80))
        stats.shots++
        await b.waitFor('kk.game.state != 1 || !!window.__over', 3000).catch(() => {})
      }
    } else if (s.state == 6 && rnd(30) == 0) {
      await b.click(P(mx), P(my), 40 + rnd(60))
      stats.skips++
      await b.waitFor('kk.game.state != 6 || !!window.__over', 5000).catch(() => {})
    }
    await b.sleep(10 + rnd(20))
  }
  await b.waitFor('!!window.__over', 300000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver, JSON.stringify(stats), 'ticks', t, 'replay chars', data.length)
  writeFileSync(gameDir('quadrikolor', 'replays') + '/q3_' + process.argv[2] + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 1)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
