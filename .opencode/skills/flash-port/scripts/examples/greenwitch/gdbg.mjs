// Green Witch: runs a JS snippet in a game after N steps and takes screenshots (debugging the display).
// usage: node gdbg.mjs '<js run once, `p` = Play.ME>' [steps before] [screenshots] [name]   env: HPORT, KKP_WORK, PORT, EXTRA
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'

const js = process.argv[2] || ''
const before = +(process.argv[3] || 60)
const n = +(process.argv[4] || 3)
const name = process.argv[5] || 'dbg'
const b = await launch(+(process.env.PORT || 9934))
try {
  await b.goto(HOST + '/game.html?game=greenwitch&cls=GameGreenWitch&seed=123&h=500' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && kk.game.frameCount > ' + before + ')', 60000)
  if (js) console.log(await b.eval(`(() => { const p = kk.game.testPlay(); ${js} })()`))
  const dir = gameDir('greenwitch', 'shots')
  for (let i = 0; i < n; i++) {
    await b.sleep(120)
    await b.screenshot(dir + `/${name}-${i}.png`, { x: 8, y: 8, width: 600, height: 500 })
  }
} finally {
  console.log(b.consoleLines.filter((l) => /EXCEPTION|CRASH|rror/.test(l)).slice(0, 10).join('\n'))
  await b.close()
}
