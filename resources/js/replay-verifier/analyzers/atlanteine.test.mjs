// node --test resources/js/replay-verifier/analyzers/atlanteine.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { create } from './atlanteine.mjs'
import { baseGrid, BLOCK, DIR, EMPTY, Level, levelCache, OUT, PATH, rateMove,ROCK, SEA, TELEPORT, UNSOLVABLE } from './atlanteine/solver.mjs'

const RIGHT = 0
const DOWN = 1
const LEFT = 2
const UP = 3

const CHARS = { '~': SEA, '.': EMPTY, ':': PATH, '#': ROCK, B: BLOCK, O: OUT, T: TELEPORT, '@': EMPTY }

// a level from rows y = 0.., one character by column x: ~ sea, . empty, : path, # rock, B box, O hole, T teleport,
// @ the ball (an empty cell)
function parse(...rows) {
  const w = rows[0].length
  const h = rows.length
  const grid = []
  const tel = []
  let ball = null
  for (let x = 0; x < w; x++) {
    grid.push([])
    for (let y = 0; y < h; y++) {
      const c = rows[y][x]
      grid[x].push(CHARS[c])
      if (c === 'T') tel.push([x, y])
      if (c === '@') ball = [x, y]
    }
  }
  const { flat } = baseGrid(grid, null)
  return { grid, level: new Level(flat, w, h, tel.length ? tel : null), ball }
}

const at = (level, state) => {
  const pos = state % (level.w * level.h)
  return [Math.floor(pos / level.h), pos % level.h]
}

test('Game.updateMove: the ball slides until a rock or a box, dies in the sea, ends in the hole', () => {
  const { level, ball } = parse(
    '~~~~~~~',
    '~....#~',
    '~.....~',
    '~@...O~',
    '~..B..~',
    '~~~~~~~',
  )
  const moves = level.moves(level.state(...ball))
  assert.equal(moves[RIGHT].to, -1) // the hole at 5, 3
  assert.equal(moves[UP].to, -2) // 1, 2 then 1, 1 then the sea
  assert.equal(moves[LEFT].to, -2) // the sea at once
  assert.equal(moves[DOWN].to, -2)
  // from 1, 1: right stops before the rock at 5, 1
  assert.deepEqual(at(level, level.moves(level.state(1, 1))[RIGHT].to), [4, 1])
  // a box stops the ball too: 1, 4 right -> 2, 4 (box at 3, 4)
  assert.equal(level.moves(level.state(1, 4))[RIGHT].to, level.state(2, 4))
  assert.equal(level.dist(level.state(...ball)), 1)
})

test('Game.control: a box with a free cell behind is pushed one cell, once by life', () => {
  const { level, ball } = parse(
    '~~~~~~~~',
    '~......~',
    '~@B..#.~',
    '~.....O~',
    '~~~~~~~~',
  )
  const push = level.moves(level.state(...ball))[RIGHT]
  assert.equal(push.push, true)
  // the ball takes the place of the box (2, 2), the box is at 3, 2: a new variant of the grid
  const [x, y] = at(level, push.to)
  assert.deepEqual([x, y], [2, 2])
  const v = Math.floor(push.to / (level.w * level.h))
  assert.equal(v, 1)
  assert.equal(level.grids[v][3 * level.h + 2], BLOCK)
  assert.equal(level.grids[v][2 * level.h + 2], EMPTY)
  // no second push in this life: the box at 3, 2 now has 4, 2 free behind it, but nothing happens
  assert.equal(level.moves(push.to)[RIGHT], null)
  // a box against a rock cannot move
  const blocked = parse('~~~~~~', '~@B#.~', '~....~', '~~~~~~').level
  assert.equal(blocked.moves(blocked.state(1, 1))[RIGHT], null)
  // the push read in the game (Game.pushInfo) is the same variant, and the grid without it the same level
  assert.equal(level.variantOfPush({ base: [2, 2], free: [3, 2] }), v)
  const pushed = parse(
    '~~~~~~~~',
    '~......~',
    '~@.B.#.~',
    '~.....O~',
    '~~~~~~~~',
  ).grid
  assert.deepEqual(baseGrid(pushed, { base: [2, 2], free: [3, 2] }).flat, level.grids[0])
})

