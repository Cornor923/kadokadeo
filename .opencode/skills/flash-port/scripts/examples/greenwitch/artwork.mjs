// Green Witch: picture of a dungeon drawn by the port (the witch, monsters on their way), for the start screen composed by
// artwork.py.   usage: node artwork.mjs <out png>      env: PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9934))
try {
  await b.goto(HOST + '/game.html?game=greenwitch&cls=GameGreenWitch&seed=123&h=500')
  await b.waitFor('!!(window.kk && kk.game && kk.game.frameCount > 120)', 60000)
  // the HUD (and the FPS of the debug build) do not belong to the start screen
  await b.eval('kk.ff.onTick = () => {}; const p = kk.game.testPlay(); p.hud.wrapper.set_visible(false); if (kk.fpsText) kk.fpsText.visible = false; kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
