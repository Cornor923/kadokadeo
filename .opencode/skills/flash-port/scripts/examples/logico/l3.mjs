// Logico: a bot plays a whole game with real mouse events (moves like a hand, hovers, presses the ball that makes the
// best line of one colour once sent to the other side of the ring), then the replay of the game is played and the end
// states (frame, score, colours, difficulty, stats) compared.
// usage: node l3.mjs <bot seed> [replay speed]     env: EXTRA (url params, e.g. '&test=lg&frames=3000'), PORT, HPORT,
//        SEED (game seed, debug builds play 123), SHOTS (dir: a screenshot every 10 moves), DUMB (1 in DUMB moves is
//        random, default 6), TOUCH=1 (taps of a finger instead of the mouse), PERF=1 (with GPU=1: shaders compiled,
//        textures uploaded and long frames during the game), FREEZE=1 (the prototypes frozen by kac.Integrity like in
//        a bundled live game: the names the game assigns, read in the build as resources/js/games/builds/bundle.mjs does),
//        FILL=1 (also presses at once during a Fill started by the timer: the balls keep their handlers, the press stops the
//        fill; the replay must play these presses too)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { writeFileSync, readFileSync } from 'node:fs'
import { WORK } from '../../harness/paths.mjs'
let rs = +(process.argv[2] || 1)
const speed = +(process.argv[3] || 8)
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = HOST + '/game.html?game=logico&cls=GameLogicO&seed=' + (process.env.SEED || '123') + (process.env.EXTRA || '')
const PORT = +(process.env.PORT || 9862)
const SHOTS = process.env.SHOTS
const DUMB = +(process.env.DUMB || 6)
const TOUCH = !!process.env.TOUCH
const FILL = !!process.env.FILL
let b = await launch(PORT)
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 })
const touch = (type, x, y) => b.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x: 8 + x, y: 8 + y }] })
const STATE = `(() => { const g = kk.game; if (!g || !g.balls) return null
  return { over: !!window.__over, step: g.step ? g.step._hx_name : null, frame: g.frameCount,
    balls: g.balls.map(b => ({ c: b.col, x: b.root._x, y: b.root._y, on: !!b.root.onPress })) } })()`
// groups of the ring (Game.buildGroups on a circular list): the longest run of one colour after a move, and the
// number of balls in runs of 4 or more
function runs(cols) {
  const n = cols.length
  let start = 0
  while (start < n && cols[start] === cols[(start + n - 1) % n]) start++
  if (start === n) return { best: n, big: n >= 4 ? n : 0 }
  let best = 0, big = 0, len = 0, sq = 0
  for (let k = 0; k < n; k++) {
    const i = (start + k) % n
    if (k > 0 && cols[i] === cols[(i + n - 1) % n]) len++
    else { if (len >= 4) big += len; sq += len * len; len = 1 }
    best = Math.max(best, len)
  }
  if (len >= 4) big += len
  sq += len * len
  return { best, big, sq }
}
// Game.select (MODE 0): the ball leaves its place and is inserted on the other side
function moved(cols, id) {
  const max = cols.length
  let id2 = (id + Math.ceil(max * 0.5)) % max
  const a = cols.slice(), [c] = a.splice(id, 1)
  if (id2 > id) id2--
  a.splice(id2, 0, c)
  return a
}
function choose(balls) {
  const cols = balls.map(b => b.c)
  let best = null
  for (let i = 0; i < cols.length; i++) {
    const r = runs(moved(cols, i))
    const score = r.big * 100 + (r.sq || 0) + rnd(3)
    if (!best || score > best.score) best = { i, score, big: r.big }
  }
  return best
}
// PERF=1: shader programs compiled, textures uploaded and browser frames longer than 25 ms (from the Electrolink bot)
const PERF_INIT = `(() => {
  const S = kk.renderer.shader, gen = S.generateShader.bind(S)
  window.__progs = []; S.generateShader = function (sh) { __progs.push(sh.program.name || '?'); return gen(sh) }
  window.__ups = []; const gl = kk.renderer.gl
  for (const fn of ['texImage2D', 'texSubImage2D']) { const o = gl[fn].bind(gl)
    gl[fn] = function (...a) { const t = performance.now(), r = o(...a), src = a[a.length - 1]
      __ups.push([+(performance.now() - t).toFixed(2), src && src.width ? src.width + 'x' + src.height : '?']); return r } }
  window.__long = []; let last = performance.now()
  const tick = () => { const n = performance.now(); if (n - last > 25) __long.push([+(n - last).toFixed(1), kk.game && kk.game.frameCount, kk.game && kk.game.step && kk.game.step._hx_name]); last = n; if (!window.__over) requestAnimationFrame(tick) }
  requestAnimationFrame(tick); return true })()`
