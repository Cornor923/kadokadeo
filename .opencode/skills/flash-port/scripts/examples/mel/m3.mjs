// Mel: a bot plays a game with real key presses (runs, jumps, double jumps, charged jumps, kicks, wall grips), then
// its replay is played and the end states compared.
// usage: node m3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params, e.g.
//   '&test=mel&pw=31&inv=1&nodl=1&climb=160&frames=5000': every power, no death, a page up every 5 s), PORT, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=mel&cls=GameMel&h=500&seed=123' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9841)
const MAXT = +(process.env.MAXT || 2500)
const K = { left: [37, 'ArrowLeft'], up: [38, 'ArrowUp'], right: [39, 'ArrowRight'], down: [40, 'ArrowDown'], space: [32, ' '], ctrl: [17, 'Control'] }
const ALT = { left: [81, 'KeyA'], right: [68, 'KeyD'], up: [87, 'KeyW'], down: [83, 'KeyS'] }
let b = await launch(PORT)
// (headless Chrome on macOS hides the page on a Control key event: no more frames until it is brought to the front)
const send = async (type, [code, k]) => {
  await b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: k })
  if (code === 17) await b.send('Page.bringToFront')
}
const held = new Set()
const press = async (name, alt) => { const kk = alt && ALT[name] ? ALT[name] : K[name]; await send('keyDown', kk); held.add(kk) }
const release = async (name) => { for (const kk of [K[name], ALT[name]]) if (kk && held.has(kk)) { await send('keyUp', kk); held.delete(kk) } }
const tap = async (name, ms = 60, alt = false) => { await press(name, alt); await b.sleep(ms); await release(name) }
const stats = { jumps: 0, djumps: 0, charges: 0, kicks: 0, turns: 0, states: {} }
let live, data, liveOver, t = 0
try {
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && kk.game.char && window.__mel)', 60000)
  let snap = 0, dir = 'right'
  await press(dir, rnd(3) === 0)
  for (; t < MAXT; t++) {
    const s = await b.eval('window.__over ? null : window.__mel')
    if (!s) break
    stats.states[s.state] = (stats.states[s.state] || 0) + 1
    if (shots && t % 40 === 0 && snap < 30) await b.screenshot(shots + '/m' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    if (rnd(10) === 0 || (dir === 'right' && s.cx > 33) || (dir === 'left' && s.cx < 4)) {
      await release(dir); dir = dir === 'right' ? 'left' : 'right'; stats.turns++
      if (rnd(5)) await press(dir, rnd(3) === 0)
    }
    if (s.state === 'WANDER_STAND' || s.state === 'WANDER_RUN') {
      const r = rnd(10)
      if (r < 5) {
        const key = ['space', 'up', 'ctrl'][rnd(3)]
        await press(key, key === 'up' && rnd(2) === 0); await b.sleep(80 + rnd(300)); await release(key); stats.jumps++
        if (rnd(3)) { await b.sleep(60 + rnd(200)); await tap('space', 60 + rnd(150)); stats.djumps++ }
      } else if (r === 5 && (s.powers & 4)) {
        await release(dir); await press('down', rnd(2) === 0); await b.sleep(400 + rnd(1400)); await tap('space', 80); await release('down'); stats.charges++
      }
    } else if (s.state === 'JUMP' || s.state === 'FALL') {
      if (rnd(8) === 0) { await tap('down', 50); stats.kicks++ }
    } else if (s.state === 'WALL_STICK') {
      if (rnd(3) === 0) { await tap('space', 60) }
    }
    await b.sleep(20 + rnd(50))
  }
  for (const kk of [...held]) await send('keyUp', kk)
  if (!(await b.eval('!!window.__over'))) await b.eval('kk.game.gameOver()')
  await b.waitFor('!!window.__over', 120000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver, JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('mel', 'replays') + '/m_replay_' + process.argv[2] + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.char)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 600000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
