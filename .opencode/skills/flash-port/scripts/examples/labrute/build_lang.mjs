// La Brute (KadoKadeo): the texts of the data of the game in another language (the names of the weapons, the skills
// and their descriptions and effects, the pets, the stats, the types of weapons, the details, the leagues), from the
// translations of labrute-react (client/src/i18n/locales/<lang>/common.json), written into
// resources/hx/games/labrute/lang/<Lang>Data.hx. The texts of the screens are in lang/<Lang>.hx, by hand.
//   node build_lang.mjs <labrute-react checkout> <kadokadeo root> <lang: en, de, es...>
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

const [src, root, lang] = process.argv.slice(2)
if (!src || !root || !lang) {
  console.error('usage: node build_lang.mjs <labrute-react> <kadokadeo> <lang>')
  process.exit(1)
}
const locales = join(src, 'client/src/i18n/locales')
const fr = JSON.parse(readFileSync(join(locales, 'fr/common.json'), 'utf8'))
const tr = JSON.parse(readFileSync(join(locales, lang, 'common.json'), 'utf8'))
const game = join(root, 'resources/hx/games/labrute')
const data = readFileSync(join(game, 'Data.hx'), 'utf8')

const names = (kind) => [...data.matchAll(new RegExp(`new ${kind}\\((?:\\d+, )?"(\\w+)"`, 'g'))].map((m) => m[1])
const weapons = names('WeaponData')
const skills = names('SkillData')
const pets = names('PetData')
// (the stats in the order of S, as LaBrute names them in its tooltips)
const STATS = ['reversal', 'counter', 'evasion', 'dexterity', 'block', 'accuracy', 'disarm', 'sabotageStat', 'combo', 'deflect', 'armor',
  'damage', 'criticalChance', 'criticalDamage', 'hitSpeed', 'initiative', 'strength', 'agility', 'speed', 'hp', 'regenerationStat',
  'weaponGrip', 'size']
const leagues = /LEAGUES:Array<String> = \[([^\]]*)\]/.exec(data)[1].match(/"[^"]*"/g).map((s) => JSON.parse(s))

const missing = []
const get = (key) => {
  if (tr[key] === undefined) missing.push(key)
  return tr[key]
}
const kinds = {
  weapon: Object.fromEntries(weapons.map((n) => [n, get(n)])),
  skill: Object.fromEntries(skills.map((n) => [n, get(n)])),
  desc: Object.fromEntries(skills.map((n) => [n, get(`${n}.desc`)])),
  effect: Object.fromEntries(skills.filter((n) => fr[`${n}.effect`]).map((n) => [n, get(`${n}.effect`)])),
  pet: Object.fromEntries(pets.map((n) => [n, get(n)])),
  stat: Object.fromEntries(STATS.map((k, i) => [String(i), get(k)])),
  type: Object.fromEntries(['fast', 'sharp', 'heavy', 'long', 'thrown', 'blunt'].map((n) => [n, get(n)])),
  detail: Object.fromEntries(['atOneHp', 'againstThrows', 'afterBlock'].map((n) => [n, get(n)])),
  // (by the French name: its key lvl_N in labrute-react)
  league: Object.fromEntries(leagues.map((name, i) => {
    const key = Object.keys(fr).find((k) => /^lvl_\d+$/.test(k) && fr[k] === name)
    return [String(i), key ? get(key) : undefined]
  })),
  // the labels of LaBrute's tooltips
  label: Object.fromEntries(['types', 'odds', 'hitSpeed', 'drawChance', 'reach', 'damage', 'bareHands', 'weapons', 'none', 'usageRate',
    'skill.notReloadable', 'opponent-damage'].map((n) => [n, get(n)])),
}

const q = (s) => JSON.stringify(s)
const Lang = lang.charAt(0).toUpperCase() + lang.slice(1)
let out = `package labrute.lang;\n\n// The texts of the data of the game in ${lang} (build_lang.mjs, from the translations of labrute-react): by kind, by key\n`
out += `class ${Lang}Data {\n\tpublic static var DATA:Map<String, Map<String, String>> = [\n`
out += Object.entries(kinds).map(([kind, map]) => {
  const rows = Object.entries(map).filter(([, v]) => v !== undefined).map(([k, v]) => `\t\t\t${q(k)} => ${q(v)}`)
  return `\t\t${q(kind)} => [\n${rows.join(',\n')}\n\t\t]`
}).join(',\n')
out += '\n\t];\n}\n'
mkdirSync(join(game, 'lang'), { recursive: true })
writeFileSync(join(game, `lang/${Lang}Data.hx`), out)
console.log(`lang/${Lang}Data.hx written`, missing.length ? `(missing: ${missing.join(', ')})` : '')
