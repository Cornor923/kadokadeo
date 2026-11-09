// La Brute (KadoKadeo): the sheet of the icons of the skills, public/assets/img/content/labrute/labrute-1.webp / .json
// (frames tier-1/<skill>.png ... tier-3/<skill>.png), from their SVG (the skills of labrute-react,
// client/public/images/skills, in a folder of tier-1/, tier-2/, tier-3/, not kept here): each one drawn at SIZE pixels,
// twice its biggest size in the game (the tooltip of a skill, Describe.SKILL_ICON), in a sheet whose sides are powers
// of two (its mipmaps: smooth in the small icons of the fight).
// Needs sharp (not a dependency of KadoKadeo), for example in the front container:
//   mkdir -p /tmp/lbtools && cd /tmp/lbtools && npm i sharp@0.33.5
//   NODE_TOOLS=/tmp/lbtools node build_skills.mjs <folder of the SVG: tier-1/ tier-2/ tier-3/> [kadokadeo root]
import { readdirSync, readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs'
import { createRequire } from 'node:module'
import { join, basename } from 'node:path'

const [srcDir, root = '.'] = process.argv.slice(2)
if (!srcDir) {
  console.error('usage: node build_skills.mjs <folder of the SVG: tier-1/ tier-2/ tier-3/> [kadokadeo root]')
  process.exit(1)
}
const require = createRequire(join(process.env.NODE_TOOLS ?? '/tmp/lbtools', 'node_modules'))
const sharp = require('sharp')

const SIZE = 102
// (transparent pixels between them: nothing of a neighbour in the small mipmaps)
const PAD = 4
const SVG_SIZE = 34
const out = join(root, 'public/assets/img/content/labrute')

const icons = []
for (const tier of [1, 2, 3])
  for (const file of readdirSync(join(srcDir, `tier-${tier}`)).filter((f) => f.endsWith('.svg')).sort()) {
    const svg = readFileSync(join(srcDir, `tier-${tier}`, file))
    const png = await sharp(svg, { density: (72 * SIZE) / SVG_SIZE }).resize(SIZE, SIZE, { fit: 'fill' }).png().toBuffer()
    icons.push({ name: `tier-${tier}/${basename(file, '.svg')}.png`, png })
  }

const cell = SIZE + PAD
const pow2 = (n) => 2 ** Math.ceil(Math.log2(n))
// (the smallest sheet of sides powers of two)
let width = 0, height = 0
for (let w = pow2(cell); w <= 4096; w *= 2) {
  const h = pow2(Math.ceil(icons.length / Math.floor(w / cell)) * cell)
  if (h <= 4096 && (width === 0 || w * h < width * height)) [width, height] = [w, h]
}
const perRow = Math.floor(width / cell)
const frames = {}
const layers = icons.map((icon, i) => {
  const x = (i % perRow) * cell + PAD / 2
  const y = Math.floor(i / perRow) * cell + PAD / 2
  frames[icon.name] = {
    frame: { x, y, w: SIZE, h: SIZE },
    rotated: false,
    trimmed: false,
    spriteSourceSize: { x: 0, y: 0, w: SIZE, h: SIZE },
    sourceSize: { w: SIZE, h: SIZE },
  }
  return { input: icon.png, left: x, top: y }
})
const sheet = await sharp({ create: { width, height, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
  .composite(layers)
  .webp({ lossless: true })
  .toBuffer()
writeFileSync(join(out, 'labrute-1.webp'), sheet)
const meta = { app: 'build_skills.mjs', version: '1.0', image: 'labrute-1.webp', format: 'RGBA8888', size: { w: width, h: height }, scale: '1' }
writeFileSync(join(out, 'labrute-1.json'), `${JSON.stringify({ frames, meta }, null, '\t')}\n`)
// (the sheet of before, its icons of 34 pixels)
if (existsSync(join(out, 'labrute-1.png'))) rmSync(join(out, 'labrute-1.png'))
console.log(`labrute-1.webp: ${icons.length} icons of ${SIZE} px, ${width}x${height}, ${Math.round(sheet.length / 1024)} KB`)
