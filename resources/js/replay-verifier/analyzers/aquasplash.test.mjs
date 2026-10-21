// node --test resources/js/replay-verifier/analyzers/aquasplash.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { analyzeDecision, bestNext, boardString, makeBoard, MAX_PLAYS, parseBoard, rateMove, simulate, value } from './aquasplash/solver.mjs'

const at = (x, y) => x * 6 + y
const EMPTY = ['......', '......', '......', '......', '......', '......']
const rows = (...first) => [...first, ...EMPTY].slice(0, 6)
const after = (o) => boardString(o.grow, o.bonus)

test('a click grows a slime; past 4 it explodes and its drops grow the first slime on each side', () => {
  // Slime.touch: 3 -> 4, nothing else
  const setUp = simulate(parseBoard(...rows('3.....')), at(0, 0), 10)
  assert.equal(setUp.explosions, 0)
  assert.equal(after(setUp), '4...../....../....../....../....../......')
  // Slime.explode (Drop.launch): the drop to the east flies over the empty cell to the 1, the others leave the board
  const o = simulate(parseBoard(...rows('4.1...', '......', '2.....')), at(0, 0), 10)
  assert.equal(o.explosions, 1)
  assert.equal(o.points, 250 + 10)
  assert.equal(after(o), '..2.../....../3...../....../....../......')
})

test('a chain: every explosion counts, a play won at 3 explosions (Cs.WIN_PLAYS)', () => {
  const o = simulate(parseBoard(...rows('444..1')), at(0, 0), 10)
  assert.equal(o.explosions, 3)
  assert.equal(o.won, 1)
  // Game.incExplode: SPOUT_POINTS + explosion * SPOUT_CHAIN
  assert.equal(o.points, 260 + 270 + 280)
  assert.equal(after(o), '.....2/....../....../....../....../......')
})

test('a 3 hit by two drops explodes', () => {
  // the click at (0, 0): (0, 1) explodes first (adjacent) and grows the 3 at (1, 1) to 4; (2, 0), then (2, 1), explode
  // later (further away) and the west drop of (2, 1) makes the 3 explode
  const o = simulate(parseBoard('4.4...', '434...', '......', '......', '......', '1.....'), at(0, 0), 10)
  assert.equal(o.explosions, 5)
  assert.deepEqual(o.hitFrames, [0, 5, 21, 26, 31])
  assert.equal(after(o), '....../....../....../....../....../2.....')
})

test('a drop hitting a bonus slime gives 6 plays, at most MAX_PLAYS', () => {
  const board = parseBoard(...rows('4..B.1'))
  const o = simulate(board, at(0, 0), 5)
  assert.equal(o.bonuses, 1)
  assert.equal(o.won, 6)
  // the drop is spent on the bonus: the 1 behind it does not grow
  assert.equal(o.grow[at(5, 0)], 1)
  assert.equal(simulate(board, at(0, 0), MAX_PLAYS - 2).won, 3)
  // a bonus slime cannot be clicked (Slime.touch)
  assert.equal(simulate(board, at(3, 0), 10), null)
})

test('a flame on an empty cell removes the slimes around it, never a bonus', () => {
  const board = parseBoard('B23...', '1.4...', '111...', '......', '......', '1.....')
  const o = simulate(board, at(1, 1), 10)
  assert.equal(o.removed, 7)
  assert.equal(o.points, 7 * 250)
  assert.equal(o.explosions, 0)
  assert.equal(after(o), 'B...../....../....../....../....../1.....')
})

test('a board left with bonus slimes only gives the next level: 2000 points and a play', () => {
  const o = simulate(parseBoard('B23...', '1.4...', '111...', '......', '......', '......'), at(1, 1), 10)
  assert.equal(o.level, true)
  assert.equal(o.won, 1)
  assert.equal(o.points, 7 * 250 + 2000)
  const chain = simulate(parseBoard(...rows('44....')), at(0, 0), 10)
  assert.equal(chain.level, true)
  assert.equal(chain.explosions, 2)
})

