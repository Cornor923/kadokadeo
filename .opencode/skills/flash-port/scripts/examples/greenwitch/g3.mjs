// Green Witch: a bot plays a League game with real inputs (the mouse, or a finger with TOUCH=1): it clicks to walk towards
// the princes and the gold, clicks a weapon dispenser when its ammunition runs low, holds the button on a square near the
// witch to summon a turret when monsters come, and moves the mouse over the game. Then its replay is played and the end
// states compared.
// usage: node g3.mjs <rng seed> [replay speed] [shots dir]    env: EXTRA (url params, e.g. '&test=gw&frames=3000'), PORT,
//        TOUCH=1, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=greenwitch&cls=GameGreenWitch&seed=123&h=500' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9933)
const TOUCH = process.env.TOUCH === '1'
const MAXT = +(process.env.MAXT || 40000)
let b = await launch(PORT)
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 })
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
const STATE = 'JSON.stringify(kk.game ? kk.game.botState() : null)'
const stats = { clicks: 0, turrets: 0, dispensers: 0, princes: 0, gold: 0 }
const clampX = (x) => Math.max(10, Math.min(590, x)), clampY = (y) => Math.max(10, Math.min(450, y))
const onScreen = (o) => o.x > 10 && o.x < 590 && o.y > 10 && o.y < 450
const press = async (x, y) => {
  if (TOUCH) await touch('touchStart', [{ x: 8 + x, y: 8 + y, id: 1, radiusX: 4, radiusY: 4, force: 1 }])
  else { await mouse('mouseMoved', x, y); await mouse('mousePressed', x, y, 1) }
}
const release = async (x, y) => {
  if (TOUCH) await touch('touchEnd', [])
  else await mouse('mouseReleased', x, y)
}
// a click: pressed and released at once (a walk, a dispenser)
const click = async (x, y) => { await press(x, y); await b.sleep(30 + rnd(40)); await release(x, y); stats.clicks++ }
let live, data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.botState())', 60000)
  let snap = 0, busy = 0
  for (; t < MAXT; t++) {
    const s = JSON.parse(await b.eval(STATE))
    if (!s || s.over) break
    if (shots && t % 60 === 0 && snap < 30) await b.screenshot(shots + '/g' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    if (s.dead) { await b.sleep(100); continue }
    if (busy > 0) { busy--; await b.sleep(20); continue }
    const r = rnd(100)
    if (s.ammo < 15 && s.disp.some((d) => d.w) && r < 60) {
      // a weapon dispenser (the witch walks to it and takes it)
      const ws = s.disp.filter((d) => d.w)
      const d = ws[rnd(ws.length)]
      await click(clampX(d.x), clampY(d.y)); stats.dispensers++; busy = 20
    } else if (s.turrets > 0 && s.near < 90 && r < 25) {
      // a turret: the button held on a square near the witch (the summoning takes 10 frames of the game)
      const x = clampX(s.hx + (rnd(2) ? 1 : -1) * (30 + rnd(40))), y = clampY(s.hy + (rnd(2) ? 1 : -1) * (20 + rnd(40)))
      await press(x, y); await b.sleep(500 + rnd(300)); await release(x, y); stats.turrets++; busy = 5
    } else if (r < 70) {
      // a prince or gold on screen, else somewhere around the witch
      const civ = s.civ.filter(onScreen), gold = s.gold.filter(onScreen)
      let x, y
      if (civ.length && rnd(2)) { const c = civ[rnd(civ.length)]; x = c.x; y = c.y; stats.princes++ }
      else if (gold.length && rnd(2)) { const g = gold[rnd(gold.length)]; x = g.x; y = g.y; stats.gold++ }
      else { x = s.hx + rnd(400) - 200; y = s.hy + rnd(300) - 150 }
      await click(clampX(x), clampY(y)); busy = 8 + rnd(10)
    } else if (!TOUCH) {
      await mouse('mouseMoved', 20 + rnd(560), 20 + rnd(420))
    }
    await b.sleep(15 + rnd(20))
  }
  await b.waitFor('!!window.__over', 900000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  live = JSON.parse(liveOver).score
  console.log('live', liveOver, JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('greenwitch', 'replays') + '/g_replay_' + process.argv[2] + (TOUCH ? 't' : '') + '.txt', data + '\n' + liveOver)
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
