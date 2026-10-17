// Brutal Teenage Crisis: picture of the level drawn by the port (the first frames, the hero falling in), for the start
// screen composed by artwork.py.   usage: node artwork.mjs <out png>      env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9560))
try {
  await b.goto(HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500')
  await b.waitFor('!!(window.kk && kk.game && kk.game.botState && kk.game.botState().frame >= 24)', 60000)
  // the HUD is hidden: the hearts and the phase icon do not belong to the start screen
  await b.eval('kk.ff.onTick = () => {}; kk.game.mode.hud.wrapper.visible = false; kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
