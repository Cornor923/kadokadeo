import { fireEvent, render, screen } from '@testing-library/vue'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, expect, test, vi } from 'vitest'

import { createAppI18n } from '@/i18n'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'

import LanguageFlags from './LanguageFlags.vue'

const save = vi.fn()
const reload = vi.fn()

const error = { value: null }

vi.mock('@/composables/useAccount', () => ({
  useAccount: () => ({ error, saveLocale: save }),
}))
vi.mock('@/i18n/reload', () => ({ reloadPage: () => reload() }))

const TEXTS = { language: { title: 'Langue', fr: 'Français', en: 'English (beta)' } }

function renderFlags({ enabled = true, loggedIn = true, pageLocale = 'fr', locales = ['fr', 'en'] } = {}) {
  window.evts = new EventTarget()
  window.Kado = { i18n_enabled: enabled, locale: pageLocale, locales }
  const pinia = createPinia()
  setActivePinia(pinia)
  if (loggedIn) {
    useAuthStore().user = { id: 1, locale: 'auto' }
  }
  return render(LanguageFlags, { global: { plugins: [pinia, createAppI18n('fr', { fr: TEXTS })] } })
}

beforeEach(() => {
  save.mockReset().mockResolvedValue()
  reload.mockReset()
  error.value = null
})

test('with the languages off, there is no flag', () => {
  renderFlags({ enabled: false })

  expect(screen.queryAllByRole('button')).toEqual([])
})

test('a visitor has no flag: the browser chooses the language', () => {
  renderFlags({ loggedIn: false })

  expect(screen.queryAllByRole('button')).toEqual([])
})

test('a player sees one flag by language, the one of the page pressed', () => {
  renderFlags()

  expect(screen.getAllByRole('img').map((flag) => flag.alt)).toEqual(['Français', 'English (beta)'])
  expect(screen.getByRole('button', { pressed: true }).title).toBe('Français')
})

test('there is one flag by language of the site', () => {
  renderFlags({ locales: ['fr'] })

  expect(screen.getAllByRole('img').map((flag) => flag.alt)).toEqual(['Français'])
})

test('the flag of a language is named after it', () => {
  renderFlags()

  expect(screen.getAllByRole('img').map((flag) => flag.getAttribute('src'))).toEqual(['/gfx/flags/fr.gif', '/gfx/flags/en.gif'])
})

test('a player who clicks a flag saves its language and reloads the page in it', async() => {
  renderFlags()

  await fireEvent.click(screen.getByTitle('English (beta)'))
  await vi.waitFor(() => expect(reload).toHaveBeenCalledOnce())

  expect(save).toHaveBeenCalledWith('en')
})

test('the flag of the page changes nothing', async() => {
  renderFlags()

  await fireEvent.click(screen.getByTitle('Français'))

  expect(save).not.toHaveBeenCalled()
})

test('a choice the server refused keeps the page and tells the player why', async() => {
  save.mockImplementation(async() => {
    error.value = 'La requête a échoué.'
    throw new Error('down')
  })
  renderFlags()

  await fireEvent.click(screen.getByTitle('English (beta)'))
  await vi.waitFor(() => expect(useToastStore().toasts).toHaveLength(1))

  expect(useToastStore().toasts[0]).toMatchObject({ title: 'Langue', text: 'La requête a échoué.' })
  expect(reload).not.toHaveBeenCalled()
})
