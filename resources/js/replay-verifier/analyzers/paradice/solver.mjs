// The rules of Paradice (resources/hx/games/paradice) to value the moves of a player. The grid: 10 columns, the stack
// grows upwards from y = 0 (just above the line), index x * ROWS + y. The penguins carry 1 to 10 balls at fixed places
// of their row; the player turns the row (Ground.dx) and validates: each carried ball is pushed into the bottom of its
// column (Ground.updateGrid). Then groups of 4+ balls of a colour (4 neighbours, frozen balls excluded) explode
// (Game.initStep(0)), free the frozen balls around them (Ball.checkBlast), the balls fall (Game.initStep(1)) and the
// new groups explode with a higher multiplier, until nothing explodes (Game.initStep(0), case dList empty). The game
// ends when a ball is left at y = 9 (Game.checkEnd).
// Everything a move makes is certain from the screen (the frozen balls show their colour); only the balls of the next
// turns are random (Ground.fill, Game.iceFall): a move is valued by its own points.
export const COLS = 10
// Cs.YMAX, plus the square y = 10 a push can reach (Flash's grid[x][10]: never in practice, see place)
export const ROWS = 11
export const EMPTY = -1
// a frozen ball: ICE + its colour
export const ICE = 10
// Cs.LIMIT_GAMEOVER
const LIMIT_GAMEOVER = 9
// Cs.YMAX: the squares Game.initStep(1) looks at
const YMAX = 10
// Cs.COMBO_SIZE
const COMBO_SIZE = 4

// Ball.BDIR: the frozen balls freed around an exploding ball (8 neighbours, but [-1, 0] twice and [-1, -1] missing)
const BDIR = [[1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, 0], [0, -1]]

const isGem = (v) => v >= 0 && v < ICE

// Game.initStep(0): Std.int(Math.pow(g.length * 3, 2) * 0.1) * 25 * multi (n * n: exact)
export function groupPoints(size, multi) {
  const n = size * 3
  return Math.trunc(n * n * 0.1) * 25 * multi
}

// a grid from the columns of the game (Game.grid[x][y]: null, or a ball with col and flIce)
export function gridOf(columns, read) {
  const g = new Int8Array(COLS * ROWS).fill(EMPTY)
  for (let x = 0; x < COLS; x++) {
    for (let y = 0; y < ROWS; y++) {
      const v = read(columns[x], y)
      if (v != null) g[x * ROWS + y] = v
    }
  }
  return g
}

// Ground.updateGrid: each carried ball {x, col} at the column (x + shift) mod 10 pushes the column up by one square
export function place(grid, carried, shift) {
  const g = Int8Array.from(grid)
  for (let i = carried.length - 1; i >= 0; i--) {
    const x = (((carried[i].x + shift) % COLS) + COLS) % COLS
    const base = x * ROWS
    // (y from YMAX - 1 down: a ball at y = 9 would go to 10; the game is over before a column is that high)
    for (let y = YMAX - 1; y >= 0; y--) {
      if (g[base + y] !== EMPTY) {
        g[base + y + 1] = g[base + y]
        g[base + y] = EMPTY
      }
    }
    g[base] = carried[i].col
  }
  return g
}

// Game.getGroups: the balls of a colour joined by their 4 neighbours (CDIR [0, 1] and [-1, 0], merged both ways),
// frozen balls apart; only the groups of COMBO_SIZE+ balls
export function groups(grid) {
  const seen = new Uint8Array(COLS * ROWS)
  const out = []
  for (let i = 0; i < grid.length; i++) {
    const color = grid[i]
    if (seen[i] || !isGem(color)) continue
    const cells = []
    const stack = [i]
    seen[i] = 1
    while (stack.length) {
      const j = stack.pop()
      cells.push(j)
      const x = Math.floor(j / ROWS)
      const y = j % ROWS
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx
        const ny = y + dy
        if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue
        const k = nx * ROWS + ny
        if (!seen[k] && grid[k] === color) {
          seen[k] = 1
          stack.push(k)
        }
      }
    }
    if (cells.length >= COMBO_SIZE) out.push(cells)
  }
  return out
}

