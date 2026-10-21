// node --test resources/js/replay-verifier/analyzers/tubulo.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { CELLS, click, clicksOf, isSolved, PLUS, rateAttempt, rateClick, SIDE, solutions, solve } from './tubulo/solver.mjs'

// a board from rows y = 0..6, one digit (color) by column x (index x * 7 + y)
function board(...rows) {
  const b = new Array(CELLS)
  rows.forEach((row, y) => [...row].forEach((c, x) => { b[x * SIDE + y] = +c }))
  return b
}
const at = (x, y) => x * SIDE + y
const EMPTY = new Array(CELLS).fill(0)

// Game.genLevel: each step turns the plus of a cell to the previous color, (id + 2) % 3
function undo(b, i) {
  const next = b.slice()
  for (const j of PLUS[i]) next[j] = (next[j] + 2) % 3
  return next
}

test('a click turns the tube and its neighbours on the board to the next color (Game.clickTube)', () => {
  assert.deepEqual(click(EMPTY, at(3, 3)), board(
    '0000000',
    '0000000',
    '0001000',
    '0011100',
    '0001000',
    '0000000',
    '0000000',
  ))
  // a corner: 3 tubes only
  assert.deepEqual(click(EMPTY, at(0, 0)), board('1100000', '1000000', '0000000', '0000000', '0000000', '0000000', '0000000'))
  // 2 -> 0
  assert.deepEqual(click(click(click(EMPTY, at(6, 3)), at(6, 3)), at(6, 3)), EMPTY)
})

test('one set of clicks solves a board for each final color', () => {
  // the clicks of a level (Game.genLevel) are its solution to color 0
  let b = EMPTY
  for (const i of [at(1, 1), at(2, 1), at(5, 5), at(3, 4)]) b = undo(b, i)
  const x = solve(b, 0)
  assert.deepEqual([...x].map((v, i) => (v ? i : -1)).filter((i) => i >= 0), [at(1, 1), at(2, 1), at(3, 4), at(5, 5)].sort((a, c) => a - c))
  // twice the same cell: 2 clicks on it
  assert.equal(solve(undo(undo(EMPTY, at(4, 4)), at(4, 4)), 0)[at(4, 4)], 2)
  // any final color: the solution reaches it
  for (let c = 0; c < 3; c++) {
    const xc = solve(b, c)
    let r = b
    for (let i = 0; i < CELLS; i++) for (let k = 0; k < xc[i]; k++) r = click(r, i)
    assert.ok(isSolved(r) && r[0] === c)
  }
  // all 0 -> all 1 takes 53 clicks, all 2: 58
  assert.deepEqual(solutions(EMPTY).map((s) => s.clicks), [0, 53, 58])
})

test('the solution of a random board, whatever the order of the clicks', () => {
  let seed = 7
  const rnd = (n) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed >> 16) % n }
  for (let t = 0; t < 20; t++) {
    const b = Array.from({ length: CELLS }, () => rnd(3))
    const x = solve(b, 0)
    const order = []
    for (let i = 0; i < CELLS; i++) for (let k = 0; k < x[i]; k++) order.push(i)
    order.sort(() => rnd(3) - 1)
    let r = b
    for (const i of order) r = click(r, i)
    assert.ok(isSolved(r) && r[0] === 0)
    assert.equal(clicksOf(x), order.length)
  }
})

test('a plus drawn by the level is visible, the cells of overlapping pluses are not', () => {
  // two pluses one cell apart: (2, 3) and (4, 3) share the tube (3, 3), turned back twice (1)
  const b = undo(undo(EMPTY, at(2, 3)), at(4, 3))
  assert.deepEqual(b, board(
    '0000000',
    '0000000',
    '0020200',
    '0221220',
    '0020200',
    '0000000',
    '0000000',
  ))
  assert.deepEqual(rateClick(b, at(2, 3), 0), { needed: true, visible: true, remaining: 2 })
  assert.deepEqual(rateClick(b, at(4, 3), 0), { needed: true, visible: true, remaining: 2 })
  // the shared tube is not the center of a plus (its neighbours above and below are solved)
  assert.deepEqual(rateClick(b, at(3, 3), 0), { needed: false, visible: false, remaining: 2 })

  // three pluses in a row: the middle tube, turned back three times, looks solved, and so do the centers' pluses
  const c = undo(undo(undo(EMPTY, at(2, 3)), at(3, 3)), at(4, 3))
  assert.deepEqual(c, board(
    '0000000',
    '0000000',
    '0022200',
    '0210120',
    '0022200',
    '0000000',
    '0000000',
  ))
  for (const i of [at(2, 3), at(3, 3), at(4, 3)]) assert.deepEqual(rateClick(c, i, 0), { needed: true, visible: false, remaining: 3 })
  assert.deepEqual(rateClick(c, at(3, 2), 0), { needed: false, visible: false, remaining: 3 })
  // against another final color everything changes
  assert.equal(rateClick(c, at(3, 3), 1).remaining, clicksOf(solve(c, 1)))
})

