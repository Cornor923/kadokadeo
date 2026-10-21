// Analyzer of Toy Maniak for the replay verifier (see README of this folder). Toy Maniak is a game of attention and
// hands (three rails of toys to keep on one colour each): everything is on the screen, there is no hidden information
// worth reading and no "best move" a helping script could show that a player does not see. What a cheat can do is play
// for the player: an auto-player (a program reading the game or the screen and moving the real mouse) presses where it
// computed the target, on the same pixel of every toy of a kind and of every slot of the box. A player presses
// somewhere on the picture: never twice on the same pixel of it (toymaniak/presses.mjs).
// Watched: the presses that do something (take, put, swap) after the mouse travelled to their target (aimed presses:
// a player who leaves the mouse on a rail and presses as the toys pass is not aiming, those presses are left out). The
// rest (how many threats to a combo were saved, how fast the aim was) is reported, never flagged: very good players
// save everything, and touch screens "teleport" the pointer like a program.
import { aimOf, aimPrecision, pressTarget } from './toymaniak/presses.mjs'

export const meta = { game: 'toymaniak', version: 1 }

// Const.RAIL_END: the toys are crushed (Rail.active) when they reach it; a toy is on the screen below x 300 + 25
const RAIL_END = 38
const SCREEN = 300
// a movement of the mouse goes on through pauses of up to this many frames
const MOVE_GAP = 2

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)
const round = (v, n = 3) => (v == null ? null : +v.toFixed(n))

