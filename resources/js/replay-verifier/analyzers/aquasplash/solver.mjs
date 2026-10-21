// The rules of Aqua Splash (resources/hx/games/aquasplash) to value the moves of a player. A 6 x 6 board of slimes,
// index x * 6 + y (y = 0 at the top). A click (Slime.touch, one play) on a slime grows it (grow 1..4); grown past 4 it
// explodes (Slime.explode) into 4 drops that fly east, south, west and north (Drop.launch) and grow the first slime
// they hit, which can explode in turn: a chain. Every explosion of the chain counts (Game.incExplode): at 3, 8, 15...
// of them a play is won (Cs.WIN_PLAYS), a bonus slime hit gives 6 plays (Game.getBonus), a board left with bonus slimes
// only gives the next level (2000 points and a play). A click on an empty cell drops a flame that removes the slimes
// around it (Game.initBombing, Slime.ungrowing). Everything is known from the board: the new board of the next level and
// the slime shrunk when the time runs out (Game.forceReduce) are random, not part of a move.
//
// The drops are simulated Flash frame by Flash frame as the game moves them (Phys.update, Drop.update): which slime a
// drop hits depends on when the slimes ahead of it exploded, and on the size of their picture (a slime grown to 4 swells
// for a few frames, Data.SLIME_BOUNDS).
export const W = 6
export const H = 6
export const CELLS = W * H

// Cs
const ZONE = 40
const BOARD_X = 30
const BOARD_Y = 10
const MAX_GROW = 4
export const MAX_PLAYS = 18
export const BONUS_PLAYS = 6
export const WIN_PLAYS = [3, 8, 15, 24, 35, 45, 60]
export const SPOUT_POINTS = 250
export const SPOUT_CHAIN = 10
export const BONUS_LEVEL = 2000
// Drop.SPEED, Phys.POW_DROP (Math.pow(1.03, tmod)), mt.Timer.tmod (Game.update: 32 / FRAME_RATE)
const SPEED = 2.3
const POW_DROP = 1.0239288500120924
const TMOD = 32 / 40
const DIRS = [[1, 0], [0, 1], [-1, 0], [0, -1]]

// Data: frames of the goute of slime frames 1-4, bounds of each picture [xmin, xmax, ymin, ymax] (the pictures of the
// blinking eyes, after the goute, have the bounds of its last picture), frame 5 (empty, a bonus), the drop
const GOUTE_FRAMES = [5, 8, 8, 7]
const N = [-19.6, 19.9, -19.8, 19.7]
const SLIME_BOUNDS = [
  [N, N, N, N, N],
  [N, [-19.6, 19.9, -23.65, 19.7], [-20.5, 19.9, -22.3, 19.7], [-19.6, 19.9, -20.9, 19.7], N, N, N, N],
  [N, [-19.6, 19.9, -19.8, 20.55], N, N, N, N, N, N],
  [[-23.1, 23.4, -22.1, 22.7], [-30.35, 30.65, -29.05, 29.65], [-32.05, 32.35, -27.7, 28.2], [-28.55, 28.95, -26.45, 26.95], [-26.45, 26.75, -25.05, 25.65], [-26.65, 26.95, -23.55, 24.15], [-23.1, 23.4, -22.1, 22.7]],
]
const SLIME5_BOUNDS = N
const DROP_BOUNDS = [-12.65, 8.35, -5.5, 5.8]
// the box of the drop around its position, by direction (Drop.hitTest: the picture rotated by d * 90 degrees)
const DROP_BOX = (() => {
  const b = DROP_BOUNDS
  return [
    [b[0], b[1], b[2], b[3]],
    [-b[3], -b[2], b[0], b[1]],
    [-b[1], -b[0], -b[3], -b[2]],
    [b[2], b[3], -b[1], -b[0]],
  ]
})()

// MC.twips: Flash keeps the positions in twips
const twips = (v) => Math.trunc(v * 20) / 20
export const centerX = (x) => BOARD_X + x * ZONE + ZONE / 2
export const centerY = (y) => BOARD_Y + y * ZONE + ZONE / 2

