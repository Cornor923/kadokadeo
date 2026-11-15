// The translation catalogs of resources/lang/ against each other and against the code, checked in the CI:
//   node scripts/lint-i18n.mjs
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { baseCompile } from '@intlify/message-compiler'

const ROOT = join(import.meta.dirname, '..')
const LANG = join(ROOT, 'resources/lang')
const JS = join(ROOT, 'resources/js')
const APP = join(ROOT, 'app')
const SOURCE_LANGUAGE = 'fr'
// generated or not part of the site: the games (Haxe), the replay verifier (Node)
const NOT_THE_SITE = [join(JS, 'games'), join(JS, 'replay-verifier')]

// { login: { title: 'x' } } -> [['login.title', 'x']]
const flatten = (messages, prefix = '') =>
  Object.entries(messages).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key
    return value !== null && typeof value === 'object' ? flatten(value, path) : [[path, value]]
  })

// {name} is a variable, {'@'} an escaped character
const variablesOf = (message) =>
  [...new Set([...message.matchAll(/\{\s*([A-Za-z_]\w*)\s*\}/g)].map((match) => match[1]))].sort().join(', ')

function syntaxErrorsOf(message) {
  const errors = []
  baseCompile(message, { onError: (error) => errors.push(error.message) })
  return errors
}

function siteMessageProblems(language, key, message) {
  if (typeof message !== 'string') {
    return [`${language}: ${key} is not a text`]
  }
  return [
    ...(message.includes('<') ? [`${language}: ${key} holds "<": a tag stays in the component (<i18n-t>)`] : []),
    ...syntaxErrorsOf(message).map((error) => `${language}: ${key}: ${error}`),
  ]
}

// a game shows its texts on a canvas, without vue-i18n: | < and @ are plain characters
const gameMessageProblems = (language, key, message) =>
  typeof message === 'string' ? [] : [`${language}: ${key} is not a text`]

function problemsAgainstFrench(french, translations, messageProblems) {
  const frenchEntries = flatten(french)
  const frenchMessages = new Map(frenchEntries)
  const problems = frenchEntries.flatMap(([key, message]) => messageProblems(SOURCE_LANGUAGE, key, message))

  for (const [language, messages] of Object.entries(translations)) {
    for (const [key, message] of flatten(messages)) {
      problems.push(...messageProblems(language, key, message))
      const source = frenchMessages.get(key)
      const isComparable = typeof source === 'string' && typeof message === 'string' && message !== ''
      if (isComparable && variablesOf(source) !== variablesOf(message)) {
        problems.push(`${language}: ${key} has the variables [${variablesOf(message)}], the French text [${variablesOf(source)}]`)
      }
    }
  }
  return problems
}

export const findCatalogProblems = (french, translations) => problemsAgainstFrench(french, translations, siteMessageProblems)

function pluralsWithoutOther(language, messages) {
  const keys = new Set(flatten(messages).map(([key]) => key))
  return [...keys]
    .filter((key) => key.endsWith('.one') && !keys.has(key.replace(/\.one$/, '.other')))
    .map((key) => `${language}: ${key} has no .other`)
}

export const findGameCatalogProblems = (french, translations) => [
  ...problemsAgainstFrench(french, translations, gameMessageProblems),
  ...Object.entries({ [SOURCE_LANGUAGE]: french, ...translations }).flatMap(([language, messages]) =>
    pluralsWithoutOther(language, messages),
  ),
]

// a server text is shown as it is, by the site or a game: only its :name is read (not the 30 of 12:30)
const serverVariablesOf = (message) =>
  [...new Set([...message.matchAll(/(?<![\w:]):([A-Za-z_]\w*)/g)].map((match) => match[1]))].sort().join(', ')

export function findServerCatalogProblems(french, translations) {
  const frenchMessages = new Map(flatten(french))
  const problems = [...frenchMessages].flatMap(([key, message]) => gameMessageProblems(SOURCE_LANGUAGE, key, message))
  for (const [language, messages] of Object.entries(translations)) {
    for (const [key, message] of flatten(messages)) {
      problems.push(...gameMessageProblems(language, key, message))
      const source = frenchMessages.get(key)
      const isComparable = typeof source === 'string' && typeof message === 'string' && message !== ''
      if (isComparable && serverVariablesOf(source) !== serverVariablesOf(message)) {
        problems.push(`${language}: ${key} has the variables [${serverVariablesOf(message)}], the French text [${serverVariablesOf(source)}]`)
      }
    }
  }
  return problems
}

