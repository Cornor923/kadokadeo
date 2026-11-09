// LaBrute (KadoKadeo): the sprite sheets, the start screen picture and the thumbnail of the game, from a checkout of
// labrute-react (https://gitlab.com/eternaltwin/labrute/labrute-react, client/public/images and client/src/assets).
// The fighters themselves are drawn at run time by labrute-pixi-fighter (npm), nothing of them is here.
//
//   labrute-0: client/public/images/game/misc.json (arena backgrounds, weapons, impacts, blood, explosions...)
//   labrute-1: the icons of the skills, made by build_skills.mjs (from their SVG, sharper than game/skills.png)
//   labrute-2: client/public/images/game/thrown-weapons.json, its frames renamed thrown/<weapon>.png
//   labrute-3: the pets (client/public/images/pets/*.svg), packed here
//
// Needs pngjs, jpeg-js and @resvg/resvg-wasm (not dependencies of KadoKadeo), for example in the front container:
//   mkdir -p /tmp/lbtools && cd /tmp/lbtools && npm i pngjs@7.0.0 jpeg-js@0.4.4 @resvg/resvg-wasm@2.6.2
//   NODE_TOOLS=/tmp/lbtools node build_assets.mjs <labrute-react checkout> <kadokadeo root>
import { mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { join } from 'node:path'

const [src, root] = process.argv.slice(2)
if (!src || !root) {
  console.error('usage: node build_assets.mjs <labrute-react> <kadokadeo>')
  process.exit(1)
}
const require = createRequire(join(process.env.NODE_TOOLS ?? '/tmp/lbtools', 'node_modules'))
const { PNG } = require('pngjs')
const jpeg = require('jpeg-js')
const { initWasm, Resvg } = require('@resvg/resvg-wasm')
await initWasm(readFileSync(require.resolve('@resvg/resvg-wasm/index_bg.wasm')))

const images = join(src, 'client/public/images')
const out = join(root, 'public/assets/img/content/labrute')
mkdirSync(out, { recursive: true })

const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'))
const writeJson = (file, data) => writeFileSync(file, `${JSON.stringify(data, null, '\t')}\n`)

// ---------------------------------------------------------------- the sheets of labrute-react
const misc = readJson(join(images, 'game/misc.json'))
misc.meta.image = 'labrute-0.png'
misc.meta.related_multi_packs = ['labrute-1.json', 'labrute-2.json', 'labrute-3.json']
delete misc.meta.smartupdate
writeJson(join(out, 'labrute-0.json'), misc)
copyFileSync(join(images, 'game/misc.png'), join(out, 'labrute-0.png'))

// (thrown/<weapon>.png: the names of misc.json are the same)
const thrown = readJson(join(images, 'game/thrown-weapons.json'))
thrown.frames = Object.fromEntries(Object.entries(thrown.frames).map(([name, frame]) => [`thrown/${name}`, frame]))
if (thrown.animations) {
  thrown.animations = Object.fromEntries(
    Object.entries(thrown.animations).map(([name, frames]) => [name, frames.map((f) => `thrown/${f}`)]),
  )
}
thrown.meta.image = 'labrute-2.png'
delete thrown.meta.smartupdate
writeJson(join(out, 'labrute-2.json'), thrown)
copyFileSync(join(images, 'game/thrown-weapons.png'), join(out, 'labrute-2.png'))

// ---------------------------------------------------------------- labrute-3: the pets
const svgToPng = (svg, width) => {
  const r = new Resvg(svg, { fitTo: { mode: 'width', value: width } })
  return PNG.sync.read(Buffer.from(r.render().asPng()))
}
const icons = []
for (const pet of ['dog1', 'dog2', 'dog3', 'panther', 'bear']) {
  icons.push({ name: `pet/${pet}.png`, png: svgToPng(readFileSync(join(images, `pets/${pet}.svg`), 'utf8'), 68) })
}

const pad = 2
let x = pad
let height = 0
for (const icon of icons) {
  icon.x = x
  icon.y = pad
  x += icon.png.width + pad
  height = Math.max(height, icon.png.height + pad * 2)
}
const sheet = new PNG({ width: x, height })
for (const icon of icons) PNG.bitblt(icon.png, sheet, 0, 0, icon.png.width, icon.png.height, icon.x, icon.y)
writeFileSync(join(out, 'labrute-3.png'), PNG.sync.write(sheet))
writeJson(join(out, 'labrute-3.json'), {
  frames: Object.fromEntries(
    icons.map((icon) => [
      icon.name,
      {
        frame: { x: icon.x, y: icon.y, w: icon.png.width, h: icon.png.height },
        rotated: false,
        trimmed: false,
        spriteSourceSize: { x: 0, y: 0, w: icon.png.width, h: icon.png.height },
        sourceSize: { w: icon.png.width, h: icon.png.height },
      },
    ]),
  ),
  meta: { app: 'build_assets.mjs', version: '1.0', image: 'labrute-3.png', format: 'RGBA8888', size: { w: x, h: height }, scale: '1' },
})

// ---------------------------------------------------------------- the start screen (600 x 460 JPEG) and the thumbnail
const miscPng = PNG.sync.read(readFileSync(join(images, 'game/misc.png')))
const bgFrame = misc.frames['background/1.jpg'].frame
const bg = new PNG({ width: bgFrame.w, height: bgFrame.h })
PNG.bitblt(miscPng, bg, bgFrame.x, bgFrame.y, bgFrame.w, bgFrame.h, 0, 0)
const dataUri = (buffer, type) => `data:${type};base64,${buffer.toString('base64')}`
const bgUri = dataUri(PNG.sync.write(bg), 'image/png')
const bearUri = dataUri(Buffer.from(readFileSync(join(images, 'pets/bear.svg'))), 'image/svg+xml')
const dogUri = dataUri(Buffer.from(readFileSync(join(images, 'pets/dog1.svg'))), 'image/svg+xml')
const font = readFileSync(join(src, 'client/src/assets/fonts/labrute.ttf'))

const poster = (w, h) => `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}" viewBox="0 0 600 460">
  <defs>
    <linearGradient id="shade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1b0f06" stop-opacity="0.85"/>
      <stop offset="0.45" stop-color="#1b0f06" stop-opacity="0.15"/>
      <stop offset="1" stop-color="#1b0f06" stop-opacity="0.75"/>
    </linearGradient>
  </defs>
  <image x="-60" y="0" width="720" height="460" preserveAspectRatio="none" xlink:href="${bgUri}"/>
  <rect width="600" height="460" fill="url(#shade)"/>
  <image x="30" y="250" width="170" height="170" xlink:href="${bearUri}"/>
  <image x="420" y="300" width="130" height="130" xlink:href="${dogUri}"/>
  <text x="300" y="150" text-anchor="middle" font-family="LaBrute" font-size="96" fill="#fbf2af" stroke="#4a2a10" stroke-width="8" paint-order="stroke">LA BRUTE</text>
  <text x="300" y="205" text-anchor="middle" font-family="LaBrute" font-size="30" fill="#ffffff" stroke="#4a2a10" stroke-width="5" paint-order="stroke">L'ARÈNE SANS FIN</text>
</svg>`

const render = (w, h) => {
  const r = new Resvg(poster(w, h), { fitTo: { mode: 'width', value: w }, font: { fontBuffers: [font], defaultFontFamily: 'LaBrute', loadSystemFonts: false } })
  return PNG.sync.read(Buffer.from(r.render().asPng()))
}

const art = render(600, 460)
const jpg = jpeg.encode({ data: art.data, width: art.width, height: art.height }, 90)
writeFileSync(join(root, 'public/assets/img/gfx/artwork/labrute.jpg'), jpg.data)

// the thumbnail of the list of games (300 x 200): the middle of the poster
const thumbSvg = poster(600, 460).replace('viewBox="0 0 600 460"', 'viewBox="0 30 600 400"')
const thumb = new Resvg(thumbSvg.replace(/width="600" height="460"/, 'width="300" height="200"'), {
  fitTo: { mode: 'width', value: 300 },
  font: { fontBuffers: [font], defaultFontFamily: 'LaBrute', loadSystemFonts: false },
})
writeFileSync(join(root, 'public/assets/img/games/La_Brute.png'), Buffer.from(thumb.render().asPng()))

console.log('labrute assets written to', out)
