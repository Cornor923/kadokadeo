// node --test resources/js/replay-verifier/analyzers/razor.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { afterSlice, getPath, options, pathScore, placeIndex, PLACES, rateSlice, ringDistance, SIDE, slip, UNKNOWN } from './razor/solver.mjs'

// a grid from rows y = 0..5, one character by column x: 0-2 a fruit, P a Pioupiou, . unknown
function grid(...rows) {
  const g = new Array(SIDE * SIDE)
  rows.forEach((row, y) => [...row].forEach((c, x) => { g[x * SIDE + y] = c === '.' ? UNKNOWN : c === 'P' ? 3 : +c }))
  return g
}
const cell = (x, y) => x * SIDE + y
const cells = (path) => path.map((i) => [Math.floor(i / SIDE), i % SIDE])
// the place of the razor in front of the cell x, y from a side (0 bottom, 1 left, 2 top, 3 right)
const BELOW = (x) => placeIndex(x, 6, 0)
const LEFT = (y) => placeIndex(-1, y, 1)
const ABOVE = (x) => placeIndex(x, -1, 2)
const RIGHT = (y) => placeIndex(6, y, 3)
// no two neighbours of the same colour: every path is one fruit
const CHECKER = ['012012', '120120', '201201', '012012', '120120', '201201']

test('the 24 places of the razor and the cell in front of each (Game.getSliceTarget)', () => {
  assert.equal(PLACES.length, 24)
  // the start of the game: moveRazorTo(3, 6), bdir 0, in front of 3, 5; its fruits fall down (y + 1, toward it)
  const start = PLACES[BELOW(3)]
  assert.equal(start.target, cell(3, 5))
  assert.deepEqual(start.fall, [0, 1])
  assert.equal(PLACES[LEFT(2)].target, cell(0, 2))
  assert.deepEqual(PLACES[LEFT(2)].fall, [-1, 0])
  assert.equal(PLACES[ABOVE(4)].target, cell(4, 0))
  assert.deepEqual(PLACES[ABOVE(4)].fall, [0, -1])
  assert.equal(PLACES[RIGHT(1)].target, cell(5, 1))
  assert.deepEqual(PLACES[RIGHT(1)].fall, [1, 0])
  // a corner cell is in front of two places
  assert.equal(PLACES.filter((p) => p.target === cell(0, 0)).length, 2)
  assert.equal(new Set(PLACES.map((p) => p.target)).size, 20)
})

test('Game.slip: the razor walks around the board, turning at the corners', () => {
  // right from the start: along the bottom row, then from 5, 6 to the right side (6, 5), skipping the corner
  assert.equal(slip(PLACES[BELOW(3)], 1), BELOW(4))
  assert.equal(slip(PLACES[BELOW(5)], 1), RIGHT(5))
  assert.equal(slip(PLACES[BELOW(0)], -1), LEFT(5))
  assert.equal(slip(PLACES[RIGHT(0)], 1), ABOVE(5))
  // 24 presses the same way: every place once, back to the start
  const seen = new Set()
  let p = BELOW(3)
  for (let i = 0; i < 24; i++) {
    seen.add(p)
    p = slip(PLACES[p], 1)
  }
  assert.equal(p, BELOW(3))
  assert.equal(seen.size, 24)
  assert.equal(ringDistance(BELOW(3), BELOW(3)), 0)
  assert.equal(ringDistance(BELOW(3), RIGHT(5)), 3)
  assert.equal(ringDistance(BELOW(3), LEFT(5)), 4)
  assert.equal(ringDistance(BELOW(0), ABOVE(5)), 12)
})

