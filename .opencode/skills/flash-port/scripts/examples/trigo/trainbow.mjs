// Trigo: the RainbowCombo and the UniCombo, played frame by frame (test mode tg&hold=1): 5 triangles one around the
// other, one per colour (RainbowCombo +10), then 3 triangles of one colour (UniCombo +2), the blocks of each triangle
// given their colour by the script; prints the combo after each triangle and saves pictures of the texts.
// usage: node trainbow.mjs [shots dir]      env: HPORT, PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const shots = process.argv[2]
const b = await launch(+(process.env.PORT || 9792))
const TRIS = [
  [[[7, 6], [8, 7], [6, 8]], 0], [[[7, 4], [10, 9], [4, 9]], 1], [[[7, 2], [12, 10], [2, 10]], 2],
  [[[7, 1], [13, 12], [1, 12]], 3], [[[7, 0], [14, 14], [0, 14]], 4],
]
const UNI = [[[[3, 3], [5, 3], [3, 5]], 1], [[[2, 2], [7, 2], [2, 7]], 1], [[[1, 1], [10, 1], [1, 10]], 1]]
try {
  await b.goto(HOST + '/game.html?game=trigo&cls=GameTrigo&seed=123&h=500&test=tg&hold=1')
  await b.waitFor('!!(window.kk && kk.game && kk.game.grid)', 60000)
  const run = async (tris, name) => {
    const r = await b.eval(`(() => {
      const g = kk.game, tick = () => g.flashFrame(), S = () => g.step._hx_index, out = []
      const until = (f, max = 3000) => { let n = 0; while (!f() && n < max) { tick(); n++ } return n }
      until(() => S() === 1)
      for (const [cells, id] of ${JSON.stringify(tris)}) {
        for (const [x, y] of cells) g.grid[x][y].id = id
        for (const [x, y] of cells) g.onClick(g.grid[x][y])
        out.push([g.step._hx_index, g.combo, g.lastGroup ? g.lastGroup.blocks.length : 0])
        until(() => g.swapingBlocks === 0)
      }
      for (let i = 0; i < 4; i++) tick()
      kk.render ? kk.render() : null
      return JSON.stringify(out)
    })()`)
    console.log(name, '[step, combo, blocks] after each triangle', r)
    if (shots) {
      // (the game drawn again: it runs by itself for a moment)
      await b.eval('kk.game.update = kk.game.__update; if (kk.fpsText) kk.fpsText.visible = false')
      await b.sleep(250)
      await b.eval('kk.game.update = () => {}')
      await b.screenshot(shots + '/' + name + '.png', { x: 8, y: 8, width: 600, height: 500 })
    }
  }
  await run(TRIS, 'rainbow')
  await b.eval(`(() => { const g = kk.game; g.onClick(g.grid[7][6]); let n = 0; while (g.step._hx_index !== 1 && n++ < 3000) g.flashFrame() })()`)
  await run(UNI, 'unicombo')
} finally {
  console.log(b.consoleLines.filter((l) => /EXCEPTION|rror/.test(l)).slice(0, 5).join('\n'))
  await b.close()
}
