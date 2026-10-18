// Generic replay seeking check for any game of the repository:
//   live: random keys + mouse for N frames (game over forced at frame N, see game.html test=generic)
//   replay: seek 60% / back to 20% / 60% again, normal playback to 75% vs seek to the same frame, end score
// The state is compared with the score and a hash of the whole display tree of the game.
import { launch } from './cdp.mjs'
const [pkg, cls] = [process.argv[2], process.argv[3]]
const PORT = +(process.argv[4] || 9333)
const FRAMES = +(process.argv[5] || 900)
let rs = +(process.argv[6] || 7)
const rnd = (n) => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return (rs >> 16) % n }
const URL0 = `http://127.0.0.1:${process.env.HPORT || 8765}/game.html?game=${pkg}&cls=${cls}&test=generic&frames=${FRAMES}${process.env.EXTRA || ''}`
const KEYS = [[37, 'ArrowLeft'], [38, 'ArrowUp'], [39, 'ArrowRight'], [40, 'ArrowDown'], [32, 'Space'], [13, 'Enter'], [17, 'ControlLeft'],
  [87, 'KeyW'], [65, 'KeyA'], [83, 'KeyS'], [68, 'KeyD'], [16, 'ShiftLeft']]
const result = { game: pkg }
let b = await launch(PORT)
// (headless Chrome on macOS hides the page on a Control key event: no more frames until it is brought to the front)
const key = async (type, code, k) => {
  await b.send('Input.dispatchKeyEvent', { type, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key: k, code: k })
  if (code === 17) await b.send('Page.bringToFront')
}
const mouse = (type, x, y, buttons = 0) => b.send('Input.dispatchMouseEvent', { type, x: 8 + x, y: 8 + y, button: type === 'mouseMoved' ? 'none' : 'left', buttons, clickCount: 1 })
let data, live
try {
  await b.goto(URL0)
  await b.waitFor('!!(window.kk && kk.game)', 60000)
  await b.eval('kk.setReplaySpeed(3)')
  const t0 = Date.now()
  while (!(await b.eval('!!window.__logs.find(l => l.includes("Replay data:"))'))) {
    if (Date.now() - t0 > 240000) throw new Error('no game over')
    const r = rnd(10)
    if (r < 5) { const [c, k] = KEYS[rnd(KEYS.length)]; await key('keyDown', c, k); await b.sleep(30 + rnd(150)); await key('keyUp', c, k) }
    else if (r < 8) { const x = rnd(600), y = 40 + rnd(540); await mouse('mouseMoved', x, y); await mouse('mousePressed', x, y, 1); await b.sleep(20 + rnd(60)); await mouse('mouseReleased', x, y) }
    else { await mouse('mouseMoved', rnd(600), rnd(600)); await b.sleep(20) }
  }
  live = await b.eval(`document.getElementById('score').textContent`)
  data = (await b.eval(`window.__logs.find(l => l.includes("Replay data:"))`)).split('Replay data: ')[1].trim()
  result.live = live
  result.replayChars = data.length
} catch (e) { result.error = 'live: ' + e.message.slice(0, 200) }
finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|CRASH/i.test(l))
  if (errs.length) result.liveErrors = errs.slice(0, 2).map(e => e.slice(0, 300))
  await b.close()
}
const FP = `(() => {
  const acc = []
  const walk = (o) => { for (const c of o.children || []) {
    const s = c._curState
    if (s) acc.push([s.x, s.y, s.rotation, s.xscale, s.yscale, s.alpha].map(v => Math.round(v * 100)).join(',') + ',' + (c._currentframe | 0) + (c.visible ? 'v' : 'h'))
    else acc.push([c.x, c.y].map(v => Math.round(v * 100)).join(',') + (c.visible ? 'v' : 'h') + (c.text != null ? c.text : ''))
    walk(c) } }
  if (kk.gameRoot) walk(kk.gameRoot)
  let h = 2166136261; const str = acc.join('|')
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0 }
  return JSON.stringify({ f: kk.replay.getCurrentFrame(), score: document.getElementById('score').textContent, n: acc.length, h })
})()`
const seekTo = async (f) => {
  await b.eval(`kk.seekReplay(${f})`)
  const t0 = Date.now()
  await b.waitFor('kk.seekTarget == null', 180000)
  return Date.now() - t0
}
if (data) {
  b = await launch(PORT)
  try {
    await b.goto(URL0 + '&seed=123&replay=' + encodeURIComponent(data))
    await b.waitFor('!!(window.kk && kk.game && kk.replayHud)', 60000)
    await b.eval('kk.setReplayPaused(true)')
    const len = await b.eval('kk.getReplayLength()')
    result.length = len
    const f60 = Math.round(len * 0.6), f20 = Math.round(len * 0.2)
    let ms = await seekTo(f60)
    const A = await b.eval(FP)
    result.seek60ms = ms
    ms = await seekTo(f20)
    result.back20ms = ms
    ms = await seekTo(f60)
    const C = await b.eval(FP)
    result.again60 = A === C ? 'SAME' : 'DIFF ' + A + ' / ' + C
    // normal playback to about 75% then the same frame by seeking
    await b.eval('kk.setReplaySpeed(2)'); await b.eval('kk.setReplayPaused(false)')
    await b.waitFor(`kk.replay.getCurrentFrame() >= ${Math.round(len * 0.75)} || !kk.replay.isPlayingReplay()`, 120000)
    await b.eval('kk.setReplayPaused(true)')
    const P = await b.eval(FP)
    const fp = JSON.parse(P).f
    await seekTo(f20)
    await seekTo(fp)
    const S = await b.eval(FP)
    result.playedVsSeek = P === S ? 'SAME' : 'DIFF ' + P + ' / ' + S
    // end of the replay: same score as the live game
    await b.eval('kk.setReplaySpeed(8)'); await b.eval('kk.setReplayPaused(false)')
    await b.waitFor('kk.gameOverScreen != null || kk.game == null', 180000)
    result.end = await b.eval(`document.getElementById('score').textContent`)
    result.endMatch = result.end === live ? 'MATCH' : 'MISMATCH'
  } catch (e) { result.error = (result.error || '') + ' replay: ' + e.message.slice(0, 200) }
  finally {
    const errs = b.consoleLines.filter(l => /EXCEPTION|CRASH/i.test(l))
    if (errs.length) result.replayErrors = errs.slice(0, 2).map(e => e.slice(0, 300))
    await b.close()
  }
}
console.log(JSON.stringify(result))
