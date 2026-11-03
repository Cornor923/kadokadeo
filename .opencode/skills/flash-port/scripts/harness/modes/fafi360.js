// Fafi 360: test modes. A test mode must do exactly the same thing in the live game and in its replay: only the frame
// counter of the game and the url decide.
//   test=fafi  frames=<the end of the match at that frame of the game: the chrono at 0, the game's own end (endLeague
//                      when the ball has an owner, the stats, the bonus of the goals)>
//              goals=<every that many frames of the game while playing, a goal of the player (Game.goal: the opponent
//                     gets a player, obstacles, mines, skill at 3 and 9 goals, GoalJump at 7)>
//              concede=<every that many frames, a goal of the opponent>
//              bonus=<every that many frames, a big bonus near the ball (Game.testBonus: bottles 3 to 7)>
//              chrono=<every that many frames, a chrono (+20 s) near the ball>
//              mine=<every that many frames, a mine under the ball (its explosion, its marks drawn on the ground)>
TEST_MODES.fafi = (P, q) => {
  const orig = P.update
  const N = +(q.get('frames') || 0), goals = +(q.get('goals') || 0), concede = +(q.get('concede') || 0), bonus = +(q.get('bonus') || 0)
  const chrono = +(q.get('chrono') || 0), mine = +(q.get('mine') || 0)
  P.update = function (d) {
    const f0 = this.frameCount
    orig.call(this, d)
    const f = this.frameCount
    // (the frames of the game played by this step: 0, 1 or 2)
    const hit = (n) => n && Math.floor(f / n) > Math.floor(f0 / n)
    const s = this.botState()
    if (s.playing && !s.ended) {
      if (hit(goals)) this.goal(true)
      else if (hit(concede)) this.goal(false)
      if (hit(bonus)) this.testBonus(true)
      if (hit(chrono)) this.testBonus(false)
      if (hit(mine)) this.testMine()
    }
    if (N && f >= N && this.chrono > 0) this.chrono = 0
  }
}

// fp=1 (game.html, fp.mjs): the gameplay state after each step
FP_STATE.fafi360 = (g) => g.ball ? [g.debugState(), g.botState()] : null
