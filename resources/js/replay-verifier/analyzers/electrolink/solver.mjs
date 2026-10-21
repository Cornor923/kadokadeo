// The rules of Electrolink (resources/hx/games/electrolink) to value the work of a player: an 8 x 9 board of pipe
// tiles (index x * HEIGHT + y, x = 0 the left column), a click turns a tile a quarter clockwise (Tile.rotate /
// rotateDone: d + 1). The board explodes when pipes link a goal of the left side to a goal of the right side
// (Game.check / parse). Here: the fewest clicks that link the two sides from a board (what a solver shows), and the
// clicks the link a player made really needed.
export const WIDTH = 8
export const HEIGHT = 9
export const EAST = 0
export const SOUTH = 1
export const WEST = 2
export const NORTH = 3
// Cs.TILE_3
export const CROSS = 3

// Tile.updatePipe: the pipes (east, south, west, north) of each kind at d = 0: line, elbow, T, cross, dead end
const BASE = [
  [true, false, true, false],
  [false, false, true, true],
  [true, false, true, true],
  [true, true, true, true],
  [false, false, true, false],
]

// the neighbour in a direction (Game.getNeighbour), -1 out of the board
const STEP = [[1, 0], [0, 1], [-1, 0], [0, -1]]
export function neighbour(i, dir) {
  const x = Math.floor(i / HEIGHT) + STEP[dir][0]
  const y = (i % HEIGHT) + STEP[dir][1]
  return x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT ? -1 : x * HEIGHT + y
}

// Tile.updatePipe + rotatePipe(d): pipes[(i + d) % 4] = base[i] (the cross is never rotated: all its pipes are open)
export function pipes(kind, d) {
  const base = BASE[kind]
  if (!base) throw new Error('unknown tile ' + kind)
  const out = [false, false, false, false]
  for (let i = 0; i < 4; i++) out[(i + d) % 4] = base[i]
  return out
}

const PIPES = BASE.map((_, kind) => [0, 1, 2, 3].map((d) => pipes(kind, d)))

// clicks to turn a tile from d to target (one quarter clockwise each)
export const turns = (from, to) => (((to - from) % 4) + 4) % 4

// the fewest clicks to give a tile the pipes it has at `to` (a line is the same every half turn, a cross always)
export function turnsToPipes(kind, from, to) {
  const want = PIPES[kind][to]
  let best = 4
  for (let k = 0; k < 4; k++) {
    const p = PIPES[kind][k]
    if (p[0] === want[0] && p[1] === want[1] && p[2] === want[2] && p[3] === want[3]) best = Math.min(best, turns(from, k))
  }
  return best
}

// two tiles are linked when each has a pipe toward the other (Game.parse)
function linked(board, i, dir, j) {
  return PIPES[board[i].t][board[i].d][dir] && PIPES[board[j].t][board[j].d][(dir + 2) % 4]
}

// the tiles linking the two sides (Game.check): the groups of linked tiles holding a tile of the left column open to
// the west and a tile of the right column open to the east. Empty: the board does not explode.
export function network(board) {
  const group = new Int32Array(WIDTH * HEIGHT).fill(-1)
  const out = new Set()
  for (let y = 0; y < HEIGHT; y++) {
    if (group[y] !== -1 || !PIPES[board[y].t][board[y].d][WEST]) continue
    const cells = [y]
    group[y] = y
    let east = false
    for (let n = 0; n < cells.length; n++) {
      const i = cells[n]
      if (Math.floor(i / HEIGHT) === WIDTH - 1 && PIPES[board[i].t][board[i].d][EAST]) east = true
      for (let dir = 0; dir < 4; dir++) {
        const j = neighbour(i, dir)
        if (j >= 0 && group[j] === -1 && linked(board, i, dir, j)) {
          group[j] = y
          cells.push(j)
        }
      }
    }
    if (east) for (const i of cells) out.add(i)
  }
  return out
}

