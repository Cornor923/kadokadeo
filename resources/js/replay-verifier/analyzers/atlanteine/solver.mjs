// The rules of Atlanteine (resources/hx/games/atlanteine/Game.hx) to rate the moves of a player: a ball slides on a
// grid (index x * h + y) until a rock or a box stops it; the level is won when it reaches the hole (OUT), the ball dies
// in the sea. Once by life, a box with a free cell behind it can be pushed one cell (the ball takes its place).
// Everything is on the screen (the PATH cells look like the EMPTY ones: both are free): the shortest way out, in moves,
// is what a solver shows. dist(state) = moves to the hole (Infinity: no way out without dying).
export const EMPTY = 0
export const PATH = 1
// (MROCK = 22 only exists while Game.genLevel builds the level)
export const ROCK = 2
export const BLOCK = 3
export const TELEPORT = 4
export const OUT = 5
export const SEA = 6

// Game.DIR: right, down, left, up
export const DIR = [[1, 0], [0, 1], [-1, 0], [0, -1]]

// Game.isBlock / Game.isFree (an undefined cell, out of the grid, is neither)
const isBlock = (c) => c === BLOCK || c === ROCK
const isFree = (c) => c === PATH || c === EMPTY

export const UNSOLVABLE = Infinity

// a level: its grid without the push of this life (the push of the box is undone at each new ball, Game.updateSpawn)
export class Level {
  // allowPush false: the ways out that never push a box (they keep the bonus of the boxes, Game.finishLevel)
  constructor(grid, w, h, tel, allowPush = true) {
    this.allowPush = allowPush
    this.w = w
    this.h = h
    this.tel = tel ? tel.map((p) => [p[0], p[1]]) : null
    // variant 0: no box pushed yet (a push is possible); variant k: the push k done (no other push in this life)
    this.grids = [Int8Array.from(grid)]
    this.pushes = [null]
    this.pushIndex = new Map()
    // the moves of a state (variant * w * h + cell): [{ d, push, to }] with to = a state, -1 the hole, -2 the sea
    this.edges = new Map()
    // the states whose whole reachable part is in edges, and their moves to the hole
    this.explored = new Set()
    this.dists = new Map()
  }

  cell(g, x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return undefined
    return g[x * this.h + y]
  }

  // Game.getTeleportPos: the other teleport
  otherTeleport(x, y) {
    for (const p of this.tel || []) if (p[0] !== x || p[1] !== y) return p
    return null
  }

  // Game.updateMove, from Game.control once the move is started (the next cell is not a rock or a box): one cell at a
  // time; the sea kills, the hole ends the level, a teleport moves the ball to the other one and the slide goes on
  // from there without looking at the next cell (break out of the loop before "CHECK NEXT"); else the ball stops
  // before a rock or a box
  slide(g, x, y, d) {
    const [dx, dy] = DIR[d]
    for (let guard = 0; guard < 4 * (this.w + this.h); guard++) {
      x += dx
      y += dy
      const c = this.cell(g, x, y)
      if (c === undefined) return { end: 'sea', x, y }
      if (c === SEA) return { end: 'sea', x, y }
      if (c === OUT) return { end: 'out', x, y }
      if (c === TELEPORT) {
        const p = this.otherTeleport(x, y)
        if (!p) return { end: 'sea', x, y }
        x = p[0]
        y = p[1]
        continue
      }
      if (isBlock(this.cell(g, x + dx, y + dy))) return { end: 'stop', x, y }
    }
    return { end: 'sea', x, y }
  }

  variantOf(bx, by, d) {
    const key = (bx * this.h + by) * 4 + d
    let v = this.pushIndex.get(key)
    if (v === undefined) {
      const g = this.grids[0].slice()
      const [dx, dy] = DIR[d]
      g[bx * this.h + by] = EMPTY
      g[(bx + dx) * this.h + by + dy] = BLOCK
      v = this.grids.length
      this.grids.push(g)
      this.pushes.push({ base: [bx, by], free: [bx + dx, by + dy], d })
      this.pushIndex.set(key, v)
    }
    return v
  }

  // the variant of a push read in the game (Game.pushInfo: base = the cell of the box, free = where it went)
  variantOfPush(push) {
    if (!push) return 0
    const d = DIR.findIndex(([dx, dy]) => push.base[0] + dx === push.free[0] && push.base[1] + dy === push.free[1])
    return d < 0 ? null : this.variantOf(push.base[0], push.base[1], d)
  }

