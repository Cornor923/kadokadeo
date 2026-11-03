// The rules of the CSS of the site (AGENTS.md « Front-end styles »), checked in the CI next to ESLint:
//   node scripts/lint-css.mjs
// - no <style> in the components: Tailwind utilities, the looks shared by components in app.css
// - no !important (class!, !class, !important): the layers of Tailwind give the order
// - no hex colour in the classes, nor the default palette of Tailwind: the palette is the @theme of app.css, whose tokens
//   exist (a kado-* or twinoid-* colour that is not in it gives no class)
// - in app.css: no colour outside @theme, and no rule on a tag outside @layer base (which styles the document only)
import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'

const ROOT = join(import.meta.dirname, '..')
const JS = join(ROOT, 'resources/js')
// generated or not part of the site: the games (Haxe), the replay verifier (Node)
const SKIP = [join(JS, 'games'), join(JS, 'replay-verifier')]
const CSS = join(ROOT, 'resources/css/app.css')

// the colours and the shadows of the @theme of app.css
const THEME_TOKENS = new Set([...readFileSync(CSS, 'utf8').matchAll(/--(?:color|shadow)-((?:kado|twinoid|etwin)-[a-z0-9-]+)\s*:/g)].map((m) => m[1]))
const TOKEN_USE = /(?:^|[\s"'`:])(?:text|bg|border(?:-[trblxyse])?|fill|stroke|from|via|to|outline|ring|decoration|shadow|divide|accent|caret|placeholder)-((?:kado|twinoid|etwin)-[a-z0-9-]+?)(?:\/\d+)?(?=$|[\s"'`\]])/g

const errors = []
const report = (file, line, message) => errors.push(`${relative(ROOT, file)}:${line}  ${message}`)

function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name)
    if (SKIP.includes(path)) return []
    if (entry.isDirectory()) return files(path)
    return /\.(vue|js)$/.test(entry.name) ? [path] : []
  })
}

const lineOf = (text, index) => text.slice(0, index).split('\n').length

// the class lists: class="...", :class / :enter-active-class... bindings, and the strings of the scripts that look like
// lists of utilities (they are given to :class)
const DEFAULT_PALETTE = /(?:^|[\s"'`:])(?:text|bg|border|fill|stroke|from|via|to|outline|ring|decoration|shadow|divide|accent|caret|placeholder)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/
const HEX_CLASS = /-\[[^\]\s]*#[0-9a-fA-F]{3,8}\b/
const IMPORTANT = /(?:^|[\s"'`])(?:![a-z][\w:/.[\]()%-]*|[a-z][\w:/.[\]()%-]*-[\w/.[\]()%]+!)(?=$|[\s"'`])/

for (const file of files(JS)) {
  const text = readFileSync(file, 'utf8')
  for (const match of file.endsWith('.vue') ? text.matchAll(/<style\b/g) : []) {
    report(file, lineOf(text, match.index), '<style> in a component: use the utilities of Tailwind (a shared look: app.css)')
  }
  // the attributes and the strings that hold classes
  // (a bound attribute, :class="...", is code: only its strings count)
  const strings = [...text.matchAll(/(?<![:\w-])(?:class|-class)="([^"]*)"|'([^'\n]*)'|`([^`]*)`/g)]
  for (const match of strings) {
    const value = match[1] ?? match[2] ?? match[3]
    if (!value) continue
    const line = lineOf(text, match.index)
    if (IMPORTANT.test(value)) report(file, line, `!important in the classes (${value.match(IMPORTANT)[0].trim()}): the layers give the order`)
    if (HEX_CLASS.test(value)) report(file, line, `hex colour in the classes (${value.match(HEX_CLASS)[0]}): a token of the palette`)
    if (DEFAULT_PALETTE.test(value)) report(file, line, `default colour of Tailwind (${value.match(DEFAULT_PALETTE)[0].trim()}): a token of the palette (kado-*)`)
    for (const use of value.matchAll(TOKEN_USE)) {
      if (!THEME_TOKENS.has(use[1])) report(file, line, `${use[1]} is not in the @theme of app.css: no class is made`)
    }
  }
}

// app.css: walk its blocks, knowing in which at-rules each rule is
const css = readFileSync(CSS, 'utf8').replace(/\/\*[\s\S]*?\*\//g, (comment) => comment.replace(/[^\n]/g, ' '))
const TAG = /(?:^|[\s,>+~(])(?:html|body|a|p|h[1-6]|img|table|thead|tbody|tfoot|tr|th|td|ul|ol|li|div|span|nav|section|article|aside|form|input|select|textarea|button|label|canvas|hr)(?=$|[\s,.:#[>+~)])/
const stack = []
let start = 0
for (let i = 0; i < css.length; i++) {
  const char = css[i]
  if (char === '{') {
    const prelude = css.slice(start, i).trim()
    stack.push(prelude)
    const inBase = stack.some((p) => p === '@layer base')
    const inTheme = stack.some((p) => p.startsWith('@theme') || p.startsWith('@keyframes'))
    if (!prelude.startsWith('@') && !inBase && !inTheme) {
      // a selector of a rule: each of its parts goes through a class (a component) or nests in one (&)
      for (const selector of prelude.split(/,(?![^(]*\))/)) {
        if (!selector.includes('.') && !selector.trim().startsWith('&') && TAG.test(selector)) {
          report(CSS, lineOf(css, i), `rule on a tag (${selector.trim()}) outside @layer base: a component, or a class`)
        }
      }
    }
    start = i + 1
  } else if (char === '}') {
    stack.pop()
    start = i + 1
  } else if (char === ';') {
    const declaration = css.slice(start, i)
    const inTheme = stack.some((p) => p.startsWith('@theme'))
    const inFontFace = stack.at(-1) === '@font-face'
    if (!inTheme && !inFontFace && /#[0-9a-fA-F]{3,8}\b|rgba?\(|hsla?\(/.test(declaration)) {
      report(CSS, lineOf(css, i), `colour outside @theme (${declaration.trim()}): a token of the palette`)
    }
    if (/!important/.test(declaration)) report(CSS, lineOf(css, i), `!important (${declaration.trim()})`)
    start = i + 1
  }
}

if (errors.length) {
  console.error(errors.join('\n'))
  console.error(`\n${errors.length} problem(s): the rules of the styles are in AGENTS.md (« Front-end styles »)`)
  process.exit(1)
}
console.log('CSS rules: OK')
