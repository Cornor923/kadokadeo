// What a Memopsy player could know when he turned a card (pure functions, no browser): the faces he has seen since
// the level began, against the faces still hidden. A card turned that was never seen is a lottery for a player, whose
// odds only depend on how many cards are still unknown; a script reading the faces in the memory of the game wins it
// every time. Rules of resources/hx/games/memopsy (Game.hx):
// - initLevel: the level is width x height cards (Const.LEVELS, the last one repeated), npairs = width * height / 2
//   ids `i % Const.NUMCARDS` (10) twice each: 6 x 4 levels have 4 cards of ids 0 and 1, any two of them match;
// - cardSelect: one card shown at a time, then a second one (lock); onShowDone: the two ids equal, they stay face up
//   (npairs--, a new level at 0), different, both are turned back face down (looseLife).

// one card turned, rated: kind 'first' (the first of the two), 'blind' (the second, no card of the first's id seen
// face down: a guess), 'memory' (the second, a card of the first's id seen face down), 'seenMiss' (the second, a
// card seen before that does not match); p: the chance of a player to win it (blind: the second matches; first: its
// id is one of a card seen face down), hit: won, unknown: number of unseen cards it was chosen among
export function createTracker() {
  let ids = []
  let down = []
  let seen = []
  let first = null
  let level = -1

  const faceDown = () => {
    const out = []
    for (let i = 0; i < ids.length; i++) if (down[i]) out.push(i)
    return out
  }

  return {
    // a new level: ids[i] = id of the card i (any order, one entry by card), every card face down, none seen
    level(levelIds, number) {
      ids = levelIds.slice()
      down = ids.map(() => true)
      seen = ids.map(() => false)
      first = null
      level = number
    },

    // the card i turned face up by the player (Game.cardSelect accepted it); returns its rating, null when the card
    // cannot be turned (face up already: not a move of the game)
    select(i) {
      if (i < 0 || i >= ids.length || !down[i]) return null
      const fd = faceDown()
      let rating
      if (first === null) {
        const unseen = fd.filter((j) => !seen[j])
        // ids of the cards seen face down: an unseen card of one of them makes a pair the player can complete
        const seenIds = new Set(fd.filter((j) => seen[j]).map((j) => ids[j]))
        const known = unseen.filter((j) => seenIds.has(ids[j])).length
        rating = {
          kind: 'first',
          level,
          wasSeen: seen[i],
          unknown: unseen.length,
          p: unseen.length ? known / unseen.length : 0,
          hit: !seen[i] && seenIds.has(ids[i]),
        }
        first = i
        down[i] = false
        seen[i] = true
        return rating
      }

      const x = ids[first]
      const others = fd.filter((j) => j !== first)
      const knownPartner = others.some((j) => seen[j] && ids[j] === x)
      const hit = ids[i] === x
      if (knownPartner) {
        rating = { kind: 'memory', level, hit }
      } else if (!seen[i]) {
        const unseen = others.filter((j) => !seen[j])
        const partners = unseen.filter((j) => ids[j] === x).length
        rating = { kind: 'blind', level, unknown: unseen.length, p: unseen.length ? partners / unseen.length : 0, hit }
      } else {
        rating = { kind: 'seenMiss', level, hit: false }
      }
      seen[i] = true
      // onShowDone: a pair stays face up, two different cards are turned back
      if (hit) down[i] = false
      else down[first] = true
      first = null
      return rating
    },

    // a first card turned and its pair not chosen yet
    get pending() {
      return first !== null
    },
  }
}

// P(X >= k) for X the number of events won among independent events of chances ps (Poisson binomial), as log10
// (-Infinity: below the doubles). O(n k)
export function log10Tail(ps, k) {
  if (k <= 0) return 0
  // dp[j]: P(j won so far), j < k; above: P(k won or more)
  const dp = new Float64Array(k)
  dp[0] = 1
  let above = 0
  for (const p of ps) {
    above += dp[k - 1] * p
    for (let j = k - 1; j > 0; j--) dp[j] = dp[j] * (1 - p) + dp[j - 1] * p
    dp[0] *= 1 - p
  }
  return above > 0 ? Math.log10(Math.min(1, above)) : -Infinity
}

// provisional (no run of production to calibrate on): simulated players with a perfect memory find 10 to 22 % of the
// blind pairs (30 % at most using the bias of the shuffle), a script reading the faces nearly 100 %
const DEFAULTS = {
  min_decisions: 20,
  optimal_rate: 0.6,
  max_guess_chance: 0.34,
  min_level: 1,
  bias_factor: 3,
  max_log10_p: -9,
}

