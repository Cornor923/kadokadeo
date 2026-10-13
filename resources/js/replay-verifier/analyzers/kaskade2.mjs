// Analyzer of Kaskade 2 for the replay verifier (see README of this folder): each group destroyed by the player against
// the best moves of the board he saw, looking a few moves ahead (kaskade2/solver.mjs). The points grow with the square
// of the group: the game is to grow groups for later, which a solver sees and a player only guesses.
import { rateMove, SIZE, UNKNOWN } from './kaskade2/solver.mjs'

export const meta = { game: 'kaskade2', version: 1 }

// Const.NCOUPS
const MOVES = 20

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 15
  const optimalRateLimit = config.optimal_rate ?? 0.9
  const maxDepth = config.max_depth ?? 3

  // the board when the game waits for a click (lock false), and the frame it began waiting
  let board = null
  let waitingSince = null
  let lastMoves = null
  const stats = { decisions: 0, optimal: 0, greedy: 0, value: 0, best: 0 }
  const decisionFrames = []

  const readBoard = (game) => {
    const grid = []
    for (let x = 0; x < SIZE; x++) {
      for (let y = 0; y < SIZE; y++) {
        const ball = game.level.billes[x][y]
        grid.push(ball && ball.id != null ? ball.id : UNKNOWN)
      }
    }
    return grid
  }

  return {
    // before the frame: a group destroyed during the frame before (Game.destroyCurrentGroup adds it to stats.d) is
    // rated on the board kept while the game waited for the click
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      if (!game.level || !Array.isArray(game.level.billes) || !game.stats || !Array.isArray(game.stats.d)) {
        throw new Error('unsupported build')
      }
      const moves = game.stats.d.length
      if (lastMoves !== null && moves > lastMoves && board) {
        const [x, y] = game.stats.d[lastMoves]
        const rating = rateMove(board, Math.min(maxDepth, MOVES - lastMoves), x, y)
        if (rating.best > 0 && rating.size > 0) {
          stats.decisions++
          if (rating.optimal) stats.optimal++
          if (rating.greedy) stats.greedy++
          stats.value += rating.value
          stats.best += rating.best
          decisionFrames.push(frame - 1 - waitingSince)
        }
        board = null
      }
      lastMoves = moves

      if (game.lock) {
        waitingSince = null
      } else if (waitingSince === null) {
        // the board does not change while the game waits
        waitingSince = frame
        board = readBoard(game)
      }
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n) => (stats.decisions ? +(n / stats.decisions).toFixed(3) : null)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        optimalRate: rate(stats.optimal),
        // the biggest group of the board (what a player does first)
        greedyRate: rate(stats.greedy),
        // the points (certain, looking ahead) of the moves played against the ones of the best moves
        valueRate: stats.best ? +(stats.value / stats.best).toFixed(3) : null,
        // frames between the board shown and the click (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`meilleur coup ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
