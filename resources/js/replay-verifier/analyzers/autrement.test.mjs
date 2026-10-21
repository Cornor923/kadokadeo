// node --test resources/js/replay-verifier/analyzers/autrement.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { attach, cell, CORE, EMPTY, MAX, moves, obstacle, rateMove, rotated, rotateShift, SHAKER, STAR } from './autrement/solver.mjs'

// a board from rows y = 0..11, one char by column x: '.' empty, a digit a color, a-f a star of the color 0-5,
// A-F a shaker of the color 0-5
function board(...rows) {
  assert.equal(rows.length, MAX)
  const b = new Array(MAX * MAX).fill(EMPTY)
  rows.forEach((row, y) => {
    assert.equal(row.length, MAX)
    ;[...row].forEach((ch, x) => {
      if (ch === '.') return
      if (/[0-9]/.test(ch)) b[x * MAX + y] = cell(+ch)
      else if (/[a-f]/.test(ch)) b[x * MAX + y] = cell(ch.charCodeAt(0) - 97, STAR)
      else b[x * MAX + y] = cell(ch.charCodeAt(0) - 65, SHAKER)
    })
  })
  return b
}
const at = (x, y) => x * MAX + y

// Stamp.new: the core, 3 x 3 grey blocks around the position of the stamp; extra blocks [x, y, color(, option)]
function stamp(...extra) {
  const s = []
  for (let x = -1; x <= 1; x++) for (let y = -1; y <= 1; y++) s.push([x, y, cell(CORE)])
  for (const [x, y, color, option] of extra) s.push([x, y, cell(color, option)])
  return s
}

const EMPTY_ROW = '............'

test('the stamp pushes against blocks, moves to free cells, never leaves the board (Stamp.getObstacle)', () => {
  const b = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '.......1....', '.......2....', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  const s = stamp()
  // right of the stamp at 5, 5: the blocks at 7, 5 and 7, 6
  assert.deepEqual(obstacle(b, s, 5, 5, [1, 0]), [at(7, 5), at(7, 6)])
  // to the left: free
  assert.deepEqual(obstacle(b, s, 5, 5, [-1, 0]), [])
  // at the top edge, up: out of the board
  assert.equal(obstacle(b, s, 5, 1, [0, -1]), null)
})

test('4 blocks of a color burst, the core never (BlocManager.getGroups, Bloc.explode)', () => {
  const b = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '........0...', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  // a bar of 3 blocks of color 0 on the right of the core: 3 + 1 = 4 burst (4 x 50)
  const s = stamp([2, -1, 0], [2, 0, 0], [2, 1, 0])
  assert.deepEqual(attach(b, s, 5, 5, [at(8, 5)]), { points: 200, burst: 4, falls: 0, shaken: 0, star: false, shaker: false })
  // the same bar of color 5 (300 by block)
  const s5 = stamp([2, -1, 5], [2, 0, 5], [2, 1, 5])
  const b5 = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '........5...', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  assert.equal(attach(b5, s5, 5, 5, [at(8, 5)]).points, 1200)
  // 3 blocks only: nothing
  assert.equal(attach(b, stamp([2, -1, 0], [2, 0, 0]), 5, 5, [at(8, 5)]).points, 0)
})

test('the blocks no longer linked to the core fall (BlocManager.getFalls), a shaker drops the rest (Stamp.updateShaker)', () => {
  // a bar of color 1 on the right, a block of color 2 then 3 hung on its middle; a block of color 1 stuck at 8, 4
  const s = stamp([2, -1, 1], [2, 0, 1], [2, 1, 1], [3, 0, 2], [4, 0, 3], [-2, 0, 4])
  const b = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '........1...', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  // 4 x 50 + 2 falls x 80; the block of color 4 on the left stays
  assert.deepEqual(attach(b, s, 5, 5, [at(8, 4)]), { points: 360, burst: 4, falls: 2, shaken: 0, star: false, shaker: false })
  // the block stuck is a shaker: the block of color 4 falls too
  const bShaker = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '........B...', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  assert.deepEqual(attach(bShaker, s, 5, 5, [at(8, 4)]), { points: 440, burst: 4, falls: 2, shaken: 1, star: false, shaker: true })
  // a star: no points
  const bStar = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '........b...', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  assert.equal(attach(bStar, s, 5, 5, [at(8, 4)]).star, true)
  assert.equal(attach(bStar, s, 5, 5, [at(8, 4)]).points, 360)
})

test('the stamp turns, shifted by one cell when it does not fit where it is (Stamp.checkRotate)', () => {
  // a bar of 2 blocks on the right of the core: turned (x, y -> -y, x) it goes under the core
  const s = stamp([2, 0, 1], [3, 0, 1])
  assert.deepEqual(rotated(s).slice(9), [[0, 2, cell(1)], [0, 3, cell(1)]])
  const free = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  assert.deepEqual(rotateShift(free, s, 5, 5), [0, 0])
  // at 5, 9 the turned bar would leave the board (y 12): shifted (the first of the cells around that fits)
  assert.deepEqual(rotateShift(free, s, 5, 8), [0, 0])
  assert.deepEqual(rotateShift(free, s, 5, 9), [-1, -1])
  // a block where the bar would go and the cells around: it cannot turn
  const blocked = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '....111.....', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  assert.equal(rotateShift(blocked, s, 5, 5), null)
})

