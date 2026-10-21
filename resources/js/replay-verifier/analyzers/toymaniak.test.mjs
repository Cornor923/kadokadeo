// node --test resources/js/replay-verifier/analyzers/toymaniak.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { create } from './toymaniak.mjs'
import { aimOf, aimPrecision, pressTarget } from './toymaniak/presses.mjs'

// a state: rails written as 'x:t' (t: -1 empty place, 0-3 colours, 4-6 bonuses; 'L' after: locked at the crusher)
function state(rails, sels = [-1, -1, -1], cursor = null) {
  return {
    rails: rails.map((toys) => ({
      toys: toys.map((s) => {
        const [x, t] = s.replace('L', '').split(':')
        return { x: +x, t: +t, lock: s.endsWith('L') }
      }),
    })),
    sels,
    cursor,
  }
}

const RAILS = [['40:0L', '90.7:1', '140:-1'], ['100:2'], ['200:3']]

test('a press on a toy: its button (Data.BUT_RECT) around Std.int(x) and the line of its rail', () => {
  const s = state(RAILS)
  // rail 0 at y 70: the toy at 90.7 (Std.int: 90)
  assert.deepEqual(pressTarget(s, 95, 50), { kind: 'toy', rail: 0, index: 1, t: 1, dx: 5, dy: -20, effect: 'take' })
  // its button goes from 52.25 above the line to 7.75 below
  assert.equal(pressTarget(s, 95, 70 - 52.25).index, 1)
  assert.equal(pressTarget(s, 95, 70 + 8), null)
  // rail 2 at y 220
  assert.deepEqual(pressTarget(s, 190, 200), { kind: 'toy', rail: 2, index: 0, t: 3, dx: -10, dy: -20, effect: 'take' })
  // between two rails, under the buttons: nothing
  assert.equal(pressTarget(s, 100, 80), null)
})

test('two buttons overlap: the toy added later is over the other', () => {
  // spacing under 50 pixels: x 112-115 is on both
  const s = state([['90:0', '137:1'], [], []])
  assert.equal(pressTarget(s, 113, 50).index, 1)
  assert.equal(pressTarget(s, 111, 50).index, 0)
})

test('what a press on a toy does (Game.selectToy)', () => {
  // the toy at the crusher is locked: nothing, whatever the hand holds
  assert.equal(pressTarget(state(RAILS), 40, 50).effect, null)
  assert.equal(pressTarget(state(RAILS, undefined, 2), 40, 50).effect, null)
  // an empty place: nothing with an empty hand, the toy in hand put there otherwise
  assert.equal(pressTarget(state(RAILS), 140, 50).effect, null)
  assert.equal(pressTarget(state(RAILS, undefined, 2), 140, 50).effect, 'put')
  // a toy: taken, or swapped with the one in hand
  assert.equal(pressTarget(state(RAILS, undefined, 2), 95, 50).effect, 'swap')
})

test('a press on a slot of the box (Game.selectSlot)', () => {
  const s = state(RAILS, [0, -1, 3])
  assert.deepEqual(pressTarget(s, 106, 270), { kind: 'slot', slot: 0, t: 0, dx: 2, dy: 270 - 272.6, effect: 'take' })
  // an empty slot: nothing with an empty hand, the toy in hand stored otherwise
  assert.equal(pressTarget(s, 150, 272).effect, null)
  assert.equal(pressTarget(state(RAILS, [0, -1, 3], 1), 150, 272).effect, 'put')
  assert.equal(pressTarget(state(RAILS, [0, -1, 3], 1), 196, 272).effect, 'swap')
  // the nearest slot; far from the box: nothing
  assert.equal(pressTarget(s, 128, 272).slot, 1)
  assert.equal(pressTarget(s, 20, 272), null)
})

test('the aim: the height on a toy (grouped by kind of toy), both coordinates on a slot', () => {
  assert.deepEqual(aimOf({ kind: 'toy', t: 2, dx: 7, dy: -20 }), { group: 'toy2', values: [-20] })
  assert.deepEqual(aimOf({ kind: 'slot', slot: 1, dx: 1, dy: -2 }), { group: 'slot1', values: [1, -2] })
})

const aims = (group, ...values) => values.map((v) => ({ group, values: [].concat(v) }))

test('a program presses the same pixel of every target of a kind: all exact, no spread', () => {
  // a reader of the screen: the centre of each picture (one height by kind of toy), the centre of the slots
  const p = aimPrecision([...aims('toy0', -20, -20, -20, -20, -20), ...aims('toy3', -12, -12, -12, -12.5), ...aims('slot1', [0, 0], [0, 0], [0.5, 0], [0, 0])])
  assert.equal(p.presses, 13)
  assert.equal(p.exactRate, 1)
  assert.ok(p.spread < 0.3)
})

test('a player presses anywhere on the picture: few exact, a spread of pixels', () => {
  const p = aimPrecision([...aims('toy0', -30, -12, -22, -41, -8, -19, -26), ...aims('slot2', [5, -3], [-8, 6], [1, 10], [-4, -9], [9, 2])])
  assert.equal(p.presses, 12)
  // one by chance: -22, the median of the others being -22.5
  assert.equal(p.exact, 1)
  assert.ok(p.spread > 6)
})

