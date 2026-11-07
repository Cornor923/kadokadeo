// Trigo: picture of the game drawn by the port at the start of a game (the grid, the clock, the combo meter), for the start
// screen composed by artwork.py.
// usage: node artwork.mjs <out png>      env: PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9562))
try {
  await b.goto(HOST + '/game.html?game=trigo&cls=GameTrigo&seed=123&h=500')
  await b.waitFor('!!(window.kk && kk.game && window.__trigo && window.__trigo.step === "S_Play")', 60000)
  await b.sleep(1500)
  // (the FPS of the debug build does not belong to the start screen)
  await b.eval('kk.ff.onTick = () => {}; if (kk.fpsText) kk.fpsText.visible = false; kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
