// Mel test modes (see game.html, with h=500: the canvas of an Arkadeo game). They only patch the game from counters
// and the url: the same in the live game and in its replay.
// mel: pw=<mask> gives powers at the start (1 double jump, 2 grips, 4 charged jump, 8 kick, 16 cancel: 31 = all),
//      inv=1 Mel cannot be hurt (godMode), nodl=1 the pulpz (deadline) never come, climb=N Mel goes one page up every
//      N Flash frames (the generation of the pages far up), frames=N ends the game at step N of KadoKadeo (window.__over)
TEST_MODES.mel = (P, q) => {
  const N = +(q.get('frames') || 0), pw = +(q.get('pw') || 0), inv = q.get('inv') === '1', nodl = q.get('nodl') === '1'
  const climb = +(q.get('climb') || 0)
  const orig = P.update
  P.update = function (d) {
    if (this.__n === undefined) {
      this.__n = 0
      if (pw) this.char.powers |= pw
    }
    if (nodl) this.level.life = -1e9
    if (inv) this.char.godMode = true
    if (climb && this.__n % climb === climb - 1) { this.char.cy -= 28; this.char.me.snap() }
    orig.call(this, d)
    if (++this.__n === N) this.gameOver()
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step (the enemies of the level: haxe.ds.List)
FP_STATE.mel = (g) => {
  if (!g.char || !g.level) return null
  const r = (v) => Math.round(v * 1e6)
  const nmys = []
  for (const l of g.level.nmyLists()) for (let n = l.h; n != null; n = n.next) {
    const e = n.item
    nmys.push([e.cx, e.cy, r(e.rx), r(e.ry), r(e.dx), r(e.dy), r(e.pv), e.mc ? r(e.mc.vx) + ':' + r(e.mc.vy) + ':' + (e.mc.parent != null) : 0])
  }
  const c = g.char
  return [g.endState(), r(c.dx), r(c.dy), c.mc ? r(c.mc.vx) + ':' + r(c.mc.vy) : 0, nmys]
}
