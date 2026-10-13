// Seeking in a bot replay of q3.mjs (harness/s3.mjs on a real game): seek 60% / back to 20% / 60% again, normal
// playback to 75% vs seek to the same frame (score + hash of the display tree), end of the replay.
// usage: node qs1.mjs <replay file>      env: PORT (default 9976), HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const [data, liveOver] = readFileSync(process.argv[2], 'utf8').split('\n')
const PORT = +(process.env.PORT || 9976)
const URL0 = HOST + '/game.html?game=quadrikolor&cls=GameQuadriKolor'
const result = { file: process.argv[2].split('/').pop(), live: JSON.parse(liveOver).score }
let b
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
    result.endMatch = result.end === String(result.live) ? 'MATCH' : 'MISMATCH'
  } catch (e) { result.error = (result.error || '') + ' replay: ' + e.message.slice(0, 200) }
  finally {
    const errs = b.consoleLines.filter(l => /EXCEPTION|CRASH/i.test(l))
    if (errs.length) result.replayErrors = errs.slice(0, 2).map(e => e.slice(0, 300))
    await b.close()
  }
}
console.log(JSON.stringify(result))
