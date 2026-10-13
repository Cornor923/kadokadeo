// Analyzer of Binary for the replay verifier (see README of this folder): each move of the player against the best moves
// of the board he saw (binary/solver.mjs). A player helped by a solver (a script showing the best rotation) plays the
// best move nearly every time; a player chooses a good one, not always the best.
import { rateMove } from './binary/solver.mjs'

export const meta = { game: 'binary', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 25
  const optimalRateLimit = config.optimal_rate ?? 0.85
  const maxDepth = config.max_depth ?? 3

  // the clicks of the replay (events {k: 1, x, y}: a turn of the block at x, y) by frame
  const clicks = new Map()
  const frames = kk.replay.playFrames
  const records = kk.replay.playRecords
  if (!Array.isArray(frames) || !Array.isArray(records)) throw new Error('unsupported build')
  frames.forEach((frame, i) => {
    for (const event of records[i].events || []) {
      if (event && event.k === 1 && !clicks.has(frame)) clicks.set(frame, { x: event.x, y: event.y })
    }
  })

  let step = null
  let playStart = 0
  const stats = { decisions: 0, optimal: 0, value: 0, best: 0, comboAvailable: 0, comboTaken: 0 }
  const decisionFrames = []

  return {
    // before the frame: the board the player saw when he clicked (the click is applied during the frame)
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.step) return
      const name = game.step._hx_name
      if (name !== step) {
        step = name
        if (name === 'Play') playStart = frame
      }
      const click = clicks.get(frame)
      if (name !== 'Play' || !click || click.x < 0 || click.x > 3 || click.y < 0 || click.y > 3) return
      if (!Array.isArray(game.grid)) throw new Error('unsupported build')

      const grid = []
      for (let x = 0; x < 5; x++) {
        for (let y = 0; y < 5; y++) {
          const ball = game.grid[x][y]
          grid.push(ball && ball.color != null ? ball.color : -1)
        }
      }
      const rating = rateMove(grid, Math.min(game.miss ?? 1, maxDepth), click.x, click.y)
      if (rating.best <= 0) return
      stats.decisions++
      if (rating.optimal) stats.optimal++
      stats.value += rating.value
      stats.best += rating.best
      if (rating.comboAvailable) {
        stats.comboAvailable++
        if (rating.comboTaken) stats.comboTaken++
      }
      decisionFrames.push(frame - playStart)
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        optimalRate: stats.decisions ? +(stats.optimal / stats.decisions).toFixed(3) : null,
        // the points of the moves played against the points of the best moves
        valueRate: stats.best ? +(stats.value / stats.best).toFixed(3) : null,
        comboAvailable: stats.comboAvailable,
        comboTaken: stats.comboTaken,
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
