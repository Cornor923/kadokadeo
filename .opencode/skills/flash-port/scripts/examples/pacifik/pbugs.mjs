// Pacifik: checks the two fixes of the original's bugs, on a game whose state is set from the page.
//  1. a fast cyan ball coming head-on to a still cyan laser (9.6 px per Flash frame, wider than the ball): destroyed?
//  2. side 1 full (test=pk&full=1), its shielded canon touched, another canon touched, the shielded one replaced, one
//     more canon added: the original put that one out of the array (l[null]), counted but never shown
// usage: HPORT=8791 PORT=9891 node pbugs.mjs
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const b = await launch(+(process.env.PORT || 9931))
const wait = (ms) => new Promise((r) => setTimeout(r, ms))

// 1. the laser
await b.goto(HOST + '/game.html?game=pacifik&cls=GamePacifik&seed=123&test=pk&ship=100000')
await b.waitFor('!!(window.kk && kk.game && kk.game.laser && kk.game.balls.length > 0)', 60000)
await b.move(8 + 300, 8 + 300)
await wait(300)
const r1 = await b.eval(`(() => {
  const g = kk.game, Ball = g.balls[0].__class__
  for (const o of g.balls) o.clean()
  g.balls.length = 0
  window.__pkConst.FIRE_CYCLE = 1e9
  g.laser.curtype = 3
  const target = g.canons2.find((c) => c && c.mc) || g.canons1.find((c) => c && c.mc)
  const o = new Ball(g, 164.6, 150, target)
  o.bonus = false; o.type = 2; o.mc.gotoAndStop(3); o.xf = -12; o.yf = 0; o.moveLeft = true
  g.balls.push(o)
  window.__ball = o
  return JSON.stringify({ laser: g.laser.mc.x, kills: g.stats.kills })
})()`)
await wait(500)
console.log('laser test, before:', r1, 'after:', await b.eval(`JSON.stringify({ kills: kk.game.stats.kills, ballX: window.__ball.mc && window.__ball.mc.x, laser: kk.game.laser.mc.x, curtype: kk.game.laser.curtype })`))

// 2. the canons
await b.goto(HOST + '/game.html?game=pacifik&cls=GamePacifik&seed=123&test=pk&full=1&ship=100000')
await b.waitFor('!!(window.kk && kk.game && kk.game.__n > 2)', 60000)
console.log('canons test:', await b.eval(`(() => {
  const g = kk.game, l = g.canons1
  const state = () => ({ count: g.canons1Count, inArray: l.filter((c) => c && !c.destroyed).length, outOfArray: l['null'] ? 1 : 0 })
  const s0 = state()
  const shielded = l.find((c) => c && c.shield > 0)
  g.touched(shielded, 0)
  g.touched(l.find((c) => c && c !== shielded && !c.destroyed), 0)
  g.addCanon(l); g.playStartAnim(l)
  const s1 = state()
  g.addCanon(l); g.playStartAnim(l)
  const s2 = state()
  return JSON.stringify({ start: s0, replaced: s1, added: s2 })
})()`))
await b.close()
