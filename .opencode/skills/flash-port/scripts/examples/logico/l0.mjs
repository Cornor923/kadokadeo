// Logico: the game loads, a few screenshots, the console errors.
// usage: node l0.mjs [ms]     env: PORT (DevTools, default 9861), HPORT, EXTRA (url params)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
const PORT = +(process.env.PORT || 9861)
const b = await launch(PORT)
await b.goto(HOST + '/game.html?game=logico&cls=GameLogicO&seed=123' + (process.env.EXTRA || ''))
await b.waitFor('!!(window.kk && kk.game && kk.game.balls)', 60000)
const dir = gameDir('logico', 'shots')
const ms = +(process.argv[2] || 3000)
for (let i = 0; i < 3; i++) {
  await new Promise((r) => setTimeout(r, ms / 3))
  await b.screenshot(dir + '/l0_' + i + '.png', { x: 8, y: 8, width: 600, height: 600 })
}
console.log(await b.eval(`JSON.stringify({ n: kk.game.balls.length, step: kk.game.step && kk.game.step._hx_name, x: kk.game.balls.map(b => Math.round(b.x)) })`))
console.log(b.consoleLines.filter((l) => /EXCEPTION|CRASH|rror/.test(l)).slice(0, 10).join('\n'))
await b.close()
