import ICONS from './etwinIcons.json'

// the icons of the forum of Eternaltwin (":kk-piou:", ":hordes-eau:"...): the images served by eternaltwin.org, kept in
// public/gfx/forum/etwin (key: {file, width, height}, resources/js/marktwin/etwinIcons.json)
export const etwinIconUrl = (key) => (ICONS[key] ? `/gfx/forum/etwin/${ICONS[key].file}` : null)

// the icons a grammar of Eternaltwin allows (its "icons"), for the box of the editor: the ones of KadoKado first
export const etwinIcons = (keys = []) =>
  keys
    .filter((key) => ICONS[key])
    .sort((a, b) => Number(b.startsWith('kk')) - Number(a.startsWith('kk')) || a.localeCompare(b))
    .map((key) => ({ key, src: etwinIconUrl(key) }))
