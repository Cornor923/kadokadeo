// NosuShi test modes (see game.html, with h=500: the canvas of an Arkadeo game). They only patch the game from its
// counters and the url: the same in the live game and in its replay.
// ns: bonus=<N> every Nth bonus draw of a new block (RandList.draw: rand(1423)) is a bonus, in turn a dynamite, a bomb,
//     an aspirin, a x2 (the draw of the game is made anyway, its result replaced: the random stays the same), so the
//     bombs, the dynamites, the plates won and the x2 come often; frames=<N> no plate left from that frame of the game on
//     (the end of the game: Game.checkEnd)
TEST_MODES.ns = (P, q) => {
  const N = +(q.get('frames') || 0), bonus = +(q.get('bonus') || 0)
  // first value of each bonus in the draw of RandList (probas 1400, 5, 5, 3, 10)
  const FIRST = [1400, 1405, 1410, 1413]
  const rand = P.rand
  P.rand = function (n) {
    const v = rand.call(this, n)
    if (bonus && n === 1423) {
      this.__draws = (this.__draws || 0) + 1
      if (this.__draws % bonus === 0) return FIRST[Math.floor(this.__draws / bonus) % 4]
    }
    return v
  }
  const orig = P.update
  P.update = function (d) {
    orig.call(this, d)
    if (N && this.getFrame() >= N && this.leftPlay > 0) {
      this.leftPlay = 0
      // waiting for a click (S_Play): the end now (setStep(S_Play) -> checkEnd -> S_End)
      if (this.step._hx_index === 1) this.setStep(this.step)
    }
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.nosushi = (g) => (g.grid ? [g.endState()] : null)
