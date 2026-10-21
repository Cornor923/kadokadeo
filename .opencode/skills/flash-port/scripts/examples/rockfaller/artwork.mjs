// Rock Faller: picture of the board drawn by the port (seed 123, after the first steps), for the start screen
// composed by artwork.py and the comparison with the screenshots of the original.   usage: node artwork.mjs <out png>
// env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const b = await launch(+(process.env.PORT || 9870))
try {
  await b.goto(HOST + '/game.html?game=rockfaller&cls=GameRockFaller&seed=123&h=500')
  await b.waitFor('!!(window.__rockfaller && __rockfaller.frame >= 8)', 60000)
  // (the pointer out of the grid: no selection; the game stopped, the last step drawn)
  // (the frame rate counter of a debug build hidden)
  await b.eval('kk.ff.onTick = () => {}; if (kk.fpsText) kk.fpsText.visible = false; kk.updateGraphics(1); kk.render()')
  await b.screenshot(out, { x: 8, y: 8, width: 600, height: 460 })
} finally {
  await b.close()
}
