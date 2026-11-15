// node --test scripts/lint-i18n.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import {
  findCatalogProblems,
  findGameCatalogProblems,
  findMissingTranslations,
  findServerCatalogProblems,
  findServerUsageProblems,
  findUsageProblems,
  parseCatalog,
  siteCatalogOf,
} from './lint-i18n.mjs'

const catalogsAreRejected = (french, english) =>
  assert.notDeepEqual(findCatalogProblems(french, { en: english }), [], 'these catalogs should be rejected')
const catalogsAreAccepted = (french, english) =>
  assert.deepEqual(findCatalogProblems(french, { en: english }), [])

const codeIsRejected = (code, frenchKeys = []) =>
  assert.notDeepEqual(findUsageProblems(code, new Set(frenchKeys), 'page.vue'), [], `this code should be rejected: ${code}`)
const codeIsAccepted = (code, frenchKeys = []) =>
  assert.deepEqual(findUsageProblems(code, new Set(frenchKeys), 'page.vue'), [])

// a new text of the site comes with its English
test('English translates every key of the site', () => {
  const french = siteCatalogOf('fr').messages
  const english = siteCatalogOf('en').messages

  assert.deepEqual(findMissingTranslations(french, { en: english }), [])
})

const gameCatalogsAreRejected = (french, english) =>
  assert.notDeepEqual(findGameCatalogProblems(french, { en: english }), [], 'these catalogs should be rejected')
const gameCatalogsAreAccepted = (french, english) =>
  assert.deepEqual(findGameCatalogProblems(french, { en: english }), [])

test('a game translation with other variables is rejected', () => {
  gameCatalogsAreRejected({ unicombo: 'UniCombo +{_c}' }, { unicombo: 'Same colour' })
})

test('a game text can hold the characters of vue-i18n', () => {
  gameCatalogsAreAccepted({ sms: 'a|b', mail: 'kado@site.fr', tag: '<3' }, { sms: 'c|d', mail: 'kado@site.com', tag: '<3' })
})

test('a game plural needs its .other, in French as in a translation', () => {
  gameCatalogsAreRejected({ 'players.one': 'Un joueur' }, {})
  gameCatalogsAreRejected({ 'players.one': 'Un joueur', 'players.other': '{count} joueurs' }, { 'players.one': 'One player' })
})

test('a game plural can have its .other alone', () => {
  gameCatalogsAreAccepted({ 'stars.other': '{count} etoiles' }, {})
  gameCatalogsAreAccepted(
    { 'players.one': 'Un joueur', 'players.other': '{count} joueurs' },
    { 'players.other': '{count} players' },
  )
})

test('a game text that is not a text is rejected', () => {
  gameCatalogsAreRejected({ combo: 3 }, {})
})

test('a game translation can be missing', () => {
  gameCatalogsAreAccepted({ combo: 'Combo +1' }, {})
})

const serverCatalogsAreRejected = (french, english) =>
  assert.notDeepEqual(findServerCatalogProblems(french, { en: english }), [], 'these catalogs should be rejected')
const serverCatalogsAreAccepted = (french, english) =>
  assert.deepEqual(findServerCatalogProblems(french, { en: english }), [])

test('a server translation with other variables is rejected', () => {
  serverCatalogsAreRejected({ clan: { full: 'Le clan :name est plein' } }, { clan: { full: 'The clan is full' } })
})

test('a server translation can hold the characters of vue-i18n', () => {
  serverCatalogsAreAccepted({ mail: 'kado@site.fr | {x} <b>' }, { mail: 'kado@site.com | {x} <b>' })
})

test('a time in a server text is not a variable', () => {
  serverCatalogsAreAccepted({ start: 'À 12:30' }, { start: 'At 12:30' })
})

test('a server text that is not a text is rejected', () => {
  serverCatalogsAreRejected({ count: 3 }, {})
})

test('a server translation can be missing', () => {
  serverCatalogsAreAccepted({ full: 'Plein' }, {})
})

const serverCodeIsRejected = (code, frenchKeys = []) =>
  assert.notDeepEqual(findServerUsageProblems(code, new Set(frenchKeys), 'A.php'), [], `this code should be rejected: ${code}`)
const serverCodeIsAccepted = (code, frenchKeys = []) =>
  assert.deepEqual(findServerUsageProblems(code, new Set(frenchKeys), 'A.php'), [])

test('a server key missing in French is rejected', () => {
  serverCodeIsRejected("__('server.clan.full')")
})

test('a server key known in French is accepted', () => {
  serverCodeIsAccepted("__('server.clan.full', ['name' => $name])", ['clan.full'])
  serverCodeIsAccepted('__("server.clan.full")', ['clan.full'])
})

test('a server key that is not a literal is rejected', () => {
  serverCodeIsRejected('__($key)')
  serverCodeIsRejected('__("server.clan.{$key}")')
})

test('the keys of the framework are not the catalog of the server', () => {
  serverCodeIsAccepted("__('validation.required')")
})

test('a server key in a comment is ignored', () => {
  serverCodeIsAccepted("// __('server.clan.full')")
})

test('a supported language must translate every key', () => {
  assert.deepEqual(findMissingTranslations({ hello: 'Bonjour', bye: 'Salut' }, { en: { hello: 'Hello' } }), [
    'en: bye has no translation',
  ])
})

