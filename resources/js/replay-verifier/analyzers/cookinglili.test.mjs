// node --test resources/js/replay-verifier/analyzers/cookinglili.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { create } from './cookinglili.mjs'
import { ARMOR, EMPTY, gravity, groups, groupScore, moves, rateMove, resolve } from './cookinglili/solver.mjs'

// a board from its last rows (the bottom one last), one char by column x: '.' empty, a digit: a token of that kind, a
// letter a..e: a frozen token of kind 0..4 (Token.fl_armor). The rows above are empty.
function board(...rows) {
  const b = new Array(100).fill(EMPTY)
  const pad = 10 - rows.length
  rows.forEach((row, r) => [...row.padEnd(10, '.')].forEach((c, x) => {
    if (c === '.') return
    b[x * 10 + r + pad] = /[a-e]/.test(c) ? c.charCodeAt(0) - 97 + ARMOR : +c
  }))
  return b
}

test('the points of a group: mul * n * n * 5 for its n-th token (Level.checkRec), mul by kind (Token.setId)', () => {
  assert.equal(groupScore(0, 3), 5 * (1 + 4 + 9))
  assert.equal(groupScore(2, 4), 5 * (1 + 4 + 9 + 16))
  // the kinds 3 and 4 (after 15 and 35 rounds, Level.endRound) are worth 2 and 3
  assert.equal(groupScore(3, 3), 2 * 70)
  assert.equal(groupScore(4, 3), 3 * 70)
})

test('the groups: 3+ connected tokens of a kind, frozen tokens left out (Level.check)', () => {
  const b = board(
    '0001112..2',
    '3a0....222',
  )
  // 000 + the 0 below (4), 111 (3), 2 + 222 (4); the frozen 0 (a) joins nothing
  assert.deepEqual(groups(b).map((g) => g.cells.length).sort(), [3, 4, 4])
  assert.deepEqual(groups(board('0a0', '0a0')), [])
})

test('gravity: the tokens of a column fall to the bottom in their order (Level.gravity)', () => {
  const b = board('0', '.', '1', '.', '.')
  gravity(b)
  assert.deepEqual(b, board('0', '1'))
})

test('the moves: only the swaps that change the board (Level.different), a frozen token with a free one of its kind too', () => {
  assert.deepEqual(moves(board('0a1')).map((m) => [m.x, m.y, m.dx, m.dy]), [[0, 9, 1, 0], [1, 9, 1, 0]])
  assert.deepEqual(moves(board('00')), [])
})

test('a frozen token is unarmed by a group exploding next to it (Level.explodeRec), then joins a group', () => {
  const b = board(
    '..1.......',
    '..1.......',
    '000b......',
  )
  // round 1: 000 (70), b unarmed; the two 1s fall next to it: round 2, 111 (2 * 70)
  const r = resolve(b)
  assert.equal(r.score, 70 + 2 * 70)
  assert.equal(r.rounds, 2)
  assert.equal(r.cleared, 6)
  // still frozen, b would have made nothing
  assert.equal(resolve(board('..1', '..1', '000c')).score, 70)
})

// x:  0123456789
const CASCADE = board(
  '.2........',
  '.1........',
  '013....0..',
  '2213.00103',
)
const A = { x: 1, y: 9, dx: 1, dy: 0 } // 111 in column 1 (70), then the 2 falls between two 2s: 222 x 2 (140)
const B = { x: 7, y: 8, dx: 0, dy: 1 } // 0000 in the bottom row at once (150), nothing after

test('a cascade: the round of a group multiplies its points (Level.comboMul)', () => {
  const r = resolve(boardAfter(CASCADE, A))
  assert.equal(r.score, 70 + 2 * 70)
  assert.equal(r.rounds, 2)
})

test('the best move is not the one with the biggest first group', () => {
  const a = rateMove(CASCADE, A)
  assert.equal(a.best, 210)
  assert.equal(a.value, 210)
  assert.equal(a.optimal, true)
  assert.equal(a.bestDirect, 150)
  assert.equal(a.greedy, false)
  // the best move scores by what falls after its first group: a player sees it less
  assert.equal(a.hidden, true)
  const b = rateMove(CASCADE, B)
  assert.equal(b.value, 150)
  assert.equal(b.optimal, false)
  assert.equal(b.greedy, true)
  // a swap that is not a move of the board
  assert.equal(rateMove(CASCADE, { x: 4, y: 9, dx: 1, dy: 0 }), null)
})

test('the decisions that say nothing: no swap scores, or every swap that scores is worth the best', () => {
  assert.equal(rateMove(CASCADE, A).choice, true)
  // 01 0: one swap makes 000, the other ones nothing
  const one = board('0.', '10.', '01')
  const r = rateMove(one, { x: 0, y: 8, dx: 0, dy: 1 })
  assert.equal(r.best, 70)
  assert.equal(r.optimal, true)
  assert.equal(r.choice, false)
  assert.equal(rateMove(board('0101010101'), { x: 0, y: 9, dx: 1, dy: 0 }).choice, false)
})

