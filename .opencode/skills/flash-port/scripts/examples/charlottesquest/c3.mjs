// Charlotte's Quest: a bot plays a League game with real inputs: it flies with the arrows (and ZQSD-WASD at times), shoots
// with Space / Ctrl, keeps away from the monsters, their shots and the walls, goes for the notes and the power-ups, stays
// ahead of the scrolling; at times it switches the mouse controls of the original on (U), steers and shoots with the mouse,
// then switches them off. TOUCH=1: the joystick and the shoot button of a touch screen. Then its replay is played and the
// end states compared.
// usage: node c3.mjs <rng seed> [replay speed] [shots dir]    env: EXTRA (url params, e.g. '&test=cq&inv=1&frames=3000'),
//        PORT, TOUCH=1, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync, mkdirSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=charlottesquest&cls=GameCharlottesQuest&seed=123&h=500' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9640)
const TOUCH = process.env.TOUCH === '1'
const MAXT = +(process.env.MAXT || 40000)
const K = { left: [37, 'ArrowLeft'], up: [38, 'ArrowUp'], right: [39, 'ArrowRight'], down: [40, 'ArrowDown'], space: [32, ' ', 'Space'],
  ctrl: [17, 'Control', 'ControlLeft'], u: [85, 'u', 'KeyU'] }
