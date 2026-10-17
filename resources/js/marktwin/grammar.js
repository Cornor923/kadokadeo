// what the players can write in the messages of the forums (Marktwin: https://gitlab.com/eternaltwin/marktwin). The
// grammar of @eternaltwin/marktwin 0.6 needs all its flags: the blocks of the staff of Eternaltwin (mod, admin,
// animation, announcement) and the role plays are off, as the mentions of players.

// the smileys of the forum of KadoKado (public/gfx/forum/smileys): ":kk-smile:" in a message
export const SMILEYS = [
  { key: 'kk-smile', file: 'smile.gif' },
  { key: 'kk-wink', file: 'wink.gif' },
  { key: 'kk-biggrin', file: 'biggrin.gif' },
  { key: 'kk-lol', file: 'lol.gif' },
  { key: 'kk-razz', file: 'razz.gif' },
  { key: 'kk-cool', file: 'cool.gif' },
  { key: 'kk-sad', file: 'sad.gif' },
  { key: 'kk-redface', file: 'redface.gif' },
  { key: 'kk-twisted', file: 'twisted.gif' },
  { key: 'kk-keepcool', file: 'keepcool.gif' },
  { key: 'kk-question', file: 'question.gif' },
  { key: 'kk-exclaim', file: 'exclaim.gif' },
  { key: 'kk-yeah', file: 'yeah.gif' },
  { key: 'kk-arrow', file: 'arrow.gif' },
  { key: 'kk-cross', file: 'cross.gif' },
]

export const smileyUrl = (smiley) => `/gfx/forum/smileys/${smiley.file}`

export const FORUM_GRAMMAR = {
  admin: false,
  animation: false,
  announcement: false,
  bad: false,
  big: false,
  code: true,
  collapse: false,
  // the nesting of the blocks (quotes in quotes...), as on the forum of Eternaltwin
  depth: 4,
  emphasis: true,
  icons: SMILEYS.map((smiley) => smiley.key),
  links: ['http', 'https'],
  list: true,
  mod: false,
  quote: true,
  rp: false,
  sidenote: false,
  spoiler: true,
  strong: true,
  strikethrough: true,
  underline: true,
  user: false,
}
