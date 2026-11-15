import { beforeEach, expect, test, vi } from 'vitest'

import { chooseLocale, inPageLanguage, intlLocale, languageChangedByLogin, pageLocale, siteLanguages } from './locale'

beforeEach(() => {
  delete window.Kado
})

function aChoice(locale, { save = vi.fn().mockResolvedValue() } = {}) {
  const reload = vi.fn()
  return { save, reload, choose: () => chooseLocale(locale, { save, reload }) }
}

test('a page without a language is French', () => {
  expect(pageLocale()).toBe('fr')
  expect(intlLocale()).toBe('fr-FR')
})

test('the page gives its language', () => {
  window.Kado = { locale: 'en' }

  expect(pageLocale()).toBe('en')
  expect(intlLocale()).toBe('en')
})

test('a player saves the language on the account, then the page reloads', async() => {
  const { save, reload, choose } = aChoice('en')

  await choose()

  expect(save).toHaveBeenCalledWith('en')
  expect(reload).toHaveBeenCalledOnce()
})

test('a choice the server refused keeps the page as it is', async() => {
  const { reload, choose } = aChoice('en', { save: vi.fn().mockRejectedValue(new Error('down')) })

  await expect(choose()).rejects.toThrow('down')

  expect(reload).not.toHaveBeenCalled()
})

test('the login changes the language when the account chose another one', () => {
  window.Kado = { locale: 'fr', i18n_enabled: true }

  expect(languageChangedByLogin({ locale: 'en' })).toBe(true)
})

test('the login keeps the language when the account chose the same one', () => {
  window.Kado = { locale: 'en', i18n_enabled: true }

  expect(languageChangedByLogin({ locale: 'en' })).toBe(false)
})

test('an automatic account keeps the language of the browser', () => {
  window.Kado = { locale: 'en', i18n_enabled: true }

  expect(languageChangedByLogin({ locale: 'auto' })).toBe(false)
})

test('with the languages off, the login changes nothing', () => {
  window.Kado = { locale: 'fr', i18n_enabled: false }

  expect(languageChangedByLogin({ locale: 'en' })).toBe(false)
})

test('a text written in each language shows the one of the page', () => {
  window.Kado = { locale: 'en' }

  expect(inPageLanguage({ fr: 'Bonjour', en: 'Hello' })).toBe('Hello')
})

test('a text not written in the language of the page shows the French one', () => {
  window.Kado = { locale: 'en' }

  expect(inPageLanguage({ fr: 'Bonjour' })).toBe('Bonjour')
})

test('the page gives the languages of the site', () => {
  window.Kado = { locales: ['fr', 'en'] }

  expect(siteLanguages()).toEqual(['fr', 'en'])
})

test('a page without languages has French only', () => {
  expect(siteLanguages()).toEqual(['fr'])
})
