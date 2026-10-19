import { loadRenderer, renderHtml } from '@/marktwin/render'

// <kado-marktwin text="…">: a text written in Marktwin (a private message, its preview) in the admin panel, rendered as
// on the site (resources/js/marktwin/render.js). Livewire changes its "text" attribute: it is rendered again. Its own
// styles (shadow DOM): the classes of the renderer, as resources/js/components/marktwin/Content.vue, without touching
// the ones of Filament.
const STYLES = `
  :host { display: block; overflow-wrap: anywhere; line-height: 1.5; }
  img { display: inline; vertical-align: text-bottom; }
  a { color: #ffa400; font-weight: bold; }
  blockquote { margin: 0.5rem 0; padding: 0.25rem; border: 1px dashed #20a8c3; background: #edffff; color: #1f6776; font-style: italic; }
  .mkt-quoteauthor { display: block; font-weight: bold; font-style: normal; }
  .mkt-quoteauthor::after { content: ' :'; }
  .mkt-spoiler { padding: 0 0.25rem; background: #ffecf2; color: transparent; outline: 1px solid #ff6b9c; cursor: pointer; }
  .mkt-spoiler.mkt-spoiler-shown { color: #f40b58; }
  .strikethrough { text-decoration: line-through; }
  .mkt-inline-code { padding: 0 0.25rem; background: #eaf8fa; font-family: monospace; }
  pre { margin: 0.5rem 0; padding: 0.5rem; overflow-x: auto; background: #eaf8fa; font-family: monospace; }
  ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
`

// (once loaded: the texts are rendered at once)
let loadedRenderer = null

class KadoMarktwin extends HTMLElement {
  static observedAttributes = ['text']

  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })
    shadow.innerHTML = `<style>${STYLES}</style><div></div>`
    this.content = shadow.querySelector('div')
    // a spoiler is shown (or hidden again) when clicked
    this.content.addEventListener('click', (event) => event.target.closest('.mkt-spoiler')?.classList.toggle('mkt-spoiler-shown'))
  }

  connectedCallback() {
    this.render()
  }

  attributeChangedCallback() {
    this.render()
  }

  render() {
    const text = this.getAttribute('text') ?? ''
    // (the text as it was written while the renderer loads)
    this.content.innerHTML = renderHtml(loadedRenderer, text)
    if (!loadedRenderer) {
      loadRenderer().then((renderer) => {
        loadedRenderer = renderer
        // (unless the text changed meanwhile)
        if (text === (this.getAttribute('text') ?? '')) {
          this.content.innerHTML = renderHtml(renderer, text)
        }
      })
    }
  }
}

if (!customElements.get('kado-marktwin')) {
  customElements.define('kado-marktwin', KadoMarktwin)
}
