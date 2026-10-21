// The rules of Autrement (resources/hx/games/autrement) to value the moves of a player. The board is a 12 x 12 grid
// (Game.MAX), index x * 12 + y, its blocks come from the edges. The player moves a stamp (a core of 3 x 3 grey blocks,
// Stamp.new) over the free cells, turns it, and sticks to it the blocks it pushes against (Stamp.action): the groups of
// 4+ blocks of a color of the stamp burst (Game.SCORE_BURST by block), the blocks no longer linked to the core fall
// (Game.SCORE_FALL by block), a burst star recolors (no points), a burst shaker drops every block of the stamp but the
// core (SCORE_FALL by block). Everything is on the screen; the blocks the next turns bring are random (unknown): a move is
// valued by its points certain from the board only, what a solver can show.
//
// A cell: EMPTY or color | (option + 1) << 4 (Bloc.id, Bloc.option: 0 star, 1 shaker). The stamp: [x, y, cell] by block,
// coordinates relative to the stamp position (Stamp.x, Stamp.y).
export const MAX = 12
export const EMPTY = -1
export const CORE = 10
export const STAR = 0
export const SHAKER = 1
// Game.DIR
export const DIR = [[0, 1], [1, 0], [0, -1], [-1, 0]]
// Game.SCORE_BURST (by color), Game.SCORE_FALL
export const SCORE_BURST = [50, 50, 80, 120, 200, 300]
export const SCORE_FALL = 80

export const cell = (color, option = null) => color | (option == null ? 0 : (option + 1) << 4)
export const colorOf = (c) => c & 15
export const optionOf = (c) => (c >> 4) - 1

// BlocManager.isOut / isFree of the board
const isOut = (x, y) => x < 0 || x >= MAX || y < 0 || y >= MAX
const isFree = (board, x, y) => !isOut(x, y) && board[x * MAX + y] === EMPTY

// Stamp.getObstacle: the blocks of the board the stamp at x, y pushes against in the direction d (sorted indexes), null
// when a block of the stamp would leave the board. An empty list: the stamp can move.
export function obstacle(board, stamp, x, y, d) {
  const list = []
  for (const [bx, by] of stamp) {
    const nx = x + bx + d[0]
    const ny = y + by + d[1]
    if (isOut(nx, ny)) return null
    if (board[nx * MAX + ny] !== EMPTY) list.push(nx * MAX + ny)
  }
  return list.sort((a, b) => a - b)
}

// BlocManager.rotate: a quarter turn of the stamp
export const rotated = (stamp) => stamp.map(([bx, by, c]) => [by === 0 ? 0 : -by, bx, c])

// BlocManager.checkRotate: the turned stamp fits at x, y
const fits = (board, stamp, x, y) => stamp.every(([bx, by]) => isFree(board, x - by, y + bx))

// Stamp.checkRotate: the shift of the stamp when it turns ([0, 0]: none), null: it cannot turn
export function rotateShift(board, stamp, x, y) {
  if (fits(board, stamp, x, y)) return [0, 0]
  for (let dx = 0; dx < 3; dx++) {
    for (let dy = 0; dy < 3; dy++) {
      if (fits(board, stamp, x + dx - 1, y + dy - 1)) return [dx - 1, dy - 1]
    }
  }
  return null
}

// the stamp grid (Stamp.bm: 24 x 24, the core at 12, 12), the 4 neighbours of a cell (no wrap: the stamp never reaches
// the sides of its grid)
const SIDE = MAX * 2
const OFFSET = MAX
const CENTER = OFFSET * SIDE + OFFSET
const NEIGHBOURS = [-SIDE, SIDE, -1, 1]
const local = (bx, by) => (bx + OFFSET) * SIDE + by + OFFSET

// what the moves of a stamp (one turn) share: its grid, its cells, the groups of 4+ blocks it already has (a star
// recolors the blocks of the stamp too: Game.activeStar; getGroups bursts them at the next stick)
export function prepare(stamp) {
  const grid = new Int16Array(SIDE * SIDE).fill(EMPTY)
  const cells = []
  for (const [bx, by, c] of stamp) {
    grid[local(bx, by)] = c
    cells.push(local(bx, by))
  }
  const mark = new Int32Array(SIDE * SIDE)
  const ctx = { grid, cells, mark, gen: 0, work: new Int16Array(SIDE * SIDE), latent: [] }
  for (const i of cells) {
    if (mark[i] === -1) continue
    const group = flood(grid, i, mark, -1)
    if (group.length > 3 && colorOf(grid[i]) < CORE) ctx.latent.push(group)
  }
  return ctx
}

// the blocks of the color of the cell i linked to it, marked with gen
function flood(grid, i, mark, gen) {
  const color = colorOf(grid[i])
  const group = [i]
  mark[i] = gen
  for (let k = 0; k < group.length; k++) {
    for (const d of NEIGHBOURS) {
      const n = group[k] + d
      if (mark[n] !== gen && grid[n] !== EMPTY && colorOf(grid[n]) === color) {
        mark[n] = gen
        group.push(n)
      }
    }
  }
  return group
}

// Stamp.action then Stamp.updateBurst: the blocks `cells` of the board stuck to the stamp at x, y. Returns the points
// certain (bursts, falls, shaker) and what happened.
export function attach(board, stamp, x, y, cells) {
  return attachTo(prepare(stamp), board, x, y, cells)
}

