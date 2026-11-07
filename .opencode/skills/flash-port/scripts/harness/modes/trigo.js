// Trigo test modes (see game.html, with h=500: the canvas of an Arkadeo game). They only patch the game from the url:
// the same in the live game and in its replay.
// tg: time=<N> the clock starts with N frames (40 a second; the original: 2400, the most the clock holds), so a game
//     ends sooner (time=600) or the late game comes sooner; colors=<N> the blocks take only the first N colours (the
//     draw of the game is made anyway, its result folded: the random stays the same), for big triangles, long combos and
//     the RainbowCombo with colors=5 still possible
//     hold=1 the game does not run by itself: a measure script plays its frames one by one (game.flashFrame(), see
//     examples/trigo/tcmp.mjs)
TEST_MODES.tg = (P, q) => {
  const C = window.GameTrigo
  const time = +(q.get('time') || 0), colors = +(q.get('colors') || 0)
  if (time) C.START_TIMER = time
  if (q.get('hold')) { P.__update = P.update; P.update = function () {} }
  if (colors) {
    const rand = P.rand
    P.rand = function (n) {
      const v = rand.call(this, n)
      return n === 5 ? v % colors : v
    }
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.trigo = (g) => (g.grid ? [g.endState()] : null)
