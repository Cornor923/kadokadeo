// node --test resources/js/replay-verifier/analyzers/xianxiang.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { create } from './xianxiang.mjs'
import { maxWeightMatching } from './xianxiang/matching.mjs'
import { afterMove, bound, cardCode, connectable, EMPTY, H, matchs, moves, newContext, perfectLine, pointsOf, rateMove, reachable, TYPICAL_ERRORS, typicalErrorRate, W } from './xianxiang/solver.mjs'

// a board as text: one row per line, cards "<socle c|t|s><color 0-3><symbol 0-4>", "..." empty; index y * 6 + x
const SOCLES = 'cts'
const parse = (text) => text.trim().split('\n').flatMap((row) => row.trim().split(/\s+/).map((c) => (c === '...' ? EMPTY : cardCode(SOCLES.indexOf(c[0]), +c[1], +c[2]))))
const at = (x, y) => y * W + x

// a board of distinct cards (every pair worth 1 point or more), then holes in it
const FULL = Array.from({ length: W * H }, (_, i) => cardCode(i % 3, Math.floor(i / 3) % 4, Math.floor(i / 12) % 5))

test('CardID.matchs and Const.POINTS_ENCODE', () => {
  assert.equal(matchs(cardCode(1, 2, 3), cardCode(1, 2, 3)), 3)
  assert.equal(matchs(cardCode(1, 2, 3), cardCode(1, 2, 4)), 2)
  assert.equal(matchs(cardCode(1, 2, 3), cardCode(0, 2, 4)), 1)
  assert.equal(matchs(cardCode(1, 2, 3), cardCode(2, 0, 4)), 0)
  assert.equal(pointsOf(cardCode(1, 2, 3), cardCode(1, 2, 3)), 1000)
  assert.equal(pointsOf(cardCode(1, 2, 3), cardCode(1, 0, 3)), 300)
  assert.equal(pointsOf(cardCode(2, 2, 3), cardCode(1, 0, 3)), 50)
  assert.equal(pointsOf(cardCode(2, 2, 4), cardCode(1, 0, 3)), 1)
})

test('full board: only the neighbours (no path around the board)', () => {
  assert.deepEqual([...reachable(FULL, at(0, 0))].sort((a, b) => a - b), [at(1, 0), at(0, 1)])
  assert.deepEqual([...reachable(FULL, at(2, 3))].sort((a, b) => a - b), [at(2, 2), at(1, 3), at(3, 3), at(2, 4)])
  // 5 * 7 horizontal + 6 * 6 vertical neighbours
  assert.equal(moves(FULL).length, 71)
  assert.ok(!connectable(FULL, at(0, 0), at(5, 0)))
})

test('Level.computePath: straight lines and one turn through empty cells, not two', () => {
  const board = parse(`
    c00 ... ... ... ... c01
    c02 c03 c04 c10 ... c11
    c12 c13 c14 c20 ... c21
    c22 c23 c24 c30 c31 c32
    c33 c34 c40 c41 c42 c43
    c44 t00 t01 t02 t03 t04
    t10 t11 t12 t13 t14 t20`)
  // a row of empty cells
  assert.ok(connectable(board, at(0, 0), at(5, 0)))
  // one turn: (0,0) right then down to (4,3) through (4,0) (4,1) (4,2)
  assert.ok(connectable(board, at(0, 0), at(4, 3)))
  // (3,1) right to (4,1), down (4,2) to (4,3): one turn
  assert.ok(connectable(board, at(3, 1), at(4, 3)))
  // (2,1) up to (2,0), right to (4,0), down (4,1) (4,2) to (4,3): two turns
  assert.ok(!connectable(board, at(2, 1), at(4, 3)))
  // (3,1) up then right to (5,0): one turn
  assert.ok(connectable(board, at(3, 1), at(5, 0)))
  // (5,1) down blocked by (5,2), left to (4,1) then down to (4,3): one turn
  assert.ok(connectable(board, at(5, 1), at(4, 3)))
  // (5,2) left to (4,2) then up/down: (4,3) reached, (3,2) neighbour
  assert.ok(connectable(board, at(5, 2), at(4, 3)))
  // (0,1) up to (0,0)? a neighbour card: yes; (1,1) to (5,0): up, right through (2..4,0): one turn
  assert.ok(connectable(board, at(1, 1), at(5, 0)))
  // (1,1) to (5,1): up, right, down: two turns
  assert.ok(!connectable(board, at(1, 1), at(5, 1)))
})

test('the last two cards always meet (corner of their rectangle empty)', () => {
  const board = new Array(W * H).fill(EMPTY)
  board[at(0, 0)] = cardCode(0, 0, 0)
  board[at(5, 6)] = cardCode(1, 1, 1)
  assert.ok(connectable(board, at(0, 0), at(5, 6)))
  assert.deepEqual(moves(board), [[at(0, 0), at(5, 6), 1]])
  assert.deepEqual(moves(afterMove(board, at(0, 0), at(5, 6))), [])
})

