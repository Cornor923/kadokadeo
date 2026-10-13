// Plays a replay saved by q3.mjs (replay data, then the live end state) and compares the end state (MATCH expected).
// usage: node qr.mjs <replay file> [replay speed]      env: PORT (default 9966), HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const [data, liveOver] = readFileSync(process.argv[2], 'utf8').split('\n')
const b = await launch(+(process.env.PORT || 9966))
try {
  await b.goto(HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor&seed=123&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  await b.eval(`kk.setReplaySpeed(${+(process.argv[3] || 8)})`)
  await b.waitFor('!!window.__over', 900000)
  const rep = await b.eval('JSON.stringify(window.__over)')
  console.log('replay', rep, rep === liveOver.trim() ? 'MATCH' : 'MISMATCH\nlive   ' + liveOver)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