const PERF_REPORT = `JSON.stringify({ shaders: __progs, uploads: __ups.length, uploadMsMax: Math.max(0, ...__ups.map(u => u[0])), sizes: [...new Set(__ups.map(u => u[1]))].slice(0, 8), longFrames: __long.length, longest: __long.sort((a, b) => b[0] - a[0]).slice(0, 6) })`
let pos = [300, 300]
async function moveTo(tx, ty) {
  if (TOUCH) { pos = [tx, ty]; return }
  const [sx, sy] = pos, n = 5 + rnd(8)
  for (let i = 1; i <= n; i++) {
    const t = i / n, e = t * t * (3 - 2 * t)
    pos = [Math.round(sx + (tx - sx) * e + rnd(3) - 1), Math.round(sy + (ty - sy) * e + rnd(3) - 1)]
    await mouse('mouseMoved', pos[0], pos[1]); await b.sleep(12)
  }
}
const stats = { fillMoves: 0, moves: 0, combos: 0, random: 0, waits: 0 }
let data, liveOver, t = 0, idle = 0, waitFill = false
// assignedNames of resources/js/games/builds/bundle.mjs (its module imports esbuild)
function assignedNames(code) {
  const STATIC_DEFINITION = /^[\w$]+\.[\w$]+ = /, names = new Set()
  for (const line of code.split('\n')) {
    const member = STATIC_DEFINITION.test(line) ? line.replace(STATIC_DEFINITION, '') : line
    for (const m of member.matchAll(/(?<!\.prototype)\.([A-Za-z_$][\w$]*)\s*=(?!=)/g)) names.add(m[1])
    for (const m of member.matchAll(/\["([A-Za-z_$][\w$]*)"\]\s*=(?!=)/g)) names.add(m[1])
    for (const m of member.matchAll(/setField\([^,]+,\s*"([A-Za-z_$][\w$]*)"/g)) names.add(m[1])
  }
  return [...names].sort()
}
try {
  if (process.env.FREEZE) {
    const names = assignedNames(readFileSync(WORK + '/build/src/logico.js', 'utf8'))
    await b.send('Page.addScriptToEvaluateOnNewDocument', { source: 'window.__kadoAssignedNames = ' + JSON.stringify(names) })
  }
  await b.goto(URL0)
  if (TOUCH) await b.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 })
  await b.waitFor('!!(window.kk && kk.game && kk.game.balls)', 60000)
  if (process.env.FREEZE) console.log('frozen', await b.eval('Object.isFrozen(Object.getPrototypeOf(kk.game.balls[0])) && Object.isFrozen(Object.getPrototypeOf(kk.game.balls[0].root))'))
  if (process.env.PERF) await b.eval(PERF_INIT)
  let shot = 0
  for (; ; t++) {
    const s = await b.eval(STATE)
    if (!s || s.over) break
    if (SHOTS && t % 10 === 0 && shot < 40) await b.screenshot(SHOTS + '/l' + String(shot++).padStart(2, '0') + '.png', { x: 8, y: 8, width: 600, height: 640 })
    const fillBall = FILL && s.step === 'Fill' ? s.balls.findIndex(b => b.on) : -1
    if (fillBall >= 0) {
      // a press at once on a ball that kept its handlers (the fill lasts a few frames)
      const bl = s.balls[fillBall]
      pos = [2 * bl.x, 2 * bl.y]
      await mouse('mouseMoved', pos[0], pos[1]); await b.sleep(10)
      await mouse('mousePressed', pos[0], pos[1], 1); await b.sleep(20); await mouse('mouseReleased', pos[0], pos[1])
      stats.fillMoves++
      waitFill = false
      continue
    }
    if (s.step !== 'Play' || !s.balls.length || !s.balls[0].on) {
      if (++idle > 3000) { console.log('STUCK', s.step); break }
      // wandering while the balls move (no handlers: no glow)
      if (!TOUCH && rnd(4) === 0) await moveTo(pos[0] + rnd(41) - 20, pos[1] + rnd(41) - 20)
      await b.sleep(30)
      stats.waits++
      continue
    }
    idle = 0
    // FILL: one move in 3, the bot waits in Play until the timer empties the pool
    if (FILL && s.step === 'Play' && (waitFill || rnd(3) === 0)) {
      waitFill = true
      await b.sleep(30)
      continue
    }
    let c = rnd(DUMB) === 0 ? null : choose(s.balls)
    if (!c) { c = { i: rnd(s.balls.length), big: 0 }; stats.random++ }
    if (c.big) stats.combos++
    const bl = s.balls[c.i]
    // somewhere on the ball (radius 16 Flash pixels), in canvas pixels
    const x = 2 * bl.x + rnd(17) - 8, y = 2 * bl.y + rnd(17) - 8
    await moveTo(x, y)
    await b.sleep(30 + rnd(150))
    if (TOUCH) {
      await touch('touchStart', x, y); await b.sleep(30 + rnd(60)); await touch('touchEnd', x, y)
    } else {
      await mouse('mousePressed', pos[0], pos[1], 1); await b.sleep(20 + rnd(60)); await mouse('mouseReleased', pos[0], pos[1])
    }
    stats.moves++
    await b.sleep(100 + rnd(100))
  }
  await b.waitFor('!!window.__over', 120000)
  if (process.env.PERF) console.log('perf', await b.eval(PERF_REPORT))
  await b.waitFor('!!(window.__logs.find(l => l.includes("Replay data:")))', 60000)
  liveOver = await b.eval('JSON.stringify(window.__over)')
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  console.log('live', liveOver, JSON.stringify(stats), 'replay chars', data.length)
  writeFileSync(gameDir('logico', 'replays') + '/l_replay_' + process.argv[2] + (TOUCH ? 't' : '') + '.txt', data + '\n' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
b = await launch(PORT + 50)
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.balls)', 60000)
  await b.eval(`kk.setReplaySpeed(${speed})`)
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver ? 'MATCH' : 'MISMATCH')
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
