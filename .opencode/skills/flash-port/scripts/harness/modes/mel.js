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