const SERVER_KEY = /^(['"])server\.([^'"$]+)\1$/
const OTHER_LITERAL_KEY = /^(['"])[^'"$]+\1$/

export function findServerUsageProblems(code, frenchKeys, file) {
  const readable = withoutComments(code)
  return [...readable.matchAll(/\b__\(\s*([^\s,)]*)/g)].flatMap(([, argument]) => {
    const serverKey = argument.match(SERVER_KEY)?.[2]
    if (serverKey !== undefined) {
      return frenchKeys.has(serverKey) ? [] : [`${file}: the key server.${serverKey} is not in resources/lang/fr/server.json`]
    }
    return OTHER_LITERAL_KEY.test(argument) ? [] : [`${file}: the key ${argument || '(none)'} is not a literal`]
  })
}

export function findMissingTranslations(french, translations) {
  const frenchKeys = flatten(french).map(([key]) => key)
  return Object.entries(translations).flatMap(([language, messages]) => {
    const translatedKeys = new Set(flatten(messages).filter(([, message]) => message !== '').map(([key]) => key))
    return frenchKeys.filter((key) => !translatedKeys.has(key)).map((key) => `${language}: ${key} has no translation`)
  })
}

const withoutComments = (code) =>
  code
    .replaceAll(/<!--[\s\S]*?-->/g, '')
    .replaceAll(/\/\*[\s\S]*?\*\//g, '')
    .replaceAll(/(^|\s)\/\/.*$/gm, '')

// `language.${name}`: a group written out, then what the code chooses in it
const BUILT_KEY = /^`((?:[^`$.]+\.)+)\$\{[^`]*\}`$/

export function findUsageProblems(code, frenchKeys, file) {
  const readable = withoutComments(code)
  const quotedArguments = [
    ...[...readable.matchAll(/(?<!function\s)\bt\(\s*([^\s,)]*)/g)].map((match) => match[1]),
    ...[...readable.matchAll(/(?<![:\w-])keypath="([^"]*)"/g)].map((match) => `'${match[1]}'`),
    ...[...readable.matchAll(/:keypath="([^"]*)"/g)].map((match) => match[1]),
  ]
  return quotedArguments.flatMap((argument) => {
    const group = argument.match(BUILT_KEY)?.[1]
    if (group !== undefined) {
      return [...frenchKeys].some((key) => key.startsWith(group))
        ? []
        : [`${file}: the group ${group.slice(0, -1)} is not in resources/lang/${SOURCE_LANGUAGE}/site.json`]
    }
    const key = argument.match(/^(['"])([^'"]+)\1$/)?.[2]
    if (key === undefined) {
      return [`${file}: the key ${argument || '(none)'} is not a literal, nor built in a group (\`group.\${name}\`)`]
    }
    return frenchKeys.has(key) ? [] : [`${file}: the key ${key} is not in resources/lang/${SOURCE_LANGUAGE}/site.json`]
  })
}

export function parseCatalog(text, file) {
  try {
    return { messages: JSON.parse(text), problems: [] }
  } catch (error) {
    return { messages: {}, problems: [`${file}: ${error.message}`] }
  }
}

function catalogOf(language, name) {
  const path = join(LANG, language, `${name}.json`)
  return parseCatalog(readFileSync(path, 'utf8'), relative(ROOT, path))
}

export const siteCatalogOf = (language) => catalogOf(language, 'site')

function translationsOf(name) {
  return readdirSync(LANG)
    .filter((language) => language !== SOURCE_LANGUAGE && existsSync(join(LANG, language, `${name}.json`)))
    .map((language) => [language, catalogOf(language, name)])
}

function gameCatalogNames() {
  const games = readdirSync(join(LANG, SOURCE_LANGUAGE, 'games'))
  return ['kado', ...games.map((file) => `games/${file.replace(/\.json$/, '')}`)]
}

function problemsOfCatalog(name, findProblems) {
  const french = catalogOf(SOURCE_LANGUAGE, name)
  const translations = translationsOf(name)
  return [
    ...french.problems,
    ...translations.flatMap(([, catalog]) => catalog.problems),
    ...findProblems(french.messages, Object.fromEntries(translations.map(([language, catalog]) => [language, catalog.messages]))),
  ]
}

function siteFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (NOT_THE_SITE.includes(path)) return []
    if (entry.isDirectory()) return siteFiles(path)
    const isTest = /\.(spec|test)\.m?js$/.test(entry.name)
    return !isTest && /\.(vue|js)$/.test(entry.name) ? [path] : []
  })
}

function phpFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return phpFiles(path)
    return entry.name.endsWith('.php') ? [path] : []
  })
}

function findAllProblems() {
  const frenchKeys = new Set(flatten(siteCatalogOf(SOURCE_LANGUAGE).messages).map(([key]) => key))
  const frenchServerKeys = new Set(flatten(catalogOf(SOURCE_LANGUAGE, 'server').messages).map(([key]) => key))
  return [
    ...problemsOfCatalog('server', findServerCatalogProblems),
    ...phpFiles(APP).flatMap((file) => findServerUsageProblems(readFileSync(file, 'utf8'), frenchServerKeys, relative(ROOT, file))),
    ...problemsOfCatalog('site', findCatalogProblems),
    ...gameCatalogNames().flatMap((name) => problemsOfCatalog(name, findGameCatalogProblems)),
    ...siteFiles(JS).flatMap((file) => findUsageProblems(readFileSync(file, 'utf8'), frenchKeys, relative(ROOT, file))),
  ]
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const problems = findAllProblems()
  if (problems.length) {
    console.error(problems.join('\n'))
    console.error(`\n${problems.length} problem(s) in the translations`)
    process.exit(1)
  }
  console.log('Translation catalogs: OK')
}
