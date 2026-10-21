// The rules of Cooking Lili (resources/hx/games/cookinglili) to value the moves of a player: a 10 x 10 board of tokens,
// index x * 10 + y (y = 0 at the top). A move swaps two neighbour tokens (Game.onClick, Level.swap); then, until the
// board is still, the groups of 3+ connected tokens of a kind explode (Level.check, Level.explode), unarming the frozen
// tokens next to them, and the tokens above fall (Level.gravity). Every round multiplies the points of its groups by its
// rank (Level.comboMul). Only after that comes the new line (Level.addLine, random): the value of a move is certain from
// the board, what a solver can show.
export const WID = 10
export const HEI = 10
export const EMPTY = -1
// a frozen token (Token.fl_armor): never part of a group, unarmed when a group next to it explodes
export const ARMOR = 16
// Cs.PTS_TOKEN, Cs.MIN_COMBO
const PTS_TOKEN = 5
const MIN_COMBO = 3

const NEIGHBOURS = []
for (let i = 0; i < WID * HEI; i++) {
  const x = Math.floor(i / HEI)
  const y = i % HEI
  // the order of Level.checkRec: left, right, up, down
  const list = []
  if (x > 0) list.push(i - HEI)
  if (x < WID - 1) list.push(i + HEI)
  if (y > 0) list.push(i - 1)
  if (y < HEI - 1) list.push(i + 1)
  NEIGHBOURS.push(list)
}

export const kindOf = (cell) => (cell === EMPTY ? EMPTY : cell & (ARMOR - 1))
export const isArmored = (cell) => cell !== EMPTY && (cell & ARMOR) !== 0

// Token.setId: the kinds 0..2 are worth 1, the later ones (more kinds after 15 and 35 rounds) 2, 3
export const mulOf = (kind) => (kind < 3 ? 1 : kind - 1)

// Level.checkRec: the n-th token of a group adds mul * n * n * PTS_TOKEN
export function groupScore(kind, size) {
  let score = 0
  for (let n = 1; n <= size; n++) score += mulOf(kind) * n * n * PTS_TOKEN
  return score
}

// Level.check: the groups of 3+ connected tokens of a kind, frozen tokens left out
export function groups(board) {
  const seen = new Uint8Array(WID * HEI)
  const out = []
  for (let i = 0; i < board.length; i++) {
    const cell = board[i]
    if (seen[i] || cell === EMPTY || isArmored(cell)) continue
    const cells = []
    const stack = [i]
    seen[i] = 1
    while (stack.length) {
      const j = stack.pop()
      cells.push(j)
      for (const k of NEIGHBOURS[j]) {
        if (!seen[k] && board[k] === cell) {
          seen[k] = 1
          stack.push(k)
        }
      }
    }
    if (cells.length >= MIN_COMBO) out.push({ kind: cell, cells })
  }
  return out
}

// Level.gravity: the tokens of every column fall to the bottom (y = HEI - 1), keeping their order
export function gravity(board) {
  for (let x = 0; x < WID; x++) {
    let to = x * HEI + HEI - 1
    for (let i = x * HEI + HEI - 1; i >= x * HEI; i--) {
      if (board[i] === EMPTY) continue
      if (i !== to) {
        board[to] = board[i]
        board[i] = EMPTY
      }
      to--
    }
  }
}

// the rounds after a swap (Game.check, Game.onEndExplosion, Game.onFelt), on a copy: points, tokens destroyed, rounds
// with groups, the board left (before the new line)
export function resolve(start) {
  const board = start.slice()
  let score = 0
  let cleared = 0
  let rounds = 0
  for (;;) {
    const found = groups(board)
    if (!found.length) break
    rounds++
    for (const g of found) {
      score += rounds * groupScore(g.kind, g.cells.length)
      cleared += g.cells.length
    }
    // Level.explodeRec: a frozen token next to an exploding one is unarmed
    for (const g of found) {
      for (const i of g.cells) board[i] = EMPTY
    }
    for (const g of found) {
      for (const i of g.cells) {
        for (const k of NEIGHBOURS[i]) {
          if (isArmored(board[k])) board[k] &= ARMOR - 1
        }
      }
    }
    gravity(board)
  }
  return { score, cleared, rounds, board }
}

// Level.different: a swap that changes the board (two kinds, or a frozen token with a free one)
export const different = (a, b) => a !== b