test('a drop flies through a slime that exploded before it arrived', () => {
  // the click at (2, 0): its east drop explodes (3, 0) at once, its west drop explodes (0, 0) later. The west drop of
  // (3, 0) crosses the empty (2, 0), finds (0, 0) already exploded and leaves the board: (0, 0) is not hit twice
  // and the 2 at (0, 1) is hit by the south drop of (0, 0) only
  const o = simulate(parseBoard('4.44..', '2.....', '......', '......', '......', '......'), at(2, 0), 10)
  assert.equal(o.explosions, 3)
  assert.equal(o.grow[at(0, 1)], 3)
})

test('a slime just grown to 4 swells for a few frames: drops hit it sooner', () => {
  // the same board, the 4 at (1, 0) at rest or in the first pictures of its goute (SlimeMC.goute)
  const grow = parseBoard(...rows('44....')).grow
  const rest = simulate(makeBoard(grow), at(0, 0), 10)
  const swollen = simulate(makeBoard(grow, null, Array.from({ length: 36 }, (_, i) => (i === at(1, 0) ? 2 : 0))), at(0, 0), 10)
  assert.equal(rest.explosions, 2)
  assert.equal(swollen.explosions, 2)
  assert.ok(swollen.hitFrames[1] < rest.hitFrames[1])
})

test('the best move: the most plays first, not the longest chain', () => {
  // the 4 at (0, 0): 3 explosions, 1 play; the 4 at (3, 3) or (4, 3): 2 explosions, but the bonus at (5, 3): 6 plays
  const board = parseBoard('444...', '......', '......', '...44B', '......', '......')
  const list = analyzeDecision(board, 10)
  const of = (x, y) => list.find((m) => m.cell === at(x, y)).outcome
  assert.equal(of(0, 0).explosions, 3)
  assert.equal(of(0, 0).won, 1)
  assert.equal(of(3, 3).explosions, 2)
  assert.equal(of(3, 3).won, 6)
  const best = Math.max(...list.filter((m) => m.outcome).map((m) => value(m.outcome)))
  assert.deepEqual(list.filter((m) => m.outcome && value(m.outcome) === best).map((m) => m.cell), [at(3, 3), at(4, 3)])
})

test('the next move: the longest chain of the board, or a flame that ends the level', () => {
  assert.equal(bestNext(parseBoard(...rows('444..1')), 10), 1000 + 3)
  // no 4: nothing explodes; the 3 slimes left are all around the empty (1, 1): a flame ends the level
  assert.equal(bestNext(parseBoard('3.3...', '......', '.3....', '......', '......', '......'), 10), 1000)
  assert.equal(bestNext(parseBoard('3.3...', '......', '.3....', '......', '......', '.....1'), 10), 0)
  // no play left: the game is over
  assert.equal(bestNext(parseBoard(...rows('444..1')), 0), 0)
})

test('a slime grown for the next move is a best move two moves ahead, not one', () => {
  // the 4s at (0, 0) and (2, 0) explode alone (the 3 between them only grows); grown first, the 3 joins them: the
  // next click explodes the three of them (a play won)
  const board = parseBoard('434...', '......', '......', '......', '......', '...4.4')
  const setUp = rateMove(board, 10, at(1, 0))
  assert.equal(setUp.optimal1, false)
  assert.equal(setUp.optimal2, true)
  assert.equal(setUp.optimal, true)
  // the 4 at (3, 5): its east drop crosses the empty (4, 5) and explodes the 4 at (5, 5): the longest chain now
  const chain = rateMove(board, 10, at(3, 5))
  assert.equal(chain.explosions, 2)
  assert.equal(chain.optimal1, true)
})

test('only the decisions that discriminate are counted', () => {
  // nothing can make a chain of 2: no decision
  assert.equal(rateMove(parseBoard('4.....', '......', '..4...', '......', '......', '.....3'), 10, 0).counted, false)
  // any 4 starts the same chain: no decision
  assert.equal(rateMove(parseBoard(...rows('444...')), 10, 0).counted, false)
  // two 4s of five slimes start the chain, the 1s do not (nor grown, two moves ahead: two flames would end the level
  // sooner): a decision, the chain is a best move
  const board = parseBoard('44....', '......', '..1...', '...1..', '......', '.....1')
  const good = rateMove(board, 10, at(0, 0))
  assert.equal(good.counted, true)
  assert.equal(good.optimal, true)
  const bad = rateMove(board, 10, at(5, 5))
  assert.equal(bad.counted, true)
  assert.equal(bad.optimal, false)
})
