// node --test resources/js/replay-verifier/analyzers/electrolink.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { cheapestWalk, EAST, HEIGHT, isConnected, minConnection, neededClicks, network, pipes, rateLink, turns, turnsToPipes, WIDTH } from './electrolink/solver.mjs'

// a board from rows y = 0..8, one token by column x: <kind><d> (kind: 0 line, 1 elbow, 2 T, 3 cross, 4 dead end;
// d: quarter turns clockwise), '.' a dead end turned to the north (links nothing)
function board(...rows) {
  const b = new Array(WIDTH * HEIGHT)
  for (let y = 0; y < HEIGHT; y++) {
    const tokens = (rows[y] ?? '. . . . . . . .').trim().split(/\s+/)
    assert.equal(tokens.length, WIDTH)
    tokens.forEach((tok, x) => { b[x * HEIGHT + y] = tok === '.' ? { t: 4, d: 1 } : { t: +tok[0], d: +tok[1] } })
  }
  return b
}

// the board after clicks (each [x, y] a quarter turn of that tile, Tile.rotateDone: d + 1)
function click(b, ...cells) {
  const out = b.map((c) => ({ ...c }))
  for (const [x, y] of cells) out[x * HEIGHT + y].d = (out[x * HEIGHT + y].d + 1) % 4
  return out
}

test('the pipes turn clockwise (Tile.rotatePipe): east, south, west, north', () => {
  assert.deepEqual(pipes(0, 0), [true, false, true, false])
  assert.deepEqual(pipes(0, 1), [false, true, false, true])
  // the elbow west + north, then north + east
  assert.deepEqual(pipes(1, 0), [false, false, true, true])
  assert.deepEqual(pipes(1, 1), [true, false, false, true])
  // the T without its south, then without its west
  assert.deepEqual(pipes(2, 1), [true, true, false, true])
  // the dead end: west, then north
  assert.deepEqual(pipes(4, 1), [false, false, false, true])
  assert.deepEqual(pipes(3, 2), [true, true, true, true])
})

test('the clicks to a tile: only clockwise, a line is the same each half turn, a cross always', () => {
  assert.equal(turns(1, 0), 3)
  assert.equal(turns(3, 1), 2)
  assert.equal(turnsToPipes(0, 1, 0), 1)
  assert.equal(turnsToPipes(0, 0, 2), 0)
  assert.equal(turnsToPipes(1, 1, 0), 3)
  assert.equal(turnsToPipes(3, 0, 3), 0)
})

test('a link: linked pipes from a left goal (west of x = 0) to a right goal (east of x = 7)', () => {
  const b = board('00 00 00 00 00 00 00 00')
  assert.equal(isConnected(b), true)
  assert.equal(network(b).size, 8)
  // one line turned: no link, its two halves alone link nothing
  assert.equal(isConnected(click(b, [4, 0])), false)
  // a pipe that does not face its neighbour's does not link (Game.parse: tile.pipes[i] && neighbour.pipes[in])
  assert.equal(isConnected(board('00 00 00 40 00 00 00 00')), false)
  // the network holds the branches of the linked group (a T going down to a line)
  const branch = board('00 00 00 20 00 00 00 00', '. . . 01 . . . .')
  assert.equal(network(branch).size, 8)
  const t = board('00 00 00 22 00 00 00 00', '. . . 01 . . . .')
  assert.deepEqual(pipes(2, 2), [true, true, true, false])
  // the T, its line going down and the filler dead end under it (turned to the north)
  assert.equal(network(t).size, 10)
})

test('the fewest clicks to link the sides', () => {
  // the first row is all lines but one turned down: one click
  const one = board('00 00 00 01 00 00 00 00')
  assert.equal(minConnection(one).cost, 1)
  assert.deepEqual(minConnection(one).path, [{ i: 3 * HEIGHT + 0, d: 2 }])
  // nothing can link (a dead end in the way): no path
  assert.equal(minConnection(board('00 00 00 . 00 00 00 00')).cost, Infinity)
  // already linked
  assert.equal(minConnection(board('00 00 00 00 00 00 00 00')).cost, 0)
})

test('the best link is not the straight one: a detour through crosses', () => {
  // row 2: three lines to turn (3 clicks); row 0: two elbows (east + south, north + east) turned once each lead down
  // to the crosses of row 1 and back up (2 clicks)
  const b = board(
    '00 12 01 01 01 01 11 00',
    '. 30 30 30 30 30 30 .',
    '00 01 01 01 00 00 00 00',
  )
  const r = minConnection(b)
  assert.equal(r.cost, 2)
  assert.equal(r.exact, true)
  assert.deepEqual(r.path, [{ i: 1 * HEIGHT + 0, d: 3 }, { i: 6 * HEIGHT + 0, d: 2 }])
  // the path applied links the sides
  const after = b.map((c) => ({ ...c }))
  for (const { i, d } of r.path) after[i].d = d
  assert.equal(isConnected(after), true)
  // the straight link of row 2 (3 clicks, no waste) is not the best
  const straight = rateLink(b, click(b, [1, 2], [2, 2], [3, 2]), 3)
  assert.deepEqual([straight.best, straight.needed, straight.optimal, straight.wasteFree], [2, 3, false, true])
  const detour = rateLink(b, after, 2)
  assert.deepEqual([detour.needed, detour.optimal, detour.wasteFree], [2, true, true])
})

