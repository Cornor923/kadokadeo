// Gameplay fingerprint of a replay: the replay is played by a build (game.html fp=1) and the state of the game after
// every step (FP_STATE[pkg] of modes/<pkg>.js) is written, one JSON line per step. Two builds that play the same
// replay (a refactor, a rebase) must write the same file: `node fp.mjs cmp a b` prints the first step that differs.
// usage: node fp.mjs <pkg> <cls> <replay file> <out file> [bundle name, default <pkg>]   env: EXTRA (url params of the
//        test mode the replay was recorded with), PORT, H (canvas height, 500 for an Arkadeo game)
//        node fp.mjs cmp <file a> <file b>
// (replay file: the replay on its first line, as written by the bots b3.mjs / m3.mjs)
import { launch } from './cdp.mjs'
import { HOST } from './paths.mjs'
import { readFileSync, writeFileSync } from 'node:fs'

if (process.argv[2] === 'cmp') {
  const a = readFileSync(process.argv[3], 'utf8').split('\n'), b = readFileSync(process.argv[4], 'utf8').split('\n')
  const n = Math.max(a.length, b.length)
  for (let i = 0; i < n; i++) {
    if (a[i] !== b[i]) {
      console.log('DIFF at step', i, '(' + a.length + ' / ' + b.length + ' lines)\n< ' + (a[i] || '').slice(0, 1500) + '\n> ' + (b[i] || '').slice(0, 1500))
      process.exit(1)
    }
  }
  console.log('SAME', a.length, 'steps')
  process.exit(0)
}
const [pkg, cls, file, out, js] = process.argv.slice(2)
const PORT = +(process.env.PORT || 10310)
const data = readFileSync(file, 'utf8').split('\n')[0].trim()
const b = await launch(PORT)
try {
  await b.goto(HOST + `/game.html?game=${pkg}&cls=${cls}&seed=123&h=${process.env.H || 500}&fp=1` + (js ? '&js=' + js : '') +
    (process.env.EXTRA || '') + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game)', 60000)
  await b.eval('kk.setReplaySpeed(16)')
  await b.waitFor('!!window.__over', 900000)
  const n = await b.eval('window.__fp.length')
  const lines = []
  for (let i = 0; i < n; i += 2000) lines.push(...JSON.parse(await b.eval(`JSON.stringify(window.__fp.slice(${i}, ${i + 2000}))`)))
  writeFileSync(out, lines.join('\n'))
  console.log(file.split(/[\\/]/).pop(), 'steps', lines.length, 'over', await b.eval('JSON.stringify(window.__over)'))
} finally {
  const errs = b.consoleLines.filter((l) => /EXCEPTION|rror|CRASH/i.test(l))
  if (errs.length) console.log(errs.slice(0, 3).join('\n').slice(0, 2000))
  await b.close()
}
