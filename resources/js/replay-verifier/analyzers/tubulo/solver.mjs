// The rules of Tubulo (resources/hx/games/tubulo) to rate the clicks of a player: a 7 x 7 board of tubes (Cs.SIDE),
// index x * 7 + y, each of 3 colors (Cs.COL_MAX). A click (Game.clickTube) turns the tube and its 4 neighbours (Cs.DIR)
// to the next color, (id + 1) % 3; a level is solved when every tube has the same color, any of the 3 (Game.checkEnd).
// Over Z/3 a click adds the "plus" around the cell: the board is solved by the clicks x with board + A.x = c (mod 3),
// and the 49 x 49 matrix A is invertible mod 3: for each final color c there is exactly ONE set of clicks (0, 1 or 2 on
// each cell, clicks commute, 3 clicks on a cell do nothing) that solves the board. A solver shows it; a player finds it.
// (Cs.SCORE_TUBE: over a level the points of the clicks only depend on the first and last boards, 50 by tube of color
// 1; players solve to color 0, the color the level is drawn from in Game.genLevel.)
export const SIDE = 7
export const CELLS = SIDE * SIDE
export const COLORS = 3

// Cs.DIR + the cell itself (Game.clickTube)
const DIRS = [[0, 0], [1, 0], [0, 1], [-1, 0], [0, -1]]

// the cells a click on i changes
export const PLUS = []
for (let i = 0; i < CELLS; i++) {
  const x = Math.floor(i / SIDE)
  const y = i % SIDE
  const list = []
  for (const [dx, dy] of DIRS) {
    const nx = x + dx
    const ny = y + dy
    if (nx >= 0 && nx < SIDE && ny >= 0 && ny < SIDE) list.push(nx * SIDE + ny)
  }
  PLUS.push(list)
}

const mod3 = (v) => ((v % 3) + 3) % 3

// the inverse of A mod 3 (Gauss-Jordan once): INVERSE[i] = row i, the clicks on i are INVERSE[i] . (c - board)
const INVERSE = (() => {
  const m = []
  for (let i = 0; i < CELLS; i++) {
    const row = new Array(2 * CELLS).fill(0)
    for (const j of PLUS[i]) row[j] = 1 // A is symmetric
    row[CELLS + i] = 1
    m.push(row)
  }
  for (let c = 0; c < CELLS; c++) {
    let p = c
    while (p < CELLS && m[p][c] === 0) p++
    if (p === CELLS) throw new Error('the board matrix is not invertible mod 3')
    ;[m[c], m[p]] = [m[p], m[c]]
    // 1 * 1 = 2 * 2 = 1 mod 3: a value is its own inverse
    const inv = m[c][c]
    for (let k = 0; k < 2 * CELLS; k++) m[c][k] = (m[c][k] * inv) % 3
    for (let r = 0; r < CELLS; r++) {
      if (r === c || m[r][c] === 0) continue
      const f = m[r][c]
      for (let k = 0; k < 2 * CELLS; k++) m[r][k] = mod3(m[r][k] - f * m[c][k])
    }
  }
  return m.map((row) => Int8Array.from(row.slice(CELLS)))
})()

// a click on i (Game.clickTube): a new board
export function click(board, i) {
  const next = board.slice()
  for (const j of PLUS[i]) next[j] = (next[j] + 1) % COLORS
  return next
}

// the clicks (0, 1 or 2 by cell) that turn the board into a board of the color c: the only ones, up to 3 on a cell
export function solve(board, c) {
  const diff = board.map((v) => mod3(c - v))
  const x = new Int8Array(CELLS)
  for (let i = 0; i < CELLS; i++) {
    let s = 0
    const row = INVERSE[i]
    for (let j = 0; j < CELLS; j++) if (row[j] && diff[j]) s += row[j] * diff[j]
    x[i] = s % 3
  }
  return x
}

export const clicksOf = (x) => x.reduce((s, v) => s + v, 0)

// the solutions of the 3 colors: { x, clicks } by color
export function solutions(board) {
  const out = []
  for (let c = 0; c < COLORS; c++) {
    const x = solve(board, c)
    out.push({ x, clicks: clicksOf(x) })
  }
  return out
}

export const isSolved = (board) => board.every((v) => v === board[0])

// what a player sees at once: the "plus" signs drawn by the level (Game.genLevel undoes clicks: each one turns a plus to
// the previous color). A click is "visible" when the 5 cells of its plus (the cells on the board) all need a click to
// reach the color c: it needs no planning. Every other click of a solution needs the player to work out how the
// pluses overlap.
export function visible(board, i, c) {
  for (const j of PLUS[i]) if (board[j] === c) return false
  return true
}

// the click on i against the board seen and the color the player solved the level to (or heads to): in the
// solution (one of the clicks still needed), and whether it was visible
export function rateClick(board, i, c) {
  const x = solve(board, c)
  return { needed: x[i] > 0, visible: visible(board, i, c), remaining: clicksOf(x) }
}

// one try of a level: the board shown, the clicks ({ i, frames }), solved or left (reset, time over). The clicks are
// rated against the color the level was solved to or, left, the color nearest to the board shown (the fewest clicks:
// the color the level was drawn from, Game.genLevel; every level of the production replays is solved to it)
export function rateAttempt(start, clicks, { solved }) {
  let last = start
  for (const { i } of clicks) last = click(last, i)
  let color = 0
  if (solved && isSolved(last)) {
    color = last[0]
  } else {
    const all = solutions(start)
    for (let c = 1; c < COLORS; c++) if (all[c].clicks < all[color].clicks) color = c
  }
  const out = []
  let board = start
  for (const { i, frames } of clicks) {
    out.push({ i, frames, ...rateClick(board, i, color) })
    board = click(board, i)
  }
  return { color, minClicks: clicksOf(solve(start, color)), clicks: out }
}
