// Brutal Teenage Crisis on a touch screen: each button of Game.TOUCH_CONTROLS acts (run right / left, double tap: dash,
// jump, go down, phase), then the replay of that game on a desktop browser must give the same end state.
// usage: node btouch.mjs      env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
const out = gameDir('brutalteenagecrisis', 'check', 'touch')
const URL0 = HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500&test=btc&inv=1&frames=900'
const PORT = +(process.env.PORT || 9580)
const clip = { x: 8, y: 8, width: 600, height: 500 }
// centres of the buttons on the canvas of 600 x 500 (leftPx / rightPx / bottomPx + size 50 of Game.TOUCH_CONTROLS)
const BTN = { left: [33, 427], right: [91, 427], down: [509, 427], jump: [567, 427], phase: [567, 369] }
const S = 'JSON.parse(JSON.stringify(kk.game.botState()))'
let b = await launch(PORT)
let data, liveOver
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
const P = ([x, y], id) => ({ x: x + 8, y: y + 8, id, radiusX: 4, radiusY: 4, force: 1 })
const hold = async (btn, ms, id = 1) => { await touch('touchStart', [P(BTN[btn], id)]); await b.sleep(ms); await touch('touchEnd', []) }
const ok = (c) => (c ? 'OK' : 'FAIL')
const waitStable = () => b.waitFor('kk.game.botState().stable', 10000)
try {
  await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode && kk.game.mode.hero)', 60000)
  await waitStable()
  console.log('overlay', await b.eval('!!kk.touchOverlay'))
  await b.screenshot(out + '/t_start.png', clip)
  let s0 = await b.eval(S)
  await hold('right', 600)
  let s1 = await b.eval(S)
  console.log('right: hero x', s0.cx.toFixed(2), '->', s1.cx.toFixed(2), ok(s1.cx > s0.cx + 1))
  await b.sleep(300)
  s0 = await b.eval(S)
  await hold('left', 600)
  s1 = await b.eval(S)
  console.log('left: hero x', s0.cx.toFixed(2), '->', s1.cx.toFixed(2), ok(s1.cx < s0.cx - 1))
  await waitStable()
  // a double tap dashes (Hero.checkKeyCombo: released, then pressed again within 5 frames)
  await hold('right', 50)
  await b.sleep(50)
  await touch('touchStart', [P(BTN.right, 1)])
  await b.sleep(60)
  const dash = await b.eval('kk.game.mode.hero.cd.has("dashRun")')
  await touch('touchEnd', [])
  console.log('double tap right: dash', ok(dash))
  await waitStable()
  s0 = await b.eval(S)
  await touch('touchStart', [P(BTN.jump, 2)])
  await b.sleep(200)
  s1 = await b.eval(S)
  await b.screenshot(out + '/t_jump.png', clip)
  await touch('touchEnd', [])
  console.log('jump: hero y', s0.cy.toFixed(2), '->', s1.cy.toFixed(2), ok(s1.cy < s0.cy - 0.5))
  await waitStable()
  s0 = await b.eval(S)
  await hold('down', 120, 3)
  await b.sleep(600)
  s1 = await b.eval(S)
  console.log('down: hero y', s0.cy.toFixed(2), '->', s1.cy.toFixed(2), ok(s1.cy > s0.cy + 1))
  await hold('phase', 100, 4)
  await b.sleep(100)
  const ph = await b.eval('kk.game.botState().phasing')
  await b.screenshot(out + '/t_phase.png', clip)
  console.log('phase: phasing', ok(ph))
  await b.waitFor('!!window.__over', 120000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver, 'replay chars', data.length)
} finally {
  const errs = b.consoleLines.filter((l) => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 1500))
  await b.close()
}
// the replay on a desktop browser (no touch)
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode)', 60000)
  await b.eval('kk.setReplaySpeed(8)')
  await b.waitFor('!!window.__over', 300000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  await b.close()
}
