// Analyzer of Razor for the replay verifier (see README of this folder): each slice of the player against the slices
// he could make from the board he saw (razor/solver.mjs). The whole game is choosing where to slice: the game cuts the
// longest path of the colour from the fruit in front of the razor, and its points grow with the square of the path.
// A script reading the board (the same getPath on the 24 places) shows the longest one every time; a player sees the
// big groups but often starts from a cell that gives a shorter path, or takes a near one. Only the choices between
// close candidates count (an obvious biggest group is taken by everybody). A smarter script looks one slice ahead (the
// fruits fall toward the razor: a small slice can join two groups for the next one): lookaheadRate. There is no hidden
// information to watch: the fruits to come are random (stirred by the inputs), unknown to a script as to the player.
import { getPath, PIOUPIOU, placeIndex, PLACES, rateSlice, ringDistance, SIDE, UNKNOWN } from './razor/solver.mjs'

export const meta = { game: 'razor', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  // provisional defaults (no replay of a real player yet, set on bots only): a whole game has about 13 slices of a
  // fruit, 8 to 13 of them close choices; flagged only when every close choice is the longest path, or nearly every
  // one the best two slices ahead
  const minDecisions = config.min_decisions ?? 11
  const optimalRateLimit = config.optimal_rate ?? 1
  // (null: not used)
  const lookaheadRateLimit = config.lookahead_rate === undefined ? 0.9 : config.lookahead_rate
  const closeRatio = config.close_ratio ?? 0.6
  const maxDepth = Math.max(1, Math.min(config.max_depth ?? 2, 3))

  let step = null
  // the frame the board was shown (the game waits for the player: Play after a spawn), the razor's place then, the
  // frames the razor stood still and the presses since
  let readyFrame = null
  let readyPlace = -1
  let stillFrames = 0
  let moves = 0
  let lastCell = null
  const stats = {
    slices: 0,
    allOptimal: 0,
    decisions: 0,
    optimal: 0,
    lookaheadOptimal: 0,
    value: 0,
    best: 0,
    free: 0,
    early: 0,
    direct: 0,
    mismatches: 0,
  }
  const decisionFrames = []
  const stillFramesList = []

  const readGrid = (game) => {
    const grid = []
    for (let x = 0; x < SIDE; x++) {
      for (let y = 0; y < SIDE; y++) {
        const ball = game.grid[x] ? game.grid[x][y] : null
        grid.push(ball && ball.col != null ? ball.col : UNKNOWN)
      }
    }
    return grid
  }

  // the slice begun during the frame before: the board is still whole (the first fruit falls after a few frames),
  // work is the path the game chose, limits already counts it
  const rate = (game, frame) => {
    const work = game.work
    if (!Array.isArray(work) || !work.length || !Array.isArray(game.limits)) throw new Error('unsupported build')
    const first = work[0]
    const place = placeIndex(game.rx, game.ry, game.bdir)
    const grid = readGrid(game)
    if (place < 0 || PLACES[place].target !== first.x * SIDE + first.y || grid[PLACES[place].target] !== first.col) {
      stats.mismatches++
      return
    }
    if (first.col === PIOUPIOU) {
      stats.free++
      return
    }
    const limits = [0, 1, 2].map((c) => +game.limits[c] || 0)
    limits[first.col]--
    const path = getPath(grid, PLACES[place].target)
    if (!path || path.length !== work.length) {
      stats.mismatches++
      return
    }
    const rating = rateSlice(grid, limits, place, { depth: maxDepth, closeRatio })
    if (!rating) {
      stats.mismatches++
      return
    }
    if (rating.early) {
      stats.early++
      return
    }
    stats.slices++
    if (rating.optimal) stats.allOptimal++
    if (!rating.close) return
    stats.decisions++
    if (rating.optimal) stats.optimal++
    if (rating.lookaheadOptimal) stats.lookaheadOptimal++
    stats.value += rating.value
    stats.best += rating.best
    if (readyFrame !== null) {
      decisionFrames.push(frame - 1 - readyFrame)
      stillFramesList.push(stillFrames)
      if (readyPlace >= 0 && moves === ringDistance(readyPlace, place)) stats.direct++
    }
  }

  return {
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.step) return
      if (!Array.isArray(game.grid) || typeof game.step._hx_name !== 'string') throw new Error('unsupported build')
      const name = game.step._hx_name
      const previous = step
      step = name
      if (name === 'Slice' && previous !== 'Slice') {
        rate(game, frame)
        readyFrame = null
      } else if (name === 'Play' && previous !== 'Play' && previous !== 'Move') {
        // the board after a spawn (or the first one): what the player decides on
        readyFrame = frame
        readyPlace = placeIndex(game.rx, game.ry, game.bdir)
        stillFrames = 0
        moves = 0
      }
      // a press moves the razor one place (rx, ry change when it arrives; a key held walks on without a Play frame)
      const cell = game.rx + ',' + game.ry
      if (readyFrame !== null) {
        if (name === 'Play') stillFrames++
        if (lastCell !== null && cell !== lastCell) moves++
      }
      lastCell = cell
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const still = stillFramesList.slice().sort((a, b) => a - b)
      const ratio = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const metrics = {
        // slices of a fruit between close candidates (the ones that tell a player from a solver)
        decisions: stats.decisions,
        optimal: stats.optimal,
        // the slice played makes as many points as the best one of the board
        optimalRate: ratio(stats.optimal, stats.decisions),
        // the points of the slices played against the best ones
        valueRate: ratio(stats.value, stats.best),
        // the best looking maxDepth - 1 slices ahead (the fruits to come unknown), on the same decisions
        lookaheadRate: maxDepth > 1 ? ratio(stats.lookaheadOptimal, stats.decisions) : null,
        // every slice of a fruit (obvious choices too), and their rate of best slices
        slices: stats.slices,
        allOptimalRate: ratio(stats.allOptimal, stats.slices),
        // slices from a Pioupiou (free), slices ending the game while others did not, slices not understood
        freeSlices: stats.free,
        earlySlices: stats.early,
        mismatches: stats.mismatches,
        // the razor walked straight (fewest presses) from where it stood to the slice
        directRate: ratio(stats.direct, decisionFrames.length),
        // frames between the board shown and the slice (32 by second), walking included
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
        // frames the razor stood still before the slice (looking at the board)
        medianStillFrames: median(still),
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`meilleure coupe ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} choix serrés, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      if (lookaheadRateLimit != null && stats.decisions >= minDecisions && metrics.lookaheadRate != null && metrics.lookaheadRate >= lookaheadRateLimit) {
        reasons.push(`meilleure coupe en prévoyant ${maxDepth === 2 ? 'la suivante' : `les ${maxDepth - 1} suivantes`} ${Math.round(metrics.lookaheadRate * 100)} % du temps (${stats.decisions} choix serrés, limite ${Math.round(lookaheadRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
