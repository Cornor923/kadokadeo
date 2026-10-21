// The rules of Flushee (resources/hx/games/flushee) to value the moves of a player: a 6 x 7 grid of gems, index
// x * 7 + y (y = 0 at the top). A move pushes the gem in hand (cur) into a row from the left or the right side
// (Game.onClick): the row shifts by one cell and the gem at the other end is pushed out, it is the next gem in hand.
// Then the groups of 4+ gems of a color explode (Game.explode, 50 * (n - 1) * wave points), the gems fall
// (Game.gravity), the new groups explode in the next wave... and only then the holes get new random gems (Game.fills,
// which never makes a group of 4: the gems it would make one with are drawn again). So everything a move scores is
// certain from the board shown: the new gems only matter for the next moves (UNKNOWN here).
export const WIDTH = 6
export const HEIGHT = 7
export const CELLS = WIDTH * HEIGHT
export const UNKNOWN = -1
// Cs.NGEMS colors (0..3), then Cs.ID_BONUS (+1000 points and +1 token when pushed out) and Cs.ID_TOKENS (+5 tokens)
export const COLORS = 4
export const BONUS = 4
export const TOKENS = 5
// Cs.NEXPLS, Cs.CMULT, Cs.C1000, Cs.NTOKENS, Cs.BIG_BONUS
export const MIN_GROUP = 4
export const GROUP_POINTS = 50
export const BONUS_POINTS = 1000
export const MAX_TOKENS = 10
export const BIG_BONUS = 5
// side true: pushed from the left (Game.onClick(side, y)); the 14 moves, index = (side ? 0 : HEIGHT) + y
export const MOVES = 2 * HEIGHT
export const moveIndex = (side, y) => (side ? 0 : HEIGHT) + y
export const moveOf = (index) => ({ side: index < HEIGHT, y: index % HEIGHT })

const EMPTY = -2
const NEIGHBOURS = []
for (let i = 0; i < CELLS; i++) {
  const x = Math.floor(i / HEIGHT)
  const y = i % HEIGHT
  const list = []
  if (x > 0) list.push(i - HEIGHT)
  if (x < WIDTH - 1) list.push(i + HEIGHT)
  if (y > 0) list.push(i - 1)
  if (y < HEIGHT - 1) list.push(i + 1)
  NEIGHBOURS.push(list)
}

// the groups that explode (Game.makeGroups + Game.explode): connected gems of a color (not a bonus), 4 or more
export function explodingGroups(grid) {
  const seen = new Uint8Array(CELLS)
  const out = []
  for (let i = 0; i < CELLS; i++) {
    const id = grid[i]
    if (seen[i] || id < 0 || id >= COLORS) continue
    const cells = [i]
    seen[i] = 1
    for (let k = 0; k < cells.length; k++) {
      for (const j of NEIGHBOURS[cells[k]]) {
        if (!seen[j] && grid[j] === id) {
          seen[j] = 1
          cells.push(j)
        }
      }
    }
    if (cells.length >= MIN_GROUP) out.push(cells)
  }
  return out
}

// Game.gravity until nothing moves: the gems of a column fall to the bottom
function gravity(grid) {
  for (let x = 0; x < WIDTH; x++) {
    let to = x * HEIGHT + HEIGHT - 1
    for (let i = to; i >= x * HEIGHT; i--) {
      if (grid[i] !== EMPTY) grid[to--] = grid[i]
    }
    while (to >= x * HEIGHT) grid[to--] = EMPTY
  }
}

// Game.onClick: the gem cur pushed into the row y from the left (side true) or the right; the gem pushed out
export function push(grid, cur, side, y) {
  const g = grid.slice()
  let pushed
  if (side) {
    pushed = g[(WIDTH - 1) * HEIGHT + y]
    for (let x = WIDTH - 1; x > 0; x--) g[x * HEIGHT + y] = g[(x - 1) * HEIGHT + y]
    g[y] = cur
  } else {
    pushed = g[y]
    for (let x = 0; x < WIDTH - 1; x++) g[x * HEIGHT + y] = g[(x + 1) * HEIGHT + y]
    g[(WIDTH - 1) * HEIGHT + y] = cur
  }
  return { grid: g, pushed }
}