// A board: grow (Int8Array: the size of the slime, 0 an empty cell, a bonus slime has 0 or -1), bonus (Uint8Array),
// goute (Uint8Array: the picture of the goute the slime clip shows, SlimeMC.goute; 0 = at rest, its last picture).
// The slimes still on the board (Game.slimes) are the cells with grow > 0 or a bonus, in the order of the board
// (Game.prepareLevel adds them column by column and the game only removes some).
export function makeBoard(grow, bonus, goute) {
  return {
    grow: Int8Array.from(grow),
    bonus: Uint8Array.from(bonus ?? new Array(CELLS).fill(0)),
    goute: Uint8Array.from(goute ?? new Array(CELLS).fill(0)),
  }
}

// a board from rows y = 0..5, one character by column x: '.' empty, '1'..'4' a slime, 'B' a bonus slime
export function parseBoard(...rows) {
  const grow = new Array(CELLS).fill(0)
  const bonus = new Array(CELLS).fill(0)
  rows.forEach((row, y) => [...row].forEach((c, x) => {
    if (c === 'B') bonus[x * H + y] = 1
    else if (c !== '.') grow[x * H + y] = +c
  }))
  return makeBoard(grow, bonus)
}

export const boardString = (grow, bonus) => {
  const rows = []
  for (let y = 0; y < H; y++) {
    let r = ''
    for (let x = 0; x < W; x++) {
      const i = x * H + y
      r += bonus[i] ? 'B' : grow[i] > 0 ? String(grow[i]) : '.'
    }
    rows.push(r)
  }
  return rows.join('/')
}

const alive = (grow, bonus, i) => grow[i] > 0 || bonus[i] === 1

// SlimeMC.frame: the frame of the clip (Slime.setSkin)
const frameOf = (grow, i) => (grow[i] > 0 ? Math.min(grow[i], 5) : 5)

// SlimeMC.stageBounds (scale 100: the slime under the pointer, scaled 110 by Slime.rollOver, is ignored)
function bounds(grow, bonus, goute, i) {
  const frame = frameOf(grow, i)
  if (frame >= 5) return SLIME5_BOUNDS
  const list = SLIME_BOUNDS[frame - 1]
  const n = GOUTE_FRAMES[frame - 1]
  const picture = goute[i] > 0 && goute[i] < n ? goute[i] : n
  return list[picture - 1] ?? N
}

// the cells on the way of a drop from cell i in direction d, in the order of Game.slimes (Drop.onWay)
const WAYS = []
for (let i = 0; i < CELLS; i++) {
  const fx = Math.floor(i / H)
  const fy = i % H
  WAYS.push(DIRS.map(([dx, dy]) => {
    const cells = []
    for (let j = 0; j < CELLS; j++) {
      const x = Math.floor(j / H)
      const y = j % H
      if (dx === 1 && y === fy && x > fx) cells.push(j)
      else if (dy === 1 && x === fx && y > fy) cells.push(j)
      else if (dx === -1 && y === fy && x < fx) cells.push(j)
      else if (dy === -1 && x === fx && y < fy) cells.push(j)
    }
    return cells
  }))
}

// the neighbours of a cell, itself excluded (Slime.isAdjacent), in the order of the board
const ADJACENT = []
for (let i = 0; i < CELLS; i++) {
  const x = Math.floor(i / H)
  const y = i % H
  const list = []
  for (let j = 0; j < CELLS; j++) {
    const ox = Math.floor(j / H)
    const oy = j % H
    if (j !== i && Math.abs(ox - x) <= 1 && Math.abs(oy - y) <= 1) list.push(j)
  }
  ADJACENT.push(list)
}

// the moves a player can make: every cell but a bonus slime (Slime.touch ignores it); an empty cell drops a flame
export function moves(board) {
  const list = []
  for (let i = 0; i < CELLS; i++) if (!board.bonus[i]) list.push(i)
  return list
}

const levelDone = (grow, bonus) => {
  // Game.checkNextLevel: no slime left but bonus ones
  for (let i = 0; i < CELLS; i++) if (grow[i] > 0 && !bonus[i]) return false
  return true
}

