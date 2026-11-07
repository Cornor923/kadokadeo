// Trigo: the same scenario played frame by frame in the port (harness, test mode tg&hold=1: game.flashFrame()) and in the
// HTML5 port of the user (its TrigoBoot.me.devTick(1), served by Twinoid/server): the number of frames of each phase of
// the game (the grid coming in, the flips of a triangle, a triangle taken, the time of a combo running out, the blocks
// destroyed, the grid made again). The blocks of the triangles are given a colour by the script in both games.
// usage: node tcmp.mjs      env: HPORT (harness), TPORT (Twinoid server, default 3098), PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const TPORT = process.env.TPORT || 3098
const SCEN = `(async (g, tick) => {
  const S = () => g.step._hx_index   // S_Create 0, S_Play 1, S_FPlay 2, S_Gather 3, S_Destroy 4, S_GameOver 5
  const until = (f, max = 3000) => { let n = 0; while (!f() && n < max) { tick(); n++ } return n }
  const out = {}
  out.start = until(() => S() === 1)
  const tri = (cells, id) => { for (const [x, y] of cells) g.grid[x][y].id = id; for (const [x, y] of cells) g.onClick(g.grid[x][y]) }
  // a triangle: the flips, then a click on it
  tri([[2, 2], [10, 3], [5, 11]], 0)
  out.afterTriangle = S()
  out.combo = g.combo
  out.blocks = g.lastGroup.blocks.length
  out.flips = until(() => g.swapingBlocks === 0)
  out.fpTimer = g.fpTimer
  g.onClick(g.grid[2][2])
  out.gather = until(() => S() === 0)
  out.score = g.__score ? g.__score() : null
  out.refill = until(() => S() === 1)
  // a triangle whose time runs out: destroyed
  tri([[1, 1], [8, 2], [3, 9]], 2)
  out.blocks2 = g.lastGroup.blocks.length
  out.fplay = until(() => S() === 4)
  out.destroy = until(() => S() === 0)
  out.refill2 = until(() => S() === 1)
  // two triangles in a combo, then taken
  tri([[6, 6], [9, 6], [7, 9]], 1)
  until(() => g.swapingBlocks === 0)
  tri([[4, 4], [12, 5], [7, 13]], 3)
  out.comboAfter = g.combo
  out.flips2 = until(() => g.swapingBlocks === 0)
  g.onClick(g.grid[6][6])
  out.gather2 = until(() => S() === 0)
  out.gTimer = g.gTimer
  out.timerDelta = g.constructor.TIMER_DELTA
  return JSON.stringify(out)
})`
const b = await launch(+(process.env.PORT || 9791))
try {
  // the port of KadoKadeo
  await b.goto(HOST + '/game.html?game=trigo&cls=GameTrigo&seed=123&h=500&test=tg&hold=1')
  await b.waitFor('!!(window.kk && kk.game && kk.game.grid)', 60000)
  const kkr = await b.eval(`${SCEN}(kk.game, () => kk.game.flashFrame()).then((r) => r.replace('"timerDelta":', '"timerDelta(static)":' + GameTrigo.TIMER_DELTA + ',"_":'))`)
  console.log('kadokadeo', kkr)
  // the HTML5 port of the user
  await b.goto(`http://127.0.0.1:${TPORT}/new-trigo`)
  await b.waitFor('!!(window.TrigoBoot && TrigoBoot.me && TrigoBoot.me.game && TrigoBoot.me.game.grid)', 60000)
  const h5 = await b.eval(`${SCEN}(TrigoBoot.me.game, () => TrigoBoot.me.devTick(1))`)
  console.log('html5    ', h5)
} finally {
  console.log(b.consoleLines.filter((l) => /EXCEPTION|rror/.test(l)).slice(0, 5).join('\n'))
  await b.close()
}
