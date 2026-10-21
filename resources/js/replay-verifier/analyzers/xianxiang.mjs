// Analyzer of Xian-Xiang for the replay verifier (see README of this folder): each pair removed by the player against
// the exact value of the board he saw, when it can be proven (xianxiang/solver.mjs). Every card is visible and nothing
// is random after the deal: a solver knows the best line, a player plans it. The value of a board is the bound of its
// cards (a maximum weight matching, paths aside) as soon as a line scoring it exists: true from the middle of the game
// on, where a move is then exactly optimal or not. The opening, where the paths bind and the value is unknown, is not
// rated (only the points of the run against the bound of the deal: valueRate).
// Strong players play the rated part perfectly in many runs (they see the identical cards and keep them for later): a
// perfect rate alone means little. The flag asks for a perfect rate on decisions hard enough that a typical player
// would have gone wrong several times on them (expectedErrors: sum of solver.typicalErrorRate).
import { bound, EMPTY, H, newContext, pointsOf, rateMove, typicalErrorRate, W } from './xianxiang/solver.mjs'

export const meta = { game: 'xianxiang', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 15
  const optimalRateLimit = config.optimal_rate ?? 1
  const minExpectedErrors = config.min_expected_errors ?? 6
  // boards visited by one search of a line scoring the bound (solver.perfectLine)
  const maxNodes = config.max_nodes ?? 2000

  const ctx = newContext()
  let previous = null
  let deal = null
  let lastChange = null
  const stats = { moves: 0, rated: 0, decisions: 0, optimal: 0, traps: 0, trapOptimal: 0, unknown: 0, points: 0, expectedErrors: 0 }
  const decisionFrames = []

  // Level.tbl[x][y]: a Card (its CardID in id) or null once removed; the board as cells y * 6 + x
  const readBoard = (game) => {
    const tbl = game.level.tbl
    if (!Array.isArray(tbl) || tbl.length !== W) throw new Error('unsupported build')
    const board = []
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const card = tbl[x][y]
        if (card == null) {
          board.push(EMPTY)
          continue
        }
        const id = card.id
        if (!id || typeof id.socle !== 'number' || typeof id.color !== 'number' || typeof id.symbol !== 'number') {
          throw new Error('unsupported build')
        }
        board.push(id.socle * 20 + id.color * 5 + id.symbol)
      }
    }
    return board
  }

  return {
    // before the frame: two cards removed during the frame before (Level.breakCards, both in the same frame) are rated
    // on the board kept before it, the one the player saw
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      if (!game.level) throw new Error('unsupported build')
      const board = readBoard(game)
      if (previous === null) {
        deal = board
        lastChange = frame
      } else {
        const gone = []
        for (let i = 0; i < board.length; i++) {
          if (previous[i] !== EMPTY && board[i] === EMPTY) gone.push(i)
        }
        if (gone.length === 2) {
          const [a, b] = gone
          stats.moves++
          stats.points += pointsOf(previous[a], previous[b])
          const rating = rateMove(previous, a, b, ctx, maxNodes)
          if (rating.rated) {
            stats.rated++
            if (rating.discriminating && rating.optimal === null) stats.unknown++
            else if (rating.discriminating) {
              stats.decisions++
              stats.expectedErrors += typicalErrorRate(rating)
              if (rating.optimal) stats.optimal++
              if (rating.trap) {
                stats.traps++
                if (rating.optimal) stats.trapOptimal++
              }
            }
          }
          decisionFrames.push(frame - 1 - lastChange)
        }
        if (gone.length) lastChange = frame - 1
      }
      previous = board
    },

    finish({ score }) {
      const sorted = decisionFrames.slice().sort((x, y) => x - y)
      const rate = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const dealBound = deal ? bound(deal, ctx.bounds) : null
      const metrics = {
        // the rated moves where the choice mattered (some move lost points for good), and the optimal ones
        decisions: stats.decisions,
        optimal: stats.optimal,
        optimalRate: rate(stats.optimal, stats.decisions),
        // the mistakes a typical player makes on these decisions (how hard they were)
        expectedErrors: +stats.expectedErrors.toFixed(2),
        // the decisions where a move scoring the most points of the board lost: the obvious move was wrong
        traps: stats.traps,
        trapOptimal: stats.trapOptimal,
        trapRate: rate(stats.trapOptimal, stats.traps),
        // the pairs removed, the ones on a board of known value (the others: the opening), the rated decisions the
        // search budget left open (not counted)
        moves: stats.moves,
        rated: stats.rated,
        unknown: stats.unknown,
        // the points of the run against the bound of the deal (no line scores more, often none scores it)
        dealBound,
        valueRate: dealBound ? rate(score ?? stats.points, dealBound) : null,
        // frames between two pairs removed (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit && metrics.expectedErrors >= minExpectedErrors) {
        const fr = (v) => String(v).replace('.', ',')
        reasons.push(`coup optimal ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %) sur des coups où un joueur se trompe ${fr(metrics.expectedErrors.toFixed(1))} fois en moyenne (minimum ${fr(minExpectedErrors)})`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
