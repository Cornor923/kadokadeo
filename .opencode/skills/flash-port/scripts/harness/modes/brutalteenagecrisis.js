// Brutal Teenage Crisis: test modes. A test mode must do exactly the same thing in the live game and in its replay:
// only the frame counter of the game and the url decide.
//   test=btc  dif=<difficulty from the start: Big >= 50, Smart >= 90, Fly >= 250>  inv=1 (the hero keeps its 3 credits)
//             frames=<game over at that frame of the game, through the game's own end (Mode.gameOver)>
TEST_MODES.btc = (P, q) => {
  const orig = P.update
  const dif = +(q.get('dif') || 0), inv = q.get('inv') === '1', N = +(q.get('frames') || 0)
  P.update = function (d) {
    const m = this.mode
    if (!this.__init) {
      this.__init = true
      if (dif) m.diff = dif
    }
    if (inv && m.hero && m.hero.credits > 0 && m.hero.credits < 3) {
      m.hero.credits = 3
      m.hud.refresh()
    }
    orig.call(this, d)
    if (N && this.frameCount >= N && !this.over) m.gameOver(false)
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.brutalteenagecrisis = (g) => g.mode && g.mode.hero ? [g.debugState(), g.botState()] : null
