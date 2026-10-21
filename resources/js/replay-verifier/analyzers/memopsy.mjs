// Analyzer of Memopsy for the replay verifier (see README of this folder). A memory game: the faces of the cards are
// hidden information, the player only knows the ones he turned since the level began. A script reading the faces in
// the memory of the game finds a pair whose second card was never seen nearly every time; a player finds it by chance
// (one card among the unknown ones). The cards turned are rated against what the player had seen (memopsy/memory.mjs):
// no "best move", only "impossible knowledge". The level dealt before the first frame is not counted (from the seed
// alone: a seed played twice deals it twice).
import { createTracker, summarize } from './memopsy/memory.mjs'

export const meta = { game: 'memopsy', version: 1 }

// frames of replay events kept to order cards turned on the same frame
const EVENT_WINDOW = 4

export function create({ kk, config = {} }) {
  // the presses of the replay (events {k: 0, x, y}: Game.pressCard), by frame
  const presses = new Map()
  const frames = kk.replay.playFrames
  const records = kk.replay.playRecords
  if (!Array.isArray(frames) || !Array.isArray(records)) throw new Error('unsupported build')
  frames.forEach((frame, i) => {
    for (const event of records[i].events || []) {
      if (event && event.k === 0) {
        if (!presses.has(frame)) presses.set(frame, [])
        presses.get(frame).push({ x: event.x, y: event.y })
      }
    }
  })

  const tracker = createTracker()
  const ratings = []
  // the level (Game.level: columns of cards) being watched, its height, the cards face up on the frame before
  let level = null
  let height = 0
  let up = []
  let firstFrame = null

  // the latest press on the cell x, y in the last frames (cards turned on the same frame, in the order pressed)
  const pressOrder = (frame, x, y) => {
    for (let f = frame; f >= frame - EVENT_WINDOW; f--) {
      const list = presses.get(f)
      if (!list) continue
      for (let k = list.length - 1; k >= 0; k--) if (list[k].x === x && list[k].y === y) return f * 64 + k
    }
    return Infinity
  }

  return {
    // before the frame: the cards turned face up during the frame before (Card.show(true) sets visible at once; a
    // pair found stays visible, a pair missed is turned back by Card.show(false))
    beforeFrame(frame) {
      const game = kk.game
      if (!game) return
      const cols = game.level
      if (!Array.isArray(cols) || !Array.isArray(cols[0]) || typeof game.nlevel !== 'number') throw new Error('unsupported build')
      if (cols !== level) {
        level = cols
        height = cols[0].length
        const ids = []
        for (let x = 0; x < cols.length; x++) {
          for (let y = 0; y < height; y++) {
            const card = cols[x][y]
            if (!card || typeof card.id !== 'number' || typeof card.visible !== 'boolean') throw new Error('unsupported build')
            ids[x * height + y] = card.id
          }
        }
        tracker.level(ids, game.nlevel)
        up = ids.map(() => false)
        firstFrame = null
      }

      const turned = []
      for (let x = 0; x < cols.length; x++) {
        for (let y = 0; y < height; y++) {
          const i = x * height + y
          const visible = cols[x][y].visible
          if (visible && !up[i]) turned.push({ i, order: pressOrder(frame - 1, x, y) })
          up[i] = visible
        }
      }
      turned.sort((a, b) => a.order - b.order)
      for (const { i } of turned) {
        const pending = tracker.pending
        const rating = tracker.select(i)
        if (!rating) continue
        // the frame before: the frame the press was applied on
        if (!pending) firstFrame = frame - 1
        else if (firstFrame !== null) rating.frames = frame - 1 - firstFrame
        ratings.push(rating)
      }
    },

    finish() {
      const result = summarize(ratings, config)
      // the daily game deals every level from the seed (no Seed.stir): the faces could be known from another game
      result.metrics.stirred = kk.replay.rngStir !== false
      if (result.suspicious && !result.metrics.stirred) {
        result.reasons.push('partie sans mélange du hasard (jeu du jour) : les cartes peuvent venir d\'une autre partie de la même seed')
      }
      return result
    },
  }
}
