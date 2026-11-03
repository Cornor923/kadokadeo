// Fafi 360: a bot plays a whole match (the League) with real inputs: when its player has the ball, it waits for the turning
// arrow to point at the goal (or forward), holds the button (the mouse, Space, Enter, or a finger with TOUCH=1) until the
// power it wants, and releases; it moves the mouse over the game (the camera follows it) and now and then out of the game,
// shows / hides the mini map (M). Then its replay is played and the end states compared.
// usage: node f3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params), PORT, TOUCH=1, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=fafi360&cls=GameFafi360&seed=123&h=500' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9560)
const TOUCH = process.env.TOUCH === '1'
const MAXT = +(process.env.MAXT || 20000)
const K = { space: [32, ' ', 'Space'], enter: [13, 'Enter', 'Enter'], m: [77, 'm', 'KeyM'] }
let b = await launch(PORT)
const key = (type, [code, k, c]) => b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: c })
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 })
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
const STATE = 'JSON.stringify(kk.game && kk.game.ball ? kk.game.botState() : null)'
const norm = (a) => { while (a > Math.PI) a -= 2 * Math.PI; while (a < -Math.PI) a += 2 * Math.PI; return a }
const stats = { shots: 0, mouse: 0, space: 0, enter: 0, touch: 0, map: 0, out: 0 }
let mx = 300, my = 230
// the button: pressed with one of the inputs, released with the same
let how = null
const down = async () => {
  const r = rnd(10)
  how = TOUCH ? 'touch' : r < 5 ? 'mouse' : r < 8 ? 'space' : 'enter'
  stats[how]++
  if (how === 'mouse') { await mouse('mouseMoved', mx, my); await mouse('mousePressed', mx, my, 1) }
  else if (how === 'touch') await touch('touchStart', [{ x: 8 + mx, y: 8 + my, id: 1, radiusX: 4, radiusY: 4, force: 1 }])
  else await key('keyDown', K[how])
}
const up = async () => {
  if (how === 'mouse') await mouse('mouseReleased', mx, my)
  else if (how === 'touch') await touch('touchEnd', [])
  else if (how) await key('keyUp', K[how])
  how = null
}
let live, data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.ball)', 60000)
  let snap = 0, want = 0.8
  for (; t < MAXT; t++) {
    const s = JSON.parse(await b.eval(STATE))
    if (!s || s.over) break
    if (shots && t % 80 === 0 && snap < 30) await b.screenshot(shots + '/f' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    if (how && !s.charging && t % 3 === 0) await up()
    if (s.playing && s.mine && !how) {
      // the goal, or forward when far from it (the arrow turns by 0.16 to 0.44 rad a frame: aim a bit ahead)
      const dx = s.goal.x - s.ox, dy = s.goal.y - s.oy
      const far = Math.hypot(dx, dy) > 420
      const target = far ? (rnd(3) === 0 ? -0.6 + rnd(13) / 10 : 0) : Math.atan2(dy, dx) + (rnd(5) - 2) * 0.05
      const d = norm(target - s.ang)
      if (d > 0 && d < 0.45) {
        want = far ? 0.55 + rnd(40) / 100 : 0.7 + rnd(30) / 100
        await down()
        stats.shots++
      }
    } else if (how && s.charging && s.power >= want) await up()
    // the mouse moves the camera: over the game, now and then out of it (the bar of KadoKadeo, the right side)
    if (!how && !TOUCH && rnd(12) === 0) {
      if (rnd(8) === 0) { mx = 300 + rnd(300); my = 465 + rnd(30); stats.out++ }
      else { mx = 20 + rnd(560); my = 20 + rnd(420) }
      await mouse('mouseMoved', mx, my)
    }
    if (!how && !TOUCH && rnd(400) === 0) { await key('keyDown', K.m); await b.sleep(40); await key('keyUp', K.m); stats.map++ }
    await b.sleep(8 + rnd(16))
  }
  await up()
  await b.waitFor('!!window.__over', 200000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  live = JSON.parse(liveOver).score
  console.log('live', liveOver, JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('fafi360', 'replays') + '/f_replay_' + process.argv[2] + (TOUCH ? 't' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.ball)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 600000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
