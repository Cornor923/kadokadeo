// node --test resources/js/replay-verifier/analyzers/paradice.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { COLS, EMPTY, fall, groupPoints, groups, ICE, place, rateMove, rateShifts, resolve,ROWS } from './paradice/solver.mjs'

// a grid from rows written top to bottom (the last row is y = 0, just above the line), one character by column x:
// '.' empty, a digit a colour, a letter a frozen ball of a colour (a = 0, b = 1...)
function grid(...rows) {
  const g = new Int8Array(COLS * ROWS).fill(EMPTY)
  rows.forEach((row, i) => {
    const y = rows.length - 1 - i
    ;[...row].forEach((c, x) => {
      if (c === '.') return
      g[x * ROWS + y] = c >= 'a' ? ICE + c.charCodeAt(0) - 97 : +c
    })
  })
  return g
}

const carried = (...list) => list.map(([x, col]) => ({ x, col }))

test('the points of a group: int((3n)^2 * 0.1) * 25 * multiplier (Game.initStep(0))', () => {
  assert.deepEqual([4, 5, 6, 7].map((n) => groupPoints(n, 1)), [350, 550, 800, 1100])
  assert.equal(groupPoints(4, 3), 1050)
})

test('a carried ball pushes its column up (Ground.updateGrid), the shift turns the row', () => {
  const g = grid('0.........', '1.........')
  assert.deepEqual(place(g, carried([9, 2]), 1), grid('0.........', '1.........', '2.........'))
  // x + shift mod 10 (3 + 7: column 0, 5 + 7: column 2), the other columns untouched
  assert.deepEqual(place(g, carried([3, 2], [5, 1]), 7), grid('0.........', '1.........', '2.1.......'))
})

test('the groups: 4 neighbours of a colour, never the frozen balls', () => {
  assert.equal(groups(grid('00........', '00........')).length, 1)
  // a diagonal does not join
  assert.equal(groups(grid('0.........', '.0........', '00........')).length, 0)
  // a frozen ball of the colour does not count
  assert.equal(groups(grid('0a........', '00........')).length, 0)
})

test('the balls fall: each column closes up (Game.initStep(1))', () => {
  const g = grid('2.........', '.1........', '1.........', '..........')
  assert.deepEqual(fall(g), grid('2.........', '11........'))
})

test('a group explodes, frees the frozen balls around it, the balls above fall and explode again (multiplier 2)', () => {
  // the four 0s explode (350); the 1 above falls next to the frozen 1s freed (Ball.checkBlast): four 1s (x2: 700)
  const g = grid(
    '1.........',
    '0b........',
    '0b........',
    '0b........',
  )
  const r = resolve(place(g, carried([0, 0]), 0))
  assert.equal(r.waves, 2)
  assert.equal(r.firstWave, 350)
  assert.equal(r.points, 350 + 700)
  assert.equal(r.grid.filter((v) => v !== EMPTY).length, 0)
})

test('Ball.BDIR never frees the frozen ball below on the left', () => {
  // the 0s at x = 1..2, y = 1..2 explode; the frozen ball at 0, 0 (below on the left of 1, 1) stays frozen
  const g = grid(
    '.00.......',
    '.00.......',
    'a34.......',
  )
  const r = resolve(g)
  assert.equal(r.points, 350)
  assert.equal(r.grid[0 * ROWS + 0], ICE + 0)
  // the one at 0, 1 (left of 1, 1) is freed (then falls)
  const g2 = grid('a00.......', '.00.......')
  assert.equal(resolve(g2).grid[0 * ROWS + 0], 0)
})

test('a ball left at y = 9 ends the game (Game.checkEnd); such a shift is worse than any other', () => {
  const tall = grid('..........', '0.........', '1.........', '0.........', '1.........', '0.........', '1.........', '0.........', '1.........', '0.........')
  assert.equal(resolve(place(tall, carried([0, 2]), 0)).ends, true)
  assert.equal(resolve(place(tall, carried([0, 2]), 1)).ends, false)
})

test('the best move needs a chain of explosions, not the biggest group seen at a glance (deep)', () => {
  // one 2 carried (at x = 0 of the row: the shift is its column). Column 0: five 2s with the one at 1, 3 (550). Column
  // 4, 5 or 6: four 2s with the column 5 (350), then the 0 on top of it falls between the 0s: four 0s (x2: 700)
  const g = grid(
    '.2...0....',
    '23...2....',
    '24..02....',
    '23..020...',
  )
  const c = carried([0, 2])
  const shifts = rateShifts(g, c)
  assert.deepEqual(shifts.map((r) => r.points), [550, 350, 0, 0, 1050, 1050, 1050, 0, 0, 0])
  assert.deepEqual(shifts.map((r) => r.firstWave), [550, 350, 0, 0, 350, 350, 350, 0, 0, 0])
  const greedy = rateMove(g, c, 0)
  assert.equal(greedy.optimal, false)
  assert.equal(greedy.greedy, true)
  assert.equal(greedy.deep, true)
  assert.equal(greedy.value, 550)
  assert.equal(greedy.best, 1050)
  const chain = rateMove(g, c, 15)
  assert.equal(chain.optimal, true)
  assert.equal(chain.greedy, false)
  assert.equal(chain.waves, 2)
  assert.equal(chain.chance, 0.3)
  assert.equal(chain.decision, true)
})

test('a move that ends the game is never the best one; a decision is a choice between scoring moves', () => {
  // the shift 0 makes four 1s at x = 0 (350) but leaves a ball at y = 9 (a 3 pushed at x = 1): the 350 of the shift 5
  // (four 1s at x = 3..5) is the best
  const g = grid(
    '.0........',
    '.3........',
    '.0........',
    '.3........',
    '.0........',
    '.3........',
    '10........',
    '13.1......',
    '10.11.....',
  )
  const c = carried([0, 1], [1, 3])
  const shifts = rateShifts(g, c)
  assert.equal(shifts[0].ends, true)
  assert.equal(shifts[0].points, 350)
  const r = rateMove(g, c, 0)
  assert.equal(r.optimal, false)
  assert.equal(r.value, 0)
  assert.equal(r.best, 350)
  assert.equal(rateMove(g, c, 5).optimal, true)
  // nothing scores: not a decision
  const none = rateMove(grid('0.........'), carried([0, 1]), 0)
  assert.equal(none.decision || none.easy, false)
  // one way to score (four 1s at x = 0): easy, not a decision
  const one = rateMove(grid('1.........', '1.........', '1.........'), carried([0, 1]), 3)
  assert.deepEqual([one.decision, one.easy, one.optimal, one.best], [false, true, false, 350])
  // the scoring shifts make the same points: easy
  assert.deepEqual([r.decision, r.easy], [false, true])
})
