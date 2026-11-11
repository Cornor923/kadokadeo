// Charlotte's Quest next to the Arkadeo HTML5 port it is checked against and the original in Ruffle (Twinoid/server:
// PORT=3099 MONGO_URL="mongodb://127.0.0.1:1/?serverSelectionTimeoutMS=500" node server.js, ORIG=http://127.0.0.1:3099).
// The port and the HTML5 play the same seed (the AKApi seed of the HTML5 forced through Math.random, &cqseed for the port)
// without any input: the same rooms, the same background and the same waves, pictures at the same frames of the game. The
// original draws its own seed (Ruffle): a picture at the same time of the game.
// usage: node cqcmp.mjs <out dir> [seed] [frames, e.g. 45,150,300]      env: ORIG, PORT, HPORT
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
import { writeFileSync, mkdirSync } from 'node:fs'
const out = process.argv[2]
const SEED = +(process.argv[3] || 424242)
const FRAMES = (process.argv[4] || '45,120,240,400,600,800').split(',').map(Number)
const ORIG = process.env.ORIG || 'http://127.0.0.1:3099'
const PORT = +(process.env.PORT || 9750)
mkdirSync(out, { recursive: true })

// the port: the game held at the frame (test=cq&hold), a screenshot of the game area
async function port(f) {
  const b = await launch(PORT)
  try {
    await b.goto(HOST + `/game.html?game=charlottesquest&cls=GameCharlottesQuest&seed=123&h=500&test=cq&hold=${f}&cqseed=${SEED}`)
    // (or the end of the game: Charlotte left alone may die first)
    await b.waitFor(`!!(window.kk && kk.game && (kk.game.frameCount >= ${f} || window.__over))`, 120000)
    await b.sleep(400)
    await b.screenshot(`${out}/port_${f}.png`, { x: 8, y: 8, width: 600, height: 460 })
  } finally { await b.close() }
}

// the HTML5 port: its game made at the load with the seed forced, played frame by frame by its devTick, then drawn
async function html5() {
  const b = await launch(PORT + 10)
  try {
    await b.send('Page.addScriptToEvaluateOnNewDocument', { source: `(() => { const r = Math.random; Math.random = function () {
      return (new Error().stack || '').indexOf('AKApi') >= 0 ? (${SEED} + 0.5) / 1000000 : r() } })()` })
    await b.goto(ORIG + '/new-charlotte-quest')
    await b.waitFor('!!(window.CharlotteQuestBoot && CharlotteQuestBoot.me && CharlotteQuestBoot.me.game)', 60000)
    await b.eval('CharlotteQuestBoot.me.stop && CharlotteQuestBoot.me.stop()')
    let done = 0
    for (const f of FRAMES) {
      await b.eval(`CharlotteQuestBoot.me.devTick(${f - done})`)
      done = f
      const url = await b.eval(`(() => { const m = CharlotteQuestBoot.me; m.renderer.render(m.stage); return m.renderer.view.toDataURL('image/png') })()`)
      writeFileSync(`${out}/html5_${f}.png`, Buffer.from(url.split(',')[1], 'base64'))
    }
    console.log('html5 seed', await b.eval('CharlotteQuestBoot.me.game.seed'))
  } finally { await b.close() }
}

// the original in Ruffle: its page's "Jouer" button, then pictures at the same times of the game (30 frames/s)
async function orig() {
  const b = await launch(PORT + 20)
  try {
    await b.goto(ORIG + '/games/charlotteQuest/play')
    await b.waitFor('!!document.getElementById("play-btn")', 30000)
    await b.sleep(1500)
    await b.eval('document.getElementById("play-btn").click()')
    // (Ruffle loads the SWF: the game starts once it is drawn)
    await b.sleep(Number(process.env.RUFFLE_WAIT || 6000))
    const r = JSON.parse(await b.eval(`JSON.stringify(document.querySelector('ruffle-player').getBoundingClientRect())`))
    const t0 = Date.now()
    for (const f of FRAMES) {
      const wait = f / 30 * 1000 - (Date.now() - t0)
      if (wait > 0) await b.sleep(wait)
      await b.screenshot(`${out}/orig_${f}.png`, { x: r.x, y: r.y, width: r.width, height: r.height })
    }
  } finally { await b.close() }
}

if (process.env.ONLY === 'orig') { await orig(); process.exit(0) }
for (const f of FRAMES) await port(f)
await html5()
await orig().catch((e) => console.log('orig', e.message))
console.log('shots in', out)