// every swap the player can make (Level.getPair: x, y with its right (dx 1) or lower (dy 1) neighbour)
export function moves(board) {
  const out = []
  for (let x = 0; x < WID; x++) {
    for (let y = 0; y < HEI; y++) {
      const i = x * HEI + y
      if (board[i] === EMPTY) continue
      if (x < WID - 1 && board[i + HEI] !== EMPTY && different(board[i], board[i + HEI])) out.push({ x, y, dx: 1, dy: 0 })
      if (y < HEI - 1 && board[i + 1] !== EMPTY && different(board[i], board[i + 1])) out.push({ x, y, dx: 0, dy: 1 })
    }
  }
  return out
}

export function swap(board, move) {
  const b = board.slice()
  const i = move.x * HEI + move.y
  const j = (move.x + move.dx) * HEI + move.y + move.dy
  const t = b[i]
  b[i] = b[j]
  b[j] = t
  return b
}

// a token left in the top row: the next line (Level.addLine) ends the game
export function topRowTaken(board) {
  for (let x = 0; x < WID; x++) {
    if (board[x * HEI] !== EMPTY) return true
  }
  return false
}

// the value of every move of the board: score (all rounds), direct (the points of the first round alone: the groups
// the swap makes, what a player sees at once), cleared, rounds, safe (the game goes on after it)
export function rateMoves(board) {
  // the board shown has no group (Level.addLine makes none): a swap scores only with a group through one of its cells
  const still = groups(board).length === 0
  const safeIfNothing = !topRowTaken(board)
  return moves(board).map((move) => {
    const b = swap(board, move)
    if (still && !groupThrough(b, move.x * HEI + move.y) && !groupThrough(b, (move.x + move.dx) * HEI + move.y + move.dy)) {
      return { ...move, score: 0, direct: 0, cleared: 0, rounds: 0, safe: safeIfNothing }
    }
    const r = resolve(b)
    let direct = 0
    for (const g of groups(b)) direct += groupScore(g.kind, g.cells.length)
    return { ...move, score: r.score, direct, cleared: r.cleared, rounds: r.rounds, safe: !topRowTaken(r.board) }
  })
}

// the cell is in a group of MIN_COMBO tokens or more
function groupThrough(board, start) {
  const cell = board[start]
  if (cell === EMPTY || isArmored(cell)) return false
  const seen = new Set([start])
  const stack = [start]
  while (stack.length) {
    const j = stack.pop()
    for (const k of NEIGHBOURS[j]) {
      if (!seen.has(k) && board[k] === cell) {
        seen.add(k)
        if (seen.size >= MIN_COMBO) return true
        stack.push(k)
      }
    }
  }
  return false
}

const sameMove = (a, b) => a.x === b.x && a.y === b.y && a.dx === b.dx && a.dy === b.dy

// the move played against the moves of the board. The best moves: the ones that score most among the ones that keep the
// game going (a solver would not show a move that ends it), all of them when none does.
//   choice: the decision says something (see below);
//   best: points of a best move; value: points of the move played; optimal: the move played is one of the best;
//   count: legal moves; scoring: moves that score; bestCount: the best moves; distinct: the different values of the
//   moves that score; danger: some move ends the game; bestDirect: the best points of a first round alone; greedy: the
//   move played is one of the best by its first round; hidden: no best move is among the best by its first round (their
//   points come from what falls after it: a cascade)
export function rateMove(board, move) {
  const rated = rateMoves(board)
  const played = rated.find((m) => sameMove(m, move))
  if (!played) return null
  const anySafe = rated.some((m) => m.safe)
  const candidates = anySafe ? rated.filter((m) => m.safe) : rated
  let best = 0
  let bestDirect = 0
  for (const m of candidates) {
    if (m.score > best) best = m.score
  }
  for (const m of rated) {
    if (m.direct > bestDirect) bestDirect = m.direct
  }
  const bestMoves = candidates.filter((m) => m.score === best)
  const scoring = rated.filter((m) => m.score > 0)
  return {
    // a choice: the best scores, and some move that scores is worth less (else any move that scores is the best)
    choice: best > 0 && candidates.some((m) => m.score > 0 && m.score < best),
    best,
    value: played.score,
    optimal: bestMoves.includes(played),
    count: rated.length,
    scoring: scoring.length,
    bestCount: bestMoves.length,
    distinct: new Set(scoring.map((m) => m.score)).size,
    danger: rated.some((m) => !m.safe),
    bestDirect,
    greedy: played.direct === bestDirect,
    hidden: bestMoves.every((m) => m.direct < bestDirect),
    played,
  }
}
