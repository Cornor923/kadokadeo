// Analyzer of Cooking Lili for the replay verifier (see README of this folder): each swap of the player against the
// best swaps of the board he saw (cookinglili/solver.mjs). Everything a swap gives is certain from the board (the
// groups, what falls after them, the next groups, multiplied by their round): only the new line after it is random.
// A solver sees the whole chain of every swap; a player sees the groups his swap makes, rarely what falls after them
// (the best swap is a cascade 85 % of the time). A player helped by a script showing the best swap plays it nearly every
// time; honest players, the best ones included, play it 9 % of the time (29 % at most over 1065 runs of 20+ decisions,
// 2026-10), and get 28 % of the points of the best swaps (55 % at most). value_rate catches the helper followed only
// for the big swaps. Playing the best swap every time ends the game early (20 to 30 swaps): min_decisions stays low.
import { ARMOR, EMPTY, HEI, rateMove, WID } from './cookinglili/solver.mjs'

export const meta = { game: 'cookinglili', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 20
  const optimalRateLimit = config.optimal_rate ?? 0.6
  const valueRateLimit = config.value_rate ?? 0.7

  // the board while the game waits for a swap (step Play: it does not change), the frame it began waiting, and the round
  // then (Game.onClick makes a new one: a swap, else a line added after 15 s without one, Game.updateGame)
  let step = null
  let board = null
  let waitingSince = 0
  let round = null
  const stats = { decisions: 0, optimal: 0, greedy: 0, value: 0, best: 0, hidden: 0, hiddenOptimal: 0, swaps: 0, timeouts: 0 }
  const decisionFrames = []

  // Level.map[x][y]: Token (id: its kind, fl_armor: frozen) or null
  const readBoard = (game) => {
    const map = game.level && game.level.map
    if (!Array.isArray(map) || map.length !== WID) throw new Error('unsupported build')
    const out = new Array(WID * HEI)
    for (let x = 0; x < WID; x++) {
      for (let y = 0; y < HEI; y++) {
        const token = map[x][y]
        if (token == null) {
          out[x * HEI + y] = EMPTY
        } else {
          if (typeof token.id !== 'number' || typeof token.fl_armor !== 'boolean') throw new Error('unsupported build')
          out[x * HEI + y] = token.id + (token.fl_armor ? ARMOR : 0)
        }
      }
    }
    return out
  }

  return {
    // before the frame: the click (event {k: 5}) of the frame before turned the step to Resolve, its pair in swapPair
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.step) return
      const name = game.step._hx_name
      if (name === 'Play') {
        if (step !== 'Play') {
          board = readBoard(game)
          waitingSince = frame
          round = game.currentRound
        }
      } else if (step === 'Play' && name === 'Resolve') {
        const pair = game.swapPair
        if (game.currentRound === round || !pair) {
          stats.timeouts++
        } else {
          stats.swaps++
          const move = { x: pair.x, y: pair.y, dx: pair.dx, dy: pair.dy }
          const time = frame - 1 - waitingSince
          const rating = rateMove(board, move)
          if (!rating) throw new Error('unsupported build')
          // a board where every swap that scores is worth the best, or none scores, says nothing
          if (rating.choice) {
            stats.decisions++
            if (rating.optimal) stats.optimal++
            if (rating.greedy) stats.greedy++
            if (rating.hidden) {
              stats.hidden++
              if (rating.optimal) stats.hiddenOptimal++
            }
            stats.value += rating.value
            stats.best += rating.best
            decisionFrames.push(time)
          }
        }
      }
      step = name
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        // the best swap (most points, all its rounds, among the ones that keep the game going)
        optimalRate: rate(stats.optimal, stats.decisions),
        // the points of the swaps played against the points of the best swaps
        valueRate: rate(stats.value, stats.best),
        // the swap with the biggest groups at once (what a player looks for)
        greedyRate: rate(stats.greedy, stats.decisions),
        // the decisions where the best swap scores by a cascade (no best swap has the biggest groups at once), and how
        // often the player found it
        cascadeDecisions: stats.hidden,
        cascadeOptimalRate: rate(stats.hiddenOptimal, stats.hidden),
        swaps: stats.swaps,
        // the lines added because the player made no swap for 15 s
        timeouts: stats.timeouts,
        // frames between the board shown and the click (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions) {
        if (metrics.optimalRate >= optimalRateLimit) {
          reasons.push(`meilleur échange ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
        }
        if (metrics.valueRate >= valueRateLimit) {
          reasons.push(`${Math.round(metrics.valueRate * 100)} % des points du meilleur échange (${stats.decisions} coups, limite ${Math.round(valueRateLimit * 100)} %)`)
        }
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