export const isConnected = (board) => network(board).size > 0

// a small binary heap of [cost, state] for the searches below
function heap() {
  const items = []
  return {
    get size() { return items.length },
    push(cost, state) {
      items.push([cost, state])
      let i = items.length - 1
      while (i > 0) {
        const p = (i - 1) >> 1
        if (items[p][0] <= items[i][0]) break
        ;[items[p], items[i]] = [items[i], items[p]]
        i = p
      }
    },
    pop() {
      const top = items[0]
      const last = items.pop()
      if (items.length) {
        items[0] = last
        let i = 0
        for (;;) {
          const l = 2 * i + 1
          const r = l + 1
          let m = i
          if (l < items.length && items[l][0] < items[m][0]) m = l
          if (r < items.length && items[r][0] < items[m][0]) m = r
          if (m === i) break
          ;[items[m], items[i]] = [items[i], items[m]]
          i = m
        }
      }
      return top
    },
  }
}

// the cheapest walk from the left goals to the right ones over (tile, side it is entered by), a tile costing the clicks
// to an orientation open on its way in and its way out (`fixed`: tiles given one orientation). A walk passing twice by
// a tile can ask it two orientations: a lower bound only. walk: [{ i, d }] from the left goal.
export function cheapestWalk(board, fixed) {
  const N = WIDTH * HEIGHT
  // cheapest orientation of each tile for each (way in, way out)
  const cost = new Float64Array(N * 16).fill(Infinity)
  const orient = new Int8Array(N * 16)
  for (let i = 0; i < N; i++) {
    const { t, d } = board[i]
    const only = fixed.get(i)
    for (let k = 0; k < 4; k++) {
      if (only !== undefined && k !== only) continue
      const p = PIPES[t][k]
      const c = turns(d, k)
      for (let a = 0; a < 4; a++) {
        if (!p[a]) continue
        for (let b = 0; b < 4; b++) {
          if (b === a || !p[b]) continue
          const s = i * 16 + a * 4 + b
          if (c < cost[s]) {
            cost[s] = c
            orient[s] = k
          }
        }
      }
    }
  }
  // state: tile * 4 + way in; GOAL: out of the right column to the east
  const GOAL = N * 4
  const dist = new Float64Array(N * 4 + 1).fill(Infinity)
  const prev = new Int32Array(N * 4 + 1).fill(-1)
  const prevOrient = new Int8Array(N * 4 + 1)
  const queue = heap()
  // the left goals: tiles of the left column entered from the west; dist[s]: the clicks of the tiles before s
  for (let y = 0; y < HEIGHT; y++) {
    dist[y * 4 + WEST] = 0
    queue.push(0, y * 4 + WEST)
  }
  while (queue.size) {
    const [c, s] = queue.pop()
    if (s === GOAL) break
    if (c > dist[s]) continue
    const i = s >> 2
    const a = s & 3
    for (let b = 0; b < 4; b++) {
      const w = cost[i * 16 + a * 4 + b]
      if (w === Infinity) continue
      const nc = c + w
      let next
      if (b === EAST && Math.floor(i / HEIGHT) === WIDTH - 1) next = GOAL
      else {
        const j = neighbour(i, b)
        if (j < 0) continue
        next = j * 4 + ((b + 2) % 4)
      }
      if (nc < dist[next]) {
        dist[next] = nc
        prev[next] = s
        prevOrient[next] = orient[i * 16 + a * 4 + b]
        queue.push(nc, next)
      }
    }
  }
  const walk = []
  if (dist[GOAL] !== Infinity) {
    for (let s = GOAL; prev[s] !== -1; s = prev[s]) walk.push({ i: prev[s] >> 2, d: prevOrient[s] })
    walk.reverse()
  }
  return { cost: dist[GOAL], walk }
}