const ALT = { left: [65, 'q', 'KeyA'], right: [68, 'd', 'KeyD'], up: [87, 'z', 'KeyW'], down: [83, 's', 'KeyS'] }
let b = await launch(PORT)
const send = (type, [code, k, c]) => b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: c || k })
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 })
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
const held = new Map()
const down = async (name, alt) => {
  const kk = alt && ALT[name] ? ALT[name] : K[name]
  if (held.has(name)) { if (held.get(name) === kk) return; await send('keyUp', held.get(name)) }
  await send('keyDown', kk); held.set(name, kk)
}
const up = async (name) => { if (held.has(name)) { await send('keyUp', held.get(name)); held.delete(name) } }
const STATE = 'JSON.stringify(kk.game && kk.game.player ? kk.game.botState() : null)'
const stats = { mouseMode: 0, alias: 0, ctrl: 0, touch: 0 }
// the joystick of a touch screen: a finger held at the left, moved in the direction; the shoot button at the bottom right
const JX = 8 + 96, JY = 8 + 390
let joy = null, shootTouch = false
const touchSet = async (dx, dy, shoot) => {
  const pts = []
  if (dx || dy) pts.push({ x: JX + dx * 40, y: JY + dy * 40, id: 1, radiusX: 4, radiusY: 4, force: 1 })
  if (shoot) pts.push({ x: 8 + 600 - 16 - 42, y: 8 + 500 - 16 - 42, id: 2, radiusX: 4, radiusY: 4, force: 1 })
  const was = (joy ? 1 : 0) + (shootTouch ? 1 : 0)
  if (!pts.length) { if (was) await touch('touchEnd', []) }
  else if (!was) {
    // the joystick's centre is where the finger lands (dynamicCenter): first at the centre, then moved
    if (dx || dy) { await touch('touchStart', [{ x: JX, y: JY, id: 1, radiusX: 4, radiusY: 4, force: 1 }]); await touch('touchMove', pts) }
    else await touch('touchStart', pts)
  } else await touch('touchMove', pts)
  joy = dx || dy ? [dx, dy] : null
  shootTouch = shoot
}
let live, data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.player)', 60000)
  if (shots) mkdirSync(shots, { recursive: true })
  let snap = 0, mouseUntil = -1, aliasUntil = -1, useCtrl = false
  for (; t < MAXT; t++) {
    const s = JSON.parse(await b.eval(STATE))
    if (!s || s.over) break
    if (shots && t % 50 === 0 && snap < 40) await b.screenshot(shots + '/c' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    if (s.dead || s.ended) { for (const k of [...held.keys()]) await up(k); if (TOUCH) await touchSet(0, 0, false); await b.sleep(100); continue }
    // where to go: ahead of the scrolling, away from the threats and the walls, towards the items
    let vx = (300 + s.sdx * 90 - s.px) / 200, vy = (230 + s.sdy * 70 - s.py) / 160
    for (const e of s.en) {
      if (!e.h) continue
      const dx = s.px - e.x, dy = s.py - e.y, d = Math.hypot(dx, dy) - e.r
      if (d < 140) { const k = 30 / Math.max(10, d); vx += dx / (d + e.r) * k; vy += dy / (d + e.r) * k }
    }
    for (const q of s.bu) {
      const dx = s.px - q.x, dy = s.py - q.y, d = Math.hypot(dx, dy)
      if (d < 90) { const k = 25 / Math.max(8, d); vx += dx / d * k; vy += dy / d * k }
    }
    for (const w of s.walls) {
      const dx = s.px - w.x, dy = s.py - w.y, d = Math.hypot(dx, dy)
      if (d < 48) { const k = 12 / Math.max(8, d); vx += dx / d * k; vy += dy / d * k }
    }
    let best = null, bd = 260
    for (const it of s.it) { const d = Math.hypot(it.x - s.px, it.y - s.py); if (d < bd) { bd = d; best = it } }
    if (best) { vx += (best.x - s.px) / bd * 0.8; vy += (best.y - s.py) / bd * 0.8 }
    const shoot = rnd(10) < 8
    // the mouse controls of the original (U) for a while
    if (!TOUCH && !s.mouse && mouseUntil < 0 && rnd(400) === 0) { await down('u'); await b.sleep(40); await up('u'); mouseUntil = t + 80 + rnd(120); stats.mouseMode++ }
    if (s.mouse) {
      for (const k of ['left', 'right', 'up', 'down', 'space', 'ctrl']) await up(k)
      const mx = Math.max(5, Math.min(595, s.px + vx * 90)), my = Math.max(5, Math.min(455, s.py + vy * 90))
      await mouse(shoot ? 'mousePressed' : 'mouseReleased', mx, my, shoot ? 1 : 0)
      await mouse('mouseMoved', mx, my, shoot ? 1 : 0)
      if (t >= mouseUntil) { await mouse('mouseReleased', mx, my); await down('u'); await b.sleep(40); await up('u'); mouseUntil = -1 }
      await b.sleep(25 + rnd(20))
      continue
    }
    if (TOUCH) {
      const dx = vx > 0.25 ? 1 : vx < -0.25 ? -1 : 0, dy = vy > 0.25 ? 1 : vy < -0.25 ? -1 : 0
      await touchSet(dx, dy, shoot); stats.touch++
      await b.sleep(25 + rnd(20))
      continue
    }
    // the aliases ZQSD-WASD for a while
    if (aliasUntil < t && rnd(300) === 0) { aliasUntil = t + 50 + rnd(100); stats.alias++ }
    const alt = aliasUntil >= t
    if (vx > 0.25) { await up('left'); await down('right', alt) } else if (vx < -0.25) { await up('right'); await down('left', alt) } else { await up('left'); await up('right') }
    if (vy > 0.25) { await up('up'); await down('down', alt) } else if (vy < -0.25) { await up('down'); await down('up', alt) } else { await up('up'); await up('down') }
    if (rnd(200) === 0) { useCtrl = !useCtrl; if (useCtrl) stats.ctrl++ }
    if (shoot) { await up(useCtrl ? 'space' : 'ctrl'); await down(useCtrl ? 'ctrl' : 'space') } else { await up('space'); await up('ctrl') }
    await b.sleep(25 + rnd(20))
  }
  for (const k of [...held.keys()]) await up(k)
  if (TOUCH) await touchSet(0, 0, false)
  await b.waitFor('!!window.__over', 900000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  live = JSON.parse(liveOver).score
  console.log('live', liveOver, JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('charlottesquest', 'replays') + '/c_replay_' + process.argv[2] + (TOUCH ? 't' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