test('the best move: every position and turn of the stamp, not always the biggest burst', () => {
  // on the left 3 blocks of color 0 (6 burst with the bar of 0: 300), on the right a block of color 1 (4 burst and
  // 2 falls: 360)
  const b = board(
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    '..0.....1...',
    '..0.........',
    '..0.........',
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
  )
  const s = stamp([-2, -1, 0], [-2, 0, 0], [-2, 1, 0], [2, -1, 1], [2, 0, 1], [2, 1, 1], [3, 0, 2], [4, 0, 3])
  const biggest = rateMove(b, s, 5, 5, [at(2, 4), at(2, 5), at(2, 6)])
  assert.equal(biggest.value, 300)
  assert.equal(biggest.best, 360)
  assert.equal(biggest.optimal, false)
  const best = rateMove(b, s, 5, 5, [at(8, 4)])
  assert.equal(best.value, 360)
  assert.equal(best.optimal, true)
  assert.equal(best.bestSteps, 0)
  // the same blocks pushed from elsewhere: moving the stamp is a move of the list
  const all = moves(b, s, 5, 5)
  assert.ok(all.some((m) => m.steps > 0 && m.points === 360))
  // a move only reached by a turn of the stamp (the bar of 0 turned to the top)
  assert.ok(all.some((m) => m.turns > 0 && m.points === 300))
  // blocks the stamp at 5, 5 does not push against: not a move
  assert.equal(rateMove(b, s, 5, 5, [at(2, 4)]), null)
})

test('the best move can be far: the stamp goes round the blocks', () => {
  // the stamp in the top left corner (at 1, 2), a bar of color 2 on its right; the block of color 2 at the bottom right corner
  // of a wall: only reachable by going round it
  const b = board(
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    '0101010.....',
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    EMPTY_ROW,
    '...........2',
  )
  const s = stamp([2, -1, 2], [2, 0, 2], [2, 1, 2])
  const all = moves(b, s, 1, 2)
  const best = all.filter((m) => m.points === 4 * 80)
  assert.ok(best.length > 0)
  assert.ok(Math.min(...best.map((m) => m.steps)) >= 10)
  // pushing against the wall from where it is: no burst
  const near = rateMove(b, s, 1, 2, [at(0, 4), at(1, 4), at(2, 4), at(3, 4)])
  assert.equal(near.value, 0)
  assert.equal(near.best, 320)
})

// the fields of the game the analyzer reads (Game.bm.grid, Game.stamp: x, y, step, bm.list), from a board and a stamp
function fakeGame(b, s, x, y) {
  const grid = []
  for (let gx = 0; gx < MAX; gx++) {
    grid.push([])
    for (let gy = 0; gy < MAX; gy++) {
      const c = b[gx * MAX + gy]
      grid[gx].push(c === EMPTY ? null : { x: gx, y: gy, id: c & 15, option: (c >> 4) - 1 < 0 ? null : (c >> 4) - 1 })
    }
  }
  const list = s.map(([bx, by, c]) => ({ x: bx, y: by, id: c & 15, option: (c >> 4) - 1 < 0 ? null : (c >> 4) - 1 }))
  return { step: { _hx_name: 'Play' }, bm: { grid }, stamp: { x, y, step: { _hx_name: 'Play' }, bm: { list } } }
}

// a game of `n` decisions on the same board, the blocks `cells` stuck each time (Stamp.action: off the board, at the end
// of the list of the stamp, relative to it); 40 frames between two
async function play(n, cells) {
  const { create } = await import('./autrement.mjs')
  const b = board(EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, '..0.....1...', '..0.........', '..0.........', '.....3......', EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)
  const s = stamp([-2, -1, 0], [-2, 0, 0], [-2, 1, 0], [2, -1, 1], [2, 0, 1], [2, 1, 1], [3, 0, 2], [4, 0, 3])
  const kk = { game: fakeGame(b, s, 5, 5) }
  const analyzer = create({ kk, config: {} })
  let frame = 1
  for (let k = 0; k < n; k++) {
    kk.game = fakeGame(b, s, 5, 5)
    for (let i = 0; i < 40; i++) analyzer.beforeFrame(frame++)
    for (const i of cells) {
      const bloc = kk.game.bm.grid[Math.floor(i / MAX)][i % MAX]
      kk.game.bm.grid[bloc.x][bloc.y] = null
      kk.game.stamp.bm.list.push({ ...bloc, x: bloc.x - 5, y: bloc.y - 5 })
    }
    analyzer.beforeFrame(frame++)
  }
  return analyzer.finish({ score: 0, frames: frame })
}

test('the analyzer: the best move every time is flagged, a player who builds is not', async() => {
  const solver = await play(30, [at(8, 4)])
  assert.equal(solver.metrics.decisions, 30)
  assert.equal(solver.metrics.optimalRate, 1)
  assert.equal(solver.metrics.medianDecisionFrames, 40)
  assert.equal(solver.suspicious, true)
  assert.match(solver.reasons[0], /^meilleur coup 100 % du temps \(30 coups, limite 65 %\)$/)

  // the block of color 3 under the stamp: no points
  const builder = await play(30, [at(5, 7)])
  assert.equal(builder.metrics.decisions, 30)
  assert.equal(builder.metrics.optimalRate, 0)
  assert.equal(builder.metrics.scoringRate, 0)
  assert.equal(builder.suspicious, false)

  // too few moves to say anything
  assert.equal((await play(29, [at(8, 4)])).suspicious, false)
})

test('the analyzer: a version of the game without the fields read is not supported', async() => {
  const { create } = await import('./autrement.mjs')
  const analyzer = create({ kk: { game: { step: { _hx_name: 'Play' }, stamp: { x: 5, y: 5 } } }, config: {} })
  assert.throws(() => analyzer.beforeFrame(1), /unsupported build/)
})