test('rateAttempt: the clicks against the color the level was solved to', () => {
  let b = EMPTY
  for (const i of [at(3, 3), at(4, 3), at(1, 1), at(5, 5), at(1, 5), at(5, 1), at(3, 0), at(0, 3)]) b = undo(b, i)
  // a wrong click (6, 6), undone by two more, then the solution
  const clicks = [at(6, 6), at(6, 6), at(6, 6), at(3, 3), at(4, 3), at(1, 1), at(5, 5), at(1, 5), at(5, 1), at(3, 0), at(0, 3)]
  const r = rateAttempt(b, clicks.map((i) => ({ i, frames: 10 })), { solved: true })
  assert.equal(r.color, 0)
  assert.equal(r.minClicks, 8)
  assert.equal(r.clicks.length, 11)
  assert.deepEqual(r.clicks.map((c) => c.needed), [false, true, true, true, true, true, true, true, true, true, true])
  assert.equal(r.clicks[0].remaining, 8)
  assert.equal(r.clicks[1].remaining, 10)
  assert.equal(r.clicks[3].remaining, 8)
  // a level left (reset / time over): the color nearest to the board shown
  const left = rateAttempt(b, clicks.slice(0, 5).map((i) => ({ i, frames: 10 })), { solved: false })
  assert.equal(left.color, 0)
  assert.equal(left.clicks.length, 5)
  // a board drawn from color 1
  let one = new Array(CELLS).fill(1)
  one = undo(undo(one, at(2, 2)), at(5, 4))
  const oneLeft = rateAttempt(one, [{ i: at(2, 2), frames: 4 }], { solved: false })
  assert.equal(oneLeft.color, 1)
  assert.equal(oneLeft.minClicks, 2)
  assert.equal(oneLeft.clicks[0].needed, true)
  // solved to color 2 (the long way): rated against 2
  const x2 = solve(b, 2)
  const to2 = []
  for (let i = 0; i < CELLS; i++) for (let k = 0; k < x2[i]; k++) to2.push({ i, frames: 1 })
  const solved2 = rateAttempt(b, to2, { solved: true })
  assert.equal(solved2.color, 2)
  assert.ok(solved2.clicks.every((c) => c.needed))
})

// the fields of Game the analyzer reads, moved like the game does: Anim (a new board), Play (waits for a click), a
// click (a new game.moves, the tube clicked last) then Move for a few frames, checkEnd (stats._e) or resetLevel
// (stats._r)
function fakeGame() {
  const tube = (x, y) => ({ id: 0, gridx: x, gridy: y })
  const game = {
    step: { _hx_index: 2 },
    grid: Array.from({ length: SIDE }, (_, x) => Array.from({ length: SIDE }, (_, y) => tube(x, y))),
    moves: undefined,
    stats: { _e: [], _r: [] },
  }
  let frame = 0
  const set = (b) => { for (let i = 0; i < CELLS; i++) game.grid[Math.floor(i / SIDE)][i % SIDE].id = b[i] }
  const get = () => { const b = []; for (let i = 0; i < CELLS; i++) b.push(game.grid[Math.floor(i / SIDE)][i % SIDE].id); return b }
  return {
    kk: { game },
    get frame() { return frame },
    // frames go by: the analyzer is called before each one
    run(analyzer, n, during = () => {}) {
      for (let k = 0; k < n; k++) { analyzer.beforeFrame(frame); during(k); frame++ }
    },
    level(analyzer, b) {
      game.step = { _hx_index: 2 }
      set(b)
      this.run(analyzer, 5)
      game.step = { _hx_index: 0 }
      this.run(analyzer, 1)
    },
    click(analyzer, i, wait = 10) {
      this.run(analyzer, wait)
      // during the frame: Game.clickTube
      analyzer.beforeFrame(frame)
      set(click(get(), i))
      game.moves = PLUS[i].filter((j) => j !== i).map((j) => game.grid[Math.floor(j / SIDE)][j % SIDE]).concat([game.grid[Math.floor(i / SIDE)][i % SIDE]])
      game.step = { _hx_index: 1, sens: 1 }
      frame++
      this.run(analyzer, 12)
      if (isSolved(get())) {
        game.stats._e.push(0)
        game.step = { _hx_index: 2 }
      } else {
        game.step = { _hx_index: 0 }
      }
      this.run(analyzer, 1)
    },
    reset(analyzer) {
      game.stats._r.push(0)
      game.step = { _hx_index: 2 }
      this.run(analyzer, 1)
    },
  }
}

