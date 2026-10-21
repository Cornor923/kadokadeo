// Analyzer of Electrolink for the replay verifier (see README of this folder): each link the player made (the clicks
// from the board shown to its explosion) against the fewest clicks that could link the two sides from that board
// (electrolink/solver.mjs). A player helped by a solver (a script showing the tiles to turn) links with the fewest
// clicks nearly every time and never turns a tile for nothing; a player under the clock finds a link, often not the
// cheapest one, and turns some tiles too much or for nothing.
import { CROSS, HEIGHT, isConnected, minConnection, neededClicks, pipes, WIDTH } from './electrolink/solver.mjs'

export const meta = { game: 'electrolink', version: 1 }

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)
const mean = (list) => (list.length ? Math.round(list.reduce((s, v) => s + v, 0) / list.length) : null)

export function create({ kk, config = {} }) {
  // provisional defaults (no production replay yet): bots following the solver 100 %, bots planning like a strong
  // player 60-70 %
  const minDecisions = config.min_decisions ?? 20
  const optimalRateLimit = config.optimal_rate ?? 0.95
  // links counted as decisions: the board needed at least this many clicks (one or two clicks: a good player sees the
  // cheapest link nearly every time)
  const minBest = config.min_best ?? 3
  // the most links the solver searches for a board (branch and bound, electrolink/solver.mjs minConnection)
  const maxNodes = config.max_nodes ?? 200
  // second rule (null: off): links made without a useless click
  const wasteFreeRateLimit = config.waste_free_rate ?? null

  // the link being made: the board when the game began to wait for clicks, the clicks since
  let link = null
  // the tile turning at the frame before (one at a time: Game.lock while it turns)
  let turning = null
  const stats = { links: 0, decisions: 0, optimal: 0, wasteFree: 0, best: 0, decisionClicks: 0, clicks: 0, linkClicks: 0, wasted: 0, ruleErrors: 0 }
  const decisionFrames = []
  const linkFrames = []

  // the board (index x * HEIGHT + y: kind, orientation), checked against the pipes the game computed
  const readBoard = (game) => {
    const board = game.board
    if (!Array.isArray(board) || board.length !== WIDTH) throw new Error('unsupported build')
    const out = new Array(WIDTH * HEIGHT)
    for (let x = 0; x < WIDTH; x++) {
      const column = board[x]
      if (!Array.isArray(column) || column.length !== HEIGHT) throw new Error('unsupported build')
      for (let y = 0; y < HEIGHT; y++) {
        const tile = column[y]
        if (!tile || typeof tile.tile !== 'number' || typeof tile.d !== 'number' || !Array.isArray(tile.pipes)) {
          throw new Error('unsupported build')
        }
        if (tile.tile !== CROSS) {
          const p = pipes(tile.tile, tile.d)
          if (p.some((v, i) => v !== !!tile.pipes[i])) throw new Error('unsupported build')
        }
        out[x * HEIGHT + y] = { t: tile.tile, d: tile.d }
      }
    }
    return out
  }

  const finishLink = (game, frame) => {
    const after = readBoard(game)
    stats.links++
    stats.linkClicks += link.clicks
    // the rules here must find the link the game found (Game.check)
    if (!isConnected(after)) {
      stats.ruleErrors++
      return
    }
    const needed = neededClicks(link.before, after)
    stats.wasted += Math.max(0, link.clicks - needed)
    const best = minConnection(link.before, maxNodes)
    if (needed < best.cost || link.clicks < needed) stats.ruleErrors++
    if (!best.exact || best.cost < minBest || best.cost === Infinity) return
    stats.decisions++
    stats.best += best.cost
    stats.decisionClicks += link.clicks
    if (link.clicks <= best.cost) stats.optimal++
    if (link.clicks <= needed) stats.wasteFree++
    if (link.firstClick !== null) decisionFrames.push(link.firstClick - link.start)
    linkFrames.push(frame - 1 - link.start)
  }

  return {
    // before the frame: a click of the frame before made a tile turn (Tile.rotate: state Rotate); a link made during
    // the frame before is charging (step Charge) on the board it linked; the game waits for clicks again (step Play,
    // unlocked) on the board after the falls
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      if (!game.step || !Array.isArray(game.board) || typeof game.lockTile !== 'boolean') throw new Error('unsupported build')
      const step = game.step._hx_name

      if (link) {
        let now = null
        for (const column of game.board) {
          for (const tile of column) {
            if (tile && tile.state && tile.state._hx_name === 'Rotate') now = tile
          }
        }
        if (now && now !== turning) {
          link.clicks++
          stats.clicks++
          if (link.firstClick === null) link.firstClick = frame - 1
        }
        turning = now
        if (step === 'Charge') {
          finishLink(game, frame)
          link = null
        } else if (game.flGameOver) {
          // the time is over before a link
          link = null
        }
      }

      if (!link && step === 'Play' && !game.lockTile && !game.flGameOver) {
        link = { start: frame, before: readBoard(game), clicks: 0, firstClick: null }
        turning = null
      }
    },

    finish() {
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const rate = (n) => (stats.decisions ? +(n / stats.decisions).toFixed(3) : null)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        // links made with the fewest clicks possible from their board
        optimalRate: rate(stats.optimal),
        // links made without a click they did not need
        wasteFree: stats.wasteFree,
        wasteFreeRate: rate(stats.wasteFree),
        // the fewest clicks against the clicks of the decisions (1: every decision linked with the fewest clicks)
        valueRate: stats.decisionClicks ? +(stats.best / stats.decisionClicks).toFixed(3) : null,
        meanBest: stats.decisions ? +(stats.best / stats.decisions).toFixed(2) : null,
        links: stats.links,
        clicks: stats.clicks,
        // clicks the links made did not need (tiles turned too much, crosses, tiles out of the link)
        wastedClicks: stats.wasted,
        ruleErrors: stats.ruleErrors,
        // frames between the board shown and the first click of a decision (32 by second)
        meanDecisionFrames: mean(sorted),
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
        // frames between the board shown and the link
        medianLinkFrames: median(linkFrames.slice().sort((a, b) => a - b)),
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`lien le plus court trouvé ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} liens, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      if (wasteFreeRateLimit !== null && stats.decisions >= minDecisions && metrics.wasteFreeRate >= wasteFreeRateLimit) {
        reasons.push(`aucun clic inutile dans ${Math.round(metrics.wasteFreeRate * 100)} % des liens (${stats.decisions} liens, limite ${Math.round(wasteFreeRateLimit * 100)} %)`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
