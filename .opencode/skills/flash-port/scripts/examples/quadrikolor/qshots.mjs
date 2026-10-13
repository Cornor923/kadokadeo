// Screenshots of a replay saved by q3.mjs at normal speed: every 250 ms while the condition holds (default: the score
// sheet is shown, state FICHE).
// usage: node qshots.mjs <replay file> [prefix] [condition js]     env: PORT (default 9969), HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const [data] = readFileSync(process.argv[2], 'utf8').split('\n')
const pre = process.argv[3] || 'f'
const cond = process.argv[4] || 'kk.game.state == 6'
const dir = gameDir('quadrikolor', 'shots')
const b = await launch(+(process.env.PORT || 9969))
let k = 0
try {
  await b.goto(HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor&seed=123&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  while (!(await b.eval('!!window.__over'))) {
    if (await b.eval(cond)) await b.screenshot(`${dir}/${pre}${String(k++).padStart(3, '0')}.png`, { x: 8, y: 8, width: 600, height: 600 })
    await b.sleep(250)
  }
  console.log('shots', k)
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