// Game.nextMove after a push: explode (wave 1), fall, explode (wave 2)... until no group explodes; then the holes
// get new gems (unknown). points: the points of the waves (Game.combo_score, without the bonus)
export function resolve(grid) {
  const g = grid.slice()
  let points = 0
  let waves = 0
  let exploded = 0
  for (let wave = 1; ; wave++) {
    const groups = explodingGroups(g)
    if (!groups.length) break
    waves = wave
    for (const cells of groups) {
      for (const i of cells) g[i] = EMPTY
      points += GROUP_POINTS * (cells.length - 1) * wave
      exploded += cells.length
    }
    gravity(g)
  }
  for (let i = 0; i < CELLS; i++) if (g[i] === EMPTY) g[i] = UNKNOWN
  return { grid: g, points, waves, exploded }
}

// one move: its points (the waves + the bonus pushed out), the tokens it wins, the grid after it and the next gem
// tokens: the tokens before the move (the move costs one, Game.onClick; the gem pushed out gives some, Game.update)
export function play(grid, cur, side, y, tokens = MAX_TOKENS) {
  const { grid: pushedGrid, pushed } = push(grid, cur, side, y)
  const r = resolve(pushedGrid)
  let left = tokens - 1
  let bonus = 0
  if (pushed === BONUS) {
    bonus = BONUS_POINTS
    left += 1
  } else if (pushed === TOKENS) {
    left = Math.min(MAX_TOKENS, left + BIG_BONUS)
  }
  return { points: r.points + bonus, wavePoints: r.points, bonus, waves: r.waves, exploded: r.exploded, tokens: left, pushed, grid: r.grid }
}

// the gems of wave 1 only, groups that hold the gem pushed in (what a player sees first: his gem makes a group)
export function firstWave(grid, cur, side, y) {
  const { grid: g } = push(grid, cur, side, y)
  const at = side ? y : (WIDTH - 1) * HEIGHT + y
  let points = 0
  let withCur = 0
  for (const cells of explodingGroups(g)) {
    points += GROUP_POINTS * (cells.length - 1)
    if (cells.includes(at)) withCur += GROUP_POINTS * (cells.length - 1)
  }
  return { points, withCur }
}

// the 14 moves of a board: their points, looking `depth` moves ahead (depth 2: the best certain points of the next
// move with the gem pushed out, on the grid whose new gems are unknown): 14 x 14 moves at depth 2, about 1 ms
export function rateMoves(grid, cur, depth = 1, tokens = MAX_TOKENS) {
  const out = []
  for (let m = 0; m < MOVES; m++) {
    const { side, y } = moveOf(m)
    const r = play(grid, cur, side, y, tokens)
    let value = r.points
    if (depth > 1 && r.tokens > 0) {
      let next = 0
      const nextCur = r.pushed >= COLORS ? UNKNOWN : r.pushed
      if (nextCur !== UNKNOWN) {
        for (const n of rateMoves(r.grid, nextCur, depth - 1, r.tokens)) next = Math.max(next, n.value)
      }
      value += next
    }
    out.push({ move: m, points: r.points, value, waves: r.waves, pushed: r.pushed, tokens: r.tokens })
  }
  return out
}

// what a token is worth in points, for a player or a helper: from nothing to two moves of a good player (about 750
// points a move). A decision whose best move changes with it (a bonus or a tokens gem against points) has no best move
// of its own: it is not counted
export const TOKEN_VALUES = [0, 700, 1500]

// one decision of the player: the points of the move he played (played: moveIndex(side, y)) against the points of the
// 14 moves he could play, all certain from the board he saw (tokens: Game.tokens before the move).
// counted: the decision discriminates (a move scores, not all the same, a best move whatever a token is worth)
export function rateDecision(grid, cur, tokens, played) {
  const moves = []
  for (let m = 0; m < MOVES; m++) {
    const { side, y } = moveOf(m)
    moves.push(play(grid, cur, side, y, tokens))
  }
  const points = moves.map((r) => r.points)
  const best = Math.max(...points)
  // the moves best whatever a token is worth
  let agreed = null
  for (const tokenValue of TOKEN_VALUES) {
    const values = moves.map((r) => r.points + tokenValue * (r.tokens - (tokens - 1)))
    const top = Math.max(...values)
    const set = values.map((v, m) => (v === top ? m : -1)).filter((m) => m >= 0)
    agreed = agreed ? agreed.filter((m) => set.includes(m)) : set
  }
  const value = points[played]
  return {
    counted: best > 0 && best > Math.min(...points) && agreed.length > 0,
    optimal: value === best,
    value,
    best,
    // the moves that score the best
    bestMoves: points.filter((p) => p === best).length,
    points,
    // without the bonus: Game.combo_score
    wavePoints: moves.map((r) => r.wavePoints),
  }
}
