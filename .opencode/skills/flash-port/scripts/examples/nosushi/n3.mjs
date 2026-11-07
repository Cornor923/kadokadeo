// NosuShi: a bot plays a game with real mouse events (or taps of a finger: TOUCH=1), then its replay is played on a
// desktop browser and the end states compared. Most clicks take a group (often the biggest), some are on a food alone
// (nothing), some out of the tray (nothing), some pressed on a group and released out of the game (no click, like the
// CLICK of Flash); the mouse also wanders over the tray between the clicks (the groups light up under it).
// usage: node n3.mjs <rng seed> [replay speed] [shots dir]     env: EXTRA (url params, e.g. '&test=ns&bonus=6'),
//   TOUCH=1 (touch screen), PORT, HPORT, MAXT (actions)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync } from 'node:fs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const shots = process.argv[4]
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=nosushi&cls=GameNosushi&h=500&seed=123' + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9873)
const MAXT = +(process.env.MAXT || 200)
const TOUCH = process.env.TOUCH === '1'
const N = 9
// the clip of the food (x, y) (Block.drawPos: RAY 24, DELTA_X 223, DELTA_Y 28) is the centre of its cell
// (Game.convertPos); the canvas is at (8, 8) of the page
const CELL = (x, y) => [(x - y) * 24 + 223, (x + y) * 24 + 28]

// the groups of the grid (cells: x * 9 + y -> id * 10 + bonus, -1 empty), like Game.initGroups / Block.makeGroup
function groups(cells) {
  const id = (x, y) => (x < 0 || y < 0 || x >= N || y >= N ? -2 : (cells[x * N + y] < 0 ? -1 : Math.floor(cells[x * N + y] / 10)))
  const seen = new Set()
  const out = []
  for (let x = 0; x < N; x++) for (let y = 0; y < N; y++) {
    if (seen.has(x * N + y) || id(x, y) < 0) continue
    const g = []
    const todo = [[x, y]]
    seen.add(x * N + y)
    while (todo.length) {
      const [cx, cy] = todo.pop()
      g.push([cx, cy])
      for (const [dx, dy] of [[1, 0], [0, 1], [-1, 0], [0, -1]]) {
        const nx = cx + dx, ny = cy + dy
        if (id(nx, ny) !== id(x, y) || seen.has(nx * N + ny)) continue
        seen.add(nx * N + ny)
        todo.push([nx, ny])
      }
    }
    out.push(g)
  }
  return out
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
const stats = { big: 0, group: 0, single: 0, outside: 0, dragOut: 0, taken: 0, nothing: 0 }
let data, liveOver, t = 0
try {
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 })
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game && window.__nosushi)', 60000)
  let snap = 0
  while (t < MAXT) {
    const s = await b.eval('window.__over ? null : window.__nosushi')
    if (!s) break
    if (s.step !== 'S_Play') {
      // the mouse wanders over the tray while the foods fall
      if (!TOUCH && rnd(3) === 0) await moveTo(...CELL(rnd(N), rnd(N)))
      await b.sleep(60)
      continue
    }
    t++
    if (shots && snap < 40) await b.screenshot(shots + '/n' + String(snap++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
    const plays = s.leftPlay
    const gs = groups(s.cells)
    const big = gs.filter((g) => g.length > 1).sort((a, c) => c.length - a.length)
    const singles = gs.filter((g) => g.length === 1)
    const r = rnd(20)
    if (r === 0) {
      // out of the tray: nothing (the corners of the stage)
      const x = rnd(2) ? 10 + rnd(60) : 460 + rnd(130), y = 10 + rnd(60)
      await press(x, y, x, y, 40 + rnd(80))
      stats.outside++
    } else if (r === 1 && !TOUCH && big.length) {
      // a press on a group released out of the game: no click
      const [cx, cy] = big[rnd(big.length)][0]
      const [x, y] = CELL(cx, cy)
      await press(x, y, 610 + rnd(40), 20 + rnd(400), 80 + rnd(120))
      stats.dragOut++
    } else if (r === 2 && singles.length) {
      // a food alone: nothing
      const [x, y] = CELL(...singles[rnd(singles.length)][0])
      await press(x, y, x, y, 30 + rnd(80))
      stats.single++
    } else if (big.length) {
      let g
      if (rnd(3)) { g = big[0]; stats.big++ } else { g = big[rnd(big.length)]; stats.group++ }
      const [cx, cy] = g[rnd(g.length)]
      const [x0, y0] = CELL(cx, cy)
      const x = x0 + rnd(17) - 8, y = y0 + rnd(17) - 8
      if (!TOUCH) { await moveTo(x, y); await b.sleep(30 + rnd(150)) }
      await press(x, y, x, y, 30 + rnd(100))
    } else {
      break
    }
    // the plate is spent when the group is taken
    await b.sleep(150)
    const s2 = await b.eval('window.__nosushi')
    if (s2.leftPlay < plays || s2.step !== 'S_Play') stats.taken++
    else stats.nothing++
    await b.sleep(20 + rnd(60))
  }
  await b.waitFor('!!window.__over', 120000)
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver.slice(0, 160), JSON.stringify(stats), 'actions', t, 'replay chars', data.length)
  writeFileSync(gameDir('nosushi', 'replays') + '/n_replay_' + process.argv[2] + (TOUCH ? '_touch' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__nosushi)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 600000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep === liveOver ? 'MATCH' : 'MISMATCH ' + rep.slice(0, 200))
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
