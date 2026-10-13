// Quadrikolor smoke test: aims at a ball, clicks (direction), clicks (power), screenshots during the shot.
// usage: node q0.mjs [shots prefix]     env: PORT, HPORT, EXTRA (url params)
import { launch } from '../../harness/cdp.mjs'
import { HOST, gameDir } from '../../harness/paths.mjs'
const pre = process.argv[2] || 's'
const b = await launch(+(process.env.PORT || 9961))
const shot = (n) => b.screenshot(gameDir('quadrikolor', 'shots') + `/${pre}${n}.png`, { x: 8, y: 8, width: 600, height: 640 })
// game pixel -> page pixel (canvas at (8, 8), drawn x2)
const P = (v) => 8 + v * 2
try {
  await b.goto(HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor&seed=123' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && window.__state)', 60000)
  await b.sleep(500)
  const st = await b.eval('JSON.stringify(window.__state)')
  console.log(st)
  // aim at the first coloured ball
  const balls = JSON.parse(st).balls.split(' ').map(s => s.split('@')[1].split(',').map(Number))
  const [sx, sy] = balls[0], [tx, ty] = balls[1]
  for (let i = 1; i <= 10; i++) { await b.move(P(sx + (tx - sx) * i / 10), P(sy + (ty - sy) * i / 10)); await b.sleep(30) }
  await b.sleep(1200)
  await shot('00aim')
  await b.click(P(tx), P(ty))
  for (let i = 0; i < 5; i++) { await b.sleep(150); await shot('1' + i + 'power') }
  await b.click(P(tx), P(ty))
  for (let i = 0; i < 16; i++) { await b.sleep(250); await shot(String(20 + i)); }
  console.log(await b.eval('JSON.stringify(window.__state)'))
} finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|rror|CRASH/i.test(l)); if (errs.length) console.log(errs.slice(0, 5).join('\n').slice(0, 3000))
  await b.close()
}