test('rating a link: optimal, and the clicks the link did not need', () => {
  const before = board('00 00 01 00 01 00 00 00', '. . 30 30 30 . . .')
  assert.equal(minConnection(before).cost, 2)
  // the two lines turned: optimal, no waste
  const best = rateLink(before, click(before, [2, 0], [4, 0]), 2)
  assert.deepEqual([best.best, best.needed, best.optimal, best.wasteFree], [2, 2, true, true])
  // a full turn of a tile first (4 clicks for nothing)
  const turned = rateLink(before, click(before, [2, 0], [4, 0]), 6)
  assert.deepEqual([turned.needed, turned.optimal, turned.wasteFree], [2, false, false])
  // a click on a cross (Tile.rotateDone: d + 1, no change) or on a tile out of the link
  const cross = rateLink(before, click(before, [3, 1], [2, 0], [4, 0]), 3)
  assert.deepEqual([cross.needed, cross.optimal, cross.wasteFree], [2, false, false])
  const aside = click(before, [0, 5], [2, 0], [4, 0])
  assert.deepEqual([rateLink(before, aside, 3).needed, rateLink(before, aside, 3).wasteFree], [2, false])
  // a line turned three times instead of once: the same pipes, two clicks wasted
  const three = rateLink(before, click(before, [2, 0], [2, 0], [2, 0], [4, 0]), 4)
  assert.deepEqual([three.needed, three.wasteFree, three.optimal], [2, false, false])
})

test('a link that is not the cheapest one, made without waste', () => {
  // row 0: two lines to turn (2 clicks); row 2: three lines (3 clicks)
  const before = board('00 00 01 00 01 00 00 00', '. . . . . . . .', '00 01 01 00 01 00 00 00')
  assert.equal(minConnection(before).cost, 2)
  const r = rateLink(before, click(before, [1, 2], [2, 2], [4, 2]), 3)
  assert.deepEqual([r.best, r.needed, r.optimal, r.wasteFree], [2, 3, false, true])
})

test('the right goal: the last tile linked to its west neighbour and open to the east', () => {
  // a dead end has one pipe: facing east it is not linked to the line on its west
  assert.equal(isConnected(board('00 00 00 00 00 00 00 40')), false)
  assert.equal(isConnected(board('00 00 00 00 00 00 00 42')), false)
  // a T without its west pipe (east + south + north), then turned once (east + south + west)
  const before = board('00 00 00 00 00 00 00 21')
  assert.equal(isConnected(before), false)
  const after = click(before, [7, 0])
  assert.deepEqual(pipes(2, 2), [true, true, true, false])
  assert.equal(isConnected(after), true)
  assert.equal(neededClicks(before, after), 1)
  assert.equal(minConnection(before).cost, 1)
  assert.equal(EAST, 0)
})

test('a walk asking a tile two orientations is not a link: the exact cost (branch and bound)', () => {
  // a random board (index x * 9 + y, <kind><d>) where the cheapest walk (3 clicks) passes twice by a tile
  const tokens = ['22', '32', '12', '11', '22', '32', '02', '22', '22', '10', '30', '13', '13', '13', '02', '11', '10', '10',
    '10', '10', '02', '32', '01', '11', '00', '13', '13', '22', '12', '02', '03', '31', '00', '13', '12', '32', '00', '00',
    '20', '13', '22', '22', '01', '11', '00', '33', '03', '02', '02', '12', '10', '00', '00', '00', '10', '00', '13', '13',
    '33', '13', '03', '12', '42', '02', '00', '30', '10', '32', '01', '41', '11', '10']
  const b = tokens.map((tok) => ({ t: +tok[0], d: +tok[1] }))
  const walk = cheapestWalk(b, new Map())
  assert.equal(walk.cost, 3)
  const tiles = walk.walk.map((w) => w.i)
  assert.notEqual(new Set(tiles).size, tiles.length, 'the walk passes twice by a tile')
  const r = minConnection(b)
  assert.deepEqual([r.cost, r.exact], [4, true])
  const after = b.map((c) => ({ ...c }))
  for (const { i, d } of r.path) after[i].d = d
  assert.equal(isConnected(after), true)
  assert.equal(r.path.reduce((s, { i, d }) => s + turns(b[i].d, d), 0), 4)
  // the walk with its three clicks applied does not link
  const relaxed = b.map((c) => ({ ...c }))
  for (const { i, d } of walk.walk) relaxed[i].d = d
  assert.equal(isConnected(relaxed), false)
})

