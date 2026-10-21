// Toy Maniak: what a press of the mouse hits and does, and how precisely the presses land on what they hit (pure
// functions, no browser: see ../toymaniak.mjs). Coordinates in Flash pixels (the game's 300 x 300, the canvas / 2).
//
// A toy of a rail is pressed through its invisible button (Toy: mc.but, Data.BUT_RECT) anywhere on 50 x 60 pixels, a slot
// of the box anywhere on its rounded square: a player presses somewhere on the picture, never twice on the same pixel
// of it. A program that clicks where it computed the target (an auto-player reading the game or the screen) presses
// on the same point of every toy of a kind: its presses pile up on one pixel.

// Const.RAIL_Y_BASE + Const.RAIL_Y_DELTA * rail: the line of each rail (the toys never move up or down)
export const RAIL_Y = [70, 145, 220]
// Data.BUT_RECT: the button of a toy around its (Std.int(x), rail y): xMin, xMax, yMin, yMax
export const BUT_RECT = [-25, 25, -52.25, 7.75]
// the box at (150, 300) (Game.new) + Data.SLOTS: the centre of the slots s0, s1, s2
export const SLOTS = [[104, 272.6], [150, 272.6], [196, 272.6]]
// a slot: its square (Data.SLOT_HIT_X / _Y: -21.5) and, when it holds a toy, the button of that toy (x +-25, up to
// 41 pixels above the centre: Data.SLOT_TOY + BUT_RECT)
export const SLOT_HIT = [-25, 25, -41, 21.5]

// What Buttons.find returns for a press at (x, y) and what the press does (Game.selectToy, Game.selectSlot).
// state: { rails: [{ toys: [{ x, t, lock }] }], sels: [t], cursor: t | null } (t: -1 an empty place, 0-3 the colours,
// 4-6 the bonuses), read before the frame of the press (the toys have not moved yet: Game.flashFrame presses first).
// returns null (nothing hit) or { kind: 'toy' | 'slot', rail | slot, index, t, dx, dy, effect }
//   dx, dy: the press relative to the toy (its Std.int(x), its rail's line) or to the centre of the slot
//   effect: 'take' (into the hand), 'put' (from the hand into an empty place), 'swap', or null (the press does nothing:
//   a locked toy at the crusher, an empty place or slot with nothing in hand)
export function pressTarget(state, x, y) {
  const hand = state.cursor
  // the toys are over the box (plane 1 vs 0), the toys of a rail added later over the older ones
  for (let r = 0; r < state.rails.length; r++) {
    const toys = state.rails[r].toys
    for (let i = toys.length - 1; i >= 0; i--) {
      const toy = toys[i]
      const dx = x - Math.trunc(toy.x)
      const dy = y - RAIL_Y[r]
      if (dx < BUT_RECT[0] || dx > BUT_RECT[1] || dy < BUT_RECT[2] || dy > BUT_RECT[3]) continue
      // Game.selectToy
      let effect = null
      if (!toy.lock) {
        if (hand == null) effect = toy.t === -1 ? null : 'take'
        else effect = toy.t === -1 ? 'put' : 'swap'
      }
      return { kind: 'toy', rail: r, index: i, t: toy.t, dx, dy, effect }
    }
  }
  // the nearest slot (they are 46 pixels apart)
  let best = null
  SLOTS.forEach(([sx, sy], s) => {
    const dx = x - sx
    const dy = y - sy
    if (dx < SLOT_HIT[0] || dx > SLOT_HIT[1] || dy < SLOT_HIT[2] || dy > SLOT_HIT[3]) return
    if (!best || Math.abs(dx) < Math.abs(best.dx)) best = { kind: 'slot', slot: s, t: state.sels[s], dx, dy }
  })
  if (best) {
    // Game.selectSlot
    if (best.t === -1) best.effect = hand == null ? null : 'put'
    else best.effect = hand == null ? 'take' : 'swap'
  }
  return best
}

// The coordinates of a press that tell where the player aimed, and the group of the presses aimed alike: on a toy,
// only its height (the toy moves along the rail while the hand travels: the x lags by the reaction, a program's too);
// grouped by kind of toy (a program reading the screen clicks the centre of each picture, the pictures differ); on a
// slot, both coordinates, grouped by slot.
export function aimOf(target) {
  if (target.kind === 'toy') return { group: 'toy' + target.t, values: [target.dy] }
  return { group: 'slot' + target.slot, values: [target.dx, target.dy] }
}

const medianOf = (values) => {
  const s = values.slice().sort((a, b) => a - b)
  const m = s.length >> 1
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

// How the aimed presses land: aims = [{ group, values }] (aimOf).
//   exact: presses within `tolerance` pixels (every coordinate) of the median of the OTHER presses of their group
//   (a group of fewer than minGroup presses is left out: nothing to compare with)
//   spread: the pooled standard deviation of the coordinates around the mean of their group (pixels)
// A player: a few presses exact by chance, a spread of many pixels; a program: nearly all exact, a spread near 0.
export function aimPrecision(aims, { tolerance = 1, minGroup = 4 } = {}) {
  const groups = new Map()
  for (const a of aims) {
    if (!groups.has(a.group)) groups.set(a.group, [])
    groups.get(a.group).push(a.values)
  }
  let counted = 0
  let exact = 0
  let squares = 0
  let freedom = 0
  for (const list of groups.values()) {
    if (list.length < minGroup) continue
    const dims = list[0].length
    for (let k = 0; k < list.length; k++) {
      counted++
      let ok = true
      for (let d = 0; d < dims && ok; d++) {
        const others = list.filter((_, j) => j !== k).map((v) => v[d])
        if (Math.abs(list[k][d] - medianOf(others)) > tolerance) ok = false
      }
      if (ok) exact++
    }
    for (let d = 0; d < dims; d++) {
      const values = list.map((v) => v[d])
      const mean = values.reduce((s, v) => s + v, 0) / values.length
      squares += values.reduce((s, v) => s + (v - mean) ** 2, 0)
      freedom += values.length - 1
    }
  }
  return {
    presses: counted,
    exact,
    exactRate: counted ? exact / counted : null,
    spread: freedom ? Math.sqrt(squares / freedom) : null,
  }
}
