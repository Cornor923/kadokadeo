// The language of the page, given by the server (App\Support\LocaleResolver), and the choice of the player.
import { t } from './index'

const AUTOMATIC = 'auto'
// a page without a language (the admin panel, the replay verifier) is in French; fr-FR: the format the site always had
const INTL_LOCALES = { fr: 'fr-FR' }

export const pageLocale = () => window.Kado?.locale ?? 'fr'

export const siteLanguages = () => window.Kado?.locales ?? ['fr']

export const languageName = (language) => t(`language.${language}`)

// a text the server gives in each language ({ fr, en }), French when the page's one is not written
export const inPageLanguage = (texts) => texts[pageLocale()] ?? texts.fr

export const intlLocale = () => INTL_LOCALES[pageLocale()] ?? pageLocale()

// the page was loaded for a visitor, in the language of the browser: the account decides once logged in
export const languageChangedByLogin = (player) =>
  Boolean(window.Kado?.i18n_enabled) && player.locale !== AUTOMATIC && player.locale !== pageLocale()

export async function chooseLocale(choice, { save, reload }) {
  await save(choice)
  reload()
}
