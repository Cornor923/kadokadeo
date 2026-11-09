// La Brute (KadoKadeo): makes the pictures of the skin (public/assets/img/content/labrute/skin) light to load, once
// for all, then writes skin.json (build_skin.mjs):
//   - an SVG picture: drawn into a WebP (lossless) at twice its biggest size in the game (SCALES), its origin (the point
//     (0, 0) of its drawing, the viewBox may start before it) and its scale kept in origins.json;
//   - a pet (pet-*.png): made smaller, twice its biggest size in the game (PET_BOXES), WebP;
//   - a flag (flag-<lang>: svg, png, jpg): a WebP of twice its box in the game (FLAG), filled;
//   - a GIF: a WebP (lossless, its frames kept);
//   - a font (ttf, otf): WOFF2.
// The originals go to skin/src (not loaded by the game): put a new version of a picture in skin/, run it again.
// Needs sharp and wawoff2 (not dependencies of KadoKadeo), for example in the front container:
//   mkdir -p /tmp/lbtools && cd /tmp/lbtools && npm i sharp@0.33.5 wawoff2@2.0.1
//   NODE_TOOLS=/tmp/lbtools node optimize_skin.mjs [kadokadeo root]
import { readdirSync, readFileSync, writeFileSync, mkdirSync, renameSync, existsSync } from 'node:fs'
import { createRequire } from 'node:module'
import { join, extname, basename, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'

const root = process.argv[2] ?? '.'
const require = createRequire(join(process.env.NODE_TOOLS ?? '/tmp/lbtools', 'node_modules'))
const sharp = require('sharp')
const wawoff2 = require('wawoff2')

const dir = join(root, 'public/assets/img/content/labrute/skin')
const src = join(dir, 'src')
mkdirSync(src, { recursive: true })

// how much bigger than its drawing an SVG picture is drawn: twice its biggest size in the game (the weapons: up to
// x 1.46 on the board, BOARD_SCALE × WEAPON_PLACES of ShopScreen.hx; the board: x 0.85)
const SCALES = { 'panel-weapons': 2 }
const WEAPON_SCALE = 3
// the boxes a pet is fitted in: its tooltip, ChoiceScreen, its place in the shop (ShopScreen.PET_SLOTS minus their
// outline)
const PET_BOXES = [
  [70, 46],
  [34, 30],
]
const PET_SLOT = { 'pet-dog1': [52, 52], 'pet-dog2': [52, 52], 'pet-dog3': [52, 52], 'pet-panther': [168, 62], 'pet-bear': [96, 126] }

// the flags of the languages (flag-<lang>): twice their box in the game (16 × 12)
const FLAG = [32, 24]

const originsFile = join(dir, 'origins.json')
const origins = existsSync(originsFile) ? JSON.parse(readFileSync(originsFile, 'utf8')) : {}
const move = (file) => renameSync(join(dir, file), join(src, file))
const kb = (n) => `${Math.round(n / 1024)} KB`

for (const file of readdirSync(dir).sort()) {
  const ext = extname(file).toLowerCase()
  const name = basename(file, extname(file))
  const path = join(dir, file)
  if (name.startsWith('flag-') && ['.svg', '.png', '.jpg', '.jpeg'].includes(ext)) {
    // (a flag: twice its box in the game, Game.LANG_W × LANG_H, filled, its middle kept)
    const input = ext === '.svg' ? sharp(readFileSync(path), { density: 300 }) : sharp(path)
    const data = await input.resize(FLAG[0], FLAG[1], { fit: 'cover' }).webp({ lossless: true }).toBuffer()
    writeFileSync(join(dir, `${name}.webp`), data)
    delete origins[name]
    move(file)
    console.log(file, '->', `${name}.webp`, `${FLAG[0]}x${FLAG[1]}`, kb(data.length))
  } else if (ext === '.svg') {
    const text = readFileSync(path, 'utf8')
    const head = text.slice(0, text.indexOf('>'))
    const box = /viewBox="\s*([-0-9.eE]+)[\s,]+([-0-9.eE]+)/.exec(head)
    const width = parseFloat(/\swidth="([0-9.eE]+)/.exec(head)?.[1] ?? '0')
    const k = SCALES[name] ?? (name.startsWith('weapon-') ? WEAPON_SCALE : 2)
    const out = await sharp(Buffer.from(text), { density: 72 * k }).webp({ lossless: true }).toBuffer({ resolveWithObject: true })
    writeFileSync(join(dir, `${name}.webp`), out.data)
    // (its scale: its pixels by unit of its drawing, as sharp rounded its size)
    origins[name] = { x: box ? -parseFloat(box[1]) : 0, y: box ? -parseFloat(box[2]) : 0, k: width > 0 ? out.info.width / width : k }
    move(file)
    console.log(file, kb(text.length), '->', `${name}.webp`, `${out.info.width}x${out.info.height}`, kb(out.data.length))
  } else if (name.startsWith('pet-') && ['.png', '.jpg', '.jpeg'].includes(ext)) {
    const meta = await sharp(path).metadata()
    const boxes = [...PET_BOXES, PET_SLOT[name] ?? [52, 52]]
    const fit = Math.max(...boxes.map(([w, h]) => Math.min(w / meta.width, h / meta.height))) * 2
    const w = Math.round(meta.width * Math.min(1, fit))
    const out = await sharp(path).resize({ width: w }).webp({ lossless: true }).toBuffer({ resolveWithObject: true })
    writeFileSync(join(dir, `${name}.webp`), out.data)
    move(file)
    console.log(file, `${meta.width}x${meta.height}`, kb(readFileSync(join(src, file)).length), '->', `${name}.webp`,
      `${out.info.width}x${out.info.height}`, kb(out.data.length))
  } else if (ext === '.gif') {
    // (a GIF: a WebP, lossless, its frames kept)
    const data = await sharp(path, { animated: true }).webp({ lossless: true }).toBuffer()
    writeFileSync(join(dir, `${name}.webp`), data)
    move(file)
    console.log(file, kb(readFileSync(join(src, file)).length), '->', `${name}.webp`, kb(data.length))
  } else if (['.ttf', '.otf'].includes(ext)) {
    const data = await wawoff2.compress(readFileSync(path))
    writeFileSync(join(dir, `${name}.woff2`), data)
    move(file)
    console.log(file, kb(readFileSync(join(src, file)).length), '->', `${name}.woff2`, kb(data.length))
  }
}
writeFileSync(originsFile, `${JSON.stringify(origins, null, '\t')}\n`)
execFileSync(process.execPath, [join(dirname(fileURLToPath(import.meta.url)), 'build_skin.mjs'), root], { stdio: 'inherit' })