// a tile the walk asks two things of (two orientations, or twice a tile that is not a cross), -1 none
function conflict(board, walk) {
  const seen = new Map()
  for (const { i, d } of walk) {
    if (seen.has(i) && (board[i].t !== CROSS || seen.get(i) !== d)) return i
    seen.set(i, d)
  }
  return -1
}

// the fewest clicks that link the two sides from a board (what a solver shows): the cheapest walk, made exact by
// branch and bound on the tiles it asks two orientations of (each child gives the tile one orientation; best first:
// the first walk without conflict is the cheapest link). `exact` false: more than maxNodes walks searched (the cost is
// then a lower bound). path: [{ i, d }] the tiles to turn and their orientation.
export function minConnection(board, maxNodes = 200) {
  if (isConnected(board)) return { cost: 0, exact: true, path: [] }
  const queue = heap()
  const nodes = []
  const push = (fixed) => {
    const r = cheapestWalk(board, fixed)
    if (r.cost === Infinity) return
    nodes.push({ fixed, ...r })
    queue.push(r.cost, nodes.length - 1)
  }
  push(new Map())
  let searched = 0
  while (queue.size) {
    const [cost, n] = queue.pop()
    const node = nodes[n]
    const tile = conflict(board, node.walk)
    if (tile < 0) {
      const path = []
      const done = new Set()
      for (const { i, d } of node.walk) {
        if (!done.has(i) && d !== board[i].d) path.push({ i, d })
        done.add(i)
      }
      return { cost, exact: true, path }
    }
    if (++searched > maxNodes) return { cost, exact: false, path: [] }
    // the tile in each orientation (a line is the same each half turn)
    const tried = new Set()
    for (let k = 0; k < 4; k++) {
      const key = PIPES[board[tile].t][k].join()
      const best = [0, 1, 2, 3].filter((o) => PIPES[board[tile].t][o].join() === key)
        .reduce((m, o) => (turns(board[tile].d, o) < turns(board[tile].d, m) ? o : m))
      if (tried.has(best)) continue
      tried.add(best)
      push(new Map(node.fixed).set(tile, best))
    }
  }
  // every orientation of the tiles asked twice fails: nothing links
  return { cost: Infinity, exact: true, path: [] }
}

// the clicks the link made really needed: the cheapest way from the left goals to the right ones through the pipes of
// `after` (the board when it exploded), a tile costing the clicks from its orientation in `before` to its pipes in
// `after`. Infinity: `after` does not link the two sides.
export function neededClicks(before, after) {
  const N = WIDTH * HEIGHT
  const w = (i) => turnsToPipes(after[i].t, before[i].d, after[i].d)
  const dist = new Float64Array(N).fill(Infinity)
  const queue = heap()
  for (let y = 0; y < HEIGHT; y++) {
    if (PIPES[after[y].t][after[y].d][WEST]) {
      dist[y] = w(y)
      queue.push(dist[y], y)
    }
  }
  while (queue.size) {
    const [c, i] = queue.pop()
    if (c > dist[i]) continue
    if (Math.floor(i / HEIGHT) === WIDTH - 1 && PIPES[after[i].t][after[i].d][EAST]) return c
    for (let dir = 0; dir < 4; dir++) {
      const j = neighbour(i, dir)
      if (j < 0 || !linked(after, i, dir, j)) continue
      const nc = c + w(j)
      if (nc < dist[j]) {
        dist[j] = nc
        queue.push(nc, j)
      }
    }
  }
  return Infinity
}

// the work of the player from a board shown (before) to the board that exploded (after), with `clicks` clicks:
// best (the fewest clicks linking the sides from before), needed (the clicks the link made needed), optimal (no
// more clicks than the best), wasteFree (no click the link did not need)
export function rateLink(before, after, clicks) {
  const best = minConnection(before)
  const needed = neededClicks(before, after)
  return {
    best: best.cost,
    exact: best.exact,
    needed,
    clicks,
    optimal: clicks <= best.cost,
    wasteFree: clicks <= needed,
  }
}
