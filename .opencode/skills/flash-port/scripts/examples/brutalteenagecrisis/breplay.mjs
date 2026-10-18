// Brutal Teenage Crisis: replays saved by b3.mjs (replays/b_replay_<n>.txt: the replay, then the end state of the live
// game) played by the current build: the same end state is expected (a change of the shared code, a rebase...).
// usage: node breplay.mjs <replay file>...      env: PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const PORT = +(process.env.PORT || 9660)
for (const file of process.argv.slice(2)) {
  const [data, liveOver] = readFileSync(file, 'utf8').split('\n').map((l) => l.trim())
  const b = await launch(PORT)
  try {
    await b.goto(HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500&replay=' + encodeURIComponent(data))
    await b.waitFor('!!(window.kk && kk.game && kk.game.mode)', 60000)
    await b.eval('kk.setReplaySpeed(16)')
    await b.waitFor('!!window.__over', 600000)
    const rep = await b.eval('JSON.stringify(window.__over)')
    console.log(file.split(/[\\/]/).pop(), rep === liveOver ? 'MATCH' : 'MISMATCH ' + rep + ' / ' + liveOver)
  } finally {
    await b.close()
  }
}
