// Analyzer of Autrement for the replay verifier (see README of this folder): each time the player sticks blocks to the
// stamp (Stamp.action), his move against the best moves of the board he saw (autrement/solver.mjs: every position and
// turn the stamp reaches, every side where it pushes against blocks, valued by the points certain from the screen:
// bursts, falls, shaker). A script showing the best move (or playing it) takes it nearly every time; players build
// their stamp for bigger drops later and take the most points of the board 14 % of the time (median, 43 % at most on
// the local runs of the best players).
import { cell, EMPTY, MAX, rateMove } from './autrement/solver.mjs'

export const meta = { game: 'autrement', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 30
  const optimalRateLimit = config.optimal_rate ?? 0.65
  const valueRateLimit = config.value_rate ?? 0.85

  // the board and the stamp before the frame (when the stamp waits for the player), and the frame it began waiting
  let prev = null
  let readySince = null
  const stats = { attaches: 0, unmatched: 0, decisions: 0, optimal: 0, scoring: 0, value: 0, best: 0 }
  const decisionFrames = []

  const readBoard = (game) => {
    const board = new Array(MAX * MAX).fill(EMPTY)
    for (let x = 0; x < MAX; x++) {
      const column = game.bm.grid[x]
      if (!Array.isArray(column)) throw new Error('unsupported build')
      for (let y = 0; y < MAX; y++) {
        const b = column[y]
        if (b != null) board[x * MAX + y] = cell(b.id, b.option)
      }
    }
    return board
  }

  return {
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      const stamp = game.stamp
      if (!stamp || !stamp.bm || !Array.isArray(stamp.bm.list) || !game.bm || !Array.isArray(game.bm.grid)
        || typeof stamp.x !== 'number' || typeof stamp.y !== 'number' || !game.step) {
        throw new Error('unsupported build')
      }
      const list = stamp.bm.list
      const playing = !!stamp.step && stamp.step._hx_name === 'Play' && game.step._hx_name === 'Play'

      // blocks stuck to the stamp during the frame before (Stamp.action adds them at the end of its list, the stamp does
      // not move in that frame): rated on the board seen before it. A board changed in the same frame before the click
      // (Game.refill, Game.addBloc) makes a move the stamp could not make on the board kept: not rated (unmatched)
      let attached = false
      if (prev && prev.frame === frame - 1 && list.length > prev.n) {
        attached = true
        stats.attaches++
        const cells = list.slice(prev.n).map((b) => (b.x + prev.x) * MAX + b.y + prev.y)
        const rating = rateMove(prev.board, prev.stamp, prev.x, prev.y, cells)
        if (!rating) {
          stats.unmatched++
        } else if (rating.best > 0) {
          // (no points anywhere, a bare stamp after a burst: every move is equal, not a decision)
          stats.decisions++
          if (rating.optimal) stats.optimal++
          if (rating.value > 0) stats.scoring++
          stats.value += rating.value
          stats.best += rating.best
          decisionFrames.push(frame - 1 - readySince)
        }
      }

      if (!playing) readySince = null
      else if (readySince === null || attached) readySince = frame

      prev = playing
        ? { frame, n: list.length, board: readBoard(game), stamp: list.map((b) => [b.x, b.y, cell(b.id, b.option)]), x: stamp.x, y: stamp.y }
        : null
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n) => (stats.decisions ? +(n / stats.decisions).toFixed(3) : null)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        // the move with the most points of the board (certain points: bursts, falls, shaker)
        optimalRate: rate(stats.optimal),
        // the points of the moves played against the points of the best moves
        valueRate: stats.best ? +(stats.value / stats.best).toFixed(3) : null,
        // the moves with points at all (a player often sticks blocks without points to drop more later)
        scoringRate: rate(stats.scoring),
        attaches: stats.attaches,
        unmatched: stats.unmatched,
        // frames between the stamp ready (after the last move and its burst) and the move (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions) {
        if (metrics.optimalRate >= optimalRateLimit) {
          reasons.push(`meilleur coup ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
        }
        if (metrics.valueRate >= valueRateLimit) {
          reasons.push(`${Math.round(metrics.valueRate * 100)} % des points des meilleurs coups (${stats.decisions} coups, limite ${Math.round(valueRateLimit * 100)} %)`)
        }
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
