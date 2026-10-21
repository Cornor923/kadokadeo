// node --test resources/js/replay-verifier/analyzers/memopsy.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { createTracker, log10Tail, summarize } from './memopsy/memory.mjs'

// Const.LEVELS (the last one repeated)
const LEVELS = [[4, 2], [4, 3], [4, 4], [5, 4], [5, 4], [5, 4], [6, 4]]

// a deterministic random (tests only)
function lcg(seed) {
  let s = seed >>> 0
  return (n) => {
    s = (Math.imul(s, 1103515245) + 12345) >>> 0
    return Math.floor((s / 4294967296) * n)
  }
}

// Game.initLevel + Game.shuffle: ids i % Const.NUMCARDS twice each, width x height random swaps; card x, y = index
// x * height + y
function deal(nlevel, random) {
  const [w, h] = LEVELS[Math.min(nlevel, LEVELS.length - 1)]
  const ids = []
  for (let i = 0; i < (w * h) / 2; i++) ids.push(i % 10, i % 10)
  for (let i = 0; i < ids.length; i++) {
    const a = random(ids.length)
    const b = random(ids.length)
    const s = ids[a]
    ids[a] = ids[b]
    ids[b] = s
  }
  return ids
}

// a level from a string of ids, one character by card
const ids = (s) => [...s].map(Number)

test('a pair found stays face up, two different cards are turned back (Game.onShowDone)', () => {
  const t = createTracker()
  t.level(ids('01230123'), 1)
  assert.equal(t.select(0).kind, 'first')
  assert.equal(t.pending, true)
  assert.equal(t.select(4).hit, true)
  assert.equal(t.pending, false)
  // face up: not a move (Game.cardSelect refuses it)
  assert.equal(t.select(0), null)
  assert.equal(t.select(4), null)
  t.select(1)
  assert.equal(t.select(2).hit, false)
  // turned back: they can be turned again
  assert.equal(t.select(1).kind, 'first')
})

test('a second card never seen, its twin never seen: a guess among the unknown cards', () => {
  const t = createTracker()
  t.level(ids('012345012345'), 1)
  t.select(0)
  // 11 cards unknown, one of them the twin
  const miss = t.select(1)
  assert.deepEqual(miss, { kind: 'blind', level: 1, unknown: 11, p: 1 / 11, hit: false })
  t.select(2)
  // 0 and 1 seen (not twins of 2): 8 unknown
  const hit = t.select(8)
  assert.equal(hit.kind, 'blind')
  assert.equal(hit.unknown, 9)
  assert.equal(hit.p, 1 / 9)
  assert.equal(hit.hit, true)
})

test('a second card whose twin was seen: memory, not a guess', () => {
  const t = createTracker()
  t.level(ids('012345012345'), 1)
  t.select(0)
  t.select(1) // 0 and 1 seen, turned back
  t.select(7) // a 1: its twin (card 1) was seen
  const r = t.select(1)
  assert.deepEqual(r, { kind: 'memory', level: 1, hit: true })
  t.select(6) // a 0: card 0 seen
  assert.equal(t.select(5).kind, 'memory') // the player forgot: still memory, a miss
})

test('a second card seen before that does not match', () => {
  const t = createTracker()
  t.level(ids('012345012345'), 1)
  t.select(0)
  t.select(1)
  t.select(2)
  assert.deepEqual(t.select(1), { kind: 'seenMiss', level: 1, hit: false })
})

test('the first card: its chance to be the twin of a card seen face down', () => {
  const t = createTracker()
  t.level(ids('012345012345'), 2)
  t.select(0)
  t.select(1) // 0 and 1 seen, turned back; 10 unknown cards, 2 of them twins of a seen card (6, 7)
  const r = t.select(7)
  assert.deepEqual(r, { kind: 'first', level: 2, wasSeen: false, unknown: 10, p: 0.2, hit: true })
  t.select(1)
  // a seen card turned first: not a lottery
  assert.equal(t.select(0).wasSeen, true)
})

test('6 x 4 levels: four cards of ids 0 and 1, any two match', () => {
  const t = createTracker()
  t.level(ids('012345678901012345678901'), 6)
  t.select(0)
  const r = t.select(10)
  // 23 unknown, 3 other 0s
  assert.equal(r.p, 3 / 23)
  assert.equal(r.hit, true)
  // one 0 left face down among the 21 unknown cards
  t.select(12)
  const r2 = t.select(22)
  assert.equal(r2.p, 1 / 21)
  assert.equal(r2.hit, true)
})

test('the Poisson binomial tail', () => {
  assert.equal(log10Tail([0.5, 0.5], 0), 0)
  assert.ok(Math.abs(log10Tail([0.5, 0.5], 1) - Math.log10(0.75)) < 1e-12)
  assert.ok(Math.abs(log10Tail([0.5, 0.5], 2) - Math.log10(0.25)) < 1e-12)
  assert.ok(Math.abs(log10Tail([0.1, 0.2, 0.3], 3) - Math.log10(0.006)) < 1e-12)
  // binomial (10, 0.1): P(X >= 5) = 0.001634937...
  assert.ok(Math.abs(log10Tail(Array(10).fill(0.1), 5) - Math.log10(0.0016349374)) < 1e-6)
  assert.equal(log10Tail([0.1], 2), -Infinity)
})

