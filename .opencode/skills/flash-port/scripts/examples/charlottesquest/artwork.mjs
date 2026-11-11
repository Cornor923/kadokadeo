// Charlotte's Quest: picture of the start of a game drawn by the port (the bedroom, Charlotte on her unicorn, the first
// room), for the start screen composed by artwork.py.   usage: node artwork.mjs <out png>      env: PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9760))
try {
  await b.goto(HOST + '/game.html?game=charlottesquest&cls=GameCharlottesQuest&seed=123&h=500&test=cq&hold=110&cqseed=' + (process.env.SEED || 424242))
  await b.waitFor('!!(window.kk && kk.game && kk.game.frameCount >= 110)', 60000)
  // the lives (and the FPS of the debug build) do not belong to the start screen
  await b.sleep(300)
  await b.eval('kk.ff.onTick = () => {}; kk.game.player.lifeCont.set_visible(false); if (kk.fpsText) kk.fpsText.visible = false; kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
