<script setup>
// a text written in Marktwin (a message of a forum), rendered by @eternaltwin/marktwin (useMarktwin): its HTML is made
// by the renderer only (the text of the players is escaped), so it is shown with v-html
const props = defineProps({
  text: { type: String, default: '' },
  // the grammar and the images of the icons (resources/js/marktwin/render.js), when not the ones of the site (the
  // forum of Eternaltwin)
  grammar: { type: Object, default: null },
  iconUrl: { type: Function, default: null },
})

const { render } = useMarktwin()
// (rendered again once the renderer is loaded: render reads it)
const html = computed(() => render(props.text, {
  ...(props.grammar ? { grammar: props.grammar } : {}),
  ...(props.iconUrl ? { iconUrl: props.iconUrl } : {}),
}))

// the classes made by the renderer (mkt-*): the quotes as the "cite" of the old forum, the spoilers hidden until
// clicked
const contentClasses = [
  'break-words [&_img]:inline [&_img]:align-text-bottom',
  '[&_blockquote]:mx-0 [&_blockquote]:my-2 [&_blockquote]:block [&_blockquote]:border [&_blockquote]:border-dashed [&_blockquote]:border-kado-cyan-700 [&_blockquote]:bg-kado-cyan-100 [&_blockquote]:p-1 [&_blockquote]:text-kado-cyan-900 [&_blockquote]:italic',
  '[&_.mkt-quoteauthor]:block [&_.mkt-quoteauthor]:font-bold [&_.mkt-quoteauthor]:not-italic [&_.mkt-quoteauthor]:after:content-["_:"]',
  '[&_.mkt-spoiler]:cursor-pointer [&_.mkt-spoiler]:bg-kado-pink-50 [&_.mkt-spoiler]:px-1 [&_.mkt-spoiler]:text-transparent [&_.mkt-spoiler]:outline [&_.mkt-spoiler]:outline-kado-pink-400',
  '[&_.mkt-spoiler.mkt-spoiler-shown]:text-kado-pink-600',
  '[&_.strikethrough]:line-through [&_.mkt-inline-code]:bg-kado-cyan-200 [&_.mkt-inline-code]:px-1 [&_.mkt-inline-code]:font-mono',
  '[&_pre]:my-2 [&_pre]:overflow-x-auto [&_pre]:bg-kado-cyan-200 [&_pre]:p-2 [&_pre]:font-mono [&_pre]:text-sm',
  '[&_ul]:my-2 [&_ul]:ml-4 [&_ul]:list-inside [&_ul]:list-image-[url(/gfx/puce.jpg)] [&_ol]:my-2 [&_ol]:ml-4 [&_ol]:list-inside [&_ol]:list-decimal',
]

// a spoiler is shown (or hidden again) when clicked
const toggleSpoiler = (event) => event.target.closest?.('.mkt-spoiler')?.classList.toggle('mkt-spoiler-shown')
</script>

<template>
  <!-- the HTML of the Marktwin renderer (useMarktwin) -->
  <div :class="contentClasses" @click="toggleSpoiler" v-html="html" />
</template>