export function create({ kk, config = {} }) {
  const minDecisions = config.min_decisions ?? 30
  const optimalRateLimit = config.optimal_rate ?? 0.7
  const maxSpread = config.max_spread ?? 1.5
  const tolerance = config.aim_tolerance ?? 1
  const aimMinDistance = config.aim_min_distance ?? 20
  const minGroup = config.min_group ?? 4

  // the mouse of the replay (positions in canvas pixels: the game reads them / 2, Game.readMouse) and its left button
  const frames = kk.replay.playFrames
  const records = kk.replay.playRecords
  if (!Array.isArray(frames) || !Array.isArray(records)) throw new Error('unsupported build')
  const recordAt = new Map()
  frames.forEach((frame, i) => recordAt.set(frame, records[i]))

  let mx = 0
  let my = 0
  let down = false
  let pressedAt = null
  let lastPress = null
  let lastMoveFrame = 0
  let moveStart = 0
  let hoverFrames = 0
  const aims = []
  const aimFrames = []
  const pressFrames = []
  const stats = { presses: 0, aimed: 0, teleports: 0, threats: 0, saved: 0, breaks: 0, maxSpeed: 0 }
  // the toys that threatened a combo (a colour other than the rail's, seen on the screen), until they are crushed
  const threats = new Map()
  let lastOfRails = null

  const readState = (game) => {
    if (!Array.isArray(game.rails) || !Array.isArray(game.sels) || game.rails.length !== 3 || game.sels.length !== 3) {
      throw new Error('unsupported build')
    }
    const rails = game.rails.map((rail) => {
      if (!Array.isArray(rail.toys) || typeof rail.speed !== 'number' || !('last' in rail)) throw new Error('unsupported build')
      return { toys: rail.toys.map((t) => ({ x: t.x, t: t.t, lock: t.lock })) }
    })
    return { rails, sels: game.sels.map((s) => s.t), cursor: game.cursor ? game.cursor.t : null }
  }

  // threats to the combos and what became of them (Rail.active: a colour other than the last one breaks the combo)
  const watchRails = (game) => {
    game.rails.forEach((rail, r) => {
      stats.maxSpeed = Math.max(stats.maxSpeed, rail.speed * (game.speed ?? 1))
      const last = lastOfRails ? lastOfRails[r] : null
      for (const toy of rail.toys) {
        const threat = threats.get(toy)
        if (threat && !threat.done && toy.x <= RAIL_END) {
          // crushed during the frame before: locked since x 48, its type did not change since
          threat.done = true
          if (toy.t >= 0 && toy.t < 4 && last !== null && toy.t !== last) stats.breaks++
          else stats.saved++
        } else if (!threat && !toy.lock && toy.x < SCREEN && toy.x > RAIL_END && toy.t >= 0 && toy.t < 4
          && rail.last != null && toy.t !== rail.last && rail.ncombos >= 2) {
          threats.set(toy, { done: false })
          stats.threats++
        }
      }
    })
    lastOfRails = game.rails.map((rail) => rail.last)
  }

  return {
    // before the frame: the presses of the frame are applied first (Game.flashFrame), on the toys where they were drawn
    beforeFrame(frame) {
      const game = kk.game
      if (!game || !game.rails) return
      if (lastOfRails === null) readState(game)
      watchRails(game)
      const record = recordAt.get(frame)
      if (!record) return
      if (record.mousePosition) {
        const x = Math.max(0, record.mousePosition.x) / 2
        const y = Math.max(0, record.mousePosition.y) / 2
        if (x !== mx || y !== my) {
          if (frame - lastMoveFrame > MOVE_GAP + 1) moveStart = frame
          lastMoveFrame = frame
          // (a touch: the pointer appears with the finger, in the record of the press)
          if (!down && !(record.mouseButtons || []).some((c) => c.isDown)) hoverFrames++
          mx = x
          my = y
        }
      }
      for (const change of record.mouseButtons || []) {
        if (!change.isDown) {
          if (down && pressedAt !== null) pressFrames.push(frame - pressedAt)
          down = false
          continue
        }
        if (down) continue
        down = true
        pressedAt = frame
        const target = pressTarget(readState(game), mx, my)
        if (!target || !target.effect) continue
        stats.presses++
        const travelled = lastPress ? Math.hypot(mx - lastPress[0], my - lastPress[1]) : Infinity
        lastPress = [mx, my]
        if (travelled < aimMinDistance) continue
        stats.aimed++
        aims.push(aimOf(target))
        // frames of the movement that brought the mouse there (1: the pointer jumped, a touch screen or a program)
        const aim = lastMoveFrame - moveStart + 1
        aimFrames.push(aim)
        if (aim <= 1) stats.teleports++
      }
    },

    finish() {
      const precision = aimPrecision(aims, { tolerance, minGroup })
      const sorted = aimFrames.slice().sort((a, b) => a - b)
      const pressSorted = pressFrames.slice().sort((a, b) => a - b)
      const metrics = {
        // aimed presses of the kinds pressed at least minGroup times, those on the pixel of the others of their kind
        decisions: precision.presses,
        optimal: precision.exact,
        optimalRate: round(precision.exactRate),
        valueRate: null,
        // pooled standard deviation of where they land on their target (Flash pixels)
        aimSpread: round(precision.spread, 2),
        presses: stats.presses,
        aimed: stats.aimed,
        // aimed presses reached by a jump of the pointer (touch screens, programs)
        teleportRate: stats.aimed ? round(stats.teleports / stats.aimed) : null,
        // frames the mouse moved while no button was down, presses apart (near 0: a touch screen)
        hoverFrames,
        medianPressFrames: median(pressSorted),
        // toys of another colour seen coming on a rail with a combo, and how many of them did not break it
        threats: stats.threats,
        saved: stats.saved,
        saveRate: stats.saved + stats.breaks ? round(stats.saved / (stats.saved + stats.breaks)) : null,
        breaks: stats.breaks,
        // the fastest rail (pixels by Flash frame: 0.5 to 0.7 at the start, Const.MAXSPEED 5 after the speed bonuses)
        maxRailSpeed: round(stats.maxSpeed, 2),
        // frames of the last movement of the mouse before the aimed presses (32 by second)
        meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((s, v) => s + v, 0) / sorted.length) : null,
        medianDecisionFrames: median(sorted),
        p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
      }
      const reasons = []
      if (precision.presses >= minDecisions) {
        if (precision.exactRate >= optimalRateLimit) {
          reasons.push(`clics au pixel près au même point des jouets et des cases ${Math.round(precision.exactRate * 100)} % du temps (${precision.presses} clics visés, limite ${Math.round(optimalRateLimit * 100)} %)`)
        }
        if (precision.spread <= maxSpread) {
          reasons.push(`clics regroupés sur les jouets et les cases : écart type de ${metrics.aimSpread} pixel (${precision.presses} clics visés, limite ${maxSpread} pixel)`)
        }
      }
      return { metrics, suspicious: reasons.length > 0, reasons }
    },
  }
}
