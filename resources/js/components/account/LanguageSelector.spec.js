import { fireEvent, render, screen } from '@testing-library/vue'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, expect, test, vi } from 'vitest'

import { createAppI18n } from '@/i18n'
import { useAuthStore } from '@/stores/auth'

import LanguageSelector from './LanguageSelector.vue'

const save = vi.fn()
const reload = vi.fn()

vi.mock('@/composables/useAccount', () => ({
  useAccount: () => ({ error: { value: null }, saveLocale: save }),
}))
vi.mock('@/i18n/reload', () => ({ reloadPage: () => reload() }))

const TEXTS = { language: { title: 'Langue', auto: 'Automatique', fr: 'Français', en: 'English (beta)' } }

function renderSelector({ enabled = true, locale = 'fr', locales = ['fr', 'en'] } = {}) {
  window.evts = new EventTarget()
  window.Kado = { i18n_enabled: enabled, locale: 'fr', locales }
  const pinia = createPinia()
  setActivePinia(pinia)
  useAuthStore().user = { locale }
  return render(LanguageSelector, { global: { plugins: [pinia, createAppI18n('fr', { fr: TEXTS })] } })
}

beforeEach(() => {
  save.mockReset().mockResolvedValue()
  reload.mockReset()
})

test('with the languages off, there is no choice', () => {
  renderSelector({ enabled: false })

  expect(screen.queryByRole('combobox')).toBeNull()
})

test('with the languages on, the player reads the three choices', () => {
  renderSelector()

  expect(screen.getAllByRole('option').map((option) => option.textContent)).toEqual([
    'Automatique',
    'Français',
    'English (beta)',
  ])
})

test('the choices are the languages of the site', () => {
  renderSelector({ locales: ['fr'] })

  expect(screen.getAllByRole('option').map((option) => option.textContent)).toEqual(['Automatique', 'Français'])
})

test('the choice shown is the one of the account', () => {
  renderSelector({ locale: 'en' })

  expect(screen.getByRole('combobox').value).toBe('en')
})

test('a player who chooses a language saves it and reloads the page in it', async() => {
  renderSelector()

  await fireEvent.update(screen.getByRole('combobox'), 'en')
  await vi.waitFor(() => expect(reload).toHaveBeenCalledOnce())

  expect(save).toHaveBeenCalledWith('en')
})

test('a choice the server refused keeps the page', async() => {
  save.mockRejectedValue(new Error('down'))
  renderSelector()

  await fireEvent.update(screen.getByRole('combobox'), 'en')
  await vi.waitFor(() => expect(save).toHaveBeenCalled())

  expect(reload).not.toHaveBeenCalled()
})
