// Fafi 360: picture of the match drawn by the port (the players in place, the kick-off), for the start screen composed by
// artwork.py.   usage: node artwork.mjs <out png>      env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9560))
try {
  await b.goto(HOST + '/game.html?game=fafi360&cls=GameFafi360&seed=123&h=500')
  await b.waitFor('!!(window.kk && kk.game && kk.game.botState && kk.game.botState().playing)', 60000)
  // the chrono, the score (and the FPS of the debug build) do not belong to the start screen
  await b.eval('kk.ff.onTick = () => {}; const g = kk.game; for (const o of [g.chronoField, g.chronoBg, g.scoreField, g.powerBar.wrapper]) o.set_visible(false); if (kk.fpsText) kk.fpsText.visible = false; kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
