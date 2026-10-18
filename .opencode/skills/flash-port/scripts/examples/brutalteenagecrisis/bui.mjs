// Brutal Teenage Crisis: the shared screens on the canvas of an Arkadeo game (600 x 500): the controls of a replay
// (shown by a mouse move), the seek ring, then the end screen once the replay is over.
// usage: node bui.mjs <replay file of b3.mjs> <out dir>      env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const [file, out] = process.argv.slice(2)
const data = readFileSync(file, 'utf8').split('\n')[0].trim()
const b = await launch(+(process.env.PORT || 9570))
const clip = { x: 8, y: 8, width: 600, height: 500 }
try {
  await b.goto(HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode && kk.replay.getCurrentFrame() > 300)', 60000)
  await b.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 300, y: 300 })
  await b.sleep(300)
  await b.screenshot(out + '/replay_hud.png', clip)
  await b.eval('kk.seekReplay(Math.floor(kk.getReplayLength() * 0.9))')
  await b.sleep(400)
  await b.screenshot(out + '/replay_seek.png', clip)
  await b.eval('kk.setReplaySpeed(8)')
  await b.waitFor('!!window.__over', 600000)
  await b.sleep(6000)
  await b.screenshot(out + '/end_scene.png', clip)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