  // Game.control: every direction the player can press; null: nothing happens (a rock, or a box that cannot move)
  moves(state) {
    let list = this.edges.get(state)
    if (list) return list
    const size = this.w * this.h
    const v = Math.floor(state / size)
    const pos = state % size
    const x = Math.floor(pos / this.h)
    const y = pos % this.h
    const g = this.grids[v]
    list = []
    for (let d = 0; d < 4; d++) {
      const [dx, dy] = DIR[d]
      const next = this.cell(g, x + dx, y + dy)
      if (next === undefined) {
        list.push(null)
      } else if (!isBlock(next)) {
        const r = this.slide(g, x, y, d)
        list.push({ d, push: false, to: r.end === 'out' ? -1 : r.end === 'sea' ? -2 : v * size + r.x * this.h + r.y })
      } else if (this.allowPush && v === 0 && next === BLOCK && isFree(this.cell(g, x + 2 * dx, y + 2 * dy))) {
        // the box goes one cell further, the ball takes its place and stops against it
        const nv = this.variantOf(x + dx, y + dy, d)
        list.push({ d, push: true, to: nv * size + (x + dx) * this.h + y + dy })
      } else {
        list.push(null)
      }
    }
    this.edges.set(state, list)
    return list
  }

  // every state reachable from the start, then the moves to the hole of each (backward BFS from the hole)
  explore(start) {
    if (this.explored.has(start)) return
    const queue = [start]
    this.explored.add(start)
    for (let i = 0; i < queue.length; i++) {
      for (const m of this.moves(queue[i])) {
        if (m && m.to >= 0 && !this.explored.has(m.to)) {
          this.explored.add(m.to)
          queue.push(m.to)
        }
      }
    }
    // a state of an earlier exploration may lead into this one: distances of every known state again
    const preds = new Map()
    const dists = new Map()
    const frontier = []
    for (const [s, list] of this.edges) {
      for (const m of list) {
        if (!m) continue
        if (m.to === -1) {
          if (!dists.has(s)) {
            dists.set(s, 1)
            frontier.push(s)
          }
        } else if (m.to >= 0) {
          if (!preds.has(m.to)) preds.set(m.to, [])
          preds.get(m.to).push(s)
        }
      }
    }
    for (let i = 0; i < frontier.length; i++) {
      const s = frontier[i]
      const dist = dists.get(s)
      for (const p of preds.get(s) || []) {
        if (!dists.has(p)) {
          dists.set(p, dist + 1)
          frontier.push(p)
        }
      }
    }
    this.dists = dists
  }

  dist(state) {
    if (state === -1) return 0
    if (state < 0) return UNSOLVABLE
    this.explore(state)
    return this.dists.get(state) ?? UNSOLVABLE
  }

  state(x, y, variant = 0) {
    return variant * this.w * this.h + x * this.h + y
  }
}

// grid: Game.grid (grid[x][y]) as it is now, push: Game.pushInfo (null: no box pushed in this life); the grid of the
// level without the push (Game.updateSpawn puts the box back: BLOCK on base, EMPTY on free)
export function baseGrid(grid, push) {
  const w = grid.length
  const h = grid[0].length
  const flat = new Int8Array(w * h)
  for (let x = 0; x < w; x++) for (let y = 0; y < h; y++) flat[x * h + y] = grid[x][y]
  if (push) {
    flat[push.base[0] * h + push.base[1]] = BLOCK
    flat[push.free[0] * h + push.free[1]] = EMPTY
  }
  return { flat, w, h }
}

// the rating of a position: its distance to the hole and the distance after each direction (null: nothing happens,
// Infinity: the sea or no way out)
export function ratePosition(level, x, y, variant) {
  const state = level.state(x, y, variant)
  const dist = level.dist(state)
  const moves = level.moves(state).map((m) => (m ? { d: m.d, push: m.push, to: m.to, dist: level.dist(m.to) } : null))
  return { state, dist, moves }
}

// the move d played from x, y against them; previous: the state the last slide started from (going back there is no
// choice)
//   optimal: the move is on a shortest way out; choice: the position was a real choice
export function rateMove(level, x, y, variant, d, previous = null) {
  const pos = ratePosition(level, x, y, variant)
  const move = pos.moves[d]
  const after = move ? move.dist : null
  const optimal = move != null && pos.dist !== UNSOLVABLE && after === pos.dist - 1
  // the moves a player considers: not the sea, not back to where the ball comes from, not nothing
  const sensible = pos.moves.filter((m) => m && m.to !== -2 && m.to !== previous && m.dist !== UNSOLVABLE)
  const optimalMoves = pos.moves.filter((m) => m && m.dist === pos.dist - 1).length
  return {
    dist: pos.dist,
    after,
    optimal,
    push: move ? move.push : false,
    to: move ? move.to : null,
    sensible: sensible.length,
    optimalMoves,
    // a real choice: a way out exists, more than one sensible move, and one of them is not on a shortest way out
    choice: pos.dist !== UNSOLVABLE && sensible.length >= 2 && sensible.some((m) => m.dist !== pos.dist - 1),
  }
}

// the levels by their grid (the same level is played again after each death): { push, never } the rules with the push
// of a box, and without (the ways a player who keeps the bonus of the boxes looks for)
export function levelCache(max = 8) {
  const cache = new Map()
  return (grid, push, tel) => {
    const { flat, w, h } = baseGrid(grid, push)
    const key = flat.join('')
    let level = cache.get(key)
    if (!level) {
      level = { push: new Level(flat, w, h, tel), never: new Level(flat, w, h, tel, false) }
      cache.set(key, level)
      if (cache.size > max) cache.delete(cache.keys().next().value)
    }
    return level
  }
}