test('Game.updateMove: a teleport sends the ball to the other one, the slide goes on from there', () => {
  const { level, ball } = parse(
    '~~~~~~~~',
    '~@.T...~',
    '~......~',
    '~....T.~',
    '~.....#~',
    '~~~~~~~~',
  )
  // right from 1, 1: the teleport at 3, 1 sends the ball to 5, 3, then 6, 3, 7, 3: the sea
  assert.equal(level.moves(level.state(...ball))[RIGHT].to, -2)
  // up from 5, 4: the teleport at 5, 3 sends it to 3, 1, then 3, 0: the sea
  assert.equal(level.moves(level.state(5, 4))[UP].to, -2)
  const withStop = parse(
    '~~~~~~~~',
    '~#.T...~',
    '~......~',
    '~....T@~',
    '~......~',
    '~~~~~~~~',
  ).level
  // left from 6, 3: teleport 5, 3 -> 3, 1, then 2, 1 and the rock at 1, 1 stops it
  assert.deepEqual(at(withStop, withStop.moves(withStop.state(6, 3))[LEFT].to), [2, 1])
})

test('the shortest way out counts the slides; a move is optimal when it is on one', () => {
  const { level, ball } = parse(
    '~~~~~~~~',
    '~#...O.~',
    '~......~',
    '~@...#.~',
    '~......~',
    '~~~~~~~~',
  )
  // 1, 3 right -> 4, 3 (rock 5, 3), up from there -> 4, 0: the sea; 1, 3 up -> 1, 2 (rock 1, 1), right -> the sea
  assert.equal(level.dist(level.state(...ball)), UNSOLVABLE)
  const two = parse(
    '~~~~~~~',
    '~#..O.~',
    '~.....~',
    '~@..#.~',
    '~.....~',
    '~~~~~~~',
  ).level
  // right -> 3, 3 (rock 4, 3), up from there -> 3, 0: the sea (the hole is at 4, 1)
  assert.equal(two.dist(two.state(1, 3)), UNSOLVABLE)
  const way = parse(
    '~~~~~~~',
    '~#..O.~',
    '~.....~',
    '~@...#~',
    '~.....~',
    '~~~~~~~',
  ).level
  // right -> 4, 3 (rock 5, 3), up -> 4, 2, 4, 1 the hole: 2 slides
  const r = rateMove(way, 1, 3, 0, RIGHT)
  assert.equal(r.dist, 2)
  assert.equal(r.after, 1)
  assert.equal(r.optimal, true)
  // up goes to 1, 2 (rock 1, 1): no way out from there (right: the sea)
  const bad = rateMove(way, 1, 3, 0, UP)
  assert.equal(bad.optimal, false)
  assert.equal(bad.after, UNSOLVABLE)
  // only one sensible move (the others die or lead nowhere): not a choice
  assert.equal(r.sensible, 1)
  assert.equal(r.choice, false)
})

test('a real choice: two sensible moves, one not on a shortest way; going back is not a choice', () => {
  const { level, ball } = parse(
    '~~~~~~~',
    '~.....~',
    '~#.@#.~',
    '~....#~',
    '~..#O.~',
    '~~~~~~~',
  )
  // 3, 2: right is a rock (nothing happens), up the sea; down -> 3, 3 (rock 3, 4), right -> 4, 3 (rock 5, 3), down: the
  // hole. Left -> 2, 2 (rock 1, 2): a way out too, longer
  const down = rateMove(level, ...ball, 0, DOWN)
  assert.equal(level.moves(level.state(...ball))[RIGHT], null)
  assert.equal(down.dist, 3)
  assert.equal(down.after, 2)
  assert.equal(down.optimal, true)
  const left = rateMove(level, ...ball, 0, LEFT)
  assert.equal(left.to, level.state(2, 2))
  assert.equal(left.optimal, false)
  assert.ok(left.after > 3 && left.after !== UNSOLVABLE)
  assert.equal(down.sensible, 2)
  assert.equal(down.choice, true)
  // the ball comes from 2, 2: going back there is not considered, one sensible move left
  const back = rateMove(level, ...ball, 0, DOWN, level.state(2, 2))
  assert.equal(back.sensible, 1)
  assert.equal(back.choice, false)
  // brute force agrees on every cell of this level
  for (let x = 0; x < level.w; x++) {
    for (let y = 0; y < level.h; y++) {
      assert.equal(level.dist(level.state(x, y)), naiveDist(parseGrid(level), level.tel, level.w, level.h, x, y), `${x}, ${y}`)
    }
  }
})

