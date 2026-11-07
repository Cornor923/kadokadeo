// Trigo: seeking in the replay of a bot game (t3.mjs saves them in $KKP_WORK/trigo/replays), like harness/s3.mjs: seek to
// 60 % / back to 20 % / 60 % again, normal playback to 75 % vs seek to the same frame, the end state; the state is the
// gameplay state of the game (window.__trigo) and a hash of the display tree.
// usage: node tseek.mjs <replay file> [extra url params]     env: PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { readFileSync } from 'node:fs'
const [data, liveOver] = readFileSync(process.argv[2], 'utf8').split('\n')
const URL0 = HOST + '/game.html?game=trigo&cls=GameTrigo&h=500&seed=123' + (process.argv[3] || '')
const FP = `(() => {
  const acc = []
  const walk = (o) => { for (const c of o.children || []) {
    const s = c._curState
    if (s) acc.push([s.x, s.y, s.rotation, s.xscale, s.yscale, s.alpha].map(v => Math.round(v * 100)).join(',') + ',' + (c._currentframe | 0) + (c.visible ? 'v' : 'h'))
    else acc.push([c.x, c.y].map(v => Math.round(v * 100)).join(',') + (c.visible ? 'v' : 'h'))
    walk(c) } }
  if (kk.gameRoot) walk(kk.gameRoot)
  let h = 2166136261; const str = acc.join('|') + JSON.stringify(window.__trigo)
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0 }
  return JSON.stringify({ f: kk.replay.getCurrentFrame(), score: window.__trigo.score, step: window.__trigo.step, n: acc.length, h })
})()`
const result = {}
const b = await launch(+(process.env.PORT || 9761))
const seekTo = async (f) => {
  await b.eval(`kk.seekReplay(${f})`)
  const t0 = Date.now()
  await b.waitFor('kk.seekTarget == null', 180000)
  return Date.now() - t0
}
try {
  await b.goto(URL0 + '&replay=' + encodeURIComponent(data))
  await b.waitFor('!!(window.kk && kk.game && kk.replayHud && window.__trigo)', 60000)
  await b.eval('kk.setReplayPaused(true)')
  const len = await b.eval('kk.getReplayLength()')
  result.length = len
  const f60 = Math.round(len * 0.6), f20 = Math.round(len * 0.2)
  result.seek60ms = await seekTo(f60)
  const A = await b.eval(FP)
  result.at60 = JSON.parse(A).score + ' ' + JSON.parse(A).step
  result.back20ms = await seekTo(f20)
  await seekTo(f60)
  const C = await b.eval(FP)
  result.again60 = A === C ? 'SAME' : 'DIFF ' + A + ' / ' + C
  await b.eval('kk.setReplaySpeed(2)'); await b.eval('kk.setReplayPaused(false)')
  await b.waitFor(`kk.replay.getCurrentFrame() >= ${Math.round(len * 0.75)} || !kk.replay.isPlayingReplay()`, 300000)
  await b.eval('kk.setReplayPaused(true)')
  const P = await b.eval(FP)
  await seekTo(f20)
  await seekTo(JSON.parse(P).f)
  const S = await b.eval(FP)
  result.playedVsSeek = P === S ? 'SAME' : 'DIFF ' + P + ' / ' + S
  await b.eval('kk.setReplaySpeed(8)'); await b.eval('kk.setReplayPaused(false)')
  await b.waitFor('!!window.__over', 600000)
  const end = await b.eval('JSON.stringify(window.__over)')
  result.endMatch = end === liveOver ? 'MATCH' : 'MISMATCH ' + end.slice(0, 200)
} catch (e) { result.error = e.message.slice(0, 300) }
finally {
  const errs = b.consoleLines.filter(l => /EXCEPTION|CRASH/i.test(l))
  if (errs.length) result.errors = errs.slice(0, 2).map(e => e.slice(0, 300))
  await b.close()
}
console.log(JSON.stringify(result))
