// Rock Faller: a bot plays a game with real mouse events (or taps of a finger: TOUCH=1), then its replay is played on
// a desktop browser and the end states compared. Most clicks turn a square that makes a group or drops a rock into a
// tube (the rotation simulated on the grid of window.__rockfaller), some are random, some must turn nothing: a click
// out of the grid, a press on a square released out of the grid.
// usage: node r3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params, e.g. '&test=rf&plays=40'),
//   TOUCH=1 (touch screen), PORT, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=rockfaller&cls=GameRockFaller&h=500&seed=123' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9861)
const MAXT = +(process.env.MAXT || 400)
const TOUCH = process.env.TOUCH === '1'
// Game: STAGE_X 120, STAGE_Y 35, cells of 60 px; the canvas is at (8, 8) of the page
const SQ = (px, py) => [120 + (px + 1) * 60, 35 + (py + 1) * 60]
const SEL = [[0, 0], [1, 0], [1, 1], [0, 1]]

// groups of 4 or more gems / a rock on a tube after turning the square (px, py) (Game.rotationDone: clockwise)
function useful(s, px, py) {
  const g = s.grid.map((c) => c.slice())
  const ids = SEL.map(([dx, dy]) => s.grid[px + dx][py + dy])
  ids.unshift(ids.pop())
  SEL.forEach(([dx, dy], i) => { g[px + dx][py + dy] = ids[i] })
  for (const [ex] of s.exits) if (g[ex][5] >= 10) return true
  const seen = g.map((c) => c.map(() => false))
  for (let x = 0; x < 6; x++) for (let y = 0; y < 6; y++) {
    if (seen[x][y] || g[x][y] < 0 || g[x][y] >= 10) continue
    let n = 0
    const todo = [[x, y]]
    seen[x][y] = true
    while (todo.length) {
      const [cx, cy] = todo.pop()
      n++
      for (const [dx, dy] of [[1, 0], [0, 1], [-1, 0], [0, -1]]) {
        const nx = cx + dx, ny = cy + dy
        if (nx < 0 || ny < 0 || nx > 5 || ny > 5 || seen[nx][ny] || g[nx][ny] !== g[x][y]) continue
        seen[nx][ny] = true
        todo.push([nx, ny])
      }
    }
    if (n >= 4) return true
  }
  return false
}

let b = await launch(PORT)
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1, pointerType: 'mouse' })
const touch = (type, pts) => b.send('Input.dispatchTouchEvent', { type, touchPoints: pts })
let mx = 300, my = 230
const moveTo = async (x, y) => {
  if (TOUCH) { mx = x; my = y; return }
  for (let i = 1; i <= 3; i++) { await mouse('mouseMoved', mx + (x - mx) * i / 3, my + (y - my) * i / 3); await b.sleep(10 + rnd(30)) }
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
const stats = { useful: 0, random: 0, outside: 0, dragOut: 0, turns: 0, nothing: 0 }
let live, data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && window.__rockfaller)', 60000)
  let snap = 0
  // (t counts the clicks: the steps of the animations are waited for)
  while (t < MAXT) {
    const s = await b.eval('window.__over ? null : window.__rockfaller')
    if (!s) break
    if (s.step !== 'S_Play') { await b.sleep(40); continue }
    t++
    if (shots && snap < 40) await b.screenshot(shots + '/r' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    const plays = s.plays
    const r = rnd(20)
    if (r === 0) {
      // out of the grid: turns nothing (x < 90: the first square is pointed from x = 91, Game.updateSelection)
      const x = 10 + rnd(75), y = 30 + rnd(400)
      await press(x, y, x, y, 40 + rnd(80))
      stats.outside++
    } else if (r === 1 && !TOUCH) {
      // a press on a square released out of the grid: turns nothing
      const [x, y] = SQ(rnd(5), rnd(5))
      await press(x, y, 540 + rnd(50), 20 + rnd(400), 80 + rnd(120))
      stats.dragOut++
    } else {
      const good = []
      for (let px = 0; px < 5; px++) for (let py = 0; py < 5; py++) if (useful(s, px, py)) good.push([px, py])
      let px, py
      if (good.length && rnd(4)) { [px, py] = good[rnd(good.length)]; stats.useful++ } else { px = rnd(5); py = rnd(5); stats.random++ }
      const [x, y] = SQ(px, py)
      const jx = x + rnd(50) - 25, jy = y + rnd(50) - 25
      if (!TOUCH) { await moveTo(jx, jy); await b.sleep(30 + rnd(120)) }
      await press(jx, jy, jx, jy, 30 + rnd(100))
    }
    // the play is spent when the square turns
    await b.sleep(120)
    const s2 = await b.eval('window.__rockfaller')
    if (s2.plays < plays || s2.step !== 'S_Play') stats.turns++
    else stats.nothing++
    await b.sleep(20 + rnd(60))
  }
  await b.waitFor('!!window.__over', 120000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver.slice(0, 120), JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('rockfaller', 'replays') + '/r_replay_' + process.argv[2] + (TOUCH ? '_touch' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__rockfaller)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 600000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep === liveOver ? 'MATCH' : 'MISMATCH ' + rep.slice(0, 200))
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
