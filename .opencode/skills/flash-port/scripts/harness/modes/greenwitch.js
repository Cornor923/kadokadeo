// Green Witch: test modes. A test mode must do exactly the same thing in the live game and in its replay: only the frame
// counter of the game and the url decide.
//   test=gw  inv=1      the witch never dies and keeps her ammunition and turrets (refilled before each step)
//            spawn=<n>  every n frames of the game, monsters near the witch (Game.testSpawn: Bleuarg, Bomber, then also
//                       Kamikaze, Ghost, FireCannon every other time, a Spawner each: their spawn effects)
//            kill=<n>   every n frames, every monster hit to death (death effects, gold, points)
//            dif=<d>    the difficulty from the start (the League raises it with the time: the monsters it brings back)
//            frames=<n> game over at that frame of the game, through the game's own end (Play.endGame)
//            hold=<n>   from that frame of the game, the game is not played any more and shown as it is (screenshots of a
//                       given frame: the same picture in two builds)
TEST_MODES.gw = (P, q) => {
  const orig = P.update
  const inv = q.get('inv') === '1', spawn = +(q.get('spawn') || 0), kill = +(q.get('kill') || 0)
  const dif = +(q.get('dif') || 0), N = +(q.get('frames') || 0), hold = +(q.get('hold') || 0)
  const KINDS = ['bleuarg', 'bomber', 'kamikaze', 'ghost', 'firecannon']
  P.update = function (d) {
    const play = this.testPlay()
    if (play && play.hero) {
      if (!this.__init) {
        this.__init = true
        if (dif) play.difficulty = dif
      }
      if (inv) {
        play.hero.life = 999
        play.hero.ammo = Math.max(play.hero.ammo, 50)
        play.hero.turrets = Math.max(play.hero.turrets, 3)
      }
      // (once per frame of the game: a step of KadoKadeo plays 0 to 2 of them)
      const f = this.frameCount
      const fresh = f !== this.__lastFrame
      this.__lastFrame = f
      if (fresh && spawn && f > 0 && f % spawn === 0) {
        const k = (f / spawn) | 0
        this.testSpawn(KINDS[0]); this.testSpawn(KINDS[1])
        if (k % 2 === 0) for (const n of KINDS.slice(2)) this.testSpawn(n)
      }
      if (fresh && kill && f > 0 && f % kill === 0) this.testKillAll()
      if (N && f >= N && !this.over && play.endGame) play.endGame(false)
    }
    // (no frame of the game in this step, shown at the frame reached)
    if (hold && this.frameCount >= hold) this.frameAcc = 0
    orig.call(this, d)
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.greenwitch = (g) => g.debugState()
