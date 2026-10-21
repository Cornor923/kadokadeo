// The rules of Xian-Xiang (resources/hx/games/xianxiang) to value the moves of a player: a 6 x 7 board of cards, index
// y * 6 + x, every card visible (no hidden information, no random after the deal). A move removes two cards joined by
// a path of at most one turn through empty cells inside the board (Level.computePath); it scores by the number of
// features the two cards share (CardID.matchs: socle, color, symbol): 1, 50, 300 or 1000 points (Const.POINTS_ENCODE).
import { maxWeightMatching } from './matching.mjs'

export const W = 6
export const H = 7
export const EMPTY = -1
export const POINTS = [1, 50, 300, 1000]
// Const.NTURNS
const TURNS = 1

// a card: its CardID as one number (socle 0..2, color 0..3, symbol 0..4)
export const cardCode = (socle, color, symbol) => socle * 20 + color * 5 + symbol

// CardID.matchs: the features two cards share (0..3)
export function matchs(a, b) {
  return (Math.floor(a / 20) === Math.floor(b / 20) ? 1 : 0) + (Math.floor(a / 5) % 4 === Math.floor(b / 5) % 4 ? 1 : 0) + (a % 5 === b % 5 ? 1 : 0)
}

export const pointsOf = (a, b) => POINTS[matchs(a, b)]

const DX = [-1, 0, 1, 0]
const DY = [0, -1, 0, 1]

// the cards a card can be removed with (Level.computePath: Level.fillColMapRec from the card, both cards taken off the
// board): m holds the turns left at each empty cell reached, a card met is a target (the path ends on it)
export function reachable(board, from) {
  const m = new Int8Array(W * H).fill(-1)
  const targets = new Set()
  const fill = (x, y, d, p) => {
    const i = y * W + x
    if (i !== from && board[i] !== EMPTY) {
      targets.add(i)
      return
    }
    if (m[i] > p) return
    m[i] = p
    for (let nd = 0; nd < 4; nd++) {
      const nx = x + DX[nd]
      const ny = y + DY[nd]
      if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue
      if (nd === d) fill(nx, ny, nd, p)
      else if (p > 0) fill(nx, ny, nd, p - 1)
    }
  }
  const x = from % W
  const y = Math.floor(from / W)
  for (let d = 0; d < 4; d++) fill(x, y, d, TURNS)
  targets.delete(from)
  return targets
}

export const connectable = (board, a, b) => a !== b && board[a] !== EMPTY && board[b] !== EMPTY && reachable(board, a).has(b)

// every move of a board: [a, b, points] with a < b
export function moves(board) {
  const out = []
  for (let a = 0; a < board.length; a++) {
    if (board[a] === EMPTY) continue
    for (const b of reachable(board, a)) {
      if (b > a) out.push([a, b, pointsOf(board[a], board[b])])
    }
  }
  return out
}

export function afterMove(board, a, b) {
  const next = board.slice()
  next[a] = EMPTY
  next[b] = EMPTY
  return next
}

// the most points the cards of a board can still make, paths aside: a maximum weight matching of the cards (every card
// is removed in the end, every pair scores 1 or more, so a maximum matching is perfect). Two identical cards are always
// paired in some best matching (exchange: X-A + Y-B -> X-Y + A-B gains 1000 + w(A, B) - 600 > 0), so they are taken out
// first and the matching runs on the cards left (distinct). memo: Map of the boards already valued (key: sorted cards).
export function bound(board, memo = null) {
  const cards = board.filter((c) => c !== EMPTY).sort((a, b) => a - b)
  const key = memo ? cards.join(',') : null
  if (memo && memo.has(key)) return memo.get(key)
  let total = 0
  const left = []
  for (let i = 0; i < cards.length; i++) {
    if (cards[i] === cards[i + 1]) {
      total += POINTS[3]
      i++
    } else left.push(cards[i])
  }
  const edges = []
  for (let i = 0; i < left.length; i++) {
    for (let j = i + 1; j < left.length; j++) edges.push([i, j, pointsOf(left[i], left[j])])
  }
  maxWeightMatching(edges).forEach((j, i) => {
    if (j > i) total += pointsOf(left[i], left[j])
  })
  if (memo) memo.set(key, total)
  return total
}