test('Game.getPath: the longest path, not the whole group; from a Pioupiou, Pioupious only', () => {
  // a T of 6 0s: a bar on the top row, a foot of 3 under its middle
  const g = grid(
    '000111',
    '101222',
    '101111',
    '202111',
    '111111',
    '111111',
  )
  // from the foot or an end of the bar: 5 fruits; from the middle of the bar: 4; never the 6 of the group
  assert.equal(getPath(g, cell(1, 3)).length, 5)
  assert.deepEqual(cells(getPath(g, cell(0, 0))), [[0, 0], [1, 0], [1, 1], [1, 2], [1, 3]])
  assert.equal(getPath(g, cell(1, 0)).length, 4)
  // a Pioupiou joins any colour, a path from a Pioupiou takes only Pioupious
  const p = grid('0P0111', '222222', '111111', '222222', '111111', 'P22222')
  assert.equal(getPath(p, cell(0, 0)).length, 3)
  assert.equal(getPath(p, cell(1, 0)).length, 1)
  assert.equal(getPath(p, cell(0, 5)).length, 1)
})

test('Game.getPath: between two paths of the same length, the one with fewer Pioupious', () => {
  // from 0, 2: to the right through a Pioupiou (found first: DIR begins with x + 1) or down without one, 3 fruits each
  const g = grid(
    '111111',
    '111111',
    '2P2111',
    '211111',
    '211111',
    '111111',
  )
  assert.deepEqual(cells(getPath(g, cell(0, 2))), [[0, 2], [0, 3], [0, 4]])
})

test('Ball.sliced: 200 + 50 by fruit already sliced, 1000 a Pioupiou', () => {
  const g = grid('00P000', ...CHECKER.slice(1))
  assert.equal(pathScore(g, [cell(0, 0)]), 200)
  assert.equal(pathScore(g, [cell(0, 0), cell(1, 0), cell(3, 0)]), 200 + 250 + 300)
  assert.equal(pathScore(g, [cell(0, 0), cell(1, 0), cell(2, 0), cell(3, 0)]), 200 + 250 + 1000 + 350)
})

test('Game.initFall: the fruits fall toward the razor, the holes far from it are unknown', () => {
  const g = grid(...CHECKER)
  // sliced from below (bdir 0): column 0, cells y = 4, 5 emptied, the column falls 2 cells
  const down = afterSlice(g, [cell(0, 4), cell(0, 5)], PLACES[BELOW(0)].fall)
  assert.deepEqual(down, grid('.12012', '.20120', '001201', '112012', '220120', '001201'))
  // sliced from the left (bdir 1): row 2, cell x = 0 emptied, the row moves left
  const left = afterSlice(g, [cell(0, 2)], PLACES[LEFT(2)].fall)
  assert.deepEqual(left, grid(CHECKER[0], CHECKER[1], '01201.', ...CHECKER.slice(3)))
  // from above: column 5, cell y = 0 emptied, the column moves up
  const up = afterSlice(g, [cell(5, 0)], PLACES[ABOVE(5)].fall)
  assert.deepEqual(up, grid('012010', '120121', '201202', '012010', '120121', '20120.'))
  // from the right: row 0 cell x = 5 emptied, the row moves right
  const right = afterSlice(g, [cell(5, 0)], PLACES[RIGHT(0)].fall)
  assert.deepEqual(right, grid('.01201', ...CHECKER.slice(1)))
})

test('the slices: free from a Pioupiou, fatal for the 5th of a colour', () => {
  const g = grid('P12012', ...CHECKER.slice(1))
  const opts = options(g, [4, 0, 0])
  assert.equal(opts.length, 24)
  assert.ok(opts.filter((o) => o.place.target === cell(0, 0)).every((o) => o.free && !o.fatal))
  assert.ok(opts.filter((o) => o.col === 0).every((o) => o.fatal))
  assert.ok(opts.filter((o) => o.col === 1).every((o) => !o.fatal))
})

// 3 2s on the top row, 4 0s on the bottom row, no other neighbours of the same colour
const BOARD = grid(
  '222010',
  '010121',
  '102012',
  '210120',
  '121201',
  '000012',
)

