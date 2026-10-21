// Analyzer of Aqua Splash for the replay verifier (see README of this folder): each click of the player against every
// click he could have made on the board he saw, valued by aquasplash/solver.mjs (the chains of drops simulated Flash
// frame by Flash frame, one and two moves ahead). A player helped by a solver (a script showing the click that starts
// the longest chain) plays a best move every time; a player misses one now and then: chains are long, a 3 needs two
// drops, a drop may fly through a slime that exploded just before. The board is entirely visible (no hidden
// information): only the rate of best moves on the decisions that discriminate is watched.
import { boardString, CELLS, H, makeBoard, rateMove } from './aquasplash/solver.mjs'

export const meta = { game: 'aquasplash', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)
const ratio = (a, b) => (b ? +(a / b).toFixed(3) : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 25
  const optimalRateLimit = config.optimal_rate ?? 0.97
  // the simulation must give what the game did (a build whose rules changed: no verdict)
  const maxMismatchRate = config.max_mismatch_rate ?? 0.1
  // tests / calibration: every click in metrics.trace
  const trace = config.trace ? [] : null

  // the board the game shows (Game.allSlimes), read while the game waits for a click
  const readBoard = (game) => {
    const list = game.allSlimes
    if (!Array.isArray(list)) throw new Error('unsupported build')
    if (list.length !== CELLS) return null
    const grow = new Array(CELLS).fill(0)
    const bonus = new Array(CELLS).fill(0)
    const goute = new Array(CELLS).fill(0)
    for (const s of list) {
      if (!s || !s.pos || typeof s.grow !== 'number' || !s.mc) throw new Error('unsupported build')
      const i = s.pos.x * H + s.pos.y
      grow[i] = s.grow
      bonus[i] = s.bonus ? 1 : 0
      // SlimeMC.goute: the picture of the goute the clip plays (a slime just grown is bigger for a few frames)
      goute[i] = typeof s.mc.goute === 'number' ? s.mc.goute : 0
    }
    return makeBoard(grow, bonus, goute)
  }

  let board = null
  let plays = null
  let waitingSince = null
  // the click being played: its simulated outcome, checked against the game when it waits again
  let pending = null
  const stats = { moves: 0, decisions: 0, optimal: 0, optimal1: 0, optimal2: 0, explosions: 0, bestExplosions: 0, checked: 0, mismatch: 0 }
  const decisionFrames = []

  return {
    // before the frame: a click during the frame before (Slime.touch: Game.downPlay) is rated on the board seen then
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.step) return
      if (typeof game.plays !== 'number' || typeof game.lockSlime !== 'boolean') throw new Error('unsupported build')
      const step = game.step._hx_name

      if (plays !== null && game.plays < plays && board) {
        // the slime clicked stays the button under the pointer (Game.updateMouse)
        const target = game.hovered && game.hovered.slime
        if (!target || !target.pos) throw new Error('unsupported build')
        const cell = target.pos.x * H + target.pos.y
        stats.moves++
        const rating = rateMove(board, plays, cell)
        if (rating) {
          pending = { outcome: rating.outcome, explosions: 0 }
          if (rating.counted) {
            stats.decisions++
            if (rating.optimal) stats.optimal++
            if (rating.optimal1) stats.optimal1++
            if (rating.optimal2) stats.optimal2++
            stats.explosions += rating.explosions
            stats.bestExplosions += rating.bestExplosions
            decisionFrames.push(frame - 1 - waitingSince)
          }
          if (trace) {
            trace.push({
              f: frame - 1,
              t: frame - 1 - waitingSince,
              b: boardString(board.grow, board.bonus),
              p: plays,
              m: cell,
              c: rating.counted ? 1 : 0,
              o: [rating.optimal1 ? 1 : 0, rating.optimal2 ? 1 : 0],
              v: [rating.value, rating.best],
              e: [rating.explosions, rating.bestExplosions],
            })
          }
        }
        board = null
        waitingSince = null
      }
      plays = game.plays

      if (pending) pending.explosions = Math.max(pending.explosions, game.explosion | 0)
      const waiting = step === 'Play' && !game.lockSlime && !game.flGameOver
      if (pending && (waiting || step === 'NextLevel' || game.flGameOver)) {
        // the chain is over (Game.setPlay): the simulation against what the game did
        const o = pending.outcome
        let same = pending.explosions === o.explosions && (step === 'NextLevel') === o.level
        if (same && step !== 'NextLevel') {
          const now = readBoard(game)
          if (now) for (let i = 0; i < CELLS; i++) if (Math.max(now.grow[i], 0) !== Math.max(o.grow[i], 0)) same = false
        }
        stats.checked++
        if (!same) {
          stats.mismatch++
          if (trace && trace.length) trace[trace.length - 1].mismatch = 1
        }
        pending = null
      }
      if (waiting) {
        if (waitingSince === null) waitingSince = frame
        board = readBoard(game)
      } else {
        board = null
      }
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const metrics = {
        // the clicks that discriminate (a chain at stake, most slimes not a best move) and the best ones among them
        decisions: stats.decisions,
        optimal: stats.optimal,
        optimalRate: ratio(stats.optimal, stats.decisions),
        // the best move looking one move ahead (the longest chain now) / two moves ahead (a slime grown for later)
        optimal1Rate: ratio(stats.optimal1, stats.decisions),
        optimal2Rate: ratio(stats.optimal2, stats.decisions),
        // the explosions of the chains started against the ones of the longest chains
        valueRate: ratio(stats.explosions, stats.bestExplosions),
        moves: stats.moves,
        // the clicks whose simulated chain was checked against the game, and the ones that differed
        simChecked: stats.checked,
        simMismatch: stats.mismatch,
        // frames between the board shown and the click (32 by second), on the decisions counted
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      if (trace) metrics.trace = trace
      const reasons = []
      const reliable = stats.mismatch <= maxMismatchRate * stats.checked
      if (reliable && stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`meilleur coup ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
