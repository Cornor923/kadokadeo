<script setup>
// a box of the sidebar: its colour frames it and its title (the images: scripts/side-box-svg.py); in Karbon the titles
// take the images of Karbon and its grey text, the blue box turns grey
const props = defineProps({
  title: { type: String, required: true },
  color: { type: String, default: 'blue', validator: (color) => ['green', 'blue', 'pink', 'violet'].includes(color) },
  // the element of the box: aside, nav (the menu)
  as: { type: String, default: 'aside' },
})

const COLORS = {
  green: {
    box: 'border-kado-green-500 bg-kado-green-50 bg-[url(/gfx/bgContainerTopGreen.svg)]',
    title: 'border-kado-green-500 text-kado-green-600 bg-[url(/gfx/bgTitleGreen.svg)] karbon:bg-[url(/gfx/themes/karbon/greenh2_bg.jpg)]',
  },
  blue: {
    box: 'border-kado-teal-500 bg-kado-blue-100 bg-[url(/gfx/bgContainerTopBlue.svg)] karbon:border-kado-slate-500 karbon:bg-kado-slate-50 karbon:bg-[url(/gfx/themes/karbon/greyh2_bg.jpg)] karbon:bg-[position:-15px_-40px]',
    title: 'border-kado-teal-500 text-kado-blue-700 bg-[url(/gfx/bgTitleBlue.svg)] karbon:border-kado-slate-500 karbon:bg-[url(/gfx/themes/karbon/greyh2_bg.jpg)]',
  },
  pink: {
    box: 'border-kado-pink-400 bg-kado-pink-50 bg-[url(/gfx/bgContainerTopPink.svg)]',
    title: 'border-kado-pink-400 text-kado-pink-400 bg-[url(/gfx/bgTitlePink.svg)] karbon:bg-[url(/gfx/themes/karbon/pinkh2_bg.jpg)]',
  },
  violet: {
    box: 'border-kado-violet-400 bg-kado-violet-50 bg-[url(/gfx/bgContainerTopViolet.svg)]',
    title: 'border-kado-violet-400 text-kado-violet-400 bg-[url(/gfx/bgTitleViolet.svg)] karbon:bg-[url(/gfx/themes/karbon/greyh2_bg.jpg)]',
  },
}
</script>

<template>
  <component
    :is="props.as"
    class="mt-7.5 border-3 bg-[position:-205px_13px] bg-no-repeat shadow-[10px_10px_10px] shadow-kado-teal-500/25 karbon:shadow-black/35"
    :class="COLORS[props.color].box"
  >
    <h2 class="h-4.5 w-full border-b-3 bg-[position:-15px_-5px] bg-no-repeat pl-5 text-[1.15em] karbon:text-kado-slate-700" :class="COLORS[props.color].title">
      {{ props.title }}
    </h2>
    <slot />
  </component>
</template>
