// Analyzer of Tubulo for the replay verifier (see README of this folder): each click of the player against the solution
// of the board he saw (tubulo/solver.mjs). The board is a "lights out" modulo 3: for each final color exactly one set
// of clicks solves it, which a solver computes at once and shows. A player peels the pluses he sees and, when they
// overlap, works the rest out by trying: on the tangled boards he clicks tubes out of the solution now and then (each
// costs him 2 more clicks), a player helped by a solver never does.
import { rateAttempt } from './tubulo/solver.mjs'

export const meta = { game: 'tubulo', version: 1 }

// Step (_hx_index): Play, Move, Anim, GameOver
const PLAY = 0
const ANIM = 2
const SIDE = 7

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 60
  const optimalRateLimit = config.optimal_rate ?? 0.95
  // the clicks that count: on a board still needing at least this many clicks (the pluses overlap)
  const minRemaining = config.min_remaining ?? 8

  let prevStep = null
  let prevBoard = null
  let lastMoves
  let solvedCount = 0
  let resetCount = 0
  let playSince = null
  // the try of the level being played: { board, clicks: [{ i, frames }] }
  let current = null
  const stats = { decisions: 0, optimal: 0, hidden: 0, clicks: 0, wrong: 0, levels: 0, resets: 0, solvedClicks: 0, solvedMin: 0, hardLevels: 0, exactHardLevels: 0 }
  const decisionFrames = []

  const readBoard = (game) => {
    const board = new Array(SIDE * SIDE)
    for (let x = 0; x < SIDE; x++) {
      for (let y = 0; y < SIDE; y++) board[x * SIDE + y] = game.grid[x][y].id
    }
    return board
  }

  const close = (solved) => {
    if (!current) return
    const { color, minClicks, clicks } = rateAttempt(current.board, current.clicks, { solved })
    for (const c of clicks) {
      stats.clicks++
      if (!c.needed) stats.wrong++
      if (c.remaining < minRemaining) continue
      stats.decisions++
      if (c.needed) {
        stats.optimal++
        if (!c.visible) stats.hidden++
      }
      decisionFrames.push(c.frames)
    }
    if (solved) {
      stats.levels++
      stats.solvedClicks += clicks.length
      stats.solvedMin += minClicks
      if (minClicks >= minRemaining) {
        stats.hardLevels++
        if (clicks.length === minClicks) stats.exactHardLevels++
      }
    }
    current = null
    return color
  }

  return {
    // before the frame: a click made during the frame before (Game.clickTube gives a new array to game.moves, the
    // clicked tube last) is rated on the board read before that frame; a level solved (stats._e) or reset (stats._r)
    // closes the try, the board shown when the game waits for a click again after an Anim opens the next one
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.step) return
      if (typeof game.step._hx_index !== 'number' || !Array.isArray(game.grid) || !game.stats || !Array.isArray(game.stats._e) || !Array.isArray(game.stats._r)) {
        throw new Error('unsupported build')
      }
      const step = game.step._hx_index
      const board = readBoard(game)
      if (lastMoves === undefined) lastMoves = game.moves ?? null
      if (game.moves && game.moves !== lastMoves) {
        lastMoves = game.moves
        const tube = game.moves[game.moves.length - 1]
        if (!tube || typeof tube.gridx !== 'number' || typeof tube.gridy !== 'number') throw new Error('unsupported build')
        if (current && prevBoard) current.clicks.push({ i: tube.gridx * SIDE + tube.gridy, frames: Math.max(0, frame - 1 - (playSince ?? frame - 1)) })
      }
      if (game.stats._e.length > solvedCount) {
        solvedCount = game.stats._e.length
        close(true)
      }
      if (game.stats._r.length > resetCount) {
        resetCount = game.stats._r.length
        stats.resets++
        close(false)
      }
      if (step === PLAY && prevStep !== PLAY) {
        playSince = frame
        // a new board (a level, or the same level after a reset)
        if (prevStep === ANIM || !current) current = { board, clicks: [] }
      }
      prevStep = step
      prevBoard = board
    },

    finish() {
      close(false)
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const metrics = {
        // clicks on a board still needing min_remaining clicks or more
        decisions: stats.decisions,
        // ... in the solution of the board (not to be undone)
        optimal: stats.optimal,
        optimalRate: rate(stats.optimal, stats.decisions),
        // the fewest clicks of the levels solved against the clicks the player made
        valueRate: rate(stats.solvedMin, stats.solvedClicks),
        // ... of them, tubes that showed no plus (the pluses overlap)
        hidden: stats.hidden,
        clicks: stats.clicks,
        wrongClicks: stats.wrong,
        levels: stats.levels,
        resets: stats.resets,
        // levels solved needing min_remaining clicks or more, and those solved with the fewest clicks
        hardLevels: stats.hardLevels,
        exactHardLevels: stats.exactHardLevels,
        // frames between the board shown (after the move before) and the click (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`clics dans la solution ${Math.round(metrics.optimalRate * 100)} % du temps sur les grilles difficiles (${stats.decisions} clics, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
