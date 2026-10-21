// Analyzer of Paradice for the replay verifier (see README of this folder): each turn of the row of penguins against
// the other turns of the board the player saw (paradice/solver.mjs). Everything a move makes is visible (the frozen
// balls show their colour), so a script can try the 10 turns of the row and show the one that makes the most points,
// chains of explosions included. Counted: the boards where several turns score, not the same points (a choice); a
// player takes a group he sees, not always the biggest total (two groups at once, a chain, a frozen ball freed), a
// solver always. Not counted: the boards where nothing scores or one way only (every player finds it), the specials
// (flame thrower, bomb, grenades). The balls of the next turns are random (stirred by the inputs): nobody can plan for
// them, a move is valued by its own points. Timing is reported, never judged.
import { EMPTY, gridOf, ICE, rateMove } from './paradice/solver.mjs'

export const meta = { game: 'paradice', version: 1 }

// Game.step: LOADING (the new balls carried, the grid still), PLAYING (Ground.control); Ground.step while playing:
// 0 waits, 1 moves the row, 2+ validated
const LOADING = 2
const PLAYING = 3

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 30
  const optimalRateLimit = config.optimal_rate ?? 0.98

  // the board and the carried balls of the turn (read while the grid does not move), the frame the row could move
  let turn = null
  const stats = { decisions: 0, optimal: 0, greedy: 0, value: 0, best: 0, chance: 0, deep: 0, deepOptimal: 0, easy: 0, easyOptimal: 0, chains: 0, specials: 0, timeouts: 0, turns: 0 }
  const decisionFrames = []

  const readTurn = (game) => {
    const ground = game.ground
    if (!Array.isArray(game.grid) || !Array.isArray(ground.bList)) throw new Error('unsupported build')
    const grid = gridOf(game.grid, (column, y) => {
      const ball = column ? column[y] : null
      if (ball == null) return EMPTY
      if (typeof ball.col !== 'number' || typeof ball.flIce !== 'boolean') throw new Error('unsupported build')
      return ball.flIce ? ICE + ball.col : ball.col
    })
    // a special (flame thrower, bomb, grenades: Ground.fill) is not valued
    const special = ground.special != null || ground.bList.some((o) => o.b == null || o.b.col == null)
    const carried = special ? [] : ground.bList.map((o) => ({ x: o.x, col: o.b.col }))
    return { grid, carried, special, start: null, timer: null }
  }

  return {
    // before the frame: the move was validated during the frame before (Ground.validate, Ground.step 0 -> 2+), the row
    // keeps its turn (Ground.dx) until the next turn
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.ground) return
      const ground = game.ground
      if (typeof game.step !== 'number' || typeof ground.step !== 'number' || typeof ground.dx !== 'number') {
        throw new Error('unsupported build')
      }
      const waiting = game.step === LOADING || (game.step === PLAYING && ground.step <= 1)
      if (turn && !waiting) {
        stats.turns++
        if (turn.special) {
          stats.specials++
        } else if (turn.carried.length) {
          const rating = rateMove(turn.grid, turn.carried, ground.dx)
          if (rating.easy) {
            stats.easy++
            if (rating.optimal) stats.easyOptimal++
          }
          if (rating.decision) {
            stats.decisions++
            if (rating.optimal) stats.optimal++
            if (rating.greedy) stats.greedy++
            if (rating.waves >= 2) stats.chains++
            stats.value += rating.value
            stats.best += rating.best
            stats.chance += rating.chance
            if (rating.deep) {
              stats.deep++
              if (rating.optimal) stats.deepOptimal++
            }
            // (Game.playTimer runs out: the timer validated, PLAY_TIMER = 180 by Flash frame of 0.8)
            if (turn.timer != null && turn.timer < 2) stats.timeouts++
            if (turn.start != null) decisionFrames.push(frame - 1 - turn.start)
          }
        }
        turn = null
      }
      if (waiting) {
        // (the grid and the carried balls do not change from the loading to the validation)
        if (!turn) turn = readTurn(game)
        if (game.step === PLAYING) {
          if (turn.start === null) turn.start = frame
          turn.timer = game.playTimer
        }
      }
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        // the turn making the most points (chains included) of the boards where several turns score
        optimalRate: rate(stats.optimal, stats.decisions),
        // the points of the moves played against the points of the best moves
        valueRate: rate(stats.value, stats.best),
        // the turn making the biggest first explosion (what a glance shows)
        greedyRate: rate(stats.greedy, stats.decisions),
        // the optimal rate of a random turn (share of the turns that are optimal): the baseline of optimalRate
        chanceRate: rate(stats.chance, stats.decisions),
        // among them, the boards whose best move needs a chain (the biggest first explosion is not the best), and how
        // often the player found it
        deepDecisions: stats.deep,
        deepOptimal: stats.deepOptimal,
        deepRate: rate(stats.deepOptimal, stats.deep),
        // the boards with one way to score (not counted above), and how often the player took it
        easyDecisions: stats.easy,
        easyRate: rate(stats.easyOptimal, stats.easy),
        chains: stats.chains,
        turns: stats.turns,
        specials: stats.specials,
        timeouts: stats.timeouts,
        // frames between the row ready to move and the validation (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`meilleur coup ${Math.round(metrics.optimalRate * 100)} % du temps quand plusieurs coups marquent (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
