import { FORUM_GRAMMAR, SMILEYS, smileyUrl } from './grammar'

// the rendering of the texts written in Marktwin (the messages of the forums, the private messages), for the site
// (useMarktwin) and the admin panel (resources/js/admin/marktwin.js)

let loading = null

// the renderer of @eternaltwin/marktwin (WebAssembly, ~430 KB): loaded with the first text to render
export const loadRenderer = () => (loading ??= import('@eternaltwin/marktwin').then((module) => module.renderMarktwin))

export const escapeHtml = (text) =>
  text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll('\'', '&#39;')

// the text as it was written, while the renderer loads or when it fails
export const plainHtml = (text) => escapeHtml(text).replaceAll('\n', '<br />\n')

// the WebAssembly of @eternaltwin/marktwin 0.6.0 corrupts its memory on texts with non-ASCII characters (as short as
// 31 "é", a panic, then its other calls fail): the renderer only gets ASCII, each other character as "&#233;", put back
// in its HTML (where the renderer escaped "&" into "&amp;")
const toAscii = (text) => text.replace(/[\u0080-\u{10ffff}]/gu, (char) => `&#${char.codePointAt(0)};`)
const fromAscii = (html) =>
  html.replace(/&amp;#(\d+);/g, (entity, code) => (Number(code) <= 0x10ffff ? escapeHtml(String.fromCodePoint(Number(code))) : entity))

const smileyFiles = Object.fromEntries(SMILEYS.map((smiley) => [smiley.key, smileyUrl(smiley)]))

// the image of an icon of the KadoKado smileys (the clan forums, the private messages): its URL or null
export const smileyIconUrl = (key) => smileyFiles[key] ?? null

// the icons (<span class="mkt-icon mkt-icon-kk-smile">) become their images (iconUrl), the links open a new tab. Also
// for the HTML rendered by Eternaltwin (its forum).
export const finishHtml = (html, iconUrl = smileyIconUrl) =>
  html
    .replace(/<span class="mkt-icon mkt-icon-([a-z0-9-]+)"><\/span>/g, (span, key) => {
      const url = iconUrl(key)
      return url ? `<img src="${url}" alt=":${key}:" title=":${key}:" />` : span
    })
    .replaceAll('<a href="', '<a target="_blank" rel="nofollow noopener noreferrer" href="')

// the HTML of a text: it comes from the renderer only (it escapes the text and keeps the links of the grammar), so it
// can be shown as HTML. Without the renderer (not loaded yet, or failing): the text as it was written. By default the
// grammar and the smileys of the site; the forum of Eternaltwin gives its own (served with its sections).
export function renderHtml(renderer, text, { grammar = FORUM_GRAMMAR, iconUrl = smileyIconUrl } = {}) {
  if (!text) {
    return ''
  }
  if (!renderer) {
    return plainHtml(text)
  }
  try {
    return finishHtml(fromAscii(renderer(grammar, toAscii(text))), iconUrl)
  } catch {
    return plainHtml(text)
  }
}