const median = (sorted) => (sorted.length ? sorted[Math.floor(sorted.length / 2)] : null)
const ratio = (a, b) => (b ? +(a / b).toFixed(3) : null)

// the metrics of a game from the ratings of its cards (createTracker().select, plus `frames`: the frames between
// the first card and the second one, on the blind ones) and whether it is suspicious. config: see DEFAULTS
// - decisions: the blind second cards (the player could not know where the pair was) with a chance of at most
//   max_guess_chance (the last unknown cards of a level are nearly forced), on the levels from min_level (0 based:
//   the first level is dealt before the first frame, from the seed alone); optimal: the ones that matched;
// - luck: the unseen cards turned (blind second ones, and first ones while a card of a seen id was still face down)
//   won against their chance multiplied by bias_factor (Game.shuffle swaps width x height random pairs of cards
//   from a sorted deck: a card is more often near its twin than by chance, which an expert could use: up to 2.6
//   times the chance of a guess in the 6 x 4 levels); luckLog10P: log10 of the chance of winning that many.
export function summarize(ratings, config = {}) {
  const c = { ...DEFAULTS }
  for (const key of Object.keys(DEFAULTS)) if (config[key] != null) c[key] = config[key]
  const s = { decisions: 0, optimal: 0, expected: 0, first: 0, firstHits: 0, firstExpected: 0, memory: 0, memoryHits: 0, seenMisses: 0, pairs: 0, misses: 0 }
  const luck = []
  let luckHits = 0
  const frames = []
  for (const r of ratings) {
    if (r.kind !== 'first') {
      if (r.hit) s.pairs++
      else s.misses++
    }
    if (r.kind === 'memory') {
      s.memory++
      if (r.hit) s.memoryHits++
    } else if (r.kind === 'seenMiss') {
      s.seenMisses++
    }
    if (r.level < c.min_level) continue
    const lottery = (r.kind === 'blind' && r.p > 0) || (r.kind === 'first' && !r.wasSeen && r.p > 0 && r.p < 1)
    if (!lottery) continue
    if (r.kind === 'blind' && r.p <= c.max_guess_chance) {
      s.decisions++
      s.expected += r.p
      if (r.hit) s.optimal++
      if (r.frames != null) frames.push(r.frames)
    }
    if (r.kind === 'first') {
      s.first++
      s.firstExpected += r.p
      if (r.hit) s.firstHits++
    }
    const p = r.p * c.bias_factor
    if (p < 1) {
      luck.push(p)
      if (r.hit) luckHits++
    }
  }
  const sorted = frames.sort((a, b) => a - b)
  const log10P = log10Tail(luck, luckHits)
  const metrics = {
    decisions: s.decisions,
    optimal: s.optimal,
    // blind second cards that matched
    optimalRate: ratio(s.optimal, s.decisions),
    // what a player wins by chance on the same cards
    expectedRate: ratio(s.expected, s.decisions),
    valueRate: null,
    firstPicks: s.first,
    firstPickHits: s.firstHits,
    firstPickRate: ratio(s.firstHits, s.first),
    firstPickExpectedRate: ratio(s.firstExpected, s.first),
    luckEvents: luck.length,
    luckHits,
    luckLog10P: Number.isFinite(log10P) ? +log10P.toFixed(1) : -324,
    // the second card when its twin had been seen: what memory does (not suspicious)
    memory: s.memory,
    memoryRate: ratio(s.memoryHits, s.memory),
    seenMisses: s.seenMisses,
    pairs: s.pairs,
    misses: s.misses,
    // frames between the first card and the blind second one (32 by second)
    meanDecisionFrames: sorted.length ? Math.round(sorted.reduce((a, v) => a + v, 0) / sorted.length) : null,
    medianDecisionFrames: median(sorted),
    p10DecisionFrames: sorted.length ? sorted[Math.floor(sorted.length * 0.1)] : null,
  }
  const reasons = []
  if (s.decisions >= c.min_decisions && metrics.optimalRate >= c.optimal_rate) {
    reasons.push(`paires trouvées sans avoir vu la carte ${Math.round(metrics.optimalRate * 100)} % du temps (${s.decisions} coups, ${Math.round(metrics.expectedRate * 100)} % attendus au hasard, limite ${Math.round(c.optimal_rate * 100)} %)`)
  }
  if (luck.length >= c.min_decisions && metrics.luckLog10P <= c.max_log10_p) {
    reasons.push(`cartes inconnues retournées avec une chance invraisemblable : ${luckHits} gagnées sur ${luck.length} (probabilité 10^${Math.round(metrics.luckLog10P)}, limite 10^${c.max_log10_p})`)
  }
  return { metrics, suspicious: reasons.length > 0, reasons }
}