// a fake game for the analyzer: the fields it reads (Game.board / step / lockTile / flGameOver, Tile.tile / d / pipes /
// state), changed like the game does between two frames
function fakeGame(b) {
  const columns = []
  for (let x = 0; x < WIDTH; x++) {
    columns.push([])
    for (let y = 0; y < HEIGHT; y++) {
      const { t, d } = b[x * HEIGHT + y]
      columns[x].push({ tile: t, d, pipes: pipes(t, d), state: { _hx_name: 'Nothing' }, pos: { x, y } })
    }
  }
  return { board: columns, step: { _hx_name: 'Play' }, lockTile: false, flGameOver: false }
}

// plays clicks on a fake game: each click turns its tile over 3 frames (Tile.rotate, rotateDone), the last one links
function playLink(analyzer, game, frame, cells, gap = 5) {
  for (const [x, y] of cells) {
    for (let k = 0; k < gap; k++) analyzer.beforeFrame(frame++)
    const tile = game.board[x][y]
    tile.state = { _hx_name: 'Rotate' }
    game.lockTile = true
    analyzer.beforeFrame(frame++)
    analyzer.beforeFrame(frame++)
    tile.state = { _hx_name: 'Nothing' }
    tile.d = (tile.d + 1) % 4
    tile.pipes = pipes(tile.tile, tile.d)
    game.lockTile = false
    const flat = []
    for (const column of game.board) for (const t of column) flat.push({ t: t.tile, d: t.d })
    if (isConnected(flat)) {
      game.step = { _hx_name: 'Charge' }
      game.lockTile = true
    }
  }
  analyzer.beforeFrame(frame++)
  return frame
}

test('the analyzer: clicks read from the tiles turning, a link rated on the board shown', async() => {
  const { create } = await import('./electrolink.mjs')
  const b = board('00 00 01 00 01 00 00 00', '. . 30 30 30 . . .')
  // the best link (2 clicks), twice; then a link with a cross clicked and a full turn first (2 + 1 + 4 clicks)
  const kk = { game: null }
  const analyzer = create({ kk, config: { min_decisions: 2, optimal_rate: 0.9, min_best: 2 } })
  let frame = 0
  for (const cells of [[[2, 0], [4, 0]], [[4, 0], [2, 0]], [[3, 1], [2, 0], [2, 0], [2, 0], [2, 0], [2, 0], [4, 0]]]) {
    kk.game = fakeGame(b)
    frame = playLink(analyzer, kk.game, frame, cells)
  }
  const result = analyzer.finish({ score: 0, frames: frame })
  assert.equal(result.metrics.links, 3)
  assert.equal(result.metrics.decisions, 3)
  assert.equal(result.metrics.optimal, 2)
  assert.equal(result.metrics.wasteFree, 2)
  assert.equal(result.metrics.clicks, 11)
  assert.equal(result.metrics.wastedClicks, 5)
  assert.equal(result.metrics.ruleErrors, 0)
  assert.equal(result.metrics.valueRate, +(6 / 11).toFixed(3))
  // 2 of 3 under the limit of 90 %: not suspicious
  assert.equal(result.suspicious, false)
  // the same with only the best links: suspicious, the reason in French
  const kk2 = { game: null }
  const cheat = create({ kk: kk2, config: { min_decisions: 2, optimal_rate: 0.9, min_best: 2 } })
  frame = 0
  for (let n = 0; n < 2; n++) {
    kk2.game = fakeGame(b)
    frame = playLink(cheat, kk2.game, frame, [[2, 0], [4, 0]])
  }
  const flagged = cheat.finish({ score: 0, frames: frame })
  assert.equal(flagged.suspicious, true)
  assert.match(flagged.reasons[0], /^lien le plus court trouvé 100 % du temps \(2 liens, limite 90 %\)$/)
})

test('the analyzer: a one-click (two by default) link is not a decision, a build without the fields is unsupported', async() => {
  const { create } = await import('./electrolink.mjs')
  const kk = { game: fakeGame(board('00 00 00 01 00 00 00 00')) }
  const analyzer = create({ kk, config: {} })
  playLink(analyzer, kk.game, 0, [[3, 0]])
  const r = analyzer.finish({})
  assert.deepEqual([r.metrics.links, r.metrics.decisions, r.metrics.optimalRate], [1, 0, null])
  // by default a two-click link is not a decision either (min_best 3)
  const kk2 = { game: fakeGame(board('00 00 01 00 01 00 00 00')) }
  const two = create({ kk: kk2, config: {} })
  playLink(two, kk2.game, 0, [[2, 0], [4, 0]])
  assert.deepEqual([two.finish({}).metrics.links, two.finish({}).metrics.decisions], [1, 0])
  const broken = create({ kk: { game: { step: { _hx_name: 'Play' }, board: [], lockTile: false } }, config: {} })
  assert.throws(() => broken.beforeFrame(0), /unsupported build/)
})
