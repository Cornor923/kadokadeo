// Charlotte's Quest: test modes. A test mode must do exactly the same thing in the live game and in its replay: only the
// frame counter of the game and the url decide.
//   test=cq  inv=1      Charlotte never loses a life and never dies of the scrolling (Game.testInvincible)
//            dif=<d>    the difficulty from the start (the League raises it at every new pair of rooms: the enemies of the
//                       late game, Eye 4, Mosquito 7, Mine 15, Worm 19 / 23 / 28, Bee 25)
//            lvl=<n>    the level of the rooms made from now on: their theme (Castle1 < 5, Castle2 < 10, Castle3 < 15,
//                       Bubbles1 < 19, Bubbles2)
//            pow=<n>    every shot of the build at the level n (0 to 8) and the speed min(n, 5), from the start
//            uber=<n>   the Uber (the big unicorn) every n frames of the game
//            frames=<n> game over at that frame of the game, through the game's own end (Game.gameOver)
//            hold=<n>   from that frame of the game, the game is not played any more and shown as it is (screenshots of a
//                       given frame: the same picture in two builds)
//            noscroll=1 the rooms do not scroll (screenshots)
TEST_MODES.cq = (P, q) => {
  const orig = P.update
  const inv = q.get('inv') === '1', dif = +(q.get('dif') || 0), pow = q.get('pow'), uber = +(q.get('uber') || 0), lvl = +(q.get('lvl') || 0)
  const N = +(q.get('frames') || 0), hold = +(q.get('hold') || 0), noscroll = q.get('noscroll') === '1'
  P.update = function (d) {
    if (this.player) {
      if (!this.__init) {
        this.__init = true
        this.testSetup(dif, pow == null ? -1 : +pow, lvl)
        this.testNoScroll = noscroll
      }
      if (inv) this.testInvincible()
      // (once per frame of the game: a step of KadoKadeo plays 0 to 2 of them)
      const f = this.frameCount
      const fresh = f !== this.__lastFrame
      this.__lastFrame = f
      if (fresh && uber && f > 0 && f % uber === 0) this.testUber()
      if (N && f >= N && !this.ended) this.gameOver(false)
    }
    // (no frame of the game in this step, shown at the frame reached)
    if (hold && this.frameCount >= hold) this.frameAcc = 0
    orig.call(this, d)
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.charlottesquest = (g) => g.debugState()