// a small seeded random (the tests stay the same from run to run)
const random = (seed) => () => {
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed / 2147483648
}

test('Level.computePath is a path of one turn at most inside the board (random boards)', () => {
  const free = (b, x, y) => b[at(x, y)] === EMPTY
  // the cells strictly between two cells of a line are empty
  const clear = (b, x1, y1, x2, y2) => {
    for (let x = Math.min(x1, x2), y = Math.min(y1, y2); x <= Math.max(x1, x2) && y <= Math.max(y1, y2); x1 === x2 ? y++ : x++) {
      if (!((x === x1 && y === y1) || (x === x2 && y === y2)) && !free(b, x, y)) return false
    }
    return true
  }
  const oneTurn = (b, a, c) => {
    const [ax, ay, cx, cy] = [a % W, Math.floor(a / W), c % W, Math.floor(c / W)]
    if (ax === cx || ay === cy) return clear(b, ax, ay, cx, cy)
    return (free(b, cx, ay) && clear(b, ax, ay, cx, ay) && clear(b, cx, ay, cx, cy)) ||
      (free(b, ax, cy) && clear(b, ax, ay, ax, cy) && clear(b, ax, cy, cx, cy))
  }
  const rnd = random(7)
  for (let t = 0; t < 300; t++) {
    const holes = rnd()
    const board = Array.from({ length: W * H }, () => (rnd() < holes ? EMPTY : 0))
    for (let a = 0; a < W * H; a++) {
      if (board[a] === EMPTY) continue
      const targets = reachable(board, a)
      for (let c = 0; c < W * H; c++) {
        if (c !== a && board[c] !== EMPTY) assert.equal(targets.has(c), oneTurn(board, a, c), `board ${t}: ${a} -> ${c}`)
      }
    }
  }
})

test('maxWeightMatching: the best matching of small graphs (brute force)', () => {
  const brute = (n, w) => {
    const memo = new Map()
    const best = (mask) => {
      if (memo.has(mask)) return memo.get(mask)
      let i = 0
      while (i < n && (mask >> i) & 1) i++
      let value = 0
      if (i < n) {
        value = best(mask | (1 << i))
        for (let j = i + 1; j < n; j++) {
          if (!((mask >> j) & 1) && w[i][j] != null) value = Math.max(value, w[i][j] + best(mask | (1 << i) | (1 << j)))
        }
      }
      memo.set(mask, value)
      return value
    }
    return best(0)
  }
  const rnd = random(11)
  for (let t = 0; t < 400; t++) {
    const n = 2 + Math.floor(rnd() * 13)
    const w = Array.from({ length: n }, () => new Array(n).fill(null))
    const edges = []
    const dense = rnd() < 0.5
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        if (dense || rnd() < 0.6) {
          w[i][j] = [1, 50, 300, 1000, 7, 3][Math.floor(rnd() * 6)]
          edges.push([i, j, w[i][j]])
        }
      }
    }
    const mate = maxWeightMatching(edges)
    let total = 0
    mate.forEach((j, i) => {
      if (j > i) {
        assert.equal(mate[j], i)
        total += w[i][j]
      }
    })
    assert.equal(total, brute(n, w), `graph ${t}`)
  }
})

test('bound: identical cards first, then the best matching of the others', () => {
  const board = parse(`
    c00 c00 c00 c01 ... ...
    t00 t11 ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...`)
  // c00-c00 1000, then c00-c01 300 + t00-t11 50 (or c00-t00 300 + c01-t11 50), not c01-t00 50 + c00-t11 1
  assert.equal(bound(board), 1350)
  assert.equal(bound(new Array(W * H).fill(EMPTY)), 0)
  // the bound of the full board of distinct cards, with a memo
  const memo = new Map()
  const value = bound(FULL, memo)
  assert.equal(bound(FULL, memo), value)
  assert.equal(memo.size, 1)
})

// X c00 and Y c01 side by side, X' (the twin of X) and Z (shares nothing) side by side in the opposite corner: the
// moves scoring the most (X-Y, Y-X', 300) lose the 1000 of X-X'; the 1 point of Y-Z opens the path of the twins
const TRAP = parse(`
  c00 c01 ... ... ... ...
  ... ... ... ... ... ...
  ... ... ... ... ... ...
  ... ... ... ... ... ...
  ... ... ... ... ... ...
  ... ... ... ... ... ...
  ... ... ... ... t22 c00`)
const [X, Y, Z, X2] = [at(0, 0), at(1, 0), at(4, 6), at(5, 6)]