test('with or without the push: pushing the box can be shorter, the rules without it keep the bonus of the boxes', () => {
  const { grid, ball } = parse(
    '~~~~~~~',
    '~.B@.#~',
    '~.O..#~',
    '~...#.~',
    '~.....~',
    '~~~~~~~',
  )
  const { flat, w, h } = baseGrid(grid, null)
  const push = new Level(flat, w, h, null)
  const never = new Level(flat, w, h, null, false)
  // left pushes the box to 1, 1, the ball at 2, 1, then down: the hole. 2 slides
  assert.equal(push.dist(push.state(...ball)), 2)
  assert.equal(rateMove(push, ...ball, 0, LEFT).optimal, true)
  assert.equal(rateMove(push, ...ball, 0, LEFT).push, true)
  // without it: right -> 4, 1 (rock 5, 1), down -> 4, 2 (rock 4, 3), left -> 3, 2 then the hole. 3 slides
  assert.equal(never.dist(never.state(...ball)), 3)
  assert.equal(never.moves(never.state(...ball))[LEFT], null)
  assert.equal(rateMove(never, ...ball, 0, RIGHT).optimal, true)
  assert.equal(rateMove(push, ...ball, 0, RIGHT).optimal, false)
})

// an independent reading of Game.control / Game.updateMove (grid copies, one cell at a time), for the BFS below
function parseGrid(level) {
  const g = []
  for (let x = 0; x < level.w; x++) {
    g.push([])
    for (let y = 0; y < level.h; y++) g[x].push(level.grids[0][x * level.h + y])
  }
  return g
}

function naiveDist(grid, tel, w, h, sx, sy) {
  const get = (g, x, y) => (g[x] === undefined ? undefined : g[x][y])
  const blocks = (c) => c === ROCK || c === BLOCK
  const free = (c) => c === EMPTY || c === PATH
  const key = (g, x, y, pushed) => `${x},${y},${pushed},${g.map((c) => c.join('')).join('|')}`
  const start = { g: grid.map((c) => c.slice()), x: sx, y: sy, pushed: false }
  const seen = new Set([key(start.g, sx, sy, false)])
  let frontier = [start]
  for (let depth = 1; frontier.length && depth < 60; depth++) {
    const next = []
    for (const s of frontier) {
      for (let d = 0; d < 4; d++) {
        const [dx, dy] = DIR[d]
        let g = s.g
        let x = s.x
        let y = s.y
        let pushed = s.pushed
        const n = get(g, x + dx, y + dy)
        if (n === undefined) continue
        if (blocks(n)) {
          if (pushed || n !== BLOCK || !free(get(g, x + 2 * dx, y + 2 * dy))) continue
          g = g.map((c) => c.slice())
          g[x + 2 * dx][y + 2 * dy] = BLOCK
          g[x + dx][y + dy] = EMPTY
          pushed = true
        }
        let end = null
        for (let guard = 0; guard < 100 && !end; guard++) {
          x += dx
          y += dy
          const c = get(g, x, y)
          if (c === undefined || c === SEA) end = 'sea'
          else if (c === OUT) end = 'out'
          else if (c === TELEPORT) {
            const p = tel.find((t) => t[0] !== x || t[1] !== y)
            x = p[0]
            y = p[1]
          } else if (blocks(get(g, x + dx, y + dy))) end = 'stop'
        }
        if (end === 'out') return depth
        if (end !== 'stop') continue
        const k = key(g, x, y, pushed)
        if (!seen.has(k)) {
          seen.add(k)
          next.push({ g, x, y, pushed })
        }
      }
    }
    frontier = next
  }
  return UNSOLVABLE
}