test('a slice against the best one of the board', () => {
  const best = rateSlice(BOARD, [0, 0, 0], BELOW(0))
  assert.equal(best.size, 4)
  assert.equal(best.best, 200 + 250 + 300 + 350)
  assert.equal(best.optimal, true)
  // the 2s from an end (750 of 1100): a choice close enough to count
  assert.equal(best.close, true)
  const twos = rateSlice(BOARD, [0, 0, 0], ABOVE(0))
  assert.equal(twos.size, 3)
  assert.equal(twos.value, 750)
  assert.equal(twos.optimal, false)
  // the 0s from the second one: the path goes one way only (3 fruits)
  const second = rateSlice(BOARD, [0, 0, 0], BELOW(1))
  assert.equal(second.size, 3)
  assert.equal(second.optimal, false)
  // the same 0s from the right end
  assert.equal(rateSlice(BOARD, [0, 0, 0], BELOW(3)).optimal, true)
  // with a stricter closeness nothing competes with the 0s (750 is 68 % of 1100): an obvious choice
  assert.equal(rateSlice(BOARD, [0, 0, 0], BELOW(0), { closeRatio: 0.7 }).close, false)
})

test('an obvious slice: one path far above the others, one place to start it', () => {
  // 3 0s up from the bottom of column 2, every other fruit alone (1s and 2s in a checker)
  const g = grid('121212', '212121', '121212', '210121', '120212', '210121')
  const r = rateSlice(g, [0, 0, 0], BELOW(2))
  assert.equal(r.best, 750)
  assert.equal(r.optimal, true)
  assert.equal(r.close, false)
})

test('a slice that ends the game is a candidate only when every slice does; free slices are not decisions', () => {
  // the 0s are exhausted (4 icons): the best slice is the 2s, slicing the 0s ends the game early
  const r = rateSlice(BOARD, [4, 0, 0], ABOVE(0))
  assert.equal(r.optimal, true)
  assert.equal(r.best, 750)
  assert.equal(rateSlice(BOARD, [4, 0, 0], BELOW(0)).early, true)
  // every colour exhausted: the last slice, the 0s are the best
  assert.equal(rateSlice(BOARD, [4, 4, 4], BELOW(0)).optimal, true)
  assert.equal(rateSlice(BOARD, [4, 4, 4], ABOVE(0)).optimal, false)
  // a slice from a Pioupiou is free: not rated
  const p = grid('P20120', ...CHECKER.slice(1))
  assert.equal(rateSlice(p, [0, 0, 0], ABOVE(0)), null)
})

test('looking ahead: the best two slices do not always begin with the biggest path', () => {
  // 5 0s on the bottom row right of a lone 1, 3 0s above the 1 (column 0)
  const g = grid(
    '210212',
    '102121',
    '021212',
    '012121',
    '021212',
    '100000',
  )
  const depth = 2
  // the biggest path now: the 5 0s
  const greedy = rateSlice(g, [0, 0, 0], BELOW(1), { depth })
  assert.equal(greedy.size, 5)
  assert.equal(greedy.optimal, true)
  assert.equal(greedy.lookaheadOptimal, false)
  // the 1 alone (200 points) from below: the column falls one cell, its 3 0s join the 5 others (8: 3000 points)
  const setUp = rateSlice(g, [0, 0, 0], BELOW(0), { depth })
  assert.equal(setUp.optimal, false)
  assert.equal(setUp.lookaheadValue, 200 + 3000)
  assert.equal(setUp.lookaheadOptimal, true)
  assert.ok(setUp.lookaheadValue > greedy.lookaheadValue)
  // the fall after the 1: the 0s down to the bottom, a fruit to come on top
  const after = afterSlice(g, [cell(0, 5)], PLACES[BELOW(0)].fall)
  assert.equal(getPath(after, cell(0, 3)).length, 8)
  assert.equal(after[cell(0, 0)], UNKNOWN)
})

test('the search is capped: over the limit, no path', () => {
  const g = grid('000000', '000000', '000000', '000000', '000000', '000000')
  assert.equal(getPath(g, cell(0, 0), 1000), null)
})
