// Green Witch: loads the game in the harness, lets it run, shows the console errors and takes screenshots.
// usage: node --experimental-websocket g0.mjs [seconds] [extra url params]     env: HPORT, KKP_WORK, PORT (DevTools)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'

const secs = +(process.argv[2] || 6)
const extra = process.argv[3] || ''
const b = await launch(+(process.env.PORT || 9932))
try {
  await b.goto(HOST + '/game.html?game=greenwitch&cls=GameGreenWitch&seed=123&h=500' + extra)
  await b.waitFor('!!(window.kk && kk.game && kk.game.frameCount > 0)', 60000)
  const dir = gameDir('greenwitch', 'shots')
  for (let i = 0; i < 3; i++) {
    await new Promise((r) => setTimeout(r, secs * 1000 / 3))
    await b.screenshot(dir + `/g0-${i}.png`, { x: 8, y: 8, width: 600, height: 500 })
  }
  console.log(await b.eval('JSON.stringify(kk.game.debugState())'))
} finally {
  console.log(b.consoleLines.filter((l) => /EXCEPTION|CRASH|rror/.test(l)).slice(0, 20).join('\n'))
  await b.close()
}