export function attachTo(ctx, board, x, y, cells) {
  const grid = ctx.work
  grid.set(ctx.grid)
  const mark = ctx.mark
  const added = cells.map((i) => local(Math.floor(i / MAX) - x, (i % MAX) - y))
  cells.forEach((i, k) => { grid[added[k]] = board[i] })

  // BlocManager.getGroups: connected blocks of a color; 4+ of a color (not the core) burst. Only the groups of the
  // blocks stuck can be new
  const gen = ++ctx.gen
  const bursting = []
  for (const i of added) {
    if (mark[i] === gen) continue
    const group = flood(grid, i, mark, gen)
    if (group.length > 3 && colorOf(grid[i]) < CORE) bursting.push(...group)
  }
  for (const group of ctx.latent) {
    if (mark[group[0]] !== gen) bursting.push(...group)
  }

  let points = 0
  let star = false
  let shaker = false
  for (const i of bursting) {
    const c = grid[i]
    points += SCORE_BURST[colorOf(c)] ?? 0
    if (optionOf(c) === STAR) star = true
    if (optionOf(c) === SHAKER) shaker = true
    grid[i] = EMPTY
  }
  const burst = bursting.length

  // BlocManager.getFalls: the blocks no longer linked to the center of the stamp fall
  let falls = 0
  let kept = 0
  if (burst > 0) {
    const linked = ++ctx.gen
    mark[CENTER] = linked
    const stack = [CENTER]
    while (stack.length) {
      const j = stack.pop()
      for (const d of NEIGHBOURS) {
        const n = j + d
        if (mark[n] !== linked && grid[n] !== EMPTY) {
          mark[n] = linked
          stack.push(n)
        }
      }
    }
    for (const list of [ctx.cells, added]) {
      for (const i of list) {
        if (grid[i] === EMPTY) continue
        if (mark[i] !== linked) falls++
        else if (colorOf(grid[i]) !== CORE) kept++
      }
    }
  }
  points += falls * SCORE_FALL
  // Stamp.updateShaker: every block left but the core falls
  const shaken = shaker ? kept : 0
  points += shaken * SCORE_FALL
  return { points, burst, falls, shaken, star, shaker }
}

// every move the player could make from the stamp at x, y: the positions it reaches (moves to free cells, quarter
// turns), and from each one the directions where it pushes against blocks. visit(x, y, turns, steps, cells, result) by
// move (steps: moves + turns from the stamp; cells: a buffer, copy it to keep it; result: of attachTo).
export function eachMove(board, stamp, x, y, visit) {
  const shapes = [stamp]
  for (let r = 1; r < 4; r++) shapes.push(rotated(shapes[r - 1]))
  const contexts = []
  const steps = new Int16Array(MAX * MAX * 4).fill(-1)
  const queue = new Int32Array(MAX * MAX * 4)
  let tail = 0
  const push = (nx, ny, nr, at) => {
    const k = (nx * MAX + ny) * 4 + nr
    if (steps[k] < 0) {
      steps[k] = at
      queue[tail++] = k
    }
  }
  push(x, y, 0, 0)
  const list = []
  for (let q = 0; q < tail; q++) {
    const k = queue[q]
    const r = k & 3
    const sx = Math.floor(k / 4 / MAX)
    const sy = (k >> 2) % MAX
    const at = steps[k]
    const shape = shapes[r]
    for (const d of DIR) {
      // Stamp.getObstacle
      list.length = 0
      let out = false
      for (const b of shape) {
        const nx = sx + b[0] + d[0]
        const ny = sy + b[1] + d[1]
        if (isOut(nx, ny)) {
          out = true
          break
        }
        if (board[nx * MAX + ny] !== EMPTY) list.push(nx * MAX + ny)
      }
      if (out) continue
      if (list.length === 0) {
        push(sx + d[0], sy + d[1], r, at + 1)
      } else {
        contexts[r] ??= prepare(shape)
        visit(sx, sy, r, at, list, attachTo(contexts[r], board, sx, sy, list))
      }
    }
    const shift = rotateShift(board, shape, sx, sy)
    if (shift) push(sx + shift[0], sy + shift[1], (r + 1) % 4, at + 1)
  }
}

// the moves of eachMove in a list: { x, y, turns, steps, cells, points, burst, falls, shaken, star, shaker }
export function moves(board, stamp, x, y) {
  const out = []
  eachMove(board, stamp, x, y, (sx, sy, turns, steps, cells, result) => {
    out.push({ x: sx, y: sy, turns, steps, cells: cells.slice().sort((a, b) => a - b), ...result })
  })
  return out
}

// the move of the player (the blocks `cells` stuck to the stamp at x, y, as it is) against the best moves of the board:
// best (the most points of a move), value (the points of the move played), optimal (one of the best), the number of
// moves, of moves with points and of distinct point values. null: the blocks are not a move of the stamp at x, y.
export function rateMove(board, stamp, x, y, cells) {
  const played = cells.slice().sort((a, b) => a - b).join(',')
  const playable = DIR.some((d) => {
    const list = obstacle(board, stamp, x, y, d)
    return list !== null && list.length > 0 && list.join(',') === played
  })
  if (!playable) return null
  const move = attach(board, stamp, x, y, cells)
  let best = 0
  let count = 0
  let scoring = 0
  let bestSteps = Infinity
  let bestTurns = Infinity
  const values = new Set()
  eachMove(board, stamp, x, y, (sx, sy, turns, steps, list, result) => {
    count++
    const points = result.points
    if (points > 0) {
      scoring++
      values.add(points)
    }
    if (points > best) {
      best = points
      bestSteps = steps
      bestTurns = turns
    } else if (points === best) {
      bestSteps = Math.min(bestSteps, steps)
      bestTurns = Math.min(bestTurns, turns)
    }
  })
  return {
    best,
    value: move.points,
    optimal: move.points === best,
    burst: move.burst,
    moves: count,
    scoring,
    values: values.size,
    // the nearest best move: moves + turns of the stamp to reach it (0: from where the stamp is)
    bestSteps,
    bestTurns,
  }
}
