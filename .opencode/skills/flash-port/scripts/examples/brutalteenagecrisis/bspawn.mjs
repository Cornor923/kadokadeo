// Brutal Teenage Crisis: the interpolated display (arkadeo: Flash.snapFirstMove / teleport) must never show something
// that appeared sliding from where it was made: a mob or an item is made at (0, 0) and placed by its first update. Every
// picture, each visible display object is checked: its node drawn more than SLIDE px away from where the game has it (in
// its parent) = a slide (the lag of the display is under 2 frames of move: a few px for a mob, ~70 px for the fastest
// sparks).
// usage: node bspawn.mjs [seconds]      env: PORT, EXTRA
import { launch } from '../../harness/cdp.mjs'
import { HOST } from '../../harness/paths.mjs'
const secs = +(process.argv[2] || 20)
const SLIDE = 100
const b = await launch(+(process.env.PORT || 9620))
try {
  await b.goto(HOST + '/game.html?game=brutalteenagecrisis&cls=GameBrutalTeenageCrisis&seed=123&h=500&test=btc&dif=300&inv=1' + (process.env.EXTRA || ''))
  await b.waitFor('!!(window.kk && kk.game && kk.game.mode && kk.game.mode.hero)', 60000)
  await b.eval(`(() => {
    window.__slide = { pictures: 0, slides: 0, maxGap: 0, examples: [] }
    const r = kk.renderer.render.bind(kk.renderer)
    kk.renderer.render = function (...a) {
      const rec = window.__slide
      if (!a[1] || !a[1].renderTexture) {
        rec.pictures++
        const walk = (n) => {
          if (!n.visible) return
          const d = n.__do
          if (d) {
            const gap = Math.hypot(n.position.x - d.vx, n.position.y - d.vy)
            if (gap > rec.maxGap) rec.maxGap = gap
            if (gap > ${SLIDE}) {
              rec.slides++
              if (rec.examples.length < 5) rec.examples.push({ drawn: [Math.round(n.position.x), Math.round(n.position.y)], game: [Math.round(d.vx), Math.round(d.vy)] })
            }
          }
          for (const c of n.children || []) walk(c)
        }
        walk(kk.gameRoot)
      }
      return r(...a)
    }
  })()`)
  await b.sleep(secs * 1000)
  const res = JSON.parse(await b.eval('JSON.stringify(Object.assign(window.__slide, { frame: kk.game.botState().frame, mobs: kk.game.botState().mobs.length }))'))
  res.maxGap = Math.round(res.maxGap)
  console.log(JSON.stringify(res), res.slides === 0 ? 'OK' : 'SLIDES')
} finally {
  await b.close()
}
