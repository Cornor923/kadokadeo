// La Brute (KadoKadeo): the list of the pictures of the skin, public/assets/img/content/labrute/skin/skin.json. The game
// loads the pictures it lists (labrute.view.Skin); each one replaces a drawing of the game, by its name (without its
// extension): see the README of the folder. Nothing to install: run it after adding, renaming or removing a picture.
// The same file under several names (the fonts) is listed once, its names pointing to it (loaded once); the origins
// of the SVG pictures made WebP by optimize_skin.mjs (origins.json) are added.
//   node build_skin.mjs [kadokadeo root]
import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { join, extname, basename } from 'node:path'

const root = process.argv[2] ?? '.'
const dir = join(root, 'public/assets/img/content/labrute/skin')
mkdirSync(dir, { recursive: true })
const files = {}
const byHash = {}
for (const file of readdirSync(dir).sort()) {
  const ext = extname(file).toLowerCase()
  if (!['.png', '.webp', '.jpg', '.jpeg', '.gif', '.svg', '.woff2', '.woff', '.ttf', '.otf'].includes(ext)) continue
  if (!statSync(join(dir, file)).isFile()) continue
  const hash = createHash('sha1').update(readFileSync(join(dir, file))).digest('hex')
  byHash[hash] ??= file
  files[basename(file, extname(file))] = byHash[hash]
}
const originsFile = join(dir, 'origins.json')
const all = existsSync(originsFile) ? JSON.parse(readFileSync(originsFile, 'utf8')) : {}
// (the origins of the pictures still there, not SVG: an SVG one has its viewBox)
const origins = Object.fromEntries(Object.entries(all).filter(([name]) => files[name] && !files[name].endsWith('.svg')))
writeFileSync(join(dir, 'skin.json'), `${JSON.stringify({ files, origins }, null, '\t')}\n`)
console.log(`skin.json: ${Object.keys(files).length} pictures`, Object.keys(files).join(', '))
