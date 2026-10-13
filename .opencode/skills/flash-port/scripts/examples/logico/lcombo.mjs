// A combo in the original (Ruffle) or in the port: the colours of the 16 balls of the start are read on a screenshot
// (Ruffle: the original's random cannot be seeded), the ball that makes the longest line once moved is pressed, then
// screenshots every SHOT ms. usage: node lcombo.mjs <ruffle|port> <out prefix> [shots]
//   env: RPORT (Ruffle site, default 8796), HPORT, PORT, GPU=1 (Ruffle), SHOT (ms between shots, default 0), EXTRA
//   (url params of the port)
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
import { inflateSync } from 'node:zlib'
const which = process.argv[2], out = process.argv[3], nshots = +(process.argv[4] || 12)
const b = await launch(+(process.env.PORT || 9864))
let x = 150, y = 150, down = false
const ev = (type) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x * 2, y: 8 + y * 2, button: type === 'mouseMoved' && !down ? 'none' : 'left', buttons: down ? 1 : 0, clickCount: 1, pointerType: 'mouse' })
// minimal PNG reader (8-bit RGBA / RGB, no interlace) of the screenshot
function png(file) {
  const d = readFileSync(file)
  let p = 8, w, h, ct, idat = []
  while (p < d.length) {
    const len = d.readUInt32BE(p), type = d.toString('ascii', p + 4, p + 8)
    if (type === 'IHDR') { w = d.readUInt32BE(p + 8); h = d.readUInt32BE(p + 12); ct = d[p + 17] }
    if (type === 'IDAT') idat.push(d.subarray(p + 8, p + 8 + len))
    p += 12 + len
  }
  const raw = inflateSync(Buffer.concat(idat)), bpp = ct === 6 ? 4 : 3, stride = w * bpp
  const px = Buffer.alloc(w * h * bpp)
  for (let r = 0; r < h; r++) {
    const f = raw[r * (stride + 1)], src = raw.subarray(r * (stride + 1) + 1, (r + 1) * (stride + 1))
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? px[r * stride + i - bpp] : 0, up = r ? px[(r - 1) * stride + i] : 0, ul = r && i >= bpp ? px[(r - 1) * stride + i - bpp] : 0
      let v = src[i]
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1
      else if (f === 4) { const pp = a + up - ul, pa = Math.abs(pp - a), pb = Math.abs(pp - up), pc = Math.abs(pp - ul); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : ul }
      px[r * stride + i] = v & 255
    }
  }
  return (X, Y) => { const o = (Y * w + X) * bpp; return [px[o], px[o + 1], px[o + 2]] }
}
// the colour of a ball: the mean of its rim (radius 13 to 15 Flash px), red / orange / green
function colour(get, cx, cy) {
  let r = 0, g = 0, n = 0
  for (let a = 0; a < 32; a++) for (const rad of [13.5, 14.5]) {
    const [R, G] = get(Math.round(2 * (cx + Math.cos(a / 32 * 6.28) * rad)), Math.round(2 * (cy + Math.sin(a / 32 * 6.28) * rad)))
    r += R; g += G; n++
  }
  r /= n; g /= n
  return g > r ? 2 : g > r * 0.45 ? 1 : 0
}
function runs(cols) {
  const n = cols.length
  let start = 0
  while (start < n && cols[start] === cols[(start + n - 1) % n]) start++
  let best = 0, len = 0
  for (let k = 0; k < n; k++) { const i = (start + k) % n; if (k > 0 && cols[i] === cols[(i + n - 1) % n]) len++; else len = 1; best = Math.max(best, len) }
  return best
}
function moved(cols, id) {
  const max = cols.length
  let id2 = (id + Math.ceil(max * 0.5)) % max
  const a = cols.slice(), [c] = a.splice(id, 1)
  if (id2 > id) id2--
  a.splice(id2, 0, c)
  return a
}
try {
  if (which === 'port') {
    await b.goto(HOST + '/game.html?game=logico&cls=GameLogicO&seed=' + (process.env.SEED || 123) + (process.env.EXTRA || ''))
    await b.waitFor('!!(window.kk && kk.game && kk.game.balls)', 60000)
  } else {
    await b.goto('http://127.0.0.1:' + (process.env.RPORT || 8796) + '/ref.html?swf=ref.swf')
    await b.waitFor('!!(window.__loaded || window.__err)', 60000)
  }
  await b.sleep(3000)
  await b.screenshot(out + '_start.png', { x: 8, y: 8, width: 600, height: 600 })
  const get = png(out + '_start.png')
  // Game.updateBalls: 16 balls on a circle of 16 * 2 * 16 / 6.28 around the centre, ball i at angle 6.28 * i / 16
  const ray = 16 * 2 * 16 / 6.28, pos = [], cols = []
  for (let i = 0; i < 16; i++) { const a = 6.28 * i / 16; pos.push([150 + Math.cos(a) * ray, 150 + Math.sin(a) * ray]); cols.push(colour(get, ...pos[i])) }
  let best = 0, bi = 0
  for (let i = 0; i < 16; i++) { const r = runs(moved(cols, i)); if (r > best) { best = r; bi = i } }
  console.log('colours', cols.join(''), 'press', bi, 'line', best)
  const sx = x, sy = y
  for (let i = 1; i <= 4; i++) { x = sx + (pos[bi][0] - sx) * i / 4; y = sy + (pos[bi][1] - sy) * i / 4; await ev('mouseMoved'); await b.sleep(15) }
  await b.sleep(200)
  down = true; await ev('mousePressed'); await b.sleep(30); down = false; await ev('mouseReleased')
  // away from the ring
  x = 150; y = 150; await ev('mouseMoved')
  for (let i = 0; i < nshots; i++) {
    await b.screenshot(out + '_' + i + '.png', { x: 8, y: 8, width: 600, height: 600 })
    if (process.env.SHOT) await b.sleep(+process.env.SHOT)
  }
} finally {
  await b.close()
}