test('an empty text is not a translation', () => {
  assert.deepEqual(findMissingTranslations({ hello: 'Bonjour' }, { en: { hello: '' } }), [
    'en: hello has no translation',
  ])
})

test('nested keys must be translated too', () => {
  assert.deepEqual(findMissingTranslations({ login: { hello: 'Bonjour' } }, { en: { login: {} } }), [
    'en: login.hello has no translation',
  ])
})

test('every supported language is checked', () => {
  assert.deepEqual(findMissingTranslations({ hello: 'Bonjour' }, { en: {}, es: {} }), [
    'en: hello has no translation',
    'es: hello has no translation',
  ])
})

test('a complete language is accepted', () => {
  assert.deepEqual(findMissingTranslations({ login: { hello: 'Bonjour' } }, { en: { login: { hello: 'Hello' } } }), [])
})

test('a translation that drops a variable is rejected', () => {
  catalogsAreRejected({ hello: 'Bonjour {name}' }, { hello: 'Hello' })
})

test('a translation that invents a variable is rejected', () => {
  catalogsAreRejected({ hello: 'Bonjour' }, { hello: 'Hello {name}' })
})

test('the same variables in another order are accepted', () => {
  catalogsAreAccepted({ duel: '{winner} bat {loser}' }, { duel: '{loser} lost to {winner}' })
})

test('a variable in one branch of a plural is accepted', () => {
  catalogsAreAccepted({ players: 'Un joueur | {n} joueurs' }, { players: 'One player | {n} players' })
})

test('a variable that only the French plural uses is rejected', () => {
  catalogsAreRejected({ players: 'Un joueur | {n} joueurs' }, { players: 'One player | Many players' })
})

test('an escaped brace is not a variable', () => {
  catalogsAreAccepted({ mail: "kado{'@'}site.fr" }, { mail: "kado{'@'}site.com" })
})

test('a missing or empty translation is accepted', () => {
  catalogsAreAccepted({ hello: 'Bonjour {name}', bye: 'Salut {name}' }, { bye: '' })
})

test('nested keys are compared', () => {
  catalogsAreRejected({ login: { hello: 'Bonjour {name}' } }, { login: { hello: 'Hello' } })
})

test('markup in a catalog is rejected, in French as in a translation', () => {
  catalogsAreRejected({ hello: '<b>Bonjour</b>' }, {})
  catalogsAreRejected({ hello: 'Bonjour' }, { hello: '<b>Hello</b>' })
})

test('a message with a broken syntax is rejected', () => {
  catalogsAreRejected({ mail: 'kado@site.fr' }, {})
  catalogsAreRejected({ hello: 'Bonjour {name' }, {})
})

test('a value that is not a text is rejected', () => {
  catalogsAreRejected({ count: 3 }, {})
  catalogsAreRejected({ hello: 'Bonjour' }, { hello: 3 })
  catalogsAreRejected({ hello: null }, {})
})

test('a key used by the code and missing in French is rejected', () => {
  codeIsRejected("t('login.title')")
  codeIsRejected("$t('login.title')")
  codeIsRejected('<i18n-t keypath="login.title" />')
})

test('a key known in French is accepted', () => {
  codeIsAccepted("t('login.title')", ['login.title'])
  codeIsAccepted('t("login.title", { name })', ['login.title'])
  codeIsAccepted('<i18n-t keypath="login.title" />', ['login.title'])
  codeIsAccepted(`<i18n-t :keypath="'login.title'" />`, ['login.title'])
})

test('a key that is not a literal is rejected', () => {
  codeIsRejected('t(key)')
  codeIsRejected('<i18n-t :keypath="key" />')
})

// the group is checked, its keys cannot be: what the variable gives is the business of the code
test('a key built in a group known in French is accepted', () => {
  codeIsAccepted('t(`language.${language}`)', ['language.fr'])
  codeIsAccepted('$t(`login.errors.${code}`)', ['login.errors.denied'])
})

test('a key built in a group missing in French is rejected', () => {
  codeIsRejected('t(`languages.${language}`)', ['language.fr'])
  codeIsRejected('t(`lang${uage}`)', ['language.fr'])
  codeIsRejected('t(`${group}.title`)', ['login.title'])
})

test('the function t itself is not a use of a key', () => {
  codeIsAccepted('export function t(...args) {}')
})

test('the words that only end with a t are not translations', () => {
  codeIsAccepted('list.at(0); wait(delay); format(value)')
})

test('a key in a comment is ignored', () => {
  codeIsAccepted("// t('login.title')")
  codeIsAccepted("/* t('login.title') */")
  codeIsAccepted("<!-- t('login.title') -->")
})

test('a link is not taken for a comment', () => {
  codeIsRejected("const url = 'https://kado.fr'; t('login.title')")
})

test('an unreadable catalog names its file', () => {
  const { problems } = parseCatalog('{ not json', 'resources/lang/en/site.json')

  assert.equal(problems.length, 1)
  assert.match(problems[0], /lang\/en\/site\.json/)
})

test('a readable catalog gives its messages', () => {
  assert.deepEqual(parseCatalog('{"hello":"Bonjour"}', 'resources/lang/fr/site.json'), {
    messages: { hello: 'Bonjour' },
    problems: [],
  })
})
