import { loadRenderer, renderHtml } from '@/marktwin/render'

const renderer = shallowRef(null)

// the texts written in Marktwin (the messages of the forums, the private messages), rendered here
// (resources/js/marktwin/render.js): the text as it was written until the renderer is loaded
export function useMarktwin() {
  if (!renderer.value) {
    loadRenderer().then((render) => {
      renderer.value = render
    })
  }

  return {
    isReady: computed(() => renderer.value !== null),
    // (options: the grammar and the icons, for the forum of Eternaltwin)
    render: (text, options = {}) => renderHtml(renderer.value, text, options),
  }
}
