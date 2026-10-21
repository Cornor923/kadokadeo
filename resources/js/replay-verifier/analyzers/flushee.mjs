// Analyzer of Flushee for the replay verifier (see README of this folder): each move of the player (a gem pushed into a
// row from a side) against the 14 moves he could play on the board he saw (flushee/solver.mjs). Everything a move
// scores is certain from the board (the new gems only come after the last wave), but the waves are hard to see: the
// whole row shifts, the gems fall, the groups they make count double, triple... A script of the page that computes
// the 14 moves and shows the best one is followed every time; a player, even the best ones, plays the best move a
// third of the time (three quarters at most on a run). Same two moves ahead (the gem pushed out is the next one in hand):
// a helper that looks further plays its best every time, players an eighth of the time.
// Luck (the new gems, the bonus gems they bring) is not judged: the analyzer only sees the choice among the 14 moves.
import { CELLS, HEIGHT, moveIndex, rateDecision, rateMoves, UNKNOWN, WIDTH } from './flushee/solver.mjs'

export const meta = { game: 'flushee', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 10
  const optimalRateLimit = config.optimal_rate ?? 0.95
  // the same, two moves ahead (the gem pushed out is the next one in hand): a helper that looks one move further
  const lookaheadRateLimit = config.lookahead_rate ?? 0.95

  // the board while the game waits for a click (Game.lock and Game.wait_fall false, Game.onClick), and since when
  let seen = null
  let waitingSince = null
  let lastMoves = null
  // the points the rules give the moves played (Game.combo_score), checked against Game.scores
  const expected = []
  const stats = { moves: 0, decisions: 0, optimal: 0, value: 0, best: 0, lookahead: 0, lookaheadOptimal: 0, unread: 0, simulationErrors: 0 }
  const decisionFrames = []

  const readGrid = (game) => {
    const grid = new Array(CELLS)
    for (let x = 0; x < WIDTH; x++) {
      const column = game.gems[x]
      if (!Array.isArray(column)) throw new Error('unsupported build')
      for (let y = 0; y < HEIGHT; y++) {
        const gem = column[y]
        grid[x * HEIGHT + y] = gem && typeof gem.id === 'number' ? gem.id : UNKNOWN
      }
    }
    return grid
  }

  // the move played: where the gem in hand is now (Game.onClick put it at x = 0 from the left, x = 5 from the right)
  const movePlayed = (game, gem) => {
    for (let y = 0; y < HEIGHT; y++) {
      if (game.gems[0][y] === gem) return moveIndex(true, y)
      if (game.gems[WIDTH - 1][y] === gem) return moveIndex(false, y)
    }
    return null
  }

  return {
    // before the frame: a move played during the frame before (Game.onClick counts it in tottokens) is rated on the
    // board kept while the game waited for the click
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      if (!Array.isArray(game.gems) || !Array.isArray(game.scores) || typeof game.tottokens !== 'number' || typeof game.tokens !== 'number') {
        throw new Error('unsupported build')
      }

      while (expected.length && expected[0].move < game.scores.length) {
        const { move, points } = expected.shift()
        if (game.scores[move] !== points) stats.simulationErrors++
      }

      const moves = game.tottokens
      if (lastMoves !== null && moves > lastMoves) {
        stats.moves++
        const played = seen ? movePlayed(game, seen.gem) : null
        if (played === null) {
          stats.unread++
        } else {
          const rating = rateDecision(seen.grid, seen.cur, seen.tokens, played)
          expected.push({ move: lastMoves, points: rating.wavePoints[played] })
          if (rating.counted) {
            stats.decisions++
            if (rating.optimal) stats.optimal++
            stats.value += rating.value
            stats.best += rating.best
            decisionFrames.push(frame - 1 - waitingSince)
            const ahead = rateMoves(seen.grid, seen.cur, 2, seen.tokens).map((m) => m.value)
            const bestAhead = Math.max(...ahead)
            if (bestAhead > Math.min(...ahead)) {
              stats.lookahead++
              if (ahead[played] === bestAhead) stats.lookaheadOptimal++
            }
          }
        }
        seen = null
      }
      lastMoves = moves

      if (!game.lock && !game.wait_fall && game.cur) {
        if (waitingSince === null) waitingSince = frame
        // read again every frame it waits (42 ids): the board the click is applied to
        seen = { grid: readGrid(game), cur: game.cur.id, gem: game.cur, tokens: game.tokens }
      } else {
        waitingSince = null
        seen = null
      }
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n, d) => (d ? +(n / d).toFixed(3) : null)
      const metrics = {
        moves: stats.moves,
        decisions: stats.decisions,
        optimal: stats.optimal,
        optimalRate: rate(stats.optimal, stats.decisions),
        // the points of the moves played against the points of the best moves
        valueRate: rate(stats.value, stats.best),
        // two moves ahead: the best certain points of this move and the next one (the gem pushed out)
        lookaheadDecisions: stats.lookahead,
        lookaheadRate: rate(stats.lookaheadOptimal, stats.lookahead),
        // moves the rules of the solver score differently from the game (should be 0: else the analysis says nothing)
        simulationErrors: stats.simulationErrors,
        unreadMoves: stats.unread,
        // frames between the board shown and the click (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.simulationErrors === 0) {
        if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
          reasons.push(`meilleur coup ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} coups, limite ${Math.round(optimalRateLimit * 100)} %)`)
        }
        if (stats.lookahead >= minDecisions && metrics.lookaheadRate >= lookaheadRateLimit) {
          reasons.push(`meilleur coup à 2 coups d'avance ${Math.round(metrics.lookaheadRate * 100)} % du temps (${stats.lookahead} coups, limite ${Math.round(lookaheadRateLimit * 100)} %)`)
        }
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
