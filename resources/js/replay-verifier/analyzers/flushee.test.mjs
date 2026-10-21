// node --test resources/js/replay-verifier/analyzers/flushee.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { explodingGroups, firstWave, moveIndex, play, push, rateDecision, rateMoves, resolve, UNKNOWN } from './flushee/solver.mjs'

// a grid from rows y = 0..6 (top to bottom), one character by column x = 0..5: a gem id (0-3 colors, 4 bonus, 5 tokens)
// or '.' (unknown)
function grid(...rows) {
  assert.equal(rows.length, 7)
  const g = new Array(42)
  rows.forEach((row, y) => [...row].forEach((c, x) => { g[x * 7 + y] = c === '.' ? UNKNOWN : +c }))
  return g
}

// no group: a checkerboard of 2 and 3
const CHECKER = ['232323', '323232', '232323', '323232', '232323', '323232', '232323']
// 5 (the tokens gem): never explodes, no points when pushed out

// Game.onClick from the left of row 6 with a 0 completes the 1s of column 1 (wave 1: 150); they explode, the 0 above
// them fall next to the 0s of column 0 (wave 2, a group of 5: 50 * 4 * 2). From the left of row 0, the 0 makes a group of 5 at
// once (wave 1: 200) and nothing falls into a group
const CASCADE = grid('000555', '555055', '505555', '515555', '015555', '015555', '155555')

test('a push shifts the row, the gem at the other end is pushed out', () => {
  const g = grid(...CHECKER.slice(0, 6), '012301')
  const left = push(g, 2, true, 6)
  assert.equal(left.pushed, 1)
  assert.deepEqual(left.grid, grid(...CHECKER.slice(0, 6), '201230'))
  const right = push(g, 2, false, 6)
  assert.equal(right.pushed, 0)
  assert.deepEqual(right.grid, grid(...CHECKER.slice(0, 6), '123012'))
})

test('groups of 4+ gems of a color explode, never the bonus gems', () => {
  assert.equal(explodingGroups(grid(...CHECKER)).length, 0)
  const g = grid('000023', '323232', '232323', '323232', '444423', '323232', '232323')
  assert.deepEqual(explodingGroups(g).map((c) => c.length), [4])
  // 50 * (n - 1) by group in wave 1 (Game.explode); the holes are unknown after the move (Game.fills)
  const five = grid('000003', ...CHECKER.slice(1))
  const r = resolve(five)
  assert.equal(r.points, 200)
  assert.equal(r.waves, 1)
  assert.deepEqual([0, 1, 2, 3, 4].map((x) => r.grid[x * 7]), [UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN])
})

test('the gems fall and the next waves count double, triple...', () => {
  const r = play(CASCADE, 0, true, 6)
  assert.equal(r.waves, 2)
  assert.equal(r.points, 150 + 400)
  // the columns fell: column 0 lost three 0s (the one pushed in among them), column 1 four 1s and two 0s
  assert.equal(r.pushed, 5)
  assert.deepEqual(r.grid.slice(0, 7), [UNKNOWN, UNKNOWN, UNKNOWN, 0, 5, 5, 5])
  assert.deepEqual(r.grid.slice(7, 14), [UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, 5])
})

test('a bonus pushed out: 1000 points and a token; the tokens gem: 5 tokens, 10 at most', () => {
  const g = grid(...CHECKER.slice(0, 5), '323234', '532323')
  const bonus = play(g, 0, true, 5, 3)
  assert.equal(bonus.points, 1000)
  assert.equal(bonus.tokens, 3)
  const tokens = play(g, 0, false, 6, 3)
  assert.equal(tokens.points, 0)
  assert.equal(tokens.tokens, 7)
  assert.equal(play(g, 0, false, 6, 9).tokens, 10)
})

test('the best move is not the one whose gem makes the biggest group at once', () => {
  const moves = rateMoves(CASCADE, 0, 1)
  const best = Math.max(...moves.map((m) => m.value))
  assert.equal(best, 550)
  assert.deepEqual(moves.filter((m) => m.value === best).map((m) => m.move), [moveIndex(true, 6)])
  // wave 1 only: 150, the group of 5 of row 0 is bigger (200)
  assert.deepEqual(firstWave(CASCADE, 0, true, 6), { points: 150, withCur: 0 })
  assert.deepEqual(firstWave(CASCADE, 0, true, 0), { points: 200, withCur: 200 })
  assert.equal(moves[moveIndex(true, 0)].value, 200)
})

test('looking 2 moves ahead: the gem pushed out is the next one, the new gems are unknown', () => {
  // the 1 pushed out of row 6 from the right completes the 1s of row 0 on the next move
  const g = grid('111055', '555555', '555555', '555555', '555555', '555555', '155555')
  const one = rateMoves(g, 3, 1)
  const two = rateMoves(g, 3, 2)
  const right6 = moveIndex(false, 6)
  assert.equal(one[right6].value, 0)
  assert.equal(two[right6].value, 150)
  // the last token: no next move
  assert.equal(rateMoves(g, 3, 2, 1)[right6].value, 0)
})

// CASCADE on unknown gems ('.': never in a group, nothing when pushed out)
const CASCADE_UNKNOWN = grid('000...', '...0..', '.0....', '.1....', '01....', '01....', '1.....')

test('a decision: the move played against the best of the 14', () => {
  const best = rateDecision(CASCADE_UNKNOWN, 0, 10, moveIndex(true, 6))
  assert.equal(best.counted, true)
  assert.equal(best.optimal, true)
  assert.equal(best.best, 550)
  assert.equal(best.bestMoves, 1)
  const greedy = rateDecision(CASCADE_UNKNOWN, 0, 10, moveIndex(true, 0))
  assert.equal(greedy.optimal, false)
  assert.equal(greedy.value, 200)
  // the bonus counts in the points, not in the points of the waves (Game.combo_score)
  const bonus = grid('......', '......', '......', '......', '......', '.....4', '......')
  const rating = rateDecision(bonus, 0, 5, moveIndex(true, 5))
  assert.equal(rating.value, 1000)
  assert.equal(rating.wavePoints[moveIndex(true, 5)], 0)
  assert.equal(rating.counted, true)
})

test('decisions that do not discriminate are not counted', () => {
  // no move scores
  assert.equal(rateDecision(grid('......', '......', '......', '......', '......', '......', '......'), 0, 10, 0).counted, false)
  // a tokens gem (row 3, from the left) against the points of the cascade: the best move depends on what a token is
  // worth (TOKEN_VALUES)
  const tokens = grid('000...', '...0..', '.0....', '.1...5', '01....', '01....', '1.....')
  assert.equal(rateDecision(tokens, 0, 5, moveIndex(true, 6)).counted, false)
  // the cascade pushes the tokens gem out: the best move whatever a token is worth
  const both = grid('000...', '...0..', '.0....', '.1....', '01....', '01....', '1....5')
  const rating = rateDecision(both, 0, 5, moveIndex(true, 6))
  assert.equal(rating.counted, true)
  assert.equal(rating.optimal, true)
})
