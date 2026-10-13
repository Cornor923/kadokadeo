// The same pointer script on the original in Ruffle (ref_swf.py + ruffle_site.sh) or on the port (harness page):
// screenshots side by side material. usage: node lshot.mjs <ruffle|port> <out prefix> [moves]
//   moves: "x,y,ms;..." (stage pixels, then wait ms), "p" / "r" press / release, "s" screenshot, "w,ms" wait
//   env: RPORT (Ruffle site, default 8796), HPORT (harness), PORT (DevTools), GPU=1 (Ruffle is slow without), EXTRA
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const which = process.argv[2]
const out = process.argv[3]
const moves = (process.argv[4] || 's').split(';')
const b = await launch(+(process.env.PORT || 9864))
let n = 0, x = 150, y = 150, down = false
const ev = (type) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x * 2, y: 8 + y * 2, button: type === 'mouseMoved' && !down ? 'none' : 'left', buttons: down ? 1 : 0, clickCount: 1, pointerType: 'mouse' })
try {
  if (which === 'port') {
    await b.goto(HOST + '/game.html?game=logico&cls=GameLogicO&seed=123' + (process.env.EXTRA || ''))
    await b.waitFor('!!(window.kk && kk.game && kk.game.balls)', 60000)
  } else {
    await b.goto('http://127.0.0.1:' + (process.env.RPORT || 8796) + '/ref.html?swf=' + (process.env.SWF || 'ref.swf'))
    await b.waitFor('!!(window.__loaded || window.__err)', 60000)
    await b.sleep(1000)
  }
  for (const m of moves) {
    if (m === 's') { await b.screenshot(out + '_' + (n++) + '.png', { x: 8, y: 8, width: 600, height: 600 }); continue }
    if (m === 'p') { down = true; await ev('mousePressed'); continue }
    if (m === 'r') { down = false; await ev('mouseReleased'); continue }
    if (m.startsWith('w,')) { await b.sleep(+m.slice(2)); continue }
    const [mx, my, ms] = m.split(',').map(Number)
    const sx = x, sy = y
    for (let i = 1; i <= 4; i++) { x = sx + (mx - sx) * i / 4; y = sy + (my - sy) * i / 4; await ev('mouseMoved'); await b.sleep(15) }
    await b.sleep(ms || 0)
  }
} finally {
  await b.close()
}