// a small generator of random levels (not the game's): rocks, boxes, sea, a hole, sometimes two teleports
function randomLevel(seed) {
  let s = seed
  const rand = (n) => {
    s = (s * 16807) % 2147483647
    return s % n
  }
  const w = 9
  const h = 9
  const grid = []
  for (let x = 0; x < w; x++) {
    grid.push([])
    for (let y = 0; y < h; y++) {
      const border = x === 0 || y === 0 || x === w - 1 || y === h - 1
      const r = rand(100)
      grid[x].push(border ? SEA : r < 18 ? ROCK : r < 26 ? BLOCK : r < 29 ? SEA : r < 40 ? PATH : EMPTY)
    }
  }
  grid[1 + rand(w - 2)][1 + rand(h - 2)] = OUT
  let tel = null
  if (rand(2)) {
    tel = [[2, 2], [6, 5]]
    for (const [x, y] of tel) grid[x][y] = TELEPORT
  }
  return { grid, tel, w, h }
}

test('the distances agree with a brute force search of the rules on random levels (boxes and teleports)', () => {
  let solvable = 0
  let notGreedy = 0
  for (let seed = 1; seed <= 40; seed++) {
    const { grid, tel, w, h } = randomLevel(seed * 7919)
    const level = new Level(baseGrid(grid, null).flat, w, h, tel)
    for (let x = 1; x < w - 1; x++) {
      for (let y = 1; y < h - 1; y++) {
        if (![EMPTY, PATH].includes(grid[x][y])) continue
        const dist = level.dist(level.state(x, y))
        assert.equal(dist, naiveDist(grid, tel, w, h, x, y), `seed ${seed} at ${x}, ${y}`)
        if (dist !== UNSOLVABLE && dist >= 2) {
          solvable++
          // the best move is not always the slide that gets closest to the hole
          const out = []
          for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) if (grid[i][j] === OUT) out.push(i, j)
          const moves = level.moves(level.state(x, y))
          const closer = moves
            .filter((m) => m && m.to >= 0)
            .map((m) => ({ m, far: Math.abs(at(level, m.to)[0] - out[0]) + Math.abs(at(level, m.to)[1] - out[1]) }))
            .sort((a, b) => a.far - b.far)[0]
          if (closer && !rateMove(level, x, y, 0, closer.m.d).optimal) notGreedy++
        }
      }
    }
  }
  assert.ok(solvable > 50, `solvable positions: ${solvable}`)
  assert.ok(notGreedy > 0)
})

test('levelCache: the same level after a death (push undone) is the same Level', () => {
  const { grid } = parse(
    '~~~~~~~~',
    '~......~',
    '~@B..#.~',
    '~.....O~',
    '~~~~~~~~',
  )
  const pushed = grid.map((c) => c.slice())
  pushed[2][2] = EMPTY
  pushed[3][2] = BLOCK
  const cache = levelCache()
  const a = cache(grid, null, null)
  const b = cache(pushed, { base: [2, 2], free: [3, 2] }, null)
  assert.equal(a, b)
  assert.equal(b.push.variantOfPush({ base: [2, 2], free: [3, 2] }), 1)
  // a push that is not one cell in a direction: unknown
  assert.equal(b.push.variantOfPush({ base: [2, 2], free: [5, 2] }), null)
  // the rules without the push: the box stays
  assert.equal(b.never.moves(b.never.state(1, 2))[RIGHT], null)
  assert.equal(b.push.moves(b.push.state(1, 2))[RIGHT].push, true)
})

// the analyzer on a fake game: the fields it reads (Game.step, grid, x, y, level, move, pushInfo, ppList), changed frame
// by frame like Game.update does; one or more levels (levels: how many times the same level is played, from level)
function fakeRun(rows, level, slides, { config = {}, waitFrames = 1, levels = 1 } = {}) {
  const { grid, ball } = parse(...rows)
  const game = { step: { _hx_name: 'WaitTimer' }, grid, x: ball[0], y: ball[1], level, move: null, pushInfo: null, ppList: null, tel: null }
  const kk = { game }
  const analyzer = create({ kk, config: { min_decisions: 1, optimal_rate: 0.9, push_optimal_rate: 0.9, ...config } })
  let frame = 0
  const step = (name) => {
    game.step = { _hx_name: name }
    analyzer.beforeFrame(frame++)
  }
  for (let n = 0; n < levels; n++) {
    game.level = level + n
    game.x = ball[0]
    game.y = ball[1]
    step('Next')
    step('Spawn')
    for (const [d, to] of slides) {
      // the ball waits waitFrames frames before the direction (0: held during the slide before)
      for (let i = 0; i <= waitFrames; i++) step('Play')
      // Game.control: a new move object, then Game.updateMove slides the ball
      game.move = { d, coef: 0 }
      game.step = { _hx_name: 'Move' }
      analyzer.beforeFrame(frame++)
      if (to === 'out') {
        step('Wait')
      } else {
        game.x = to[0]
        game.y = to[1]
      }
    }
    step('Wait')
  }
  return analyzer.finish({ score: 0, frames: frame })
}