test('perfectLine and rateMove: the move scoring the most is a trap', () => {
  assert.equal(bound(TRAP), 1001)
  assert.ok(!connectable(TRAP, X, X2))
  assert.equal(perfectLine(TRAP, newContext(), 100), true)
  const best = rateMove(TRAP, Y, Z, newContext(), 100)
  assert.deepEqual([best.rated, best.discriminating, best.optimal, best.trap, best.greedy, best.lost], [true, true, true, true, false, 0])
  const greedy = rateMove(TRAP, X, Y, newContext(), 100)
  assert.deepEqual([greedy.rated, greedy.optimal, greedy.greedy, greedy.points, greedy.lost], [true, false, true, 300, 700])
  // the last two cards: one move, nothing to choose
  const last = rateMove(afterMove(TRAP, Y, Z), X, X2, newContext(), 100)
  assert.deepEqual([last.rated, last.discriminating, last.optimal], [true, false, true])
})

test('typicalErrorRate: traps and few good moves are harder', () => {
  const rating = (moves, losing, trap) => ({ moves, losing, trap })
  // 1 good move out of 40 (2.5 %), 4 (10 %), 8 (20 %), 20 (50 %)
  assert.equal(typicalErrorRate(rating(40, 39, true)), TYPICAL_ERRORS.trap[0])
  assert.equal(typicalErrorRate(rating(40, 36, true)), TYPICAL_ERRORS.trap[1])
  assert.equal(typicalErrorRate(rating(40, 32, false)), TYPICAL_ERRORS.plain[2])
  assert.equal(typicalErrorRate(rating(40, 20, false)), TYPICAL_ERRORS.plain[3])
  for (let level = 0; level < 4; level++) {
    assert.ok(TYPICAL_ERRORS.trap[level] > TYPICAL_ERRORS.plain[level])
    if (level) assert.ok(TYPICAL_ERRORS.trap[level] < TYPICAL_ERRORS.trap[level - 1] && TYPICAL_ERRORS.plain[level] < TYPICAL_ERRORS.plain[level - 1])
  }
})

test('perfectLine: twins crossed in a corner never meet (value under the bound), budget', () => {
  // A B / B A: each pair of twins is blocked by the other pair, whatever is played first
  const crossed = parse(`
    c00 t33 ... ... ... ...
    t33 c00 ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...
    ... ... ... ... ... ...`)
  assert.equal(bound(crossed), 2000)
  assert.equal(perfectLine(crossed, newContext(), 100), false)
  assert.deepEqual(rateMove(crossed, at(0, 0), at(1, 0), newContext(), 100), { rated: false })
  // the search gives up past its budget
  assert.equal(perfectLine(FULL, newContext(), 1), null)
})

test('analyzer: reads Level.tbl, rates the pairs removed between two frames', () => {
  const card = (code) => (code === EMPTY ? null : { id: { socle: Math.floor(code / 20), color: Math.floor(code / 5) % 4, symbol: code % 5 } })
  const tblOf = (board) => Array.from({ length: W }, (_, x) => Array.from({ length: H }, (_, y) => card(board[at(x, y)])))
  const kk = { game: { level: { tbl: tblOf(TRAP) } } }
  const analyzer = create({ kk, config: { min_decisions: 1, min_expected_errors: 0.2 } })
  analyzer.beforeFrame(10)
  analyzer.beforeFrame(11)
  // Y-Z removed during frame 40, X-X' during frame 70
  kk.game.level.tbl = tblOf(afterMove(TRAP, Y, Z))
  analyzer.beforeFrame(41)
  kk.game.level.tbl = tblOf(afterMove(afterMove(TRAP, Y, Z), X, X2))
  analyzer.beforeFrame(71)
  const { metrics, suspicious, reasons } = analyzer.finish({ score: 1001 })
  assert.equal(metrics.moves, 2)
  assert.deepEqual([metrics.decisions, metrics.optimal, metrics.traps, metrics.trapOptimal, metrics.rated], [1, 1, 1, 1, 2])
  // 6 moves, 1 keeps the value (17 %): a trap of level 2
  assert.equal(metrics.expectedErrors, +TYPICAL_ERRORS.trap[2].toFixed(2))
  assert.equal(metrics.valueRate, 1)
  assert.deepEqual([metrics.medianDecisionFrames, metrics.p10DecisionFrames], [30, 30])
  assert.ok(suspicious)
  assert.match(reasons[0], /^coup optimal 100 % du temps \(1 coups, limite 100 %\) sur des coups où un joueur se trompe 0,2 fois en moyenne \(minimum 0,2\)$/)
  // defaults: one decision is far from enough
  const quiet = create({ kk: { game: { level: { tbl: tblOf(TRAP) } } } })
  quiet.beforeFrame(0)
  assert.equal(quiet.finish({ score: 0 }).suspicious, false)
})

test('analyzer: a build without Level.tbl is not supported', () => {
  const analyzer = create({ kk: { game: { level: {} } } })
  assert.throws(() => analyzer.beforeFrame(0), /unsupported build/)
})
