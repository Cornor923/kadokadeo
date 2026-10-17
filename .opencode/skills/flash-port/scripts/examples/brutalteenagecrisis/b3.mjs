// Brutal Teenage Crisis: a bot plays a whole game with real key presses (runs to the mobs and the gold, jumps held or
// not, drops through the platforms, dashes with a double tap, phases with space, aliases ZQSD-WASD), then its replay is
// played and the end states compared.
// usage: node b3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params), PORT, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9520)
const MAXT = +(process.env.MAXT || 4000)
const K = { left: [37, 'ArrowLeft'], up: [38, 'ArrowUp'], right: [39, 'ArrowRight'], down: [40, 'ArrowDown'], space: [32, ' '] }
const ALT = { left: [65, 'KeyA'], right: [68, 'KeyD'], up: [87, 'KeyW'], down: [83, 'KeyS'] }
let b = await launch(PORT)
const send = (type, [code, k]) => b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: k })
const held = new Set()
const press = async (name, alt) => { const kk = alt && ALT[name] ? ALT[name] : K[name]; if (held.has(kk)) return; await send('keyDown', kk); held.add(kk) }
const release = async (name) => { for (const kk of [K[name], ALT[name]]) if (kk && held.has(kk)) { await send('keyUp', kk); held.delete(kk) } }
const tap = async (name, ms = 60, alt = false) => { await press(name, alt); await b.sleep(ms); await release(name) }
const STATE = 'JSON.stringify(kk.game && kk.game.mode && kk.game.mode.hero ? kk.game.botState() : null)'
const stats = { jumps: 0, drops: 0, dashes: 0, phases: 0, turns: 0 }
let live, data, liveOver, t = 0
try {
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode && kk.game.mode.hero)', 60000)
  let snap = 0, dir = null
  for (; t < MAXT; t++) {
    const s = JSON.parse(await b.eval(STATE))
    if (!s || s.over) break
    if (shots && t % 60 === 0 && snap < 20) await b.screenshot(shots + '/b' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    // target: a climbing mob first (it escapes at the top), else the nearest mob, else an item, else wander
    let target = null, best = 1e9
    for (const m of s.mobs) {
      const d = Math.abs(m.cx - s.cx) + 2 * Math.abs(m.cy - s.cy) - (m.climbing ? 20 : 0)
      if (d < best) { best = d; target = m }
    }
    for (const it of s.items) {
      const d = Math.abs(it.cx - s.cx) + 2 * Math.abs(it.cy - s.cy) + 4
      if (d < best) { best = d; target = it }
    }
    if (!target || rnd(15) === 0) target = { cx: 1 + rnd(21), cy: s.cy }
    const want = target.cx < s.cx - 0.4 ? 'left' : target.cx > s.cx + 0.4 ? 'right' : null
    if (want !== dir) {
      if (dir) await release(dir)
      dir = want
      stats.turns++
      if (dir) {
        // a double tap dashes now and then
        if (rnd(6) === 0) { await tap(dir, 40); await b.sleep(40); stats.dashes++ }
        await press(dir, rnd(3) === 0)
      }
    }
    if (s.stable && !s.stun) {
      if (target.cy < s.cy - 1.5 || rnd(10) === 0) { await press('up', rnd(4) === 0); await b.sleep(40 + rnd(250)); await release('up'); stats.jumps++ }
      else if (target.cy > s.cy + 1.5 && rnd(3) === 0) { await tap('down', 60, rnd(2) === 0); stats.drops++ }
    }
    if (s.phaseReady && rnd(40) === 0) { await tap('space', 60); stats.phases++ }
    await b.sleep(20 + rnd(50))
  }
  for (const kk of [...held]) await send('keyUp', kk)
  held.clear()
  if (!(await b.eval('!!window.__over'))) await b.eval('kk.game.mode.gameOver(false)')
  await b.waitFor('!!window.__over', 120000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  live = JSON.parse(liveOver).score
  console.log('live', liveOver, JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('brutalteenagecrisis', 'replays') + '/b_replay_' + process.argv[2] + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode && kk.game.mode.hero)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 600000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
