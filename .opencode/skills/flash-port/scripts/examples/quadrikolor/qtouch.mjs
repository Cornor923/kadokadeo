// Quadrikolor on a touch screen: a finger only aims (dragged then lifted, nothing is chosen), the fire button chooses
// the direction, a finger on the table during the choice of the power aims again, the fire button chooses the power;
// a whole game is then played like this (ghost ball shots, like q3.mjs) and its replay, watched on a desktop browser,
// must give the same end state.
// usage: node qtouch.mjs [bot seed]      env: PORT (default 9984; the replay uses PORT + 1), HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor&seed=123'
const PORT = +(process.env.PORT || 9984)
const out = gameDir('quadrikolor', 'check', 'touch')
let b = await launch(PORT)
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
// game pixel -> page pixel (canvas at (8, 8), drawn x2)
const T = (x, y) => ({ x: 8 + x * 2, y: 8 + y * 2, id: 1, radiusX: 4, radiusY: 4, force: 1 })
const ST = 'kk.game.state'
const HOLES = [[0, 14], [300, 14], [0, 300], [300, 300]]
let fails = 0
const check = (what, ok) => { console.log(what, ok ? 'OK' : 'FAIL'); if (!ok) fails++ }
async function drag(x0, y0, x1, y1) {
  await touch('touchStart', [T(x0, y0)])
  for (let i = 1; i <= 8; i++) { await b.sleep(40); await touch('touchMove', [T(x0 + (x1 - x0) * i / 8, y0 + (y1 - y0) * i / 8)]) }
  await b.sleep(300)
}
async function tap(x, y) {
  await touch('touchStart', [T(x, y)])
  await b.sleep(60 + rnd(60))
  await touch('touchEnd', [])
}
async function fireButton() {
  // TOUCH_CONTROLS: size 64, centered, bottomPx 4 of the 600 x 640 canvas
  await b.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 8 + 300, y: 8 + 640 - 4 - 32, id: 2 }] })
  await b.sleep(60 + rnd(60))
  await b.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
}
let data, liveOver
try {
  await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  await b.sleep(1600)
  check('touch controls shown', await b.eval('!!kk.touchOverlay'))
  // drag the aim: the finger down does not choose
  const ship = await b.eval('[kk.game.ship.x, kk.game.ship.y]')
  const [ax, ay] = [ship[0] < 150 ? 250 : 50, ship[1] < 150 ? 250 : 60]
  await drag(150, 150, ax, ay)
  check('finger down: still aiming (state ' + await b.eval(ST) + ')', await b.eval(ST) === 0)
  check('touch mode', await b.eval('window.__state.touch'))
  await b.screenshot(out + '/t_aim.png', { x: 8, y: 8, width: 600, height: 640 })
  await touch('touchEnd', [])
  await b.sleep(500)
  check('finger lifted: still aiming (state ' + await b.eval(ST) + ')', await b.eval(ST) === 0)
  await fireButton()
  await b.waitFor(`${ST} != 0`, 3000).catch(() => {})
  check('fire button: power (state ' + await b.eval(ST) + ')', await b.eval(ST) === 1)
  const ang = await b.eval('kk.game.angle'), want = Math.atan2(ay - ship[1], ax - ship[0])
  check('direction towards the finger: ' + ang.toFixed(3) + ' / ' + want.toFixed(3), Math.abs(ang - want) < 0.02)
  await b.screenshot(out + '/t_power.png', { x: 8, y: 8, width: 600, height: 640 })
  await tap(150, 150)
  await b.waitFor(`${ST} != 1`, 3000).catch(() => {})
  check('finger on the table: aiming again (state ' + await b.eval(ST) + ')', await b.eval(ST) === 0)
  // a whole game with the finger
  const stats = { shots: 0, backs: 1 }
  for (let t = 0; ; t++) {
    const s = await b.eval(`(() => { const g = kk.game; return { over: !!window.__over, state: g.state, speed: g.speed, start: g.start_time,
      balls: g.balls.map(b => [b.ship ? -1 : b.id, b.x, b.y]) } })()`)
    if (s.over) break
    if (s.state == 0 && s.start < 0) {
      const sh = s.balls.find(x => x[0] < 0)
      let best = null
      for (const o of s.balls.filter(x => x[0] >= 0)) for (const h of HOLES) {
        const bx = h[0] - o[1], by = h[1] - o[2], bd = Math.hypot(bx, by)
        const cx = o[1] - bx / bd * 26, cy = o[2] - by / bd * 26
        const dx = cx - sh[1], dy = cy - sh[2], dd = Math.hypot(dx, dy)
        const v = (dx * bx + dy * by) / (dd * bd) * 2 - (dd + bd) / 300
        if (!best || v > best.v) best = { v, x: cx, y: cy }
      }
      const x = Math.max(1, Math.min(299, best.x)), y = Math.max(15, Math.min(299, best.y))
      await drag(sh[1] + (rnd(40) - 20), sh[2] + (rnd(40) - 20), x, y)
      await touch('touchEnd', [])
      await fireButton()
      await b.waitFor(`${ST} != 0 || !!window.__over`, 3000).catch(() => {})
    } else if (s.state == 1) {
      if (Math.abs(s.speed - 26) < 2.5) {
        await fireButton()
        stats.shots++
        await b.waitFor(`${ST} != 1 || !!window.__over`, 3000).catch(() => {})
      }
    } else if (s.state == 6 && rnd(25) == 0) {
      await tap(150, 150)
      await b.waitFor(`${ST} != 6 || !!window.__over`, 5000).catch(() => {})
    }
    await b.sleep(10)
  }
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver, JSON.stringify(stats))
  writeFileSync(gameDir('quadrikolor', 'replays') + '/qtouch_' + (process.argv[2] || 1) + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 1)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  await b.eval('kk.setReplaySpeed(8)')
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay (desktop)', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
  console.log(fails ? fails + ' FAIL' : 'all OK')
} finally {
  await b.close()
}