const CHOICE = [
  '~~~~~~~',
  '~.....~',
  '~#.@#.~',
  '~....#~',
  '~..#O.~',
  '~~~~~~~',
]

test('the analyzer: the slide read from the new move object, rated on the position when the ball waited', () => {
  // down (on the shortest way: a real choice), right (forced), down into the hole (one slide away: not counted)
  const best = fakeRun(CHOICE, 10, [[DOWN, [3, 3]], [RIGHT, [4, 3]], [DOWN, 'out']])
  assert.equal(best.metrics.moves, 3)
  assert.equal(best.metrics.decisions, 1)
  assert.equal(best.metrics.optimal, 1)
  assert.equal(best.metrics.optimalRate, 1)
  assert.equal(best.metrics.levels, 1)
  assert.equal(best.metrics.perfectLevelRate, 1)
  assert.equal(best.metrics.valueRate, 1)
  assert.equal(best.suspicious, true)
  assert.match(best.reasons[0], /plus court chemin 100 %/)
  // left first: a real choice, not on the shortest way
  const detour = fakeRun(CHOICE, 10, [[LEFT, [2, 2]], [RIGHT, [3, 2]], [DOWN, [3, 3]], [RIGHT, [4, 3]], [DOWN, 'out']])
  assert.equal(detour.metrics.decisions >= 1, true)
  assert.equal(detour.metrics.optimalRate < 1, true)
  assert.equal(detour.metrics.perfectLevelRate, 0)
  assert.equal(detour.metrics.valueRate, +(3 / 5).toFixed(3))
  // the levels where the game shows the way are not looked at
  const early = fakeRun(CHOICE, 3, [[DOWN, [3, 3]], [RIGHT, [4, 3]], [DOWN, 'out']])
  assert.equal(early.metrics.decisions, 0)
  assert.equal(early.suspicious, false)
})

test('the analyzer: an unknown build is refused', () => {
  const analyzer = create({ kk: { game: { step: { _hx_name: 'Play' } } }, config: {} })
  assert.throws(() => analyzer.beforeFrame(0), /unsupported build/)
})

test('the analyzer: slides started the frame the ball stops, with good moves (a script that plays)', () => {
  const slides = [[DOWN, [3, 3]], [RIGHT, [4, 3]], [DOWN, 'out']]
  const config = { min_decisions: 100, min_moves: 3, instant_rate: 0.6, instant_optimal_rate: 0.85 }
  // the rule needs 15 choices or more: one level is not enough, the rate is only reported
  const one = fakeRun(CHOICE, 10, slides, { config, waitFrames: 0 })
  assert.equal(one.metrics.instantRate, 1)
  assert.equal(one.metrics.medianDecisionFrames, 0)
  assert.equal(one.suspicious, false)
  const waited = fakeRun(CHOICE, 10, slides, { config, waitFrames: 5 })
  assert.equal(waited.metrics.instantRate, 0)
  assert.equal(waited.metrics.medianDecisionFrames, 5)
  // 20 levels: 20 choices, all instant and on the shortest way
  const bot = fakeRun(CHOICE, 10, slides, { config, waitFrames: 0, levels: 20 })
  assert.equal(bot.metrics.decisions, 20)
  assert.equal(bot.suspicious, true)
  assert.match(bot.reasons[0], /instant où la bille s'arrête 100 %/)
  // the same moves, played after a look: nothing
  assert.equal(fakeRun(CHOICE, 10, slides, { config, waitFrames: 4, levels: 20 }).suspicious, false)
  // instant, but wandering (left first every time: 1 choice in 2 off the shortest way)
  const detour = [[LEFT, [2, 2]], [RIGHT, [3, 2]], [DOWN, [3, 3]], [RIGHT, [4, 3]], [DOWN, 'out']]
  assert.equal(fakeRun(CHOICE, 10, detour, { config, waitFrames: 0, levels: 20 }).suspicious, false)
})