test('the analyzer: clicks rated on the board seen, levels solved and reset, the limit', async() => {
  const { create } = await import('./tubulo.mjs')
  // a level of 12 overlapping pluses (Game.genLevel)
  let seed = 3
  const rnd = (n) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed >> 16) % n }
  const levelOf = (n) => {
    let b = EMPTY
    for (let k = 0; k < n; k++) b = undo(b, rnd(CELLS))
    return b
  }
  const solveAll = (g, analyzer, b, wrong) => {
    if (wrong != null) {
      g.click(analyzer, wrong)
      b = click(b, wrong)
    }
    const x = solve(b, 0)
    for (let i = 0; i < CELLS; i++) for (let k = 0; k < x[i]; k++) g.click(analyzer, i, 3 + rnd(20))
  }

  // a solver: every click in the solution
  let g = fakeGame()
  let analyzer = create({ kk: g.kk, config: { min_decisions: 20, optimal_rate: 0.95, min_remaining: 8 } })
  for (let l = 0; l < 4; l++) {
    const b = levelOf(14)
    g.level(analyzer, b)
    solveAll(g, analyzer, b)
  }
  let r = analyzer.finish({ score: 0, frames: g.frame })
  assert.equal(r.metrics.levels, 4)
  assert.equal(r.metrics.wrongClicks, 0)
  assert.equal(r.metrics.optimalRate, 1)
  assert.equal(r.metrics.valueRate, 1)
  assert.ok(r.metrics.decisions >= 20)
  assert.equal(r.suspicious, true)
  assert.match(r.reasons[0], /^clics dans la solution 100 % du temps/)

  // a player: a wrong click on each hard board (+2 clicks to undo it), a level reset
  g = fakeGame()
  analyzer = create({ kk: g.kk, config: { min_decisions: 20, optimal_rate: 0.95, min_remaining: 8 } })
  let b = levelOf(14)
  g.level(analyzer, b)
  g.click(analyzer, 0)
  g.click(analyzer, 1)
  g.reset(analyzer)
  for (let l = 0; l < 4; l++) {
    b = levelOf(14)
    g.level(analyzer, b)
    // a tube out of the solution
    const x = solve(b, 0)
    solveAll(g, analyzer, b, x.findIndex((v) => v === 0))
  }
  r = analyzer.finish({ score: 0, frames: g.frame })
  assert.equal(r.metrics.levels, 4)
  assert.equal(r.metrics.resets, 1)
  assert.ok(r.metrics.wrongClicks >= 4)
  assert.ok(r.metrics.optimalRate < 0.95)
  assert.ok(r.metrics.valueRate < 1)
  assert.equal(r.suspicious, false)
  // the decision frames: the waits of the clicks
  assert.ok(r.metrics.medianDecisionFrames >= 3 && r.metrics.medianDecisionFrames < 23)
})

test('the analyzer: a build without the fields', async() => {
  const { create } = await import('./tubulo.mjs')
  const analyzer = create({ kk: { game: { step: { _hx_index: 0 }, grid: [] } }, config: {} })
  assert.throws(() => analyzer.beforeFrame(0), /unsupported build/)
})