const OVER_BUDGET = new Error('over budget')

// the cells holding a card, as a key of the memos
const presence = (board) => board.map((c) => (c === EMPTY ? '0' : '1')).join('')

// Is there a line of moves scoring the bound of the board (the bound is then its exact value)? Depth first, the moves
// scoring the most first, a move kept only when its points plus the bound of the board after it still make the bound.
// true / false, or null when the search would visit more than `budget` boards. ctx: { bounds, lines } (memos).
export function perfectLine(board, ctx, budget) {
  let visited = 0
  const search = (b) => {
    const key = presence(b)
    const known = ctx.lines.get(key)
    if (known !== undefined) return known
    if (++visited > budget) throw OVER_BUDGET
    const target = bound(b, ctx.bounds)
    let found = !b.some((c) => c !== EMPTY)
    if (!found) {
      const list = moves(b).sort((m1, m2) => m2[2] - m1[2])
      for (const [x, y, points] of list) {
        const next = afterMove(b, x, y)
        if (points + bound(next, ctx.bounds) === target && search(next)) {
          found = true
          break
        }
      }
    }
    ctx.lines.set(key, found)
    return found
  }
  try {
    return search(board)
  } catch(e) {
    if (e === OVER_BUDGET) return null
    throw e
  }
}

export const newContext = () => ({ bounds: new Map(), lines: new Map() })

// The move a, b of the player on a board, against its exact value when it is the bound (perfectLine within budget):
//   rated: the value of the board is known (else nothing more: the opening, where the paths bind);
//   discriminating: some move of the board loses points for good (its points plus the bound after it are under the
//     value), so the choice mattered;
//   optimal: the move keeps the value (a line scoring it follows), null when the search after it ran out of budget;
//   greedy: the move scores the most points of the board; trap: some move scoring the most points loses (the obvious
//     move is wrong there); lost: the points the move loses for sure (its bound under the value; 0 when it keeps the
//     bound but no line scores it).
export function rateMove(board, a, b, ctx, budget) {
  const value = bound(board, ctx.bounds)
  if (perfectLine(board, ctx, budget) !== true) return { rated: false }
  const list = moves(board)
  let maxPoints = 0
  for (const m of list) maxPoints = Math.max(maxPoints, m[2])
  let losing = 0
  let trap = false
  for (const [x, y, points] of list) {
    if (points + bound(afterMove(board, x, y), ctx.bounds) < value) {
      losing++
      if (points === maxPoints) trap = true
    }
  }
  const points = pointsOf(board[a], board[b])
  const next = afterMove(board, a, b)
  const kept = points + bound(next, ctx.bounds)
  let optimal = false
  if (kept === value) {
    const line = perfectLine(next, ctx, budget)
    optimal = line === null ? null : line
  }
  return { rated: true, value, discriminating: losing > 0, moves: list.length, losing, optimal, greedy: points === maxPoints, trap, points, lost: value - kept }
}

// How often players miss the best move of a rated decision like this one: by trap (some move scoring the most loses)
// and by the share of the moves that keep the value (under 5 %, 15 %, 30 %, more): the fewer good moves, the harder.
// Measured on 5715 discriminating decisions of 513 runs (99 players) of the production copy, October 2026.
export const TYPICAL_ERRORS = {
  trap: [0.509, 0.395, 0.234, 0.146],
  plain: [0.141, 0.101, 0.067, 0.033],
}

// the chance that a typical player misses the best move of a discriminating rated decision (rateMove)
export function typicalErrorRate(rating) {
  const good = (rating.moves - rating.losing) / rating.moves
  const level = good < 0.05 ? 0 : good < 0.15 ? 1 : good < 0.3 ? 2 : 3
  return (rating.trap ? TYPICAL_ERRORS.trap : TYPICAL_ERRORS.plain)[level]
}