// The outcome of a click on cell i (Slime.touch, then the chain until the game waits again: Game.setPlay):
// explosions (of the chain), plays won (Game.upPlay: WIN_PLAYS, bonus slimes, next level; at most MAX_PLAYS),
// bonuses, level (the board is done), points, removed (slimes removed by a flame), grow / bonus (the board after),
// frames (Flash frames of the chain), hitFrames (the frame of each explosion). plays: the plays before the click.
export function simulate(board, i, plays = 10) {
  const grow = Int8Array.from(board.grow)
  const bonus = Uint8Array.from(board.bonus)
  const goute = Uint8Array.from(board.goute)
  let left = plays - 1
  const out = { explosions: 0, won: 0, bonuses: 0, level: false, points: 0, removed: 0, frames: 0, hitFrames: [], grow, bonus }
  const upPlay = () => {
    if (left >= MAX_PLAYS) return
    left++
    out.won++
  }
  if (bonus[i]) return null

  const drops = []
  const setGrow = (j, g) => {
    // SlimeMC.gotoAndStop: a new frame plays its goute from its first picture
    if (frameOf(grow, j) !== (g > 0 ? Math.min(g, 5) : 5)) goute[j] = 1
    grow[j] = g
  }
  const launch = (j) => {
    const x = centerX(Math.floor(j / H))
    const y = centerY(j % H)
    for (let d = 0; d < 4; d++) {
      drops.push({ from: j, d, x, y, vx: DIRS[d][0] * SPEED, vy: DIRS[d][1] * SPEED, rx: twips(x), ry: twips(y), done: false })
    }
  }
  // Slime.explode
  const explode = (j) => {
    if (bonus[j]) {
      out.bonuses++
      for (let k = 0; k < BONUS_PLAYS; k++) upPlay()
      setGrow(j, 0)
      bonus[j] = 0
      return
    }
    out.explosions++
    out.hitFrames.push(out.frames)
    if (WIN_PLAYS.includes(out.explosions)) upPlay()
    out.points += SPOUT_POINTS + out.explosions * SPOUT_CHAIN
    setGrow(j, 0)
    launch(j)
  }

  if (grow[i] > 0) {
    setGrow(i, grow[i] + 1)
    if (grow[i] > MAX_GROW) explode(i)
  } else {
    // the flame: the slimes around it (grow 0 skipped: a bonus not shrunk by the time) are removed
    let n = 0
    for (const j of ADJACENT[i]) {
      if (!alive(grow, bonus, j) || grow[j] === 0) continue
      setGrow(j, 0)
      bonus[j] = 0
      out.points += SPOUT_POINTS
      out.removed++
      if (++n === 8) break
    }
  }

  // the Flash frames of the chain: the clips advance (MC.frameStart), then the drops move (Game.updateSprites, the
  // drops launched during the frame move from the next one)
  while (drops.length) {
    out.frames++
    for (let j = 0; j < CELLS; j++) {
      if (grow[j] > 0 && grow[j] < 5 && goute[j] > 0) {
        if (goute[j] < GOUTE_FRAMES[grow[j] - 1]) goute[j]++
        else goute[j] = 0
      }
    }
    const list = drops.slice()
    for (const drop of list) {
      if (drop.done) continue
      // Phys.update
      drop.vx *= POW_DROP
      drop.vy *= POW_DROP
      drop.x += drop.vx * TMOD
      drop.y += drop.vy * TMOD
      drop.rx = twips(drop.x)
      drop.ry = twips(drop.y)
      // Drop.onSlime: the first slime on its way whose picture its box overlaps
      const box = DROP_BOX[drop.d]
      let hit = -1
      for (const j of WAYS[drop.from][drop.d]) {
        if (!alive(grow, bonus, j)) continue
        const b = bounds(grow, bonus, goute, j)
        const sx = centerX(Math.floor(j / H))
        const sy = centerY(j % H)
        if (drop.rx + box[0] <= sx + b[1] && sx + b[0] <= drop.rx + box[1] && drop.ry + box[2] <= sy + b[3] && sy + b[2] <= drop.ry + box[3]) {
          hit = j
          break
        }
      }
      let gone = hit >= 0
      if (!gone) {
        // Drop.outOfBounds (Cs.BOARD_X_LIMIT, BOARD_Y_LIMIT)
        gone = drop.rx < BOARD_X || drop.rx > BOARD_X + W * ZONE || drop.ry < BOARD_Y || drop.ry > BOARD_Y + H * ZONE
      }
      if (!gone) continue
      drop.done = true
      drops.splice(drops.indexOf(drop), 1)
      if (hit >= 0) {
        // Slime.growing
        if (bonus[hit]) {
          explode(hit)
        } else {
          setGrow(hit, grow[hit] + 1)
          if (grow[hit] > MAX_GROW) explode(hit)
        }
      }
    }
    if (out.frames > 2000) throw new Error('aquasplash: endless chain')
  }

  if (levelDone(grow, bonus)) {
    out.level = true
    out.points += BONUS_LEVEL
    upPlay()
  }
  return out
}