// x:  0123456789; the column 0 is full: the next line ends the game unless a swap takes tokens out of it
const DANGER = board(
  '1',
  '2',
  '1',
  '2',
  '1',
  '2',
  '1',
  '20........',
  '01.....0..',
  '02...0010.',
)
const SAFE = { x: 0, y: 7, dx: 1, dy: 0 } // 000 in the column 0 (70)
const UNSAFE = { x: 7, y: 8, dx: 0, dy: 1 } // 0000 in the bottom row (150), the column 0 still full

test('the best moves keep the game going: a solver would not show a swap after which the next line ends it', () => {
  const u = rateMove(DANGER, UNSAFE)
  assert.equal(u.value, 150)
  assert.equal(u.played.safe, false)
  assert.equal(u.danger, true)
  assert.equal(u.best, 70)
  assert.equal(u.optimal, false)
  const s = rateMove(DANGER, SAFE)
  assert.equal(s.value, 70)
  assert.equal(s.played.safe, true)
  assert.equal(s.optimal, true)
  // the only swap that saves the game: forced, not a decision
  assert.equal(s.choice, false)
})

// the game as the analyzer reads it (Game.step, Game.level.map, Game.currentRound, Game.swapPair)
function fakeGame(b) {
  const map = []
  for (let x = 0; x < 10; x++) {
    map[x] = []
    for (let y = 0; y < 10; y++) {
      const c = b[x * 10 + y]
      map[x][y] = c === EMPTY ? null : { id: c & (ARMOR - 1), fl_armor: (c & ARMOR) !== 0 }
    }
  }
  return { step: { _hx_name: 'Play' }, level: { map }, currentRound: null, swapPair: null }
}

test('the analyzer: the board while the game waits, the swap of the click, the lines added without a swap', () => {
  const game = fakeGame(CASCADE)
  const kk = { game, replay: { playFrames: [], playRecords: [] } }
  const analyzer = create({ kk, config: { min_decisions: 2 } })
  analyzer.beforeFrame(0)
  analyzer.beforeFrame(1)
  // a click at frame 40 (Game.onClick): a new round, the pair in swapPair
  game.step = { _hx_name: 'Resolve' }
  game.currentRound = { t: 1 }
  game.swapPair = { ...A, t1: {}, t2: {} }
  analyzer.beforeFrame(41)
  // the next board, then 15 s without a swap: a line added, the same round (Game.updateGame -> endRound)
  game.step = { _hx_name: 'Play' }
  analyzer.beforeFrame(100)
  game.step = { _hx_name: 'Resolve' }
  analyzer.beforeFrame(580)
  // the same board again, the swap B
  game.step = { _hx_name: 'Play' }
  analyzer.beforeFrame(600)
  game.step = { _hx_name: 'Resolve' }
  game.currentRound = { t: 2 }
  game.swapPair = { ...B }
  analyzer.beforeFrame(620)
  const { metrics, suspicious, reasons } = analyzer.finish({ score: 360, frames: 700 })
  assert.equal(metrics.decisions, 2)
  assert.equal(metrics.optimal, 1)
  assert.equal(metrics.optimalRate, 0.5)
  assert.equal(metrics.valueRate, +(360 / 420).toFixed(3))
  assert.equal(metrics.greedyRate, 0.5)
  assert.equal(metrics.cascadeDecisions, 2)
  assert.equal(metrics.swaps, 2)
  assert.equal(metrics.timeouts, 1)
  assert.deepEqual([metrics.p10DecisionFrames, metrics.medianDecisionFrames], [19, 40])
  // the best swap half of the time (limit 60 % by default), 86 % of the points of the best swaps (limit 70 %)
  assert.equal(suspicious, true)
  assert.deepEqual(reasons, ['86 % des points du meilleur échange (2 coups, limite 70 %)'])
  // under min_decisions (20 by default): nothing
  game.step = { _hx_name: 'Play' }
  const quiet = create({ kk, config: {} })
  quiet.beforeFrame(700)
  game.step = { _hx_name: 'Resolve' }
  game.currentRound = { t: 3 }
  game.swapPair = { ...A }
  quiet.beforeFrame(710)
  const few = quiet.finish({ score: 210, frames: 720 })
  assert.equal(few.metrics.optimalRate, 1)
  assert.equal(few.suspicious, false)
  // the same with min_decisions 1: both reasons
  game.step = { _hx_name: 'Play' }
  const one = create({ kk, config: { min_decisions: 1 } })
  one.beforeFrame(800)
  game.step = { _hx_name: 'Resolve' }
  game.currentRound = { t: 4 }
  one.beforeFrame(810)
  assert.deepEqual(one.finish({ score: 210, frames: 820 }).reasons, [
    'meilleur échange 100 % du temps (1 coups, limite 60 %)',
    '100 % des points du meilleur échange (1 coups, limite 70 %)',
  ])
})

test('the analyzer: an unknown build', () => {
  const kk = { game: { step: { _hx_name: 'Play' }, level: {} }, replay: { playFrames: [], playRecords: [] } }
  assert.throws(() => create({ kk, config: {} }).beforeFrame(0), /unsupported build/)
})

function boardAfter(b, m) {
  const out = b.slice()
  const i = m.x * 10 + m.y
  const j = (m.x + m.dx) * 10 + m.y + m.dy
  ;[out[i], out[j]] = [out[j], out[i]]
  return out
}