// Game.initStep(1) + main() step 1: the balls of the squares y < YMAX fall until they rest on a ball or the line (the
// lower balls of a column move first: the column closes up)
export function fall(grid) {
  for (let x = 0; x < COLS; x++) {
    const base = x * ROWS
    let to = 0
    for (let y = 0; y < YMAX; y++) {
      const v = grid[base + y]
      if (v === EMPTY) continue
      if (y !== to) {
        grid[base + to] = v
        grid[base + y] = EMPTY
      }
      to++
    }
  }
  return grid
}

// the explosions after a push, until nothing explodes: points (multiplier 1, 2, 3... by wave: Game.multi), the points
// of the first wave (what is seen at a glance), the number of waves, the grid left, the end of the game
export function resolve(grid) {
  const g = Int8Array.from(grid)
  let points = 0
  let firstWave = 0
  let waves = 0
  for (;;) {
    const list = groups(g)
    if (!list.length) break
    waves++
    let wave = 0
    const destroyed = []
    for (const cells of list) {
      wave += groupPoints(cells.length, waves)
      for (const i of cells) destroyed.push(i)
    }
    // Game.main step 0: each ball explodes (Ball.kill) then frees the frozen balls around it (Ball.checkBlast)
    for (const i of destroyed) {
      g[i] = EMPTY
      const x = Math.floor(i / ROWS)
      const y = i % ROWS
      for (const [dx, dy] of BDIR) {
        const nx = x + dx
        const ny = y + dy
        if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue
        const k = nx * ROWS + ny
        if (g[k] >= ICE) g[k] -= ICE
      }
    }
    fall(g)
    points += wave
    if (waves === 1) firstWave = wave
  }
  let ends = false
  for (let x = 0; x < COLS; x++) if (g[x * ROWS + LIMIT_GAMEOVER] !== EMPTY) ends = true
  return { points, firstWave, waves, grid: g, ends }
}

// every shift of the row (0..9: the final Ground.dx mod 10) valued
export function rateShifts(grid, carried) {
  const out = []
  for (let s = 0; s < COLS; s++) {
    const r = resolve(place(grid, carried, s))
    out.push({ shift: s, points: r.points, firstWave: r.firstWave, waves: r.waves, ends: r.ends })
  }
  return out
}

// the move of the player (the final shift) against the other shifts. A shift that ends the game is worse than any
// other (unless they all do). best: the most points; optimal: the shift played makes them; greedy: it makes the most
// points of the first wave (the groups seen at a glance); deep: no greedy shift makes the best points (the best move
// needs a chain of explosions, a frozen ball freed, a fall); chance: the share of the shifts that are optimal (what
// a random shift would get). decision: at least two shifts score, and not the same points (a choice between scoring
// moves); easy: one way to score only (finding a group to complete: every player does), not a decision
export function rateMove(grid, carried, played) {
  const shifts = rateShifts(grid, carried)
  const alive = shifts.filter((r) => !r.ends)
  const pool = alive.length ? alive : shifts
  const best = Math.max(...pool.map((r) => r.points))
  const firstBest = Math.max(...pool.map((r) => r.firstWave))
  const isOptimal = (r) => pool.includes(r) && r.points === best
  const isGreedy = (r) => pool.includes(r) && r.firstWave === firstBest
  const mine = shifts[(((played % COLS) + COLS) % COLS)]
  const optimalCount = shifts.filter(isOptimal).length
  const scores = new Set(pool.filter((r) => r.points > 0).map((r) => r.points)).size
  return {
    best,
    value: mine.ends && alive.length ? 0 : mine.points,
    optimal: isOptimal(mine),
    greedy: isGreedy(mine),
    deep: best > 0 && !shifts.some((r) => isGreedy(r) && isOptimal(r)),
    ends: mine.ends,
    waves: mine.waves,
    chance: optimalCount / COLS,
    decision: scores >= 2,
    easy: scores === 1 && optimalCount < COLS,
  }
}
