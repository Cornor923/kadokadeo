<script setup>
import { etwinIconUrl } from '@/marktwin/etwin'
import { finishHtml } from '@/marktwin/render'

// a message of the forum of Eternaltwin: its HTML rendered (and sanitized) by Eternaltwin from its Marktwin, its icons
// shown with their images (public/gfx/forum/etwin). The classes of the renderer (mkt-*), for the dark bodies of the
// messages of the forum of Twinoid.
const props = defineProps({
  html: { type: String, default: '' },
})

const content = computed(() => finishHtml(props.html, etwinIconUrl))

const contentClasses = [
  'break-words leading-snug [&_img]:inline [&_img]:align-middle [&_a]:font-bold [&_a]:text-kado-orange',
  '[&_blockquote]:mx-0 [&_blockquote]:my-2 [&_blockquote]:block [&_blockquote]:border [&_blockquote]:border-dashed [&_blockquote]:border-white/50 [&_blockquote]:bg-white/10 [&_blockquote]:p-1.5 [&_blockquote]:italic',
  '[&_.mkt-quoteauthor]:block [&_.mkt-quoteauthor]:text-xs [&_.mkt-quoteauthor]:font-bold [&_.mkt-quoteauthor]:not-italic [&_.mkt-quoteauthor]:after:content-["_:"]',
  '[&_.mkt-spoiler]:cursor-pointer [&_.mkt-spoiler]:bg-[url(/gfx/forum/twinoid/spoiler.png)] [&_.mkt-spoiler]:px-1 [&_.mkt-spoiler]:text-transparent [&_.mkt-spoiler.mkt-spoiler-shown]:bg-none [&_.mkt-spoiler.mkt-spoiler-shown]:text-inherit',
  '[&_.strikethrough]:line-through [&_.mkt-inline-code]:bg-black/20 [&_.mkt-inline-code]:px-1 [&_.mkt-inline-code]:font-mono',
  '[&_pre]:my-2 [&_pre]:overflow-x-auto [&_pre]:bg-black/20 [&_pre]:p-2 [&_pre]:font-mono [&_pre]:text-sm',
  '[&_ul]:my-2 [&_ul]:ml-5 [&_ul]:list-disc [&_ol]:my-2 [&_ol]:ml-5 [&_ol]:list-decimal',
  '[&_.mkt-big]:text-xl [&_.mkt-bad]:font-bold [&_.mkt-bad]:text-red-300',
  '[&_.mkt-rp]:my-2 [&_.mkt-rp]:flex [&_.mkt-rp]:flex-col [&_.mkt-rp]:rounded-lg [&_.mkt-rp]:border [&_.mkt-rp]:border-amber-700 [&_.mkt-rp]:bg-black/25 [&_.mkt-rp]:p-2 [&_.mkt-rpauthor]:text-xs [&_.mkt-rpauthor]:font-bold [&_.mkt-rpauthor]:text-amber-200',
  '[&_.mkt-sidenote]:my-2 [&_.mkt-sidenote]:border-0 [&_.mkt-sidenote]:border-l-2 [&_.mkt-sidenote]:border-solid [&_.mkt-sidenote]:border-white/30 [&_.mkt-sidenote]:pl-3 [&_.mkt-sidenote]:text-sm [&_.mkt-sidenote]:italic [&_.mkt-sidenote]:opacity-80',
  '[&_.mkt-collapsor]:mt-2 [&_.mkt-collapsor]:cursor-pointer [&_.mkt-collapsor]:rounded-sm [&_.mkt-collapsor]:bg-black/20 [&_.mkt-collapsor]:px-2 [&_.mkt-collapsor]:py-1 [&_.mkt-collapsor]:font-bold [&_.mkt-collapsed]:mb-2 [&_.mkt-collapsed]:bg-black/10 [&_.mkt-collapsed]:p-2',
]

// a spoiler is shown (or hidden again) when clicked, a collapsed block opened (or closed)
const onClick = (event) => {
  event.target.closest?.('.mkt-spoiler')?.classList.toggle('mkt-spoiler-shown')
  const collapsor = event.target.closest?.('.mkt-collapsor')
  const collapsed = collapsor?.nextElementSibling
  if (collapsed) {
    collapsed.hidden = !collapsed.hidden
    collapsor.setAttribute('aria-expanded', String(!collapsed.hidden))
  }
}
</script>

<template>
  <!-- the HTML rendered and sanitized by Eternaltwin -->
  <div :class="contentClasses" @click="onClick" v-html="content" />
</template>
