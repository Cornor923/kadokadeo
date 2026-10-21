// The rules of Razor (resources/hx/games/razor/Game.hx) to value the slices of a player. A 6 x 6 grid of fruits (index
// x * 6 + y; colours 0-2, Pioupiou 3: a wildcard), the razor walks on the 24 places around it and slices the fruit in
// front of it: the game cuts the longest path of fruits of that colour (or Pioupious) from it (Game.getPath), the
// fruits left fall toward the razor's side (Game.initFall) and the holes get new random fruits: unknown here, so the
// look-ahead counts only what is certain from the board. Each colour has 4 slices (the icons of Game.incPool): the 5th
// slice of a colour ends the game; a slice from a Pioupiou costs nothing.
export const SIDE = 6
// Cs.COL_MAX: the colour of a Pioupiou
export const PIOUPIOU = 3
// Cs.POOL_MAX
export const POOL_MAX = 4
// a hole (a fruit to come: unknown)
export const UNKNOWN = -1
// Cs.DIR
const DIR = [[1, 0], [0, 1], [-1, 0], [0, -1]]

const smod = (n, m) => ((n % m) + m) % m

// the 24 places of the razor: rx, ry, bdir (the side: 0 bottom, 1 left, 2 top, 3 right), the cell in front of it
// (Game.getSliceTarget: DIR[bdir - 1]) and the direction the fruits fall to after its slice (Game.initFall: DIR[bdir + 1],
// toward the razor). Corner cells are in front of two places (two sides: two falls).
export const PLACES = []
for (let bdir = 0; bdir < 4; bdir++) {
  const t = DIR[smod(bdir - 1, 4)]
  for (let i = 0; i < SIDE; i++) {
    // the place is the target cell moved one cell away from the grid
    const tx = t[0] === 0 ? i : t[0] === 1 ? 0 : SIDE - 1
    const ty = t[1] === 0 ? i : t[1] === 1 ? 0 : SIDE - 1
    PLACES.push({ rx: tx - t[0], ry: ty - t[1], bdir, target: tx * SIDE + ty, fall: DIR[(bdir + 1) % 4] })
  }
}

// the place of the razor at rx, ry facing bdir (-1: not a place)
export const placeIndex = (rx, ry, bdir) => PLACES.findIndex((p) => p.rx === rx && p.ry === ry && p.bdir === bdir)

// Game.slip: the place one press of a side key away (sens 1: right, -1: left), turning at the corners
export function slip(place, sens) {
  let di = (place.bdir + 1 - sens) % 4
  const dx = DIR[di][0]
  const dy = DIR[di][1]
  let x = place.rx + dx
  let y = place.ry + dy
  let bdir = place.bdir
  if ((dx !== 0 && (x === -1 || x === SIDE)) || (dy !== 0 && (y === -1 || y === SIDE))) {
    di = smod(di - sens, 4)
    bdir = smod(bdir - sens, 4)
    x += DIR[di][0]
    y += DIR[di][1]
  }
  return placeIndex(x, y, bdir)
}

// the fewest presses to walk the razor from a place to another (either way around the board)
export function ringDistance(from, to) {
  let a = from
  let b = from
  for (let n = 0; n <= PLACES.length / 2; n++) {
    if (a === to || b === to) return n
    a = slip(PLACES[a], 1)
    b = slip(PLACES[b], -1)
  }
  return -1
}

const at = (x, y) => (x >= 0 && x < SIDE && y >= 0 && y < SIDE ? x * SIDE + y : -1)

// Game.getPath, faithfully: the longest path of cells of the colour of `start` (or Pioupious) from it, every path tried
// in the order of DIR; between two of the same length, the first found unless the other has fewer Pioupious. From a
// Pioupiou (colour 3) only Pioupious follow. `limit` caps the cells visited (the search is exponential; the game's own
// boards never come near it): over it, null.
export function getPath(grid, start, limit = 2000000) {
  const col = grid[start]
  if (col == null || col < 0) return null
  const inList = new Uint8Array(SIDE * SIDE)
  let visits = 0
  const rec = (i) => {
    if (++visits > limit) throw new RangeError('path search too long')
    inList[i] = 1
    let a = []
    let aPiou = 0
    const x = Math.floor(i / SIDE)
    const y = i % SIDE
    for (const d of DIR) {
      const j = at(x + d[0], y + d[1])
      if (j < 0 || inList[j]) continue
      const c = grid[j]
      if (c !== col && c !== PIOUPIOU) continue
      const work = rec(j)
      if (work.length > a.length) {
        a = work
        aPiou = work.piou
      } else if (work.length === a.length && work.piou < aPiou) {
        a = work
        aPiou = work.piou
      }
    }
    inList[i] = 0
    const out = [i, ...a]
    out.piou = aPiou + (grid[i] === PIOUPIOU ? 1 : 0)
    return out
  }
  try {
    const path = rec(start)
    delete path.piou
    return path
  } catch(e) {
    if (e instanceof RangeError) return null
    throw e
  }
}