test('the median compared is the one of the other presses; small groups left out', () => {
  // 4 presses, one apart: the 3 others agree with each other, the odd one is not exact
  assert.deepEqual(aimPrecision(aims('toy1', -20, -20, -20, -35)), { presses: 4, exact: 3, exactRate: 0.75, spread: 7.5 })
  // fewer than minGroup presses of a kind: nothing to compare with
  assert.deepEqual(aimPrecision(aims('toy1', -20, -20, -20)), { presses: 0, exact: 0, exactRate: null, spread: null })
  assert.equal(aimPrecision(aims('toy1', -20, -20, -20), { minGroup: 3 }).exactRate, 1)
  // the tolerance
  assert.equal(aimPrecision(aims('toy1', -20, -21.5, -20, -20)).exact, 3)
  assert.equal(aimPrecision(aims('toy1', -20, -21.5, -20, -20), { tolerance: 1.5 }).exact, 4)
})

// the analyzer on a made-up game: one toy by rail standing still, presses written in the replay records
function fakeRun(presses, config = {}) {
  const game = {
    speed: 1,
    time: 10,
    cursor: null,
    sels: [{ t: 1 }, { t: -1 }, { t: -1 }],
    rails: [0, 1, 2].map(() => ({ speed: 0.5, last: null, ncombos: 0, toys: [{ x: 150.4, t: 2, lock: false }] })),
  }
  const playFrames = []
  const playRecords = []
  let frame = 10
  for (const [x, y] of presses) {
    // the mouse moves there (canvas pixels: x 2), is pressed 4 frames later, released 3 frames after
    playFrames.push(frame, frame + 4, frame + 7)
    playRecords.push({ mousePosition: { x: 2 * x, y: 2 * y } }, { mouseButtons: [{ button: 0, isDown: true }] }, { mouseButtons: [{ button: 0, isDown: false }] })
    frame += 20
  }
  const kk = { game, replay: { playFrames, playRecords } }
  const analyzer = create({ kk, config })
  for (let f = 0; f <= frame; f++) analyzer.beforeFrame(f)
  return analyzer.finish({ score: 0, frames: frame })
}

test('the analyzer: a program pressing the same point of the toys is flagged', () => {
  // rail 0, 1, 2 in turn, always 20 pixels above the line: 60 pixels apart, every press aimed
  const presses = Array.from({ length: 36 }, (_, i) => [150, [70, 145, 220][i % 3] - 20])
  const { metrics, suspicious, reasons } = fakeRun(presses)
  assert.equal(metrics.presses, 36)
  assert.equal(metrics.aimed, 36)
  assert.equal(metrics.decisions, 36)
  assert.equal(metrics.optimalRate, 1)
  assert.equal(metrics.aimSpread, 0)
  assert.equal(metrics.medianPressFrames, 3)
  // the pointer jumped there (one position by press)
  assert.equal(metrics.medianDecisionFrames, 1)
  assert.equal(metrics.teleportRate, 1)
  assert.ok(suspicious)
  assert.equal(reasons.length, 2)
  assert.match(reasons[0], /100 % du temps \(36 clics visés, limite 70 %\)/)
})

test('the analyzer: a player pressing anywhere on the toys is not', () => {
  let seed = 7
  const rand = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) % 1000) / 1000
  const presses = Array.from({ length: 36 }, (_, i) => [140 + rand() * 20, [70, 145, 220][i % 3] - 5 - rand() * 40])
  const { metrics, suspicious } = fakeRun(presses)
  assert.equal(metrics.decisions, 36)
  assert.ok(metrics.optimalRate < 0.3)
  assert.ok(metrics.aimSpread > 5)
  assert.equal(suspicious, false)
})

test('the analyzer: presses without moving the mouse are not aimed; too few aimed presses: nothing said', () => {
  // the same rail spot again and again (a player waiting for the toys there)
  const still = fakeRun(Array.from({ length: 36 }, () => [150, 50]))
  assert.equal(still.metrics.presses, 36)
  assert.equal(still.metrics.aimed, 1)
  assert.equal(still.suspicious, false)
  // a program, but a short game
  const short = fakeRun(Array.from({ length: 12 }, (_, i) => [150, [70, 145, 220][i % 3] - 20]))
  assert.equal(short.metrics.optimalRate, 1)
  assert.equal(short.suspicious, false)
  // the minimum from the config
  assert.equal(fakeRun(Array.from({ length: 12 }, (_, i) => [150, [70, 145, 220][i % 3] - 20]), { min_decisions: 10 }).suspicious, true)
})

test('the analyzer: a build without the fields read throws unsupported build', () => {
  assert.throws(() => create({ kk: { replay: {} } }), /unsupported build/)
  const kk = { game: { rails: [], sels: [] }, replay: { playFrames: [0], playRecords: [{ mouseButtons: [{ isDown: true }] }] } }
  const analyzer = create({ kk })
  assert.throws(() => analyzer.beforeFrame(0), /unsupported build/)
})
