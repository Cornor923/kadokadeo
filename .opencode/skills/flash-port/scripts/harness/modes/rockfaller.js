// Rock Faller test modes (see game.html, with h=500: the canvas of an Arkadeo game). They only patch the game from
// counters and the url: the same in the live game and in its replay.
// rf: plays=<N> plays at the start instead of 10 (longer games: more combos, tubes, rocks), frames=N ends the game at
//     step N of KadoKadeo (window.__over)
TEST_MODES.rf = (P, q) => {
  const N = +(q.get('frames') || 0), plays = +(q.get('plays') || 0)
  const orig = P.update
  P.update = function (d) {
    if (this.__n === undefined) {
      this.__n = 0
      if (plays > this.leftPlay) this.addPlay(plays - this.leftPlay)
    }
    orig.call(this, d)
    if (++this.__n === N) this.gameOver()
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.rockfaller = (g) => (g.grid ? [g.endState(), g.waitingFx, g.falls.length, g.selected.map((s) => s.x * 10 + s.y)] : null)