// Ball.sliced: the k-th fruit of the path (k from 0, Game.bonus) is worth 200 + 50 k, a Pioupiou 1000
export function pathScore(grid, path) {
  let score = 0
  path.forEach((i, k) => {
    score += grid[i] === PIOUPIOU ? 1000 : 200 + 50 * k
  })
  return score
}

// Game.initFall: the cells of the path emptied, the fruits fall toward the razor's side (fall: the direction of the
// fall), the holes left on the far side get new fruits (unknown)
export function afterSlice(grid, path, fall) {
  const g = grid.slice()
  for (const i of path) g[i] = null
  for (let line = 0; line < SIDE; line++) {
    // the cells of the line from the razor's side: k = 0 the nearest
    const cells = []
    for (let k = 0; k < SIDE; k++) {
      const far = SIDE - 1 - k
      let x
      let y
      if (fall[0] === 0) {
        x = line
        y = fall[1] === 1 ? far : k
      } else {
        y = line
        x = fall[0] === 1 ? far : k
      }
      cells.push(x * SIDE + y)
    }
    const kept = cells.map((i) => g[i]).filter((c) => c !== null)
    cells.forEach((i, k) => {
      g[i] = k < kept.length ? kept[k] : UNKNOWN
    })
  }
  return g
}

// the slices possible from a board: each place in front of a known fruit, its path, its points, its kind (free: from a
// Pioupiou, costs no icon; fatal: the 5th slice of its colour, ends the game). Paths are memoized by target cell.
export function options(grid, limits, cache = new Map()) {
  const out = []
  PLACES.forEach((place, index) => {
    const col = grid[place.target]
    if (col == null || col < 0) return
    let entry = cache.get(place.target)
    if (entry === undefined) {
      const path = getPath(grid, place.target)
      entry = path ? { path, score: pathScore(grid, path) } : null
      cache.set(place.target, entry)
    }
    if (!entry) return
    const free = col === PIOUPIOU
    out.push({ index, place, col, path: entry.path, score: entry.score, free, fatal: !free && (limits[col] ?? 0) >= POOL_MAX })
  })
  return out
}

const nextLimits = (limits, option) => {
  if (option.free) return limits
  const l = limits.slice()
  l[option.col] = (l[option.col] ?? 0) + 1
  return l
}

// the most points certain in `depth` slices from a board (the slices that do not end the game first, any slice when
// all of them do; a slice that ends the game ends the sequence)
function bestValue(grid, limits, depth, memo) {
  if (depth <= 0) return 0
  const id = depth + ':' + limits.join(',') + ':' + grid.join(',')
  const known = memo.get(id)
  if (known !== undefined) return known
  const opts = options(grid, limits)
  const open = opts.filter((o) => !o.fatal)
  let best = 0
  for (const o of open.length ? open : opts) {
    const v = o.score + (depth > 1 && !o.fatal ? bestValue(afterSlice(grid, o.path, o.place.fall), nextLimits(limits, o), depth - 1, memo) : 0)
    if (v > best) best = v
  }
  memo.set(id, best)
  return best
}

// a slice of a fruit (not a Pioupiou) from the place `played` (index in PLACES) against the other slices of a fruit
// the player could make from the same board (limits: the icons of each colour before the slice). Free slices (from a
// Pioupiou) are not candidates: they cost nothing and stay for later. The slices that end the game are candidates
// only when every slice does (the last slice), and a slice that ends the game while others do not is `early`.
//   best / value: points of the best candidate / of the slice played (immediate)
//   optimal: the slice played makes as many points as the best
//   close: a candidate worse than the best makes at least closeRatio of its points (the choice is not obvious: the
//          only ones that discriminate a player from a solver)
//   lookahead* (depth > 1): the same, adding the most points certain in the next depth - 1 slices
export function rateSlice(grid, limits, played, { depth = 1, closeRatio = 0.6 } = {}) {
  const cache = new Map()
  const all = options(grid, limits, cache).filter((o) => !o.free)
  const move = all.find((o) => o.index === played)
  if (!move) return null
  const open = all.filter((o) => !o.fatal)
  if (move.fatal && open.length) return { early: true, value: move.score, size: move.path.length }
  const candidates = open.length ? open : all
  let best = 0
  for (const o of candidates) if (o.score > best) best = o.score
  const close = candidates.some((o) => o.score < best && o.score >= best * closeRatio)
  const out = {
    early: false,
    best,
    value: move.score,
    optimal: move.score === best,
    close,
    size: move.path.length,
    bestSize: Math.max(...candidates.filter((o) => o.score === best).map((o) => o.path.length)),
    candidates: candidates.length,
  }
  if (depth > 1) {
    const memo = new Map()
    const valueOf = (o) => o.score + (o.fatal ? 0 : bestValue(afterSlice(grid, o.path, o.place.fall), nextLimits(limits, o), depth - 1, memo))
    let lookBest = 0
    const values = new Map()
    for (const o of candidates) {
      const v = valueOf(o)
      values.set(o.index, v)
      if (v > lookBest) lookBest = v
    }
    out.lookaheadBest = lookBest
    out.lookaheadValue = values.get(move.index)
    out.lookaheadOptimal = values.get(move.index) === lookBest
  }
  return out
}