// a whole game: each pair chosen by `choose(state)`, the levels dealt by Game.initLevel, 10 lives (+5 a level, at most
// 20), one lost by pair missed; at most `maxLevels` levels, then the pairs are missed on purpose
function play(seed, choose, maxLevels = 30) {
  const random = lcg(seed)
  const t = createTracker()
  const ratings = []
  let lives = 10
  let frame = 0
  for (let nl = 0; lives > 0; nl++) {
    const deck = deal(nl, random)
    t.level(deck, nl)
    const down = deck.map(() => true)
    const known = deck.map(() => false)
    let left = deck.length / 2
    while (left > 0 && lives > 0) {
      const [a, b] = nl >= maxLevels ? missOnPurpose(deck, down) : choose({ deck, down, known, random })
      frame += 30
      const r1 = t.select(a)
      const r2 = t.select(b)
      r2.frames = 20
      ratings.push(r1, r2)
      known[a] = known[b] = true
      if (deck[a] === deck[b]) {
        down[a] = down[b] = false
        left--
      } else {
        lives--
      }
    }
    if (left === 0) lives = Math.min(20, lives + 5)
  }
  return ratings
}

function missOnPurpose(deck, down) {
  const fd = deck.map((_, i) => i).filter((i) => down[i])
  return [fd[0], fd.find((j) => deck[j] !== deck[fd[0]]) ?? fd[1]]
}

// a player with a perfect memory: a pair known, else an unknown card, its twin if known, else another unknown card
function honest({ deck, down, known, random }) {
  const fd = deck.map((_, i) => i).filter((i) => down[i])
  for (const i of fd) {
    const j = fd.find((j) => j !== i && known[i] && known[j] && deck[j] === deck[i])
    if (j !== undefined) return [i, j]
  }
  const unknown = fd.filter((i) => !known[i])
  const a = unknown.length ? unknown[random(unknown.length)] : fd[0]
  const twin = fd.find((j) => j !== a && known[j] && deck[j] === deck[a])
  if (twin !== undefined) return [a, twin]
  const rest = fd.filter((j) => j !== a && !known[j])
  return [a, rest.length ? rest[random(rest.length)] : fd.find((j) => j !== a)]
}

// a script showing the faces: an unknown card and its twin, every time
function cheat({ deck, down }) {
  const fd = deck.map((_, i) => i).filter((i) => down[i])
  return [fd[0], fd.find((j) => j !== fd[0] && deck[j] === deck[fd[0]])]
}

test('a player with a perfect memory is not suspicious', () => {
  let worst = 0
  for (let seed = 1; seed <= 150; seed++) {
    const { metrics, suspicious } = summarize(play(seed, honest))
    assert.equal(suspicious, false)
    assert.ok(metrics.decisions >= 20)
    worst = Math.max(worst, metrics.optimalRate)
  }
  assert.ok(worst < 0.35, `worst rate ${worst}`)
})

test('a player reading the faces is suspicious', () => {
  for (let seed = 1; seed <= 20; seed++) {
    const { metrics, suspicious, reasons } = summarize(play(seed, cheat, 6))
    assert.equal(suspicious, true)
    assert.ok(metrics.optimalRate > 0.95)
    assert.ok(metrics.expectedRate < 0.2)
    assert.match(reasons[0], /^paires trouvées sans avoir vu la carte \d+ % du temps \(\d+ coups/)
  }
})

test('the first level and the short games are not counted', () => {
  // the first level read, then only pairs missed on purpose: no pair found blind is counted
  const { metrics } = summarize(play(3, cheat, 1))
  assert.equal(metrics.optimal, 0)
  assert.equal(summarize(play(3, cheat, 1), { min_level: 0 }).metrics.optimal > 0, true)
  // two levels of cheat: too few decisions
  const short = summarize(play(3, cheat, 2))
  assert.ok(short.metrics.decisions > 0 && short.metrics.decisions < 20)
  assert.equal(short.suspicious, false)
  assert.equal(summarize(play(3, cheat, 2), { min_decisions: 2 }).suspicious, true)
})

test('a script choosing only the first card (a twin of a card seen) is caught by its luck', () => {
  // an unknown card whose twin is face down and seen, when there is one; else like a player
  const firstOnly = (state) => {
    const { deck, down, known } = state
    const fd = deck.map((_, i) => i).filter((i) => down[i])
    const a = fd.find((i) => !known[i] && fd.some((j) => j !== i && known[j] && deck[j] === deck[i]))
    if (a === undefined) return honest(state)
    return [a, fd.find((j) => j !== a && known[j] && deck[j] === deck[a])]
  }
  const { metrics, suspicious, reasons } = summarize(play(5, firstOnly, 12))
  assert.equal(metrics.firstPickRate, 1)
  assert.ok(metrics.optimalRate < 0.4)
  assert.equal(suspicious, true)
  assert.match(reasons.at(-1), /^cartes inconnues retournées avec une chance invraisemblable/)
})
