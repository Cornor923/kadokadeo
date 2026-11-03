// Fafi 360: screenshots of a game at given frames of the game (the kick-off, a goal, an explosion, the end screen...).
// usage: node fpics.mjs <out dir> <frame,frame,...>      env: EXTRA (url params, e.g. a test mode), PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const [out, list] = process.argv.slice(2)
const frames = list.split(',').map(Number)
const b = await launch(+(process.env.PORT || 9560))
try {
  await b.goto(HOST + '/game.html?game=fafi360&cls=GameFafi360&seed=123&h=500' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && kk.game.ball)', 60000)
  for (const f of frames) {
    await b.waitFor(`kk.game == null || kk.game.frameCount >= ${f}`, 300000)
    await b.screenshot(out + '/p' + String(f).padStart(5, '0') + '.png', { x: 8, y: 8, width: 600, height: 500 })
  }
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