// what a move is worth: the plays first (the game ends when they run out), then the explosions
export const value = (o) => o.won * 1000 + o.explosions

// every move of a decision with its outcome
export function analyzeDecision(board, plays) {
  const list = []
  for (const i of moves(board)) list.push({ cell: i, outcome: simulate(board, i, plays) })
  return list
}

// the value of the best next move on a board (0: none, the game over). Only a click on a 4 explodes, a click on a
// smaller slime is worth nothing, a flame only by the level it ends (all the slimes left around it)
export function bestNext(board, plays) {
  if (plays <= 0) return 0
  let best = 0
  for (let i = 0; i < CELLS; i++) {
    if (board.grow[i] >= MAX_GROW && !board.bonus[i]) best = Math.max(best, value(simulate(board, i, plays)))
  }
  if (best < 1000 && plays < MAX_PLAYS) {
    const left = []
    for (let i = 0; i < CELLS; i++) if (board.grow[i] > 0 && !board.bonus[i]) left.push(i)
    for (let i = 0; i < CELLS && best < 1000; i++) {
      if (board.grow[i] > 0 || board.bonus[i]) continue
      if (left.every((j) => ADJACENT[i].includes(j))) best = 1000
    }
  }
  return best
}

// Every move of a decision valued looking one move ahead (v1: its own plays and explosions) and two moves ahead (v2:
// plus the best move on the board it leaves; a new level is random: nothing after it). A solver picks the best v1
// (the longest chain now) or the best v2 (a slime grown now for a bigger chain next).
export function rateDecision(board, plays) {
  const list = []
  let best1 = -1
  let best2 = -1
  for (const i of moves(board)) {
    const o = simulate(board, i, plays)
    const v1 = value(o)
    const left = plays - 1 + o.won
    const v2 = v1 + (o.level ? 0 : bestNext({ grow: o.grow, bonus: o.bonus, goute: new Uint8Array(CELLS) }, left))
    list.push({ cell: i, outcome: o, v1, v2 })
    best1 = Math.max(best1, v1)
    best2 = Math.max(best2, v2)
  }
  return { moves: list, best1, best2 }
}

// A click of the player against the moves of the board. optimal: the best move looking one or two moves ahead.
// counted: the decision says something (a chain of 2 explosions or more can be made, and most of the slimes
// that can be clicked are not a best move: a board where any 4 starts the same chain, or where nothing explodes, is
// not a decision)
export function rateMove(board, plays, cell, rating = rateDecision(board, plays)) {
  const { moves: list, best1, best2 } = rating
  const played = list.find((m) => m.cell === cell)
  if (!played) return null
  const isOptimal = (m) => m.v1 === best1 || m.v2 === best2
  const slimes = list.filter((m) => board.grow[m.cell] > 0)
  const optimalSlimes = slimes.filter(isOptimal).length
  return {
    counted: best1 >= 2 && slimes.length >= 2 && optimalSlimes * 2 < slimes.length,
    optimal: isOptimal(played),
    optimal1: played.v1 === best1,
    optimal2: played.v2 === best2,
    value: played.v1,
    best: best1,
    explosions: played.outcome.explosions,
    bestExplosions: Math.max(...list.map((m) => m.outcome.explosions)),
    outcome: played.outcome,
  }
}
