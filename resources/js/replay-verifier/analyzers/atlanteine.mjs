// Analyzer of Atlanteine for the replay verifier (see README of this folder): each slide of the ball against the shortest
// ways out of the level the player sees (atlanteine/solver.mjs). The whole level is on the screen: a script can solve
// it and show the way (or play it). A good player finds the way most of the time, not every time: he tries a slide,
// comes back, dies in the sea (985 runs of 228 players: at most 90 % of the choices on a shortest way over 80 choices
// or more, 96 % over 50).
// Two rules: without pushing a box (a push loses the bonus of every box of the level, Game.finishLevel: what a player
// and a solver looking for points do) and with the push (a solver looking for the fewest slides only).
// Only the real choices count (atlanteine/solver.mjs rateMove: a way out, two sensible moves or more, not all of them
// on a shortest way, the hole more than one slide away); the levels where the game shows the way don't.
// Third signal, for a script that plays: the slides started the very frame the ball stops (a direction held during the
// slide before: players do it, at most 4 times out of 10), with good moves.
import { levelCache, rateMove, UNSOLVABLE } from './atlanteine/solver.mjs'

export const meta = { game: 'atlanteine', version: 1 }

// Game.SHOW_PATH_LEVEL_LIMIT: up to this level the game shows the way when the time is out (and the levels are short)
const SHOW_PATH_LEVEL_LIMIT = 3

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 80
  const optimalRateLimit = config.optimal_rate ?? 0.98
  const pushRateLimit = config.push_optimal_rate ?? 0.92
  // a script that plays: instant slides (share of the slides), with the moves on a shortest way (either rule)
  const minMoves = config.min_moves ?? 50
  const instantRateLimit = config.instant_rate ?? 0.6
  const instantOptimalLimit = config.instant_optimal_rate ?? 0.85
  const minInstantDecisions = 15

  const levelOf = levelCache()
  let stepName = null
  let playSince = null
  // the position when the game waits for a direction (step Play)
  let snapshot = null
  let lastMove
  // the state the last slide of this life started from (going back there is not a choice)
  let previous = null
  let current = null
  const stats = { moves: 0, instant: 0, pushes: 0, sea: 0, decisions: 0, optimal: 0, pushDecisions: 0, pushOptimal: 0 }
  const decisionFrames = []
  const levels = []

  const levelDone = (finished) => {
    if (!current) return
    current.finished = finished
    levels.push(current)
    current = null
  }

  // a slide of the player from the snapshot (direction d), wait: frames since the ball waits
  const rate = (s, d, wait) => {
    // after a push both rules are the same (no other push in this life): the grid of the push
    const never = s.variant === 0 ? rateMove(s.level.never, s.x, s.y, 0, d, previous) : rateMove(s.level.push, s.x, s.y, s.variant, d, previous)
    const push = rateMove(s.level.push, s.x, s.y, s.variant, d, previous)
    previous = s.state
    if (!s.counts) return
    stats.moves++
    if (wait === 0) stats.instant++
    if (push.push) stats.pushes++
    if (push.to === -2) stats.sea++
    if (never.choice && never.dist >= 2) {
      stats.decisions++
      if (never.optimal) stats.optimal++
      decisionFrames.push(wait)
    }
    if (push.choice && push.dist >= 2) {
      stats.pushDecisions++
      if (push.optimal) stats.pushOptimal++
    }
  }

  const read = (frame) => {
    const game = kk.game
    if (!game || !game.step) return
    if (!Array.isArray(game.grid) || typeof game.x !== 'number' || typeof game.level !== 'number') {
      throw new Error('unsupported build')
    }
    const name = game.step._hx_name

    // a slide started during the frame before (Game.control: a new move object), from the position of the snapshot
    if (game.move !== lastMove) {
      if (lastMove !== undefined && game.move && snapshot && game.level === snapshot.levelNumber) {
        const d = game.move.d
        rate(snapshot, d, frame - 1 - playSince)
        if (current) {
          current.moves++
        }
      }
      lastMove = game.move
      snapshot = null
    }

    if (name === stepName) return
    if (name === 'Play') {
      playSince = frame
      // the ball was born again (Game.spawnBall): the push is undone, nothing to go back to
      if (stepName === 'Spawn') previous = null
      const push = game.pushInfo ? { base: game.pushInfo.base.slice(), free: game.pushInfo.free.slice() } : null
      // Game.genLevel: the teleports from level 10 (Game.tel is left from the levels before otherwise)
      const tel = Array.isArray(game.tel) && game.level >= 10 ? game.tel : null
      const level = levelOf(game.grid, push, tel)
      const variant = level.push.variantOfPush(push)
      snapshot = {
        levelNumber: game.level,
        level,
        x: game.x,
        y: game.y,
        variant,
        state: level.push.state(game.x, game.y, variant ?? 0),
        // the levels where the game shows the way are not looked at (Game.updateTimer: ppList)
        counts: variant !== null && game.level > SHOW_PATH_LEVEL_LIMIT && game.ppList == null,
      }
      if (!current || current.level !== game.level) {
        levelDone(false)
        // the fewest slides to the hole without pushing, and with the push
        const shortest = level.never.dist(snapshot.state)
        const fewest = level.push.dist(snapshot.state)
        current = { level: game.level, shortest, fewest, moves: 0, deaths: 0, start: frame, end: null }
      }
    } else if (name === 'Wait' && current) {
      // Game.finishLevel: the hole
      current.end = frame - 1 - current.start
      levelDone(true)
    } else if (name === 'WaitTimer' && stepName !== null && current) {
      // Game.killBall: the sea or a ghost
      current.deaths++
    }
    stepName = name
  }

  return {
    beforeFrame(frame) {
      read(frame)
    },

    finish() {
      levelDone(false)
      const sorted = decisionFrames.slice().sort((a, b) => a - b)
      const ratio = (n, of) => (of ? +(n / of).toFixed(3) : null)
      // the levels won that needed 3 slides or more
      const counted = levels.filter((l) => l.level > SHOW_PATH_LEVEL_LIMIT && l.finished && l.fewest >= 3 && l.fewest !== UNSOLVABLE)
      // the fewest slides without pushing (with the push when there is no way without), or fewer when the player pushed
      const best = (l) => Math.min(l.moves, l.shortest === UNSOLVABLE ? l.fewest : l.shortest)
      const perfect = counted.filter((l) => l.deaths === 0 && l.moves === best(l)).length
      const fewest = counted.reduce((n, l) => n + best(l), 0)
      const played = counted.reduce((n, l) => n + l.moves, 0)
      const metrics = {
        decisions: stats.decisions,
        optimal: stats.optimal,
        // the slides on a shortest way out without pushing, when there was a real choice
        optimalRate: ratio(stats.optimal, stats.decisions),
        // the fewest slides against the slides played, over the levels counted
        valueRate: ratio(fewest, played),
        // the same with the push of a box
        pushDecisions: stats.pushDecisions,
        pushOptimalRate: ratio(stats.pushOptimal, stats.pushDecisions),
        moves: stats.moves,
        // the slides started the frame the ball stopped (32 frames by second)
        instantRate: ratio(stats.instant, stats.moves),
        pushes: stats.pushes,
        // the slides into the sea (a solver never takes one)
        seaSlides: stats.sea,
        // the levels counted won with the fewest slides, without dying (a ghost can kill a solver too)
        levels: counted.length,
        perfectLevelRate: ratio(perfect, counted.length),
        // frames between the ball waiting and the direction (32 by second; a direction held during the slide: 0)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (stats.decisions >= minDecisions && metrics.optimalRate >= optimalRateLimit) {
        reasons.push(`plus court chemin ${Math.round(metrics.optimalRate * 100)} % du temps (${stats.decisions} choix, limite ${Math.round(optimalRateLimit * 100)} %)`)
      }
      if (stats.pushDecisions >= minDecisions && metrics.pushOptimalRate >= pushRateLimit) {
        reasons.push(`plus court chemin en poussant les caisses ${Math.round(metrics.pushOptimalRate * 100)} % du temps (${stats.pushDecisions} choix, limite ${Math.round(pushRateLimit * 100)} %)`)
      }
      // the better of the two rules, over enough choices
      const rates = [
        stats.decisions >= minInstantDecisions ? metrics.optimalRate : null,
        stats.pushDecisions >= minInstantDecisions ? metrics.pushOptimalRate : null,
      ].filter((r) => r !== null)
      const bestRate = rates.length ? Math.max(...rates) : null
      if (stats.moves >= minMoves && metrics.instantRate >= instantRateLimit && bestRate !== null && bestRate >= instantOptimalLimit) {
        reasons.push(`coups joués à l'instant où la bille s'arrête ${Math.round(metrics.instantRate * 100)} % du temps (${stats.moves} coups, limite ${Math.round(instantRateLimit * 100)} %), plus court chemin ${Math.round(bestRate * 100)} % du temps`)
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
