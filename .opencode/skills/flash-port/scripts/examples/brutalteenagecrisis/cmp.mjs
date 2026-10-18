// Brutal Teenage Crisis: the port next to the Arkadeo HTML5 version it comes from (its server: `npm start` in the
// Arkadeo repository, ORIG=http://127.0.0.1:3000). The same keys are pressed in both and pictures are taken at the same
// moments: the random differs (two live games), the look of the hero, the mobs, the effects and the HUD can be compared.
// usage: node cmp.mjs <out dir>      env: ORIG, PORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const out = process.argv[2]
const ORIG = process.env.ORIG || 'http://127.0.0.1:3000'
const PORT = +(process.env.PORT || 9590)
const K = { left: [37, 'ArrowLeft'], up: [38, 'ArrowUp'], right: [39, 'ArrowRight'], down: [40, 'ArrowDown'], space: [32, ' '] }
// [time ms, key, down]: run right, jump, run left, phase, drop
const SCRIPT = [[300, 'right', 1], [1200, 'up', 1], [1500, 'up', 0], [2200, 'right', 0], [2300, 'left', 1], [3500, 'left', 0],
  [3600, 'space', 1], [3700, 'space', 0], [4200, 'down', 1], [4300, 'down', 0], [5000, 'right', 1], [7000, 'right', 0]]
const SHOTS = [1400, 3800, 4600, 6500, 9000, 12000]

async function run(name, url, ready, start, canvasExpr) {
  const b = await launch(PORT + (name === 'port' ? 0 : 50))
  try {
    await b.goto(url)
    await b.waitFor(ready, 60000)
    if (start) await b.eval(start)
    const r = JSON.parse(await b.eval(`JSON.stringify(${canvasExpr}.getBoundingClientRect())`))
    const clip = { x: r.x, y: r.y, width: r.width, height: r.width * 460 / 600 }
    const send = (type, [code, k]) => b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: k })
    const events = [...SCRIPT.map(([t, k, d]) => ({ t, k, d })), ...SHOTS.map((t, i) => ({ t, shot: i }))].sort((a, c) => a.t - c.t)
    const t0 = Date.now()
    for (const e of events) {
      const wait = e.t - (Date.now() - t0)
      if (wait > 0) await b.sleep(wait)
      if (e.shot !== undefined) await b.screenshot(`${out}/${name}_${e.shot}.png`, clip)
      else await send(e.d ? 'keyDown' : 'keyUp', K[e.k])
    }
  } finally {
    await b.close()
  }
}

await Promise.all([
  run('port', HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500',
    '!!(window.kk && kk.game && kk.game.mode && kk.game.mode.hero)', null, "document.getElementById('c')"),
  run('orig', ORIG + '/new-btc', '!!(window.BTCBoot && BTCBoot.me && BTCBoot.me.game && !document.getElementById("btc-play").hidden)', 'document.getElementById("btc-play-btn").click()',
    "document.getElementById('btc-canvas')"),
])
console.log('shots in', out)
